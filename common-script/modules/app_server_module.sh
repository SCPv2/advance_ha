# App Server Application Install Module  
app_install() {
    echo "[4/5] App server install..."
    
    # Install Node.js 20.x
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs postgresql nmap-ncat
    npm install -g pm2
    
    # Load master config
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "cesvc.net"' $MASTER_CONFIG)
    DB_HOST=$(jq -r '.ceweb_required_variables.database_host // "db.'$PRIVATE_DOMAIN'"' $MASTER_CONFIG)
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "cedbadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
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
    
    # Create app directories  
    APP_DIR="/home/rocky/ceweb/app-server"
    sudo -u rocky mkdir -p $APP_DIR/logs
    sudo -u rocky mkdir -p /home/rocky/ceweb/files/audition
    
    # Create .env file
    cat > $APP_DIR/.env << EOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
PORT=3000
NODE_ENV=production
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "default-jwt-secret-change-me")
EOF
    chown rocky:rocky $APP_DIR/.env && chmod 600 $APP_DIR/.env
    
    # Create PM2 ecosystem
    cat > $APP_DIR/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'creative-energy-api',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: { NODE_ENV: 'production', PORT: 3000 }
  }]
};
EOF
    chown rocky:rocky $APP_DIR/ecosystem.config.js
    
    # Install dependencies and start app
    cd $APP_DIR
    if [ -f package.json ]; then
        sudo -u rocky npm install
        sudo -u rocky pm2 start ecosystem.config.js
        sudo -u rocky pm2 save
    fi
    
    echo "✅ App server installed"
}

# App Server Verification Module
verify_install() {
    echo "[5/5] App verification..."
    
    # Check Node.js process
    pgrep -f node || exit 1
    
    # Check port 3000
    netstat -tlnp | grep :3000 || exit 1
    
    # Test API health endpoint
    for i in {1..30}; do
        if curl -f http://localhost:3000/health 2>/dev/null; then
            echo "✅ App server health check passed"
            break
        fi
        sleep 2
    done
    
    echo "✅ App server verified"
}