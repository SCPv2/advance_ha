#!/bin/bash

# Creative Energy Application Server Auto-Installation Script
# Rocky Linux 9.4 Node.js App Server Setup
# Terraform UserData Script for Samsung Cloud Platform

set -euxo pipefail

# Create log file for troubleshooting
LOGFILE="/var/log/userdata_app.log"
exec 1> >(tee -a $LOGFILE)
exec 2> >(tee -a $LOGFILE >&2)

echo "===================="
echo "App Server Init Started: $(date)"
echo "===================="

# Update system packages
echo "[1/8] System update..."
sudo dnf install -y epel-release
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils netcat telnet postgresql

# Clone application repository
echo "[2/8] Cloning application repository..."
cd /home/rocky
sudo -u rocky git clone https://github.com/SCPv2/ceweb.git

# Apply master configuration to web-server directory only (central location)
echo "[2.5/8] Applying master configuration..."
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

# Wait for database to be ready (DB server dependency)
echo "[3/8] Waiting for database server..."
DB_HOST="10.1.3.131"
DB_PORT="2866"
until nc -z $DB_HOST $DB_PORT 2>/dev/null; do
    echo "Waiting for database server ($DB_HOST:$DB_PORT)..."
    sleep 10
done
echo "Database server is ready!"

# Install Node.js and application
echo "[4/8] Installing Node.js and application..."
cd /home/rocky/ceweb/app-server
sudo bash install_app_server.sh

# Verify Node.js application
echo "[5/8] Verifying Node.js application..."
sleep 5
until curl -f http://localhost:3000/health 2>/dev/null; do
    echo "Waiting for application to start..."
    sleep 5
done

# Test database connectivity
echo "[6/8] Testing database connectivity..."
sudo -u rocky node -e "
const { Client } = require('pg');
const client = new Client({
    host: '$DB_HOST',
    port: $DB_PORT,
    database: 'cedb',
    user: 'ceadmin',
    password: 'ceadmin123!'
});
client.connect().then(() => {
    console.log('Database connection successful');
    client.end();
}).catch(err => {
    console.error('Database connection failed:', err.message);
});
"

# Verify API endpoints
echo "[7/8] Testing API endpoints..."
curl -f http://localhost:3000/api/orders/products || echo "Products API not yet available"
curl -f http://localhost:3000/health || echo "Health check not yet available"

# Create completion marker
echo "[8/8] Application setup completed successfully!"
echo "Application server ready: $(date)" > /home/rocky/App_Server_Ready.log
chown rocky:rocky /home/rocky/App_Server_Ready.log

echo "===================="
echo "App Server Init Completed: $(date)"
echo "App Service: 10.1.2.121:3000 (or 10.1.2.122:3000)"
echo "Health Check: /health"
echo "API Endpoints: /api/orders/products"
echo "===================="
