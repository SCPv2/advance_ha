#!/bin/bash
# ==============================================================================
# Apply Read Replica to Application Routes
# Purpose: Update all route files to use read replica
# Execute from: /home/rocky/ on app server
# ==============================================================================

set -e

APP_DIR="/home/rocky/ceweb/app-server"
ROUTES_DIR="$APP_DIR/routes"

echo "=========================================="
echo "Apply Read Replica to Routes"
echo "=========================================="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Check if setup was completed
if [ ! -f "$APP_DIR/config/database-replicated.js" ]; then
    echo "❌ database-replicated.js not found!"
    echo "   Please run setup_replica.sh first"
    exit 1
fi

cd $APP_DIR

# Step 1: Backup route files
echo "[Step 1/4] Backing up route files..."
if [ ! -d "routes.backup" ]; then
    cp -r routes routes.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Routes backup created"
fi

# Step 2: Update orders.js
echo ""
echo "[Step 2/4] Updating orders.js..."
if [ -f "$ROUTES_DIR/orders.js" ]; then
    # Replace database import
    sed -i.bak "s|const pool = require('../config/database');|const pool = require('../config/database-replicated').pool;\nconst db = require('../config/database-replicated');|g" $ROUTES_DIR/orders.js
    echo "✅ orders.js updated"
else
    echo "⚠️ orders.js not found"
fi

# Step 3: Update other route files
echo ""
echo "[Step 3/4] Updating other route files..."

# List of route files to update
ROUTE_FILES=("audition.js" "objaudition.js" "objorders.js" "health.js")

for file in "${ROUTE_FILES[@]}"; do
    if [ -f "$ROUTES_DIR/$file" ]; then
        # Check if file uses database
        if grep -q "require('../config/database')" "$ROUTES_DIR/$file" 2>/dev/null; then
            sed -i.bak "s|const pool = require('../config/database');|const pool = require('../config/database-replicated').pool;\nconst db = require('../config/database-replicated');|g" $ROUTES_DIR/$file
            echo "✅ $file updated"
        else
            echo "⚠️ $file doesn't use database module"
        fi
    else
        echo "⚠️ $file not found"
    fi
done

# Step 4: Create enhanced health check endpoint
echo ""
echo "[Step 4/4] Creating enhanced health check with replica status..."
cat > $ROUTES_DIR/health-replica.js << 'EOF'
const express = require('express');
const router = express.Router();
const db = require('../config/database-replicated');
const os = require('os');
const fs = require('fs');
const path = require('path');

router.get('/health', async (req, res) => {
  try {
    // Check master database
    let masterStatus = 'disconnected';
    try {
      await db.masterPool.query('SELECT 1');
      masterStatus = 'connected';
    } catch (error) {
      masterStatus = 'error';
    }
    
    // Check replica database
    let replicaStatus = 'disconnected';
    if (db.isReplicaAvailable()) {
      try {
        await db.getReplicaPool().query('SELECT 1');
        replicaStatus = 'connected';
      } catch (error) {
        replicaStatus = 'error';
      }
    }
    
    // Get VM info if exists
    let vmInfo = {};
    const vmInfoPath = path.join(__dirname, '../vm-info.json');
    if (fs.existsSync(vmInfoPath)) {
      try {
        vmInfo = JSON.parse(fs.readFileSync(vmInfoPath, 'utf8'));
      } catch (error) {
        vmInfo = { error: 'Failed to read VM info' };
      }
    }
    
    // Prepare response
    const healthStatus = {
      success: true,
      message: 'Server is healthy',
      database: {
        master: masterStatus,
        replica: replicaStatus,
        replicaEnabled: db.isReplicaAvailable()
      },
      hostname: os.hostname(),
      ip: req.ip || req.connection.remoteAddress,
      vm_info: vmInfo,
      performance: {
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        node_version: process.version
      },
      timestamp: new Date().toISOString(),
      request_headers: {
        'x-forwarded-for': req.headers['x-forwarded-for'] || 'direct',
        'x-forwarded-host': req.headers['x-forwarded-host'] || os.hostname(),
        'user-agent': req.headers['user-agent']
      }
    };
    
    res.json(healthStatus);
  } catch (error) {
    console.error('Health check error:', error);
    res.status(500).json({
      success: false,
      message: 'Health check failed',
      error: error.message
    });
  }
});

// Detailed database stats endpoint
router.get('/health/database', async (req, res) => {
  try {
    const stats = {
      master: {
        status: 'unknown',
        connections: 0,
        idle: 0,
        waiting: 0
      },
      replica: {
        status: 'unknown',
        connections: 0,
        idle: 0,
        waiting: 0
      }
    };
    
    // Get master pool stats
    try {
      const masterPool = db.getMasterPool();
      stats.master = {
        status: 'connected',
        connections: masterPool.totalCount,
        idle: masterPool.idleCount,
        waiting: masterPool.waitingCount
      };
    } catch (error) {
      stats.master.status = 'error';
    }
    
    // Get replica pool stats
    if (db.isReplicaAvailable()) {
      try {
        const replicaPool = db.getReplicaPool();
        stats.replica = {
          status: 'connected',
          connections: replicaPool.totalCount,
          idle: replicaPool.idleCount,
          waiting: replicaPool.waitingCount
        };
      } catch (error) {
        stats.replica.status = 'error';
      }
    } else {
      stats.replica.status = 'disabled';
    }
    
    res.json({
      success: true,
      database_stats: stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to get database stats',
      error: error.message
    });
  }
});

module.exports = router;
EOF

echo "✅ Enhanced health check created"

echo ""
echo "=========================================="
echo "✅ Read Replica Applied to Routes!"
echo "=========================================="
echo ""
echo "Modified files:"
ls -la $ROUTES_DIR/*.bak 2>/dev/null | awk '{print "  - " $9}'
echo ""
echo "Next steps:"
echo "1. Test the application:"
echo "   curl http://localhost:3000/health"
echo ""
echo "2. Restart with PM2:"
echo "   pm2 restart creative-energy-api"
echo ""
echo "3. Monitor logs:"
echo "   pm2 logs creative-energy-api"
echo ""
echo "4. Check database stats:"
echo "   curl http://localhost:3000/health/database"
echo "=========================================="