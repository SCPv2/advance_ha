#!/bin/bash

# Creative Energy Web Server Preparation Script
# Rocky Linux 9.4 Nginx Web Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euxo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_web.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "Web Server Preparation Started: $(date)"
echo "===================="

# Update system packages
echo "[1/7] System update..."
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet

# Clone application repository
echo "[2/7] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Apply master configuration to web-server directory only
echo "[3/7] Applying master configuration..."
if [ -f /home/rocky/master_config.json ]; then
    sudo cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/master_config.json
    sudo chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    sudo rm -f /home/rocky/master_config.json
    echo "Master config applied to web-server directory (central location)"
    echo "Temporary config file cleaned up"
else
    echo "Warning: master_config.json not found, using default configuration"
fi

# Check application servers dependency
echo "[4/7] Checking application servers availability..."
APP_HOST1="10.1.2.121"
APP_PORT="3000"

echo "Checking if app server ($APP_HOST1) is ready..."
# This is just a network connectivity check, not actual app installation verification
if nc -z $APP_HOST1 22 2>/dev/null; then
    echo "✓ App server host is reachable via SSH"
else
    echo "⚠ App server host not yet reachable, but will proceed with preparation"
fi

# Prepare Nginx web server installation directory
echo "[5/7] Preparing Nginx web server environment..."
cd /home/rocky/ceweb/web-server
sudo chown -R rocky:rocky /home/rocky/ceweb/web-server
sudo chmod +x install_web_server.sh
echo "Nginx web server installation script ready at: $(pwd)/install_web_server.sh"

# Check if installation script exists
echo "[6/7] Verifying installation script..."
if [ -f "install_web_server.sh" ]; then
    echo "✓ Nginx web server installation script found"
    echo "✓ Ready to install Nginx and web application"
    echo "Installation command: sudo bash install_web_server.sh"
else
    echo "❌ Nginx web server installation script not found"
    exit 1
fi

# Create ready-to-install marker file
echo "[7/7] Creating installation readiness marker..."
echo "Web Server preparation completed: $(date)" > /home/rocky/z_ready2install_go2web-server
echo "Next step: Run 'sudo bash install_web_server.sh' in /home/rocky/ceweb/web-server/" >> /home/rocky/z_ready2install_go2web-server
echo "Nginx and web application will be installed" >> /home/rocky/z_ready2install_go2web-server
echo "Web server will run on port 80" >> /home/rocky/z_ready2install_go2web-server
echo "API proxy target: app.${private_domain_name}:3000" >> /home/rocky/z_ready2install_go2web-server
echo "Fallback target: 10.1.2.121:3000" >> /home/rocky/z_ready2install_go2web-server
echo "Health check: http://localhost/health" >> /home/rocky/z_ready2install_go2web-server
chown rocky:rocky /home/rocky/z_ready2install_go2web-server

echo "===================="
echo "Web Server Preparation Completed: $(date)"
echo "Web Server IP: $(ip route get 1 | awk '{print $7}' | head -1)"
echo "Ready file: /home/rocky/z_ready2install_go2web-server"
echo "Installation directory: /home/rocky/ceweb/web-server/"
echo "Install command: sudo bash install_web_server.sh"
echo "Note: Ensure app server is installed and running before web installation"
echo "===================="