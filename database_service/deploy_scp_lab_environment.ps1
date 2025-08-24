# PowerShell 에러 처리 설정
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

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Terraform Deployment Started" -ForegroundColor Green
Write-Host "Project: Creative Energy Database Service" -ForegroundColor Green
Write-Host "Architecture: 3-Tier High Availability" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# API 로깅 설정
$logFile = Set-TerraformLogging

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

    # User Input Variables Interactive Configuration
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "사용자 입력 변수 확인/수정" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Function to safely get a terraform variable
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

    # Function to get variables by category from variables.tf
    function Get-VariablesByCategory {
        param($Category)
        $variables = @{}
        
        # Read variables.tf and extract variables by category
        $content = Get-Content "variables.tf" -Raw
        
        # Pattern to match variable blocks with specific category tag
        $pattern = "variable\s+`"([^`"]+)`"\s*\{[^}]*description\s*=\s*`"\[$Category\][^`"]*`"[^}]*default\s*=\s*([^}]+)\}"
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        foreach ($match in $matches) {
            $varName = $match.Groups[1].Value
            $varValue = Get-TerraformVariable $varName
            if ($varValue -ne $null) {
                $variables[$varName] = $varValue
            }
        }
        
        return $variables
    }

    # Function to validate ceweb required variables
    function Test-CewebRequiredVariables {
        $requiredVars = @(
            "app_server_port", "database_port", "database_name", "database_user", 
            "nginx_port", "ssl_enabled", "object_storage_bucket_name", "object_storage_region",
            "certificate_path", "private_key_path", "git_repository", "git_branch", 
            "timezone", "web_lb_service_ip", "app_lb_service_ip", "node_env", 
            "session_secret", "db_type", "db_max_connections", "object_storage_private_endpoint",
            "object_storage_public_endpoint", "object_storage_media_folder", "object_storage_audition_folder",
            "auto_deployment", "rollback_enabled", "backup_retention_days", "company_name", "admin_email"
        )
        
        $cewebVars = Get-VariablesByCategory "CEWEB_REQUIRED"
        $missingVars = @()
        
        foreach ($requiredVar in $requiredVars) {
            if (-not $cewebVars.ContainsKey($requiredVar)) {
                $missingVars += $requiredVar
            }
        }
        
        if ($missingVars.Count -gt 0) {
            Write-Host "❌ 경고: ceweb 필수 변수가 누락되었습니다!" -ForegroundColor Red
            Write-Host "누락된 변수들을 variables.tf에 [CEWEB_REQUIRED] 태그로 정의해야 합니다:" -ForegroundColor Yellow
            $missingVars | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
            Write-Host ""
            return $false
        }
        
        return $true
    }

    # Function to update variable in variables.tf
    function Update-VariableInFile {
        param($VarName, $NewValue)
        try {
            $content = Get-Content "variables.tf" -Raw
            $pattern = "(variable\s+`"$VarName`"\s*\{[^}]*?default\s*=\s*)`"[^`"]*`""
            $replacement = "`${1}`"$NewValue`""
            $newContent = $content -replace $pattern, $replacement
            $newContent | Set-Content "variables.tf" -NoNewline
            return $true
        }
        catch {
            Write-Host "❌ Failed to update variable $VarName : $_" -ForegroundColor Red
            return $false
        }
    }

    # Initialize terraform if needed for variable extraction
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform for variable extraction..." -ForegroundColor Yellow
        terraform init | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "❌ Terraform Init 실패!" -ForegroundColor Red
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host "오류 해결 방법:" -ForegroundColor Yellow
            Write-Host "1. 위의 오류 메시지를 확인하세요" -ForegroundColor White
            Write-Host "2. 인터넷 연결 상태를 확인하세요" -ForegroundColor White
            Write-Host "3. Terraform 버전이 호환되는지 확인하세요 (>=1.11)" -ForegroundColor White
            Write-Host "4. 프로바이더 다운로드가 차단되지 않았는지 확인하세요" -ForegroundColor White
            Write-Host "5. .terraform 폴더를 삭제 후 다시 시도하세요" -ForegroundColor White
            Write-Host "6. 문제 해결 후 다시 스크립트를 실행하세요" -ForegroundColor White
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }

    # Validate ceweb required variables
    Write-Host "ceweb 필수 변수 검증 중..." -ForegroundColor Cyan
    if (-not (Test-CewebRequiredVariables)) {
        Write-Host "ceweb 필수 변수 검증 실패. 스크립트를 종료합니다." -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ ceweb 필수 변수 검증 완료!" -ForegroundColor Green
    Write-Host ""

    # Get USER_INPUT variables for interactive configuration
    $userInputVars = Get-VariablesByCategory "USER_INPUT"
    $userVariables = @{}
    
    foreach ($varName in $userInputVars.Keys) {
        $currentValue = $userInputVars[$varName]
        
        # Extract description from variables.tf
        $description = ""
        $content = Get-Content "variables.tf" -Raw
        $pattern = "variable\s+`"$varName`"\s*\{[^}]*description\s*=\s*`"\[USER_INPUT\]\s*([^`"]*)`""
        $match = [regex]::Match($content, $pattern)
        if ($match.Success) {
            $description = $match.Groups[1].Value.Trim()
        }
        
        $userVariables[$varName] = @{
            "current" = $currentValue
            "description" = $description
            "new_value" = ""
        }
    }

    # Display current variables
    Write-Host "현재 variables.tf에 설정된 사용자 입력 변수:" -ForegroundColor Yellow
    Write-Host ""
    $index = 1
    $userVariables.GetEnumerator() | ForEach-Object {
        Write-Host "[$index] $($_.Key)" -ForegroundColor White
        Write-Host "    설명: $($_.Value.description)" -ForegroundColor Gray
        Write-Host "    현재 값: $($_.Value.current)" -ForegroundColor Cyan
        Write-Host ""
        $index++
    }

    # Ask if user wants to modify variables
    do {
        $modifyVars = Read-Host "사용자 입력 변수를 확인/수정하시겠습니까? 네(y), 아니오(n) [기본값: y]"
        $modifyVars = $modifyVars.Trim().ToLower()
        
        if ($modifyVars -eq 'y' -or $modifyVars -eq 'yes' -or $modifyVars -eq '네' -or $modifyVars -eq 'ㅇ' -or $modifyVars -eq '') {
            $shouldModify = $true
            break
        }
        elseif ($modifyVars -eq 'n' -or $modifyVars -eq 'no' -or $modifyVars -eq '아니오' -or $modifyVars -eq 'ㄴ') {
            $shouldModify = $false
            break
        }
        else {
            Write-Host "잘못된 입력입니다. 네(y) 또는 아니오(n)를 입력하세요." -ForegroundColor Yellow
        }
    } while ($true)

    if ($shouldModify) {
        Write-Host ""
        Write-Host "변수 값 입력 (기존 값 유지하려면 Enter, 변경하려면 새 값 입력):" -ForegroundColor Cyan
        Write-Host ""

        # Collect input for each USER_INPUT variable
        $varNames = $userVariables.Keys | Sort-Object
        foreach ($varName in $varNames) {
            $currentValue = $userVariables[$varName].current
            $description = $userVariables[$varName].description
            
            Write-Host "[$varName]" -ForegroundColor Yellow
            Write-Host "  설명: $description" -ForegroundColor Gray
            Write-Host "  현재 값: $currentValue" -ForegroundColor Cyan
            $newValue = Read-Host "  새 값 입력 (Enter=기존값 유지)"
            
            if ([string]::IsNullOrWhiteSpace($newValue)) {
                $userVariables[$varName].new_value = $currentValue
            } else {
                $userVariables[$varName].new_value = $newValue.Trim()
            }
            Write-Host ""
        }

        # Display confirmation
        do {
            Write-Host "=========================================" -ForegroundColor Green
            Write-Host "입력된 변수 값 확인" -ForegroundColor Green
            Write-Host "=========================================" -ForegroundColor Green
            $index = 1
            $varNames | ForEach-Object {
                $varName = $_
                $newValue = $userVariables[$varName].new_value
                Write-Host "[$index] $varName = $newValue" -ForegroundColor White
                $index++
            }
            Write-Host ""
            
            $confirmation = Read-Host "입력한 값이 맞습니까? 수정을 원하실 경우 번호를 입력하시고, 맞을 경우 네(y) [기본값: y]"
            $confirmation = $confirmation.Trim()
            
            if ($confirmation -eq 'y' -or $confirmation -eq 'Y' -or $confirmation -eq '네' -or $confirmation -eq '') {
                # Update variables.tf with new values
                Write-Host "variables.tf 파일을 업데이트 중..." -ForegroundColor Cyan
                $updateSuccess = $true
                $varNames | ForEach-Object {
                    $varName = $_
                    $newValue = $userVariables[$varName].new_value
                    if (-not (Update-VariableInFile -VarName $varName -NewValue $newValue)) {
                        $updateSuccess = $false
                    }
                }
                
                if ($updateSuccess) {
                    Write-Host "✓ variables.tf 업데이트 완료!" -ForegroundColor Green
                } else {
                    Write-Host "❌ variables.tf 업데이트 중 일부 오류 발생" -ForegroundColor Red
                }
                break
            }
            elseif ($confirmation -match '^\d+$') {
                $modifyIndex = [int]$confirmation
                if ($modifyIndex -ge 1 -and $modifyIndex -le $varNames.Count) {
                    $varToModify = $varNames[$modifyIndex - 1]
                    $currentValue = $userVariables[$varToModify].current
                    $description = $userVariables[$varToModify].description
                    
                    Write-Host ""
                    Write-Host "[$varToModify] 수정" -ForegroundColor Yellow
                    Write-Host "  설명: $description" -ForegroundColor Gray
                    Write-Host "  현재 값: $currentValue" -ForegroundColor Cyan
                    $newValue = Read-Host "  새 값 입력"
                    
                    if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                        $userVariables[$varToModify].new_value = $newValue.Trim()
                    }
                } else {
                    Write-Host "잘못된 번호입니다. 1-$($varNames.Count) 사이의 숫자를 입력하세요." -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "잘못된 입력입니다. 번호 또는 네(y)를 입력하세요." -ForegroundColor Yellow
            }
        } while ($true)
    }

    Write-Host ""

    # Extract variables by category from variables.tf using terraform console
    Write-Host "[0/4] Extracting variables from variables.tf using terraform console..." -ForegroundColor Cyan

    Write-Host "Reading USER_INPUT and CEWEB_REQUIRED variables from variables.tf..." -ForegroundColor Yellow

    # Get variables by category (only USER_INPUT and CEWEB_REQUIRED for master_config.json)
    $userInputVars = Get-VariablesByCategory "USER_INPUT"
    $cewebRequiredVars = Get-VariablesByCategory "CEWEB_REQUIRED"
    $terraformInfraVars = @{
        # Network variables from complex objects
        vpc_cidr = (echo "var.vpcs[0].cidr" | terraform console).Trim().Trim('"')
        web_subnet_cidr = (echo "var.subnets[0].cidr" | terraform console).Trim().Trim('"')
        app_subnet_cidr = (echo "var.subnets[1].cidr" | terraform console).Trim().Trim('"')
        db_subnet_cidr = (echo "var.subnets[2].cidr" | terraform console).Trim().Trim('"')
        # Server IPs
        bastion_ip = Get-TerraformVariable "bastion_ip"
        web_ip = Get-TerraformVariable "web_ip"
        web_ip2 = Get-TerraformVariable "web_ip2"
        app_ip = Get-TerraformVariable "app_ip"
        app_ip2 = Get-TerraformVariable "app_ip2"
        db_ip = Get-TerraformVariable "db_ip"
    }

    # Combine all variables for master_config.json generation
    $variables = @{}
    $userInputVars.GetEnumerator() | ForEach-Object { $variables[$_.Key] = $_.Value }
    $cewebRequiredVars.GetEnumerator() | ForEach-Object { $variables[$_.Key] = $_.Value }
    $terraformInfraVars.GetEnumerator() | ForEach-Object { $variables[$_.Key] = $_.Value }

    # Verify we got the variables
    $missingVars = @()
    $variables.GetEnumerator() | ForEach-Object {
        if ([string]::IsNullOrEmpty($_.Value)) {
            $missingVars += $_.Key
        }
    }
    
    if ($missingVars.Count -gt 0) {
        throw "Failed to extract the following variables: $($missingVars -join ', ')"
    }

    Write-Host "✓ Variables extracted successfully:" -ForegroundColor Green
    Write-Host "  Public Domain: $($variables.public_domain_name)" -ForegroundColor White
    Write-Host "  Private Domain: $($variables.private_domain_name)" -ForegroundColor White
    Write-Host "  User IP: $($variables.user_public_ip)" -ForegroundColor White
    Write-Host "  SSH Key: $($variables.keypair_name)" -ForegroundColor White
    Write-Host "  VPC CIDR: $($variables.vpc_cidr)" -ForegroundColor White
    Write-Host "  Web LB IP: $($variables.web_lb_service_ip)" -ForegroundColor White
    Write-Host ""

    # Generate master_config.json with extracted variables
    Write-Host "Generating master_config.json with extracted values..." -ForegroundColor Cyan

    $masterConfig = @{
        config_metadata = @{
            version = "1.0.0"
            created = Get-Date -Format "yyyy-MM-dd"
            description = "Samsung Cloud Platform 3-Tier Architecture Master Configuration"
            generated_from = "variables.tf via terraform console"
        }
        infrastructure = @{
            domain = @{
                public_domain_name = $variables.public_domain_name
                private_domain_name = $variables.private_domain_name
                private_hosted_zone_id = $variables.private_hosted_zone_id
            }
            network = @{
                vpc_cidr = $variables.vpc_cidr
                web_subnet_cidr = $variables.web_subnet_cidr
                app_subnet_cidr = $variables.app_subnet_cidr
                db_subnet_cidr = $variables.db_subnet_cidr
            }
            load_balancer = @{
                web_lb_service_ip = $variables.web_lb_service_ip
                app_lb_service_ip = $variables.app_lb_service_ip
            }
            servers = @{
                web_primary_ip = $variables.web_ip
                web_secondary_ip = $variables.web_ip2
                app_primary_ip = $variables.app_ip
                app_secondary_ip = $variables.app_ip2
                db_primary_ip = $variables.db_ip
                bastion_ip = $variables.bastion_ip
            }
        }
        application = @{
            web_server = @{
                nginx_port = $variables.nginx_port
                ssl_enabled = [System.Convert]::ToBoolean($variables.ssl_enabled)
                upstream_target = "app.$($variables.private_domain_name):$($variables.app_server_port)"
                fallback_target = "$($variables.app_ip2):$($variables.app_server_port)"
                health_check_path = "/health"
                api_proxy_path = "/api"
            }
            app_server = @{
                port = $variables.app_server_port
                node_env = $variables.node_env
                database_host = "db.$($variables.private_domain_name)"
                database_port = $variables.database_port
                database_name = $variables.database_name
                session_secret = $variables.session_secret
            }
            database = @{
                type = $variables.db_type
                port = $variables.database_port
                max_connections = $variables.db_max_connections
                shared_buffers = "256MB"
                effective_cache_size = "1GB"
            }
        }
        security = @{
            firewall = @{
                allowed_public_ips = @("$($variables.user_public_ip)/32")
                ssh_key_name = $variables.keypair_name
            }
            ssl = @{
                certificate_path = $variables.certificate_path
                private_key_path = $variables.private_key_path
            }
        }
        object_storage = @{
            access_key_id = $variables.object_storage_access_key_id
            secret_access_key = $variables.object_storage_secret_access_key
            region = $variables.object_storage_region
            bucket_name = $variables.object_storage_bucket_name
            bucket_string = $variables.object_storage_bucket_string
            private_endpoint = $variables.object_storage_private_endpoint
            public_endpoint = $variables.object_storage_public_endpoint
            folders = @{
                media = $variables.object_storage_media_folder
                audition = $variables.object_storage_audition_folder
            }
            "_comment" = "Object Storage 설정은 기본 3-tier에서 선택사항입니다"
        }
        deployment = @{
            git_repository = $variables.git_repository
            git_branch = $variables.git_branch
            auto_deployment = [System.Convert]::ToBoolean($variables.auto_deployment)
            rollback_enabled = [System.Convert]::ToBoolean($variables.rollback_enabled)
        }
        monitoring = @{
            log_level = "info"
            health_check_interval = 30
            metrics_enabled = $true
        }
        user_customization = @{
            "_comment" = "사용자 직접 수정 영역"
            company_name = $variables.company_name
            admin_email = $variables.admin_email
            timezone = $variables.timezone
            backup_retention_days = $variables.backup_retention_days
        }
    }

    # Convert to JSON and save with error handling
    try {
        $jsonString = $masterConfig | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $jsonString | Out-File -FilePath "master_config.json" -Encoding UTF8 -ErrorAction Stop
        Write-Host "✓ master_config.json created successfully!" -ForegroundColor Green
    }
    catch {
        throw "Failed to create master_config.json: $_"
    }
    Write-Host ""

    # Inject variables into userdata files
    Write-Host "Injecting variables into userdata files..." -ForegroundColor Cyan
    
    $userDataFiles = @("userdata_db.sh", "userdata_app.sh", "userdata_web.sh")
    
    foreach ($file in $userDataFiles) {
        if (Test-Path $file) {
            Write-Host "  Processing $file..." -ForegroundColor Yellow
            
            $content = Get-Content $file -Raw -Encoding UTF8
            
            # Replace the master_config.json placeholder with actual JSON content
            $jsonContent = $jsonString -replace '"', '\"' -replace '`', '\`' -replace '\$', '\$'
            $content = $content -replace '\$\{MASTER_CONFIG_JSON_CONTENT\}', $jsonContent
            
            # Write back to file
            $content | Set-Content $file -NoNewline -Encoding UTF8
            Write-Host "  ✓ $file updated with variable values" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ $file not found" -ForegroundColor Red
        }
    }
    Write-Host "✓ All userdata files processed successfully!" -ForegroundColor Green
    Write-Host ""

    # Step 1: Terraform Validate (skip init since we already did it)
    Write-Host "[1/3] Running terraform validate..." -ForegroundColor Cyan
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ Terraform Validate 실패!" -ForegroundColor Red
        Write-Host "=========================================" -ForegroundColor Red
        Write-Host "오류 해결 방법:" -ForegroundColor Yellow
        Write-Host "1. 위의 오류 메시지를 확인하세요" -ForegroundColor White
        Write-Host "2. main.tf, variables.tf 파일의 문법을 점검하세요" -ForegroundColor White
        Write-Host "3. 누락된 변수나 잘못된 설정을 수정하세요" -ForegroundColor White
        Write-Host "4. 문제 해결 후 다시 스크립트를 실행하세요" -ForegroundColor White
        Write-Host "=========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    Write-Host "✓ Success: terraform validate completed" -ForegroundColor Green
    Write-Host ""

    # Step 2: Terraform Plan
    Write-Host "[2/3] Terraform Plan으로 실행 계획을 작성 중입니다..." -ForegroundColor Cyan
    $planOutput = terraform plan -out=tfplan 2>&1
    $planSuccess = $LASTEXITCODE -eq 0
    if (-not $planSuccess) {
        Write-Host ""
        Write-Host "❌ Terraform Plan 실패!" -ForegroundColor Red
        Write-Host "=========================================" -ForegroundColor Red
        Write-Host "오류 내용:" -ForegroundColor Yellow
        $planOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        Write-Host ""
        Write-Host "오류 해결 방법:" -ForegroundColor Yellow
        Write-Host "1. 위의 오류 메시지를 확인하세요" -ForegroundColor White
        Write-Host "2. 프로바이더 인증 설정을 확인하세요" -ForegroundColor White
        Write-Host "3. 변수 값들이 올바르게 설정되었는지 확인하세요" -ForegroundColor White
        Write-Host "4. 네트워크 연결 상태를 확인하세요" -ForegroundColor White
        Write-Host "5. Samsung Cloud Platform 콘솔에서 권한을 확인하세요" -ForegroundColor White
        Write-Host "6. 문제 해결 후 다시 스크립트를 실행하세요" -ForegroundColor White
        Write-Host "=========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host "자세한 API 통신 내용을 확인하세요" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    Write-Host "✓ Success: terraform plan completed" -ForegroundColor Green
    Write-Host ""

    # Step 3: Terraform Apply (with confirmation and retry)
    Write-Host "[3/3] Ready to deploy infrastructure..." -ForegroundColor Cyan
    Write-Host "Warning: This will create real resources on Samsung Cloud Platform!" -ForegroundColor Yellow
    
    do {
        $confirmation = Read-Host "배포를 계속하시겠습니까? 네(y), 아니오(n) [기본값: y]"
        $confirmation = $confirmation.Trim().ToLower()
        
        if ($confirmation -eq 'y' -or $confirmation -eq 'yes' -or $confirmation -eq '네' -or $confirmation -eq 'ㅇ' -or $confirmation -eq '') {
            $proceed = $true
            break
        }
        elseif ($confirmation -eq 'n' -or $confirmation -eq 'no' -or $confirmation -eq '아니오' -or $confirmation -eq 'ㄴ') {
            $proceed = $false
            break
        }
        else {
            Write-Host "잘못된 입력입니다. 네(y) 또는 아니오(n)를 입력하세요." -ForegroundColor Yellow
        }
    } while ($true)
    
    if ($proceed) {
        Write-Host "Starting terraform apply..." -ForegroundColor Cyan
        terraform apply --auto-approve tfplan
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "❌ Terraform Apply 실패!" -ForegroundColor Red
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host "오류 해결 방법:" -ForegroundColor Yellow
            Write-Host "1. 위의 오류 메시지를 자세히 확인하세요" -ForegroundColor White
            Write-Host "2. 리소스 할당량 초과 여부를 확인하세요" -ForegroundColor White
            Write-Host "3. 이미 사용 중인 리소스명이 있는지 확인하세요" -ForegroundColor White
            Write-Host "4. 네트워크 연결이 끊어졌는지 확인하세요" -ForegroundColor White
            Write-Host "5. Samsung Cloud Platform 콘솔에서 부분 생성된 리소스를 확인하세요" -ForegroundColor White
            Write-Host "6. 필요시 rollback_scp_lab_environment.ps1로 정리 후 재시도하세요" -ForegroundColor White
            Write-Host "=========================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
            Write-Host "자세한 API 통신 내용과 오류 원인을 확인하세요" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
        
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "API Log saved to: $logFile" -ForegroundColor Cyan
        Write-Host "This log contains all provider API requests and responses" -ForegroundColor Gray
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
    }
    else {
        Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
    }
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
    Write-Host "3. Verify variables.tf has all required variables" -ForegroundColor White
    Write-Host "4. Check Samsung Cloud Platform credentials" -ForegroundColor White
    exit 1
}
finally {
    # Cleanup temporary files
    if (Test-Path "terraform.tfstate.backup") {
        Write-Host "Terraform state files present - deployment artifacts saved" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Gray