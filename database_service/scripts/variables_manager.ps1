# Samsung Cloud Platform v2 - Variables Manager (PowerShell)
# Converts variables.tf to variables.json and handles user input
#
# Usage:
#   .\variables_manager.ps1         # Process variables interactively
#   .\variables_manager.ps1 -Debug  # Enable debug output
#   .\variables_manager.ps1 -Reset  # Reset variables to default values
#
# Based on: deploy_with_standardized_userdata.ps1 variable processing logic
# Author: SCPv2 Team

param(
    [switch]$Debug,
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$VariablesTf = Join-Path $ProjectDir "variables.tf"
$VariablesJson = Join-Path $ScriptDir "variables.json"
# Image/Engine cache file removed - values now hardcoded in variables.tf

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

# Removed scpcli availability check - engine IDs now hardcoded in variables.tf

# Removed Get-ScpImageEngineIds function - engine IDs now hardcoded in variables.tf

# Removed Get-CachedImageEngineData function - engine IDs now hardcoded in variables.tf

# Removed Update-ImageEngineCache function - engine IDs now hardcoded in variables.tf

# Removed Get-ImageId function - images now handled by Terraform data sources

# Removed Get-PostgreSQLEngineId function - engine IDs now hardcoded in variables.tf

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

    # Use the same custom order for preview
    $orderedVarNames = @(
        "user_public_ip",           # 1. Public IP
        "public_domain_name",       # 2. Public Domain Name
        "private_domain_name",      # 3. Private Domain Name
        "object_storage_access_key_id",  # 4. Auth Access Key
        "object_storage_secret_access_key",  # 5. Auth Secret Key
        "object_storage_bucket_string",  # 6. Account ID
        "keypair_name"              # 7. Keypair Name
    )

    # Add any remaining variables not in the ordered list
    $remainingVars = $UserVars.Keys | Where-Object { $_ -notin $orderedVarNames }
    $finalOrder = $orderedVarNames + $remainingVars

    foreach ($varName in $finalOrder) {
        if (-not $UserVars.ContainsKey($varName)) { continue }
        $defaultValue = $UserVars[$varName]

        # Get user-friendly name for display
        $displayName = switch ($varName) {
            "user_public_ip" { "1. Public IP" }
            "public_domain_name" { "2. Public Domain Name" }
            "private_domain_name" { "3. Private Domain Name" }
            "object_storage_access_key_id" { "4. Auth Access Key" }
            "object_storage_secret_access_key" { "5. Auth Secret Key" }
            "object_storage_bucket_string" { "6. Account ID" }
            "keypair_name" { "7. Keypair Name" }
            default { $varName }
        }

        Write-Host "  " -NoNewline
        Write-Host $displayName -ForegroundColor Yellow -NoNewline
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

    do {
        # Show preview and ask if user wants to change
        $wantsToChange = Show-VariablesPreview $UserVars

        if (-not $wantsToChange) {
            Write-Info "Using all default values"
            $updatedVars = $UserVars
        } else {
            $updatedVars = @{}

            Write-Host ""
            Cyan "=== Variable Input Session ==="
            Write-Host "Press Enter to keep default value, or type new value:" -ForegroundColor White

            # Define custom order for user input
            $orderedVarNames = @(
                "user_public_ip",           # 1. Public IP
                "public_domain_name",       # 2. Public Domain Name
                "private_domain_name",      # 3. Private Domain Name
                "object_storage_access_key_id",  # 4. Auth Access Key
                "object_storage_secret_access_key",  # 5. Auth Secret Key
                "object_storage_bucket_string",  # 6. Account ID
                "keypair_name"              # 7. Keypair Name
            )

            # Add any remaining variables not in the ordered list
            $remainingVars = $UserVars.Keys | Where-Object { $_ -notin $orderedVarNames }
            $finalOrder = $orderedVarNames + $remainingVars

            foreach ($varName in $finalOrder) {
                if (-not $UserVars.ContainsKey($varName)) { continue }
                $defaultValue = $UserVars[$varName]

                # Get user-friendly name for display
                $displayName = switch ($varName) {
                    "user_public_ip" { "1. Public IP" }
                    "public_domain_name" { "2. Public Domain Name" }
                    "private_domain_name" { "3. Private Domain Name" }
                    "object_storage_access_key_id" { "4. Auth Access Key" }
                    "object_storage_secret_access_key" { "5. Auth Secret Key" }
                    "object_storage_bucket_string" { "6. Account ID" }
                    "keypair_name" { "7. Keypair Name" }
                    default { $varName }
                }

                Write-Host ""
                Write-Host $displayName -ForegroundColor Yellow -NoNewline
                Write-Host " ?" -ForegroundColor Yellow
                Write-Host "Default(Enter): " -ForegroundColor Cyan -NoNewline
                Write-Host $defaultValue -ForegroundColor Blue
                Write-Host -NoNewline "New Value: " -ForegroundColor White
                $userInput = Read-Host

                $finalValue = if ([string]::IsNullOrWhiteSpace($userInput)) { $defaultValue } else { $userInput }
                $updatedVars[$varName] = $finalValue
            }
        }

        # Show final confirmation and handle retry
        $confirmResult = Show-FinalConfirmation $updatedVars

        if ($confirmResult -eq "confirmed") {
            return $updatedVars
        }
        # If "retry", loop continues

    } while ($true)
}

# Show final confirmation of all values
function Show-FinalConfirmation {
    param([hashtable]$UpdatedVars)

    do {
        Write-Host ""
        Cyan "=== Final Configuration Review ==="
        Write-Host "Please review your configuration:" -ForegroundColor White
        Write-Host ""

        # Use the same custom order for final review
        $orderedVarNames = @(
            "user_public_ip",           # 1. Public IP
            "public_domain_name",       # 2. Public Domain Name
            "private_domain_name",      # 3. Private Domain Name
            "object_storage_access_key_id",  # 4. Auth Access Key
            "object_storage_secret_access_key",  # 5. Auth Secret Key
            "object_storage_bucket_string",  # 6. Account ID
            "keypair_name"              # 7. Keypair Name
        )

        # Add any remaining variables not in the ordered list
        $remainingVars = $UpdatedVars.Keys | Where-Object { $_ -notin $orderedVarNames }
        $finalOrder = $orderedVarNames + $remainingVars

        foreach ($varName in $finalOrder) {
            if (-not $UpdatedVars.ContainsKey($varName)) { continue }
            $value = $UpdatedVars[$varName]

            # Get user-friendly name for display
            $displayName = switch ($varName) {
                "user_public_ip" { "1. Public IP" }
                "public_domain_name" { "2. Public Domain Name" }
                "private_domain_name" { "3. Private Domain Name" }
                "object_storage_access_key_id" { "4. Auth Access Key" }
                "object_storage_secret_access_key" { "5. Auth Secret Key" }
                "object_storage_bucket_string" { "6. Account ID" }
                "keypair_name" { "7. Keypair Name" }
                default { $varName }
            }

            Write-Host "  " -NoNewline
            Write-Host $displayName -ForegroundColor Yellow -NoNewline
            Write-Host ": " -NoNewline
            Write-Host $value -ForegroundColor Green
        }

        Write-Host ""
        Write-Host -NoNewline "Would you like to confirm and proceed? " -ForegroundColor White
        Write-Host -NoNewline "[Y/n/r(retry)]: " -ForegroundColor Yellow
        $confirmation = Read-Host

        if ($confirmation -match "^[Nn]$") {
            Write-Host ""
            Yellow "Options:"
            Write-Host "- Press Enter or 'Y' to proceed with current configuration"
            Write-Host "- Type 'r' to modify variables again"
            Write-Host "- Type 'q' to quit"
            Write-Host -NoNewline "Choice: " -ForegroundColor White
            $choice = Read-Host

            if ($choice -match "^[Qq]$") {
                Write-Host "Configuration cancelled by user." -ForegroundColor Red
                exit 1
            } elseif ($choice -match "^[Rr]$") {
                return "retry"
            } else {
                Write-Success "Configuration confirmed! Proceeding with deployment..."
                return "confirmed"
            }
        } elseif ($confirmation -match "^[Rr]$") {
            return "retry"
        } else {
            Write-Success "Configuration confirmed! Proceeding with deployment..."
            return "confirmed"
        }
    } while ($true)
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

    # Create backup in lab_logs directory
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $LogsDir "variables.tf.backup.$timestamp"

    # Ensure lab_logs directory exists
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }

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

    Write-Info "📄 Generating variables.json..."

    # Create comprehensive variables structure
    $variablesData = @{
        "_variable_classification" = @{
            description = "ceweb application variable classification system"
            categories = @{
                user_input = "Variables that users input interactively during deployment"
                ceweb_required = "Variables required by ceweb application for business logic and database connections"
                terraform_infra = "Variables used by terraform for infrastructure deployment"
            }
        }
        "config_metadata" = @{
            version = "4.1.0"
            created = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            description = "Samsung Cloud Platform Database Service Configuration with DBaaS"
            usage = "This file contains all environment-specific settings for the application deployment"
            generator = "variables_manager.ps1"
            template_source = "variables.tf"
        }
        "user_input_variables" = @{
            _comment = "Variables that users input interactively during deployment"
            _source = "variables.tf USER_INPUT category"
        }
        "ceweb_required_variables" = @{
            _comment = "Variables required by ceweb application for business logic and functionality"
            _source = "variables.tf CEWEB_REQUIRED category"
            "_database_connection" = @{
                database_password = if ($CewebRequiredVars["database_password"]) { $CewebRequiredVars["database_password"] } else { "cedbadmin123!" }
                db_ssl_enabled = $false
                db_pool_min = 20
                db_pool_max = 100
                db_pool_idle_timeout = 30000
                db_pool_connection_timeout = 60000
            }
        }
        "terraform_infra_variables" = @{
            _comment = "Variables used by terraform for infrastructure deployment"
            _source = "variables.tf TERRAFORM_INFRA category"

            # Include db_ip2 for Active-Standby configuration
            db_ip2 = "10.1.3.33"
        }
    }

    # Add user input variables
    foreach ($key in $UserInputVars.Keys) {
        $variablesData.user_input_variables[$key] = $UserInputVars[$key]
    }

    # Add ceweb required variables with dynamic database_host
    foreach ($key in $CewebRequiredVars.Keys) {
        if ($key -ne "database_password") {  # Already added to _database_connection
            if ($key -eq "database_host") {
                # Dynamically generate database_host from private_domain_name
                $privateDomain = $UserInputVars["private_domain_name"]
                if ($privateDomain) {
                    $variablesData.ceweb_required_variables[$key] = "db.$privateDomain"
                    Write-Info "Generated dynamic database_host: db.$privateDomain"
                } else {
                    # Fallback to default if private_domain_name not found
                    $variablesData.ceweb_required_variables[$key] = "db.internal.local"
                    Write-Warning "private_domain_name not found, using default: db.internal.local"
                }
            } else {
                $variablesData.ceweb_required_variables[$key] = $CewebRequiredVars[$key]
            }
        }
    }

    # Save to file
    $variablesData | ConvertTo-Json -Depth 10 | Set-Content $VariablesJson -Encoding UTF8

    Write-Success "Generated variables.json"
    Write-Info "File: $VariablesJson"
}

# Reset user input variables to defaults
function Reset-UserInputVariables {
    Write-Info "🔄 Resetting user input variables to default values..."

    $defaultValuesFile = Resolve-Path (Join-Path $ProjectDir "..\common-script\default_user_input_values.json")

    # Check if default values file exists
    if (!(Test-Path $defaultValuesFile)) {
        Write-Error "Default values file not found: $defaultValuesFile"
        return $false
    }

    # Load default values
    try {
        $defaultValues = Get-Content $defaultValuesFile | ConvertFrom-Json
        Write-Info "Loaded default values from: $defaultValuesFile"
    } catch {
        Write-Error "Failed to parse default values file: $($_.Exception.Message)"
        return $false
    }

    # Create backup in lab_logs directory
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $LogsDir "variables.tf.backup.reset.$timestamp"

    # Ensure lab_logs directory exists
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }

    Copy-Item $VariablesTf $backupFile
    Write-Info "Backup created: $backupFile"

    # Read current variables.tf content
    $content = Get-Content $VariablesTf -Raw

    # Reset each user input variable to its default value
    foreach ($varName in $defaultValues.user_input_variables.PSObject.Properties.Name) {
        $defaultValue = $defaultValues.user_input_variables.$varName

        # Pattern to match the variable block and replace the default value
        $pattern = '(?s)(variable\s+"' + [regex]::Escape($varName) + '"\s*\{[^}]*?default\s*=\s*)"[^"]*"([^}]*?\})'
        $replacement = '${1}"' + $defaultValue + '"${2}'

        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacement
            Write-Info "Reset $varName to: $defaultValue"
        } else {
            Write-Warning "Could not find variable pattern for: $varName"
        }
    }

    # Write updated content back to variables.tf
    Set-Content -Path $VariablesTf -Value $content -Encoding UTF8

    Write-Success "✅ User input variables reset to default values"
    Write-Info "Original file backed up as: $(Split-Path -Leaf $backupFile)"

    return $true
}

# Removed Update-VariablesTfWithImageEngineIds function - IDs now hardcoded in variables.tf


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
    Write-Info "📁 Generated file:"
    Write-Info "  • variables.json: $VariablesJson"
    Write-Info "Next step: Run userdata_manager.ps1 to generate UserData files"

    return 0
}

# Set debug mode
if ($Debug) {
    $env:DEBUG_MODE = "true"
}

# Run appropriate function based on parameters
try {
    if ($Reset) {
        # Direct reset without user interaction
        if (Reset-UserInputVariables) {
            Write-Success "✅ Variables reset completed successfully!"
            exit 0
        } else {
            Write-Error "❌ Variables reset failed!"
            exit 1
        }
    } else {
        # Normal interactive mode
        exit (Main)
    }
} catch {
    Write-Error "Variables processing failed: $($_.Exception.Message)"
    exit 1
}