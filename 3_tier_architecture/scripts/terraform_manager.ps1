# Samsung Cloud Platform v2 - Terraform Manager
# Handles Terraform operations (init, validate, plan, apply, destroy)
#
# Author: SCPv2 Team

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Terraform API 로깅 설정 함수
function Set-TerraformLogging {
    # 로그 디렉토리 생성
    if (-not (Test-Path "terraform_log")) {
        New-Item -ItemType Directory -Path "terraform_log" -Force | Out-Null
    }
    
    # 다음 trial 번호 찾기
    $trialNum = 1
    while (Test-Path "terraform_log\trial$('{0:D2}' -f $trialNum).log") {
        $trialNum++
    }
    
    $logFile = "terraform_log\trial$('{0:D2}' -f $trialNum).log"
    
    # Terraform 환경변수 설정 (모든 API 통신 로그 기록)
    $env:TF_LOG = "TRACE"
    $env:TF_LOG_PATH = $logFile
    
    Write-Host "✓ Terraform API logging enabled: $logFile" -ForegroundColor Cyan
    Write-Host "  - All provider API requests and responses will be logged" -ForegroundColor Gray
    Write-Host ""
    
    return $logFile
}

function Initialize-Terraform {
    # First initialize terraform if needed
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
    }
}

function Test-Prerequisites {
    # Check if main.tf exists
    if (-not (Test-Path "main.tf")) {
        throw "main.tf file not found. Please run script in terraform directory."
    }

    # Check if terraform is installed
    $terraformVersion = terraform version 2>$null
    if (-not $terraformVersion) {
        throw "Terraform is not installed or not in PATH"
    }
    Write-Host "✓ Terraform found: $($terraformVersion[0])" -ForegroundColor Green
}

function Start-TerraformDeployment {
    # Step 1: Terraform Validate (skip init since we already did it)
    Write-Host "[1/3] Running terraform validate..." -ForegroundColor Cyan
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "terraform validate failed"
    }
    Write-Host "✓ Success: terraform validate completed" -ForegroundColor Green
    Write-Host ""

    # Step 2: Terraform Plan
    Write-Host "[2/3] Running terraform plan..." -ForegroundColor Cyan
    terraform plan -out=tfplan
    if ($LASTEXITCODE -ne 0) {
        throw "terraform plan failed"
    }
    Write-Host "✓ Success: terraform plan completed" -ForegroundColor Green
    Write-Host ""

    # Step 3: Terraform Apply (with confirmation and retry)
    Write-Host "[3/3] Ready to deploy infrastructure..." -ForegroundColor Cyan
    Write-Host "Warning: This will create real resources on Samsung Cloud Platform!" -ForegroundColor Yellow
    
    do {
        $confirmation = Read-Host "Do you want to continue? (y/N)"
        $confirmation = $confirmation.Trim().ToLower()
        
        if ($confirmation -eq 'y' -or $confirmation -eq 'yes' -or $confirmation -eq '네' -or $confirmation -eq 'ㅇ') {
            $proceed = $true
            break
        }
        elseif ($confirmation -eq 'n' -or $confirmation -eq 'no' -or $confirmation -eq '' -or $confirmation -eq '아니오' -or $confirmation -eq 'ㄴ') {
            $proceed = $false
            break
        }
        else {
            Write-Host "Invalid input. Please enter 'y' for yes or 'n' for no (Korean: '네' or '아니오')" -ForegroundColor Yellow
        }
    } while ($true)
    
    if ($proceed) {
        Write-Host "Starting terraform apply..." -ForegroundColor Cyan
        terraform apply --auto-approve tfplan
        if ($LASTEXITCODE -ne 0) {
            throw "terraform apply failed"
        }
        
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "Deployed Resources:" -ForegroundColor Yellow
        Write-Host "* VPC: VPC1 (10.1.0.0/16)" -ForegroundColor White
        Write-Host "* Subnets: 3 (Web, App, DB tiers)" -ForegroundColor White
        Write-Host "* Security Groups: 4" -ForegroundColor White
        Write-Host "* Virtual Servers: 6" -ForegroundColor White
        Write-Host "* Load Balancers: 2" -ForegroundColor White
        Write-Host "* Public IPs: 4" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "1. Wait 10-15 minutes for application installation" -ForegroundColor White
        Write-Host "2. Check VM logs via SSH" -ForegroundColor White
        Write-Host "3. Access web application via Load Balancer IP" -ForegroundColor White
        
        return $true
    }
    else {
        Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
        return $false
    }
}