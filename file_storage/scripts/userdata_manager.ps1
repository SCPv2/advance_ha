# Samsung Cloud Platform v2 - UserData Manager  
# Manages UserData generation using common-script templates and modules
#
# Author: SCPv2 Team

param(
    [string[]]$ServerTypes = @("web", "app", "db"),
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$UserdataTemplate = Resolve-Path (Join-Path $ProjectDir "..\common-script\userdata_template_base.sh")
$ModulesDir = Resolve-Path (Join-Path $ProjectDir "..\common-script\modules")
$VariablesJson = Join-Path $ScriptDir "variables.json"
$GeneratedUserdataDir = Join-Path $ScriptDir "generated_userdata"
$EmergencyScriptsDir = Join-Path $ScriptDir "emergency_scripts"

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
function Write-Warning($message) { Write-Host (Yellow "[WARNING] $message") }

# Initialize directories
function Initialize-Directories {
    if (!(Test-Path $GeneratedUserdataDir)) {
        New-Item -ItemType Directory -Path $GeneratedUserdataDir -Force | Out-Null
    }
    if (!(Test-Path $EmergencyScriptsDir)) {
        New-Item -ItemType Directory -Path $EmergencyScriptsDir -Force | Out-Null
    }
    Write-Success "Created generated_userdata and emergency_scripts directories"
}

# Load variables from JSON
function Get-Variables {
    if (!(Test-Path $VariablesJson)) {
        Write-Error "Variables file not found: $VariablesJson. Run variables_manager.ps1 first."
    }
    
    try {
        $variables = Get-Content $VariablesJson | ConvertFrom-Json
        Write-Success "Variables loaded: $($VariablesJson.Length) chars"
        return $variables
    } catch {
        Write-Error "Failed to load variables: $($_.Exception.Message)"
    }
}

# Generate UserData for a specific server type  
function Generate-UserData {
    param(
        [string]$ServerType,
        [object]$Variables
    )
    
    Write-Info "🔧 Generating $ServerType server UserData..."
    
    # Load appropriate module
    $moduleFile = Join-Path $ModulesDir "${ServerType}_server_module.sh"
    if (!(Test-Path $moduleFile)) {
        Write-Error "Module not found: $moduleFile"
    }
    
    $moduleContent = Get-Content $moduleFile -Raw
    Write-Success "Module loaded: ${ServerType}_server_module.sh"
    
    # Load template
    if (!(Test-Path $UserdataTemplate)) {
        Write-Error "Template not found: $UserdataTemplate"
    }
    
    $template = Get-Content $UserdataTemplate -Raw
    
    # Load variables JSON content
    $variablesContent = Get-Content $VariablesJson -Raw
    Write-Success "Variables loaded: $($variablesContent.Length) chars"
    
    # Replace template variables
    $userdata = $template -replace '\$\{VARIABLES_JSON\}', $variablesContent
    $userdata = $userdata -replace '\$\{SERVER_TYPE\}', $ServerType.ToUpper()
    $userdata = $userdata -replace '\$\{SERVER_MODULE_CONTENT\}', $moduleContent
    
    # Validate UserData size (45KB OpenStack limit)
    $userdataBytes = [System.Text.Encoding]::UTF8.GetByteCount($userdata)
    $maxSize = 45000  # 45KB limit
    
    Write-Info "UserData size: $userdataBytes bytes (limit: $maxSize bytes)"
    
    if ($userdataBytes -gt $maxSize) {
        Write-Warning "UserData exceeds 45KB limit: $userdataBytes bytes"
        Write-Warning "Consider optimizing the UserData content"
    } else {
        Write-Success "UserData size validation passed: $userdataBytes bytes"
    }
    
    # Save UserData
    $outputFile = Join-Path $GeneratedUserdataDir "userdata_$ServerType.sh"
    $userdata | Out-File -FilePath $outputFile -Encoding UTF8
    
    Write-Success "🎉 UserData generated successfully!"
    Write-Info ""
    Write-Info "📁 Output: `n$outputFile"
    Write-Info "📊 Size: `n$userdataBytes / $maxSize bytes ($([math]::Round($userdataBytes / $maxSize * 100, 1))%)"
    
    # Generate emergency recovery script
    Generate-EmergencyScript -ServerType $ServerType -ModuleContent $moduleContent -Variables $Variables
    
    return $outputFile
}

# Generate emergency recovery script
function Generate-EmergencyScript {
    param(
        [string]$ServerType,
        [string]$ModuleContent,
        [object]$Variables
    )
    
    Write-Info "🚨 Generating emergency recovery script for $ServerType server..."
    
    $emergencyScript = @"
#!/bin/bash
# Emergency Recovery Script for $($ServerType.ToUpper()) Server
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 
# This script can be manually executed if UserData fails during VM boot
# Usage: sudo bash emergency_$ServerType.sh

set -e

echo "🚨 Emergency Recovery: $($ServerType.ToUpper()) Server Setup"
echo "Started: `$(date)"

$ModuleContent

echo "✅ Emergency recovery completed: `$(date)"
"@

    $emergencyFile = Join-Path $EmergencyScriptsDir "emergency_$ServerType.sh"
    $emergencyScript | Out-File -FilePath $emergencyFile -Encoding UTF8
    
    Write-Success "Emergency recovery script generated: $emergencyFile"
    Write-Info ""
    Write-Success "🚨 Emergency recovery script generated!"
}

# Generate Object Storage configuration script for manual deployment
function New-ObjectStorageConfigScript {
    param([string]$VariablesContent)
    
    Write-Info "🔧 Generating Object Storage configuration script for manual deployment..."
    
    $configScript = Join-Path $ScriptsDir "configure_web_server_for_object_storage.sh"
    
    $currentDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    $scriptContent = @"
#!/bin/bash
# Samsung Cloud Platform v2 - Object Storage Configuration Script
# Generated: $currentDate
#
# PURPOSE: Configure master_config.json for manually deployed web servers
# USAGE: Run this script from /home/rocky directory
#        cd /home/rocky && bash configure_web_server_for_object_storage.sh
#
# This script creates master_config.json required for Object Storage integration

set -euo pipefail

# Color functions
red() { echo -e `"\033[31m`$1\033[0m`"; }
green() { echo -e `"\033[32m`$1\033[0m`"; }
yellow() { echo -e `"\033[33m`$1\033[0m`"; }
cyan() { echo -e `"\033[36m`$1\033[0m`"; }

# Logging
log_info() { echo `"[INFO] `$1`"; }
log_success() { echo `"`$(green `"[SUCCESS]`") `$1`"; }
log_error() { echo `"`$(red `"[ERROR]`") `$1`"; }
log_warning() { echo `"`$(yellow `"[WARNING]`") `$1`"; }

echo `"`$(cyan `"===========================================`")`"
echo `"`$(cyan `"Object Storage Configuration for Web Server`")`"
echo `"`$(cyan `"Samsung Cloud Platform v2`")`"
echo `"`$(cyan `"===========================================`")`"
echo `"`"

# Check if running from correct directory
if [[ `"`$(pwd)`" != `"/home/rocky`" ]]; then
    log_warning `"Current directory: `$(pwd)`"
    log_info `"Switching to /home/rocky directory...`"
    cd /home/rocky || {
        log_error `"Failed to change to /home/rocky directory`"
        exit 1
    }
fi

# Check if ceweb repository exists
if [[ ! -d `"ceweb`" ]]; then
    log_error `"ceweb directory not found in /home/rocky`"
    log_info `"Please clone the repository first:`"
    echo `"  git clone https://github.com/SCPv2/ceweb.git`"
    exit 1
fi

# Check if web-server directory exists
if [[ ! -d `"ceweb/web-server`" ]]; then
    log_error `"web-server directory not found in /home/rocky/ceweb`"
    log_info `"Repository structure may be incorrect`"
    exit 1
fi

# Create master_config.json
log_info `"Creating master_config.json...`"

cat > /home/rocky/ceweb/web-server/master_config.json << 'CONFIG_EOF'
$VariablesContent
CONFIG_EOF

# Set proper permissions
if id `"rocky`" &>/dev/null; then
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    chmod 644 /home/rocky/ceweb/web-server/master_config.json
    log_success `"Permissions set for rocky user`"
else
    chmod 644 /home/rocky/ceweb/web-server/master_config.json
    log_warning `"User 'rocky' not found, permissions set for current user`"
fi

# Validate JSON
if command -v jq &> /dev/null; then
    if jq . /home/rocky/ceweb/web-server/master_config.json >/dev/null 2>&1; then
        log_success `"JSON validation passed`"
    else
        log_error `"Invalid JSON in master_config.json`"
        log_info `"Please check the file for syntax errors`"
        exit 1
    fi
else
    log_warning `"jq not installed, skipping JSON validation`"
    log_info `"Install jq for JSON validation: sudo dnf install -y jq`"
fi

# Check if required fields exist
if command -v jq &> /dev/null; then
    log_info `"Checking Object Storage configuration...`"
    
    BUCKET_STRING=`$(jq -r '.user_input_variables.object_storage_bucket_string // `"not_found`"' /home/rocky/ceweb/web-server/master_config.json)
    BUCKET_NAME=`$(jq -r '.ceweb_required_variables.object_storage_bucket_name // `"not_found`"' /home/rocky/ceweb/web-server/master_config.json)
    PUBLIC_ENDPOINT=`$(jq -r '.ceweb_required_variables.object_storage_public_endpoint // `"not_found`"' /home/rocky/ceweb/web-server/master_config.json)
    
    if [[ `"`$BUCKET_STRING`" == `"not_found`" ]] || [[ `"`$BUCKET_STRING`" == `"thisneedstobereplaced1234`" ]]; then
        log_warning `"Object Storage bucket string not configured or using default value`"
        log_info `"Template variables will use local media files instead of Object Storage`"
    else
        log_success `"Object Storage configured:`"
        echo `"  - Bucket String: `$BUCKET_STRING`"
        echo `"  - Bucket Name: `$BUCKET_NAME`"
        echo `"  - Endpoint: `$PUBLIC_ENDPOINT`"
        echo `"`"
        echo `"  Full Object Storage URL will be:`"
        echo `"  `$PUBLIC_ENDPOINT/`$BUCKET_STRING:`$BUCKET_NAME/media/img/`"
    fi
fi

echo `"`"
log_success `"master_config.json created successfully!`"
echo `"`"
echo `"`$(cyan `"File location:`")`"
echo `"  /home/rocky/ceweb/web-server/master_config.json`"
echo `"`"
echo `"`$(cyan `"Next steps:`")`"
echo `"  1. Restart web server to apply configuration:`"
echo `"     sudo systemctl restart nginx`"
echo `"`"
echo `"  2. Check if template variables are being replaced:`"
echo `"     Open browser and check if images load correctly`"
echo `"`"
echo `"  3. Monitor browser console for any errors:`"
echo `"     Check for {{OBJECT_STORAGE_MEDIA_BASE}} placeholders`"
echo `"`"
echo `"  4. If using Object Storage, ensure:`"
echo `"     - Bucket is created and accessible`"
echo `"     - CORS policy is configured for your domain`"
echo `"     - Files are uploaded to correct paths`"
echo `"`"

# Test if nginx is installed and running
if command -v nginx &> /dev/null; then
    if systemctl is-active nginx &> /dev/null; then
        log_info `"Nginx is running. You may want to restart it:`"
        echo `"  sudo systemctl restart nginx`"
    else
        log_warning `"Nginx is installed but not running`"
        echo `"  Start nginx: sudo systemctl start nginx`"
    fi
else
    log_warning `"Nginx not found. Please install and configure nginx`"
fi

echo `"`"
log_success `"Configuration script completed!`"
"@

    # Write the configuration script (UTF-8 without BOM)
    [System.IO.File]::WriteAllText($configScript, $scriptContent, [System.Text.UTF8Encoding]::new($false))
    
    Write-Success "Object Storage configuration script generated: $configScript"
    return $true
}

# Main execution
function Main {
    Write-Info "🚀 Samsung Cloud Platform v2 - UserData Manager"
    
    # Validate prerequisites
    if (!(Test-Path $UserdataTemplate)) {
        Write-Error "Template not found: $UserdataTemplate"
    }
    if (!(Test-Path $ModulesDir)) {
        Write-Error "Modules directory not found: $ModulesDir"  
    }
    if (!(Test-Path $VariablesJson)) {
        Write-Error "Variables file not found: $VariablesJson. Run variables_manager.ps1 first."
    }
    Write-Success "All prerequisites validated successfully"
    Write-Info ""
    
    Initialize-Directories
    Write-Info ""
    
    $variables = Get-Variables
    
    Write-Info "🚀 Samsung Cloud Platform v2 - Batch UserData Generator"
    Write-Info "============================================================"
    Write-Info ""
    
    $generatedFiles = @()
    
    foreach ($serverType in $ServerTypes) {
        Write-Info "Generating $serverType server UserData..."
        $outputFile = Generate-UserData -ServerType $serverType -Variables $variables
        $generatedFiles += $outputFile
        Write-Success "$serverType server UserData generated"
        Write-Info ""
    }
    
    # Summary
    Write-Info "📊 Generation Summary:"
    Write-Info "=================================================="
    
    foreach ($serverType in $ServerTypes) {
        $file = Join-Path $GeneratedUserdataDir "userdata_$serverType.sh"
        if (Test-Path $file) {
            $size = (Get-Item $file).Length
            $percentage = [math]::Round($size / 45000 * 100, 1)
            Write-Info "📁 $serverType : $size bytes ($percentage% of 45KB limit)"
        }
    }
    
    Write-Info ""
    Write-Success "🎉 All UserData files generated successfully!"
    Write-Info "📂 UserData directory: `n$GeneratedUserdataDir"
    Write-Info "🚨 Emergency scripts: `n$EmergencyScriptsDir"
    Write-Info ""
    Write-Info "📋 Emergency Recovery Usage:"
    Write-Info "If UserData fails during VM boot, SSH to the VM and run:"
    foreach ($serverType in $ServerTypes) {
        Write-Info "  • $($serverType.Substring(0,1).ToUpper() + $serverType.Substring(1)) Server: sudo bash emergency_$serverType.sh"
    }
    
    Write-Info ""
    Write-Info "📋 Next Steps:"
    Write-Info "1. Review generated UserData files in $GeneratedUserdataDir"
    Write-Info "2. Copy emergency scripts to VMs if needed"
    Write-Info "3. Test UserData files in development environment"  
    Write-Info "4. Deploy using terraform_manager.ps1"
    Write-Info ""
    
    # Generate Object Storage configuration script for manual deployment
    if (Test-Path $VariablesJson) {
        $variablesContent = Get-Content $VariablesJson -Raw | ConvertFrom-Json | ConvertTo-Json -Compress
        if (New-ObjectStorageConfigScript $variablesContent) {
            Write-Success "✅ Object Storage configuration script generated!"
            Write-Info "📁 Script location: $ScriptsDir\configure_web_server_for_object_storage.sh"
            Write-Info "📋 Usage: Copy to web server and run from /home/rocky directory"
        }
    }
    
    Write-Info ""
    Write-Success "✅ UserData generation completed successfully!"
    Write-Info ""
    Write-Info "Next step: Run terraform_manager.ps1 to deploy infrastructure"
}

# Execute main function
if ($MyInvocation.InvocationName -ne '.') {
    Main
}