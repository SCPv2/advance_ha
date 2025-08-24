# 실제로 작동하는 PowerShell userdata 업데이트 스크립트
# 사용자가 입력한 변수 값을 variables.tf 에서 읽어서 userdata 파일들에 실제로 반영

param(
    [string]$PublicDomain,
    [string]$PrivateDomain,
    [string]$UserPublicIP,
    [string]$KeypairName,
    [string]$PrivateHostedZoneId
)

function Update-VariablesTf {
    param($Variables)
    
    Write-Host "Updating variables.tf with new values..." -ForegroundColor Cyan
    
    if (Test-Path "variables.tf") {
        $content = Get-Content "variables.tf" -Raw
        
        # Update each variable's default value
        $content = $content -replace '(variable\s+"public_domain_name".*?default\s*=\s*)"[^"]*"', "`$1`"$($Variables.PublicDomain)`""
        $content = $content -replace '(variable\s+"private_domain_name".*?default\s*=\s*)"[^"]*"', "`$1`"$($Variables.PrivateDomain)`""
        $content = $content -replace '(variable\s+"user_public_ip".*?default\s*=\s*)"[^"]*"', "`$1`"$($Variables.UserPublicIP)`""
        $content = $content -replace '(variable\s+"keypair_name".*?default\s*=\s*)"[^"]*"', "`$1`"$($Variables.KeypairName)`""
        $content = $content -replace '(variable\s+"private_hosted_zone_id".*?default\s*=\s*)"[^"]*"', "`$1`"$($Variables.PrivateHostedZoneId)`""
        
        $content | Set-Content "variables.tf" -Encoding UTF8
        Write-Host "✓ variables.tf updated" -ForegroundColor Green
    }
}

function Update-UserdataFiles {
    param($Variables)
    
    Write-Host "Updating userdata files with actual variable values..." -ForegroundColor Cyan
    
    $files = @("userdata_db.sh", "userdata_app.sh", "userdata_web.sh")
    
    foreach ($file in $files) {
        if (Test-Path $file) {
            Write-Host "  Processing $file..." -ForegroundColor Yellow
            $content = Get-Content $file -Raw
            
            # Update bash variable definitions
            $content = $content -replace 'PUBLIC_DOMAIN_NAME="[^"]*"', "PUBLIC_DOMAIN_NAME=`"$($Variables.PublicDomain)`""
            $content = $content -replace 'PRIVATE_DOMAIN_NAME="[^"]*"', "PRIVATE_DOMAIN_NAME=`"$($Variables.PrivateDomain)`""
            $content = $content -replace 'USER_PUBLIC_IP="[^"]*"', "USER_PUBLIC_IP=`"$($Variables.UserPublicIP)`""
            $content = $content -replace 'KEYPAIR_NAME="[^"]*"', "KEYPAIR_NAME=`"$($Variables.KeypairName)`""
            $content = $content -replace 'PRIVATE_HOSTED_ZONE_ID="[^"]*"', "PRIVATE_HOSTED_ZONE_ID=`"$($Variables.PrivateHostedZoneId)`""
            
            # Update JSON configurations within the bash scripts
            $content = $content -replace '"public_domain_name":\s*"[^"]*"', "`"public_domain_name`": `"$($Variables.PublicDomain)`""
            $content = $content -replace '"private_domain_name":\s*"[^"]*"', "`"private_domain_name`": `"$($Variables.PrivateDomain)`""
            
            $content | Set-Content $file -NoNewline -Encoding UTF8
            Write-Host "  ✓ $file updated with variable values" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $file not found" -ForegroundColor Yellow
        }
    }
    
    Write-Host "✓ All userdata files updated successfully!" -ForegroundColor Green
}

# Main execution
if ($PublicDomain -and $PrivateDomain -and $UserPublicIP -and $KeypairName -and $PrivateHostedZoneId) {
    $Variables = @{
        PublicDomain = $PublicDomain
        PrivateDomain = $PrivateDomain
        UserPublicIP = $UserPublicIP
        KeypairName = $KeypairName
        PrivateHostedZoneId = $PrivateHostedZoneId
    }
    
    Write-Host "=== 실제 변수 업데이트 시작 ===" -ForegroundColor Green
    Write-Host "Public Domain: $PublicDomain" -ForegroundColor White
    Write-Host "Private Domain: $PrivateDomain" -ForegroundColor White
    Write-Host "User Public IP: $UserPublicIP" -ForegroundColor White
    Write-Host "Keypair Name: $KeypairName" -ForegroundColor White
    Write-Host "Private Zone ID: $PrivateHostedZoneId" -ForegroundColor White
    Write-Host ""
    
    Update-VariablesTf $Variables
    Update-UserdataFiles $Variables
    
    Write-Host "=== 업데이트 완료 ===" -ForegroundColor Green
} else {
    Write-Host "Usage: .\fix_userdata_real.ps1 -PublicDomain 'creative-energy.net' -PrivateDomain 'ceservice.net' -UserPublicIP '14.39.93.74' -KeypairName 'stkey' -PrivateHostedZoneId '9fa4151c-0dc8-4397-a22c-9797c3026cd2'" -ForegroundColor Yellow
}