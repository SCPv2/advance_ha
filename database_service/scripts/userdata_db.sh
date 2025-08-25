#!/bin/bash

# Creative Energy Database Server Auto-Installation Script
# Rocky Linux 9.4 PostgreSQL Database Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_db.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "DB Server Init Started: $(date)"
echo "===================="

# Wait for internet connection (HTTP-based check for security group compatibility)
echo "[0/6] Waiting for internet connection..."
MAX_WAIT=300  # 5 minutes maximum wait
WAIT_COUNT=0
until curl -s --connect-timeout 5 http://www.google.com > /dev/null 2>&1; do
    echo "Waiting for internet connection... ($((WAIT_COUNT * 10))s elapsed)"
    sleep 10
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -gt $((MAX_WAIT / 10)) ]; then
        echo "Internet connection timeout after $MAX_WAIT seconds"
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
    echo "Package installation attempt $attempt/5"
    if sudo dnf clean all && sudo dnf install -y epel-release; then
        echo "EPEL repository installed successfully"
        break
    else
        echo "EPEL installation attempt $attempt failed"
        if [ $attempt -eq 5 ]; then
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
UPDATE_RESULT=$?
set -e  # Re-enable exit on error

if [ $UPDATE_RESULT -ne 0 ]; then
    echo "System update had issues, but continuing with installation..."
fi

# Install additional packages with retry
for attempt in 1 2 3; do
    if sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet; then
        echo "Additional packages installed successfully"
        break
    else
        echo "Additional packages installation attempt $attempt failed"
        if [ $attempt -eq 3 ]; then
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
PUBLIC_DOMAIN_NAME=""
PRIVATE_DOMAIN_NAME=""
USER_PUBLIC_IP=""
KEYPAIR_NAME="mykey"
PRIVATE_HOSTED_ZONE_ID=""

VPC_CIDR="10.1.0.0/16"
WEB_SUBNET_CIDR="10.1.1.0/24"
APP_SUBNET_CIDR="10.1.2.0/24"
DB_SUBNET_CIDR="10.1.3.0/24"

BASTION_IP="10.1.1.110"
WEB_IP="10.1.1.111"
WEB_IP2="10.1.1.112"
APP_IP="10.1.2.121"
APP_IP2="10.1.2.122"
DB_IP="10.1.3.131"

WEB_LB_SERVICE_IP="10.1.1.100"
APP_LB_SERVICE_IP="10.1.2.100"

APP_SERVER_PORT="3000"
DATABASE_PORT="2866"
DATABASE_NAME="creative_energy_db"

# Create master_config.json with terraform variables
cat > /home/rocky/master_config.json << EOF
{
  "config_metadata": {
    "version": "1.0.0",
    "created": "$(date +%Y-%m-%d)",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "generated_from": "variables.tf via deploy_scp_lab_environment.ps1",
    "server_role": "database"
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "",
      "private_domain_name": "",
      "private_hosted_zone_id": "$PRIVATE_HOSTED_ZONE_ID"
    },
    "network": {
      "vpc_cidr": "$VPC_CIDR",
      "web_subnet_cidr": "$WEB_SUBNET_CIDR",
      "app_subnet_cidr": "$APP_SUBNET_CIDR",
      "db_subnet_cidr": "$DB_SUBNET_CIDR"
    },
    "load_balancer": {
      "web_lb_service_ip": "$WEB_LB_SERVICE_IP",
      "app_lb_service_ip": "$APP_LB_SERVICE_IP"
    },
    "servers": {
      "web_primary_ip": "$WEB_IP",
      "web_secondary_ip": "$WEB_IP2",
      "app_primary_ip": "$APP_IP",
      "app_secondary_ip": "$APP_IP2",
      "db_primary_ip": "$DB_IP",
      "bastion_ip": "$BASTION_IP"
    }
  },
  "application": {
    "web_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "upstream_target": "app.$PRIVATE_DOMAIN_NAME:$APP_SERVER_PORT",
      "fallback_target": "$APP_IP2:$APP_SERVER_PORT",
      "health_check_path": "/health",
      "api_proxy_path": "/api"
    },
    "app_server": {
      "port": $APP_SERVER_PORT,
      "node_env": "production",
      "database_host": "db.$PRIVATE_DOMAIN_NAME",
      "database_port": $DATABASE_PORT,
      "database_name": "$DATABASE_NAME",
      "session_secret": "your-secret-key-change-in-production"
    },
    "database": {
      "type": "postgresql",
      "port": $DATABASE_PORT,
      "max_connections": 100,
      "shared_buffers": "256MB",
      "effective_cache_size": "1GB"
    }
  },
  "security": {
    "firewall": {
      "allowed_public_ips": ["$USER_PUBLIC_IP/32"],
      "ssh_key_name": "$KEYPAIR_NAME"
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
echo "Database server ready: $(date)" > /home/rocky/DB_Server_Ready.log
chown rocky:rocky /home/rocky/DB_Server_Ready.log

echo "===================="
echo "DB Server Init Completed: $(date)"
echo "DB Connection: db.ceservice.net:2866"
echo "Database: cedb"
echo "Admin User: ceadmin"
echo "===================="