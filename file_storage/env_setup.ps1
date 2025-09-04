# Samsung Cloud Platform v2 - Master Controller & Deployment Orchestrator
# Version: 4.0 (PowerShell implementation with proper data flow and monitoring)
# 
# MASTER CONTROLLER RESPONSIBILITIES:
# 1. Module Integration & Control: variables_manager -> userdata_manager (Terraform manual execution)
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

# Operation mode
$global:OperationMode = ""
$global:DebugMode = $true  # Always use debug mode

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
    if (Test-Path (Split-Path $DeploymentLog -Parent)) {
        Add-Content -Path $DeploymentLog -Value $logEntry -ErrorAction SilentlyContinue
    }
}

function Write-Info($message) { Write-LogMessage "INFO" $message }
function Write-Success($message) { 
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
    if (Test-Path (Split-Path $DeploymentLog -Parent)) {
        Add-Content -Path $DeploymentLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] $message" -ErrorAction SilentlyContinue
    }
}
function Write-Error($message) { 
    Write-Host "[ERROR] $message" -ForegroundColor Red
    if (Test-Path (Split-Path $DeploymentLog -Parent)) {
        Add-Content -Path $DeploymentLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] $message" -ErrorAction SilentlyContinue
    }
}
function Write-Warning($message) { 
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
    if (Test-Path (Split-Path $DeploymentLog -Parent)) {
        Add-Content -Path $DeploymentLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [WARNING] $message" -ErrorAction SilentlyContinue
    }
}
#endregion

#region Setup Functions
# Scan for previous deployment status markers
function Test-PreviousDeploymentStatus {
    Write-Info "🔍 Scanning for previous deployment attempts..."
    
    # Create archive directory if it doesn't exist
    $archiveDir = Join-Path $LogsDir "archive"
    if (!(Test-Path $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }
    
    # Find status markers
    $statusMarkers = @(Get-ChildItem -Path $LogsDir -Name "deployment_*_*.marker" -ErrorAction SilentlyContinue)
    
    if ($statusMarkers.Count -gt 0) {
        $latestMarker = $statusMarkers | Sort-Object Name -Descending | Select-Object -First 1
        $markerPath = Join-Path $LogsDir $latestMarker
        
        try {
            $markerData = Get-Content $markerPath | ConvertFrom-Json
            $status = $markerData.Status
            $timestamp = $markerData.Timestamp
            
            Write-Host ""
            if ($status -eq "SUCCESS") {
                Write-Host "✅ " -NoNewline -ForegroundColor Green
                Write-Host "Previous deployment attempt SUCCEEDED" -ForegroundColor Green
            } else {
                Write-Host "❌ " -NoNewline -ForegroundColor Red  
                Write-Host "Previous deployment attempt FAILED" -ForegroundColor Red
            }
            Write-Host "   Timestamp: $timestamp" -ForegroundColor Gray
            Write-Host "   Log files:" -ForegroundColor Gray
            Write-Host "     - Terraform: $(Split-Path -Leaf $markerData.TerraformLog)" -ForegroundColor Gray
            Write-Host "     - Provider: $(Split-Path -Leaf $markerData.ProviderLog)" -ForegroundColor Gray
            Write-Host "     - Execution: $(Split-Path -Leaf $markerData.ExecutionLog)" -ForegroundColor Gray
            Write-Host ""
            
            # Prompt user for action
            Write-Host "Would you like to clean up previous logs?" -ForegroundColor Yellow
            Write-Host "  Y - Delete status marker and associated log files" -ForegroundColor White
            Write-Host "  N - Keep marker but move log files to archive" -ForegroundColor White
            Write-Host ""
            
            do {
                $response = Read-Host "Delete existing logs? (Y/N)"
                $response = $response.Trim().ToUpper()
                
                if ($response -eq "Y" -or $response -eq "YES") {
                    # Delete marker and associated logs
                    Write-Info "Deleting status marker and associated log files..."
                    
                    Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
                    Remove-Item $markerData.TerraformLog -Force -ErrorAction SilentlyContinue
                    Remove-Item $markerData.ProviderLog -Force -ErrorAction SilentlyContinue  
                    Remove-Item $markerData.ExecutionLog -Force -ErrorAction SilentlyContinue
                    
                    Write-Success "Previous deployment logs deleted successfully"
                    break
                }
                elseif ($response -eq "N" -or $response -eq "NO") {
                    # Archive logs and delete marker
                    Write-Info "Moving log files to archive and removing status marker..."
                    
                    # Move logs to archive
                    $archiveTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    Move-Item $markerData.TerraformLog "$archiveDir\terraform_debug_archived_$archiveTimestamp.log" -Force -ErrorAction SilentlyContinue
                    Move-Item $markerData.ProviderLog "$archiveDir\provider_api_archived_$archiveTimestamp.log" -Force -ErrorAction SilentlyContinue
                    Move-Item $markerData.ExecutionLog "$archiveDir\terraform_execution_archived_$archiveTimestamp.log" -Force -ErrorAction SilentlyContinue
                    
                    # Remove marker
                    Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
                    
                    Write-Success "Logs archived to: $archiveDir"
                    Write-Success "Status marker removed"
                    break
                }
                else {
                    Write-Host "Please enter Y or N" -ForegroundColor Red
                }
            } while ($true)
            
            Write-Host ""
        }
        catch {
            Write-Warning "Could not read status marker: $markerPath"
            Write-Warning "Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Info "No previous deployment status markers found"
    }
}

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
File Storage Lab Environment
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
    Cyan "File Storage Integration with Dynamic Configuration"
    Cyan "========================================================"
    Write-Host ""
    Write-Host "Choose Operation Mode:" -ForegroundColor White -BackgroundColor Black
    Write-Host ""
    Green "1. NORMALIZE - Normalize the variables across infrastructure and application"
    Write-Host "   • Variables processing → UserData generation → Prepare for Terraform"
    Write-Host ""
    Yellow "2. RESET     - Reset to initial values and clean the logs"
    Write-Host "   • Reset user input variables → Clean generated files → Clear logs"
    Write-Host ""
    Red "3. EXIT      - Exit the application"
    Write-Host ""
}

function Get-OperationMode {
    while ($true) {
        Write-Host -NoNewline -ForegroundColor Cyan "Select option (1-3): "
        $input = Read-Host
        
        switch ($input) {
            { $_ -in @("1", "normalize", "NORMALIZE") } {
                $global:OperationMode = "normalize"
                Write-Info "NORMALIZE mode selected - Variables and UserData preparation"
                return
            }
            { $_ -in @("2", "reset", "RESET") } {
                $global:OperationMode = "reset"
                Write-Info "RESET mode selected - Reset to initial values and clean logs"
                return
            }
            { $_ -in @("3", "exit", "EXIT") } {
                Write-Info "Exiting application..."
                exit 0
            }
            "" {
                Red "Please select an option (1-3)"
            }
            default {
                Red "Invalid option: '$input'. Please select 1, 2, or 3."
            }
        }
    }
}

function Get-DebugMode {
    # Always use debug mode - no user prompt needed
    $global:DebugMode = $true
    Write-Info "Debug mode enabled - verbose output will be shown"
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
    if (Test-Path (Split-Path $ChangesLog -Parent)) {
        Add-Content -Path $ChangesLog -Value $entry -ErrorAction SilentlyContinue
    }
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
            # Debug mode - run directly with real-time output and logging
            & $ModuleScript 2>&1 | ForEach-Object { 
                Write-Host $_
                $_ | Out-File -Append -FilePath $moduleLog -Encoding UTF8
            }
        } else {
            # For variables_manager, we need real-time output
            if ($ModuleName -eq "variables_manager") {
                & $ModuleScript 2>&1 | ForEach-Object { 
                    Write-Host $_
                    $_ | Out-File -Append -FilePath $moduleLog -Encoding UTF8
                }
            } else {
                & $ModuleScript > $moduleLog 2>&1
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            $duration = (Get-Date) - $startTime
            Write-Success "$ModuleName completed successfully in $($duration.TotalSeconds)s"
            
            # Append module log to master log
            if (Test-Path (Split-Path $DeploymentLog -Parent)) {
                Add-Content -Path $DeploymentLog -Value "" -ErrorAction SilentlyContinue
                Add-Content -Path $DeploymentLog -Value "=== $ModuleName Output ===" -ErrorAction SilentlyContinue
                if (Test-Path $moduleLog) {
                    Get-Content $moduleLog | Add-Content -Path $DeploymentLog -ErrorAction SilentlyContinue
                } else {
                    Add-Content -Path $DeploymentLog -Value "Module log file not found: $moduleLog" -ErrorAction SilentlyContinue
                }
                Add-Content -Path $DeploymentLog -Value "" -ErrorAction SilentlyContinue
            }
            
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
    }
    
    Write-Host ""
    Cyan "=== RECOVERY ACTIONS ==="
    Green "a) Fix the issue and re-run: .\env_setup.ps1"
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
function Invoke-NormalizationPipeline {
    Write-Info "🚀 SAMSUNG CLOUD PLATFORM v2 FILE STORAGE NORMALIZATION STARTED"
    
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
    
    # Preparation completion
    Write-Host ""
    Write-Success "🎉 NORMALIZATION COMPLETED SUCCESSFULLY!"
    
    Write-Host ""
    
    # Final status
    Write-Info "📊 Final Status:"
    Write-Info "  - Variables: $VariablesJson"
    Write-Info "  - UserData: $ScriptsDir\generated_userdata\"
    Write-Info "  - Lab Logs: $LogsDir\"
    Write-Info "  - Master Log: $DeploymentLog"
    
    # Show next steps for manual Terraform execution
    Write-Host ""
    Cyan "=== NEXT STEPS: MANUAL TERRAFORM EXECUTION ==="
    Write-Host ""
    
    Write-Host "All preparation completed. Now execute Terraform commands manually:" -ForegroundColor Green
    Write-Host ""
    
    Yellow "📋 TERRAFORM COMMAND SEQUENCE:"
    Write-Host ""
    
    Write-Host "1. Initialize Terraform:" -ForegroundColor White
    Write-Host "   terraform init" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "2. Validate configuration:" -ForegroundColor White  
    Write-Host "   terraform validate" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "3. Create execution plan:" -ForegroundColor White
    Write-Host "   terraform plan" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "4. Apply infrastructure:" -ForegroundColor White
    Write-Host "   terraform apply" -ForegroundColor Cyan
    Write-Host ""
    
    Yellow "📁 GENERATED FILES READY:"
    Write-Host ""
    Write-Host "• Variables: scripts/generated_userdata/variables.json" -ForegroundColor White
    Write-Host "• Web UserData: scripts/generated_userdata/userdata_web.sh" -ForegroundColor White  
    Write-Host "• App UserData: scripts/generated_userdata/userdata_app.sh" -ForegroundColor White
    Write-Host "• Emergency Scripts: scripts/emergency_scripts/" -ForegroundColor White
    Write-Host ""
    
    Yellow "🔧 USEFUL COMMANDS AFTER DEPLOYMENT:"
    Write-Host ""
    Write-Host "• Get outputs: terraform output" -ForegroundColor Cyan
    Write-Host "• Get web IP: terraform output web_lb_public_ip" -ForegroundColor Cyan
    Write-Host "• View state: terraform show" -ForegroundColor Cyan
    Write-Host "• Destroy all: terraform destroy" -ForegroundColor Cyan
}

function Move-LegacyTerraformFiles {
    Write-Info "🔄 Checking for legacy Terraform files in main directory..."
    
    # Ensure lab_logs directory exists
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    $movedFiles = 0
    
    # Move plan files
    $legacyPlanFiles = @(Get-ChildItem -Path $ScriptDir -Name "*.tfplan" -ErrorAction SilentlyContinue)
    foreach ($file in $legacyPlanFiles) {
        $sourcePath = Join-Path $ScriptDir $file
        $destPath = Join-Path $LogsDir $file
        Move-Item $sourcePath $destPath -Force
        Write-Info "Moved plan file: $file → lab_logs/"
        $movedFiles++
    }
    
    # Move terraform state backup files
    $legacyStateBackups = @(Get-ChildItem -Path $ScriptDir -Name "terraform.tfstate.backup*" -ErrorAction SilentlyContinue)
    foreach ($file in $legacyStateBackups) {
        $sourcePath = Join-Path $ScriptDir $file
        $destPath = Join-Path $LogsDir $file
        Move-Item $sourcePath $destPath -Force
        Write-Info "Moved state backup: $file → lab_logs/"
        $movedFiles++
    }
    
    # Move variables.tf backup files
    $legacyVarBackups = @(Get-ChildItem -Path $ScriptDir -Name "variables.tf.backup*" -ErrorAction SilentlyContinue)
    foreach ($file in $legacyVarBackups) {
        $sourcePath = Join-Path $ScriptDir $file
        $destPath = Join-Path $LogsDir $file
        Move-Item $sourcePath $destPath -Force
        Write-Info "Moved variables backup: $file → lab_logs/"
        $movedFiles++
    }
    
    if ($movedFiles -gt 0) {
        Write-Success "✅ Moved $movedFiles legacy Terraform files to lab_logs directory"
        Add-ChangeTracking "MOVE" "legacy_terraform_files" "Moved $movedFiles files to lab_logs"
    } else {
        Write-Info "No legacy Terraform files found in main directory"
    }
}

function Invoke-Cleanup {
    Write-Info "🧹 SAMSUNG CLOUD PLATFORM v2 CLEANUP STARTED"
    Write-Host ""
    
    # Track cleanup start
    Add-ChangeTracking "CLEANUP_START" "infrastructure" "Started cleanup process"
    
    # Step 0: Move legacy Terraform files to lab_logs directory
    Move-LegacyTerraformFiles
    
    # Step 1: Terraform Destroy
    Write-Host ""
    Cyan "================================================================"
    Cyan "STEP 1: TERRAFORM INFRASTRUCTURE DESTRUCTION"
    Cyan "================================================================"
    
    # Check if terraform state exists
    $terraformStateExists = Test-Path "terraform.tfstate"
    $terraformStateBackupExists = Test-Path "terraform.tfstate.backup"
    
    if ($terraformStateExists -or $terraformStateBackupExists) {
        Write-Warning "⚠️  Terraform state files detected. This will DESTROY all infrastructure!"
        Write-Host ""
        Write-Host "The following will be destroyed:" -ForegroundColor Red
        Write-Host "  • All virtual machines (Web, App, Database servers)" -ForegroundColor Red
        Write-Host "  • Load balancers and networking components" -ForegroundColor Red
        Write-Host "  • Security groups and firewall rules" -ForegroundColor Red
        Write-Host "  • Public IPs and floating IPs" -ForegroundColor Red
        Write-Host "  • All storage volumes and snapshots" -ForegroundColor Red
        Write-Host ""
        
        Write-Host "⚠️  THIS ACTION CANNOT BE UNDONE!" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host ""
        
        do {
            Write-Host -NoNewline -ForegroundColor Yellow "Are you sure you want to destroy the infrastructure? (yes/no): "
            $destroyConfirm = Read-Host
            $destroyConfirm = $destroyConfirm.Trim().ToLower()
            
            if ($destroyConfirm -eq "yes") {
                Write-Info "🗂️  Starting Terraform destroy process..."
                
                # Create destroy log
                $destroyLog = Join-Path $LogsDir "terraform_destroy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                $destroyStartTime = Get-Date
                
                try {
                    Write-Info "Running: terraform destroy -auto-approve"
                    Write-Info "Destroy log: $destroyLog"
                    
                    # Run terraform destroy
                    terraform destroy -auto-approve *> $destroyLog
                    $destroyExitCode = $LASTEXITCODE
                    
                    if ($destroyExitCode -eq 0) {
                        $destroyDuration = (Get-Date) - $destroyStartTime
                        Write-Success "✅ Terraform destroy completed successfully in $($destroyDuration.TotalMinutes.ToString('F1')) minutes"
                        Add-ChangeTracking "TERRAFORM_DESTROY" "infrastructure" "Infrastructure destroyed successfully"
                        
                        # Clean up terraform state files
                        if (Test-Path "terraform.tfstate") {
                            Remove-Item "terraform.tfstate" -Force
                            Write-Info "Removed terraform.tfstate"
                        }
                        if (Test-Path "terraform.tfstate.backup") {
                            Remove-Item "terraform.tfstate.backup" -Force  
                            Write-Info "Removed terraform.tfstate.backup"
                        }
                        if (Test-Path ".terraform.lock.hcl") {
                            Remove-Item ".terraform.lock.hcl" -Force
                            Write-Info "Removed .terraform.lock.hcl"
                        }
                    } else {
                        Write-Error "❌ Terraform destroy failed with exit code $destroyExitCode"
                        Write-Error "Check destroy log: $destroyLog"
                        Write-Host ""
                        Write-Host "Common solutions:" -ForegroundColor Yellow
                        Write-Host "  • Check cloud provider credentials" -ForegroundColor Yellow
                        Write-Host "  • Verify network connectivity" -ForegroundColor Yellow
                        Write-Host "  • Some resources may need manual cleanup" -ForegroundColor Yellow
                        return
                    }
                } catch {
                    Write-Error "❌ Error running terraform destroy: $($_.Exception.Message)"
                    Write-Error "Check destroy log: $destroyLog"
                    return
                }
                break
            }
            elseif ($destroyConfirm -eq "no") {
                Write-Info "Terraform destroy cancelled by user"
                Write-Info "Proceeding to file cleanup options..."
                break
            }
            else {
                Write-Host "Please enter 'yes' or 'no'" -ForegroundColor Red
            }
        } while ($true)
    } else {
        Write-Info "No terraform state files found - skipping infrastructure destruction"
    }
    
    # Step 2: File and Log Cleanup Options
    Write-Host ""
    Cyan "================================================================"
    Cyan "STEP 2: FILE AND LOG CLEANUP OPTIONS"
    Cyan "================================================================"
    
    # Inventory cleanup targets
    $cleanupTargets = @()
    
    # Log files (preserve lab_logs directory structure)
    if (Test-Path $LogsDir) {
        $logFiles = @(Get-ChildItem -Path $LogsDir -File -Recurse)
        if ($logFiles.Count -gt 0) {
            $cleanupTargets += @{
                Name = "Log Files (Preserve Directory)"
                Path = $LogsDir
                Files = $logFiles
                Description = "Deployment logs, terraform logs, module execution logs (keeps lab_logs folder)"
                PreserveDirectory = $true
            }
        }
    }
    
    # Generated UserData files - PROTECTED - DO NOT CLEAN
    # $userdataDir = Join-Path $ScriptsDir "generated_userdata"
    # These files are preserved to avoid regeneration requirements
    
    # Variables JSON file - PROTECTED - DO NOT CLEAN
    # if (Test-Path $VariablesJson) {
    # This file is preserved to avoid regeneration requirements
    
    # Changes tracking log
    if (Test-Path $ChangesLog) {
        $cleanupTargets += @{
            Name = "Changes Tracking Log"
            Path = $ChangesLog
            Files = @(Get-Item $ChangesLog)
            Description = "Record of all deployment changes"
        }
    }
    
    # Terraform plan files (now stored in lab_logs)
    $planFiles = @(Get-ChildItem -Path $LogsDir -Name "*.tfplan" -ErrorAction SilentlyContinue)
    if ($planFiles.Count -gt 0) {
        $cleanupTargets += @{
            Name = "Terraform Plan Files"
            Path = $LogsDir
            Files = $planFiles | ForEach-Object { Get-Item (Join-Path $LogsDir $_) }
            Description = "Terraform execution plans"
        }
    }
    
    # Terraform state backup files (now stored in lab_logs)
    $stateBackupFiles = @(Get-ChildItem -Path $LogsDir -Name "terraform.tfstate.backup*" -ErrorAction SilentlyContinue)
    if ($stateBackupFiles.Count -gt 0) {
        $cleanupTargets += @{
            Name = "Terraform State Backup Files"
            Path = $LogsDir
            Files = $stateBackupFiles | ForEach-Object { Get-Item (Join-Path $LogsDir $_) }
            Description = "Terraform state backup files"
        }
    }
    
    # Variables.tf backup files (now stored in lab_logs)
    $variablesBackupFiles = @(Get-ChildItem -Path $LogsDir -Name "variables.tf.backup*" -ErrorAction SilentlyContinue)
    if ($variablesBackupFiles.Count -gt 0) {
        $cleanupTargets += @{
            Name = "Variables.tf Backup Files"
            Path = $LogsDir
            Files = $variablesBackupFiles | ForEach-Object { Get-Item (Join-Path $LogsDir $_) }
            Description = "Variables.tf backup files"
        }
    }
    
    # .terraform directory
    $terraformDir = Join-Path $ScriptDir ".terraform"
    if (Test-Path $terraformDir) {
        $terraformFiles = @(Get-ChildItem -Path $terraformDir -Recurse)
        if ($terraformFiles.Count -gt 0) {
            $cleanupTargets += @{
                Name = "Terraform Cache Directory"
                Path = $terraformDir
                Files = $terraformFiles
                Description = "Provider plugins and modules cache"
            }
        }
    }
    
    if ($cleanupTargets.Count -eq 0) {
        Write-Info "No cleanup targets found - all files are already clean"
    } else {
        Write-Info "Found $($cleanupTargets.Count) cleanup target(s):"
        Write-Host ""
        
        for ($i = 0; $i -lt $cleanupTargets.Count; $i++) {
            $target = $cleanupTargets[$i]
            Write-Host "  $($i + 1). $($target.Name)" -ForegroundColor Cyan
            Write-Host "     Path: $($target.Path)" -ForegroundColor Gray
            Write-Host "     Files: $(@($target.Files).Count)" -ForegroundColor Gray
            Write-Host "     Description: $($target.Description)" -ForegroundColor Gray
            Write-Host ""
        }
        
        # Cleanup options menu
        Write-Host ""
        Write-Host "Choose cleanup option:" -ForegroundColor White -BackgroundColor Black
        Write-Host ""
        Green "A. CLEAN ALL     - Remove all temporary files and logs"
        Yellow "S. SELECTIVE     - Choose specific items to clean"
        Blue "K. KEEP LOGS     - Clean generated files but keep logs for review"
        Red "N. NO CLEANUP    - Keep all files (exit cleanup)"
        Write-Host ""
        
        do {
            Write-Host -NoNewline -ForegroundColor Cyan "Select cleanup option (A/S/K/N): "
            $cleanupChoice = Read-Host
            $cleanupChoice = $cleanupChoice.Trim().ToUpper()
            
            switch ($cleanupChoice) {
                "A" {
                    # Clean all
                    Write-Info "🗑️  Cleaning all temporary files and logs..."
                    foreach ($target in $cleanupTargets) {
                        Remove-CleanupTarget $target
                    }
                    Write-Success "✅ All cleanup targets removed"
                    break
                }
                "S" {
                    # Selective cleanup
                    Write-Info "🎯 Selective cleanup mode"
                    Write-Host ""
                    
                    foreach ($target in $cleanupTargets) {
                        Write-Host ""
                        Write-Host "Clean $($target.Name)?" -ForegroundColor Yellow
                        Write-Host "  Path: $($target.Path)" -ForegroundColor Gray
                        Write-Host "  Files: $(@($target.Files).Count)" -ForegroundColor Gray
                        
                        do {
                            Write-Host -NoNewline -ForegroundColor Cyan "Remove this item? (y/n): "
                            $itemChoice = Read-Host
                            $itemChoice = $itemChoice.Trim().ToLower()
                            
                            if ($itemChoice -eq "y" -or $itemChoice -eq "yes") {
                                Remove-CleanupTarget $target
                                break
                            }
                            elseif ($itemChoice -eq "n" -or $itemChoice -eq "no") {
                                Write-Info "Skipped $($target.Name)"
                                break
                            }
                            else {
                                Write-Host "Please enter 'y' or 'n'" -ForegroundColor Red
                            }
                        } while ($true)
                    }
                    Write-Success "✅ Selective cleanup completed"
                    break
                }
                "K" {
                    # Keep logs, clean generated files
                    Write-Info "📋 Keeping logs, cleaning generated files..."
                    foreach ($target in $cleanupTargets) {
                        if ($target.Name -notlike "*Log*") {
                            Remove-CleanupTarget $target
                        } else {
                            Write-Info "Preserved $($target.Name)"
                        }
                    }
                    Write-Success "✅ Generated files cleaned, logs preserved"
                    break
                }
                "N" {
                    Write-Info "No cleanup performed - all files preserved"
                    break
                }
                default {
                    Write-Host "Invalid option. Please select A, S, K, or N" -ForegroundColor Red
                }
            }
        } while ($cleanupChoice -notin @("A", "S", "K", "N"))
    }
    
    # Step 3: Reset Configuration
    Write-Host ""
    Cyan "================================================================"
    Cyan "STEP 3: CONFIGURATION RESET"
    Cyan "================================================================"
    
    Write-Host ""
    Write-Host "Reset configuration to initial state?" -ForegroundColor Yellow
    Write-Host "This will:" -ForegroundColor Gray
    Write-Host "  • Keep original variables.tf file intact" -ForegroundColor Gray
    Write-Host "  • Remove any deployment status markers" -ForegroundColor Gray
    Write-Host "  • Reset environment for fresh deployment" -ForegroundColor Gray
    Write-Host ""
    
    do {
        Write-Host -NoNewline -ForegroundColor Cyan "Reset configuration? (y/n): "
        $resetChoice = Read-Host
        $resetChoice = $resetChoice.Trim().ToLower()
        
        if ($resetChoice -eq "y" -or $resetChoice -eq "yes") {
            # Remove deployment status markers
            $statusMarkers = Get-ChildItem -Path $LogsDir -Name "deployment_*_*.marker" -ErrorAction SilentlyContinue
            foreach ($marker in $statusMarkers) {
                $markerPath = Join-Path $LogsDir $marker
                Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
                Write-Info "Removed status marker: $marker"
            }
            
            # Reset any other configuration as needed
            Write-Success "✅ Configuration reset to initial state"
            Add-ChangeTracking "CONFIGURATION_RESET" "environment" "Reset to initial deployment state"
            break
        }
        elseif ($resetChoice -eq "n" -or $resetChoice -eq "no") {
            Write-Info "Configuration reset skipped"
            break
        }
        else {
            Write-Host "Please enter 'y' or 'n'" -ForegroundColor Red
        }
    } while ($true)
    
    # Cleanup completion
    Write-Host ""
    Add-ChangeTracking "CLEANUP_COMPLETE" "environment" "Cleanup process completed"
    
    Cyan "================================================================"
    Write-Success "🎉 CLEANUP PROCESS COMPLETED!"
    Cyan "================================================================"
    Write-Host ""
    Write-Info "📊 Cleanup Summary:"
    Write-Info "  ✅ Infrastructure destruction: $(if ($terraformStateExists -or $terraformStateBackupExists) { 'Processed' } else { 'Not needed' })"
    Write-Info "  ✅ File cleanup: Completed based on user selection"
    Write-Info "  ✅ Configuration reset: Completed"
    Write-Host ""
    Write-Info "Environment is ready for fresh deployment"
}

function Remove-CleanupTarget {
    param($Target)
    
    try {
        if (Test-Path $Target.Path) {
            # Check if this target should preserve directory structure
            if ($Target.PSObject.Properties.Name -contains "PreserveDirectory" -and $Target.PreserveDirectory -eq $true) {
                # Preserve directory structure - remove only individual files
                $filesRemoved = 0
                foreach ($file in $Target.Files) {
                    if (Test-Path $file.FullName) {
                        Remove-Item -Path $file.FullName -Force
                        $filesRemoved++
                    }
                }
                Write-Info "Cleaned $filesRemoved files from directory, preserved: $($Target.Name)"
                Add-ChangeTracking "CLEAN_FILES" $Target.Path "Cleaned $filesRemoved files, preserved directory structure"
            } elseif ((Get-Item $Target.Path).PSIsContainer) {
                # Directory - remove entirely
                Remove-Item -Path $Target.Path -Recurse -Force
                Write-Info "Removed directory: $($Target.Name)"
                Add-ChangeTracking "DELETE" $Target.Path "Cleaned up during reset"
            } else {
                # File
                Remove-Item -Path $Target.Path -Force
                Write-Info "Removed file: $($Target.Name)"
                Add-ChangeTracking "DELETE" $Target.Path "Cleaned up during reset"
            }
        } else {
            Write-Warning "Path not found (already removed): $($Target.Path)"
        }
    } catch {
        Write-Error "Failed to remove $($Target.Name): $($_.Exception.Message)"
    }
}

function Show-Status {
    # Status implementation would go here
    Write-Info "📊 STATUS functionality not yet implemented"
}

function Invoke-Reset {
    Write-Info "🔄 SAMSUNG CLOUD PLATFORM v2 RESET STARTED"
    Write-Host ""
    
    # Track reset start
    Add-ChangeTracking "RESET_START" "variables" "Started variables reset process"
    
    Write-Host ""
    Cyan "================================================================"
    Cyan "RESET USER INPUT VARIABLES TO DEFAULT VALUES"
    Cyan "================================================================"
    
    Write-Host ""
    Write-Warning "⚠️  This will reset all user input variables in variables.tf to their default values!"
    Write-Host ""
    Write-Host "This will reset the following variables:" -ForegroundColor Yellow
    Write-Host "  • private_domain_name → 'your_internal.local'" -ForegroundColor Gray
    Write-Host "  • private_hosted_zone_id → 'your_private_hosted_zone_id'" -ForegroundColor Gray
    Write-Host "  • public_domain_name → 'yourdomain.com'" -ForegroundColor Gray
    Write-Host "  • keypair_name → 'mykey'" -ForegroundColor Gray
    Write-Host "  • user_public_ip → 'your_public_ip/32'" -ForegroundColor Gray
    Write-Host "  • Object storage credentials → default placeholder values" -ForegroundColor Gray
    Write-Host ""
    Write-Host "A backup will be created in lab_logs/ before making changes." -ForegroundColor Green
    Write-Host ""
    
    do {
        Write-Host -NoNewline -ForegroundColor Red "To confirm reset, type 'delete' or '0' to return to main menu: "
        $resetConfirm = Read-Host
        $resetConfirm = $resetConfirm.Trim()
        
        if ($resetConfirm -eq "0") {
            Write-Info "Returning to main menu..."
            return "return_to_menu"
        }
        elseif ($resetConfirm -eq "delete") {
            Write-Info "🔄 Starting variables reset process..."
            
            # Call variables_manager in reset mode (no user interaction)
            $resetScript = Join-Path $ScriptsDir "variables_manager.ps1"
            & $resetScript -Reset 2>&1 | ForEach-Object { 
                Write-Host $_
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✅ Variables reset completed successfully!"
                Add-ChangeTracking "RESET_COMPLETE" "variables" "User input variables reset to defaults"
            } else {
                Write-Error "❌ Variables reset failed!"
                Add-ChangeTracking "RESET_FAILED" "variables" "Reset process failed"
                return "failed"
            }
            break
        }
        else {
            Write-Host "Please type 'delete' to confirm or '0' to return to main menu" -ForegroundColor Red
        }
    } while ($true)
    
    # Ask about cleaning logs 
    Write-Host ""
    Yellow "🗂️  STEP 2: LOG CLEANUP"
    Write-Host ""
    Write-Host "Clean deployment logs and backups:" -ForegroundColor White
    Write-Host "• lab_logs/ - All deployment logs and backups" -ForegroundColor Gray
    Write-Host ""
    
    $logsCleanup = $false
    do {
        Write-Host -NoNewline -ForegroundColor Red "Clean logs? Type 'delete' or 'N' to skip: "
        $logsConfirm = Read-Host
        $logsConfirm = $logsConfirm.Trim().ToUpper()
        
        if ($logsConfirm -eq "DELETE") {
            Write-Info "🗑️ Cleaning up logs..."
            $logsCleanup = $true
            
            # Clean lab_logs directory
            if (Test-Path $LogsDir) {
                Remove-Item -Path $LogsDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Removed lab_logs/ directory"
            } else {
                Write-Info "No lab_logs/ directory found"
            }
            break
        }
        elseif ($logsConfirm -eq "N") {
            Write-Info "Skipping logs cleanup"
            break
        }
        else {
            Write-Host "Please type 'delete' or 'N'" -ForegroundColor Red
        }
    } while ($true)
    
    # Ask about cleaning Terraform files
    Write-Host ""
    Yellow "🗂️  STEP 3: TERRAFORM FILES CLEANUP"
    Write-Host ""
    Write-Host "Clean Terraform state and initialization files:" -ForegroundColor White
    Write-Host "• .terraform/ - Terraform initialization directory" -ForegroundColor Gray
    Write-Host "• terraform.tfstate* - Terraform state files and backups" -ForegroundColor Gray  
    Write-Host "• .terraform.lock.hcl - Terraform lock file" -ForegroundColor Gray
    Write-Host "• *.tfplan - Terraform plan files" -ForegroundColor Gray
    Write-Host ""
    
    do {
        Write-Host -NoNewline -ForegroundColor Red "Clean Terraform files? Type 'delete' or 'N' to skip: "
        $terraformConfirm = Read-Host
        $terraformConfirm = $terraformConfirm.Trim().ToUpper()
        
        if ($terraformConfirm -eq "DELETE") {
            Write-Info "🗑️ Cleaning up Terraform files..."
            
            # Clean Terraform files in project directory
            $terraformFiles = @(
                ".terraform",
                "terraform.tfstate", 
                "terraform.tfstate.backup",
                "terraform.tfstate.backup.*",
                ".terraform.lock.hcl",
                ".terraform.tfstate.lock.info",
                "*.tfplan"
            )
            
            $cleanedCount = 0
            
            # Handle .terraform directory separately (direct path check)
            $terraformDir = Join-Path $ScriptDir ".terraform"
            if (Test-Path $terraformDir) {
                Remove-Item -Path $terraformDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Removed .terraform/"
                $cleanedCount++
            }
            
            # Handle other terraform files with patterns
            $filePatterns = @(
                "terraform.tfstate", 
                "terraform.tfstate.backup",
                "terraform.tfstate.backup.*",
                ".terraform.lock.hcl",
                ".terraform.tfstate.lock.info",
                "*.tfplan"
            )
            
            foreach ($pattern in $filePatterns) {
                $files = Get-ChildItem -Path $ScriptDir -Name $pattern -Force -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $fullPath = Join-Path $ScriptDir $file
                    if (Test-Path $fullPath) {
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        Write-Success "Removed $file"
                        $cleanedCount++
                    }
                }
            }
            
            if ($cleanedCount -eq 0) {
                Write-Info "No Terraform files found to clean"
            } else {
                Write-Success "Cleaned up $cleanedCount Terraform files/directories"
            }
            break
        }
        elseif ($terraformConfirm -eq "N") {
            Write-Info "Skipping Terraform files cleanup"
            break
        }
        else {
            Write-Host "Please type 'delete' or 'N'" -ForegroundColor Red
        }
    } while ($true)
    
    Write-Host ""
    Cyan "================================================================"
    Write-Success "🎉 RESET PROCESS COMPLETED!"
    Cyan "================================================================"
    
    Write-Host ""
    Write-Host -NoNewline -ForegroundColor Yellow "Press any key to return to main menu... "
    $null = Read-Host
    
    return "return_to_menu"
    Write-Host ""
    Write-Info "📊 Reset Summary:"
    Write-Info "  ✅ variables.tf reset to default values"
    Write-Info "  ✅ Backup created in lab_logs/"
    Write-Info "  ✅ Ready for fresh variable configuration"
    Write-Host ""
    Write-Info "Next steps:"
    Write-Info "  1. Run DEPLOY mode to configure variables interactively"
    Write-Info "  2. Or manually edit variables.tf with your values"
}

function Main {
    # Initialize environment
    Initialize-DeploymentEnvironment
    Initialize-ChangesTracking
    
    # Check for previous deployment status before showing main banner
    Test-PreviousDeploymentStatus
    
    # Main menu loop
    while ($true) {
        Show-MainBanner
        Get-OperationMode
        Get-DebugMode
        
        # Execute based on operation mode
        $result = switch ($global:OperationMode) {
            "normalize" { 
                Invoke-NormalizationPipeline
                return "completed"
            }
            "reset" { 
                Invoke-Reset 
            }
        }
        
        # Handle reset result
        if ($result -ne "return_to_menu") {
            break
        }
        
        # Clear operation mode for next iteration
        $global:OperationMode = ""
    }
    
    Green "🚀 Samsung Cloud Platform v2 operation completed at $(Get-Date)"
}
#endregion

# Export environment variables for child processes
$env:DEBUG_MODE = $global:DebugMode.ToString().ToLower()

# Run main function
Main