# Samsung Cloud Platform v2 - Master Controller & Deployment Orchestrator
# Version: 4.0 (PowerShell implementation with proper data flow and monitoring)
# 
# MASTER CONTROLLER RESPONSIBILITIES:
# 1. Module Integration & Control: variables_manager -> userdata_manager -> terraform_manager
# 2. Data Flow Management: variables.tf -> variables.json -> userdata_*.sh -> terraform apply
# 3. Error Handling & Recovery: Module failure detection and recovery path guidance
# 4. Monitoring & Logging: Centralized log management and deployment monitoring
# 5. User Experience: Progress tracking and status reporting
#
# Data Flow: variables.tf -> variables.json -> userdata_*.sh -> terraform apply
# Referenced GitHub installation scripts:
# - Web Server: https://github.com/SCPv2/ceweb/blob/main/web-server/install_web_server.sh
# - App Server: https://github.com/SCPv2/ceweb/blob/main/app-server/install_app_server.sh  
# - DB Server: https://github.com/SCPv2/ceweb/blob/main/db-server/vm_db/install_postgresql_vm.sh

param(
    [switch]$Debug
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Global Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptsDir = Join-Path $ScriptDir "scripts"
$LogsDir = Join-Path $ScriptDir "lab_logs"
$TerraformLogsDir = Join-Path $ScriptDir "lab_logs"
$VariablesTf = Join-Path $ScriptDir "variables.tf"
$VariablesJson = Join-Path $ScriptsDir "variables.json"

# Master deployment log
$DeploymentLog = Join-Path $LogsDir "deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ChangesLog = Join-Path $LogsDir "logs.log"

# Module Scripts
$VariablesManager = Join-Path $ScriptsDir "variables_manager.ps1"
$UserdataManager = Join-Path $ScriptsDir "userdata_manager.ps1"  
$TerraformManager = Join-Path $ScriptsDir "terraform_manager.ps1"

# Operation mode
$global:OperationMode = ""
$global:DebugMode = $Debug.IsPresent

#region Color Functions
function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green" 
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "Cyan" = "Cyan"
        "White" = "White"
    }
    
    Write-Host $Text -ForegroundColor $colorMap[$Color]
}

function Red($text) { Write-ColorText $text "Red" }
function Green($text) { Write-ColorText $text "Green" }
function Yellow($text) { Write-ColorText $text "Yellow" }
function Blue($text) { Write-ColorText $text "Blue" }
function Cyan($text) { Write-ColorText $text "Cyan" }
#endregion

#region Logging Functions
function Write-LogMessage {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    Write-Host $logEntry
    Add-Content -Path $DeploymentLog -Value $logEntry
}

function Write-Info($message) { Write-LogMessage "INFO" $message }
function Write-Success($message) { 
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
    Add-Content -Path $DeploymentLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] $message"
}
function Write-Error($message) { 
    Write-Host "[ERROR] $message" -ForegroundColor Red
    Add-Content -Path $DeploymentLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] $message"
}
function Write-Warning($message) { 
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
    Add-Content -Path $DeploymentLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [WARNING] $message"
}
#endregion

#region Setup Functions
function Initialize-DeploymentEnvironment {
    Write-Info "🔧 Setting up deployment environment..."
    
    # Create directories
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    # Initialize deployment log
    $logHeader = @"
========================================
Samsung Cloud Platform v2 Deployment Log
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================

"@
    Set-Content -Path $DeploymentLog -Value $logHeader
    
    Write-Success "Deployment environment initialized"
    Write-Info "Master log file: $DeploymentLog"
}

function Initialize-ChangesTracking {
    if (!(Test-Path $ChangesLog)) {
        $trackingHeader = @"
# Samsung Cloud Platform v2 - Changes Tracking Log (logs.log)
# Format: timestamp|action|target|details
# Actions: CREATE, MODIFY, DELETE, TERRAFORM_APPLY, TERRAFORM_DESTROY
# This file tracks all changes for proper cleanup/reset
"@
        Set-Content -Path $ChangesLog -Value $trackingHeader
        Write-Info "Changes tracking initialized: logs.log"
    }
}
#endregion

#region UI Functions
function Show-MainBanner {
    Clear-Host
    Cyan "========================================================"
    Cyan "Samsung Cloud Platform v2 - Lab Environment Manager"
    Cyan "3-Tier Architecture with Dynamic Configuration"
    Cyan "========================================================"
    Write-Host ""
    Write-Host "Choose Operation Mode:" -ForegroundColor White -BackgroundColor Black
    Write-Host ""
    Green "1. DEPLOY   - Deploy new infrastructure"
    Write-Host "   • Variables processing → UserData generation → Terraform apply"
    Write-Host ""
    Yellow "2. CLEANUP  - Destroy infrastructure and reset configuration" 
    Write-Host "   • Terraform destroy → Reset variables → Clean generated files"
    Write-Host ""
    Blue "3. STATUS   - Check deployment status and logs"
    Write-Host ""
    Red "4. EXIT     - Exit without changes"
    Write-Host ""
}

function Get-OperationMode {
    while ($true) {
        Write-Host -NoNewline -ForegroundColor Cyan "Select option (1-4): "
        $input = Read-Host
        
        switch ($input) {
            { $_ -in @("1", "deploy", "DEPLOY") } {
                $global:OperationMode = "deploy"
                Write-Info "DEPLOY mode selected - Infrastructure deployment"
                return
            }
            { $_ -in @("2", "cleanup", "CLEANUP") } {
                $global:OperationMode = "cleanup"
                Write-Info "CLEANUP mode selected - Infrastructure destruction and reset"
                return
            }
            { $_ -in @("3", "status", "STATUS") } {
                $global:OperationMode = "status"
                Write-Info "STATUS mode selected - Deployment status check"
                return
            }
            { $_ -in @("4", "exit", "EXIT") } {
                Write-Info "Operation cancelled by user"
                exit 0
            }
            "" {
                Red "Please select an option (1-4)"
            }
            default {
                Red "Invalid option: '$input'. Please select 1-4."
            }
        }
    }
}

function Get-DebugMode {
    if ($global:OperationMode -eq "deploy" -and !$global:DebugMode) {
        Write-Host ""
        Write-Host -NoNewline -ForegroundColor Yellow "Enable debug mode? (y/N): "
        $debugInput = Read-Host
        
        if ($debugInput -match "^[Yy]$") {
            $global:DebugMode = $true
            Write-Info "Debug mode enabled - verbose output will be shown"
        } else {
            $global:DebugMode = $false
            Write-Info "Standard deployment mode selected"
        }
    }
}
#endregion

#region Changes Tracking
function Add-ChangeTracking {
    param(
        [string]$Action,
        [string]$Target, 
        [string]$Details
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp|$Action|$Target|$Details"
    Add-Content -Path $ChangesLog -Value $entry
    Write-Info "Tracked: $Action $Target"
}
#endregion

#region Module Execution
function Invoke-Module {
    param(
        [string]$ModuleName,
        [string]$ModuleScript,
        [int]$StepNum
    )
    
    Write-Info "[$StepNum/3] Executing $ModuleName..."
    
    # Check if module script exists
    if (!(Test-Path $ModuleScript)) {
        Write-Error "Module script not found: $ModuleScript"
        return $false
    }
    
    # Execute module with output capture
    $moduleLog = Join-Path $LogsDir "${ModuleName}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $startTime = Get-Date
    
    Write-Info "Starting $ModuleName (log: $moduleLog)"
    
    try {
        if ($global:DebugMode) {
            # Interactive mode - run directly with Tee for logging
            & $ModuleScript | Tee-Object -FilePath $moduleLog
        } else {
            # For variables_manager, we need interactive input even in non-debug mode
            if ($ModuleName -eq "variables_manager") {
                & $ModuleScript | Tee-Object -FilePath $moduleLog
            } else {
                & $ModuleScript > $moduleLog 2>&1
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            $duration = (Get-Date) - $startTime
            Write-Success "$ModuleName completed successfully in $($duration.TotalSeconds)s"
            
            # Append module log to master log
            Add-Content -Path $DeploymentLog -Value ""
            Add-Content -Path $DeploymentLog -Value "=== $ModuleName Output ==="
            if (Test-Path $moduleLog) {
                Get-Content $moduleLog | Add-Content -Path $DeploymentLog
            } else {
                Add-Content -Path $DeploymentLog -Value "Module log file not found: $moduleLog"
            }
            Add-Content -Path $DeploymentLog -Value ""
            
            return $true
        } else {
            Write-Error "$ModuleName failed with exit code $LASTEXITCODE"
            Show-ErrorRecovery $ModuleName $moduleLog $LASTEXITCODE
            return $false
        }
    } catch {
        Write-Error "$ModuleName failed with exception: $($_.Exception.Message)"
        Show-ErrorRecovery $ModuleName $moduleLog 1
        return $false
    }
}

function Show-ErrorRecovery {
    param(
        [string]$ModuleName,
        [string]$ErrorLog,
        [int]$ExitCode
    )
    
    Write-Host ""
    Red "❌ $ModuleName FAILED"
    Red "Exit Code: $ExitCode"
    Yellow "Error Log: $ErrorLog"
    Write-Host ""
    
    Cyan "=== ERROR RECOVERY OPTIONS ==="
    
    switch ($ModuleName) {
        "variables_manager" {
            Yellow "1. Check variables.tf file exists and is properly formatted"
            Yellow "2. Ensure PowerShell execution policy allows script execution"
            Yellow "3. Verify user input was provided correctly"
            Yellow "4. Check file permissions on variables.tf"
        }
        "userdata_manager" {
            Yellow "1. Ensure variables.json exists (run variables_manager.ps1 first)"
            Yellow "2. Check server modules exist in modules/ directory"
            Yellow "3. Verify UserData template file exists"
            Yellow "4. Check if UserData exceeds 45KB OpenStack limit"
        }
        "terraform_manager" {
            Yellow "1. Ensure UserData files are generated (run userdata_manager.ps1 first)"
            Yellow "2. Check Terraform is installed and accessible"
            Yellow "3. Verify cloud credentials and connectivity"
            Yellow "4. Check main.tf and provider configuration"
        }
    }
    
    Write-Host ""
    Cyan "=== RECOVERY ACTIONS ==="
    Green "a) Fix the issue and re-run: .\deploy_lab_env.ps1"
    Green "b) Run specific module: .\scripts\$ModuleName.ps1"
    Green "c) View detailed error log: Get-Content $ErrorLog"
    Green "d) Check master log: Get-Content $DeploymentLog"
    Write-Host ""
}

function Show-DeploymentProgress {
    param([int]$CurrentStep)
    
    $totalSteps = 3
    
    Write-Host ""
    Cyan "=== DEPLOYMENT PROGRESS ==="
    Write-Host "Step $CurrentStep of $totalSteps"
    
    switch ($CurrentStep) {
        1 { Write-Host "📊 Variables Processing: Converting variables.tf → variables.json" }
        2 { Write-Host "📄 UserData Generation: Creating server initialization scripts" }
        3 { Write-Host "🏗️ Infrastructure Deployment: Terraform apply to Samsung Cloud Platform v2" }
    }
    
    # Progress bar
    $progress = [math]::Round(($CurrentStep * 100 / $totalSteps), 0)
    $filled = [math]::Round(($progress / 10), 0)
    $empty = 10 - $filled
    
    Write-Host -NoNewline "Progress: ["
    Write-Host -NoNewline ("=" * $filled) -ForegroundColor Green
    Write-Host -NoNewline ("-" * $empty) -ForegroundColor Gray
    Write-Host "] $progress%"
    Write-Host ""
}
#endregion

#region Main Functions
function Invoke-DeploymentPipeline {
    Write-Info "🚀 SAMSUNG CLOUD PLATFORM v2 DEPLOYMENT STARTED"
    
    # Prerequisites validation would go here
    
    # Track deployment start
    Add-ChangeTracking "DEPLOYMENT_START" "infrastructure" "Started deployment process"
    
    # Module execution pipeline
    Show-DeploymentProgress 1
    if (!(Invoke-Module "variables_manager" $VariablesManager 1)) {
        exit 1
    }
    Add-ChangeTracking "CREATE" "variables.json" "Generated from variables.tf"
    
    Show-DeploymentProgress 2
    if (!(Invoke-Module "userdata_manager" $UserdataManager 2)) {
        exit 1
    }
    Add-ChangeTracking "CREATE" "userdata_files" "Generated web/app/db UserData"
    
    Show-DeploymentProgress 3
    if (!(Invoke-Module "terraform_manager" $TerraformManager 3)) {
        exit 1
    }
    Add-ChangeTracking "TERRAFORM_APPLY" "infrastructure" "Infrastructure deployed"
    
    # Deployment completion
    Write-Host ""
    Write-Success "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    
    # Get Web Load Balancer Public IP from Terraform output
    Write-Host ""
    Write-Info "🔍 Retrieving Web Load Balancer Public IP..."
    
    try {
        # Get public IP from terraform output
        $terraformOutput = & terraform output -json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($terraformOutput -and $terraformOutput.web_lb_public_ip) {
            $webLbPublicIP = $terraformOutput.web_lb_public_ip.value
        } else {
            # Fallback: try to get it from terraform state
            $stateOutput = & terraform show -json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($stateOutput) {
                $publicIPResource = $stateOutput.values.root_module.resources | Where-Object { $_.type -eq "samsungcloudplatformv2_vpc_publicip" -and $_.name -eq "pip2" }
                if ($publicIPResource) {
                    $webLbPublicIP = $publicIPResource.values.ip_address
                }
            }
        }
        
        # Load variables for domain information
        if (Test-Path $VariablesJson) {
            $variables = Get-Content $VariablesJson | ConvertFrom-Json
            $publicDomain = $variables.user_input_variables.public_domain_name
        } else {
            $publicDomain = "your-domain.com"
        }
        
        if ($webLbPublicIP) {
            Write-Host ""
            Cyan "================================================================"
            Cyan "🌐 WEB LOAD BALANCER PUBLIC IP INFORMATION"
            Cyan "================================================================"
            Green "Public IP Address: $webLbPublicIP"
            Write-Host ""
            Yellow "📋 DNS CONFIGURATION REQUIRED:"
            Yellow "Please add the following DNS record to your public domain registrar:"
            Write-Host ""
            Write-Host "   Domain: " -NoNewline -ForegroundColor White
            Write-Host "$publicDomain" -ForegroundColor Cyan
            Write-Host "   Record Type: " -NoNewline -ForegroundColor White
            Write-Host "A" -ForegroundColor Green
            Write-Host "   Name: " -NoNewline -ForegroundColor White
            Write-Host "www" -ForegroundColor Green
            Write-Host "   Value: " -NoNewline -ForegroundColor White
            Write-Host "$webLbPublicIP" -ForegroundColor Green
            Write-Host "   TTL: " -NoNewline -ForegroundColor White
            Write-Host "300 (or default)" -ForegroundColor Green
            Write-Host ""
            Yellow "After DNS propagation, your website will be accessible at:"
            Green "   http://www.$publicDomain"
            Write-Host ""
            Cyan "================================================================"
        } else {
            Yellow "⚠️  Could not retrieve Web Load Balancer Public IP automatically."
            Yellow "   Check terraform output manually: terraform output web_lb_public_ip"
        }
    } catch {
        Yellow "⚠️  Error retrieving Public IP: $($_.Exception.Message)"
        Yellow "   Check terraform output manually: terraform output web_lb_public_ip"
    }
    
    Write-Host ""
    
    # Final status
    Write-Info "📊 Final Status:"
    Write-Info "  - Variables: $VariablesJson"
    Write-Info "  - UserData: $ScriptsDir\generated_userdata\"
    Write-Info "  - Lab Logs: $LogsDir\"
    Write-Info "  - Master Log: $DeploymentLog"
}

function Invoke-Cleanup {
    # Cleanup implementation would go here
    Write-Info "🧹 CLEANUP functionality not yet implemented"
}

function Show-Status {
    # Status implementation would go here
    Write-Info "📊 STATUS functionality not yet implemented"
}

function Main {
    # Initialize environment
    Initialize-DeploymentEnvironment
    Initialize-ChangesTracking
    Show-MainBanner
    Get-OperationMode
    Get-DebugMode
    
    # Execute based on operation mode
    switch ($global:OperationMode) {
        "deploy" { Invoke-DeploymentPipeline }
        "cleanup" { Invoke-Cleanup }
        "status" { Show-Status }
    }
    
    Green "🚀 Samsung Cloud Platform v2 operation completed at $(Get-Date)"
}
#endregion

# Export environment variables for child processes
$env:DEBUG_MODE = $global:DebugMode.ToString().ToLower()

# Run main function
Main