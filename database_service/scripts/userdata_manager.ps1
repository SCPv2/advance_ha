# Samsung Cloud Platform v2 - UserData Manager (PowerShell)
# Generates UserData files from variables.json
#
# Based on: userdata_manager.sh logic
# Referenced GitHub installation scripts:
# - Web Server: https://github.com/SCPv2/ceweb/blob/main/web-server/install_web_server.sh
# - App Server: https://github.com/SCPv2/ceweb/blob/main/app-server/install_app_server.sh
# - DB Server: https://github.com/SCPv2/ceweb/blob/main/db-server/vm_db/install_postgresql_vm.sh

param(
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$VariablesJson = Join-Path $ScriptDir "variables.json"
$UserdataTemplate = Join-Path $ScriptDir "userdata_template_base.sh"
$ModulesDir = Join-Path $ScriptDir "modules"
$GeneratedDir = Join-Path $ScriptDir "generated_userdata"
$EmergencyDir = Join-Path $ScriptDir "emergency_scripts"
$OpenStackSizeLimit = 45000  # 45KB

# Server types
$ServerTypes = @("web", "app", "db")

# Color functions
function Red($text) { Write-Host $text -ForegroundColor Red }
function Green($text) { Write-Host $text -ForegroundColor Green }
function Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Blue($text) { Write-Host $text -ForegroundColor Blue }
function Cyan($text) { Write-Host $text -ForegroundColor Cyan }

# Logging functions
function Write-Info($message) { Write-Host "[INFO] $message" }
function Write-Success($message) { Write-Host (Green "[SUCCESS] $message") }
function Write-Error($message) { Write-Host (Red "[ERROR] $message") }

# Setup directories
function Initialize-Directories {
    if (!(Test-Path $GeneratedDir)) {
        New-Item -ItemType Directory -Path $GeneratedDir -Force | Out-Null
    }
    if (!(Test-Path $EmergencyDir)) {
        New-Item -ItemType Directory -Path $EmergencyDir -Force | Out-Null
    }
    Write-Success "Created generated_userdata and emergency_scripts directories"
}

# Load server module content
function Get-ServerModuleContent {
    param([string]$ServerType)
    
    $moduleFile = Join-Path $ModulesDir "${ServerType}_server_module.sh"
    
    if (!(Test-Path $moduleFile)) {
        Write-Error "Module not found: $moduleFile"
        return $null
    }
    
    return Get-Content $moduleFile -Raw
}

# Generate emergency recovery script for a server type
function New-EmergencyScript {
    param(
        [string]$ServerType,
        [string]$VariablesContent
    )
    
    Write-Info "🚨 Generating emergency recovery script for ${ServerType} server..."
    
    # Load server module
    $moduleContent = Get-ServerModuleContent $ServerType
    if (-not $moduleContent) {
        return $false
    }
    
    # Create emergency script header
    $emergencyScript = Join-Path $EmergencyDir "emergency_${ServerType}.sh"
    
    $headerContent = @"
#!/bin/bash
# Samsung Cloud Platform v2 - Emergency Recovery Script
# Server Type: $($ServerType.ToUpper()) SERVER
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
#
# PURPOSE: Emergency installation and configuration when UserData fails
# USAGE: Run this script directly on the VM as root
#        sudo bash emergency_${ServerType}.sh
#
# Referenced GitHub installation scripts:
# - Web Server: https://github.com/SCPv2/ceweb/blob/main/web-server/install_web_server.sh
# - App Server: https://github.com/SCPv2/ceweb/blob/main/app-server/install_app_server.sh
# - DB Server: https://github.com/SCPv2/ceweb/blob/main/db-server/vm_db/install_postgresql_vm.sh

set -euo pipefail

# Color functions for better visibility
red() { echo -e "\033[31m\`$1\033[0m"; }
green() { echo -e "\033[32m\`$1\033[0m"; }
yellow() { echo -e "\033[33m\`$1\033[0m"; }
cyan() { echo -e "\033[36m\`$1\033[0m"; }

# Logging
log_info() { echo "[INFO] \`$1"; }
log_success() { echo "\`$(green "[SUCCESS]") \`$1"; }
log_error() { echo "\`$(red "[ERROR]") \`$1"; }

echo "\`$(cyan "==========================================")"
echo "\`$(cyan "EMERGENCY $($ServerType.ToUpper()) SERVER RECOVERY")"
echo "\`$(cyan "Samsung Cloud Platform v2")"
echo "\`$(cyan "==========================================")"
echo ""

# Check if running as root
if [[ \`$EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Please run: sudo bash emergency_${ServerType}.sh"
    exit 1
fi

log_info "Starting emergency recovery for ${ServerType} server..."

# System Update
sys_update() {
    log_info "[1/4] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do 
        echo "Waiting for network connectivity..."
        sleep 10
    done
    
    for i in {1..3}; do 
        dnf clean all && dnf install -y epel-release && break
        sleep 30
    done
    
    dnf -y update || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    
    log_success "System updated with NTP"
}

# Repository Clone
repo_clone() {
    log_info "[2/4] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    log_success "Repository ready"
}

# Create master_config.json
create_master_config() {
    log_info "[3/4] Creating master_config.json..."
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
$VariablesContent
CONFIG_EOF
    
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    
    # Validate JSON
    if ! jq . /home/rocky/master_config.json >/dev/null; then
        log_error "Invalid JSON in master_config.json"
        exit 1
    fi
    
    log_success "master_config.json created and validated"
}

# Server-specific installation (from module)
"@

    # Append the server module content (app_install and verify_install functions)
    $fullContent = $headerContent + "`n" + $moduleContent
    
    # Add main execution and testing section
    $mainContent = @'

# Main execution
main() {
    sys_update
    repo_clone
    create_master_config
    app_install
    verify_install
    
    echo ""
    log_success "🎉 EMERGENCY RECOVERY COMPLETED!"
    
    # Create ready indicator
    echo "$(date): Emergency recovery completed" > /home/rocky/${SERVER_TYPE^}_Emergency_Ready.log
    
    show_test_commands
}

# Show test commands for user verification
show_test_commands() {
    echo ""
    echo "$(cyan "==========================================")"
    echo "$(cyan "MANUAL TESTING COMMANDS")"
    echo "$(cyan "==========================================")"
    echo ""
'@

    $fullContent += $mainContent
    
    # Add server-specific test commands
    switch ($ServerType) {
        "web" {
            $testCommands = @'
    echo "$(yellow "WEB SERVER TESTING:")"
    echo ""
    echo "1. Check Nginx status:"
    echo "   systemctl status nginx"
    echo ""
    echo "2. Test web server response:"
    echo "   curl -I http://localhost/"
    echo ""
    echo "3. Check Nginx configuration:"
    echo "   nginx -t"
    echo ""
    echo "4. View Nginx access logs:"
    echo "   tail -f /var/log/nginx/access.log"
    echo ""
    echo "5. Test specific endpoints:"
    echo "   curl http://localhost/"
    echo "   curl http://localhost/api/"
    echo ""
    echo "6. Check SELinux status:"
    echo "   getsebool httpd_read_user_content"
    echo "   getsebool httpd_can_network_connect"
    echo ""
    echo "7. Verify domain configuration:"
    echo "   cat /etc/nginx/conf.d/creative-energy.conf"
'@
        }
        "app" {
            $testCommands = @'
    echo "$(yellow "APP SERVER TESTING:")"
    echo ""
    echo "1. Check Node.js version:"
    echo "   node --version"
    echo ""
    echo "2. Check PM2 status:"
    echo "   sudo -u rocky pm2 status"
    echo ""
    echo "3. Check application port:"
    echo "   netstat -tlnp | grep :3000"
    echo ""
    echo "4. Test application health:"
    echo "   curl http://localhost:3000/health"
    echo ""
    echo "5. View application logs:"
    echo "   sudo -u rocky pm2 logs"
    echo ""
    echo "6. Test database connection:"
    echo "   cd /home/rocky/ceweb/app-server"
    echo "   sudo -u rocky node -e 'console.log(process.env.DB_HOST)'"
    echo ""
    echo "7. Check environment file:"
    echo "   sudo -u rocky cat /home/rocky/ceweb/app-server/.env"
    echo ""
    echo "8. Restart application if needed:"
    echo "   sudo -u rocky pm2 restart all"
'@
        }
        "db" {
            $testCommands = @'
    echo "$(yellow "DATABASE SERVER TESTING:")"
    echo ""
    echo "1. Check PostgreSQL status:"
    echo "   systemctl status postgresql-16"
    echo ""
    echo "2. Check database port:"
    echo "   netstat -tlnp | grep :2866"
    echo ""
    echo "3. Test database connection:"
    echo "   sudo -u postgres psql -h localhost -p 2866 -d cedb -c 'SELECT version();'"
    echo ""
    echo "4. Check database users:"
    echo "   sudo -u postgres psql -c '\du'"
    echo ""
    echo "5. List databases:"
    echo "   sudo -u postgres psql -c '\l'"
    echo ""
    echo "6. Check tables in cedb:"
    echo "   sudo -u postgres psql -d cedb -c '\dt'"
    echo ""
    echo "7. View PostgreSQL configuration:"
    echo "   cat /var/lib/pgsql/16/data/postgresql.conf | grep -E '(listen_addresses|port)'"
    echo ""
    echo "8. Check connection permissions:"
    echo "   cat /var/lib/pgsql/16/data/pg_hba.conf"
    echo ""
    echo "9. Test with application credentials:"
    echo "   PGPASSWORD=ceadmin123 psql -h localhost -p 2866 -U ceadmin -d cedb -c 'SELECT now();'"
'@
        }
    }
    
    $fullContent += $testCommands
    
    $footerContent = @"

    echo ""
    echo "`$(green "Emergency recovery script completed!")"
    echo "`$(green "Use the commands above to verify the installation.")"
    echo ""
    echo "`$(cyan "Log files:")"
    echo "  - Emergency recovery: /home/rocky/`${SERVER_TYPE^}_Emergency_Ready.log"
    echo "  - Master config: /home/rocky/master_config.json"
    echo "  - Application logs: Check service-specific locations above"
    echo ""
}

# Define SERVER_TYPE for the script
SERVER_TYPE="$ServerType"

# Execute main function
main "`$@"
"@

    $fullContent += $footerContent
    
    # Write the emergency script (UTF-8 without BOM)
    [System.IO.File]::WriteAllText($emergencyScript, $fullContent, [System.Text.UTF8Encoding]::new($false))
    
    Write-Success "Emergency recovery script generated: $emergencyScript"
    return $true
}

# Generate UserData for a specific server type
function New-ServerUserData {
    param([string]$ServerType)
    
    Write-Info "🔧 Generating ${ServerType} server UserData..."
    
    # Load base template
    if (!(Test-Path $UserdataTemplate)) {
        Write-Error "Base template not found: $UserdataTemplate"
        return $false
    }
    $baseTemplate = Get-Content $UserdataTemplate -Raw
    
    # Load server module
    $moduleContent = Get-ServerModuleContent $ServerType
    if (-not $moduleContent) {
        return $false
    }
    Write-Success "Module loaded: ${ServerType}_server_module.sh"
    
    # Load variables.json content
    if (!(Test-Path $VariablesJson)) {
        Write-Error "Variables file not found: $VariablesJson"
        return $false
    }
    
    $variablesContent = Get-Content $VariablesJson -Raw | ConvertFrom-Json | ConvertTo-Json -Compress
    Write-Success "Variables loaded: $($variablesContent.Length) chars"
    
    # Substitute template variables
    $userdataContent = $baseTemplate
    
    # Replace SERVER_TYPE
    $userdataContent = $userdataContent -replace '\${SERVER_TYPE}', $ServerType
    
    # Replace APPLICATION_INSTALL_MODULE
    $userdataContent = $userdataContent -replace '\${APPLICATION_INSTALL_MODULE}', $moduleContent
    
    # Replace MASTER_CONFIG_JSON_CONTENT
    $userdataContent = $userdataContent -replace '\${MASTER_CONFIG_JSON_CONTENT}', $variablesContent
    
    # Validate size (OpenStack 45KB limit)
    $sizeBytes = [System.Text.Encoding]::UTF8.GetByteCount($userdataContent)
    
    Write-Host "UserData size: $sizeBytes bytes (limit: $OpenStackSizeLimit bytes)"
    
    if ($sizeBytes -gt $OpenStackSizeLimit) {
        Write-Error "UserData exceeds 45KB limit: $sizeBytes bytes"
        return $false
    }
    
    $sizePercentage = [math]::Round(($sizeBytes * 100 / $OpenStackSizeLimit), 1)
    Write-Success "UserData size validation passed: $sizeBytes bytes"
    
    # Write output file (UTF-8 without BOM with Unix line endings)
    $outputFile = Join-Path $GeneratedDir "userdata_${ServerType}.sh"
    # Convert Windows line endings to Unix line endings
    $userdataContentUnix = $userdataContent -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($outputFile, $userdataContentUnix, [System.Text.UTF8Encoding]::new($false))
    
    Write-Host (Green "🎉 UserData generated successfully!")
    Write-Host (Yellow "📁 Output: ") -NoNewline; Write-Host $outputFile
    Write-Host (Yellow "📊 Size: ") -NoNewline; Write-Host "$sizeBytes / $OpenStackSizeLimit bytes ($sizePercentage%)"
    
    # Generate emergency recovery script with same variables
    if (New-EmergencyScript $ServerType $variablesContent) {
        Write-Host (Green "🚨 Emergency recovery script generated!")
    } else {
        Write-Error "Failed to generate emergency recovery script for $ServerType"
        return $false
    }
    
    return $true
}

# Generate all UserData files
function New-AllUserData {
    Write-Info "🚀 Samsung Cloud Platform v2 - Batch UserData Generator"
    Cyan "============================================================"
    
    $totalGenerated = 0
    $generationSummary = @()
    
    foreach ($serverType in $ServerTypes) {
        Write-Host ""
        Write-Info "Generating ${serverType} server UserData..."
        
        if (New-ServerUserData $serverType) {
            $totalGenerated++
            
            # Get file size for summary
            $outputFile = Join-Path $GeneratedDir "userdata_${serverType}.sh"
            $fileSize = (Get-Item $outputFile).Length
            $sizePercentage = [math]::Round(($fileSize * 100 / $OpenStackSizeLimit), 1)
            
            $generationSummary += "📁 $serverType : $fileSize bytes ($sizePercentage% of 45KB limit)"
            
            Write-Success "${serverType} server UserData generated"
        } else {
            Write-Error "Failed to generate ${serverType} server UserData"
            return $false
        }
    }
    
    # Display summary
    Write-Host ""
    Cyan "📊 Generation Summary:"
    Cyan "=================================================="
    $generationSummary | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Green "🎉 All UserData files generated successfully!"
    Write-Host (Blue "📂 UserData directory: ") -NoNewline; Write-Host $GeneratedDir
    Write-Host (Blue "🚨 Emergency scripts: ") -NoNewline; Write-Host $EmergencyDir
    Write-Host ""
    Yellow "📋 Emergency Recovery Usage:"
    Write-Host "If UserData fails during VM boot, SSH to the VM and run:"
    Write-Host "  • Web Server: sudo bash emergency_web.sh"
    Write-Host "  • App Server: sudo bash emergency_app.sh"
    Write-Host "  • DB Server:  sudo bash emergency_db.sh"
    Write-Host ""
    Yellow "📋 Next Steps:"
    Write-Host "1. Review generated UserData files in $GeneratedDir"
    Write-Host "2. Copy emergency scripts to VMs if needed"
    Write-Host "3. Test UserData files in development environment"
    Write-Host "4. Deploy using terraform_manager.ps1"
    Write-Host ""
    
    return $true
}

# Validate prerequisites
function Test-Prerequisites {
    $errors = 0
    
    # Check variables.json
    if (!(Test-Path $VariablesJson)) {
        Write-Error "variables.json not found: $VariablesJson"
        Write-Error "Run variables_manager.ps1 first to generate variables.json"
        $errors++
    }
    
    # Check base template
    if (!(Test-Path $UserdataTemplate)) {
        Write-Error "UserData template not found: $UserdataTemplate"
        $errors++
    }
    
    # Check modules directory
    if (!(Test-Path $ModulesDir)) {
        Write-Error "Modules directory not found: $ModulesDir"
        $errors++
    }
    
    # Check individual modules
    foreach ($serverType in $ServerTypes) {
        $moduleFile = Join-Path $ModulesDir "${serverType}_server_module.sh"
        if (!(Test-Path $moduleFile)) {
            Write-Error "Module not found: $moduleFile"
            $errors++
        }
    }
    
    if ($errors -gt 0) {
        Write-Error "Prerequisites validation failed with $errors errors"
        return $false
    }
    
    Write-Success "All prerequisites validated successfully"
    return $true
}

# Main execution
function Main {
    Write-Info "🚀 Samsung Cloud Platform v2 - UserData Manager"
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Setup directories
    Initialize-Directories
    
    # Generate UserData files
    if (-not (New-AllUserData)) {
        Write-Error "UserData generation failed"
        exit 1
    }
    
    Write-Success "✅ UserData generation completed successfully!"
    Write-Info "Next step: Run terraform_manager.ps1 to deploy infrastructure"
    
    return 0
}

# Set debug mode
if ($Debug) {
    $env:DEBUG_MODE = "true"
}

# Run main function
try {
    exit (Main)
} catch {
    Write-Error "UserData generation failed: $($_.Exception.Message)"
    exit 1
}