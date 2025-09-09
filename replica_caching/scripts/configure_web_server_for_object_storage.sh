#!/bin/bash
# Samsung Cloud Platform v2 - Object Storage Configuration Script
# Generated: 2025-09-06 11:36:28
#
# PURPOSE: Configure master_config.json for manually deployed web servers
# USAGE: Run this script from /home/rocky directory
#        cd /home/rocky && bash configure_web_server_for_object_storage.sh
#
# This script creates master_config.json required for Object Storage integration

set -euo pipefail

# Color functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Logging
log_info() { echo "[INFO] $1"; }
log_success() { echo "$(green "[SUCCESS]") $1"; }
log_error() { echo "$(red "[ERROR]") $1"; }
log_warning() { echo "$(yellow "[WARNING]") $1"; }

echo "$(cyan "===========================================")"
echo "$(cyan "Object Storage Configuration for Web Server")"
echo "$(cyan "Samsung Cloud Platform v2")"
echo "$(cyan "===========================================")"
echo ""

# Check if running from correct directory
if [[ "$(pwd)" != "/home/rocky" ]]; then
    log_warning "Current directory: $(pwd)"
    log_info "Switching to /home/rocky directory..."
    cd /home/rocky || {
        log_error "Failed to change to /home/rocky directory"
        exit 1
    }
fi

# Check if ceweb repository exists
if [[ ! -d "ceweb" ]]; then
    log_error "ceweb directory not found in /home/rocky"
    log_info "Please clone the repository first:"
    echo "  git clone https://github.com/SCPv2/ceweb.git"
    exit 1
fi

# Check if web-server directory exists
if [[ ! -d "ceweb/web-server" ]]; then
    log_error "web-server directory not found in /home/rocky/ceweb"
    log_info "Repository structure may be incorrect"
    exit 1
fi

# Create master_config.json
log_info "Creating master_config.json..."

cat > /home/rocky/ceweb/web-server/master_config.json << 'CONFIG_EOF'
{"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","terraform_infra":"Variables used by terraform for infrastructure deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"ceweb_required_variables":{"rollback_enabled":"true","nginx_port":"80","object_storage_public_endpoint":"https://object-store.kr-west1.e.samsungsdscloud.com","_source":"variables.tf CEWEB_REQUIRED category","object_storage_audition_folder":"files/audition","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","object_storage_media_folder":"media/img","db_max_connections":"100","database_user":"cedbadmin","app_ip":"10.1.2.121","object_storage_region":"kr-west1","app_server_port":"3000","auto_deployment":"true","database_name":"cedb","git_repository":"https://github.com/SCPv2/ceweb.git","admin_email":"ars4mundus@gmail.com","db_type":"postgresql","backup_retention_days":"30","object_storage_private_endpoint":"https://object-store.private.kr-west1.e.samsungsdscloud.com","db_ip":"10.1.3.132","git_branch":"main","session_secret":"your-secret-key-change-in-production","_comment":"Variables required by ceweb application for business logic and functionality","web_lb_service_ip":"10.1.1.100","company_name":"Creative Energy","_database_connection":{"db_ssl_enabled":false,"database_password":"cedbadmin123!","db_pool_idle_timeout":30000,"db_pool_min":20,"db_pool_connection_timeout":60000,"db_pool_max":100},"object_storage_bucket_name":"ceweb","node_env":"production","web_ip":"10.1.1.111","database_host":"db.your_private_domain.name","ssl_enabled":"false"},"image_engine_metadata":{"cache_file":"image_engine_id.json","scpcli_available":false,"last_updated":"2025-09-06T11:36:22Z"},"terraform_infra_variables":{"_comment":"Variables used by terraform for infrastructure deployment","db_ip2":"10.1.3.33","windows_image_id":"fallback-windows-id","rocky_image_id":"fallback-rocky-id","_source":"variables.tf TERRAFORM_INFRA category and SCP CLI","postgresql_engine_id":"8a463aa4b1dc4f279c3f53b94dc45e74"},"config_metadata":{"template_source":"variables.tf","version":"4.1.0","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS","image_engine_cache":"image_engine_id.json","created":"2025-09-06 11:36:27","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1"},"user_input_variables":{"object_storage_bucket_string":"put_your_account_id_here","public_domain_name":"your_public_domain.name","object_storage_secret_access_key":"put_your_authentificate_secret_key_here","keypair_name":"mykey","_source":"variables.tf USER_INPUT category","private_domain_name":"your_private_domain.name","object_storage_access_key_id":"put_your_authentificate_access_key_here","user_public_ip":"your_public_ip/32","_comment":"Variables that users input interactively during deployment"}}
CONFIG_EOF

# Set proper permissions
if id "rocky" &>/dev/null; then
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    chmod 644 /home/rocky/ceweb/web-server/master_config.json
    log_success "Permissions set for rocky user"
else
    chmod 644 /home/rocky/ceweb/web-server/master_config.json
    log_warning "User 'rocky' not found, permissions set for current user"
fi

# Validate JSON
if command -v jq &> /dev/null; then
    if jq . /home/rocky/ceweb/web-server/master_config.json >/dev/null 2>&1; then
        log_success "JSON validation passed"
    else
        log_error "Invalid JSON in master_config.json"
        log_info "Please check the file for syntax errors"
        exit 1
    fi
else
    log_warning "jq not installed, skipping JSON validation"
    log_info "Install jq for JSON validation: sudo dnf install -y jq"
fi

# Check if required fields exist
if command -v jq &> /dev/null; then
    log_info "Checking Object Storage configuration..."
    
    BUCKET_STRING=$(jq -r '.user_input_variables.object_storage_bucket_string // "not_found"' /home/rocky/ceweb/web-server/master_config.json)
    BUCKET_NAME=$(jq -r '.ceweb_required_variables.object_storage_bucket_name // "not_found"' /home/rocky/ceweb/web-server/master_config.json)
    PUBLIC_ENDPOINT=$(jq -r '.ceweb_required_variables.object_storage_public_endpoint // "not_found"' /home/rocky/ceweb/web-server/master_config.json)
    
    if [[ "$BUCKET_STRING" == "not_found" ]] || [[ "$BUCKET_STRING" == "thisneedstobereplaced1234" ]]; then
        log_warning "Object Storage bucket string not configured or using default value"
        log_info "Template variables will use local media files instead of Object Storage"
    else
        log_success "Object Storage configured:"
        echo "  - Bucket String: $BUCKET_STRING"
        echo "  - Bucket Name: $BUCKET_NAME"
        echo "  - Endpoint: $PUBLIC_ENDPOINT"
        echo ""
        echo "  Full Object Storage URL will be:"
        echo "  $PUBLIC_ENDPOINT/$BUCKET_STRING:$BUCKET_NAME/media/img/"
    fi
fi

echo ""
log_success "master_config.json created successfully!"
echo ""
echo "$(cyan "File location:")"
echo "  /home/rocky/ceweb/web-server/master_config.json"
echo ""
echo "$(cyan "Next steps:")"
echo "  1. Restart web server to apply configuration:"
echo "     sudo systemctl restart nginx"
echo ""
echo "  2. Check if template variables are being replaced:"
echo "     Open browser and check if images load correctly"
echo ""
echo "  3. Monitor browser console for any errors:"
echo "     Check for {{OBJECT_STORAGE_MEDIA_BASE}} placeholders"
echo ""
echo "  4. If using Object Storage, ensure:"
echo "     - Bucket is created and accessible"
echo "     - CORS policy is configured for your domain"
echo "     - Files are uploaded to correct paths"
echo ""

# Test if nginx is installed and running
if command -v nginx &> /dev/null; then
    if systemctl is-active nginx &> /dev/null; then
        log_info "Nginx is running. You may want to restart it:"
        echo "  sudo systemctl restart nginx"
    else
        log_warning "Nginx is installed but not running"
        echo "  Start nginx: sudo systemctl start nginx"
    fi
else
    log_warning "Nginx not found. Please install and configure nginx"
fi

echo ""
log_success "Configuration script completed!"