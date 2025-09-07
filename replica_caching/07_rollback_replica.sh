#!/bin/bash
# ==============================================================================
# Rollback Read Replica Configuration
# Purpose: Revert to single database configuration if needed
# Execute from: /home/rocky/ on app server
# ==============================================================================

set -e

APP_DIR="/home/rocky/ceweb/app-server"
ROUTES_DIR="$APP_DIR/routes"

echo "=========================================="
echo "Read Replica Rollback Script"
echo "=========================================="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will revert to single database configuration"
echo ""
read -p "Are you sure you want to rollback? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

cd $APP_DIR

# Step 1: Check for backups
echo ""
echo "[Step 1/5] Checking for backup files..."

BACKUPS_FOUND=0

# Check for database.js backup
DB_BACKUP=$(ls -t config/database.js.backup.* 2>/dev/null | head -1)
if [ -n "$DB_BACKUP" ]; then
    echo "✅ Found database config backup: $DB_BACKUP"
    BACKUPS_FOUND=1
else
    echo "⚠️ No database.js backup found"
fi

# Check for .env backup
ENV_BACKUP=$(ls -t .env.backup.* 2>/dev/null | head -1)
if [ -n "$ENV_BACKUP" ]; then
    echo "✅ Found .env backup: $ENV_BACKUP"
    BACKUPS_FOUND=1
else
    echo "⚠️ No .env backup found"
fi

# Check for routes backup
ROUTES_BACKUP=$(ls -dt routes.backup.* 2>/dev/null | head -1)
if [ -n "$ROUTES_BACKUP" ]; then
    echo "✅ Found routes backup: $ROUTES_BACKUP"
    BACKUPS_FOUND=1
else
    echo "⚠️ No routes backup found"
fi

if [ $BACKUPS_FOUND -eq 0 ]; then
    echo ""
    echo "❌ No backup files found. Cannot perform safe rollback."
    echo "   Manual intervention required."
    exit 1
fi

# Step 2: Stop PM2 application
echo ""
echo "[Step 2/5] Stopping application..."
if pm2 list | grep -q "creative-energy-api"; then
    pm2 stop creative-energy-api
    echo "✅ Application stopped"
else
    echo "⚠️ Application not running"
fi

# Step 3: Restore configuration files
echo ""
echo "[Step 3/5] Restoring configuration files..."

# Restore database.js
if [ -n "$DB_BACKUP" ]; then
    cp "$DB_BACKUP" config/database.js
    echo "✅ Restored database.js"
fi

# Restore .env
if [ -n "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" .env
    echo "✅ Restored .env"
fi

# Step 4: Restore route files
echo ""
echo "[Step 4/5] Restoring route files..."

if [ -n "$ROUTES_BACKUP" ]; then
    # Remove current routes with backups
    rm -f routes/*.bak
    
    # Restore from backup
    cp -r "$ROUTES_BACKUP"/* routes/
    echo "✅ Restored route files"
else
    # Manual restoration if no backup directory
    echo "Manually reverting route files..."
    
    for file in routes/*.js; do
        if [ -f "$file.bak" ]; then
            mv "$file.bak" "$file"
            echo "  ✅ Restored $(basename $file)"
        fi
    done
fi

# Remove replica-specific files
if [ -f "routes/health-replica.js" ]; then
    rm -f routes/health-replica.js
    echo "✅ Removed health-replica.js"
fi

# Step 5: Clean up and restart
echo ""
echo "[Step 5/5] Cleaning up and restarting..."

# Remove database-replicated.js
if [ -f "config/database-replicated.js" ]; then
    mv config/database-replicated.js config/database-replicated.js.disabled
    echo "✅ Disabled database-replicated.js"
fi

# Remove cache-related files
echo "Removing cache-related files..."
[ -f "config/database-cached.js" ] && rm -f config/database-cached.js && echo "  ✅ Removed database-cached.js"
[ -f "config/redis.js" ] && rm -f config/redis.js && echo "  ✅ Removed redis.js"
[ -f "config/cachingService.js" ] && rm -f config/cachingService.js && echo "  ✅ Removed cachingService.js"
[ -f "routes/orders-cached.js" ] && rm -f routes/orders-cached.js && echo "  ✅ Removed orders-cached.js"
[ -f "routes/health-cached.js" ] && rm -f routes/health-cached.js && echo "  ✅ Removed health-cached.js"
[ -f "warm_cache.js" ] && rm -f warm_cache.js && echo "  ✅ Removed warm_cache.js"
[ -f "benchmark_cache.js" ] && rm -f benchmark_cache.js && echo "  ✅ Removed benchmark_cache.js"
[ -f "monitor_cache.sh" ] && rm -f monitor_cache.sh && echo "  ✅ Removed monitor_cache.sh"
[ -f "load_test_cache.sh" ] && rm -f load_test_cache.sh && echo "  ✅ Removed load_test_cache.sh"

# Restore server.js from cache backup if exists
if [ -f "server.js.backup.cache" ]; then
    mv server.js.backup.cache server.js
    echo "✅ Restored server.js from cache backup"
fi

# Optional: Remove Redis npm packages (uncomment if needed)
# echo "Removing Redis npm packages..."
# npm uninstall redis ioredis 2>/dev/null && echo "✅ Removed Redis packages"

# Test database connection
echo ""
echo "Testing database connection..."
cat > test_connection.js << 'EOF'
const pool = require('./config/database');

async function testConnection() {
  try {
    const result = await pool.query('SELECT NOW() as time, current_database() as db');
    console.log('✅ Database connection successful:', result.rows[0]);
    process.exit(0);
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    process.exit(1);
  }
}

testConnection();
EOF

node test_connection.js
rm -f test_connection.js

# Restart application
echo ""
echo "Restarting application..."
pm2 start creative-energy-api
echo "✅ Application restarted"

# Verify application status
echo ""
echo "Verifying application status..."
sleep 3
pm2 status creative-energy-api

# Test health endpoint
echo ""
echo "Testing health endpoint..."
curl -s http://localhost:3000/health | jq '.database' 2>/dev/null || echo "Health check response received"

echo ""
echo "=========================================="
echo "✅ Rollback Complete!"
echo "=========================================="
echo ""
echo "System has been reverted to:"
echo "- Single database configuration"
echo "- Original route files restored"
echo "- Application restarted"
echo ""
echo "Backup files preserved for reference:"
ls -la config/*.backup.* 2>/dev/null | tail -3
ls -la .env.backup.* 2>/dev/null | tail -1
echo ""
echo "Monitor application:"
echo "  pm2 logs creative-energy-api --lines 50"
echo "=========================================="