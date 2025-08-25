# deploy_scp_lab_userdata_module.ps1
# Samsung Cloud Platform v2 - UserData Generation Module
# Handles master_config.json creation and all userdata script generation

#region Master Config JSON Generation
function New-MasterConfigJson {
    param($Variables)
    
    if ($global:ValidationMode) {
        Write-Host "🔄 Creating master_config.json..." -ForegroundColor Cyan
    }
    
    # Build the complete configuration structure
    $config = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        deployment_info = @{
            template_name = "Samsung Cloud Platform v2 Database Service"
            deployment_type = "3-Tier High Availability"
            terraform_version = if (Get-Command terraform -ErrorAction SilentlyContinue) { 
                (terraform version 2>$null | Select-Object -First 1) -replace "Terraform v", ""
            } else { "Unknown" }
        }
        
        # Company and project information
        company = @{
            name = if ($Variables.company_name) { $Variables.company_name } else { "Creative Energy" }
            domain = if ($Variables.private_domain_name) { $Variables.private_domain_name } else { "creativenergy.local" }
            public_domain = if ($Variables.public_domain_name) { $Variables.public_domain_name } else { "" }
        }
        
        # Infrastructure configuration
        infrastructure = @{
            vpc = @{
                name = if ($Variables.vpc_name) { $Variables.vpc_name } else { "VPC1" }
                cidr = if ($Variables.vpc_cidr) { $Variables.vpc_cidr } else { "10.1.0.0/16" }
            }
            subnets = @{
                web = @{
                    name = if ($Variables.web_subnet_name) { $Variables.web_subnet_name } else { "Subnet11" }
                    cidr = if ($Variables.web_subnet_cidr) { $Variables.web_subnet_cidr } else { "10.1.1.0/24" }
                }
                app = @{
                    name = if ($Variables.app_subnet_name) { $Variables.app_subnet_name } else { "Subnet12" }
                    cidr = if ($Variables.app_subnet_cidr) { $Variables.app_subnet_cidr } else { "10.1.2.0/24" }
                }
                db = @{
                    name = if ($Variables.db_subnet_name) { $Variables.db_subnet_name } else { "Subnet13" }
                    cidr = if ($Variables.db_subnet_cidr) { $Variables.db_subnet_cidr } else { "10.1.3.0/24" }
                }
            }
            servers = @{
                bastion = @{
                    name = if ($Variables.bastion_name) { $Variables.bastion_name } else { "bastion-server" }
                    ip = if ($Variables.bastion_ip) { $Variables.bastion_ip } else { "10.1.1.110" }
                    os = "Windows Server 2022"
                    type = if ($Variables.vm_server_type) { $Variables.vm_server_type } else { "s1v1m2" }
                }
                web = @{
                    name = if ($Variables.web_name) { $Variables.web_name } else { "web-server" }
                    ip = if ($Variables.web_ip) { $Variables.web_ip } else { "10.1.1.111" }
                    os = "Rocky Linux 9.4"
                    type = if ($Variables.vm_server_type) { $Variables.vm_server_type } else { "s1v1m2" }
                }
                app = @{
                    name = if ($Variables.app_name) { $Variables.app_name } else { "app-server" }
                    ip = if ($Variables.app_ip) { $Variables.app_ip } else { "10.1.2.121" }
                    os = "Rocky Linux 9.4"  
                    type = if ($Variables.vm_server_type) { $Variables.vm_server_type } else { "s1v1m2" }
                }
                db = @{
                    name = if ($Variables.db_name) { $Variables.db_name } else { "db-server" }
                    ip = if ($Variables.db_ip) { $Variables.db_ip } else { "10.1.3.131" }
                    os = "Rocky Linux 9.4"
                    type = if ($Variables.vm_server_type) { $Variables.vm_server_type } else { "s1v1m2" }
                }
            }
        }
        
        # Application configuration
        application = @{
            web_server = @{
                port = if ($Variables.web_port) { $Variables.web_port } else { "80" }
                ssl_port = if ($Variables.ssl_port) { $Variables.ssl_port } else { "443" }
                ssl_enabled = if ($Variables.ssl_enabled) { $Variables.ssl_enabled } else { $false }
                document_root = "/var/www/html"
            }
            app_server = @{
                port = if ($Variables.app_port) { $Variables.app_port } else { "3000" }
                environment = if ($Variables.node_env) { $Variables.node_env } else { "production" }
                session_secret = if ($Variables.session_secret) { $Variables.session_secret } else { "your-session-secret-here" }
            }
            database = @{
                type = if ($Variables.db_type) { $Variables.db_type } else { "postgresql" }
                port = if ($Variables.db_port) { $Variables.db_port } else { "2866" }
                name = if ($Variables.db_name_app) { $Variables.db_name_app } else { "creativenergy_db" }
                user = if ($Variables.db_user) { $Variables.db_user } else { "ceweb" }
                password = if ($Variables.db_password) { $Variables.db_password } else { "your-db-password-here" }
                max_connections = if ($Variables.db_max_connections) { $Variables.db_max_connections } else { "100" }
            }
        }
        
        # DNS configuration
        dns = @{
            private_domain = if ($Variables.private_domain_name) { $Variables.private_domain_name } else { "creativenergy.local" }
            public_domain = if ($Variables.public_domain_name) { $Variables.public_domain_name } else { "" }
            hosted_zone_id = if ($Variables.private_hosted_zone_id) { $Variables.private_hosted_zone_id } else { "" }
            records = @{
                www = if ($Variables.web_ip) { $Variables.web_ip } else { "10.1.1.111" }
                app = if ($Variables.app_ip) { $Variables.app_ip } else { "10.1.2.121" }
                db = if ($Variables.db_ip) { $Variables.db_ip } else { "10.1.3.131" }
            }
        }
        
        # Git configuration
        git = @{
            repository_url = if ($Variables.git_repository_url) { $Variables.git_repository_url } else { "https://github.com/your-repo/ceweb.git" }
            branch = if ($Variables.git_branch) { $Variables.git_branch } else { "main" }
            username = if ($Variables.git_username) { $Variables.git_username } else { "" }
            token = if ($Variables.git_token) { $Variables.git_token } else { "" }
        }
        
        # Object Storage configuration (optional)
        object_storage = @{
            access_key_id = if ($Variables.object_storage_access_key_id) { $Variables.object_storage_access_key_id } else { "" }
            secret_access_key = if ($Variables.object_storage_secret_access_key) { $Variables.object_storage_secret_access_key } else { "" }
            bucket_string = if ($Variables.object_storage_bucket_string) { $Variables.object_storage_bucket_string } else { "" }
            private_endpoint = if ($Variables.object_storage_private_endpoint) { $Variables.object_storage_private_endpoint } else { "" }
            public_endpoint = if ($Variables.object_storage_public_endpoint) { $Variables.object_storage_public_endpoint } else { "" }
            media_folder = if ($Variables.object_storage_media_folder) { $Variables.object_storage_media_folder } else { "media" }
            audition_folder = if ($Variables.object_storage_audition_folder) { $Variables.object_storage_audition_folder } else { "auditions" }
            "_comment" = "Object Storage is optional for basic 3-tier architecture"
        }
        
        # Deployment configuration
        deployment = @{
            auto_deployment = if ($Variables.auto_deployment) { $Variables.auto_deployment } else { $false }
            rollback_enabled = if ($Variables.rollback_enabled) { $Variables.rollback_enabled } else { $true }
            backup_retention_days = if ($Variables.backup_retention_days) { $Variables.backup_retention_days } else { "7" }
        }
        
        # Security configuration
        security = @{
            keypair_name = if ($Variables.keypair_name) { $Variables.keypair_name } else { "mykey" }
            user_public_ip = if ($Variables.user_public_ip) { $Variables.user_public_ip } else { "0.0.0.0/0" }
        }
    }
    
    # Convert to JSON and save to scripts directory
    $jsonContent = $config | ConvertTo-Json -Depth 10
    $jsonContent | Out-File "scripts/master_config.json" -Encoding UTF8
    
    if ($global:ValidationMode) {
        Write-Host "✓ master_config.json created successfully!" -ForegroundColor Green
        Write-Host "  Size: $([Math]::Round((Get-Item "scripts/master_config.json").Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host ""
    }
    
    return $jsonContent
}
#endregion

#region Database UserData Script Generation
function Generate-UserdataDbScript {
    param($Variables, $MasterConfigJsonContent)
    
    if ($global:ValidationMode) {
        Write-Host "🔄 Generating database userdata script..." -ForegroundColor Cyan
    }
    
    $dbScript = @"
#!/bin/bash
# Database Server UserData Script
# Samsung Cloud Platform v2 - Database Service
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

set -e
exec > >(tee /var/log/userdata.log) 2>&1

echo "Starting database server initialization..."
echo "Timestamp: `$(date)"

# Create master_config.json on the server
cat > /home/rocky/master_config.json << 'MASTER_CONFIG_EOF'
$MasterConfigJsonContent
MASTER_CONFIG_EOF

# Set proper permissions
chown rocky:rocky /home/rocky/master_config.json
chmod 644 /home/rocky/master_config.json

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y git curl wget unzip jq

# Install PostgreSQL
echo "Installing PostgreSQL..."
dnf install -y postgresql postgresql-server postgresql-contrib

# Initialize PostgreSQL
echo "Initializing PostgreSQL..."
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $(if ($Variables.db_name_app) { $Variables.db_name_app } else { 'creativenergy_db' });"
sudo -u postgres psql -c "CREATE USER $(if ($Variables.db_user) { $Variables.db_user } else { 'ceweb' }) WITH PASSWORD '$(if ($Variables.db_password) { $Variables.db_password } else { 'your-db-password-here' })';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $(if ($Variables.db_name_app) { $Variables.db_name_app } else { 'creativenergy_db' }) TO $(if ($Variables.db_user) { $Variables.db_user } else { 'ceweb' });"

# Configure PostgreSQL to listen on custom port
echo "Configuring PostgreSQL port..."
sed -i "s/#port = 5432/port = $(if ($Variables.db_port) { $Variables.db_port } else { '2866' })/g" /var/lib/pgsql/data/postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Configure authentication
echo "Configuring PostgreSQL authentication..."
cat >> /var/lib/pgsql/data/pg_hba.conf << EOF
# Allow connections from app subnet
host    all             all             $(if ($Variables.app_subnet_cidr) { $Variables.app_subnet_cidr } else { '10.1.2.0/24' })               md5
EOF

# Restart PostgreSQL
systemctl restart postgresql

# Configure firewall
echo "Configuring firewall..."
firewall-cmd --permanent --add-port=$(if ($Variables.db_port) { $Variables.db_port } else { '2866' })/tcp
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Test network connectivity
echo "Testing network connectivity..."
ping -c 2 $(if ($Variables.bastion_ip) { $Variables.bastion_ip } else { '10.1.1.110' }) && echo "✓ Bastion connectivity OK" || echo "❌ Bastion connectivity failed"
ping -c 2 $(if ($Variables.app_ip) { $Variables.app_ip } else { '10.1.2.121' }) && echo "✓ App server connectivity OK" || echo "❌ App server connectivity failed"

# Create ready marker
echo "Creating ready marker..."
touch /home/rocky/z_ready2install_go2db-server
chown rocky:rocky /home/rocky/z_ready2install_go2db-server

echo "Database server initialization completed!"
echo "Next steps:"
echo "1. SSH to this server via bastion"
echo "2. Run: sudo bash install_postgresql_vm.sh"
echo "3. Verify database connectivity from app server"

# Log completion
echo "DB Server UserData completed at: `$(date)" >> /var/log/userdata_completion.log
"@

    return $dbScript
}
#endregion

#region Application UserData Script Generation  
function Generate-UserdataAppScript {
    param($Variables, $MasterConfigJsonContent)
    
    if ($global:ValidationMode) {
        Write-Host "🔄 Generating application userdata script..." -ForegroundColor Cyan
    }
    
    $appScript = @"
#!/bin/bash
# Application Server UserData Script
# Samsung Cloud Platform v2 - Database Service
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

set -e
exec > >(tee /var/log/userdata.log) 2>&1

echo "Starting application server initialization..."
echo "Timestamp: `$(date)"

# Create master_config.json on the server
cat > /home/rocky/master_config.json << 'MASTER_CONFIG_EOF'
$MasterConfigJsonContent
MASTER_CONFIG_EOF

# Set proper permissions
chown rocky:rocky /home/rocky/master_config.json
chmod 644 /home/rocky/master_config.json

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y git curl wget unzip jq

# Install Node.js (Latest LTS)
echo "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
dnf install -y nodejs

# Verify installations
echo "Verifying installations..."
node --version
npm --version

# Install PM2 globally
echo "Installing PM2..."
npm install -g pm2

# Configure firewall
echo "Configuring firewall..."
firewall-cmd --permanent --add-port=$(if ($Variables.app_port) { $Variables.app_port } else { '3000' })/tcp
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Test network connectivity
echo "Testing network connectivity..."
ping -c 2 $(if ($Variables.bastion_ip) { $Variables.bastion_ip } else { '10.1.1.110' }) && echo "✓ Bastion connectivity OK" || echo "❌ Bastion connectivity failed"
ping -c 2 $(if ($Variables.web_ip) { $Variables.web_ip } else { '10.1.1.111' }) && echo "✓ Web server connectivity OK" || echo "❌ Web server connectivity failed"
ping -c 2 $(if ($Variables.db_ip) { $Variables.db_ip } else { '10.1.3.131' }) && echo "✓ DB server connectivity OK" || echo "❌ DB server connectivity failed"

# Test database connection
echo "Testing database connection..."
dnf install -y postgresql
export PGPASSWORD='$(if ($Variables.db_password) { $Variables.db_password } else { 'your-db-password-here' })'
psql -h $(if ($Variables.db_ip) { $Variables.db_ip } else { '10.1.3.131' }) -p $(if ($Variables.db_port) { $Variables.db_port } else { '2866' }) -U $(if ($Variables.db_user) { $Variables.db_user } else { 'ceweb' }) -d $(if ($Variables.db_name_app) { $Variables.db_name_app } else { 'creativenergy_db' }) -c "SELECT version();" && echo "✓ Database connection successful" || echo "❌ Database connection failed"

# Prepare application directory
echo "Preparing application directory..."
mkdir -p /opt/ceweb
chown rocky:rocky /opt/ceweb

# Create environment file template
cat > /home/rocky/.env.template << EOF
# Application Configuration
NODE_ENV=$(if ($Variables.node_env) { $Variables.node_env } else { 'production' })
PORT=$(if ($Variables.app_port) { $Variables.app_port } else { '3000' })
SESSION_SECRET=$(if ($Variables.session_secret) { $Variables.session_secret } else { 'your-session-secret-here' })

# Database Configuration
DB_HOST=$(if ($Variables.db_ip) { $Variables.db_ip } else { '10.1.3.131' })
DB_PORT=$(if ($Variables.db_port) { $Variables.db_port } else { '2866' })
DB_NAME=$(if ($Variables.db_name_app) { $Variables.db_name_app } else { 'creativenergy_db' })
DB_USER=$(if ($Variables.db_user) { $Variables.db_user } else { 'ceweb' })
DB_PASSWORD=$(if ($Variables.db_password) { $Variables.db_password } else { 'your-db-password-here' })

# Web Server Configuration
WEB_SERVER_URL=http://$(if ($Variables.web_ip) { $Variables.web_ip } else { '10.1.1.111' })

# Object Storage (Optional)
OBJECT_STORAGE_ACCESS_KEY_ID=$(if ($Variables.object_storage_access_key_id) { $Variables.object_storage_access_key_id } else { '' })
OBJECT_STORAGE_SECRET_ACCESS_KEY=$(if ($Variables.object_storage_secret_access_key) { $Variables.object_storage_secret_access_key } else { '' })
OBJECT_STORAGE_BUCKET=$(if ($Variables.object_storage_bucket_string) { $Variables.object_storage_bucket_string } else { '' })
EOF

chown rocky:rocky /home/rocky/.env.template

# Create ready marker
echo "Creating ready marker..."
touch /home/rocky/z_ready2install_go2app-server
chown rocky:rocky /home/rocky/z_ready2install_go2app-server

echo "Application server initialization completed!"
echo "Next steps:"
echo "1. SSH to this server via bastion"
echo "2. Run: sudo bash install_app_server.sh"
echo "3. Verify application is running on port $(if ($Variables.app_port) { $Variables.app_port } else { '3000' })"

# Log completion
echo "App Server UserData completed at: `$(date)" >> /var/log/userdata_completion.log
"@

    return $appScript
}
#endregion

#region Web UserData Script Generation
function Generate-UserdataWebScript {
    param($Variables, $MasterConfigJsonContent)
    
    if ($global:ValidationMode) {
        Write-Host "🔄 Generating web userdata script..." -ForegroundColor Cyan
    }
    
    $webScript = @"
#!/bin/bash
# Web Server UserData Script  
# Samsung Cloud Platform v2 - Database Service
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

set -e
exec > >(tee /var/log/userdata.log) 2>&1

echo "Starting web server initialization..."
echo "Timestamp: `$(date)"

# Create master_config.json on the server
cat > /home/rocky/master_config.json << 'MASTER_CONFIG_EOF'
$MasterConfigJsonContent
MASTER_CONFIG_EOF

# Set proper permissions
chown rocky:rocky /home/rocky/master_config.json
chmod 644 /home/rocky/master_config.json

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y git curl wget unzip jq nginx

# Configure Nginx
echo "Configuring Nginx..."
systemctl enable nginx

# Create Nginx configuration
cat > /etc/nginx/conf.d/ceweb.conf << EOF
upstream app_backend {
    server $(if ($Variables.app_ip) { $Variables.app_ip } else { '10.1.2.121' }):$(if ($Variables.app_port) { $Variables.app_port } else { '3000' });
}

server {
    listen $(if ($Variables.web_port) { $Variables.web_port } else { '80' });
    server_name $(if ($Variables.private_domain_name) { $Variables.private_domain_name } else { 'creativenergy.local' }) www.$(if ($Variables.private_domain_name) { $Variables.private_domain_name } else { 'creativenergy.local' });
    
    # Static file serving
    location /static/ {
        root /var/www/html;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        root /var/www/html;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Proxy to application server
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        
        # Health check bypass
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create web directory
echo "Creating web directories..."
mkdir -p /var/www/html/static
mkdir -p /var/www/html/media
chown -R nginx:nginx /var/www/html

# Configure firewall
echo "Configuring firewall..."
firewall-cmd --permanent --add-port=$(if ($Variables.web_port) { $Variables.web_port } else { '80' })/tcp
if [ "$(if ($Variables.ssl_enabled) { $Variables.ssl_enabled } else { 'false' })" = "true" ]; then
    firewall-cmd --permanent --add-port=$(if ($Variables.ssl_port) { $Variables.ssl_port } else { '443' })/tcp
fi
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Test network connectivity
echo "Testing network connectivity..."
ping -c 2 $(if ($Variables.bastion_ip) { $Variables.bastion_ip } else { '10.1.1.110' }) && echo "✓ Bastion connectivity OK" || echo "❌ Bastion connectivity failed"
ping -c 2 $(if ($Variables.app_ip) { $Variables.app_ip } else { '10.1.2.121' }) && echo "✓ App server connectivity OK" || echo "❌ App server connectivity failed"

# Test application backend connection
echo "Testing application backend..."
curl -f -m 10 http://$(if ($Variables.app_ip) { $Variables.app_ip } else { '10.1.2.121' }):$(if ($Variables.app_port) { $Variables.app_port } else { '3000' })/health && echo "✓ App backend reachable" || echo "❌ App backend not ready (normal during initial setup)"

# Create ready marker
echo "Creating ready marker..."
touch /home/rocky/z_ready2install_go2web-server
chown rocky:rocky /home/rocky/z_ready2install_go2web-server

echo "Web server initialization completed!"
echo "Next steps:"
echo "1. SSH to this server via bastion"
echo "2. Run: sudo bash install_web_server.sh" 
echo "3. Verify web server is accessible on port $(if ($Variables.web_port) { $Variables.web_port } else { '80' })"

# Log completion  
echo "Web Server UserData completed at: `$(date)" >> /var/log/userdata_completion.log
"@

    return $webScript
}
#endregion

#region UserData Files Update
function Update-UserdataFiles {
    param($Variables)
    
    if ($global:ValidationMode) {
        Write-Host "🔄 Updating all userdata files with variable values..." -ForegroundColor Cyan
    }
    
    # Generate master_config.json content
    $jsonContent = New-MasterConfigJson $Variables
    
    # Generate and save userdata scripts
    $dbScript = Generate-UserdataDbScript $Variables $jsonContent
    $appScript = Generate-UserdataAppScript $Variables $jsonContent  
    $webScript = Generate-UserdataWebScript $Variables $jsonContent
    
    # Write userdata files to scripts directory
    $dbScript | Out-File "scripts/userdata_db.sh" -Encoding UTF8
    $appScript | Out-File "scripts/userdata_app.sh" -Encoding UTF8
    $webScript | Out-File "scripts/userdata_web.sh" -Encoding UTF8
    
    if ($global:ValidationMode) {
        Write-Host "✓ userdata_db.sh updated" -ForegroundColor Green
        Write-Host "✓ userdata_app.sh updated" -ForegroundColor Green
        Write-Host "✓ userdata_web.sh updated" -ForegroundColor Green
        Write-Host ""
    }
    
    return $true
}
#endregion