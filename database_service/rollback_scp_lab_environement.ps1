# PowerShell 에러 처리 설정
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Terraform API 로깅 설정 함수
function Set-TerraformLogging {
    # 로그 디렉토리 생성
    if (-not (Test-Path "terraform_log")) {
        New-Item -ItemType Directory -Path "terraform_log" -Force | Out-Null
    }
    
    # 다음 rollback 번호 찾기
    $rollbackNum = 1
    while (Test-Path "terraform_log\rollback$('{0:D2}' -f $rollbackNum).log") {
        $rollbackNum++
    }
    
    $logFile = "terraform_log\rollback$('{0:D2}' -f $rollbackNum).log"
    
    # Terraform 환경변수 설정 (모든 API 통신 로그 기록)
    $env:TF_LOG = "TRACE"
    $env:TF_LOG_PATH = $logFile
    
    Write-Host "✓ Terraform API logging enabled: $logFile" -ForegroundColor Cyan
    Write-Host "  - All provider API requests and responses will be logged" -ForegroundColor Gray
    Write-Host ""
    
    return $logFile
}

# Terraform 변수 값을 읽어오는 함수
function Get-TerraformVariable {
    param($VarName)
    try {
        $result = echo "var.$VarName" | terraform console
        if ($LASTEXITCODE -eq 0) {
            return $result.Trim().Trim('"')
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

# 변수를 기본값으로 복구하는 함수
function Reset-VariableInFile {
    param($VarName, $DefaultValue)
    try {
        $content = Get-Content "variables.tf" -Raw
        $pattern = "(variable\s+`"$VarName`"\s*\{[^}]*?default\s*=\s*)`"[^`"]*`""
        $replacement = "`${1}`"$DefaultValue`""
        $newContent = $content -replace $pattern, $replacement
        $newContent | Set-Content "variables.tf" -NoNewline
        return $true
    }
    catch {
        Write-Host "❌ Failed to reset variable $VarName : $_" -ForegroundColor Red
        return $false
    }
}

# 개별 파일 삭제 함수
function Remove-FileIfExists {
    param($FilePath, $Description)
    if (Test-Path $FilePath) {
        try {
            Remove-Item $FilePath -Force
            Write-Host "✓ Deleted: $Description" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to delete $Description : $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "○ Not found: $Description (already clean)" -ForegroundColor Gray
    }
}

# 디렉토리 삭제 함수
function Remove-DirectoryIfExists {
    param($DirPath, $Description)
    if (Test-Path $DirPath) {
        try {
            Remove-Item $DirPath -Recurse -Force
            Write-Host "✓ Deleted: $Description" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to delete $Description : $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "○ Not found: $Description (already clean)" -ForegroundColor Gray
    }
}

Write-Host "=========================================" -ForegroundColor Red
Write-Host "Terraform Deployment Deletion" -ForegroundColor Red
Write-Host "Project: Creative Energy Database Service" -ForegroundColor Red
Write-Host "Architecture: 3-Tier High Availability" -ForegroundColor Red
Write-Host "=========================================" -ForegroundColor Red
Write-Host ""

Write-Host "⚠️  WARNING: This script will:" -ForegroundColor Yellow
Write-Host "   1. Destroy all deployed infrastructure resources" -ForegroundColor White
Write-Host "   2. Reset user input variables to default values" -ForegroundColor White
Write-Host "   3. Clean up generated files and logs" -ForegroundColor White
Write-Host "   4. Remove Terraform state and cache files" -ForegroundColor White
Write-Host ""

# 현재 디렉토리 확인
Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow
Write-Host ""

try {
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

    # Initialize terraform if needed for variable reading
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform for variable reading..." -ForegroundColor Yellow
        terraform init | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "❌ Terraform Init 실패!" -ForegroundColor Red
            Write-Host "Terraform 초기화가 필요하지만 실패했습니다." -ForegroundColor Yellow
            Write-Host "기본값으로 복구 작업을 계속할 수 없습니다." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }

    # 메뉴 표시
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "삭제 옵션 선택" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "[1] 전체 삭제 (권장)" -ForegroundColor White
    Write-Host "    - 인프라 전체 삭제" -ForegroundColor Gray
    Write-Host "    - 변수 초기화" -ForegroundColor Gray
    Write-Host "    - 생성 파일 정리" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[2] 인프라만 삭제 (Terraform Destroy)" -ForegroundColor White
    Write-Host "    - 클라우드 리소스만 삭제" -ForegroundColor Gray
    Write-Host "    - 로컬 파일은 유지" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[3] 변수만 초기화" -ForegroundColor White
    Write-Host "    - variables.tf를 기본값으로 초기화" -ForegroundColor Gray
    Write-Host "    - 인프라는 유지" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[4] 생성 파일만 정리" -ForegroundColor White
    Write-Host "    - master_config.json, 로그 파일만 삭제" -ForegroundColor Gray
    Write-Host "    - 인프라와 변수는 유지" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[5] 개별 항목 선택" -ForegroundColor White
    Write-Host "    - 개별 삭제 작업 선택 실행" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[0] 취소" -ForegroundColor White
    Write-Host "    - 스크립트 종료" -ForegroundColor Gray
    Write-Host ""

    # 사용자 선택
    do {
        $choice = Read-Host "삭제 옵션을 선택하세요 (0-5)"
        $choice = $choice.Trim()
        
        if ($choice -eq '0') {
            Write-Host "작업이 취소되었습니다." -ForegroundColor Yellow
            exit 0
        }
        elseif ($choice -match '^[1-5]$') {
            break
        }
        else {
            Write-Host "잘못된 입력입니다. 0-5 사이의 숫자를 입력하세요." -ForegroundColor Yellow
        }
    } while ($true)

    # API 로깅 설정
    $logFile = Set-TerraformLogging

    switch ($choice) {
        "1" {
            # 전체 삭제
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host "전체 삭제 시작" -ForegroundColor Red
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host ""

            # 최종 확인
            do {
                Write-Host "⚠️  모든 클라우드 리소스가 삭제되고 설정이 초기화됩니다!" -ForegroundColor Yellow
                $finalConfirm = Read-Host "정말 계속하시겠습니까? 네(y), 아니오(n) [기본값: n]"
                $finalConfirm = $finalConfirm.Trim().ToLower()
                
                if ($finalConfirm -eq 'y' -or $finalConfirm -eq 'yes' -or $finalConfirm -eq '네' -or $finalConfirm -eq 'ㅇ') {
                    break
                }
                elseif ($finalConfirm -eq 'n' -or $finalConfirm -eq 'no' -or $finalConfirm -eq '아니오' -or $finalConfirm -eq 'ㄴ' -or $finalConfirm -eq '') {
                    Write-Host "삭제 작업이 취소되었습니다." -ForegroundColor Yellow
                    exit 0
                }
                else {
                    Write-Host "잘못된 입력입니다. 네(y) 또는 아니오(n)를 입력하세요." -ForegroundColor Yellow
                }
            } while ($true)

            # Step 1: Terraform Destroy
            Write-Host "[1/4] Terraform Destroy 실행..." -ForegroundColor Red
            if (Test-Path "terraform.tfstate") {
                terraform destroy --auto-approve
                if ($LASTEXITCODE -ne 0) {
                    Write-Host ""
                    Write-Host "❌ Terraform Destroy 실패!" -ForegroundColor Red
                    Write-Host "=========================================" -ForegroundColor Red
                    Write-Host "오류 해결 방법:" -ForegroundColor Yellow
                    Write-Host "1. 위의 오류 메시지를 확인하세요" -ForegroundColor White
                    Write-Host "2. 일부 리소스가 다른 리소스에 의존될 수 있습니다" -ForegroundColor White
                    Write-Host "3. Samsung Cloud Platform 콘솔에서 수동 삭제가 필요할 수 있습니다" -ForegroundColor White
                    Write-Host "4. 네트워크 연결 상태를 확인하세요" -ForegroundColor White
                    Write-Host "5. 리소스 삭제 권한이 있는지 확인하세요" -ForegroundColor White
                    Write-Host "6. terraform state list로 남은 리소스를 확인하세요" -ForegroundColor White
                    Write-Host "=========================================" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
                    Write-Host "자세한 API 통신 내용을 확인하세요" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                else {
                    Write-Host "✓ Success: 모든 인프라 리소스 삭제 완료" -ForegroundColor Green
                }
            }
            else {
                Write-Host "○ terraform.tfstate 없음 - 삭제할 인프라 없음" -ForegroundColor Gray
            }
            Write-Host ""

            # Step 2: Reset Variables
            Write-Host "[2/4] 변수 초기화..." -ForegroundColor Red
            Write-Host "variables.tf 파일에서 현재 기본값을 읽어와서 초기화합니다..." -ForegroundColor Gray
            
            # Read current default values from variables.tf file directly
            $varNames = @("private_domain_name", "private_hosted_zone_id", "public_domain_name", "keypair_name", "user_public_ip")
            $resetSuccess = $true
            
            foreach ($varName in $varNames) {
                try {
                    # Extract default value from variables.tf file
                    $content = Get-Content "variables.tf" -Raw
                    $pattern = "variable\s+`"$varName`"\s*\{[^}]*?default\s*=\s*`"([^`"]*)`""
                    if ($content -match $pattern) {
                        $defaultValue = $matches[1]
                        Write-Host "  $varName = '$defaultValue'" -ForegroundColor Gray
                        if (-not (Reset-VariableInFile -VarName $varName -DefaultValue $defaultValue)) {
                            $resetSuccess = $false
                        }
                    }
                    else {
                        Write-Host "  $varName = (패턴을 찾을 수 없음)" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "  ❌ Failed to read $varName : $_" -ForegroundColor Red
                    $resetSuccess = $false
                }
            }
            
            if ($resetSuccess) {
                Write-Host "✓ Success: variables.tf 기본값으로 초기화 완료" -ForegroundColor Green
            }
            else {
                Write-Host "❌ variables.tf 초기화 중 일부 오류 발생" -ForegroundColor Red
            }
            Write-Host ""

            # Step 3: Clean Files
            Write-Host "[3/4] 생성 파일 정리..." -ForegroundColor Red
            Remove-FileIfExists "master_config.json" "Master Config File"
            Remove-FileIfExists "tfplan" "Terraform Plan File"
            Remove-FileIfExists "terraform.tfstate" "Terraform State File"
            Remove-FileIfExists "terraform.tfstate.backup" "Terraform State Backup"
            Remove-DirectoryIfExists ".terraform" "Terraform Cache Directory"
            Write-Host ""

            # Step 4: Clean Logs
            Write-Host "[4/4] 로그 파일 정리..." -ForegroundColor Red
            if (Test-Path "terraform_log") {
                Get-ChildItem "terraform_log" -Filter "trial*.log" | ForEach-Object {
                    Remove-FileIfExists $_.FullName "Trial Log: $($_.Name)"
                }
                # Keep rollback logs for reference
                Write-Host "○ Rollback logs kept for reference" -ForegroundColor Gray
            }
            Write-Host ""

            Write-Host "=========================================" -ForegroundColor Green
            Write-Host "전체 삭제 완료!" -ForegroundColor Green
            Write-Host "=========================================" -ForegroundColor Green
        }

        "2" {
            # 인프라만 삭제
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host "인프라 삭제 시작" -ForegroundColor Red
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host ""

            if (Test-Path "terraform.tfstate") {
                do {
                    Write-Host "⚠️  모든 클라우드 리소스가 삭제됩니다!" -ForegroundColor Yellow
                    $confirm = Read-Host "계속하시겠습니까? 네(y), 아니오(n) [기본값: n]"
                    $confirm = $confirm.Trim().ToLower()
                    
                    if ($confirm -eq 'y' -or $confirm -eq 'yes' -or $confirm -eq '네' -or $confirm -eq 'ㅇ') {
                        break
                    }
                    elseif ($confirm -eq 'n' -or $confirm -eq 'no' -or $confirm -eq '아니오' -or $confirm -eq 'ㄴ' -or $confirm -eq '') {
                        Write-Host "작업이 취소되었습니다." -ForegroundColor Yellow
                        exit 0
                    }
                    else {
                        Write-Host "잘못된 입력입니다. 네(y) 또는 아니오(n)를 입력하세요." -ForegroundColor Yellow
                    }
                } while ($true)

                terraform destroy --auto-approve
                if ($LASTEXITCODE -ne 0) {
                    Write-Host ""
                    Write-Host "❌ Terraform Destroy 실패!" -ForegroundColor Red
                    Write-Host "=========================================" -ForegroundColor Red
                    Write-Host "오류 해결 방법:" -ForegroundColor Yellow
                    Write-Host "1. 위의 오류 메시지를 확인하세요" -ForegroundColor White
                    Write-Host "2. Samsung Cloud Platform 콘솔에서 수동 삭제를 시도하세요" -ForegroundColor White
                    Write-Host "3. terraform state list로 남은 리소스를 확인하세요" -ForegroundColor White
                    Write-Host "4. 네트워크 연결과 권한을 확인하세요" -ForegroundColor White
                    Write-Host "=========================================" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Press any key to exit..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    exit 1
                }
                Write-Host "✓ Success: 모든 인프라 리소스 삭제 완료" -ForegroundColor Green
            }
            else {
                Write-Host "○ terraform.tfstate 없음 - 삭제할 인프라 없음" -ForegroundColor Gray
            }
        }

        "3" {
            # 변수만 초기화
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host "변수 초기화 시작" -ForegroundColor Red
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "variables.tf 파일에서 현재 기본값을 읽어와서 초기화합니다..." -ForegroundColor Gray

            # Read current default values from variables.tf file directly
            $varNames = @("private_domain_name", "private_hosted_zone_id", "public_domain_name", "keypair_name", "user_public_ip")
            $resetSuccess = $true
            
            foreach ($varName in $varNames) {
                try {
                    # Extract default value from variables.tf file
                    $content = Get-Content "variables.tf" -Raw
                    $pattern = "variable\s+`"$varName`"\s*\{[^}]*?default\s*=\s*`"([^`"]*)`""
                    if ($content -match $pattern) {
                        $defaultValue = $matches[1]
                        Write-Host "  $varName = '$defaultValue'" -ForegroundColor Gray
                        if (-not (Reset-VariableInFile -VarName $varName -DefaultValue $defaultValue)) {
                            $resetSuccess = $false
                        }
                    }
                    else {
                        Write-Host "  $varName = (패턴을 찾을 수 없음)" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "  ❌ Failed to read $varName : $_" -ForegroundColor Red
                    $resetSuccess = $false
                }
            }
            
            if ($resetSuccess) {
                Write-Host "✓ Success: variables.tf 기본값으로 초기화 완료" -ForegroundColor Green
            }
            else {
                Write-Host "❌ variables.tf 초기화 중 일부 오류 발생" -ForegroundColor Red
            }
        }

        "4" {
            # 생성 파일만 정리
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host "생성 파일 정리 시작" -ForegroundColor Red
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host ""

            Remove-FileIfExists "master_config.json" "Master Config File"
            Remove-FileIfExists "tfplan" "Terraform Plan File"
            
            if (Test-Path "terraform_log") {
                Get-ChildItem "terraform_log" -Filter "trial*.log" | ForEach-Object {
                    Remove-FileIfExists $_.FullName "Trial Log: $($_.Name)"
                }
            }
            
            Write-Host "✓ Success: 생성 파일 정리 완료" -ForegroundColor Green
        }

        "5" {
            # 개별 항목 선택
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "개별 삭제 항목 선택" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host ""

            $items = @(
                @{Name="Terraform Destroy"; Description="클라우드 인프라 전체 삭제"},
                @{Name="Reset Variables"; Description="variables.tf를 기본값으로 초기화"},
                @{Name="Delete master_config.json"; Description="마스터 설정 파일 삭제"},
                @{Name="Delete terraform.tfstate"; Description="Terraform 상태 파일 삭제"},
                @{Name="Delete .terraform directory"; Description="Terraform 캐시 디렉토리 삭제"},
                @{Name="Delete tfplan"; Description="Terraform 계획 파일 삭제"},
                @{Name="Delete trial logs"; Description="배포 로그 파일들 삭제"},
                @{Name="Exit"; Description="종료"}
            )

            do {
                Write-Host "개별 삭제 항목을 선택하세요:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $items.Count; $i++) {
                    Write-Host "[$($i+1)] $($items[$i].Name)" -ForegroundColor White
                    Write-Host "     $($items[$i].Description)" -ForegroundColor Gray
                }
                Write-Host ""

                $itemChoice = Read-Host "항목 번호 선택 (1-$($items.Count))"
                $itemIndex = [int]$itemChoice - 1

                if ($itemIndex -ge 0 -and $itemIndex -lt $items.Count) {
                    $selectedItem = $items[$itemIndex]
                    
                    if ($selectedItem.Name -eq "Exit") {
                        break
                    }

                    Write-Host ""
                    Write-Host "선택된 항목: $($selectedItem.Name)" -ForegroundColor Cyan
                    $confirm = Read-Host "실행하시겠습니까? 네(y), 아니오(n) [기본값: n]"
                    
                    if ($confirm.Trim().ToLower() -eq 'y' -or $confirm.Trim().ToLower() -eq '네' -or $confirm.Trim().ToLower() -eq 'ㅇ') {
                        switch ($selectedItem.Name) {
                            "Terraform Destroy" {
                                if (Test-Path "terraform.tfstate") {
                                    terraform destroy --auto-approve
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Host "✓ 인프라 삭제 완료" -ForegroundColor Green
                                    } else {
                                        Write-Host ""
                                        Write-Host "❌ Terraform Destroy 실패!" -ForegroundColor Red
                                        Write-Host "오류 해결 방법:" -ForegroundColor Yellow
                                        Write-Host "- 위의 오류 메시지를 확인하세요" -ForegroundColor White
                                        Write-Host "- Samsung Cloud Platform 콘솔에서 수동 삭제를 시도하세요" -ForegroundColor White
                                        Write-Host "- API Log를 확인하세요: $logFile" -ForegroundColor White
                                    }
                                } else {
                                    Write-Host "○ 삭제할 인프라 없음" -ForegroundColor Gray
                                }
                            }
                            "Reset Variables" {
                                Write-Host "variables.tf 파일에서 현재 기본값을 읽어와서 초기화합니다..." -ForegroundColor Gray
                                
                                # Read current default values from variables.tf file directly
                                $varNames = @("private_domain_name", "private_hosted_zone_id", "public_domain_name", "keypair_name", "user_public_ip")
                                $resetSuccess = $true
                                
                                foreach ($varName in $varNames) {
                                    try {
                                        # Extract default value from variables.tf file
                                        $content = Get-Content "variables.tf" -Raw
                                        $pattern = "variable\s+`"$varName`"\s*\{[^}]*?default\s*=\s*`"([^`"]*)`""
                                        if ($content -match $pattern) {
                                            $defaultValue = $matches[1]
                                            Write-Host "  $varName = '$defaultValue'" -ForegroundColor Gray
                                            if (-not (Reset-VariableInFile -VarName $varName -DefaultValue $defaultValue)) {
                                                $resetSuccess = $false
                                            }
                                        }
                                        else {
                                            Write-Host "  $varName = (패턴을 찾을 수 없음)" -ForegroundColor Yellow
                                        }
                                    }
                                    catch {
                                        Write-Host "  ❌ Failed to read $varName : $_" -ForegroundColor Red
                                        $resetSuccess = $false
                                    }
                                }
                                
                                if ($resetSuccess) {
                                    Write-Host "✓ 변수 기본값으로 초기화 완료" -ForegroundColor Green
                                }
                                else {
                                    Write-Host "❌ 변수 초기화 중 일부 오류 발생" -ForegroundColor Red
                                }
                            }
                            "Delete master_config.json" {
                                Remove-FileIfExists "master_config.json" "Master Config File"
                            }
                            "Delete terraform.tfstate" {
                                Remove-FileIfExists "terraform.tfstate" "Terraform State File"
                                Remove-FileIfExists "terraform.tfstate.backup" "Terraform State Backup"
                            }
                            "Delete .terraform directory" {
                                Remove-DirectoryIfExists ".terraform" "Terraform Cache Directory"
                            }
                            "Delete tfplan" {
                                Remove-FileIfExists "tfplan" "Terraform Plan File"
                            }
                            "Delete trial logs" {
                                if (Test-Path "terraform_log") {
                                    Get-ChildItem "terraform_log" -Filter "trial*.log" | ForEach-Object {
                                        Remove-FileIfExists $_.FullName "Trial Log: $($_.Name)"
                                    }
                                }
                            }
                        }
                    }
                    Write-Host ""
                }
                else {
                    Write-Host "잘못된 선택입니다." -ForegroundColor Yellow
                }
            } while ($true)
        }
    }

    Write-Host ""
    Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
    Write-Host "This log contains all provider API requests and responses" -ForegroundColor Gray
}
catch {
    Write-Host ""
    Write-Host "❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    if ($logFile) {
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host "Check the log for detailed API communication errors" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Make sure you're in the correct directory with main.tf" -ForegroundColor White
    Write-Host "2. Check if Terraform is installed: terraform version" -ForegroundColor White
    Write-Host "3. Check Samsung Cloud Platform credentials" -ForegroundColor White
    Write-Host "4. Some resources might need manual deletion from cloud console" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Rollback script completed." -ForegroundColor Gray