#!/bin/bash

# Creative Energy Web Server Auto-Installation Script
# Rocky Linux 9.4 Nginx Web Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_web.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "Web Server Init Started: $(date)"
echo "===================="

# Wait for internet connection (HTTP-based check)
echo "[0/8] Waiting for internet connection..."
MAX_WAIT=300
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
set +e
sudo dnf -y update
UPDATE_RESULT=$?
sudo dnf -y upgrade
UPGRADE_RESULT=$?
set -e

if [ $UPDATE_RESULT -ne 0 ] || [ $UPGRADE_RESULT -ne 0 ]; then
    echo "System update/upgrade had issues, but continuing..."
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
echo "[2/8] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Create master configuration from terraform variables  
echo "[2.5/8] Creating master configuration from terraform variables..."

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
    "server_role": "web"
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
APP_HOST1="app.ceservice.net"
APP_HOST2="10.1.2.122"
APP_PORT="3000"

# Wait for at least one app server
until nc -z $APP_HOST1 $APP_PORT 2>/dev/null || nc -z $APP_HOST2 $APP_PORT 2>/dev/null; do
    echo "Waiting for application servers ($APP_HOST1:$APP_PORT or $APP_HOST2:$APP_PORT)..."
    sleep 10
done
echo "Application servers are ready!"

# Install Nginx and web application
echo "[4/8] Installing Nginx and web application..."
cd /home/rocky/ceweb/web-server
sudo bash install_web_server.sh

# Test app server connectivity through Load Balancer
echo "[5/8] Testing application server connectivity..."
LB_APP_IP="app.ceservice.net"
if nc -z $LB_APP_IP $APP_PORT 2>/dev/null; then
    echo "App Load Balancer is working"
else
    echo "App Load Balancer not accessible, using direct connection"
    # Modify nginx config to use direct app server connection (bypass LB failure)
    sudo sed -i "s|proxy_pass http://app.ceservice.net:3000;|proxy_pass http://$APP_HOST2:3000;|g" /etc/nginx/conf.d/creative-energy.conf
    sudo sed -i "s|proxy_pass http://app.ceservice.net:3000/health;|proxy_pass http://$APP_HOST2:3000/health;|g" /etc/nginx/conf.d/creative-energy.conf
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
echo "Web server ready: $(date)" > /home/rocky/Web_Server_Ready.log
chown rocky:rocky /home/rocky/Web_Server_Ready.log

echo "===================="
echo "Web Server Init Completed: $(date)"
echo "Web Service: 10.1.1.111:80 (or 10.1.1.112:80)"
echo "Load Balancer: 10.1.1.100:80"
echo "Proxy to App: $APP_HOST2:3000 (direct connection)"
echo "===================="