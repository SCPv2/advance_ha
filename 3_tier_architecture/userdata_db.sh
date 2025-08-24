#!/bin/bash

# Creative Energy Database Server Preparation Script
# Rocky Linux 9.4 PostgreSQL DB Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euxo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_db.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "DB Server Preparation Started: $(date)"
echo "===================="

# Update system packages
echo "[1/6] System update..."
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet postgresql

# Clone application repository
echo "[2/6] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Apply master configuration to web-server directory only (central location)
echo "[3/6] Applying master configuration..."
if [ -f /home/rocky/master_config.json ]; then
    sudo cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/master_config.json
    sudo chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    sudo rm -f /home/rocky/master_config.json
    echo "Master config applied to web-server directory (central location)"
    echo "DB server will reference: /home/rocky/ceweb/web-server/master_config.json"
    echo "Temporary config file cleaned up"
else
    echo "Warning: master_config.json not found, using default configuration"
fi

# Prepare PostgreSQL installation directory
echo "[4/6] Preparing PostgreSQL installation environment..."
cd /home/rocky/ceweb/db-server/vm_db
sudo chown -R rocky:rocky /home/rocky/ceweb/db-server
sudo chmod +x install_postgresql_vm.sh
echo "PostgreSQL installation script ready at: $(pwd)/install_postgresql_vm.sh"

# Check if installation script exists
echo "[5/6] Verifying installation script..."
if [ -f "install_postgresql_vm.sh" ]; then
    echo "✓ PostgreSQL installation script found"
    echo "✓ Ready to install PostgreSQL 16.8"
    echo "Installation command: sudo bash install_postgresql_vm.sh"
else
    echo "❌ PostgreSQL installation script not found"
    exit 1
fi

# Create ready-to-install marker file
echo "[6/6] Creating installation readiness marker..."
echo "DB Server preparation completed: $(date)" > /home/rocky/z_ready2install_go2db-server
echo "Next step: Run 'sudo bash install_postgresql_vm.sh' in /home/rocky/ceweb/db-server/vm_db/" >> /home/rocky/z_ready2install_go2db-server
echo "PostgreSQL 16.8 will be installed and configured" >> /home/rocky/z_ready2install_go2db-server
echo "Database: cedb, User: ceadmin, Password: ceadmin123!" >> /home/rocky/z_ready2install_go2db-server
chown rocky:rocky /home/rocky/z_ready2install_go2db-server

echo "===================="
echo "DB Server Preparation Completed: $(date)"
echo "DB Server IP: $(ip route get 1 | awk '{print $7}' | head -1)"
echo "Ready file: /home/rocky/z_ready2install_go2db-server"
echo "Installation directory: /home/rocky/ceweb/db-server/vm_db/"
echo "Install command: sudo bash install_postgresql_vm.sh"
echo "===================="