# PowerShell 에러 처리 설정
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Terraform Deployment Started" -ForegroundColor Green
Write-Host "Project: Creative Energy File Storage" -ForegroundColor Green
Write-Host "Architecture: 3-Tier High Availability" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

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

    # Generate master_config.json from variables.tf using terraform console
    Write-Host "[0/4] Extracting variables from variables.tf using terraform console..." -ForegroundColor Cyan

    # First initialize terraform if needed
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
    }

    # Extract variables using terraform console with individual commands
    Write-Host "Reading variables from variables.tf..." -ForegroundColor Yellow
    
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

    # Get all variables individually
    $variables = @{
        public_domain_name = Get-TerraformVariable "public_domain_name"
        private_domain_name = Get-TerraformVariable "private_domain_name" 
        user_public_ip = Get-TerraformVariable "user_public_ip"
        keypair_name = Get-TerraformVariable "keypair_name"
        object_storage_bucket_string = Get-TerraformVariable "object_storage_bucket_string"
        object_storage_access_key_id = Get-TerraformVariable "object_storage_access_key_id"
        object_storage_secret_access_key = Get-TerraformVariable "object_storage_secret_access_key"
        public_hosted_zone_id = Get-TerraformVariable "public_hosted_zone_id"
        private_hosted_zone_id = Get-TerraformVariable "private_hosted_zone_id"
    }

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
                public_hosted_zone_id = $variables.public_hosted_zone_id
                private_hosted_zone_id = $variables.private_hosted_zone_id
            }
            network = @{
                vpc_cidr = "10.1.0.0/16"
                web_subnet_cidr = "10.1.1.0/24"
                app_subnet_cidr = "10.1.2.0/24"
                db_subnet_cidr = "10.1.3.0/24"
            }
            load_balancer = @{
                web_lb_service_ip = "10.1.1.100"
                app_lb_service_ip = "10.1.2.100"
            }
            servers = @{
                web_primary_ip = "10.1.1.111"
                web_secondary_ip = "10.1.1.112"
                app_primary_ip = "10.1.2.121"
                app_secondary_ip = "10.1.2.122"
                db_primary_ip = "10.1.3.131"
                bastion_ip = "10.1.1.110"
            }
        }
        application = @{
            web_server = @{
                nginx_port = 80
                ssl_enabled = $false
                upstream_target = "app.$($variables.private_domain_name):3000"
                fallback_target = "10.1.2.122:3000"
                health_check_path = "/health"
                api_proxy_path = "/api"
            }
            app_server = @{
                port = 3000
                node_env = "production"
                database_host = "db.$($variables.private_domain_name)"
                database_port = 2866
                database_name = "creative_energy_db"
                session_secret = "your-secret-key-change-in-production"
            }
            database = @{
                type = "postgresql"
                port = 2866
                max_connections = 100
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
                certificate_path = "/etc/ssl/certs/certificate.crt"
                private_key_path = "/etc/ssl/private/private.key"
            }
        }
        object_storage = @{
            access_key_id = $variables.object_storage_access_key_id
            secret_access_key = $variables.object_storage_secret_access_key
            region = "kr-west1"
            bucket_name = "ceweb"
            bucket_string = $variables.object_storage_bucket_string
            private_endpoint = "https://object-store.private.kr-west1.e.samsungsdscloud.com"
            public_endpoint = "https://object-store.kr-west1.e.samsungsdscloud.com"
            folders = @{
                media = "media/img"
                audition = "files/audition"
            }
        }
        deployment = @{
            git_repository = "https://github.com/SCPv2/ceweb.git"
            git_branch = "main"
            auto_deployment = $true
            rollback_enabled = $true
        }
        monitoring = @{
            log_level = "info"
            health_check_interval = 30
            metrics_enabled = $true
        }
        user_customization = @{
            "_comment" = "사용자 직접 수정 영역"
            company_name = "Creative Energy"
            admin_email = "admin@company.com"
            timezone = "Asia/Seoul"
            backup_retention_days = 30
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