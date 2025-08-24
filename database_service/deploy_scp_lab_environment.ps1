# PowerShell 에러 처리 설정
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
========================================
Samsung Cloud Platform v2 Creative Energy
3-Tier High Availability 실습 환경 배포 스크립트
========================================

📋 사용 방법:
  - Enter만 누르기: 일반 모드 (빠른 배포)
    * 변수 일관성 검증 생략
    * 빠른 배포에 최적화
    
  - 'admin' 입력 후 Enter: 개발자 모드 (상세 검증 포함)
    * variables.tf와 master_config.json.tpl 간 변수 일관성 검사
    * 불일치 항목 상세 정보 표시
    * 상세한 디버그 정보 제공
    * 모든 Terraform 출력 표시

작성자: SCPv2 Team
버전: 2.0
========================================
#>

# Initialize script-level variables for caching
$script:variablesContent = $null
$script:masterConfigContent = $null
$script:allVariablesCache = $null
$script:variablesCacheValid = $false
# Separate caches for different variable categories
$script:userInputCache = $null
$script:userInputCacheValid = $false
$script:cewebRequiredCache = $null
$script:cewebRequiredCacheValid = $false
$script:terraformInfraCache = $null
$script:terraformInfraCacheValid = $false
$global:ValidationMode = $false

#region 공통 파트 (Common Functions)
# ==========================================================
# 공통 함수들 - 개발자 모드와 일반 모드에서 공통으로 사용
# ==========================================================

# Function to parse variables.tf and create variables.json for fast access
function ConvertTo-VariablesJson {
    param(
        [string]$VariablesTfPath = "variables.tf",
        [string]$OutputJsonPath = "variables.json"
    )
    
    if ($global:ValidationMode) {
        Write-Host "🔄 variables.tf 파일을 JSON으로 파싱 중..." -ForegroundColor Cyan
    }
    $parseStartTime = Get-Date
    
    if (-not (Test-Path $VariablesTfPath)) {
        throw "$VariablesTfPath 파일을 찾을 수 없습니다."
    }
    
    # Read variables.tf content
    $content = Get-Content $VariablesTfPath -Raw
    
    # Initialize variables structure
    $variables = @{
        USER_INPUT = @{}
        CEWEB_REQUIRED = @{}
        TERRAFORM_INFRA = @{}
        metadata = @{
            parsed_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            source_file = $VariablesTfPath
            total_variables = 0
        }
    }
    
    # Helper function to extract default value from variable body
    function Extract-DefaultValue {
        param([string]$VarBody)
        
        # Look for default = pattern
        if ($VarBody -notmatch 'default\s*=') {
            return $null
        }
        
        # Split the body by lines and find the default line
        $lines = $VarBody -split '\r?\n'
        $defaultStartIndex = -1
        
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match '^\s*default\s*=\s*(.*)') {
                $defaultStartIndex = $i
                break
            }
        }
        
        if ($defaultStartIndex -eq -1) {
            return $null
        }
        
        # Extract the default value - could be single line or multi-line
        $defaultLine = $lines[$defaultStartIndex]
        $defaultPart = [regex]::Match($defaultLine, 'default\s*=\s*(.*)').Groups[1].Value
        
        # Handle different value types
        $defaultPart = $defaultPart.Trim()
        
        # Simple string value: "value"
        if ($defaultPart -match '^".*"$') {
            return $defaultPart.Trim('"')
        }
        # Simple number
        elseif ($defaultPart -match '^\d+$') {
            return [int]$defaultPart
        }
        # Simple boolean
        elseif ($defaultPart -match '^(true|false)$') {
            return [bool]($defaultPart -eq 'true')
        }
        # Complex object or array - starts with { or [
        elseif ($defaultPart -match '^[\{\[]' -or $defaultPart -eq '') {
            # For complex values, collect all lines until the closing
            $result = $defaultPart
            $braceCount = ($defaultPart -split '\{').Length - ($defaultPart -split '\}').Length
            $bracketCount = ($defaultPart -split '\[').Length - ($defaultPart -split '\]').Length
            
            # If we have unmatched braces/brackets, continue to next lines
            if ($braceCount -gt 0 -or $bracketCount -gt 0) {
                for ($j = $defaultStartIndex + 1; $j -lt $lines.Length; $j++) {
                    $line = $lines[$j].Trim()
                    if ($line -eq '}' -and $braceCount -eq 1) {
                        # This is the closing brace for the variable, stop here
                        break
                    }
                    $result += "`n" + $line
                    $braceCount += ($line -split '\{').Length - ($line -split '\}').Length
                    $bracketCount += ($line -split '\[').Length - ($line -split '\]').Length
                    
                    if ($braceCount -eq 0 -and $bracketCount -eq 0) {
                        break
                    }
                }
            }
            
            # Try to parse as JSON-like structure for better handling
            $cleanResult = $result.Trim()
            if ($cleanResult -ne '') {
                try {
                    # Convert HCL-like syntax to JSON for parsing
                    $jsonLike = $cleanResult -replace '(\w+)\s*=\s*', '"$1": ' -replace '(\w+):', '"$1":'
                    # Handle unquoted string values
                    $jsonLike = $jsonLike -replace ':\s*([^",\[\{\s]+)', ': "$1"'
                    return $cleanResult  # Return original for now, can enhance later
                } catch {
                    return $cleanResult
                }
            }
            return $cleanResult
        }
        else {
            # Simple value without quotes
            return $defaultPart
        }
    }
    
    # Regex patterns for variable parsing
    $variablePattern = 'variable\s+"([^"]+)"\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}'
    $descriptionPattern = 'description\s*=\s*"([^"]*)"'
    
    # Find all variable blocks
    $variableMatches = [regex]::Matches($content, $variablePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $variableMatches) {
        $varName = $match.Groups[1].Value.Trim()
        $varBody = $match.Groups[2].Value.Trim()
        
        # Extract description
        $descMatch = [regex]::Match($varBody, $descriptionPattern)
        $description = if ($descMatch.Success) { $descMatch.Groups[1].Value.Trim() } else { "" }
        
        # Extract default value using helper function
        $defaultValue = Extract-DefaultValue -VarBody $varBody
        
        # Determine category based on description tags
        $category = "TERRAFORM_INFRA"  # default
        if ($description -match '\[USER_INPUT\]') { $category = "USER_INPUT" }
        elseif ($description -match '\[CEWEB_REQUIRED\]') { $category = "CEWEB_REQUIRED" }
        
        # Add to appropriate category
        $variables[$category][$varName] = @{
            name = $varName
            description = $description -replace '\[USER_INPUT\]\s*|\[CEWEB_REQUIRED\]\s*|\[TERRAFORM_INFRA\]\s*', ''
            default_value = $defaultValue
            category = $category
            raw_body = $varBody
        }
    }
    
    # Update metadata
    $variables.metadata.total_variables = $variables.USER_INPUT.Count + $variables.CEWEB_REQUIRED.Count + $variables.TERRAFORM_INFRA.Count
    
    # Convert to JSON and save
    $jsonContent = $variables | ConvertTo-Json -Depth 10
    $jsonContent | Out-File -FilePath $OutputJsonPath -Encoding UTF8
    
    $parseEndTime = Get-Date
    $parseDuration = [math]::Round(($parseEndTime - $parseStartTime).TotalSeconds, 2)
    
    if ($global:ValidationMode) {
        Write-Host "✅ variables.tf → variables.json 파싱 완료!" -ForegroundColor Green
        Write-Host "   📊 파싱된 변수: USER_INPUT($($variables.USER_INPUT.Count)), CEWEB_REQUIRED($($variables.CEWEB_REQUIRED.Count)), TERRAFORM_INFRA($($variables.TERRAFORM_INFRA.Count))" -ForegroundColor White
        Write-Host "   ⏱️  파싱 시간: $parseDuration 초" -ForegroundColor White
        Write-Host "   📁 출력 파일: $OutputJsonPath" -ForegroundColor White
        Write-Host ""
    }
    
    return $variables
}

# Function to load variables from JSON file (fast alternative to terraform console)
function Get-VariablesFromJson {
    param(
        [string]$JsonPath = "variables.json",
        [string]$Category = $null  # USER_INPUT, CEWEB_REQUIRED, TERRAFORM_INFRA, or null for all
    )
    
    if (-not (Test-Path $JsonPath)) {
        throw "$JsonPath 파일을 찾을 수 없습니다. ConvertTo-VariablesJson을 먼저 실행하세요."
    }
    
    $jsonData = Get-Content $JsonPath -Raw | ConvertFrom-Json
    
    if ($Category) {
        # Return specific category as hashtable
        $result = @{}
        $categoryData = $jsonData.$Category
        if ($categoryData) {
            foreach ($property in $categoryData.PSObject.Properties) {
                $result[$property.Name] = $property.Value.default_value
                # Debug: Show what we're loading
                if ($global:ValidationMode) {
                    Write-Host "    Loading [$Category] $($property.Name) = $($property.Value.default_value)" -ForegroundColor Gray
                }
            }
        }
        return $result
    } else {
        # Return all variables as flat hashtable
        $result = @{}
        
        foreach ($cat in @("USER_INPUT", "CEWEB_REQUIRED", "TERRAFORM_INFRA")) {
            $categoryData = $jsonData.$cat
            if ($categoryData) {
                foreach ($property in $categoryData.PSObject.Properties) {
                    $result[$property.Name] = $property.Value.default_value
                }
            }
        }
        
        return $result
    }
}

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

# Function to safely get a terraform variable
function Get-TerraformVariable {
    param($VarName)
    try {
        $result = echo "var.$VarName" | terraform console 2>$null
        if ($LASTEXITCODE -eq 0 -and $result -and $result -ne "null") {
            $cleanResult = $result.Trim().Trim('"')
            return $cleanResult
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

# Function to get multiple terraform variables individually (reliable approach)
function Get-TerraformVariablesBatch {
    param($VarNames)
    $results = @{}
    
    if ($VarNames.Count -eq 0) {
        return $results
    }
    
    Write-Host "  Processing $($VarNames.Count) variables individually..." -ForegroundColor Gray
    
    $processedCount = 0
    foreach ($varName in $VarNames) {
        $value = Get-TerraformVariable $varName
        if ($value -and $value -ne "null") {
            $results[$varName] = $value
        }
        $processedCount++
        
        # Show progress every 5 variables
        if ($processedCount % 5 -eq 0 -or $processedCount -eq $VarNames.Count) {
            $progress = [math]::Round(($processedCount / $VarNames.Count) * 100)
            Write-Host "    Progress: $processedCount/$($VarNames.Count) ($progress%)" -ForegroundColor Cyan
        }
    }
    
    return $results
}

# Function to get variables by category from variables.tf (performance optimized)
function Get-VariablesByCategory {
    param($Category)
    
    # Use cached content if available
    if ([string]::IsNullOrEmpty($script:variablesContent)) {
        Write-Host "  Loading variables.tf file content..." -ForegroundColor Gray
        $script:variablesContent = Get-Content "variables.tf" -Raw
    }
    
    # Pattern to match variable blocks with specific category tag
    $pattern = "variable\s+`"([^`"]+)`"\s*\{[^}]*description\s*=\s*`"\[$Category\][^`"]*`"[^}]*default\s*=\s*([^}]+)\}"
    $matches = [regex]::Matches($script:variablesContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    # Extract variable names
    $varNames = @()
    foreach ($match in $matches) {
        $varNames += $match.Groups[1].Value
    }
    
    Write-Host "  Found $($varNames.Count) variables with [$Category] tag" -ForegroundColor Gray
    
    # Batch query all variables at once
    if ($varNames.Count -gt 0) {
        return Get-TerraformVariablesBatch $varNames
    } else {
        return @{}
    }
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

# Common terraform initialization
function Initialize-Terraform {
    param($ShowOutput = $false)
    
    if (-not (Test-Path ".terraform")) {
        if ($ShowOutput) {
            Write-Host "Initializing Terraform for variable extraction..." -ForegroundColor Yellow
            terraform init
        } else {
            Write-Host "Initializing Terraform..." -ForegroundColor Yellow
            terraform init | Out-Null
        }
        
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
}

# Common terraform validate
function Invoke-TerraformValidate {
    param($ShowOutput = $false)
    
    if ($ShowOutput) {
        Write-Host "[1/3] Running terraform validate..." -ForegroundColor Cyan
        terraform validate
    } else {
        Write-Host "[1/3] Running terraform validate..." -ForegroundColor Cyan
        terraform validate | Out-Null
    }
    
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
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    Write-Host "✓ Success: terraform validate completed" -ForegroundColor Green
    Write-Host ""
}

# Common terraform plan
function Invoke-TerraformPlan {
    param($ShowOutput = $false)
    
    Write-Host "[2/3] Terraform Plan으로 실행 계획을 작성 중입니다..." -ForegroundColor Cyan
    
    if ($ShowOutput) {
        $planOutput = terraform plan -out=tfplan 2>&1
        $planSuccess = $LASTEXITCODE -eq 0
    } else {
        $planOutput = terraform plan -out=tfplan 2>&1 | Out-Null
        $planSuccess = $LASTEXITCODE -eq 0
    }
    
    if (-not $planSuccess) {
        Write-Host ""
        Write-Host "❌ Terraform Plan 실패!" -ForegroundColor Red
        Write-Host "=========================================" -ForegroundColor Red
        if ($ShowOutput) {
            Write-Host "오류 내용:" -ForegroundColor Yellow
            $planOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        } else {
            Write-Host "오류가 발생했습니다. 'admin' 모드로 실행하여 상세 정보를 확인하세요." -ForegroundColor Yellow
        }
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
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    Write-Host "✓ Success: terraform plan completed" -ForegroundColor Green
    Write-Host ""
}

# Common terraform apply
function Invoke-TerraformApply {
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
            exit 1
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
    }
    else {
        Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
    }
}

# Generate master_config.json
function New-MasterConfigJson {
    param($Variables)
    
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
                public_domain_name = $Variables.public_domain_name
                private_domain_name = $Variables.private_domain_name
                private_hosted_zone_id = $Variables.private_hosted_zone_id
            }
            network = @{
                vpc_cidr = $Variables.vpc_cidr
                web_subnet_cidr = $Variables.web_subnet_cidr
                app_subnet_cidr = $Variables.app_subnet_cidr
                db_subnet_cidr = $Variables.db_subnet_cidr
            }
            load_balancer = @{
                web_lb_service_ip = $Variables.web_lb_service_ip
                app_lb_service_ip = $Variables.app_lb_service_ip
            }
            servers = @{
                web_primary_ip = $Variables.web_ip
                web_secondary_ip = $Variables.web_ip2
                app_primary_ip = $Variables.app_ip
                app_secondary_ip = $Variables.app_ip2
                db_primary_ip = $Variables.db_ip
                bastion_ip = $Variables.bastion_ip
            }
        }
        application = @{
            web_server = @{
                nginx_port = $Variables.nginx_port
                ssl_enabled = [System.Convert]::ToBoolean($Variables.ssl_enabled)
                upstream_target = "app.$($Variables.private_domain_name):$($Variables.app_server_port)"
                fallback_target = "$($Variables.app_ip2):$($Variables.app_server_port)"
                health_check_path = "/health"
                api_proxy_path = "/api"
            }
            app_server = @{
                port = $Variables.app_server_port
                node_env = $Variables.node_env
                database_host = "db.$($Variables.private_domain_name)"
                database_port = $Variables.database_port
                database_name = $Variables.database_name
                session_secret = $Variables.session_secret
            }
            database = @{
                type = $Variables.db_type
                port = $Variables.database_port
                max_connections = $Variables.db_max_connections
                shared_buffers = "256MB"
                effective_cache_size = "1GB"
            }
        }
        security = @{
            firewall = @{
                allowed_public_ips = @("$($Variables.user_public_ip)/32")
                ssh_key_name = $Variables.keypair_name
            }
            ssl = @{
                certificate_path = $Variables.certificate_path
                private_key_path = $Variables.private_key_path
            }
        }
        object_storage = @{
            access_key_id = $Variables.object_storage_access_key_id
            secret_access_key = $Variables.object_storage_secret_access_key
            region = $Variables.object_storage_region
            bucket_name = $Variables.object_storage_bucket_name
            bucket_string = $Variables.object_storage_bucket_string
            private_endpoint = $Variables.object_storage_private_endpoint
            public_endpoint = $Variables.object_storage_public_endpoint
            folders = @{
                media = $Variables.object_storage_media_folder
                audition = $Variables.object_storage_audition_folder
            }
            "_comment" = "Object Storage 설정은 기본 3-tier에서 선택사항입니다"
        }
        deployment = @{
            git_repository = $Variables.git_repository
            git_branch = $Variables.git_branch
            auto_deployment = [System.Convert]::ToBoolean($Variables.auto_deployment)
            rollback_enabled = [System.Convert]::ToBoolean($Variables.rollback_enabled)
        }
        monitoring = @{
            log_level = "info"
            health_check_interval = 30
            metrics_enabled = $true
        }
        user_customization = @{
            "_comment" = "사용자 직접 수정 영역"
            company_name = $Variables.company_name
            admin_email = $Variables.admin_email
            timezone = $Variables.timezone
            backup_retention_days = $Variables.backup_retention_days
        }
    }

    # Convert to JSON and save with error handling
    try {
        $jsonString = $masterConfig | ConvertTo-Json -Depth 10 -ErrorAction Stop
        $jsonString | Out-File -FilePath "master_config.json" -Encoding UTF8 -ErrorAction Stop
        Write-Host "✓ master_config.json created successfully!" -ForegroundColor Green
        return $jsonString
    }
    catch {
        throw "Failed to create master_config.json: $_"
    }
}

# Generate userdata_db.sh script with actual variable values
function Generate-UserdataDbScript {
    param($Variables)
    
    return @"
#!/bin/bash

# Creative Energy Database Server Auto-Installation Script
# Rocky Linux 9.4 PostgreSQL Database Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_db.log"
exec 1> >(tee -a `$LOGFILE)
exec 2> >(tee -a `$LOGFILE >&2)

echo "===================="
echo "DB Server Init Started: `$(date)"
echo "===================="

# Wait for internet connection (HTTP-based check for security group compatibility)
echo "[0/6] Waiting for internet connection..."
MAX_WAIT=300  # 5 minutes maximum wait
WAIT_COUNT=0
until curl -s --connect-timeout 5 http://www.google.com > /dev/null 2>&1; do
    echo "Waiting for internet connection... (`$((WAIT_COUNT * 10))s elapsed)"
    sleep 10
    WAIT_COUNT=`$((WAIT_COUNT + 1))
    if [ `$WAIT_COUNT -gt `$((MAX_WAIT / 10)) ]; then
        echo "Internet connection timeout after `$MAX_WAIT seconds"
        exit 1
    fi
done
echo "Internet connection established"

# Wait for Rocky Linux mirrors to be accessible
echo "[0.5/6] Checking Rocky Linux repositories..."
until curl -s --connect-timeout 10 https://mirrors.rockylinux.org > /dev/null 2>&1; do
    echo "Waiting for Rocky Linux mirrors..."
    sleep 15
done
echo "Rocky Linux repositories accessible"

# Update system packages with retry logic
echo "[1/6] System update..."
for attempt in 1 2 3 4 5; do
    echo "Package installation attempt `$attempt/5"
    if sudo dnf clean all && sudo dnf install -y epel-release; then
        echo "EPEL repository installed successfully"
        break
    else
        echo "EPEL installation attempt `$attempt failed"
        if [ `$attempt -eq 5 ]; then
            echo "All package installation attempts failed"
            exit 1
        fi
        echo "Retrying in 30 seconds..."
        sleep 30
    fi
done

# Update packages with error handling
set +e  # Temporarily disable exit on error for updates
sudo dnf -y update
UPDATE_RESULT=`$?
set -e  # Re-enable exit on error

if [ `$UPDATE_RESULT -ne 0 ]; then
    echo "System update had issues, but continuing with installation..."
fi

# Install additional packages with retry
for attempt in 1 2 3; do
    if sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet; then
        echo "Additional packages installed successfully"
        break
    else
        echo "Additional packages installation attempt `$attempt failed"
        if [ `$attempt -eq 3 ]; then
            echo "Additional packages installation failed, but continuing..."
        else
            sleep 20
        fi
    fi
done

# Clone application repository
echo "[2/6] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Create master configuration from terraform variables
echo "[2.5/6] Creating master configuration from terraform variables..."

# Variables injected by PowerShell deploy script
PUBLIC_DOMAIN_NAME="$($Variables.public_domain_name)"
PRIVATE_DOMAIN_NAME="$($Variables.private_domain_name)"
USER_PUBLIC_IP="$($Variables.user_public_ip)"
KEYPAIR_NAME="$($Variables.keypair_name)"
PRIVATE_HOSTED_ZONE_ID="$($Variables.private_hosted_zone_id)"

VPC_CIDR="$($Variables.vpc_cidr)"
WEB_SUBNET_CIDR="$($Variables.web_subnet_cidr)"
APP_SUBNET_CIDR="$($Variables.app_subnet_cidr)"
DB_SUBNET_CIDR="$($Variables.db_subnet_cidr)"

BASTION_IP="$($Variables.bastion_ip)"
WEB_IP="$($Variables.web_ip)"
WEB_IP2="$($Variables.web_ip2)"
APP_IP="$($Variables.app_ip)"
APP_IP2="$($Variables.app_ip2)"
DB_IP="$($Variables.db_ip)"

WEB_LB_SERVICE_IP="$($Variables.web_lb_service_ip)"
APP_LB_SERVICE_IP="$($Variables.app_lb_service_ip)"

APP_SERVER_PORT="$($Variables.app_server_port)"
DATABASE_PORT="$($Variables.database_port)"
DATABASE_NAME="$($Variables.database_name)"

# Create master_config.json with terraform variables
cat > /home/rocky/master_config.json << EOF
{
  "config_metadata": {
    "version": "1.0.0",
    "created": "`$(date +%Y-%m-%d)",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "generated_from": "variables.tf via deploy_scp_lab_environment.ps1",
    "server_role": "database"
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "`$PUBLIC_DOMAIN_NAME",
      "private_domain_name": "`$PRIVATE_DOMAIN_NAME",
      "private_hosted_zone_id": "`$PRIVATE_HOSTED_ZONE_ID"
    },
    "network": {
      "vpc_cidr": "`$VPC_CIDR",
      "web_subnet_cidr": "`$WEB_SUBNET_CIDR",
      "app_subnet_cidr": "`$APP_SUBNET_CIDR",
      "db_subnet_cidr": "`$DB_SUBNET_CIDR"
    },
    "load_balancer": {
      "web_lb_service_ip": "`$WEB_LB_SERVICE_IP",
      "app_lb_service_ip": "`$APP_LB_SERVICE_IP"
    },
    "servers": {
      "web_primary_ip": "`$WEB_IP",
      "web_secondary_ip": "`$WEB_IP2",
      "app_primary_ip": "`$APP_IP",
      "app_secondary_ip": "`$APP_IP2",
      "db_primary_ip": "`$DB_IP",
      "bastion_ip": "`$BASTION_IP"
    }
  },
  "application": {
    "web_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "upstream_target": "app.`$PRIVATE_DOMAIN_NAME:`$APP_SERVER_PORT",
      "fallback_target": "`$APP_IP2:`$APP_SERVER_PORT",
      "health_check_path": "/health",
      "api_proxy_path": "/api"
    },
    "app_server": {
      "port": `$APP_SERVER_PORT,
      "node_env": "production",
      "database_host": "db.`$PRIVATE_DOMAIN_NAME",
      "database_port": `$DATABASE_PORT,
      "database_name": "`$DATABASE_NAME",
      "session_secret": "your-secret-key-change-in-production"
    },
    "database": {
      "type": "postgresql",
      "port": `$DATABASE_PORT,
      "max_connections": 100,
      "shared_buffers": "256MB",
      "effective_cache_size": "1GB"
    }
  },
  "security": {
    "firewall": {
      "allowed_public_ips": ["`$USER_PUBLIC_IP/32"],
      "ssh_key_name": "`$KEYPAIR_NAME"
    },
    "ssl": {
      "certificate_path": "/etc/ssl/certs/certificate.crt",
      "private_key_path": "/etc/ssl/private/private.key"
    }
  },
  "object_storage": {
    "access_key_id": "",
    "secret_access_key": "",
    "region": "kr-west1",
    "bucket_name": "ceweb",
    "bucket_string": "",
    "private_endpoint": "https://object-store.private.kr-west1.e.samsungsdscloud.com",
    "public_endpoint": "https://object-store.kr-west1.e.samsungsdscloud.com",
    "folders": {
      "media": "media/img",
      "audition": "files/audition"
    },
    "_comment": "Object Storage 설정은 기본 3-tier에서 사용하지 않음 (로컬 파일 저장소 사용)"
  },
  "deployment": {
    "git_repository": "https://github.com/SCPv2/ceweb.git",
    "git_branch": "main",
    "auto_deployment": true,
    "rollback_enabled": true
  },
  "monitoring": {
    "log_level": "info",
    "health_check_interval": 30,
    "metrics_enabled": true
  },
  "user_customization": {
    "_comment": "사용자 직접 수정 영역",
    "company_name": "Creative Energy",
    "admin_email": "admin@company.com",
    "timezone": "Asia/Seoul",
    "backup_retention_days": 30
  }
}
EOF

# Apply master configuration to web-server directory (central location)
sudo cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/master_config.json
sudo chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
echo "Master config created and applied to web-server directory (central location)"
echo "DB server will reference: /home/rocky/ceweb/web-server/master_config.json"

# PostgreSQL installation with auto mode
echo "[3/6] Installing PostgreSQL 16.8..."
cd /home/rocky/ceweb/db-server/vm_db
sudo bash install_postgresql_vm.sh --auto

# Wait for PostgreSQL to be ready
echo "[4/6] Waiting for PostgreSQL to be ready..."
sleep 10
until sudo -u postgres psql -c '\q' 2>/dev/null; do
    echo "Waiting for PostgreSQL..."
    sleep 5
done

# Verify database setup
echo "[5/6] Verifying database setup..."
sudo -u postgres psql -c "SELECT version();"
sudo -u postgres psql -d cedb -c "SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public';"

# Create completion marker
echo "[6/6] Database setup completed successfully!"
echo "Database server ready: `$(date)" > /home/rocky/DB_Server_Ready.log
chown rocky:rocky /home/rocky/DB_Server_Ready.log

echo "===================="
echo "DB Server Init Completed: `$(date)"
echo "DB Connection: db.$($Variables.private_domain_name):$($Variables.database_port)"
echo "Database: cedb"
echo "Admin User: ceadmin"
echo "===================="
"@
}

# Generate userdata_app.sh script with actual variable values
function Generate-UserdataAppScript {
    param($Variables)
    
    return @"
#!/bin/bash

# Creative Energy Application Server Auto-Installation Script
# Rocky Linux 9.4 Node.js App Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_app.log"
exec 1> >(tee -a `$LOGFILE)
exec 2> >(tee -a `$LOGFILE >&2)

echo "===================="
echo "App Server Init Started: `$(date)"
echo "===================="

# Wait for internet connection (HTTP-based check)
echo "[0/8] Waiting for internet connection..."
MAX_WAIT=300
WAIT_COUNT=0
until curl -s --connect-timeout 5 http://www.google.com > /dev/null 2>&1; do
    echo "Waiting for internet connection... (`$((WAIT_COUNT * 10))s elapsed)"
    sleep 10
    WAIT_COUNT=`$((WAIT_COUNT + 1))
    if [ `$WAIT_COUNT -gt `$((MAX_WAIT / 10)) ]; then
        echo "Internet connection timeout after `$MAX_WAIT seconds"
        exit 1
    fi
done
echo "Internet connection established"

# Check Rocky Linux repositories
echo "[0.5/8] Checking Rocky Linux repositories..."
until curl -s --connect-timeout 10 https://mirrors.rockylinux.org > /dev/null 2>&1; do
    echo "Waiting for Rocky Linux mirrors..."
    sleep 15
done
echo "Rocky Linux repositories accessible"

# Update system packages with retry logic
echo "[1/8] System update..."
for attempt in 1 2 3 4 5; do
    echo "Package installation attempt `$attempt/5"
    if sudo dnf clean all && sudo dnf install -y epel-release; then
        echo "EPEL repository installed successfully"
        break
    else
        echo "EPEL installation attempt `$attempt failed"
        if [ `$attempt -eq 5 ]; then
            echo "All package installation attempts failed"
            exit 1
        fi
        echo "Retrying in 30 seconds..."
        sleep 30
    fi
done

# Update packages with error handling
set +e
sudo dnf -y update
UPDATE_RESULT=`$?
sudo dnf -y upgrade
UPGRADE_RESULT=`$?
set -e

if [ `$UPDATE_RESULT -ne 0 ] || [ `$UPGRADE_RESULT -ne 0 ]; then
    echo "System update/upgrade had issues, but continuing..."
fi

# Install additional packages with retry
for attempt in 1 2 3; do
    if sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet postgresql; then
        echo "Additional packages installed successfully"
        break
    else
        echo "Additional packages installation attempt `$attempt failed"
        if [ `$attempt -eq 3 ]; then
            echo "Additional packages installation failed, but continuing..."
        else
            sleep 20
        fi
    fi
done

# Clone application repository
echo "[2/8] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Create master configuration from terraform variables  
echo "[2.5/8] Creating master configuration from terraform variables..."

# Variables injected by PowerShell deploy script
PUBLIC_DOMAIN_NAME="$($Variables.public_domain_name)"
PRIVATE_DOMAIN_NAME="$($Variables.private_domain_name)"
USER_PUBLIC_IP="$($Variables.user_public_ip)"
KEYPAIR_NAME="$($Variables.keypair_name)"
PRIVATE_HOSTED_ZONE_ID="$($Variables.private_hosted_zone_id)"

VPC_CIDR="$($Variables.vpc_cidr)"
WEB_SUBNET_CIDR="$($Variables.web_subnet_cidr)"
APP_SUBNET_CIDR="$($Variables.app_subnet_cidr)"
DB_SUBNET_CIDR="$($Variables.db_subnet_cidr)"

BASTION_IP="$($Variables.bastion_ip)"
WEB_IP="$($Variables.web_ip)"
WEB_IP2="$($Variables.web_ip2)"
APP_IP="$($Variables.app_ip)"
APP_IP2="$($Variables.app_ip2)"
DB_IP="$($Variables.db_ip)"

WEB_LB_SERVICE_IP="$($Variables.web_lb_service_ip)"
APP_LB_SERVICE_IP="$($Variables.app_lb_service_ip)"

APP_SERVER_PORT="$($Variables.app_server_port)"
DATABASE_PORT="$($Variables.database_port)"
DATABASE_NAME="$($Variables.database_name)"

# Create master_config.json with terraform variables
cat > /home/rocky/master_config.json << EOF
{
  "config_metadata": {
    "version": "1.0.0",
    "created": "`$(date +%Y-%m-%d)",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "generated_from": "variables.tf via deploy_scp_lab_environment.ps1",
    "server_role": "application"
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "`$PUBLIC_DOMAIN_NAME",
      "private_domain_name": "`$PRIVATE_DOMAIN_NAME",
      "private_hosted_zone_id": "`$PRIVATE_HOSTED_ZONE_ID"
    },
    "network": {
      "vpc_cidr": "`$VPC_CIDR",
      "web_subnet_cidr": "`$WEB_SUBNET_CIDR",
      "app_subnet_cidr": "`$APP_SUBNET_CIDR",
      "db_subnet_cidr": "`$DB_SUBNET_CIDR"
    },
    "load_balancer": {
      "web_lb_service_ip": "`$WEB_LB_SERVICE_IP",
      "app_lb_service_ip": "`$APP_LB_SERVICE_IP"
    },
    "servers": {
      "web_primary_ip": "`$WEB_IP",
      "web_secondary_ip": "`$WEB_IP2",
      "app_primary_ip": "`$APP_IP",
      "app_secondary_ip": "`$APP_IP2",
      "db_primary_ip": "`$DB_IP",
      "bastion_ip": "`$BASTION_IP"
    }
  },
  "application": {
    "web_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "upstream_target": "app.`$PRIVATE_DOMAIN_NAME:`$APP_SERVER_PORT",
      "fallback_target": "`$APP_IP2:`$APP_SERVER_PORT",
      "health_check_path": "/health",
      "api_proxy_path": "/api"
    },
    "app_server": {
      "port": `$APP_SERVER_PORT,
      "node_env": "production",
      "database_host": "db.`$PRIVATE_DOMAIN_NAME",
      "database_port": `$DATABASE_PORT,
      "database_name": "`$DATABASE_NAME",
      "session_secret": "your-secret-key-change-in-production"
    },
    "database": {
      "type": "postgresql",
      "port": `$DATABASE_PORT,
      "max_connections": 100,
      "shared_buffers": "256MB",
      "effective_cache_size": "1GB"
    }
  },
  "security": {
    "firewall": {
      "allowed_public_ips": ["`$USER_PUBLIC_IP/32"],
      "ssh_key_name": "`$KEYPAIR_NAME"
    },
    "ssl": {
      "certificate_path": "/etc/ssl/certs/certificate.crt",
      "private_key_path": "/etc/ssl/private/private.key"
    }
    },
    "object_storage": {
        "access_key_id": "$($Variables.object_storage_access_key_id)",
        "bucket_name": "$($Variables.object_storage_bucket_name)",
        "bucket_string": "$($Variables.object_storage_bucket_string)",
        "public_endpoint": "$($Variables.object_storage_public_endpoint)",
        "region": "$($Variables.object_storage_region)",
        "folders": {
            "media": "$($Variables.object_storage_media_folder)",
            "audition": "$($Variables.object_storage_audition_folder)"
        },
        "private_endpoint": "$($Variables.object_storage_private_endpoint)",
        "secret_access_key": "$($Variables.object_storage_secret_access_key)",
        "_comment": "Object Storage 설정은 기본 3-tier에서 선택사항입니다"
    },
    "user_customization": {
        "backup_retention_days": $($Variables.backup_retention_days),
        "admin_email": "$($Variables.admin_email)",
        "timezone": "$($Variables.timezone)",
        "company_name": "$($Variables.company_name)",
        "_comment": "사용자 직접 수정 영역"
    },
    "infrastructure": {
        "load_balancer": {
            "web_lb_service_ip": "$($Variables.web_lb_service_ip)",
            "app_lb_service_ip": "$($Variables.app_lb_service_ip)"
        },
        "domain": {
            "private_hosted_zone_id": "$($Variables.private_hosted_zone_id)",
            "private_domain_name": "$($Variables.private_domain_name)",
            "public_domain_name": "$($Variables.public_domain_name)"
        },
        "servers": {
            "web_primary_ip": "$($Variables.web_ip)",
            "app_primary_ip": "$($Variables.app_ip)",
            "bastion_ip": "$($Variables.bastion_ip)",
            "app_secondary_ip": "$($Variables.app_ip2)",
            "web_secondary_ip": "$($Variables.web_ip2)",
            "db_primary_ip": "$($Variables.db_ip)"
        },
        "network": {
            "app_subnet_cidr": "$($Variables.app_subnet_cidr)",
            "vpc_cidr": "$($Variables.vpc_cidr)",
            "web_subnet_cidr": "$($Variables.web_subnet_cidr)",
            "db_subnet_cidr": "$($Variables.db_subnet_cidr)"
        }
    },
    "deployment": {
        "rollback_enabled": $($Variables.rollback_enabled.ToString().ToLower()),
        "git_repository": "$($Variables.git_repository)",
        "git_branch": "$($Variables.git_branch)",
        "auto_deployment": $($Variables.auto_deployment.ToString().ToLower())
    },
    "config_metadata": {
        "created": "`$(date +%Y-%m-%d)",
        "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
        "version": "1.0.0",
        "generated_from": "variables.tf via deploy_scp_lab_environment.ps1"
    },
    "monitoring": {
        "health_check_interval": 30,
        "metrics_enabled": true,
        "log_level": "info"
    },
    "application": {
        "web_server": {
            "api_proxy_path": "/api",
            "upstream_target": "app.$($Variables.private_domain_name):$($Variables.app_server_port)",
            "health_check_path": "/health",
            "ssl_enabled": $($Variables.ssl_enabled.ToString().ToLower()),
            "nginx_port": $($Variables.nginx_port),
            "fallback_target": "$($Variables.app_ip2):$($Variables.app_server_port)"
        },
        "database": {
            "port": $($Variables.database_port),
            "shared_buffers": "256MB",
            "max_connections": $($Variables.db_max_connections),
            "type": "$($Variables.db_type)",
            "effective_cache_size": "1GB"
        },
        "app_server": {
            "port": $($Variables.app_server_port),
            "database_port": $($Variables.database_port),
            "node_env": "$($Variables.node_env)",
            "session_secret": "$($Variables.session_secret)",
            "database_host": "db.$($Variables.private_domain_name)",
            "database_name": "$($Variables.database_name)"
        }
    }
}
EOF

# Set proper ownership
sudo chown rocky:rocky /home/rocky/master_config.json

# Apply master configuration to web-server directory only (central location)
echo "[2.5/8] Applying master configuration..."
if [ -f /home/rocky/master_config.json ]; then
    sudo cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/master_config.json
    sudo chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    sudo rm -f /home/rocky/master_config.json
    echo "Master config applied to web-server directory (central location)"
    echo "App server will reference: /home/rocky/ceweb/web-server/master_config.json"
    echo "Temporary config file cleaned up"
else
    echo "Warning: master_config.json not found, using default configuration"
fi

# Wait for database to be ready (DB server dependency)
echo "[3/8] Waiting for database server..."
DB_HOST="db.$($Variables.private_domain_name)"
DB_PORT="$($Variables.database_port)"
until nc -z `$DB_HOST `$DB_PORT 2>/dev/null; do
    echo "Waiting for database server (`$DB_HOST:`$DB_PORT)..."
    sleep 10
done
echo "Database server is ready!"

# Install Node.js and application
echo "[4/8] Installing Node.js and application..."
cd /home/rocky/ceweb/app-server
sudo bash install_app_server.sh

# Verify Node.js application
echo "[5/8] Verifying Node.js application..."
sleep 5
until curl -f http://localhost:$($Variables.app_server_port)/health 2>/dev/null; do
    echo "Waiting for application to start..."
    sleep 5
done

# Test database connectivity
echo "[6/8] Testing database connectivity..."
sudo -u rocky node -e "
const { Client } = require('pg');
const client = new Client({
    host: '`$DB_HOST',
    port: `$DB_PORT,
    database: '$($Variables.database_name.Split('_')[0])db',
    user: 'ceadmin',
    password: 'ceadmin123!'
});
client.connect().then(() => {
    console.log('Database connection successful');
    client.end();
}).catch(err => {
    console.error('Database connection failed:', err.message);
});
"

# Verify API endpoints
echo "[7/8] Testing API endpoints..."
curl -f http://localhost:$($Variables.app_server_port)/api/orders/products || echo "Products API not yet available"
curl -f http://localhost:$($Variables.app_server_port)/health || echo "Health check not yet available"

# Create completion marker
echo "[8/8] Application setup completed successfully!"
echo "Application server ready: `$(date)" > /home/rocky/App_Server_Ready.log
chown rocky:rocky /home/rocky/App_Server_Ready.log

echo "===================="
echo "App Server Init Completed: `$(date)"
echo "App Service: $($Variables.app_ip):$($Variables.app_server_port) (or $($Variables.app_ip2):$($Variables.app_server_port))"
echo "Health Check: /health"
echo "API Endpoints: /api/orders/products"
echo "===================="
"@
}

# Generate userdata_web.sh script with actual variable values
function Generate-UserdataWebScript {
    param($Variables)
    
    # For now, return a simplified version - can be expanded later
    return @"
#!/bin/bash

# Creative Energy Web Server Auto-Installation Script
# Rocky Linux 9.4 Nginx Web Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_web.log"
exec 1> >(tee -a `$LOGFILE)
exec 2> >(tee -a `$LOGFILE >&2)

echo "===================="
echo "Web Server Init Started: `$(date)"
echo "===================="

# Wait for internet connection (HTTP-based check)
echo "[0/8] Waiting for internet connection..."
MAX_WAIT=300
WAIT_COUNT=0
until curl -s --connect-timeout 5 http://www.google.com > /dev/null 2>&1; do
    echo "Waiting for internet connection... (`$((WAIT_COUNT * 10))s elapsed)"
    sleep 10
    WAIT_COUNT=`$((WAIT_COUNT + 1))
    if [ `$WAIT_COUNT -gt `$((MAX_WAIT / 10)) ]; then
        echo "Internet connection timeout after `$MAX_WAIT seconds"
        exit 1
    fi
done
echo "Internet connection established"

# Check Rocky Linux repositories
echo "[0.5/8] Checking Rocky Linux repositories..."
until curl -s --connect-timeout 10 https://mirrors.rockylinux.org > /dev/null 2>&1; do
    echo "Waiting for Rocky Linux mirrors..."
    sleep 15
done
echo "Rocky Linux repositories accessible"

# Update system packages with retry logic
echo "[1/8] System update..."
for attempt in 1 2 3 4 5; do
    echo "Package installation attempt `$attempt/5"
    if sudo dnf clean all && sudo dnf install -y epel-release; then
        echo "EPEL repository installed successfully"
        break
    else
        echo "EPEL installation attempt `$attempt failed"
        if [ `$attempt -eq 5 ]; then
            echo "All package installation attempts failed"
            exit 1
        fi
        echo "Retrying in 30 seconds..."
        sleep 30
    fi
done

# Update packages with error handling
set +e
sudo dnf -y update
UPDATE_RESULT=`$?
sudo dnf -y upgrade
UPGRADE_RESULT=`$?
set -e

if [ `$UPDATE_RESULT -ne 0 ] || [ `$UPGRADE_RESULT -ne 0 ]; then
    echo "System update/upgrade had issues, but continuing..."
fi

# Install additional packages with retry
for attempt in 1 2 3; do
    if sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet; then
        echo "Additional packages installed successfully"
        break
    else
        echo "Additional packages installation attempt `$attempt failed"
        if [ `$attempt -eq 3 ]; then
            echo "Additional packages installation failed, but continuing..."
        else
            sleep 20
        fi
    fi
done

# Clone application repository
echo "[2/8] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Create master configuration from terraform variables  
echo "[2.5/8] Creating master configuration from terraform variables..."

# Variables injected by PowerShell deploy script
PUBLIC_DOMAIN_NAME="$($Variables.public_domain_name)"
PRIVATE_DOMAIN_NAME="$($Variables.private_domain_name)"
USER_PUBLIC_IP="$($Variables.user_public_ip)"
KEYPAIR_NAME="$($Variables.keypair_name)"
PRIVATE_HOSTED_ZONE_ID="$($Variables.private_hosted_zone_id)"

VPC_CIDR="$($Variables.vpc_cidr)"
WEB_SUBNET_CIDR="$($Variables.web_subnet_cidr)"
APP_SUBNET_CIDR="$($Variables.app_subnet_cidr)"
DB_SUBNET_CIDR="$($Variables.db_subnet_cidr)"

BASTION_IP="$($Variables.bastion_ip)"
WEB_IP="$($Variables.web_ip)"
WEB_IP2="$($Variables.web_ip2)"
APP_IP="$($Variables.app_ip)"
APP_IP2="$($Variables.app_ip2)"
DB_IP="$($Variables.db_ip)"

WEB_LB_SERVICE_IP="$($Variables.web_lb_service_ip)"
APP_LB_SERVICE_IP="$($Variables.app_lb_service_ip)"

APP_SERVER_PORT="$($Variables.app_server_port)"
DATABASE_PORT="$($Variables.database_port)"
DATABASE_NAME="$($Variables.database_name)"

# Create master_config.json with terraform variables
cat > /home/rocky/master_config.json << EOF
{
  "config_metadata": {
    "version": "1.0.0",
    "created": "`$(date +%Y-%m-%d)",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "generated_from": "variables.tf via deploy_scp_lab_environment.ps1",
    "server_role": "web"
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "`$PUBLIC_DOMAIN_NAME",
      "private_domain_name": "`$PRIVATE_DOMAIN_NAME",
      "private_hosted_zone_id": "`$PRIVATE_HOSTED_ZONE_ID"
    },
    "network": {
      "vpc_cidr": "`$VPC_CIDR",
      "web_subnet_cidr": "`$WEB_SUBNET_CIDR",
      "app_subnet_cidr": "`$APP_SUBNET_CIDR",
      "db_subnet_cidr": "`$DB_SUBNET_CIDR"
    },
    "load_balancer": {
      "web_lb_service_ip": "`$WEB_LB_SERVICE_IP",
      "app_lb_service_ip": "`$APP_LB_SERVICE_IP"
    },
    "servers": {
      "web_primary_ip": "`$WEB_IP",
      "web_secondary_ip": "`$WEB_IP2",
      "app_primary_ip": "`$APP_IP",
      "app_secondary_ip": "`$APP_IP2",
      "db_primary_ip": "`$DB_IP",
      "bastion_ip": "`$BASTION_IP"
    }
  },
  "application": {
    "web_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "upstream_target": "app.`$PRIVATE_DOMAIN_NAME:`$APP_SERVER_PORT",
      "fallback_target": "`$APP_IP2:`$APP_SERVER_PORT",
      "health_check_path": "/health",
      "api_proxy_path": "/api"
    },
    "app_server": {
      "port": `$APP_SERVER_PORT,
      "node_env": "production",
      "database_host": "db.`$PRIVATE_DOMAIN_NAME",
      "database_port": `$DATABASE_PORT,
      "database_name": "`$DATABASE_NAME",
      "session_secret": "your-secret-key-change-in-production"
    },
    "database": {
      "type": "postgresql",
      "port": `$DATABASE_PORT,
      "max_connections": 100,
      "shared_buffers": "256MB",
      "effective_cache_size": "1GB"
    }
  },
  "security": {
    "firewall": {
      "allowed_public_ips": ["`$USER_PUBLIC_IP/32"],
      "ssh_key_name": "`$KEYPAIR_NAME"
    },
    "ssl": {
      "certificate_path": "/etc/ssl/certs/certificate.crt",
      "private_key_path": "/etc/ssl/private/private.key"
    }
  }
}
EOF

# Set proper ownership
sudo chown rocky:rocky /home/rocky/master_config.json

# Apply master configuration to web-server directory only
echo "[2.5/8] Applying master configuration..."
if [ -f /home/rocky/master_config.json ]; then
    sudo cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/master_config.json
    sudo chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    sudo rm -f /home/rocky/master_config.json
    echo "Master config applied to web-server directory (central location)"
    echo "Temporary config file cleaned up"
else
    echo "Warning: master_config.json not found, using default configuration"
fi

# Wait for app server to be ready (App server dependency)
echo "[3/8] Waiting for application servers..."
APP_HOST1="app.$($Variables.private_domain_name)"
APP_HOST2="$($Variables.app_ip2)"
APP_PORT="$($Variables.app_server_port)"

# Wait for at least one app server
until nc -z `$APP_HOST1 `$APP_PORT 2>/dev/null || nc -z `$APP_HOST2 `$APP_PORT 2>/dev/null; do
    echo "Waiting for application servers (`$APP_HOST1:`$APP_PORT or `$APP_HOST2:`$APP_PORT)..."
    sleep 10
done
echo "Application servers are ready!"

# Install Nginx and web application
echo "[4/8] Installing Nginx and web application..."
cd /home/rocky/ceweb/web-server
sudo bash install_web_server.sh

# Test app server connectivity through Load Balancer
echo "[5/8] Testing application server connectivity..."
LB_APP_IP="app.$($Variables.private_domain_name)"
if nc -z `$LB_APP_IP `$APP_PORT 2>/dev/null; then
    echo "App Load Balancer is working"
else
    echo "App Load Balancer not accessible, using direct connection"
    # Modify nginx config to use direct app server connection (bypass LB failure)
    sudo sed -i "s|proxy_pass http://app.$($Variables.private_domain_name):$($Variables.app_server_port);|proxy_pass http://`$APP_HOST2:$($Variables.app_server_port);|g" /etc/nginx/conf.d/creative-energy.conf
    sudo sed -i "s|proxy_pass http://app.$($Variables.private_domain_name):$($Variables.app_server_port)/health;|proxy_pass http://`$APP_HOST2:$($Variables.app_server_port)/health;|g" /etc/nginx/conf.d/creative-energy.conf
    sudo nginx -t && sudo systemctl restart nginx
    echo "Configured direct connection to app server"
fi

# Verify web server
echo "[6/8] Verifying web server..."
sleep 5
curl -I http://localhost/ || echo "Web server not yet fully ready"

# Test API proxy functionality
echo "[7/8] Testing API proxy..."
curl -f http://localhost/health || echo "Health check proxy not yet ready"
curl -f http://localhost/api/orders/products || echo "API proxy not yet ready"

# Create completion marker
echo "[8/8] Web server setup completed successfully!"
echo "Web server ready: `$(date)" > /home/rocky/Web_Server_Ready.log
chown rocky:rocky /home/rocky/Web_Server_Ready.log

echo "===================="
echo "Web Server Init Completed: `$(date)"
echo "Web Service: $($Variables.web_ip):$($Variables.nginx_port) (or $($Variables.web_ip2):$($Variables.nginx_port))"
echo "Load Balancer: $($Variables.web_lb_service_ip):$($Variables.nginx_port)"
echo "Proxy to App: `$APP_HOST2:$($Variables.app_server_port) (direct connection)"
echo "===================="
"@
}

# Generate userdata files with actual variable values
function Update-UserdataFiles {
    param($Variables)
    
    Write-Host "Updating variables.tf and userdata files with actual variable values..." -ForegroundColor Cyan
    
    # Extract variable values for replacement
    $publicDomain = $Variables.public_domain_name
    $privateDomain = $Variables.private_domain_name
    $userPublicIP = $Variables.user_public_ip
    $keypairName = $Variables.keypair_name
    $privateHostedZoneId = $Variables.private_hosted_zone_id
    
    # Update variables.tf default values
    Write-Host "  Processing variables.tf..." -ForegroundColor Yellow
    if (Test-Path "variables.tf") {
        $content = Get-Content "variables.tf" -Raw
        
        # Update each variable's default value using more specific regex patterns
        $content = $content -replace '(variable\s+"public_domain_name".*?default\s*=\s*)"[^"]*"', "`$1`"$publicDomain`""
        $content = $content -replace '(variable\s+"private_domain_name".*?default\s*=\s*)"[^"]*"', "`$1`"$privateDomain`""
        $content = $content -replace '(variable\s+"user_public_ip".*?default\s*=\s*)"[^"]*"', "`$1`"$userPublicIP`""
        $content = $content -replace '(variable\s+"keypair_name".*?default\s*=\s*)"[^"]*"', "`$1`"$keypairName`""
        $content = $content -replace '(variable\s+"private_hosted_zone_id".*?default\s*=\s*)"[^"]*"', "`$1`"$privateHostedZoneId`""
        
        $content | Set-Content "variables.tf" -Encoding UTF8
        Write-Host "  ✓ variables.tf updated with user input values" -ForegroundColor Green
    }
    
    # Update userdata_db.sh
    Write-Host "  Processing userdata_db.sh..." -ForegroundColor Yellow
    if (Test-Path "userdata_db.sh") {
        $content = Get-Content "userdata_db.sh" -Raw
        $content = $content -replace 'PUBLIC_DOMAIN_NAME="[^"]*"', "PUBLIC_DOMAIN_NAME=`"$publicDomain`""
        $content = $content -replace 'PRIVATE_DOMAIN_NAME="[^"]*"', "PRIVATE_DOMAIN_NAME=`"$privateDomain`""
        $content = $content -replace 'USER_PUBLIC_IP="[^"]*"', "USER_PUBLIC_IP=`"$userPublicIP`""
        $content = $content -replace 'KEYPAIR_NAME="[^"]*"', "KEYPAIR_NAME=`"$keypairName`""
        $content = $content -replace 'PRIVATE_HOSTED_ZONE_ID="[^"]*"', "PRIVATE_HOSTED_ZONE_ID=`"$privateHostedZoneId`""
        $content = $content -replace '"public_domain_name":\s*"[^"]*"', "`"public_domain_name`": `"$publicDomain`""
        $content = $content -replace '"private_domain_name":\s*"[^"]*"', "`"private_domain_name`": `"$privateDomain`""
        $content | Set-Content "userdata_db.sh" -NoNewline -Encoding UTF8
        Write-Host "  ✓ userdata_db.sh updated with variable values" -ForegroundColor Green
    }
    
    # Update userdata_app.sh
    Write-Host "  Processing userdata_app.sh..." -ForegroundColor Yellow
    if (Test-Path "userdata_app.sh") {
        $content = Get-Content "userdata_app.sh" -Raw
        $content = $content -replace 'PUBLIC_DOMAIN_NAME="[^"]*"', "PUBLIC_DOMAIN_NAME=`"$publicDomain`""
        $content = $content -replace 'PRIVATE_DOMAIN_NAME="[^"]*"', "PRIVATE_DOMAIN_NAME=`"$privateDomain`""
        $content = $content -replace 'USER_PUBLIC_IP="[^"]*"', "USER_PUBLIC_IP=`"$userPublicIP`""
        $content = $content -replace 'KEYPAIR_NAME="[^"]*"', "KEYPAIR_NAME=`"$keypairName`""
        $content = $content -replace 'PRIVATE_HOSTED_ZONE_ID="[^"]*"', "PRIVATE_HOSTED_ZONE_ID=`"$privateHostedZoneId`""
        $content = $content -replace '"public_domain_name":\s*"[^"]*"', "`"public_domain_name`": `"$publicDomain`""
        $content = $content -replace '"private_domain_name":\s*"[^"]*"', "`"private_domain_name`": `"$privateDomain`""
        $content | Set-Content "userdata_app.sh" -NoNewline -Encoding UTF8
        Write-Host "  ✓ userdata_app.sh updated with variable values" -ForegroundColor Green
    }
    
    # Update userdata_web.sh
    Write-Host "  Processing userdata_web.sh..." -ForegroundColor Yellow
    if (Test-Path "userdata_web.sh") {
        $content = Get-Content "userdata_web.sh" -Raw
        $content = $content -replace 'PUBLIC_DOMAIN_NAME="[^"]*"', "PUBLIC_DOMAIN_NAME=`"$publicDomain`""
        $content = $content -replace 'PRIVATE_DOMAIN_NAME="[^"]*"', "PRIVATE_DOMAIN_NAME=`"$privateDomain`""
        $content = $content -replace 'USER_PUBLIC_IP="[^"]*"', "USER_PUBLIC_IP=`"$userPublicIP`""
        $content = $content -replace 'KEYPAIR_NAME="[^"]*"', "KEYPAIR_NAME=`"$keypairName`""
        $content = $content -replace 'PRIVATE_HOSTED_ZONE_ID="[^"]*"', "PRIVATE_HOSTED_ZONE_ID=`"$privateHostedZoneId`""
        $content = $content -replace '"public_domain_name":\s*"[^"]*"', "`"public_domain_name`": `"$publicDomain`""
        $content = $content -replace '"private_domain_name":\s*"[^"]*"', "`"private_domain_name`": `"$privateDomain`""
        $content | Set-Content "userdata_web.sh" -NoNewline -Encoding UTF8
        Write-Host "  ✓ userdata_web.sh updated with variable values" -ForegroundColor Green
    }
    
    Write-Host "✓ All userdata files updated successfully with actual variable values!" -ForegroundColor Green
    
    # Clean up temporary variables.json file
    if (Test-Path "variables.json") {
        Remove-Item "variables.json" -Force
        if ($global:ValidationMode) {
            Write-Host "✓ Temporary variables.json file cleaned up" -ForegroundColor Green
        }
    }
    Write-Host ""
}

# Load all variables for deployment using JSON parsing (fast alternative)
function Get-AllVariablesForDeployment {
    param(
        [switch]$Force = $false  # Force reload even if cache is valid
    )
    
    if ($global:ValidationMode) {
        Write-Host "⚡ JSON 기반 고속 변수 로딩..." -ForegroundColor Cyan
    }
    $loadStartTime = Get-Date
    
    # Get all variables from JSON (super fast)
    $allVars = Get-VariablesFromJson
    
    # Extract by categories for compatibility
    $userInputVars = Get-VariablesFromJson -Category "USER_INPUT"
    $cewebRequiredVars = Get-VariablesFromJson -Category "CEWEB_REQUIRED" 
    $terraformInfraVars = Get-VariablesFromJson -Category "TERRAFORM_INFRA"
    
    if ($global:ValidationMode) {
        Write-Host "  ✅ USER_INPUT: $($userInputVars.Count) variables" -ForegroundColor Green
        Write-Host "  ✅ CEWEB_REQUIRED: $($cewebRequiredVars.Count) variables" -ForegroundColor Green  
        Write-Host "  ✅ TERRAFORM_INFRA: $($terraformInfraVars.Count) variables" -ForegroundColor Green
    }

    # Combine all variables for master_config.json generation
    $variables = @{}
    $userInputVars.GetEnumerator() | ForEach-Object { $variables[$_.Key] = $_.Value }
    $cewebRequiredVars.GetEnumerator() | ForEach-Object { $variables[$_.Key] = $_.Value }
    $terraformInfraVars.GetEnumerator() | ForEach-Object { $variables[$_.Key] = $_.Value }

    $loadEndTime = Get-Date
    $loadDuration = [math]::Round(($loadEndTime - $loadStartTime).TotalSeconds, 2)

    if ($global:ValidationMode) {
        Write-Host "⚡ JSON 기반 변수 로딩 완료! ($loadDuration 초)" -ForegroundColor Green
        Write-Host "  📊 총 $($variables.Count)개 변수 로드 완료" -ForegroundColor White
        
        # Debug: Show sample variables
        Write-Host "  🔍 변수 샘플 확인:" -ForegroundColor Yellow
        if ($variables.ContainsKey("public_domain_name")) {
            Write-Host "  Public Domain: $($variables.public_domain_name)" -ForegroundColor White
        } else { Write-Host "  ❌ public_domain_name 키 없음" -ForegroundColor Red }
        
        if ($variables.ContainsKey("private_domain_name")) {
            Write-Host "  Private Domain: $($variables.private_domain_name)" -ForegroundColor White  
        } else { Write-Host "  ❌ private_domain_name 키 없음" -ForegroundColor Red }
        
        if ($variables.ContainsKey("user_public_ip")) {
            Write-Host "  User IP: $($variables.user_public_ip)" -ForegroundColor White
        } else { Write-Host "  ❌ user_public_ip 키 없음" -ForegroundColor Red }
        
        if ($variables.ContainsKey("keypair_name")) {
            Write-Host "  SSH Key: $($variables.keypair_name)" -ForegroundColor White
        } else { Write-Host "  ❌ keypair_name 키 없음" -ForegroundColor Red }
        
        # Debug: Show first few variable keys
        Write-Host "  🗝️  처음 5개 변수 키: $($variables.Keys | Select-Object -First 5 | Out-String)" -ForegroundColor Gray
        Write-Host ""
    }

    return $variables
}

# Function to invalidate cache when variables are updated
function Reset-VariablesCache {
    param(
        [string[]]$Categories = @("ALL")
    )
    
    foreach ($category in $Categories) {
        switch ($category.ToUpper()) {
            "USER_INPUT" {
                $script:userInputCacheValid = $false
                $script:userInputCache = $null
                if ($global:ValidationMode) {
                    Write-Host "✓ USER_INPUT 변수 캐시가 무효화되었습니다." -ForegroundColor Yellow
                }
            }
            "CEWEB_REQUIRED" {
                $script:cewebRequiredCacheValid = $false
                $script:cewebRequiredCache = $null
                if ($global:ValidationMode) {
                    Write-Host "✓ CEWEB_REQUIRED 변수 캐시가 무효화되었습니다." -ForegroundColor Yellow
                }
            }
            "TERRAFORM_INFRA" {
                $script:terraformInfraCacheValid = $false
                $script:terraformInfraCache = $null
                if ($global:ValidationMode) {
                    Write-Host "✓ TERRAFORM_INFRA 변수 캐시가 무효화되었습니다." -ForegroundColor Yellow
                }
            }
            "ALL" {
                $script:variablesCacheValid = $false
                $script:allVariablesCache = $null
                $script:userInputCacheValid = $false
                $script:userInputCache = $null
                $script:cewebRequiredCacheValid = $false
                $script:cewebRequiredCache = $null
                $script:terraformInfraCacheValid = $false
                $script:terraformInfraCache = $null
                if ($global:ValidationMode) {
                    Write-Host "✓ 모든 변수 캐시가 무효화되었습니다." -ForegroundColor Yellow
                }
            }
        }
    }
}

# Function to update a single variable value in cache (if cache is valid)
function Update-VariableInCache {
    param(
        [string]$VariableName,
        [string]$NewValue
    )
    
    if ($script:variablesCacheValid -and $script:allVariablesCache) {
        $script:allVariablesCache[$VariableName] = $NewValue
        Write-Host "✓ 캐시에서 $VariableName 변수가 업데이트되었습니다: $NewValue" -ForegroundColor Green
    }
}

#endregion

#region 개발자 모드 파트 (Developer Mode)
# ==========================================================
# 개발자 모드 - 상세 검증 및 모든 출력 표시
# ==========================================================

# Function to get variable list from master_config.json.tpl
function Get-MasterConfigVariables {
    param($Category)
    
    if (-not (Test-Path "master_config.json.tpl")) {
        Write-Host "⚠️ master_config.json.tpl 파일을 찾을 수 없습니다." -ForegroundColor Yellow
        return @()
    }
    
    try {
        $tplContent = Get-Content "master_config.json.tpl" -Raw -Encoding UTF8
        $json = $tplContent | ConvertFrom-Json
        
        switch ($Category) {
            "USER_INPUT" {
                if ($json.user_input_variables) {
                    return ($json.user_input_variables.PSObject.Properties | Where-Object { $_.Name -ne "_comment" }).Name
                }
            }
            "CEWEB_REQUIRED" {
                if ($json.ceweb_required_variables) {
                    return ($json.ceweb_required_variables.PSObject.Properties | Where-Object { $_.Name -ne "_comment" }).Name
                }
            }
        }
        return @()
    } catch {
        Write-Host "⚠️ master_config.json.tpl 파싱 실패: $_" -ForegroundColor Yellow
        return @()
    }
}

# Function to validate variables between variables.tf and master_config.json.tpl
function Test-VariableConsistency {
    param($Category)
    
    Write-Host "  $Category 변수 일관성 검사 중..." -ForegroundColor Gray
    
    # Get variables from both sources
    $variablesTfVars = Get-VariablesByCategory $Category
    $masterConfigVars = Get-MasterConfigVariables $Category
    
    $variablesTfVarNames = $variablesTfVars.Keys | Sort-Object
    $masterConfigVarNames = $masterConfigVars | Sort-Object
    
    # Check for missing variables in master_config.json.tpl
    $missingInMasterConfig = @()
    foreach ($varName in $variablesTfVarNames) {
        if ($varName -notin $masterConfigVarNames) {
            $missingInMasterConfig += $varName
        }
    }
    
    # Check for extra variables in master_config.json.tpl
    $extraInMasterConfig = @()
    foreach ($varName in $masterConfigVarNames) {
        if ($varName -notin $variablesTfVarNames) {
            $extraInMasterConfig += $varName
        }
    }
    
    $hasIssues = $false
    
    if ($missingInMasterConfig.Count -gt 0) {
        $hasIssues = $true
        Write-Host "    ❌ master_config.json.tpl의 $Category 섹션에서 누락된 변수 ($($missingInMasterConfig.Count)개):" -ForegroundColor Red
        $missingInMasterConfig | ForEach-Object { 
            $varValue = $variablesTfVars[$_]
            Write-Host "      - $_" -ForegroundColor White -NoNewline
            Write-Host " (variables.tf 값: $varValue)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    if ($extraInMasterConfig.Count -gt 0) {
        $hasIssues = $true
        Write-Host "    ❌ master_config.json.tpl의 $Category 섹션에 불필요한 변수 ($($extraInMasterConfig.Count)개):" -ForegroundColor Red
        $extraInMasterConfig | ForEach-Object { Write-Host "      - $_" -ForegroundColor White }
        Write-Host ""
    }
    
    if (-not $hasIssues) {
        Write-Host "    ✓ $Category 변수 일관성 검사 통과 ($($variablesTfVarNames.Count)개 변수)" -ForegroundColor Green
    } else {
        Write-Host "    📝 해결 방법: master_config.json.tpl 파일을 수정하여 variables.tf와 일치시키세요." -ForegroundColor Cyan
    }
    
    return -not $hasIssues
}

function Start-DeveloperMode {
    Write-Host "🔧 개발자 모드가 활성화되었습니다!" -ForegroundColor Magenta
    Write-Host "- 변수 무결성 검증이 포함됩니다" -ForegroundColor Gray
    Write-Host "- 상세한 디버그 정보를 제공합니다" -ForegroundColor Gray
    Write-Host "- 모든 Terraform 출력을 표시합니다" -ForegroundColor Gray
    Write-Host ""

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

    # Initialize terraform with full output
    Initialize-Terraform -ShowOutput $true

    # Load all variables for deployment and validation
    $variables = Get-AllVariablesForDeployment
    
    # Extract variables by category from the loaded results
    $userInputVars = @{}
    $cewebVars = @{}
    
    foreach ($key in $variables.Keys) {
        if ($key -match "^(private_domain_name|private_hosted_zone_id|public_domain_name|keypair_name|user_public_ip|object_storage_access_key_id|object_storage_secret_access_key|object_storage_bucket_string)$") {
            $userInputVars[$key] = $variables[$key]
        }
        elseif ($key -match "^(app_server_port|database_port|database_name|database_user|nginx_port|ssl_enabled|object_storage_bucket_name|object_storage_region|certificate_path|private_key_path|git_repository|git_branch|timezone|web_lb_service_ip|app_lb_service_ip|node_env|session_secret|db_type|db_max_connections|object_storage_private_endpoint|object_storage_public_endpoint|object_storage_media_folder|object_storage_audition_folder|auto_deployment|rollback_enabled|backup_retention_days|company_name|admin_email)$") {
            $cewebVars[$key] = $variables[$key]
        }
    }
    
    # Validate variables with detailed validation (CEWEB_REQUIRED first, then USER_INPUT)
    Write-Host "변수 검증 중..." -ForegroundColor Cyan
    $validationStartTime = Get-Date
    
    # Get master config variables for consistency checking
    $masterConfigUserInput = Get-MasterConfigVariables "USER_INPUT"
    $masterConfigCewebRequired = Get-MasterConfigVariables "CEWEB_REQUIRED"
    
    # Initialize counters and consistency flags
    $cewebSuccessfulVars = 0
    $cewebFailedVars = 0
    $cewebRequiredConsistent = $true
    $userSuccessfulVars = 0
    $userFailedVars = 0
    $userInputConsistent = $true
    
    # Validate CEWEB_REQUIRED variables first - using already loaded data
    Write-Host "  ceweb 필수 변수 (CEWEB_REQUIRED) 검증 중..." -ForegroundColor Gray
    
    if ($cewebVars.Count -eq 0) {
        Write-Host "    ❌ CEWEB_REQUIRED 변수가 로드되지 않았습니다!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "    variables.tf에서 $($cewebVars.Count)개 CEWEB_REQUIRED 변수를 발견했습니다." -ForegroundColor Gray
    
    # Process each CEWEB_REQUIRED variable
    foreach ($varName in $cewebVars.Keys) {
        $varValue = $cewebVars[$varName]
        
        # Check existence
        if ($varValue -and $varValue -ne "null") {
            $cewebSuccessfulVars++
        } else {
            $cewebFailedVars++
        }
        
        # Check consistency for this variable
        if ($varName -notin $masterConfigCewebRequired) {
            $cewebRequiredConsistent = $false
        }
    }
    
    Write-Host "    ✓ CEWEB_REQUIRED 변수 존재 여부 검증: $cewebSuccessfulVars 개 성공, $cewebFailedVars 개 실패" -ForegroundColor Green
    
    # Check for missing variables in master config
    $missingInMasterConfig = @()
    foreach ($varName in $cewebVars.Keys) {
        if ($varName -notin $masterConfigCewebRequired) {
            $missingInMasterConfig += $varName
        }
    }
    
    if ($missingInMasterConfig.Count -gt 0) {
        $cewebRequiredConsistent = $false
        Write-Host "    ❌ master_config.json.tpl의 CEWEB_REQUIRED 섹션에서 누락된 변수 ($($missingInMasterConfig.Count)개)" -ForegroundColor Red
    } else {
        Write-Host "    ✓ CEWEB_REQUIRED 변수 일관성 검사 통과 ($($cewebVars.Count)개 변수)" -ForegroundColor Green
    }
    
    # Validate USER_INPUT variables - using already loaded data
    Write-Host "  사용자 입력 변수 (USER_INPUT) 검증 중..." -ForegroundColor Gray
    
    if ($userInputVars.Count -eq 0) {
        Write-Host "    ❌ USER_INPUT 변수가 로드되지 않았습니다!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "    variables.tf에서 $($userInputVars.Count)개 USER_INPUT 변수를 발견했습니다." -ForegroundColor Gray
    
    # Process each USER_INPUT variable
    foreach ($varName in $userInputVars.Keys) {
        $varValue = $userInputVars[$varName]
        
        # Check existence
        if ($varValue -and $varValue -ne "null") {
            $userSuccessfulVars++
        } else {
            $userFailedVars++
        }
        
        # Check consistency for this variable
        if ($varName -notin $masterConfigUserInput) {
            $userInputConsistent = $false
        }
    }
    
    Write-Host "    ✓ USER_INPUT 변수 존재 여부 검증: $userSuccessfulVars 개 성공, $userFailedVars 개 실패" -ForegroundColor Green
    
    # Check for missing variables in master config
    $missingInMasterConfig = @()
    foreach ($varName in $userInputVars.Keys) {
        if ($varName -notin $masterConfigUserInput) {
            $missingInMasterConfig += $varName
        }
    }
    
    if ($missingInMasterConfig.Count -gt 0) {
        $userInputConsistent = $false
        Write-Host "    ❌ master_config.json.tpl의 USER_INPUT 섹션에서 누락된 변수 ($($missingInMasterConfig.Count)개)" -ForegroundColor Red
    } else {
        Write-Host "    ✓ USER_INPUT 변수 일관성 검사 통과 ($($userInputVars.Count)개 변수)" -ForegroundColor Green
    }
    
    # Final validation summary
    if (-not $userInputConsistent -or -not $cewebRequiredConsistent) {
        Write-Host "    ⚠️ 개발자 모드: 변수 불일치가 감지되었지만 배포는 계속 진행됩니다." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "    ✓ 모든 변수 일관성 검사 통과!" -ForegroundColor Green
    }
    
    $validationEndTime = Get-Date
    $validationDuration = [math]::Round(($validationEndTime - $validationStartTime).TotalSeconds, 1)
    Write-Host "✓ 변수 검증 완료! ($validationDuration 초 소요)" -ForegroundColor Green
    Write-Host ""

    # Display USER_INPUT variables for information only (no modification)
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "사용자 입력 변수 정보 (개발자 모드)" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Use JSON data for USER_INPUT variables (fast)
    $userVariables = @{}
    
    # Load JSON data to get descriptions and current values
    $jsonData = Get-Content "variables.json" -Raw | ConvertFrom-Json
    $userInputData = $jsonData.USER_INPUT
    
    foreach ($varName in $userInputVars.Keys) {
        $currentValue = $userInputVars[$varName]
        $description = if ($userInputData.$varName) { $userInputData.$varName.description } else { "" }
        
        $userVariables[$varName] = @{
            "current" = $currentValue
            "description" = $description
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

    Write-Host "사용자 입력 변수 리스트를 확인해주세요. 확인이 끝났으면 Enter를 누르세요." -ForegroundColor Magenta
    Read-Host
    Write-Host ""

    # Use already loaded variables for deployment
    $jsonContent = New-MasterConfigJson $variables
    Update-UserdataFiles $variables
    
    # Clear all caches after userdata files are updated (no more cache usage needed)
    Reset-VariablesCache -Categories @("ALL")
    if ($global:ValidationMode) {
        Write-Host "✓ userdata 파일 업데이트 완료 후 모든 캐시를 무효화했습니다." -ForegroundColor Cyan
    }

    # Run Terraform commands with full output
    Invoke-TerraformValidate -ShowOutput $true
    Invoke-TerraformPlan -ShowOutput $true
    Invoke-TerraformApply
}

#endregion

#region 일반 모드 파트 (General Mode)
# ==========================================================
# 일반 모드 - 빠른 배포에 최적화
# ==========================================================

function Start-GeneralMode {
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

    # Initialize terraform quietly
    Initialize-Terraform -ShowOutput $false

    # Simple validation - silent in general mode

    # User input variables section
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "사용자 입력 변수 확인/수정" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Load USER_INPUT variables from JSON (fast) - suppress debug output in general mode
    $originalValidationMode = $global:ValidationMode
    $global:ValidationMode = $false  # Temporarily disable to suppress loading messages
    $userInputVars = Get-VariablesFromJson -Category "USER_INPUT"
    $global:ValidationMode = $originalValidationMode  # Restore original mode
    $userVariables = @{}
    
    # Load JSON data to get descriptions
    $jsonData = Get-Content "variables.json" -Raw | ConvertFrom-Json
    $userInputData = $jsonData.USER_INPUT
    
    foreach ($varName in $userInputVars.Keys) {
        $currentValue = $userInputVars[$varName]
        $description = if ($userInputData.$varName) { $userInputData.$varName.description } else { "" }
        
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

    # Ask if user wants to modify variables (only in general mode)
    $shouldModify = $false
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
            
            # Special handling for user_public_ip - detect current public IP
            if ($varName -eq "user_public_ip") {
                try {
                    Write-Host "  현재 Public IP 조회 중..." -ForegroundColor Gray -NoNewline
                    $detectedIP = (Invoke-RestMethod 'https://api.ipify.org?format=json' -TimeoutSec 5).ip
                    Write-Host " ✓" -ForegroundColor Green
                    Write-Host "  조회된 Public IP: $detectedIP" -ForegroundColor Green
                    $newValue = Read-Host "  새 값 입력 (Enter=조회된 IP 사용, 다른 값 입력=사용자 지정)"
                    
                    if ([string]::IsNullOrWhiteSpace($newValue)) {
                        $userVariables[$varName].new_value = $detectedIP
                        Write-Host "  → 조회된 IP($detectedIP)가 적용됩니다." -ForegroundColor Green
                    } else {
                        $userVariables[$varName].new_value = $newValue.Trim()
                        Write-Host "  → 사용자 입력값($($newValue.Trim()))이 적용됩니다." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host " ❌" -ForegroundColor Red
                    Write-Host "  Public IP 조회 실패 (네트워크 오류): $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "  수동으로 입력하거나 Enter를 눌러 기존값을 유지하세요." -ForegroundColor Yellow
                    $newValue = Read-Host "  새 값 입력 (Enter=기존값 유지)"
                    
                    if ([string]::IsNullOrWhiteSpace($newValue)) {
                        $userVariables[$varName].new_value = $currentValue
                    } else {
                        $userVariables[$varName].new_value = $newValue.Trim()
                    }
                }
            } else {
                # Special handling for Object Storage variables
                if ($varName -like "*object_storage*") {
                    $newValue = Read-Host "  Object Storage를 사용하는 실습 배포일 경우 값을 정확히 입력하세요. 사용하지 않는다면 (Enter=기존값 유지)"
                } else {
                    # Default handling for other variables
                    $newValue = Read-Host "  새 값 입력 (Enter=기존값 유지)"
                }
                
                if ([string]::IsNullOrWhiteSpace($newValue)) {
                    $userVariables[$varName].new_value = $currentValue
                } else {
                    $userVariables[$varName].new_value = $newValue.Trim()
                }
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
            
            $confirmation = Read-Host "수정이 필요한 항목이 있으면, 번호를 누르세요. 모두 맞으면 네(y) [기본값: y]"
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

    # If variables were modified, invalidate only USER_INPUT cache to ensure fresh data
    if ($shouldModify) {
        Reset-VariablesCache -Categories @("USER_INPUT")
        if ($global:ValidationMode) {
            Write-Host "✓ USER_INPUT 변수 수정으로 인해 해당 캐시만 무효화했습니다. CEWEB_REQUIRED와 TERRAFORM_INFRA는 캐시를 재사용합니다." -ForegroundColor Cyan
        }
        Write-Host ""
    }

    # Load all variables and proceed with deployment
    $variables = Get-AllVariablesForDeployment
    $jsonContent = New-MasterConfigJson $variables
    Update-UserdataFiles $variables
    
    # Clear all caches after userdata files are updated (no more cache usage needed)
    Reset-VariablesCache -Categories @("ALL")
    if ($global:ValidationMode) {
        Write-Host "✓ userdata 파일 업데이트 완료 후 모든 캐시를 무효화했습니다." -ForegroundColor Cyan
    }

    # Run Terraform commands with minimal output
    Invoke-TerraformValidate -ShowOutput $false
    Invoke-TerraformPlan -ShowOutput $false
    Invoke-TerraformApply
}

#endregion

#region 메인 실행 부분 (Main Execution)
# ==========================================================
# 메인 프로그램 - 모드 선택 및 실행
# ==========================================================

try {
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Samsung Cloud Platform v2 Creative Energy" -ForegroundColor Green
    Write-Host "3-Tier High Availability 실습 환경 배포" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    
    # Initialize by parsing variables.tf to JSON for fast access
    if ($global:ValidationMode) {
        Write-Host "🚀 초기화: variables.tf → variables.json 파싱..." -ForegroundColor Magenta
        ConvertTo-VariablesJson
        Write-Host ""
    } else {
        ConvertTo-VariablesJson | Out-Null
    }

    # 사용자 모드 선택 - Enter 또는 admin만 허용
    do {
        $userInput = Read-Host "지금부터 Creative-Energy 실습 환경을 배포하시겠습니까?(Enter)"
        $trimmedInput = $userInput.Trim().ToLower()
    } while ($trimmedInput -ne "" -and $trimmedInput -ne "admin")

    # API 로깅 설정
    $logFile = Set-TerraformLogging

    Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host ""

    # 모드에 따른 실행
    if ($userInput.Trim().ToLower() -eq "admin") {
        $global:ValidationMode = $true
        Start-DeveloperMode
    } else {
        $global:ValidationMode = $false  
        Start-GeneralMode
    }

} catch {
    Write-Host ""
    Write-Host "❌ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    if (Get-Variable -Name "logFile" -ErrorAction SilentlyContinue) {
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
} finally {
    # Cleanup temporary files
    if (Test-Path "terraform.tfstate.backup") {
        Write-Host "Terraform state files present - deployment artifacts saved" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Gray

#endregion