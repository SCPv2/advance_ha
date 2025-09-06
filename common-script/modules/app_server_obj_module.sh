# App Server Application Install Module (Object Storage Enhanced)
app_install() {
    echo "[4/5] App server install (Object Storage + DBaaS)..."
    
    # Install Node.js 20.x
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs postgresql nmap-ncat wget curl git vim nano htop net-tools telnet
    npm install -g pm2
    
    # Load master config first (needed for DBaaS setup)
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "cesvc.net"' $MASTER_CONFIG)
    PUBLIC_DOMAIN=$(jq -r '.user_input_variables.public_domain_name // "creative-energy.net"' $MASTER_CONFIG)
    DB_HOST=$(jq -r '.ceweb_required_variables.database_host // "db.'$PRIVATE_DOMAIN'"' $MASTER_CONFIG)
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "cedbadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
    # Load additional configuration for infrastructure IPs
    WEB_LB_SERVICE_IP=$(jq -r '.ceweb_required_variables.web_lb_service_ip // "10.1.1.100"' $MASTER_CONFIG)
    APP_LB_SERVICE_IP=$(jq -r '.ceweb_required_variables.app_lb_service_ip // "10.1.2.100"' $MASTER_CONFIG)
    WEB_PRIMARY_IP=$(jq -r '.ceweb_required_variables.web_ip // "10.1.1.111"' $MASTER_CONFIG)
    WEB_SECONDARY_IP="10.1.1.112"
    APP_PRIMARY_IP=$(jq -r '.ceweb_required_variables.app_ip // "10.1.2.121"' $MASTER_CONFIG)
    APP_SECONDARY_IP="10.1.2.122"
    DB_PRIMARY_IP=$(jq -r '.ceweb_required_variables.db_ip // "10.1.3.131"' $MASTER_CONFIG)
    BASTION_IP="10.1.1.110"
    
    # Set server hostnames based on domains
    APP_SERVER_HOST="app.${PRIVATE_DOMAIN}"
    DB_SERVER_HOST="db.${PRIVATE_DOMAIN}"
    
    # CORS allowed domains setup
    ALLOWED_ORIGINS="http://www.${PRIVATE_DOMAIN},https://www.${PRIVATE_DOMAIN},http://www.${PUBLIC_DOMAIN},https://www.${PUBLIC_DOMAIN}"
    
    # Wait for database with timeout
    echo "Waiting for database $DB_HOST:$DB_PORT..."
    for i in {1..30}; do
        if nc -z $DB_HOST $DB_PORT 2>/dev/null; then
            echo "✅ Database connection available"
            break
        elif [ $i -eq 30 ]; then
            echo "⚠️  Database timeout after 5 minutes, proceeding anyway..."
            break
        else
            echo "Attempt $i/30: Database not ready, waiting 10s..."
            sleep 10
        fi
    done
    
    # DBaaS Database Setup (execute after connection is confirmed)
    echo "Setting up DBaaS database schema..."
    DBAAS_SCRIPT="/home/rocky/ceweb/db-server/dbaas_db/setup_postgresql_dbaas.sh"
    if [ -f "$DBAAS_SCRIPT" ]; then
        cd /home/rocky/ceweb/db-server/dbaas_db
        # Auto-confirm for non-interactive execution
        echo "y" | sudo -u rocky bash setup_postgresql_dbaas.sh
        echo "✅ DBaaS database setup completed"
    else
        echo "⚠️  DBaaS setup script not found: $DBAAS_SCRIPT"
        echo "Proceeding with app server installation..."
    fi
    
    # Create app directories  
    APP_DIR="/home/rocky/ceweb/app-server"
    FILES_DIR="/home/rocky/ceweb/files"
    AUDITION_DIR="/home/rocky/ceweb/files/audition"
    
    sudo -u rocky mkdir -p $APP_DIR/logs
    sudo -u rocky mkdir -p $AUDITION_DIR
    chmod -R 755 $FILES_DIR
    chown -R rocky:rocky $FILES_DIR
    
    # Install S3/Object Storage dependencies and all application dependencies
    cd $APP_DIR
    if [ -f package.json ]; then
        echo "Installing all Node.js dependencies..."
        sudo -u rocky npm install
        
        echo "Installing Object Storage dependencies..."
        sudo -u rocky npm install @aws-sdk/client-s3@^3.600.0
        sudo -u rocky npm install @aws-sdk/s3-request-presigner@^3.600.0
        echo "✅ All dependencies installed"
    fi
    
    # Generate JWT Secret Key
    if command -v openssl &> /dev/null; then
        JWT_SECRET=$(openssl rand -hex 32)
        echo "✅ JWT Secret Key generated (64 characters)"
    else
        JWT_SECRET="your_jwt_secret_key_minimum_32_characters_long_change_this_in_production"
        echo "⚠️ Using default JWT key - OpenSSL not available"
    fi
    
    # Create comprehensive .env file matching production environment
    cat > $APP_DIR/.env << EOF
# External Database Configuration
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_SSL=false

# Connection Pool Settings
DB_POOL_MIN=2
DB_POOL_MAX=10
DB_POOL_IDLE_TIMEOUT=30000
DB_POOL_CONNECTION_TIMEOUT=5000

# Server Configuration (App Server)
PORT=3000
NODE_ENV=production
BIND_HOST=0.0.0.0

# CORS Configuration (allowed domain list)
ALLOWED_ORIGINS=$ALLOWED_ORIGINS

# Security
JWT_SECRET=$JWT_SECRET

# Logging
LOG_LEVEL=info
EOF
    chown rocky:rocky $APP_DIR/.env && chmod 600 $APP_DIR/.env
    
    # Create comprehensive PM2 ecosystem configuration matching production
    cat > $APP_DIR/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'creative-energy-api',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      BIND_HOST: '0.0.0.0'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    node_args: '--max_old_space_size=1024',
    
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF
    chown rocky:rocky $APP_DIR/ecosystem.config.js
    
    # Create VM information file for Load Balancer environment
    VM_HOSTNAME=$(hostname -s)
    VM_IP=$(hostname -I | awk '{print $1}')
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Extract VM number from hostname (appvm121r -> 1, appvm122r -> 2)
    VM_NUMBER=""
    if [[ $VM_HOSTNAME =~ appvm([0-9]+) ]]; then
        FULL_NUMBER=${BASH_REMATCH[1]}
        VM_NUMBER="${FULL_NUMBER: -1}"
    else
        VM_NUMBER="1"  # default
    fi
    
    VM_INFO_FILE="$APP_DIR/vm-info.json"
    cat > "$VM_INFO_FILE" << EOF
{
  "hostname": "$VM_HOSTNAME",
  "ip_address": "$VM_IP",
  "vm_number": "$VM_NUMBER",
  "server_type": "app-server",
  "load_balancer": {
    "name": "$APP_SERVER_HOST",
    "ip": "$APP_LB_SERVICE_IP",
    "policy": "Round Robin"
  },
  "cluster": {
    "servers": [
      {
        "hostname": "appvm121r",
        "ip": "$APP_PRIMARY_IP",
        "vm_number": "1"
      },
      {
        "hostname": "appvm122r", 
        "ip": "$APP_SECONDARY_IP",
        "vm_number": "2"
      }
    ]
  },
  "timestamp": "$CURRENT_TIME",
  "version": "1.0"
}
EOF
    chmod 644 "$VM_INFO_FILE"
    chown rocky:rocky "$VM_INFO_FILE"
    echo "✅ VM information file created: $VM_INFO_FILE"
    
    # Create Object Storage credentials template (matches production structure)
    cat > $APP_DIR/credentials.json << 'EOF'
{
  "accessKeyId": "your-access-key-here",
  "secretAccessKey": "your-secret-key-here",
  "region": "kr-west1",
  "bucketName": "ceweb",
  "privateEndpoint": "https://object-store.private.kr-west1.e.samsungsdscloud.com",
  "publicEndpoint": "https://object-store.kr-west1.e.samsungsdscloud.com",
  "folders": {
    "media": "media/img",
    "audition": "files/audition"
  }
}
EOF
    chown rocky:rocky $APP_DIR/credentials.json && chmod 600 $APP_DIR/credentials.json
    echo "✅ Object Storage credentials template created"
    echo "⚠️  Real Samsung Cloud Platform credentials must be configured for Object Storage functionality"
    
    # Install dependencies and start app
    cd $APP_DIR
    if [ -f package.json ]; then
        # Start PM2 application
        sudo -u rocky pm2 start ecosystem.config.js
        
        if [ $? -eq 0 ]; then
            echo "✅ PM2 application started successfully"
            sudo -u rocky pm2 list
            sudo -u rocky pm2 save
        else
            echo "⚠️ PM2 application start failed"
        fi
    fi
    
    # Setup PM2 auto-start
    echo "Setting up PM2 auto-start..."
    sudo -u rocky pm2 startup systemd --user rocky 2>/dev/null || {
        echo "PM2 startup setup requires manual execution:"
        echo "sudo su - rocky"
        echo "pm2 startup systemd"
        echo "pm2 save"
    }
    
    if sudo -u rocky pm2 save >/dev/null 2>&1; then
        echo "✅ PM2 auto-start configuration completed"
    else
        echo "⚠️ PM2 save failed - manual 'pm2 save' execution required"
    fi
    
    echo "✅ App server with Object Storage support installed"
}

# App Server Verification Module
verify_install() {
    echo "[5/5] App verification..."
    
    # Check Node.js process
    if pgrep -f node >/dev/null; then
        echo "✅ Node.js process is running"
    else
        echo "❌ Node.js process not found"
        exit 1
    fi
    
    # Check port 3000
    if netstat -tlnp | grep :3000 >/dev/null; then
        echo "✅ Port 3000 is listening"
    else
        echo "❌ Port 3000 not listening"
        exit 1
    fi
    
    # Test API health endpoint
    echo "Testing API health endpoint..."
    for i in {1..30}; do
        if curl -f http://localhost:3000/health 2>/dev/null; then
            echo "✅ App server health check passed"
            break
        elif curl -f http://localhost:3000/ 2>/dev/null; then
            echo "✅ App server basic response successful"
            break
        elif [ $i -eq 30 ]; then
            echo "⚠️ API endpoint timeout after 60 seconds"
        else
            echo "Attempt $i/30: API not ready, waiting 2s..."
            sleep 2
        fi
    done
    
    # Verify configuration files
    APP_DIR="/home/rocky/ceweb/app-server"
    
    # Check .env file
    if [ -f "$APP_DIR/.env" ]; then
        echo "✅ .env file exists"
        if grep -q "DB_HOST" $APP_DIR/.env && grep -q "ALLOWED_ORIGINS" $APP_DIR/.env; then
            echo "✅ Environment configuration verified"
        else
            echo "⚠️ Environment configuration incomplete"
        fi
    else
        echo "❌ .env file not found"
    fi
    
    # Check PM2 ecosystem
    if [ -f "$APP_DIR/ecosystem.config.js" ]; then
        echo "✅ PM2 ecosystem configuration exists"
    else
        echo "❌ PM2 ecosystem configuration not found"
    fi
    
    # Check VM info file
    if [ -f "$APP_DIR/vm-info.json" ]; then
        echo "✅ VM information file exists"
    else
        echo "⚠️ VM information file not found"
    fi
    
    # Check Object Storage credentials template
    if [ -f "$APP_DIR/credentials.json" ]; then
        echo "✅ Object Storage credentials template exists"
    else
        echo "⚠️ Object Storage credentials template not found"
    fi
    
    # Check PM2 process status
    if sudo -u rocky pm2 list | grep -q "creative-energy-api"; then
        echo "✅ PM2 process 'creative-energy-api' is registered"
        if sudo -u rocky pm2 list | grep "creative-energy-api" | grep -q "online"; then
            echo "✅ PM2 process is online"
        else
            echo "⚠️ PM2 process is not online"
        fi
    else
        echo "❌ PM2 process 'creative-energy-api' not found"
    fi
    
    # Check file directories
    if [ -d "/home/rocky/ceweb/files/audition" ]; then
        echo "✅ Audition file directory exists"
    else
        echo "⚠️ Audition file directory not found"
    fi
    
    echo "✅ App server with Object Storage verification completed"
}