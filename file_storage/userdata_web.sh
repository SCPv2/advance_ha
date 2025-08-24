#!/bin/bash

# Creative Energy Web Server Auto-Installation Script
# Rocky Linux 9.4 Nginx Web Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euxo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_web.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "Web Server Init Started: $(date)"
echo "===================="

# Update system packages
echo "[1/8] System update..."
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet

# Clone application repository
echo "[2/8] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

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
APP_HOST1="10.1.2.121"
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
LB_APP_IP="10.1.2.100"
if nc -z $LB_APP_IP $APP_PORT 2>/dev/null; then
    echo "App Load Balancer is working"
else
    echo "App Load Balancer not accessible, using direct connection"
    # Modify nginx config to use direct app server connection (bypass LB failure)
    sudo sed -i "s|proxy_pass http://app.${private_domain_name}:3000;|proxy_pass http://$APP_HOST2:3000;|g" /etc/nginx/conf.d/creative-energy.conf
    sudo sed -i "s|proxy_pass http://app.${private_domain_name}:3000/health;|proxy_pass http://$APP_HOST2:3000/health;|g" /etc/nginx/conf.d/creative-energy.conf
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
