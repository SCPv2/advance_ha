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
    Write-Success "✅ UserData generation completed successfully!"
    Write-Info ""
    Write-Info "Next step: Run terraform_manager.ps1 to deploy infrastructure"
}

# Execute main function
if ($MyInvocation.InvocationName -ne '.') {
    Main
}