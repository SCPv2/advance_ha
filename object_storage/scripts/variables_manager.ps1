# Samsung Cloud Platform v2 - Variables Manager (PowerShell)
# Converts variables.tf to variables.json and handles user input
#
# Usage:
#   .\variables_manager.ps1                    # Use cache if available, fetch if not
#   .\variables_manager.ps1 -RefreshCache      # Force refresh image/engine data from SCP CLI
#   .\variables_manager.ps1 -Debug             # Enable debug output
#
# Based on: deploy_with_standardized_userdata.ps1 variable processing logic
# Author: SCPv2 Team

param(
    [switch]$Debug,
    [switch]$RefreshCache,
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$VariablesTf = Join-Path $ProjectDir "variables.tf"
$VariablesJson = Join-Path $ScriptDir "variables.json"
$ImageEngineJson = Resolve-Path (Join-Path $ProjectDir "..\common-script\image_engine_id.json")

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

# Check if scpcli is available
function Test-ScpCliAvailability {
    try {
        $result = & scpcli --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Samsung Cloud Platform CLI is available"
            return $true
        }
    } catch {
        Write-Warning "Samsung Cloud Platform CLI not found or not accessible"
        Write-Warning "Using cached image/engine IDs if available"
        return $false
    }
    return $false
}

# Get image and engine IDs from SCP CLI
function Get-ScpImageEngineIds {
    Write-Info "🔍 Retrieving image and engine IDs from Samsung Cloud Platform..."
    
    $cliAvailable = Test-ScpCliAvailability
    $imageEngineData = @{
        metadata = @{
            generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            scpcli_available = $cliAvailable
            cache_ttl_hours = 24
        }
        virtualserver_images = @{
            windows = @()
            rocky = @()
        }
        postgresql_engines = @()
        cachestore_engines = @()
    }
    
    if ($cliAvailable) {
        try {
            # Get Virtual Server Images
            Write-Info "Fetching virtual server images..."
            $imagesOutput = & scpcli virtualserver image list -f json 2>$null
            if ($LASTEXITCODE -eq 0 -and $imagesOutput) {
                $images = $imagesOutput | ConvertFrom-Json
                
                foreach ($image in $images) {
                    if ($image.status -eq "active") {
                        $imageEntry = @{
                            id = $image.id
                            name = $image.name
                            os_distro = $image.os_distro
                            scp_os_version = $image.scp_os_version
                            status = $image.status
                        }
                        
                        if ($image.os_distro -eq "windows") {
                            $imageEngineData.virtualserver_images.windows += $imageEntry
                        } elseif ($image.os_distro -eq "rocky") {
                            $imageEngineData.virtualserver_images.rocky += $imageEntry
                        }
                    }
                }
                Write-Success "Retrieved $(($imageEngineData.virtualserver_images.windows + $imageEngineData.virtualserver_images.rocky).Count) virtual server images"
            }
            
            # Get PostgreSQL Engine Versions
            Write-Info "Fetching PostgreSQL engine versions..."
            $pgEnginesOutput = & scpcli postgresql engine version list -f json 2>$null
            if ($LASTEXITCODE -eq 0 -and $pgEnginesOutput) {
                $pgEngines = $pgEnginesOutput | ConvertFrom-Json
                
                foreach ($engine in $pgEngines) {
                    if ($engine.end_of_service -eq $false) {
                        $engineEntry = @{
                            id = $engine.id
                            name = $engine.name
                            major_version = $engine.major_version
                            software_version = $engine.software_version
                            end_of_service = $engine.end_of_service
                            is_latest = $false  # Will be determined later
                        }
                        $imageEngineData.postgresql_engines += $engineEntry
                    }
                }
                
                # Mark the latest version
                if ($imageEngineData.postgresql_engines.Count -gt 0) {
                    $latestEngine = $imageEngineData.postgresql_engines | Sort-Object software_version -Descending | Select-Object -First 1
                    $latestEngine.is_latest = $true
                }
                
                Write-Success "Retrieved $($imageEngineData.postgresql_engines.Count) PostgreSQL engine versions"
            }
            
            # Get CacheStore Engine Versions
            Write-Info "Fetching CacheStore engine versions..."
            $cacheEnginesOutput = & scpcli cachestore engine version list -f json 2>$null
            if ($LASTEXITCODE -eq 0 -and $cacheEnginesOutput) {
                $cacheEngines = $cacheEnginesOutput | ConvertFrom-Json
                
                foreach ($engine in $cacheEngines) {
                    if ($engine.status -eq "active") {
                        $engineEntry = @{
                            id = $engine.id
                            version = $engine.version
                            type = $engine.type
                            status = $engine.status
                        }
                        $imageEngineData.cachestore_engines += $engineEntry
                    }
                }
                Write-Success "Retrieved $($imageEngineData.cachestore_engines.Count) CacheStore engine versions"
            }
            
        } catch {
            Write-Warning "Error retrieving data from SCP CLI: $($_.Exception.Message)"
            Write-Warning "Falling back to cached data if available"
        }
    }
    
    return $imageEngineData
}

# Load cached image/engine data
function Get-CachedImageEngineData {
    if (Test-Path $ImageEngineJson) {
        try {
            $jsonData = Get-Content $ImageEngineJson | ConvertFrom-Json
            # Convert PSCustomObject to Hashtable manually for PowerShell compatibility
            $cachedData = @{
                metadata = @{
                    generated = $jsonData.metadata.generated
                    scpcli_available = $jsonData.metadata.scpcli_available
                    cache_ttl_hours = $jsonData.metadata.cache_ttl_hours
                }
                virtualserver_images = @{
                    windows = @()
                    rocky = @()
                }
                postgresql_engines = @()
                cachestore_engines = @()
            }
            
            # Convert arrays
            if ($jsonData.virtualserver_images.windows) {
                foreach ($img in $jsonData.virtualserver_images.windows) {
                    $cachedData.virtualserver_images.windows += @{
                        id = $img.id
                        name = $img.name
                        os_distro = $img.os_distro
                        scp_os_version = $img.scp_os_version
                        status = $img.status
                    }
                }
            }
            if ($jsonData.virtualserver_images.rocky) {
                foreach ($img in $jsonData.virtualserver_images.rocky) {
                    $cachedData.virtualserver_images.rocky += @{
                        id = $img.id
                        name = $img.name
                        os_distro = $img.os_distro
                        scp_os_version = $img.scp_os_version
                        status = $img.status
                    }
                }
            }
            if ($jsonData.postgresql_engines) {
                foreach ($engine in $jsonData.postgresql_engines) {
                    $cachedData.postgresql_engines += @{
                        id = $engine.id
                        name = $engine.name
                        major_version = $engine.major_version
                        software_version = $engine.software_version
                        end_of_service = $engine.end_of_service
                        is_latest = $engine.is_latest
                    }
                }
            }
            $cacheAge = (Get-Date) - [datetime]$cachedData.metadata.generated
            
            if ($cacheAge.TotalHours -lt $cachedData.metadata.cache_ttl_hours) {
                Write-Info "Using cached image/engine data (age: $([math]::Round([math]::Abs($cacheAge.TotalHours), 1)) hours)"
                return $cachedData
            } else {
                Write-Warning "Cached data is older than TTL ($($cachedData.metadata.cache_ttl_hours) hours)"
            }
        } catch {
            Write-Warning "Error reading cached data: $($_.Exception.Message)"
        }
    }
    return $null
}

# Update image/engine IDs cache
function Update-ImageEngineCache {
    Write-Info "🔄 Checking image/engine IDs cache..."
    
    # Check if force refresh is requested
    if ($RefreshCache) {
        Write-Info "Force refresh requested, fetching fresh data from SCP CLI..."
        $freshData = Get-ScpImageEngineIds
    } else {
        # Check if cache file exists and is valid
        $cachedData = Get-CachedImageEngineData
        if ($cachedData) {
            Write-Info "Using existing image/engine cache (age: $([math]::Round([math]::Abs(((Get-Date) - [datetime]$cachedData.metadata.generated).TotalHours), 1)) hours)"
            return $cachedData
        }
        
        # Cache doesn't exist or is invalid, fetch fresh data
        Write-Info "Cache not found or invalid, fetching fresh data from SCP CLI..."
        $freshData = Get-ScpImageEngineIds
    }
    
    # If we got fresh data, save it
    if ($freshData.virtualserver_images.windows.Count -gt 0 -or 
        $freshData.virtualserver_images.rocky.Count -gt 0 -or 
        $freshData.postgresql_engines.Count -gt 0) {
        
        $freshData | ConvertTo-Json -Depth 10 | Set-Content $ImageEngineJson -Encoding UTF8
        Write-Success "Created new image/engine cache: $ImageEngineJson"
        return $freshData
    }
    
    # Last resort: create minimal default data
    Write-Error "No fresh data available and no valid cache. Creating minimal fallback data."
    $fallbackData = @{
        metadata = @{
            generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            scpcli_available = $false
            cache_ttl_hours = 24
            fallback_mode = $true
        }
        virtualserver_images = @{
            windows = @(@{
                id = "fallback-windows-id"
                name = "Windows Server 2022 Std."
                os_distro = "windows"
                scp_os_version = "2022 Std."
                status = "active"
            })
            rocky = @(@{
                id = "fallback-rocky-id"
                name = "Rocky Linux 9.4"
                os_distro = "rocky"
                scp_os_version = "9.4"
                status = "active"
            })
        }
        postgresql_engines = @(@{
            id = "8a463aa4b1dc4f279c3f53b94dc45e74"
            version = "16.8"
            type = "PostgreSQL Community"
            status = "active"
            is_latest = $true
        })
        cachestore_engines = @()
    }
    
    $fallbackData | ConvertTo-Json -Depth 10 | Set-Content $ImageEngineJson -Encoding UTF8
    Write-Warning "Created fallback image/engine data"
    return $fallbackData
}

# Get best matching image ID
function Get-ImageId {
    param(
        [hashtable]$ImageEngineData,
        [string]$OsDistro,
        [string]$OsVersion
    )
    
    $images = $ImageEngineData.virtualserver_images.$OsDistro
    
    if ($images -and $images.Count -gt 0) {
        # Find exact version match manually to avoid PowerShell pipeline issues
        $matchedImage = $null
        foreach ($img in $images) {
            if ($img.scp_os_version -eq $OsVersion) {
                $matchedImage = $img
                break
            }
        }
        
        if ($matchedImage) {
            return $matchedImage.id
        }
        
        # Return first available image for the OS
        return $images[0].id
    }
    
    Write-Warning "No image found for OS: $OsDistro, Version: $OsVersion"
    return "image-not-found"
}

# Get latest PostgreSQL engine ID
function Get-PostgreSQLEngineId {
    param([hashtable]$ImageEngineData)
    
    $engines = $ImageEngineData.postgresql_engines
    if ($engines -and $engines.Count -gt 0) {
        # Try to find latest marked engine
        $latestEngine = $engines | Where-Object { $_.is_latest -eq $true }
        if ($latestEngine) {
            return $latestEngine.id
        }
        
        # Fall back to first engine
        return $engines[0].id
    }
    
    Write-Warning "No PostgreSQL engine found"
    return "postgresql-engine-not-found"
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
                "database_password" = "cedbadmin123"
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

# Update variables.tf with image/engine IDs
function Update-VariablesTfWithImageEngineIds {
    param([hashtable]$ImageEngineData)
    
    Write-Info "📝 Updating variables.tf with latest image/engine IDs..."
    
    $content = Get-Content $VariablesTf -Raw
    
    # Get current image variables from variables.tf for matching
    $windowsOsDistro = "windows"
    $windowsOsVersion = "2022 Std."
    $rockyOsDistro = "rocky" 
    $rockyOsVersion = "9.4"
    
    # Extract current OS versions from variables.tf if possible
    if ($content -match 'variable\s+"image_windows_scp_os_version"[^}]*default\s*=\s*"([^"]*)"') {
        $windowsOsVersion = $matches[1]
    }
    if ($content -match 'variable\s+"image_rocky_scp_os_version"[^}]*default\s*=\s*"([^"]*)"') {
        $rockyOsVersion = $matches[1]
    }
    
    # Get appropriate IDs
    $windowsImageId = Get-ImageId $ImageEngineData $windowsOsDistro $windowsOsVersion
    $rockyImageId = Get-ImageId $ImageEngineData $rockyOsDistro $rockyOsVersion
    $postgresEngineId = Get-PostgreSQLEngineId $ImageEngineData
    
    Write-Info "Image IDs to inject:"
    Write-Info "  Windows ($windowsOsVersion): $windowsImageId"
    Write-Info "  Rocky ($rockyOsVersion): $rockyImageId"
    Write-Info "  PostgreSQL Engine: $postgresEngineId"
    
    # Create backup
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $LogsDir "variables.tf.backup.imageids.$timestamp"
    Copy-Item $VariablesTf $backupFile
    
    # Add image/engine ID variables to TERRAFORM_INFRASTRUCTURE_VARIABLES section
    $infrastructureSection = '########################################################
# 4. Terraform 인프라 변수 (TERRAFORM_INFRASTRUCTURE_VARIABLES)'
    
    if ($content -match [regex]::Escape($infrastructureSection)) {
        # Add new variables after the infrastructure section header
        $imageEngineVarsBlock = @"

# Image and Engine IDs (Auto-generated from SCP CLI)
variable "windows_image_id" {
  type        = string
  description = "Windows Server image ID [TERRAFORM_INFRA]"
  default     = "$windowsImageId"
}

variable "rocky_image_id" {
  type        = string
  description = "Rocky Linux image ID [TERRAFORM_INFRA]"
  default     = "$rockyImageId"
}

variable "postgresql_engine_id" {
  type        = string
  description = "PostgreSQL engine version ID [TERRAFORM_INFRA]"
  default     = "$postgresEngineId"
}
"@
        
        $insertAfter = $infrastructureSection + [Environment]::NewLine + '#    이 파트에는 새로운 변수를 추가할 수 있습니다.' + [Environment]::NewLine + '#    단, 이 파트의 변수는 main.tf에서만 사용됩니다.' + [Environment]::NewLine + '########################################################'
        
        # Only add if not already present
        if ($content -notmatch 'variable\s+"windows_image_id"') {
            $content = $content -replace [regex]::Escape($insertAfter), "$insertAfter$imageEngineVarsBlock"
        } else {
            # Update existing variables
            $content = $content -replace '(variable\s+"windows_image_id"[^}]*default\s*=\s*)"[^"]*"', "`$1`"$windowsImageId`""
            $content = $content -replace '(variable\s+"rocky_image_id"[^}]*default\s*=\s*)"[^"]*"', "`$1`"$rockyImageId`""
            $content = $content -replace '(variable\s+"postgresql_engine_id"[^}]*default\s*=\s*)"[^"]*"', "`$1`"$postgresEngineId`""
        }
        
        Set-Content -Path $VariablesTf -Value $content -Encoding UTF8
        Write-Success "Updated variables.tf with image/engine IDs"
    } else {
        Write-Warning "Could not find TERRAFORM_INFRASTRUCTURE_VARIABLES section in variables.tf"
        Write-Warning "Image/Engine IDs will be available in variables.json but not injected into variables.tf"
    }
}

# Enhanced JSON generation with image/engine data
function New-VariablesJson {
    param(
        [hashtable]$UserInputVars,
        [hashtable]$CewebRequiredVars,
        [hashtable]$ImageEngineData
    )
    
    Write-Info "📄 Generating variables.json with image/engine data..."
    
    # Get image/engine IDs
    $windowsImageId = Get-ImageId $ImageEngineData "windows" "2022 Std."
    $rockyImageId = Get-ImageId $ImageEngineData "rocky" "9.4"
    $postgresEngineId = Get-PostgreSQLEngineId $ImageEngineData
    
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
            description = "Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS"
            usage = "This file contains all environment-specific settings for the application deployment"
            generator = "variables_manager.ps1"
            template_source = "variables.tf"
            image_engine_cache = "image_engine_id.json"
        }
        "user_input_variables" = @{
            _comment = "Variables that users input interactively during deployment"
            _source = "variables.tf USER_INPUT category"
        }
        "ceweb_required_variables" = @{
            _comment = "Variables required by ceweb application for business logic and functionality"
            _source = "variables.tf CEWEB_REQUIRED category"
            "_database_connection" = @{
                database_password = $CewebRequiredVars["database_password"]
                db_ssl_enabled = $false
                db_pool_min = 20
                db_pool_max = 100
                db_pool_idle_timeout = 30000
                db_pool_connection_timeout = 60000
            }
        }
        "terraform_infra_variables" = @{
            _comment = "Variables used by terraform for infrastructure deployment"
            _source = "variables.tf TERRAFORM_INFRA category and SCP CLI"
            
            # Image IDs
            windows_image_id = $windowsImageId
            rocky_image_id = $rockyImageId
            postgresql_engine_id = $postgresEngineId
            
            # Include db_ip2 for Active-Standby configuration
            db_ip2 = "10.1.3.33"
        }
        "image_engine_metadata" = @{
            cache_file = "image_engine_id.json"
            last_updated = $ImageEngineData.metadata.generated
            scpcli_available = $ImageEngineData.metadata.scpcli_available
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
    
    Write-Success "Generated variables.json with image/engine integration"
    Write-Info "File: $VariablesJson"
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
    
    # Update image/engine IDs first
    Write-Info "🔄 Updating image and engine IDs..."
    $imageEngineData = Update-ImageEngineCache
    
    # Update variables.tf with latest IDs
    Update-VariablesTfWithImageEngineIds $imageEngineData
    
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
    
    # Generate variables.json with image/engine data
    New-VariablesJson $updatedUserVars $cewebRequiredVars $imageEngineData
    
    Write-Success "✅ Variables processing completed successfully!"
    Write-Info "📁 Generated files:"
    Write-Info "  • variables.json: $VariablesJson"
    Write-Info "  • image_engine_id.json: $ImageEngineJson"
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