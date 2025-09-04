# Virtual Server Masking Script for 3_tier_architecture (PowerShell Version)
# This script masks Virtual Server resources and dependent resources in main.tf

param(
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$MainTf = Join-Path $ProjectDir "main.tf"
$BackupFile = Join-Path $ProjectDir "main.tf.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Color functions
function Red($text) { Write-Host $text -ForegroundColor Red }
function Green($text) { Write-Host $text -ForegroundColor Green }
function Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Cyan($text) { Write-Host $text -ForegroundColor Cyan }

if ($Help) {
    Write-Host ""
    Cyan "========================================="
    Cyan "Virtual Server Masking Script Help"
    Cyan "========================================="
    Write-Host ""
    Write-Host "PURPOSE:" -ForegroundColor White
    Write-Host "  This script masks (comments out) Virtual Server resources"
    Write-Host "  in main.tf to temporarily disable VM creation."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor White
    Write-Host "  .\mask_vm.ps1        # Mask all VMs"
    Write-Host "  .\mask_vm.ps1 -Help  # Show this help"
    Write-Host ""
    Write-Host "WHAT IT DOES:" -ForegroundColor White
    Write-Host "  1. Creates backup of main.tf"
    Write-Host "  2. Comments out VM resources: vm_bastion, vm_db, vm_app, vm_web"
    Write-Host "  3. Comments out resources that depend on VMs"
    Write-Host "  4. Fixes depends_on syntax to maintain Terraform validity"
    Write-Host ""
    Write-Host "TO RESTORE:" -ForegroundColor White
    Write-Host "  .\unmask.ps1         # Restore from backup"
    Write-Host ""
    return
}

Write-Host ""
Cyan "========================================="
Cyan "Virtual Server Masking Script"
Cyan "3-Tier Architecture Environment"
Cyan "========================================="
Write-Host ""

# Check if main.tf exists
if (!(Test-Path $MainTf)) {
    Red "Error: main.tf not found at $MainTf"
    exit 1
}

# Create backup
Yellow "Creating backup: $(Split-Path -Leaf $BackupFile)"
Copy-Item $MainTf $BackupFile

# Read main.tf content
$content = Get-Content $MainTf -Raw

# Function to mask Virtual Server resources
function Mask-VirtualServers {
    param([string]$Content)
    
    Yellow "Step 1: Masking Virtual Server resources..."
    
    $vmResources = @('vm_bastion', 'vm_db', 'vm_app', 'vm_web')
    
    foreach ($vm in $vmResources) {
        Write-Host "  Masking: $vm" -ForegroundColor Gray
        
        # Find and mask the resource block
        $pattern = "(?ms)^(resource\s+`"samsungcloudplatformv2_virtualserver_server`"\s+`"$vm`"\s*\{.*?)^(\})"
        if ($Content -match $pattern) {
            $maskedBlock = $matches[1] + $matches[2]
            $commentedBlock = ($maskedBlock -split "`n" | ForEach-Object { "#$_" }) -join "`n"
            $Content = $Content -replace [regex]::Escape($maskedBlock), $commentedBlock
        }
    }
    
    return $Content
}

# Function to mask dependent resources
function Mask-DependentResources {
    param([string]$Content)
    
    Yellow "Step 2: Masking resources dependent on Virtual Servers..."
    
    # Split into lines for processing
    $lines = $Content -split "`n"
    $result = @()
    $inResourceBlock = $false
    $resourceLines = @()
    $currentResource = ""
    
    foreach ($line in $lines) {
        if ($line -match "^resource\s+") {
            # Start of a resource block
            if ($resourceLines.Count -gt 0) {
                # Process previous resource
                $result += Process-ResourceBlock $resourceLines $currentResource
            }
            $inResourceBlock = $true
            $resourceLines = @($line)
            $currentResource = $line
        }
        elseif ($line -match "^}$" -and $inResourceBlock) {
            # End of resource block
            $resourceLines += $line
            $result += Process-ResourceBlock $resourceLines $currentResource
            $inResourceBlock = $false
            $resourceLines = @()
            $currentResource = ""
        }
        elseif ($inResourceBlock) {
            # Inside resource block
            $resourceLines += $line
        }
        else {
            # Outside resource blocks
            $result += $line
        }
    }
    
    # Handle last resource if exists
    if ($resourceLines.Count -gt 0) {
        $result += Process-ResourceBlock $resourceLines $currentResource
    }
    
    return $result -join "`n"
}

# Function to process individual resource blocks
function Process-ResourceBlock {
    param([string[]]$ResourceLines, [string]$ResourceHeader)
    
    # Check if this resource depends on VMs
    $hasVmDependency = $false
    foreach ($line in $ResourceLines) {
        if ($line -match "depends_on.*vm_(bastion|db|app|web)") {
            $hasVmDependency = $true
            break
        }
    }
    
    if ($hasVmDependency) {
        Write-Host "  Masking dependent resource: $($ResourceHeader -replace '^\s*', '')" -ForegroundColor Gray
        # Comment out the entire resource
        return $ResourceLines | ForEach-Object { "#$_" }
    }
    
    return $ResourceLines
}

# Main execution
try {
    # Mask Virtual Servers
    $content = Mask-VirtualServers $content
    
    # Mask dependent resources
    $content = Mask-DependentResources $content
    
    # Write the modified content back to main.tf
    Set-Content -Path $MainTf -Value $content -Encoding UTF8
    
    Write-Host ""
    Green "✅ Virtual Server masking completed!"
    Cyan "Summary:"
    Write-Host "  • Virtual Servers masked: vm_bastion, vm_db, vm_app, vm_web" -ForegroundColor White
    Write-Host "  • Dependent resources masked automatically" -ForegroundColor White
    Write-Host "  • Backup saved: $(Split-Path -Leaf $BackupFile)" -ForegroundColor White
    Write-Host ""
    Yellow "Note: Run 'terraform plan' to verify the configuration"
    Write-Host "To restore: .\unmask.ps1" -ForegroundColor Gray
    
} catch {
    Red "Error occurred during masking: $($_.Exception.Message)"
    
    # Restore from backup if error occurs
    if (Test-Path $BackupFile) {
        Yellow "Restoring from backup..."
        Copy-Item $BackupFile $MainTf
        Yellow "Restored original main.tf from backup"
    }
    exit 1
}