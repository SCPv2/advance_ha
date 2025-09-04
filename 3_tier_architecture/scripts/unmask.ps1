# Virtual Server Unmasking Script for 3_tier_architecture (PowerShell Version)
# This script restores Virtual Server resources from the latest backup

param(
    [switch]$Help,
    [string]$BackupFile
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$MainTf = Join-Path $ProjectDir "main.tf"

# Color functions
function Red($text) { Write-Host $text -ForegroundColor Red }
function Green($text) { Write-Host $text -ForegroundColor Green }
function Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Cyan($text) { Write-Host $text -ForegroundColor Cyan }

if ($Help) {
    Write-Host ""
    Cyan "========================================="
    Cyan "Virtual Server Unmasking Script Help"
    Cyan "========================================="
    Write-Host ""
    Write-Host "PURPOSE:" -ForegroundColor White
    Write-Host "  This script restores Virtual Server resources from backup"
    Write-Host "  to re-enable VM creation in main.tf."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor White
    Write-Host "  .\unmask.ps1                           # Restore from latest backup"
    Write-Host "  .\unmask.ps1 -BackupFile backup.tf     # Restore from specific backup"
    Write-Host "  .\unmask.ps1 -Help                     # Show this help"
    Write-Host ""
    Write-Host "WHAT IT DOES:" -ForegroundColor White
    Write-Host "  1. Finds latest main.tf.backup.* file (or uses specified backup)"
    Write-Host "  2. Restores main.tf from backup"
    Write-Host "  3. Re-enables all VM resources and dependencies"
    Write-Host ""
    return
}

Write-Host ""
Cyan "========================================="
Cyan "Virtual Server Unmasking Script"
Cyan "3-Tier Architecture Environment"
Cyan "========================================="
Write-Host ""

# Check if main.tf exists
if (!(Test-Path $MainTf)) {
    Red "Error: main.tf not found at $MainTf"
    exit 1
}

# Find backup file
if ($BackupFile) {
    if (!(Test-Path $BackupFile)) {
        Red "Error: Specified backup file not found: $BackupFile"
        exit 1
    }
    $RestoreFrom = $BackupFile
} else {
    # Find latest backup
    $backupFiles = Get-ChildItem -Path $ProjectDir -Name "main.tf.backup.*" | Sort-Object -Descending
    
    if ($backupFiles.Count -eq 0) {
        Red "Error: No backup files found in $ProjectDir"
        Red "Backup files should be named: main.tf.backup.YYYYMMDD_HHMMSS"
        exit 1
    }
    
    $RestoreFrom = Join-Path $ProjectDir $backupFiles[0]
}

# Show backup info
Yellow "Restoring from backup: $(Split-Path -Leaf $RestoreFrom)"
$backupDate = (Get-Item $RestoreFrom).LastWriteTime
Write-Host "Backup created: $backupDate" -ForegroundColor Gray

# Confirm restoration
Write-Host ""
Write-Host "This will restore main.tf and re-enable all Virtual Servers." -ForegroundColor White
Write-Host -NoNewline "Do you want to continue? [Y/n]: " -ForegroundColor Yellow
$confirmation = Read-Host

if ($confirmation -match "^[Nn]$") {
    Yellow "Operation cancelled by user."
    exit 0
}

try {
    # Create a backup of current state before restore
    $currentBackup = Join-Path $ProjectDir "main.tf.pre-unmask.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $MainTf $currentBackup
    Write-Host "Current state backed up to: $(Split-Path -Leaf $currentBackup)" -ForegroundColor Gray
    
    # Restore from backup
    Copy-Item $RestoreFrom $MainTf
    
    Write-Host ""
    Green "✅ Virtual Server unmasking completed!"
    Cyan "Summary:"
    Write-Host "  • main.tf restored from backup" -ForegroundColor White
    Write-Host "  • All Virtual Servers re-enabled: vm_bastion, vm_db, vm_app, vm_web" -ForegroundColor White
    Write-Host "  • Dependent resources re-enabled" -ForegroundColor White
    Write-Host "  • Previous state backed up: $(Split-Path -Leaf $currentBackup)" -ForegroundColor White
    Write-Host ""
    Yellow "Note: Run 'terraform plan' to verify the restored configuration"
    
} catch {
    Red "Error occurred during unmasking: $($_.Exception.Message)"
    exit 1
}