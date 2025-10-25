########################################################
# DEPRECATION NOTICE: Image ID lookups are now handled
# by Terraform data sources. The scpcli image lookup
# functionality in this script has been deprecated.
# See main.tf for the new data source implementation.
########################################################
# Samsung Cloud Platform v2 - SCP CLI Helper Functions
# Handles SCP CLI integration and caching for image/engine IDs
#
# Author: SCPv2 Team

$ErrorActionPreference = "Stop"

# Check if SCP CLI is available
function Test-ScpCliAvailability {
    try {
        $result = & "D:\scpv2cli\scpcli" --version 2>$null
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

# Load cached image/engine data
function Get-CachedImageEngineData {
    if (Test-Path $ImageEngineJson) {
        try {
            $data = Get-Content $ImageEngineJson -Raw | ConvertFrom-Json
            Write-Success "Loaded cached image/engine data"
            return $data
        } catch {
            Write-Warning "Failed to load cached data: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "No cached image/engine data found"
    }
    return $null
}

# Refresh image and engine data from SCP CLI
function Update-ImageEngineCache {
    $cliAvailable = Test-ScpCliAvailability
    
    if ($cliAvailable) {
        try {
            Write-Info "Refreshing image and engine data from SCP CLI..."
            
            $imageEngineData = @{
                postgresql_engines = @()
                cachestore_engines = @()
                virtualserver_images = @{
                    rocky = @()
                    windows = @()
                }
                metadata = @{
                    cache_ttl_hours = 24
                    scpcli_available = $cliAvailable
                    generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                }
            }
            
            # Get Virtual Server Images
            Write-Info "Fetching virtual server images..."
            # DEPRECATED: $imagesOutput = & "D:\scpv2cli\scpcli" virtualserver image list --output json 2>$null
            if ($LASTEXITCODE -eq 0 -and $imagesOutput) {
                $images = $imagesOutput | ConvertFrom-Json
                
                # DEPRECATED: Image lookup now handled by Terraform data sources
# foreach ($image in $images) {
                    $imageInfo = @{
                        status = $image.status
                        os_distro = $image.os_distro
                        name = $image.name
                        id = $image.id
                        scp_os_version = $image.scp_os_version
                    }
                    
                    if ($image.os_distro -eq "rocky") {
                        $imageEngineData.virtualserver_images.rocky += $imageInfo
                    } elseif ($image.os_distro -eq "windows") {
                        $imageEngineData.virtualserver_images.windows += $imageInfo
                    }
                }
            }
            
            # Get PostgreSQL Engine Versions
            Write-Info "Fetching PostgreSQL engine versions..."
            $pgEnginesOutput = & "D:\scpv2cli\scpcli" postgresql engine version list --output json 2>$null
            if ($LASTEXITCODE -eq 0 -and $pgEnginesOutput) {
                $pgEngines = $pgEnginesOutput | ConvertFrom-Json
                
                foreach ($engine in $pgEngines) {
                    $engineInfo = @{
                        id = $engine.id
                        name = $engine.name
                        is_latest = $engine.is_latest
                        major_version = $engine.major_version
                        end_of_service = $engine.end_of_service
                        software_version = $engine.software_version
                    }
                    $imageEngineData.postgresql_engines += $engineInfo
                }
            }
            
            # Get CacheStore Engine Versions
            Write-Info "Fetching CacheStore engine versions..."
            $cacheEnginesOutput = & "D:\scpv2cli\scpcli" cachestore engine version list --output json 2>$null
            if ($LASTEXITCODE -eq 0 -and $cacheEnginesOutput) {
                $cacheEngines = $cacheEnginesOutput | ConvertFrom-Json
                
                foreach ($engine in $cacheEngines) {
                    $engineInfo = @{
                        id = $engine.id
                        name = $engine.name
                        is_latest = $engine.is_latest
                        major_version = $engine.major_version
                        end_of_service = $engine.end_of_service
                        software_version = $engine.software_version
                    }
                    $imageEngineData.cachestore_engines += $engineInfo
                }
            }
            
            # Save to cache file
            $jsonString = $imageEngineData | ConvertTo-Json -Depth 10
            $jsonString | Out-File -FilePath $ImageEngineJson -Encoding UTF8
            
            Write-Success "Successfully updated image/engine cache"
            return $imageEngineData
            
        } catch {
            Write-Error "Failed to refresh cache: $($_.Exception.Message)"
            return Get-CachedImageEngineData
        }
    } else {
        # Return fallback data structure
        return @{
            postgresql_engines = @()
            cachestore_engines = @()
            virtualserver_images = @{
                rocky = @()
                windows = @()
            }
            metadata = @{
                cache_ttl_hours = 24
                scpcli_available = $false
                generated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
        }
    }
}
