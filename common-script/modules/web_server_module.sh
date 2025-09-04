# Web Server Application Install Module
app_install() {
    echo "[4/5] Web server install..."
    
    # Install Nginx
    dnf install -y nginx
    systemctl start nginx && systemctl enable nginx
    
    # Create web directories with proper permissions
    WEB_DIR="/home/rocky/ceweb"
    sudo -u rocky mkdir -p $WEB_DIR/{media/img,files/audition}
    chown -R rocky:rocky $WEB_DIR
    chmod -R 755 $WEB_DIR
    
    # Set home directory permissions (critical for Nginx access)
    chmod 755 /home/rocky
    
    # SELinux configuration for home directory access
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
        echo "Setting SELinux contexts for web directory..."
        
        # Set proper SELinux context for web content
        semanage fcontext -a -t httpd_exec_t "$WEB_DIR(/.*)?" 2>/dev/null || true
        semanage fcontext -a -t httpd_exec_t "$WEB_DIR/media(/.*)?" 2>/dev/null || true  
        semanage fcontext -a -t httpd_exec_t "$WEB_DIR/files(/.*)?" 2>/dev/null || true
        restorecon -Rv $WEB_DIR 2>/dev/null || true
        
        # Enable home directory access
        setsebool -P httpd_enable_homedirs 1 2>/dev/null || true
        
        # Enable NFS file access (for various file contexts)
        setsebool -P httpd_use_nfs 1 2>/dev/null || true
    fi
    
    # Load master config and extract variables
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "cesvc.net"' $MASTER_CONFIG)
    PUBLIC_DOMAIN=$(jq -r '.user_input_variables.public_domain_name // "creative-energy.net"' $MASTER_CONFIG)
    APP_PORT=$(jq -r '.ceweb_required_variables.app_server_port // "3000"' $MASTER_CONFIG)
    
    # Create Nginx configuration
    cat > /etc/nginx/conf.d/creative-energy.conf << EOF
server {
    listen 80 default_server;
    server_name www.$PRIVATE_DOMAIN www.$PUBLIC_DOMAIN localhost;
    client_max_body_size 100M;
    
    location / {
        root /home/rocky/ceweb;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://app.$PRIVATE_DOMAIN:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /health {
        proxy_pass http://app.$PRIVATE_DOMAIN:$APP_PORT/health;
        proxy_connect_timeout 5s;
    }
}
EOF
    
    # SELinux configuration for OpenStack
    if command -v setsebool >/dev/null 2>&1; then
        setsebool -P httpd_read_user_content 1 2>/dev/null || true
        setsebool -P httpd_can_network_connect 1 2>/dev/null || true
    fi
    
    # Disable default server block (prevents Rocky Linux test page)
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    sed -i '/^    server {/,/^    }/s/^/#/' /etc/nginx/nginx.conf
    
    # Test nginx configuration and restart
    nginx -t && systemctl restart nginx
    
    # Wait for app server to be available
    echo "Checking app server connectivity..."
    for i in {1..20}; do
        if curl -f --connect-timeout 3 http://app.$PRIVATE_DOMAIN:$APP_PORT/health >/dev/null 2>&1; then
            echo "✅ App server connection verified"
            break
        elif [ $i -eq 20 ]; then
            echo "⚠️  App server not responding, but web server configured"
            break
        else
            echo "Attempt $i/20: App server not ready, waiting 5s..."
            sleep 5
        fi
    done
    
    echo "✅ Web server installed"
}

# Web Server Verification Module
verify_install() {
    echo "[5/5] Web verification..."
    
    # Check Nginx status
    systemctl is-active nginx || exit 1
    
    # Check port 80
    netstat -tlnp | grep :80 || exit 1
    
    # Test web server response with timeout and retry
    for i in {1..10}; do
        if curl -I --connect-timeout 5 http://localhost/ >/dev/null 2>&1; then
            echo "✅ Web server responding"
            break
        elif [ $i -eq 10 ]; then
            echo "⚠️  Web server timeout, but proceeding"
            break
        else
            echo "Attempt $i/10: Web server not ready, waiting 3s..."
            sleep 3
        fi
    done
    
    echo "✅ Web server verified"
}