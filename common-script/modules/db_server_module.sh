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
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "cedbadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
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
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
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