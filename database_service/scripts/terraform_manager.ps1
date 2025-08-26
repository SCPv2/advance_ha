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

# Setup Terraform logging (Enhanced version)
function Set-TerraformLogging {
    # Create log directory
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    # Find next trial number
    $trialNum = 1
    while (Test-Path "$TerraformLogsDir\tf_deployment_$('{0:D2}' -f $trialNum).log") {
        $trialNum++
    }
    
    $logFile = "$LogsDir\tf_deployment_$('{0:D2}' -f $trialNum).log"
    
    # Set Terraform environment variables (log all API communication)
    $env:TF_LOG = "TRACE"
    $env:TF_LOG_PATH = $logFile
    
    Write-Host "✓ Terraform API logging enabled: $logFile" -ForegroundColor Cyan
    Write-Host "  - All provider API requests and responses will be logged" -ForegroundColor Gray
    Write-Host ""
    
    return $logFile
}

# Update Terraform UserData variables
function Update-TerraformUserdataVariables {
    Write-Info "🔄 Updating Terraform UserData variables..."
    
    Push-Location $ProjectDir
    try {
        # Check if generated UserData files exist
        $userdataFiles = @("userdata_web.sh", "userdata_app.sh", "userdata_db.sh")
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
        $planArgs = @("plan", "-out=$planFile")
        
        if ($ShowOutput -or $global:DebugMode) {
            & terraform @planArgs
        } else {
            & terraform @planArgs > $null 2>&1
        }
        
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

# Apply Terraform plan (Enhanced version)
function Invoke-TerraformApply {
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
        & terraform apply $planFile
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform Apply Failed!"
            Write-Host "Check the error message above and the API log file." -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "✅ Infrastructure deployment completed successfully!" -ForegroundColor Green
        Write-Host "Check Terraform outputs for connection details." -ForegroundColor Cyan
        return $true
    } finally {
        Pop-Location
    }
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

# Validate prerequisites
function Test-Prerequisites {
    $errors = 0
    
    # Check Terraform
    if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is required but not installed"
        $errors++
    }
    
    # Check UserData files
    $userdataFiles = @("userdata_web.sh", "userdata_app.sh", "userdata_db.sh")
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
    
    # Setup logging
    $logFile = Set-TerraformLogging
    
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
    
    if (-not (Invoke-TerraformApply)) {
        exit 1
    }
    
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