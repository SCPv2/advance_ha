#!/bin/bash

# Creative Energy Database Server Auto-Installation Script
# Rocky Linux 9.4 PostgreSQL Database Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euxo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_db.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "DB Server Init Started: $(date)"
echo "===================="

# Update system packages
echo "[1/6] System update..."
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet

# Clone application repository
echo "[2/6] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Create master configuration from terraform variables
echo "[2.5/6] Creating master configuration from terraform variables..."

# Variables injected by PowerShell deploy script
PUBLIC_DOMAIN_NAME="${public_domain_name}"
PRIVATE_DOMAIN_NAME="${private_domain_name}"
USER_PUBLIC_IP="${user_public_ip}"
KEYPAIR_NAME="${keypair_name}"
PRIVATE_HOSTED_ZONE_ID="${private_hosted_zone_id}"

VPC_CIDR="${vpc_cidr}"
WEB_SUBNET_CIDR="${web_subnet_cidr}"
APP_SUBNET_CIDR="${app_subnet_cidr}"
DB_SUBNET_CIDR="${db_subnet_cidr}"

BASTION_IP="${bastion_ip}"
WEB_IP="${web_ip}"
WEB_IP2="${web_ip2}"
APP_IP="${app_ip}"
APP_IP2="${app_ip2}"
DB_IP="${db_ip}"

WEB_LB_SERVICE_IP="${web_lb_service_ip}"
APP_LB_SERVICE_IP="${app_lb_service_ip}"

APP_SERVER_PORT="${app_server_port}"
DATABASE_PORT="${database_port}"
DATABASE_NAME="${database_name}"

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
      "public_domain_name": "$PUBLIC_DOMAIN_NAME",
      "private_domain_name": "$PRIVATE_DOMAIN_NAME",
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
echo "DB Connection: db.${private_domain_name}:2866"
echo "Database: cedb"
echo "Admin User: ceadmin"
echo "===================="