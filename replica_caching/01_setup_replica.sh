#!/bin/bash
# ==============================================================================
# Read Replica Setup Script
# Purpose: Configure PostgreSQL read replica for load distribution
# Execute from: /home/rocky/ on app server
# ==============================================================================

set -e

APP_DIR="/home/rocky/ceweb/app-server"

echo "=========================================="
echo "PostgreSQL Read Replica Setup Script"
echo "=========================================="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Step 1: Check current directory and environment
echo "[Step 1/6] Checking environment..."
if [ ! -d "$APP_DIR" ]; then
    echo "❌ App directory not found: $APP_DIR"
    exit 1
fi

cd $APP_DIR
echo "✅ Working directory: $(pwd)"
echo "✅ User: $(whoami)"

# Step 2: Backup existing configuration
echo ""
echo "[Step 2/6] Backing up existing configuration..."
if [ -f config/database.js ]; then
    cp config/database.js config/database.js.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Database config backup created"
fi

if [ -f .env ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Environment file backup created"
fi

# Step 3: Create database-replicated.js
echo ""
echo "[Step 3/6] Creating database-replicated.js..."
cat > config/database-replicated.js << 'EOF'
const { Pool } = require('pg');
require('dotenv').config();

// Master DB Pool (Read-Write)
const masterPool = new Pool({
  host: process.env.DB_HOST || 'db.your_private_domain.name',
  port: process.env.DB_PORT || 2866,
  database: process.env.DB_NAME || 'cedb',
  user: process.env.DB_USER || 'cedbadmin',
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  
  min: parseInt(process.env.DB_POOL_MIN) || 2,
  max: parseInt(process.env.DB_POOL_MAX) || 10,
  idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE_TIMEOUT) || 30000,
  connectionTimeoutMillis: parseInt(process.env.DB_POOL_CONNECTION_TIMEOUT) || 5000,
  
  query_timeout: 60000,
  statement_timeout: 60000,
  allowExitOnIdle: true
});

// Replica DB Pool (Read-Only)
const replicaPool = new Pool({
  host: process.env.DB_REPLICA_HOST || 'replica.your_private_domain.name',
  port: process.env.DB_REPLICA_PORT || 2866,
  database: process.env.DB_NAME || 'cedb',
  user: process.env.DB_REPLICA_USER || process.env.DB_USER || 'cedbadmin',
  password: process.env.DB_REPLICA_PASSWORD || process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  
  min: parseInt(process.env.DB_REPLICA_POOL_MIN) || 5,
  max: parseInt(process.env.DB_REPLICA_POOL_MAX) || 20,
  idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE_TIMEOUT) || 30000,
  connectionTimeoutMillis: parseInt(process.env.DB_POOL_CONNECTION_TIMEOUT) || 5000,
  
  query_timeout: 60000,
  statement_timeout: 60000,
  allowExitOnIdle: true
});

// Track replica availability
let replicaAvailable = true;
let lastReplicaCheck = Date.now();
const REPLICA_CHECK_INTERVAL = 30000;

// Connection event handlers
masterPool.on('connect', () => {
  console.log('✅ Master DB connected:', process.env.DB_HOST);
});

masterPool.on('error', (err) => {
  console.error('❌ Master DB error:', err.message);
});

replicaPool.on('connect', () => {
  console.log('✅ Replica DB connected:', process.env.DB_REPLICA_HOST);
  replicaAvailable = true;
});

replicaPool.on('error', (err) => {
  console.error('❌ Replica DB error:', err.message);
  replicaAvailable = false;
});

// Test connections
const testConnections = async () => {
  try {
    const masterClient = await masterPool.connect();
    await masterClient.query('SELECT 1');
    console.log('✅ Master DB test successful');
    masterClient.release();
    
    try {
      const replicaClient = await replicaPool.connect();
      await replicaClient.query('SELECT 1');
      console.log('✅ Replica DB test successful');
      replicaClient.release();
      replicaAvailable = true;
    } catch (replicaError) {
      console.warn('⚠️ Replica DB unavailable, falling back to master');
      replicaAvailable = false;
    }
  } catch (error) {
    console.error('❌ Database connection test failed:', error.message);
  }
};

// Check replica health
const checkReplicaHealth = async () => {
  if (Date.now() - lastReplicaCheck < REPLICA_CHECK_INTERVAL) {
    return replicaAvailable;
  }
  
  lastReplicaCheck = Date.now();
  
  try {
    const client = await replicaPool.connect();
    await client.query('SELECT 1');
    client.release();
    
    if (!replicaAvailable) {
      console.log('✅ Replica DB recovered');
    }
    replicaAvailable = true;
  } catch (error) {
    if (replicaAvailable) {
      console.warn('⚠️ Replica DB became unavailable');
    }
    replicaAvailable = false;
  }
  
  return replicaAvailable;
};

// Query routing logic
const executeQuery = async (queryText, params, options = {}) => {
  const {
    forceWrite = false,
    preferReplica = true,
    isTransaction = false
  } = options;
  
  const isWriteQuery = forceWrite || 
    isTransaction ||
    /^\s*(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|TRUNCATE)/i.test(queryText);
  
  if (isWriteQuery) {
    return masterPool.query(queryText, params);
  } else {
    if (preferReplica && replicaAvailable) {
      try {
        await checkReplicaHealth();
        if (replicaAvailable) {
          return await replicaPool.query(queryText, params);
        }
      } catch (error) {
        console.warn('⚠️ Replica query failed, falling back to master:', error.message);
        replicaAvailable = false;
      }
    }
    return masterPool.query(queryText, params);
  }
};

// Transaction support
const beginTransaction = async () => {
  const client = await masterPool.connect();
  await client.query('BEGIN');
  return client;
};

const commitTransaction = async (client) => {
  await client.query('COMMIT');
  client.release();
};

const rollbackTransaction = async (client) => {
  await client.query('ROLLBACK');
  client.release();
};

// Utility functions
const getMasterPool = () => masterPool;
const getReplicaPool = () => replicaPool;
const isReplicaAvailable = () => replicaAvailable;

const shutdown = async () => {
  console.log('🔄 Closing database connections...');
  await Promise.all([
    masterPool.end(),
    replicaPool.end()
  ]);
  console.log('✅ Database connections closed');
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// Initialize
testConnections();

// For backward compatibility
const pool = masterPool;

module.exports = {
  query: executeQuery,
  pool,
  
  beginTransaction,
  commitTransaction,
  rollbackTransaction,
  
  masterPool,
  replicaPool,
  getMasterPool,
  getReplicaPool,
  isReplicaAvailable,
  
  testConnections,
  shutdown
};
EOF

echo "✅ database-replicated.js created successfully"

# Step 4: Update environment variables
echo ""
echo "[Step 4/6] Updating .env file with replica configuration..."

# Check if replica config already exists
if grep -q "DB_REPLICA_HOST" .env 2>/dev/null; then
    echo "⚠️ Replica configuration already exists in .env"
    echo "   Skipping .env update"
else
    cat >> .env << 'EOF'

# Read Replica Configuration
DB_REPLICA_HOST=replica.your_private_domain.name
DB_REPLICA_PORT=2866
DB_REPLICA_USER=cedbadmin
DB_REPLICA_PASSWORD=cedbadmin123!
DB_REPLICA_POOL_MIN=5
DB_REPLICA_POOL_MAX=20
EOF
    echo "✅ Replica configuration added to .env"
fi

# Step 5: Create test script
echo ""
echo "[Step 5/6] Creating test script..."
cat > test_replica.js << 'EOF'
const db = require('./config/database-replicated');

async function testReplica() {
  console.log('\n🔍 Testing Read Replica Configuration...\n');
  
  try {
    // Test master connection
    console.log('1. Testing Master DB connection...');
    const masterResult = await db.masterPool.query('SELECT NOW() as time, current_database() as db');
    console.log('   ✅ Master DB:', masterResult.rows[0]);
    
    // Test replica connection
    console.log('\n2. Testing Replica DB connection...');
    if (db.isReplicaAvailable()) {
      try {
        const replicaResult = await db.replicaPool.query('SELECT NOW() as time, current_database() as db');
        console.log('   ✅ Replica DB:', replicaResult.rows[0]);
      } catch (error) {
        console.log('   ⚠️ Replica not available:', error.message);
      }
    } else {
      console.log('   ⚠️ Replica marked as unavailable');
    }
    
    // Test query routing
    console.log('\n3. Testing query routing...');
    const readQuery = await db.query('SELECT COUNT(*) as count FROM products');
    console.log('   ✅ Read query executed, product count:', readQuery.rows[0].count);
    
    console.log('\n✅ All tests completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
  }
  
  // Close connections
  await db.shutdown();
  process.exit(0);
}

testReplica();
EOF

echo "✅ Test script created"

# Step 6: Run the test
echo ""
echo "[Step 6/6] Running connection test..."
echo "=========================================="
node test_replica.js
echo "=========================================="

# Clean up test file
rm -f test_replica.js

echo ""
echo "=========================================="
echo "✅ Read Replica Setup Complete!"
echo "=========================================="
echo ""
echo "Configuration Summary:"
echo "  Master DB: db.your_private_domain.name:2866"
echo "  Replica DB: replica.your_private_domain.name:2866"
echo "  Config file: $APP_DIR/config/database-replicated.js"
echo ""
echo "Next steps:"
echo "1. Update route files to use database-replicated module:"
echo "   Change: const pool = require('../config/database');"
echo "   To:     const db = require('../config/database-replicated');"
echo ""
echo "2. Restart application:"
echo "   pm2 restart creative-energy-api"
echo ""
echo "3. Monitor replica usage:"
echo "   pm2 logs creative-energy-api"
echo "=========================================="