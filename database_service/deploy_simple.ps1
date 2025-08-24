# Simplified deployment script that works
param(
    [switch]$TestMode
)

# Load the main script functions
. .\deploy_scp_lab_environment.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Samsung Cloud Platform v2 Variable Update" -ForegroundColor Cyan  
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Simple variable input
Write-Host "현재 variables.tf 변수 값들을 업데이트합니다:" -ForegroundColor Yellow
Write-Host ""

$variables = @{}

Write-Host "1. Public Domain Name 입력:"
$variables.public_domain_name = Read-Host "   값"

Write-Host "2. Private Domain Name 입력:" 
$variables.private_domain_name = Read-Host "   값"

Write-Host "3. User Public IP 입력:"
$variables.user_public_ip = Read-Host "   값"

Write-Host "4. Keypair Name 입력:"
$variables.keypair_name = Read-Host "   값"  

Write-Host "5. Private Hosted Zone ID 입력:"
$variables.private_hosted_zone_id = Read-Host "   값"

Write-Host ""
Write-Host "변수 업데이트를 시작합니다..." -ForegroundColor Green

# Call the working Update-UserdataFiles function
Update-UserdataFiles $variables

Write-Host ""
Write-Host "✅ 모든 파일이 업데이트되었습니다!" -ForegroundColor Green
Write-Host "- variables.tf" -ForegroundColor White
Write-Host "- userdata_db.sh" -ForegroundColor White  
Write-Host "- userdata_app.sh" -ForegroundColor White
Write-Host "- userdata_web.sh" -ForegroundColor White