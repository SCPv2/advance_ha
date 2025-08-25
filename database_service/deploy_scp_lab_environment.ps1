# PowerShell Error Handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
========================================
Samsung Cloud Platform v2 Creative Energy
3-Tier High Availability Lab Environment Deployment Script
========================================

Usage:
  - Press Enter: General Mode (Fast deployment)
  - Type 'admin' + Enter: Developer Mode (Detailed validation and debug output)

Author: SCPv2 Team
Version: 3.0 (Modularized)
========================================
#>

# Global variables
$global:ValidationMode = $false

# Load required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    . (Join-Path $scriptPath "scripts\deploy_scp_lab_variable_module.ps1")
    . (Join-Path $scriptPath "scripts\deploy_scp_lab_userdata_module.ps1")
} catch {
    Write-Host "❌ Failed to load required modules from ./scripts/" -ForegroundColor Red
    Write-Host "Make sure the following files exist:" -ForegroundColor Yellow
    Write-Host "  - $scriptPath\scripts\deploy_scp_lab_variable_module.ps1" -ForegroundColor White
    Write-Host "  - $scriptPath\scripts\deploy_scp_lab_userdata_module.ps1" -ForegroundColor White
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#region Terraform Operations
function Set-TerraformLogging {
    # Create log directory
    if (-not (Test-Path "terraform_log")) {
        New-Item -ItemType Directory -Path "terraform_log" -Force | Out-Null
    }
    
    # Find next trial number
    $trialNum = 1
    while (Test-Path "terraform_log\trial$('{0:D2}' -f $trialNum).log") {
        $trialNum++
    }
    
    $logFile = "terraform_log\trial$('{0:D2}' -f $trialNum).log"
    
    # Set Terraform environment variables (log all API communication)
    $env:TF_LOG = "TRACE"
    $env:TF_LOG_PATH = $logFile
    
    Write-Host "✓ Terraform API logging enabled: $logFile" -ForegroundColor Cyan
    Write-Host "  - All provider API requests and responses will be logged" -ForegroundColor Gray
    Write-Host ""
    
    return $logFile
}

function Initialize-Terraform {
    param($ShowOutput = $false)
    
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        if ($ShowOutput) {
            terraform init
        } else {
            terraform init | Out-Null
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Terraform Init Failed!" -ForegroundColor Red
            Write-Host "Troubleshooting:" -ForegroundColor Yellow
            Write-Host "1. Check error message above" -ForegroundColor White
            Write-Host "2. Verify internet connection" -ForegroundColor White
            Write-Host "3. Check Terraform version compatibility (>=1.11)" -ForegroundColor White
            Write-Host "4. Delete .terraform folder and retry" -ForegroundColor White
            Read-Host "Press any key to exit..."
            exit 1
        }
    }
}

function Invoke-TerraformValidate {
    param($ShowOutput = $false)
    
    Write-Host "[1/3] Running terraform validate..." -ForegroundColor Cyan
    if ($ShowOutput) {
        terraform validate
    } else {
        terraform validate | Out-Null
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform Validate Failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Success: terraform validate completed" -ForegroundColor Green
}

function Invoke-TerraformPlan {
    param($ShowOutput = $false)
    
    Write-Host "[2/3] Creating execution plan with Terraform Plan..." -ForegroundColor Cyan
    if ($ShowOutput) {
        terraform plan
    } else {
        terraform plan | Out-Null
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform Plan Failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Success: terraform plan completed" -ForegroundColor Green
}

function Invoke-TerraformApply {
    Write-Host "[3/3] Ready to deploy infrastructure..." -ForegroundColor Cyan
    Write-Host "Warning: This will create real resources on Samsung Cloud Platform!" -ForegroundColor Yellow
    
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
        exit 0
    }
    
    Write-Host "Starting Terraform Apply..." -ForegroundColor Green
    terraform apply -auto-approve
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform Apply Failed!" -ForegroundColor Red
        Write-Host "Check the error message above and the API log file." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✅ Infrastructure deployment completed successfully!" -ForegroundColor Green
    Write-Host "Check Terraform outputs for connection details." -ForegroundColor Cyan
}
#endregion

#region Mode Functions
function Start-DeveloperMode {
    Write-Host "=========================================" -ForegroundColor Magenta
    Write-Host "Developer Mode - Detailed Validation" -ForegroundColor Magenta
    Write-Host "=========================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Initialize with detailed output
    Initialize-Terraform -ShowOutput $true
    
    # Variable consistency check
    Write-Host "🔍 Checking variable consistency..." -ForegroundColor Cyan
    $userInputIssues = Test-VariableConsistency "USER_INPUT"
    $cewebRequiredIssues = Test-VariableConsistency "CEWEB_REQUIRED"
    $terraformInfraIssues = Test-VariableConsistency "TERRAFORM_INFRA"
    
    $totalIssues = 0
    if ($userInputIssues) { $totalIssues += $userInputIssues.Count }
    if ($cewebRequiredIssues) { $totalIssues += $cewebRequiredIssues.Count }
    if ($terraformInfraIssues) { $totalIssues += $terraformInfraIssues.Count }
    
    if ($totalIssues -gt 0) {
        Write-Host "⚠️ Variable inconsistencies found but continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "✅ All variable consistency checks passed!" -ForegroundColor Green
    }
    Write-Host ""
    
    # Load all variables for deployment
    $variables = Get-AllVariablesForDeployment
    
    # Generate configurations
    Write-Host "🔄 Generating master_config.json and userdata files..." -ForegroundColor Cyan
    $jsonContent = New-MasterConfigJson $variables
    Update-UserdataFiles $variables
    Write-Host ""
    
    # Terraform operations with detailed output
    Invoke-TerraformValidate -ShowOutput $true
    Invoke-TerraformPlan -ShowOutput $true
    Invoke-TerraformApply
}

function Start-GeneralMode {
    # Check prerequisites
    if (-not (Test-Path "main.tf")) {
        throw "main.tf file not found. Please run script in terraform directory."
    }
    
    $terraformVersion = terraform version 2>$null
    if (-not $terraformVersion) {
        throw "Terraform is not installed or not in PATH"
    }
    Write-Host "✓ Terraform found: $($terraformVersion[0])" -ForegroundColor Green
    
    # Initialize terraform quietly
    Initialize-Terraform -ShowOutput $false
    
    # User input variables section
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "User Input Variables Review/Modification" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Load USER_INPUT variables from JSON (fast)
    $originalValidationMode = $global:ValidationMode
    $global:ValidationMode = $false
    $userInputVars = Get-VariablesFromJson -Category "USER_INPUT"
    $global:ValidationMode = $originalValidationMode
    $userVariables = @{}
    
    # Load JSON data to get descriptions
    $jsonData = Get-Content "variables.json" -Raw | ConvertFrom-Json
    $userInputData = $jsonData.USER_INPUT
    
    if ($userInputVars -and $userInputVars.Keys) {
        foreach ($varName in $userInputVars.Keys) {
        $currentValue = $userInputVars[$varName]
        $description = if ($userInputData.$varName) { $userInputData.$varName.description } else { "" }
        
        $userVariables[$varName] = @{
            "current" = $currentValue
            "description" = $description
            "new_value" = ""
        }
        }
    }
    
    # Display current variables
    Write-Host "Current USER_INPUT variables in variables.tf:" -ForegroundColor Yellow
    Write-Host ""
    $index = 1
    $userVariables.GetEnumerator() | ForEach-Object {
        Write-Host "[$index] $($_.Key)" -ForegroundColor White
        Write-Host "    Description: $($_.Value.description)" -ForegroundColor Gray
        Write-Host "    Current Value: $($_.Value.current)" -ForegroundColor Cyan
        Write-Host ""
        $index++
    }
    
    # Ask if user wants to modify variables
    $shouldModify = $false
    do {
        $modifyVars = Read-Host "Do you want to review/modify user input variables? Yes(y), No(n) [default: y]"
        # Safe null handling
        $safeModifyVars = if ($null -eq $modifyVars) { "" } else { $modifyVars.Trim().ToLower() }
        
        if ($safeModifyVars -eq 'y' -or $safeModifyVars -eq 'yes' -or $safeModifyVars -eq '') {
            $shouldModify = $true
            break
        }
        elseif ($safeModifyVars -eq 'n' -or $safeModifyVars -eq 'no') {
            $shouldModify = $false
            break
        }
        else {
            Write-Host "Invalid input. Please enter Yes(y) or No(n)." -ForegroundColor Yellow
        }
    } while ($true)
    
    if ($shouldModify) {
        Write-Host ""
        Write-Host "Variable Value Input (Press Enter to keep existing value, or enter new value):" -ForegroundColor Cyan
        Write-Host ""
        
        # Collect input for each USER_INPUT variable
        $varNames = if ($userVariables.Keys) { $userVariables.Keys | Sort-Object } else { @() }
        foreach ($varName in $varNames) {
            $currentValue = $userVariables[$varName].current
            $description = $userVariables[$varName].description
            
            Write-Host "[$varName]" -ForegroundColor Yellow
            Write-Host "  Description: $description" -ForegroundColor Gray
            Write-Host "  Current Value: $currentValue" -ForegroundColor Cyan
            
            # Special handling for user_public_ip - detect current public IP
            if ($varName -eq "user_public_ip") {
                try {
                    Write-Host "  Detecting current Public IP..." -ForegroundColor Gray -NoNewline
                    $detectedIP = (Invoke-RestMethod 'https://api.ipify.org?format=json' -TimeoutSec 5).ip
                    Write-Host " ✓" -ForegroundColor Green
                    Write-Host "  Detected Public IP: $detectedIP" -ForegroundColor Green
                    $newValue = Read-Host "  Enter new value (Enter=use detected IP, other value=custom)"
                    
                    if ([string]::IsNullOrWhiteSpace($newValue)) {
                        $userVariables[$varName].new_value = $detectedIP
                        Write-Host "  → Detected IP($detectedIP) will be used." -ForegroundColor Green
                    } else {
                        $safeTrimmedValue = if ($null -eq $newValue) { "" } else { $newValue.Trim() }
                        $userVariables[$varName].new_value = $safeTrimmedValue
                        Write-Host "  → User input($safeTrimmedValue) will be used." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host " ❌" -ForegroundColor Red
                    Write-Host "  Public IP detection failed (network error): $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "  Enter manually or press Enter to keep existing value." -ForegroundColor Yellow
                    $newValue = Read-Host "  Enter new value (Enter=keep existing)"
                    
                    if ([string]::IsNullOrWhiteSpace($newValue)) {
                        $userVariables[$varName].new_value = $currentValue
                    } else {
                        $safeTrimmedValue = if ($null -eq $newValue) { "" } else { $newValue.Trim() }
                        $userVariables[$varName].new_value = $safeTrimmedValue
                    }
                }
            } else {
                # Regular variable input
                $newValue = Read-Host "  Enter new value (Enter=keep existing)"
                
                if ([string]::IsNullOrWhiteSpace($newValue)) {
                    $userVariables[$varName].new_value = $currentValue
                } else {
                    $safeTrimmedValue = if ($null -eq $newValue) { "" } else { $newValue.Trim() }
                    $userVariables[$varName].new_value = $safeTrimmedValue
                }
            }
            Write-Host ""
        }
        
        # Display confirmation
        do {
            Write-Host "=========================================" -ForegroundColor Green
            Write-Host "Variable Values Confirmation" -ForegroundColor Green
            Write-Host "=========================================" -ForegroundColor Green
            $index = 1
            $varNames | ForEach-Object {
                $varName = $_
                $newValue = $userVariables[$varName].new_value
                Write-Host "[$index] $varName = $newValue" -ForegroundColor White
                $index++
            }
            Write-Host ""
            
            $confirmation = Read-Host "If any item needs modification, enter its number. If all correct, enter Yes(y) [default: y]"
            # Safe null handling
            $safeConfirmation = if ($null -eq $confirmation) { "" } else { $confirmation.Trim() }
            
            if ($safeConfirmation -eq 'y' -or $safeConfirmation -eq 'Y' -or $safeConfirmation -eq '') {
                # Update variables.tf with new values
                Write-Host "Updating variables.tf file..." -ForegroundColor Cyan
                $updateSuccess = $true
                $varNames | ForEach-Object {
                    $varName = $_
                    $newValue = $userVariables[$varName].new_value
                    if (-not (Update-VariableInFile -VariableName $varName -NewValue $newValue)) {
                        Write-Host "⚠️  No change detected for $varName" -ForegroundColor Yellow
                    }
                }
                
                if ($updateSuccess) {
                    Write-Host "✓ variables.tf update completed!" -ForegroundColor Green
                } else {
                    Write-Host "❌ Some errors occurred during variables.tf update" -ForegroundColor Red
                }
                break
            }
            elseif ($safeConfirmation -match '^\d+$') {
                $modifyIndex = [int]$safeConfirmation
                if ($varNames -and $modifyIndex -ge 1 -and $modifyIndex -le $varNames.Count) {
                    $varToModify = $varNames[$modifyIndex - 1]
                    $currentValue = $userVariables[$varToModify].current
                    $description = $userVariables[$varToModify].description
                    
                    Write-Host ""
                    Write-Host "Modifying [$varToModify]" -ForegroundColor Yellow
                    Write-Host "  Description: $description" -ForegroundColor Gray
                    Write-Host "  Current Value: $currentValue" -ForegroundColor Cyan
                    $newValue = Read-Host "  Enter new value"
                    
                    $safeTrimmedValue = if ($null -eq $newValue) { "" } else { $newValue.Trim() }
                    $userVariables[$varToModify].new_value = $safeTrimmedValue
                    Write-Host "  Updated to: $safeTrimmedValue" -ForegroundColor Green
                    Write-Host ""
                } else {
                    $maxCount = if ($varNames) { $varNames.Count } else { 0 }
                    Write-Host "Invalid number. Please enter a number between 1 and $maxCount." -ForegroundColor Red
                }
            } else {
                Write-Host "Invalid input. Enter a number to modify or 'y' to confirm." -ForegroundColor Red
            }
        } while ($true)
    }
    
    Write-Host ""
    
    # Generate all configurations
    Write-Host "Generating master_config.json with extracted values..." -ForegroundColor Cyan
    $variables = Get-AllVariablesForDeployment
    $jsonContent = New-MasterConfigJson $variables
    Update-UserdataFiles $variables
    Write-Host "✓ All configuration files updated successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Terraform operations (quiet mode)
    Invoke-TerraformValidate -ShowOutput $false
    Invoke-TerraformPlan -ShowOutput $false
    Invoke-TerraformApply
}
#endregion

#region Main Execution
try {
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Samsung Cloud Platform v2 Creative Energy" -ForegroundColor Green
    Write-Host "3-Tier High Availability Lab Deployment" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    
    # Initialize by parsing variables.tf to JSON for fast access
    if ($global:ValidationMode) {
        Write-Host "🚀 Initializing: variables.tf → variables.json parsing..." -ForegroundColor Magenta
        ConvertTo-VariablesJson
        Write-Host ""
    } else {
        ConvertTo-VariablesJson | Out-Null
    }
    
    # User mode selection - Enter or admin only
    do {
        $userInput = Read-Host "Start Creative-Energy lab environment deployment now? (Enter)"
        # Safe null handling
        if ($null -eq $userInput) {
            $trimmedInput = ""
        } else {
            $trimmedInput = $userInput.Trim().ToLower()
        }
    } while ($trimmedInput -ne "" -and $trimmedInput -ne "admin")
    
    # API logging setup
    $logFile = Set-TerraformLogging
    
    Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host ""
    
    # Execute based on mode
    $safeUserInput = if ($null -eq $userInput) { "" } else { $userInput.Trim().ToLower() }
    if ($safeUserInput -eq "admin") {
        $global:ValidationMode = $true
        Start-DeveloperMode
    } else {
        $global:ValidationMode = $false
        Start-GeneralMode
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    if (Get-Variable -Name "logFile" -ErrorAction SilentlyContinue) {
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host "Check the log for detailed API communication errors" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Make sure you're in the correct directory with main.tf" -ForegroundColor White
    Write-Host "2. Check if Terraform is installed: terraform version" -ForegroundColor White
    Write-Host "3. Verify variables.tf has all required variables" -ForegroundColor White
    Write-Host "4. Check Samsung Cloud Platform credentials" -ForegroundColor White
    exit 1
} finally {
    # Cleanup temporary files
    if (Test-Path "terraform.tfstate.backup") {
        Write-Host "Terraform state files present - deployment artifacts saved" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Gray
#endregion