#!/bin/bash

# Creative Energy Application Server Preparation Script
# Rocky Linux 9.4 Node.js App Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euxo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_app.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "App Server Preparation Started: $(date)"
echo "===================="

# Update system packages
echo "[1/7] System update..."
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet postgresql

# Clone application repository
echo "[2/7] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Apply master configuration to web-server directory only (central location)
echo "[3/7] Applying master configuration..."
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

# Wait for database to be ready (DB server dependency check)
echo "[4/7] Checking database server availability..."
DB_HOST="10.1.3.131"
DB_PORT="2866"
echo "Checking if database server ($DB_HOST:$DB_PORT) is ready..."
# This is just a network connectivity check, not actual DB installation verification
if nc -z $DB_HOST 22 2>/dev/null; then
    echo "✓ DB server host is reachable via SSH"
else
    echo "⚠ DB server host not yet reachable, but will proceed with preparation"
fi

# Prepare Node.js application installation directory
echo "[5/7] Preparing Node.js application environment..."
cd /home/rocky/ceweb/app-server
sudo chown -R rocky:rocky /home/rocky/ceweb/app-server
sudo chmod +x install_app_server.sh
echo "Node.js application installation script ready at: $(pwd)/install_app_server.sh"

# Check if installation script exists
echo "[6/7] Verifying installation script..."
if [ -f "install_app_server.sh" ]; then
    echo "✓ Node.js application installation script found"
    echo "✓ Ready to install Node.js 20.x and application"
    echo "Installation command: sudo bash install_app_server.sh"
else
    echo "❌ Node.js application installation script not found"
    exit 1
fi

# Create ready-to-install marker file
echo "[7/7] Creating installation readiness marker..."
echo "App Server preparation completed: $(date)" > /home/rocky/z_ready2install_go2app-server
echo "Next step: Run 'sudo bash install_app_server.sh' in /home/rocky/ceweb/app-server/" >> /home/rocky/z_ready2install_go2app-server
echo "Node.js 20.x and application will be installed" >> /home/rocky/z_ready2install_go2app-server
echo "Application will run on port 3000" >> /home/rocky/z_ready2install_go2app-server
echo "Database connection: db.${private_domain_name}:2866" >> /home/rocky/z_ready2install_go2app-server
echo "Health check endpoint: http://localhost:3000/health" >> /home/rocky/z_ready2install_go2app-server
chown rocky:rocky /home/rocky/z_ready2install_go2app-server

echo "===================="
echo "App Server Preparation Completed: $(date)"
echo "App Server IP: $(ip route get 1 | awk '{print $7}' | head -1)"
echo "Ready file: /home/rocky/z_ready2install_go2app-server"
echo "Installation directory: /home/rocky/ceweb/app-server/"
echo "Install command: sudo bash install_app_server.sh"
echo "Note: Ensure database is installed and running before app installation"
echo "===================="