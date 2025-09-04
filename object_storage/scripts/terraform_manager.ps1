# Samsung Cloud Platform v2 - Terraform Manager (PowerShell)
# Handles Terraform deployment (init/validate/plan/apply)
#
# Based on: terraform_manager.sh logic
# Author: SCPv2 Team

param(
    [switch]$Debug,
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$GeneratedDir = Join-Path $ScriptDir "generated_userdata"

# Color functions
function Red($text) { Write-Host $text -ForegroundColor Red }
function Green($text) { Write-Host $text -ForegroundColor Green }
function Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Blue($text) { Write-Host $text -ForegroundColor Blue }
function Cyan($text) { Write-Host $text -ForegroundColor Cyan }

# Logging functions
function Write-Info($message) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp [INFO] $message" 
}
function Write-Success($message) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp $(Green '[SUCCESS]') $message" 
}
function Write-Error($message) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp $(Red '[ERROR]') $message" 
}
function Write-Warning($message) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp $(Yellow '[WARNING]') $message" 
}

# Setup Terraform logging (Enhanced version with detailed API logging)
function Set-TerraformLogging {
    # Create log directory
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    # Create timestamp for all log files
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Create comprehensive log file names
    $terraformLogFile = "$LogsDir\terraform_debug_$timestamp.log"
    $providerLogFile = "$LogsDir\provider_api_$timestamp.log"
    $executionLogFile = "$LogsDir\terraform_execution_$timestamp.log"
    
    # Set comprehensive Terraform environment variables (log ALL API communication)
    $env:TF_LOG = "TRACE"                    # Terraform core logging
    $env:TF_LOG_PATH = $terraformLogFile     # Main Terraform log
    $env:TF_LOG_PROVIDER = "TRACE"           # Provider-specific logging
    $env:TF_LOG_PROVIDER_PATH = $providerLogFile  # Provider API log
    $env:TF_CPP_MIN_LOG_LEVEL = "0"          # Enable all C++ logs
    
    Write-Host "✓ Enhanced Terraform API logging enabled:" -ForegroundColor Cyan
    Write-Host "  📋 Terraform Core: $terraformLogFile" -ForegroundColor Gray
    Write-Host "  🔌 Provider API: $providerLogFile" -ForegroundColor Gray
    Write-Host "  📊 Execution Log: $executionLogFile" -ForegroundColor Gray
    Write-Host "  - All provider API requests/responses will be logged" -ForegroundColor Gray
    Write-Host "  - HTTP calls, timeouts, and errors will be captured" -ForegroundColor Gray
    Write-Host ""
    
    return @{
        Terraform = $terraformLogFile
        Provider = $providerLogFile
        Execution = $executionLogFile
        Timestamp = $timestamp
    }
}

# Update Terraform UserData variables
function Update-TerraformUserdataVariables {
    Write-Info "🔄 Updating Terraform UserData variables..."
    
    Push-Location $ProjectDir
    try {
        # Check if generated UserData files exist
        $userdataFiles = @("userdata_web.sh", "userdata_app.sh")
        foreach ($file in $userdataFiles) {
            $filePath = Join-Path $GeneratedDir $file
            if (!(Test-Path $filePath)) {
                Write-Error "UserData file not found: $filePath"
                return $false
            }
        }
        
        # Update main.tf with UserData file paths (if needed)
        # This assumes your main.tf references the UserData files
        Write-Success "UserData variables updated successfully"
        
        return $true
    } finally {
        Pop-Location
    }
}

# Initialize Terraform (Enhanced version)
function Initialize-Terraform {
    param($ShowOutput = $false)
    
    Write-Info "[1/4] Initializing Terraform..."
    
    Push-Location $ProjectDir
    try {
        if (!(Test-Path ".terraform")) {
            Write-Host "Initializing Terraform..." -ForegroundColor Yellow
            if ($ShowOutput -or $global:DebugMode) {
                & terraform init
            } else {
                & terraform init > $null 2>&1
            }
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform Init Failed!"
                Write-Host "Troubleshooting:" -ForegroundColor Yellow
                Write-Host "1. Check error message above" -ForegroundColor White
                Write-Host "2. Verify internet connection" -ForegroundColor White
                Write-Host "3. Check Terraform version compatibility (>=1.11)" -ForegroundColor White
                Write-Host "4. Delete .terraform folder and retry" -ForegroundColor White
                return $false
            }
        } else {
            Write-Info "Terraform already initialized"
        }
        
        Write-Success "Terraform initialization completed"
        return $true
    } finally {
        Pop-Location
    }
}

# Validate Terraform configuration (Enhanced version)
function Invoke-TerraformValidate {
    param($ShowOutput = $false)
    
    Write-Info "[2/4] Running terraform validate..."
    
    Push-Location $ProjectDir
    try {
        if ($ShowOutput -or $global:DebugMode) {
            & terraform validate
        } else {
            & terraform validate > $null 2>&1
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform Validate Failed!"
            return $false
        }
        
        Write-Success "Terraform validation completed"
        return $true
    } finally {
        Pop-Location
    }
}

# Run Terraform plan (Enhanced version)
function Invoke-TerraformPlan {
    param($ShowOutput = $false)
    
    Write-Info "[3/4] Creating execution plan with Terraform Plan..."
    
    Push-Location $ProjectDir
    try {
        $planFile = Join-Path $LogsDir "terraform.tfplan"
        $backupFile = Join-Path $LogsDir "terraform.tfstate.backup"
        $planArgs = @("plan", "-out=$planFile", "-backup=$backupFile")
        
        # Always show terraform plan output for better visibility of issues
        Write-Host "Executing: terraform plan -out=$planFile -backup=$backupFile" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Gray
        
        # Real-time output with logging
        $planLogFile = Join-Path $LogsDir "terraform_plan_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        & terraform @planArgs 2>&1 | ForEach-Object { 
            Write-Host $_ -ForegroundColor White
            $_ | Out-File -Append -FilePath $planLogFile -Encoding UTF8
        }
        
        Write-Host ("=" * 60) -ForegroundColor Gray
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform Plan Failed!"
            return $false
        }
        
        Write-Success "Terraform plan completed"
        Write-Info "Plan file saved: $planFile"
        return $true
    } finally {
        Pop-Location
    }
}

# Apply Terraform plan (Enhanced version with execution logging)
function Invoke-TerraformApply {
    param($LogFiles)
    
    Write-Info "[4/4] Ready to deploy infrastructure..."
    Write-Host "Warning: This will create real resources on Samsung Cloud Platform!" -ForegroundColor Yellow
    
    Push-Location $ProjectDir
    try {
        $planFile = Join-Path $LogsDir "terraform.tfplan"
        
        if (!(Test-Path $planFile)) {
            Write-Error "Plan file not found: $planFile"
            return $false
        }
        
        # Enhanced user confirmation with safe null handling
        if (-not $AutoApprove) {
            do {
                $confirmation = Read-Host "Continue with deployment? Yes(y), No(n) [default: y]"
                # Safe null handling
                $safeConfirmation = if ($null -eq $confirmation) { "" } else { $confirmation.Trim().ToLower() }
                
                if ($safeConfirmation -eq 'y' -or $safeConfirmation -eq 'yes' -or $safeConfirmation -eq '') {
                    $proceed = $true
                    break
                }
                elseif ($safeConfirmation -eq 'n' -or $safeConfirmation -eq 'no') {
                    $proceed = $false
                    break
                }
                else {
                    Write-Host "Invalid input. Please enter Yes(y) or No(n)." -ForegroundColor Yellow
                }
            } while ($true)
            
            if (-not $proceed) {
                Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
                return $false
            }
        }
        
        Write-Host "Starting Terraform Apply..." -ForegroundColor Green
        
        # Create execution log with timestamps and detailed output
        $startTime = Get-Date
        $executionContent = @(
            "=== Terraform Apply Started: $startTime ==="
            "Command: terraform apply $planFile"
            "Terraform Log: $($LogFiles.Terraform)"
            "Provider Log: $($LogFiles.Provider)"
            "="*50
        )
        
        # Execute terraform apply with real-time output
        $backupFile = Join-Path $LogsDir "terraform.tfstate.backup.apply"
        Write-Host "Executing: terraform apply -backup=$backupFile $planFile" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Gray
        
        # Run terraform apply and show output in real-time while capturing to log
        $terraformLogFile = Join-Path $LogsDir "terraform_apply_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        & terraform apply "-backup=$backupFile" $planFile 2>&1 | ForEach-Object { 
            Write-Host $_ -ForegroundColor White
            $_ | Out-File -Append -FilePath $terraformLogFile -Encoding UTF8
        }
        $exitCode = $LASTEXITCODE
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host ("=" * 60) -ForegroundColor Gray
        
        # Read captured output for execution log
        $terraformOutput = if (Test-Path $terraformLogFile) { Get-Content $terraformLogFile } else { @("Output log not found") }
        
        # Append execution results
        $executionContent += $terraformOutput
        $executionContent += ""
        $executionContent += "="*50
        $executionContent += "=== Terraform Apply Ended: $endTime ==="
        $executionContent += "Duration: $($duration.TotalSeconds) seconds"
        $executionContent += "Exit Code: $exitCode"
        
        # Save execution log
        $executionContent | Out-File -FilePath $LogFiles.Execution -Encoding UTF8
        
        if ($exitCode -ne 0) {
            Write-Error "Terraform Apply Failed!"
            Write-Host "📄 Detailed logs available:" -ForegroundColor Yellow
            Write-Host "  🔍 Execution: $($LogFiles.Execution)" -ForegroundColor Red
            Write-Host "  🔍 API Debug: $($LogFiles.Provider)" -ForegroundColor Red
            Write-Host "  🔍 Core Debug: $($LogFiles.Terraform)" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ Infrastructure deployment completed successfully!" -ForegroundColor Green
        Write-Host "Check Terraform outputs for connection details." -ForegroundColor Cyan
        return $true
    } finally {
        Pop-Location
    }
}

# Create status markers for deployment success/failure
function Create-StatusMarker {
    param(
        [bool]$IsSuccess,
        [hashtable]$LogFiles
    )
    
    $timestamp = $LogFiles.Timestamp
    $status = if ($IsSuccess) { "SUCCESS" } else { "FAILURE" }
    $statusFile = "$LogsDir\deployment_${status}_$timestamp.marker"
    
    # Create status marker content
    $markerContent = @{
        Status = $status
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TerraformLog = $LogFiles.Terraform
        ProviderLog = $LogFiles.Provider
        ExecutionLog = $LogFiles.Execution
        Duration = if ($IsSuccess) { "Completed" } else { "Failed" }
    }
    
    # Save marker as JSON
    $markerContent | ConvertTo-Json -Depth 3 | Out-File -FilePath $statusFile -Encoding UTF8
    
    if ($IsSuccess) {
        Write-Success "✅ Deployment SUCCESS marker created: $statusFile"
    } else {
        Write-Error "❌ Deployment FAILURE marker created: $statusFile"
    }
    
    return $statusFile
}

# Display deployment results
function Show-DeploymentResults {
    Write-Info "📊 Deployment Results:"
    
    Push-Location $ProjectDir
    try {
        Write-Host ""
        Cyan "=== Infrastructure Deployment Summary ==="
        
        # Show Terraform outputs
        if (Get-Command terraform -ErrorAction SilentlyContinue) {
            Write-Host ""
            Write-Host "Terraform Outputs:" -ForegroundColor White -BackgroundColor Black
            try {
                & terraform output 2>$null
            } catch {
                Write-Host "No outputs available"
            }
        }
        
        Write-Host ""
        Green "✅ Deployment completed successfully!"
        Write-Host "$(Blue '📁 Logs directory:') $LogsDir"
        Write-Host "$(Blue '📋 UserData files:') $GeneratedDir"
    } finally {
        Pop-Location
    }
}

# Clean up logs
function Remove-TerraformLogs {
    $logFiles = Get-ChildItem -Path $LogsDir -Name "tf_deployment_*.log" -ErrorAction SilentlyContinue
    $logCount = $logFiles.Count
    
    if ($logCount -gt 0) {
        Write-Host ""
        $response = Read-Host "$(Yellow "Clean up terraform logs? ($logCount files) (y/N)")"
        
        if ($response -match "^[Yy]$") {
            Remove-Item -Path "$LogsDir\tf_deployment_*.log" -Force -ErrorAction SilentlyContinue
            Write-Success "Terraform logs cleaned up"
        } else {
            Write-Info "Terraform logs preserved in $LogsDir"
        }
    }
}

# Check previous deployment state
function Test-PreviousDeploymentState {
    Write-Info "🔍 Checking previous deployment state..."
    
    # Check for deployment status markers
    $statusMarkers = @(Get-ChildItem -Path $LogsDir -Name "deployment_*_*.marker" -ErrorAction SilentlyContinue)
    
    if ($statusMarkers.Count -eq 0) {
        Write-Success "No previous deployment markers found - clean start"
        return $true
    }
    
    # Find the most recent marker
    $latestMarker = $statusMarkers | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $markerPath = Join-Path $LogsDir $latestMarker.Name
    
    try {
        $markerData = Get-Content $markerPath | ConvertFrom-Json
        $markerStatus = $markerData.Status
        
        if ($markerStatus -eq "FAILURE") {
            Write-Warning "Previous deployment FAILED at $($markerData.Timestamp)"
            Write-Host ""
            Yellow "Previous deployment logs:"
            if (Test-Path $markerData.TerraformLog) { Write-Host "  🔍 Terraform: $($markerData.TerraformLog)" }
            if (Test-Path $markerData.ProviderLog) { Write-Host "  🔍 Provider: $($markerData.ProviderLog)" }
            if (Test-Path $markerData.ExecutionLog) { Write-Host "  🔍 Execution: $($markerData.ExecutionLog)" }
            Write-Host ""
            
            # Offer recovery options
            do {
                Write-Host "How do you want to proceed?" -ForegroundColor White -BackgroundColor Black
                Write-Host ""
                Yellow "1. CLEAN START  - Remove all state files and start fresh"
                Yellow "2. RETRY        - Continue with existing state (risky if state corrupted)"
                Red "3. CANCEL       - Exit and manually investigate"
                Write-Host ""
                Write-Host -NoNewline -ForegroundColor Cyan "Select option (1/2/3): "
                $choice = Read-Host
                
                switch ($choice) {
                    "1" {
                        Write-Info "Cleaning up previous deployment state..."
                        # Remove terraform state files
                        $stateFiles = @("terraform.tfstate", "terraform.tfstate.backup")
                        foreach ($stateFile in $stateFiles) {
                            $statePath = Join-Path $ProjectDir $stateFile
                            if (Test-Path $statePath) {
                                $backupName = "terraform.tfstate.cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').backup"
                                $backupPath = Join-Path $LogsDir $backupName
                                Move-Item $statePath $backupPath -Force
                                Write-Info "Backed up state file: $backupName"
                            }
                        }
                        
                        # Remove .terraform directory
                        $terraformDir = Join-Path $ProjectDir ".terraform"
                        if (Test-Path $terraformDir) {
                            Remove-Item $terraformDir -Recurse -Force
                            Write-Info "Removed .terraform directory"
                        }
                        
                        # Remove failure marker
                        Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
                        Write-Success "Clean start setup completed"
                        return $true
                    }
                    "2" {
                        Write-Warning "Continuing with existing state - monitoring for errors..."
                        return $true
                    }
                    "3" {
                        Write-Info "Deployment cancelled for manual investigation"
                        return $false
                    }
                    default {
                        Red "Invalid option. Please select 1, 2, or 3."
                    }
                }
            } while ($true)
        }
        elseif ($markerStatus -eq "SUCCESS") {
            Write-Info "Previous deployment succeeded at $($markerData.Timestamp)"
            Write-Warning "Proceeding will modify existing infrastructure"
            Write-Host ""
            do {
                Write-Host -NoNewline -ForegroundColor Yellow "Continue with deployment? (y/N): "
                $proceed = Read-Host
                if ($proceed -match "^[Yy]$") {
                    return $true
                }
                elseif ($proceed -match "^[Nn]$" -or $proceed -eq "") {
                    Write-Info "Deployment cancelled by user"
                    return $false
                }
                else {
                    Red "Please enter 'y' for yes or 'n' for no."
                }
            } while ($true)
        }
    }
    catch {
        Write-Warning "Could not read deployment marker: $($_.Exception.Message)"
        Write-Info "Proceeding with deployment..."
        return $true
    }
    
    return $true
}

# Validate prerequisites
function Test-Prerequisites {
    $errors = 0
    
    # Check Terraform
    if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is required but not installed"
        $errors++
    }
    
    # Check UserData files (DB uses DBaaS - no VM UserData needed)
    $userdataFiles = @("userdata_web.sh", "userdata_app.sh")
    foreach ($file in $userdataFiles) {
        $filePath = Join-Path $GeneratedDir $file
        if (!(Test-Path $filePath)) {
            Write-Error "UserData file not found: $filePath"
            Write-Error "Run userdata_manager.ps1 first to generate UserData files"
            $errors++
        }
    }
    
    # Check project structure
    $mainTf = Join-Path $ProjectDir "main.tf"
    if (!(Test-Path $mainTf)) {
        Write-Error "main.tf not found in project directory: $ProjectDir"
        $errors++
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
    Write-Info "🚀 Samsung Cloud Platform v2 - Terraform Manager"
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Check previous deployment state
    if (-not (Test-PreviousDeploymentState)) {
        exit 1
    }
    
    # Setup comprehensive logging
    $logFiles = Set-TerraformLogging
    
    # Update UserData variables
    if (-not (Update-TerraformUserdataVariables)) {
        Write-Error "Failed to update UserData variables"
        exit 1
    }
    
    Write-Host ""
    Write-Info "=== TERRAFORM DEPLOYMENT STARTED ==="
    
    # Execute Terraform workflow
    if (-not (Initialize-Terraform -ShowOutput $global:DebugMode)) {
        exit 1
    }
    
    if (-not (Invoke-TerraformValidate -ShowOutput $global:DebugMode)) {
        exit 1
    }
    
    if (-not (Invoke-TerraformPlan -ShowOutput $global:DebugMode)) {
        exit 1
    }
    
    if (-not (Invoke-TerraformApply -LogFiles $logFiles)) {
        # Create failure marker
        Create-StatusMarker -IsSuccess $false -LogFiles $logFiles
        exit 1
    }
    
    # Create success marker
    Create-StatusMarker -IsSuccess $true -LogFiles $logFiles
    
    # Show results
    Show-DeploymentResults
    
    # Cleanup
    Remove-TerraformLogs
    
    Write-Success "✅ Terraform deployment completed successfully!"
    
    return 0
}

# Set global debug mode
$global:DebugMode = $Debug.IsPresent

# Set environment variables for child processes
$env:DEBUG_MODE = $global:DebugMode.ToString().ToLower()
$env:AUTO_APPROVE = $AutoApprove.IsPresent.ToString().ToLower()

# Run main function
try {
    exit (Main)
} catch {
    Write-Error "Terraform deployment failed: $($_.Exception.Message)"
    exit 1
}