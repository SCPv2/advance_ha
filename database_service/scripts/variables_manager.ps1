# Samsung Cloud Platform v2 - Variables Manager (PowerShell)
# Converts variables.tf to variables.json and handles user input
#
# Based on: deploy_with_standardized_userdata.ps1 variable processing logic
# Author: SCPv2 Team

param(
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$VariablesTf = Join-Path $ProjectDir "variables.tf"
$VariablesJson = Join-Path $ScriptDir "variables.json"

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

# Create directories
function Initialize-Directories {
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    Write-Success "Created lab_logs directory"
}

# Extract user input variables from variables.tf
function Get-UserInputVariables {
    Write-Info "Extracting USER_INPUT variables from variables.tf..."
    
    $content = Get-Content $VariablesTf -Raw
    $variables = @{}
    
    # Use regex to find variable blocks with [USER_INPUT] tag
    $pattern = 'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[USER_INPUT\][^"]*"[^}]*default\s*=\s*"([^"]*)"[^}]*}'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        $defaultValue = $match.Groups[2].Value
        $variables[$varName] = $defaultValue
        Write-Info "Found USER_INPUT variable: $varName = `"$defaultValue`""
    }
    
    return $variables
}

# Show discovered variables preview
function Show-VariablesPreview {
    param([hashtable]$UserVars)
    
    Write-Host ""
    Cyan "=== Discovered USER_INPUT Variables ==="
    Write-Host "Please check the default values below:" -ForegroundColor White
    Write-Host ""
    
    $sortedKeys = $UserVars.Keys | Sort-Object
    foreach ($varName in $sortedKeys) {
        $defaultValue = $UserVars[$varName]
        Write-Host "  " -NoNewline
        Write-Host $varName -ForegroundColor Yellow -NoNewline
        Write-Host ": " -NoNewline
        Write-Host $defaultValue -ForegroundColor Blue
    }
    
    Write-Host ""
    Write-Host -NoNewline "Do you want to change any values? " -ForegroundColor White
    Write-Host -NoNewline "[Y/n]: " -ForegroundColor Yellow
    $response = Read-Host
    
    return ($response -match "^[Yy]?$" -and $response -ne "n")
}

# Interactive user input collection
function Get-UserInput {
    param([hashtable]$UserVars)
    
    Write-Info "🔍 Collecting user input variables..."
    
    # Show preview and ask if user wants to change
    $wantsToChange = Show-VariablesPreview $UserVars
    
    if (-not $wantsToChange) {
        Write-Info "Using all default values"
        return $UserVars
    }
    
    $updatedVars = @{}
    
    Write-Host ""
    Cyan "=== Variable Input Session ==="
    Write-Host "Press Enter to keep default value, or type new value:" -ForegroundColor White
    
    foreach ($varName in $UserVars.Keys | Sort-Object) {
        $defaultValue = $UserVars[$varName]
        
        Write-Host ""
        Write-Host $varName -ForegroundColor Yellow -NoNewline
        Write-Host " ?" -ForegroundColor Yellow
        Write-Host "Default(Enter): " -ForegroundColor Cyan -NoNewline
        Write-Host $defaultValue -ForegroundColor Blue
        Write-Host -NoNewline "New Value: " -ForegroundColor White
        $userInput = Read-Host
        
        $finalValue = if ([string]::IsNullOrWhiteSpace($userInput)) { $defaultValue } else { $userInput }
        $updatedVars[$varName] = $finalValue
    }
    
    # Show final confirmation
    Show-FinalConfirmation $updatedVars
    
    return $updatedVars
}

# Show final confirmation of all values
function Show-FinalConfirmation {
    param([hashtable]$UpdatedVars)
    
    Write-Host ""
    Cyan "=== Final Configuration Review ==="
    Write-Host "Please review your configuration:" -ForegroundColor White
    Write-Host ""
    
    $sortedKeys = $UpdatedVars.Keys | Sort-Object
    foreach ($varName in $sortedKeys) {
        $value = $UpdatedVars[$varName]
        Write-Host "  " -NoNewline
        Write-Host $varName -ForegroundColor Yellow -NoNewline
        Write-Host ": " -NoNewline
        Write-Host $value -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host -NoNewline "Would you like to confirm and proceed? " -ForegroundColor White
    Write-Host -NoNewline "[Y/n]: " -ForegroundColor Yellow
    $confirmation = Read-Host
    
    if ($confirmation -match "^[Nn]$") {
        Write-Host ""
        Write-Host "Configuration cancelled. Please restart the script to try again." -ForegroundColor Red
        exit 1
    }
    
    Write-Success "Configuration confirmed! Proceeding with deployment..."
}

# Extract CEWEB_REQUIRED variables from variables.tf
function Get-CewebRequiredVariables {
    Write-Info "Extracting CEWEB_REQUIRED variables from variables.tf..."
    
    $content = Get-Content $VariablesTf -Raw
    $variables = @{}
    
    # Use regex to find variable blocks with [CEWEB_REQUIRED] tag
    $patterns = @(
        'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[CEWEB_REQUIRED\][^"]*"[^}]*default\s*=\s*"([^"]*)"[^}]*}',
        'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[CEWEB_REQUIRED\][^"]*"[^}]*default\s*=\s*(\d+)[^}]*}',
        'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[CEWEB_REQUIRED\][^"]*"[^}]*default\s*=\s*(true|false)[^}]*}'
    )
    
    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        foreach ($match in $matches) {
            $varName = $match.Groups[1].Value
            $defaultValue = $match.Groups[2].Value
            $variables[$varName] = $defaultValue
        }
    }
    
    return $variables
}

# Update variables.tf with user input values
function Update-VariablesTf {
    param([hashtable]$UserInputVars)
    
    Write-Info "📝 Updating variables.tf with user input values..."
    
    # Create backup
    $backupFile = "$VariablesTf.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $VariablesTf $backupFile
    Write-Info "Backup created: $backupFile"
    
    # Read current content
    $content = Get-Content $VariablesTf -Raw
    
    # Update each user input variable
    foreach ($varName in $UserInputVars.Keys) {
        $varValue = $UserInputVars[$varName]
        Write-Info "Updating $varName = `"$varValue`""
        
        # Pattern to match variable block and update default value
        $pattern = "(variable\s+`"$varName`"[^}]*default\s*=\s*)`"[^`"]*`""
        $replacement = "`${1}`"$varValue`""
        
        $content = $content -replace $pattern, $replacement
    }
    
    # Save updated content
    Set-Content -Path $VariablesTf -Value $content -Encoding UTF8
    
    Write-Success "variables.tf updated with user input values"
    
    # Skip Terraform validation - it will be handled by terraform_manager
    Write-Info "Variables.tf updated successfully (Terraform validation will be done in terraform_manager)"
}

# Generate variables.json from collected data
function New-VariablesJson {
    param(
        [hashtable]$UserInputVars,
        [hashtable]$CewebRequiredVars
    )
    
    Write-Info "📊 Generating variables.json..."
    
    # Create configuration object
    $config = [PSCustomObject]@{
        "_variable_classification" = [PSCustomObject]@{
            "description" = "ceweb application variable classification system"
            "categories" = [PSCustomObject]@{
                "user_input" = "Variables that users input interactively during deployment"
                "ceweb_required" = "Variables required by ceweb application for business logic and database connections"
            }
        }
        "config_metadata" = [PSCustomObject]@{
            "version" = "4.0.0"
            "created" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            "description" = "Samsung Cloud Platform 3-Tier Architecture Master Configuration"
            "usage" = "This file contains all environment-specific settings for the application deployment"
            "generator" = "variables_manager.ps1"
            "template_source" = "variables.tf"
        }
        "user_input_variables" = [PSCustomObject]@{
            "_comment" = "Variables that users input interactively during deployment"
            "_source" = "variables.tf USER_INPUT category"
        }
        "ceweb_required_variables" = [PSCustomObject]@{
            "_comment" = "Variables required by ceweb application for business logic and functionality"
            "_source" = "variables.tf CEWEB_REQUIRED category"
            "_database_connection" = [PSCustomObject]@{
                "database_password" = "ceadmin123"
                "db_ssl_enabled" = $false
                "db_pool_min" = 20
                "db_pool_max" = 100
                "db_pool_idle_timeout" = 30000
                "db_pool_connection_timeout" = 60000
            }
        }
    }
    
    # Add user input variables
    foreach ($varName in $UserInputVars.Keys) {
        $config.user_input_variables | Add-Member -MemberType NoteProperty -Name $varName -Value $UserInputVars[$varName]
    }
    
    # Add CEWEB required variables  
    foreach ($varName in $CewebRequiredVars.Keys) {
        $config.ceweb_required_variables | Add-Member -MemberType NoteProperty -Name $varName -Value $CewebRequiredVars[$varName]
    }
    
    # Convert to JSON and save
    $jsonContent = $config | ConvertTo-Json -Depth 10
    Set-Content -Path $VariablesJson -Value $jsonContent -Encoding UTF8
    
    Write-Success "Variables.json generated successfully"
    
    # Display summary
    Write-Host ""
    Cyan "=== Variables Summary ==="
    Write-Host "$(Green 'User Input Variables:') $($UserInputVars.Count) items"
    Write-Host "$(Green 'CEWEB Required Variables:') $($CewebRequiredVars.Count) items"  
    Write-Host "$(Green 'Output File:') $VariablesJson"
    Write-Host "$(Green 'Updated File:') $VariablesTf"
    Write-Host ""
}

# Main execution
function Main {
    Write-Info "🚀 Samsung Cloud Platform v2 - Variables Manager"
    
    # Check prerequisites
    if (!(Test-Path $VariablesTf)) {
        Write-Error "variables.tf not found: $VariablesTf"
        exit 1
    }
    
    # Setup directories
    Initialize-Directories
    
    # Extract variables from variables.tf
    $userInputVars = Get-UserInputVariables
    if ($userInputVars.Count -eq 0) {
        Write-Error "No USER_INPUT variables found in variables.tf"
        exit 1
    }
    
    $cewebRequiredVars = Get-CewebRequiredVariables
    Write-Info "Found $($cewebRequiredVars.Count) CEWEB_REQUIRED variables"
    
    # Collect user input
    $updatedUserVars = Get-UserInput $userInputVars
    
    # Update variables.tf with user input
    Update-VariablesTf $updatedUserVars
    
    # Generate variables.json
    New-VariablesJson $updatedUserVars $cewebRequiredVars
    
    Write-Success "✅ Variables processing completed successfully!"
    Write-Info "Next step: Run userdata_manager.ps1 to generate UserData files"
    
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
    Write-Error "Variables processing failed: $($_.Exception.Message)"
    exit 1
}