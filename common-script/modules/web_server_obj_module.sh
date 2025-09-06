# Web Server Application Install Module (Object Storage Enhanced)
app_install() {
    echo "[4/5] Web server install (Object Storage + Load Balancer)..."
    
    # Install Nginx and additional packages
    dnf install -y nginx wget curl git vim nano htop net-tools
    systemctl start nginx && systemctl enable nginx
    
    # Load master config first
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "cesvc.net"' $MASTER_CONFIG)
    PUBLIC_DOMAIN=$(jq -r '.user_input_variables.public_domain_name // "creative-energy.net"' $MASTER_CONFIG)
    APP_PORT=$(jq -r '.ceweb_required_variables.app_server_port // "3000"' $MASTER_CONFIG)
    
    # Load additional configuration for infrastructure
    WEB_LB_SERVICE_IP=$(jq -r '.ceweb_required_variables.web_lb_service_ip // "10.1.1.100"' $MASTER_CONFIG)
    APP_LB_SERVICE_IP=$(jq -r '.ceweb_required_variables.app_lb_service_ip // "10.1.2.100"' $MASTER_CONFIG)
    WEB_PRIMARY_IP=$(jq -r '.ceweb_required_variables.web_ip // "10.1.1.111"' $MASTER_CONFIG)
    WEB_SECONDARY_IP="10.1.1.112"
    APP_PRIMARY_IP=$(jq -r '.ceweb_required_variables.app_ip // "10.1.2.121"' $MASTER_CONFIG)
    APP_SECONDARY_IP="10.1.2.122"
    DB_PRIMARY_IP=$(jq -r '.ceweb_required_variables.db_ip // "10.1.3.131"' $MASTER_CONFIG)
    BASTION_IP="10.1.1.110"
    
    # Set server hostnames
    APP_SERVER_HOST="app.${PRIVATE_DOMAIN}"
    DEFAULT_SERVER_NAMES="www.$PRIVATE_DOMAIN www.$PUBLIC_DOMAIN"
    
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
        setsebool -P httpd_read_user_content 1 2>/dev/null || true
        
        # Enable network connections and NFS file access
        setsebool -P httpd_can_network_connect 1 2>/dev/null || true
        setsebool -P httpd_use_nfs 1 2>/dev/null || true
        
        echo "✅ SELinux configuration completed"
    fi
    
    # Create comprehensive Nginx configuration for Object Storage
    cat > /etc/nginx/conf.d/creative-energy.conf << EOF
server {
    listen 80 default_server;
    server_name $DEFAULT_SERVER_NAMES localhost _;
    
    # File upload size limit (for audition files)
    client_max_body_size 100M;
    
    # Static file serving (HTML, CSS, JS, images, etc.)
    location / {
        root /home/rocky/ceweb;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # Static file caching
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Files folder - for uploaded file downloads
    location /files/ {
        root /home/rocky/ceweb;
        autoindex off;  # Disable directory listing for security
        
        # File download headers
        add_header Content-Disposition "attachment";
        add_header X-Content-Type-Options "nosniff";
        
        # Allow only specific file extensions
        location ~* \.(pdf|doc|docx|mp3|mp4|jpg|jpeg|png)\$ {
            expires 30d;
            add_header Cache-Control "public";
        }
        
        # Block executable files
        location ~* \.(php|php3|php4|php5|phtml|pl|py|jsp|asp|sh|cgi|exe|bat|com)\$ {
            deny all;
            return 403;
        }
    }
    
    # Media folder - for image file serving
    location /media/ {
        root /home/rocky/ceweb;
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Allow only image files
        location ~* /media/.*\.(jpg|jpeg|png|gif|ico|svg|webp)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # Block executable files and other files
        location ~* /media/.*\.(php|php3|php4|php5|phtml|pl|py|jsp|asp|sh|cgi|exe|bat|com|txt|md)\$ {
            deny all;
            return 403;
        }
    }
    
    # Web-Server folder - API config files only (security enhanced)
    location /web-server/ {
        root /home/rocky/ceweb;
        
        # Allow JS files only (api-config.js etc.)
        location ~* \.js\$ {
            expires 1d;
            add_header Cache-Control "public";
        }
        
        # Block installation scripts and documentation files
        location ~* \.(sh|md|txt|conf|yml|yaml)\$ {
            deny all;
            return 403;
        }
        
        # Disable directory listing
        autoindex off;
    }
    
    # VM info endpoint - Load Balancer server status
    location /vm-info.json {
        alias /home/rocky/ceweb/vm-info.json;
        add_header Content-Type application/json;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma no-cache;
        add_header Expires 0;
    }
    
    # Master Configuration endpoint - config file serving
    location /web-server/master_config.json {
        alias /home/rocky/ceweb/web-server/master_config.json;
        add_header Content-Type application/json;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma no-cache;
        add_header Expires 0;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type";
    }
    
    # API proxy (to App Load Balancer)
    location /api/ {
        proxy_pass http://$APP_SERVER_HOST:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Load Balancer environment optimization
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        
        # Load Balancer Health Check and Failover settings
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 2;
        proxy_next_upstream_timeout 30s;
        
        # Session maintenance headers
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header X-Forwarded-Server \$host;
    }
    
    # Health Check endpoint (to App Load Balancer)
    location /health {
        proxy_pass http://$APP_SERVER_HOST:$APP_PORT/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
        proxy_read_timeout 5s;
        
        # Load Balancer Health Check response optimization
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 1;
    }
    
    # Global media file caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Log settings
    access_log /var/log/nginx/creative-energy-access.log;
    error_log /var/log/nginx/creative-energy-error.log;
}
EOF
    
    # Disable default server block (prevents proxy conflicts)
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    sed -i '/^    server {/,/^    }/s/^/#/' /etc/nginx/nginx.conf
    
    # Test nginx configuration and restart
    nginx -t && systemctl restart nginx
    
    # Create VM information file for Load Balancer environment
    VM_HOSTNAME=\$(hostname -s)
    VM_IP=\$(hostname -I | awk '{print \$1}')
    CURRENT_TIME=\$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Extract VM number from hostname (webvm111r -> 1, webvm112r -> 2)
    VM_NUMBER=""
    if [[ \$VM_HOSTNAME =~ webvm([0-9]+) ]]; then
        FULL_NUMBER=\${BASH_REMATCH[1]}
        VM_NUMBER="\${FULL_NUMBER: -1}"
    else
        VM_NUMBER="1"  # default
    fi
    
    VM_INFO_FILE="$WEB_DIR/vm-info.json"
    cat > "\$VM_INFO_FILE" << VMEOF
{
  "hostname": "\$VM_HOSTNAME",
  "ip_address": "\$VM_IP",
  "vm_number": "\$VM_NUMBER",
  "server_type": "web-server",
  "load_balancer": {
    "name": "www.$PRIVATE_DOMAIN",
    "ip": "$WEB_LB_SERVICE_IP",
    "policy": "Round Robin"
  },
  "cluster": {
    "servers": [
      {
        "hostname": "webvm111r",
        "ip": "$WEB_PRIMARY_IP",
        "vm_number": "1"
      },
      {
        "hostname": "webvm112r", 
        "ip": "$WEB_SECONDARY_IP",
        "vm_number": "2"
      }
    ]
  },
  "timestamp": "\$CURRENT_TIME",
  "version": "1.0"
}
VMEOF
    
    chmod 644 "\$VM_INFO_FILE"
    chown rocky:rocky "\$VM_INFO_FILE"
    echo "✅ VM information file created: \$VM_INFO_FILE"
    
    # Setup Bootstrap script (if exists)
    BOOTSTRAP_SCRIPT="$WEB_DIR/web-server/bootstrap_web_vm.sh"
    if [ -f "\$BOOTSTRAP_SCRIPT" ]; then
        echo "Bootstrap script found, setting up auto-execution..."
        
        # Copy Bootstrap script to system location
        cp "\$BOOTSTRAP_SCRIPT" /usr/local/bin/
        chmod +x /usr/local/bin/bootstrap_web_vm.sh
        chown root:root /usr/local/bin/bootstrap_web_vm.sh
        
        # Add to rc.local for VM boot auto-execution
        if ! grep -q "bootstrap_web_vm.sh" /etc/rc.local 2>/dev/null; then
            echo '#!/bin/bash' > /etc/rc.local
            echo '/usr/local/bin/bootstrap_web_vm.sh' >> /etc/rc.local
            chmod +x /etc/rc.local
            echo "✅ VM Bootstrap script auto-execution setup completed"
        else
            echo "Bootstrap script already configured in rc.local"
        fi
        
        echo "✅ Samsung Cloud Platform Load Balancer environment setup completed"
    else
        echo "⚠️  Bootstrap script not found: \$BOOTSTRAP_SCRIPT"
    fi
    
    # Final permission settings
    chmod 755 /home/rocky
    chmod -R 755 $WEB_DIR
    chown -R rocky:rocky $WEB_DIR
    echo "✅ Final permission settings completed"
    
    # Wait for app server to be available
    echo "Checking app server connectivity..."
    for i in {1..20}; do
        if curl -f --connect-timeout 3 http://$APP_SERVER_HOST:$APP_PORT/health >/dev/null 2>&1; then
            echo "✅ App server connection verified"
            break
        elif [ i -eq 20 ]; then
            echo "⚠️  App server not responding, but web server configured"
            break
        else
            echo "Attempt \$i/20: App server not ready, waiting 5s..."
            sleep 5
        fi
    done
    
    echo "✅ Web server with Object Storage and Load Balancer support installed"
}

# Web Server Verification Module
verify_install() {
    echo "[5/5] Web verification..."
    
    # Check Nginx status
    if systemctl is-active nginx >/dev/null; then
        echo "✅ Nginx service is active"
    else
        echo "❌ Nginx service not active"
        exit 1
    fi
    
    # Check port 80
    if netstat -tlnp | grep :80 >/dev/null; then
        echo "✅ Port 80 is listening"
    else
        echo "❌ Port 80 not listening"
        exit 1
    fi
    
    # Test web server response with timeout and retry
    echo "Testing web server response..."
    for i in {1..10}; do
        if curl -I --connect-timeout 5 http://localhost/ >/dev/null 2>&1; then
            echo "✅ Web server responding"
            break
        elif [ i -eq 10 ]; then
            echo "⚠️  Web server timeout, but proceeding"
            break
        else
            echo "Attempt \$i/10: Web server not ready, waiting 3s..."
            sleep 3
        fi
    done
    
    # Verify configuration files
    WEB_DIR="/home/rocky/ceweb"
    
    # Check VM info file
    if [ -f "\$WEB_DIR/vm-info.json" ]; then
        echo "✅ VM information file exists"
    else
        echo "⚠️  VM information file not found"
    fi
    
    # Check master_config.json endpoint
    if curl -f --connect-timeout 3 http://localhost/web-server/master_config.json >/dev/null 2>&1; then
        echo "✅ master_config.json endpoint responding"
    else
        echo "⚠️  master_config.json endpoint not responding"
    fi
    
    # Check directories
    if [ -d "\$WEB_DIR/media/img" ] && [ -d "\$WEB_DIR/files/audition" ]; then
        echo "✅ Web directories exist"
    else
        echo "⚠️  Web directories not found"
    fi
    
    # Check permissions
    if [ -r "\$WEB_DIR" ] && [ -r "\$WEB_DIR/media" ]; then
        echo "✅ Directory permissions correct"
    else
        echo "⚠️  Directory permission issues detected"
    fi
    
    echo "✅ Web server with Object Storage verified"
}