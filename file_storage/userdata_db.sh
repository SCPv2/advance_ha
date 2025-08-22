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

# Apply master configuration to web-server directory only (central location)
echo "[2.5/6] Applying master configuration..."
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
echo "DB Connection: db.cesvc.net:2866"
echo "Database: cedb"
echo "Admin User: ceadmin"
echo "===================="