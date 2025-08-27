#!/bin/bash
# Samsung Cloud Platform v2 (OpenStack) - Compact UserData Base
# 45KB limit optimized for OpenStack cloud-init

set -euo pipefail
SERVER_TYPE="web"
LOGFILE="/var/log/userdata_web.log"
exec 1> >(tee -a $LOGFILE) 2>&1

echo "=== ${SERVER_TYPE^} Server Init: $(date) ==="

# Module 0: Local DNS Resolution
local_dns_setup() {
    echo "[0/5] Local DNS Resolution setup..."
    
    # Define domain mappings
    PRIVATE_DOMAIN="your_internal.local"
    WEB_IP="10.1.1.111"
    APP_IP="10.1.2.121"
    DB_IP="10.1.3.31"
    
    # Create temporary hosts entries
    cat >> /etc/hosts << EOF

# === SCPv2 Temporary DNS Mappings ===
10.1.1.111 www.${PRIVATE_DOMAIN}
10.1.2.121 app.${PRIVATE_DOMAIN}
10.1.3.31 db.${PRIVATE_DOMAIN}
# === End SCPv2 Mappings ===
EOF
    
    echo "✅ Local DNS mappings added to /etc/hosts"
    echo "   www.${PRIVATE_DOMAIN} -> 10.1.1.111"
    echo "   app.${PRIVATE_DOMAIN} -> 10.1.2.121"
    echo "   db.${PRIVATE_DOMAIN} -> 10.1.3.31"
}

# Module 1: System Update (Compact)
sys_update() {
    echo "[1/5] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do sleep 10; done
    for i in {1..3}; do dnf clean all && dnf install -y epel-release && break; sleep 30; done
    dnf -y update upgrade || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    echo "✅ System updated with NTP"
}

# Module 2: Repository Clone
repo_clone() {
    echo "[2/5] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    echo "✅ Repository ready"
}

# Module 3: Config Injection (Template substitution)
config_inject() {
    echo "[3/5] Config injection..."
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
{"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"config_metadata":{"version":"4.0.0","created":"2025-08-27 19:48:42","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1","template_source":"variables.tf"},"user_input_variables":{"_comment":"Variables that users input interactively during deployment","_source":"variables.tf USER_INPUT category","object_storage_bucket_string":"put_the_value_if_you_use_object_storage_in_this_lab","public_domain_name":"yourdomain.com","object_storage_secret_access_key":"put_the_value_if_you_use_object_storage_in_this_labs","private_hosted_zone_id":"your_private_hosted_zone_id","private_domain_name":"your_internal.local","object_storage_access_key_id":"put_the_value_if_you_use_object_storage_in_this_labs","user_public_ip":"your_public_ip/32","keypair_name":"mykey"},"ceweb_required_variables":{"_comment":"Variables required by ceweb application for business logic and functionality","_source":"variables.tf CEWEB_REQUIRED category","_database_connection":{"database_password":"ceadmin123","db_ssl_enabled":false,"db_pool_min":20,"db_pool_max":100,"db_pool_idle_timeout":30000,"db_pool_connection_timeout":60000},"certificate_path":"/etc/ssl/certs/certificate.crt","admin_email":"ars4mundus@gmail.com","private_key_path":"/etc/ssl/private/private.key","rollback_enabled":"true","object_storage_public_endpoint":"https://object-store.kr-west1.e.samsungsdscloud.com","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","object_storage_media_folder":"media/img","db_max_connections":"100","database_user":"ceadmin","app_ip":"10.1.2.121","object_storage_region":"kr-west1","app_server_port":"3000","database_password":"ceadmin123!","auto_deployment":"true","database_name":"cedb","git_repository":"https://github.com/SCPv2/ceweb.git","object_storage_audition_folder":"files/audition","company_name":"Creative Energy","backup_retention_days":"30","object_storage_private_endpoint":"https://object-store.private.kr-west1.e.samsungsdscloud.com","db_type":"postgresql","git_branch":"main","session_secret":"your-secret-key-change-in-production","web_lb_service_ip":"10.1.1.100","nginx_port":"80","db_ip":"10.1.3.31","object_storage_bucket_name":"ceweb","node_env":"production","web_ip":"10.1.1.111","database_host":"db.cesvc.net","ssl_enabled":"false"}}
CONFIG_EOF
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    jq . /home/rocky/master_config.json >/dev/null || exit 1
    echo "✅ Config injected"
}

# Module 3 & 5: Application Install and Verification (Server-specific - will be injected)
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

# Module 6: Local DNS Cleanup
local_dns_cleanup() {
    echo "[6/6] Local DNS Resolution cleanup..."
    
    # Remove SCPv2 temporary DNS mappings from /etc/hosts
    sudo sed -i '/# === SCPv2 Temporary DNS Mappings ===/,/# === End SCPv2 Mappings ===/d' /etc/hosts
    
    echo "✅ Local DNS mappings cleaned up from /etc/hosts"
}

# Main execution
main() {
    local_dns_setup
    sys_update
    repo_clone
    config_inject
    app_install
    verify_install
    local_dns_cleanup
    echo "${SERVER_TYPE^} ready: $(date)" > /home/rocky/${SERVER_TYPE^}_Ready.log
    echo "=== ${SERVER_TYPE^} Init Complete: $(date) ==="
}

main