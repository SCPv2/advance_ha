#!/bin/bash
# Samsung Cloud Platform v2 - Emergency Recovery Script
# Server Type: DB SERVER
# Generated: 2025-08-26 10:07:38
#
# PURPOSE: Emergency installation and configuration when UserData fails
# USAGE: Run this script directly on the VM as root
#        sudo bash emergency_db.sh
#
# Referenced GitHub installation scripts:
# - Web Server: https://github.com/SCPv2/ceweb/blob/main/web-server/install_web_server.sh
# - App Server: https://github.com/SCPv2/ceweb/blob/main/app-server/install_app_server.sh
# - DB Server: https://github.com/SCPv2/ceweb/blob/main/db-server/vm_db/install_postgresql_vm.sh

set -euo pipefail

# Color functions for better visibility
red() { echo -e "\033[31m\$1\033[0m"; }
green() { echo -e "\033[32m\$1\033[0m"; }
yellow() { echo -e "\033[33m\$1\033[0m"; }
cyan() { echo -e "\033[36m\$1\033[0m"; }

# Logging
log_info() { echo "[INFO] \$1"; }
log_success() { echo "\$(green "[SUCCESS]") \$1"; }
log_error() { echo "\$(red "[ERROR]") \$1"; }

echo "\$(cyan "==========================================")"
echo "\$(cyan "EMERGENCY DB SERVER RECOVERY")"
echo "\$(cyan "Samsung Cloud Platform v2")"
echo "\$(cyan "==========================================")"
echo ""

# Check if running as root
if [[ \$EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Please run: sudo bash emergency_db.sh"
    exit 1
fi

log_info "Starting emergency recovery for db server..."

# System Update
sys_update() {
    log_info "[1/4] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do 
        echo "Waiting for network connectivity..."
        sleep 10
    done
    
    for i in {1..3}; do 
        dnf clean all && dnf install -y epel-release && break
        sleep 30
    done
    
    dnf -y update || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    
    log_success "System updated with NTP"
}

# Repository Clone
repo_clone() {
    log_info "[2/4] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    log_success "Repository ready"
}

# Create master_config.json
create_master_config() {
    log_info "[3/4] Creating master_config.json..."
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
{"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"config_metadata":{"version":"4.0.0","created":"2025-08-26 08:47:44","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1","template_source":"variables.tf"},"user_input_variables":{"_comment":"Variables that users input interactively during deployment","_source":"variables.tf USER_INPUT category","object_storage_access_key_id":"put_the_value_if_you_use_object_storage_in_this_lab","public_domain_name":"creative-energy.net","object_storage_secret_access_key":"put_the_value_if_you_use_object_storage_in_this_lab","private_hosted_zone_id":"c9ff590c-ce1a-42ca-ae22-b6b8e94cf572","private_domain_name":"cesvc.net","object_storage_bucket_string":"put_the_value_if_you_use_object_storage_in_this_lab","user_public_ip":"182.215.17.173","keypair_name":"mykey"},"ceweb_required_variables":{"_comment":"Variables required by ceweb application for business logic and functionality","_source":"variables.tf CEWEB_REQUIRED category","_database_connection":{"database_password":"ceadmin123","db_ssl_enabled":false,"db_pool_min":20,"db_pool_max":100,"db_pool_idle_timeout":30000,"db_pool_connection_timeout":60000},"certificate_path":"/etc/ssl/certs/certificate.crt","nginx_port":"80","private_key_path":"/etc/ssl/private/private.key","rollback_enabled":"true","object_storage_public_endpoint":"https://object-store.kr-west1.e.samsungsdscloud.com","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","object_storage_media_folder":"media/img","db_max_connections":"100","admin_email":"ars4mundus@gmail.com","database_user":"ceadmin","ssl_enabled":"false","object_storage_region":"kr-west1","app_server_port":"3000","database_password":"ceadmin123!","auto_deployment":"true","database_name":"cedb","git_repository":"https://github.com/SCPv2/ceweb.git","object_storage_audition_folder":"files/audition","company_name":"Creative Energy","backup_retention_days":"30","object_storage_private_endpoint":"https://object-store.private.kr-west1.e.samsungsdscloud.com","db_type":"postgresql","git_branch":"main","session_secret":"your-secret-key-change-in-production","web_lb_service_ip":"10.1.1.100","object_storage_bucket_name":"ceweb","node_env":"production","database_host":"db.cesvc.net"}}
CONFIG_EOF
    
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    
    # Validate JSON
    if ! jq . /home/rocky/master_config.json >/dev/null; then
        log_error "Invalid JSON in master_config.json"
        exit 1
    fi
    
    log_success "master_config.json created and validated"
}

# Server-specific installation (from module)
# Database Server Application Install Module
app_install() {
    echo "[4/5] Database server install..."
    
    # Install PostgreSQL 16 repository
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dnf install -y postgresql16-server postgresql16 postgresql16-contrib
    
    # Initialize and start PostgreSQL
    /usr/pgsql-16/bin/postgresql-16-setup initdb
    systemctl start postgresql-16 && systemctl enable postgresql-16
    
    # Load master config
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "ceadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "ceadmin123!"' $MASTER_CONFIG)
    
    # Configure PostgreSQL
    PG_CONFIG="/var/lib/pgsql/16/data"
    cp $PG_CONFIG/postgresql.conf $PG_CONFIG/postgresql.conf.backup
    cp $PG_CONFIG/pg_hba.conf $PG_CONFIG/pg_hba.conf.backup
    
    # Update configuration
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONFIG/postgresql.conf
    sed -i "s/#port = 5432/port = $DB_PORT/" $PG_CONFIG/postgresql.conf
    sed -i "s/#max_connections = 100/max_connections = 100/" $PG_CONFIG/postgresql.conf
    
    # Allow remote connections
    echo "host all all 0.0.0.0/0 md5" >> $PG_CONFIG/pg_hba.conf
    
    # Restart PostgreSQL
    systemctl restart postgresql-16
    sleep 5
    
    # Verify port binding
    netstat -tlnp | grep ":$DB_PORT" || exit 1
    
    # Set up database and users
    sudo -u postgres PGPORT=$DB_PORT psql -c "ALTER USER postgres PASSWORD '$DB_PASSWORD';"
    sudo -u postgres PGPORT=$DB_PORT psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres PGPORT=$DB_PORT psql -c "ALTER USER $DB_USER CREATEDB;"
    sudo -u postgres PGPORT=$DB_PORT createdb -O $DB_USER $DB_NAME
    
    # Install schema if exists
    SCHEMA_FILE="/home/rocky/ceweb/db-server/vm_db/postgresql_vm_init_schema.sql"
    if [ -f "$SCHEMA_FILE" ]; then
        # Copy schema file to accessible location for postgres user
        cp "$SCHEMA_FILE" /tmp/postgresql_vm_init_schema.sql
        chmod 644 /tmp/postgresql_vm_init_schema.sql
        
        # Install schema using postgres user
        sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -f /tmp/postgresql_vm_init_schema.sql
        sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
        sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"
        
        # Clean up
        rm -f /tmp/postgresql_vm_init_schema.sql
    fi
    
    echo "✅ Database server installed"
}

# Database Server Verification Module
verify_install() {
    echo "[5/5] Database verification..."
    
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "ceadmin123!"' $MASTER_CONFIG)
    
    # Check PostgreSQL service
    systemctl is-active postgresql-16 || exit 1
    
    # Check port binding
    netstat -tlnp | grep ":$DB_PORT" || exit 1
    
    # Test database connection
    sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "SELECT version();" || exit 1
    
    # Show table count
    sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
    
    echo "✅ Database server verified"
}
# Main execution
main() {
    sys_update
    repo_clone
    create_master_config
    app_install
    verify_install
    
    echo ""
    log_success "🎉 EMERGENCY RECOVERY COMPLETED!"
    
    # Create ready indicator
    echo "$(date): Emergency recovery completed" > /home/rocky/${SERVER_TYPE^}_Emergency_Ready.log
    
    show_test_commands
}

# Show test commands for user verification
show_test_commands() {
    echo ""
    echo "$(cyan "==========================================")"
    echo "$(cyan "MANUAL TESTING COMMANDS")"
    echo "$(cyan "==========================================")"
    echo ""    echo "$(yellow "DATABASE SERVER TESTING:")"
    echo ""
    echo "1. Check PostgreSQL status:"
    echo "   systemctl status postgresql-16"
    echo ""
    echo "2. Check database port:"
    echo "   netstat -tlnp | grep :2866"
    echo ""
    echo "3. Test database connection:"
    echo "   sudo -u postgres psql -h localhost -p 2866 -d cedb -c 'SELECT version();'"
    echo ""
    echo "4. Check database users:"
    echo "   sudo -u postgres psql -c '\du'"
    echo ""
    echo "5. List databases:"
    echo "   sudo -u postgres psql -c '\l'"
    echo ""
    echo "6. Check tables in cedb:"
    echo "   sudo -u postgres psql -d cedb -c '\dt'"
    echo ""
    echo "7. View PostgreSQL configuration:"
    echo "   cat /var/lib/pgsql/16/data/postgresql.conf | grep -E '(listen_addresses|port)'"
    echo ""
    echo "8. Check connection permissions:"
    echo "   cat /var/lib/pgsql/16/data/pg_hba.conf"
    echo ""
    echo "9. Test with application credentials:"
    echo "   PGPASSWORD=ceadmin123 psql -h localhost -p 2866 -U ceadmin -d cedb -c 'SELECT now();'"
    echo ""
    echo "$(green "Emergency recovery script completed!")"
    echo "$(green "Use the commands above to verify the installation.")"
    echo ""
    echo "$(cyan "Log files:")"
    echo "  - Emergency recovery: /home/rocky/${SERVER_TYPE^}_Emergency_Ready.log"
    echo "  - Master config: /home/rocky/master_config.json"
    echo "  - Application logs: Check service-specific locations above"
    echo ""
}

# Define SERVER_TYPE for the script
SERVER_TYPE="db"

# Execute main function
main "$@"