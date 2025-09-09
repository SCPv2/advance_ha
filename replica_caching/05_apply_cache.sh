#!/bin/bash
# ==============================================================================
# Apply Redis Cache to Application Routes
# Purpose: Integrate caching layer with read replica
# Execute from: /home/rocky/ on app server
# ==============================================================================

set -e

APP_DIR="/home/rocky/ceweb/app-server"
ROUTES_DIR="$APP_DIR/routes"

echo "=========================================="
echo "Apply Redis Cache to Routes"
echo "=========================================="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "=========================================="
echo ""

cd $APP_DIR

# Check prerequisites
if [ ! -f "config/database-cached.js" ]; then
    echo "❌ database-cached.js not found!"
    echo "   Please run setup_redis_cache.sh first"
    exit 1
fi

# Step 1: Create cached version of orders route
echo "[Step 1/4] Creating cached orders route..."
cat > routes/orders-cached.js << 'EOF'
const express = require('express');
const router = express.Router();
const db = require('../config/database-cached');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// File upload configuration (same as original)
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, '../../files');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    const name = path.basename(file.originalname, ext);
    cb(null, `${name}_${uniqueSuffix}${ext}`);
  }
});

const upload = multer({ storage: storage });

// GET /products - Cached for 2 hours
router.get('/products', async (req, res) => {
  try {
    const result = await db.products.getAll();
    
    res.json({
      success: true,
      products: result.rows,
      cached: result.cached || false,
      message: result.cached ? 'Data from cache' : 'Data from database'
    });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch products',
      error: error.message
    });
  }
});

// GET /product/:id - Cached for 2 hours
router.get('/product/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.products.getById(id);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Product not found'
      });
    }
    
    res.json({
      success: true,
      product: result.rows[0],
      cached: result.cached || false
    });
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch product',
      error: error.message
    });
  }
});

// GET /search - Cached for 30 minutes
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query;
    
    if (!q) {
      return res.status(400).json({
        success: false,
        message: 'Search query required'
      });
    }
    
    const result = await db.products.search(q);
    
    res.json({
      success: true,
      results: result.rows,
      cached: result.cached || false,
      query: q
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({
      success: false,
      message: 'Search failed',
      error: error.message
    });
  }
});

// GET /orders - Recent orders cached for 5 minutes
router.get('/orders', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const result = await db.orders.getRecent(limit);
    
    res.json({
      success: true,
      orders: result.rows,
      cached: result.cached || false
    });
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch orders',
      error: error.message
    });
  }
});

// GET /order/:id - Cached for 30 minutes
router.get('/order/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.orders.getById(id);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    
    res.json({
      success: true,
      order: result.rows[0],
      cached: result.cached || false
    });
  } catch (error) {
    console.error('Error fetching order:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch order',
      error: error.message
    });
  }
});

// POST /orders - Create order (invalidates cache)
router.post('/orders', async (req, res) => {
  try {
    const result = await db.orders.create(req.body);
    
    res.json({
      success: true,
      message: 'Order created successfully',
      order_id: result.rows[0].order_id,
      cache_invalidated: true
    });
  } catch (error) {
    console.error('Error creating order:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create order',
      error: error.message
    });
  }
});

// GET /dashboard/stats - Cached for 5 minutes
router.get('/dashboard/stats', async (req, res) => {
  try {
    const result = await db.stats.getDashboard();
    
    res.json({
      success: true,
      stats: result.rows[0],
      cached: result.cached || false,
      cache_ttl: '5 minutes'
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch statistics',
      error: error.message
    });
  }
});

// GET /inventory/status - Cached for 10 minutes
router.get('/inventory/status', async (req, res) => {
  try {
    const result = await db.stats.getInventory();
    
    res.json({
      success: true,
      inventory: result.rows[0],
      cached: result.cached || false,
      cache_ttl: '10 minutes'
    });
  } catch (error) {
    console.error('Error fetching inventory:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch inventory status',
      error: error.message
    });
  }
});

// DELETE /product/:id - Delete product (invalidates cache)
router.delete('/product/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Check if product has orders
    const orderCheck = await db.queryCached(
      'SELECT COUNT(*) as count FROM orders WHERE product_id = $1',
      [id],
      { skipCache: true }
    );
    
    if (orderCheck.rows[0].count > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete product with existing orders'
      });
    }
    
    // Delete product
    await db.query('DELETE FROM inventory WHERE product_id = $1', [id]);
    await db.query('DELETE FROM products WHERE product_id = $1', [id]);
    
    // Invalidate cache
    await db.cache.invalidateProduct(id);
    
    res.json({
      success: true,
      message: 'Product deleted successfully',
      cache_invalidated: true
    });
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete product',
      error: error.message
    });
  }
});

// Admin endpoints for cache management
router.get('/cache/stats', async (req, res) => {
  try {
    const stats = await db.getCacheStats();
    
    res.json({
      success: true,
      cache_stats: stats
    });
  } catch (error) {
    console.error('Error fetching cache stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch cache statistics',
      error: error.message
    });
  }
});

router.post('/cache/clear', async (req, res) => {
  try {
    const { pattern } = req.body;
    
    if (pattern) {
      await db.cache.clearPattern(pattern);
      res.json({
        success: true,
        message: `Cache cleared for pattern: ${pattern}`
      });
    } else {
      await db.invalidateCache();
      res.json({
        success: true,
        message: 'All cache cleared'
      });
    }
  } catch (error) {
    console.error('Error clearing cache:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to clear cache',
      error: error.message
    });
  }
});

module.exports = router;
EOF
echo "✅ Cached orders route created"

# Step 2: Create health check with cache status
echo ""
echo "[Step 2/4] Creating health check with cache status..."
cat > routes/health-cached.js << 'EOF'
const express = require('express');
const router = express.Router();
const db = require('../config/database-cached');
const os = require('os');

router.get('/health', async (req, res) => {
  try {
    // Database status
    let masterStatus = 'disconnected';
    let replicaStatus = 'disconnected';
    
    try {
      await db.masterPool.query('SELECT 1');
      masterStatus = 'connected';
    } catch (error) {
      masterStatus = 'error';
    }
    
    if (db.isReplicaAvailable()) {
      try {
        await db.getReplicaPool().query('SELECT 1');
        replicaStatus = 'connected';
      } catch (error) {
        replicaStatus = 'error';
      }
    }
    
    // Cache status
    const cacheStats = await db.getCacheStats();
    
    const healthStatus = {
      success: true,
      message: 'Server is healthy',
      database: {
        master: masterStatus,
        replica: replicaStatus,
        replicaEnabled: db.isReplicaAvailable()
      },
      cache: {
        enabled: cacheStats.enabled,
        connected: cacheStats.enabled && !cacheStats.error,
        keys: cacheStats.keys || 0,
        hitRatio: cacheStats.hitRatio || 'N/A',
        host: process.env.REDIS_HOST || 'cache.your_private_domain.name'
      },
      architecture: {
        layers: ['Redis Cache', 'Read Replica', 'Master DB'],
        caching_ttl: {
          products: '2 hours',
          stats: '5 minutes',
          default: '1 hour'
        }
      },
      hostname: os.hostname(),
      timestamp: new Date().toISOString()
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

// Detailed performance metrics
router.get('/health/performance', async (req, res) => {
  try {
    const cacheStats = await db.getCacheStats();
    
    // Run sample queries to test performance
    const tests = [];
    
    // Test 1: Cached query
    const cacheStart = Date.now();
    await db.products.getAll();
    const cacheTime1 = Date.now() - cacheStart;
    
    // Test 2: Should be from cache
    const cacheStart2 = Date.now();
    const cached = await db.products.getAll();
    const cacheTime2 = Date.now() - cacheStart2;
    
    // Test 3: Direct database query
    const dbStart = Date.now();
    await db.masterPool.query('SELECT * FROM products LIMIT 1');
    const dbTime = Date.now() - dbStart;
    
    res.json({
      success: true,
      performance: {
        cache: {
          first_query_ms: cacheTime1,
          cached_query_ms: cacheTime2,
          improvement: `${Math.round((cacheTime1 - cacheTime2) / cacheTime1 * 100)}%`,
          hit_ratio: cacheStats.hitRatio
        },
        database: {
          direct_query_ms: dbTime
        },
        summary: {
          cache_faster_by: `${Math.round(dbTime / cacheTime2)}x`,
          total_cache_keys: cacheStats.keys,
          cache_hits: cacheStats.hits,
          cache_misses: cacheStats.misses
        }
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Performance check failed',
      error: error.message
    });
  }
});

module.exports = router;
EOF
echo "✅ Health check with cache status created"

# Step 3: Update server.js to use cached routes
echo ""
echo "[Step 3/4] Creating server configuration for cached routes..."

# Backup server.js before modification
if [ ! -f "server.js.backup.cache" ]; then
    cp server.js server.js.backup.cache
    echo "✅ Created server.js backup"
fi

cat > update_server.js << 'EOF'
const fs = require('fs');
const path = require('path');

// Read current server.js
const serverPath = path.join(__dirname, 'server.js');
let serverContent = fs.readFileSync(serverPath, 'utf8');

// Check if already using cached routes
if (serverContent.includes('orders-cached')) {
  console.log('✅ Server already configured for cached routes');
  process.exit(0);
}

// Add comment about caching
const cacheComment = `
// Redis caching with read replica enabled
// Using cached routes for improved performance
`;

// Replace route imports (handle both naming conventions)
serverContent = serverContent.replace(
  "const ordersRouter = require('./routes/orders');",
  "const ordersRouter = require('./routes/orders-cached'); // Using cached version"
);
serverContent = serverContent.replace(
  "const ordersRoutes = require('./routes/orders');",
  "const ordersRoutes = require('./routes/orders-cached'); // Using cached version"
);

serverContent = serverContent.replace(
  "const healthRouter = require('./routes/health');",
  "const healthRouter = require('./routes/health-cached'); // Using cached version"
);

// If health router doesn't exist, add it
if (!serverContent.includes('healthRouter')) {
  serverContent = serverContent.replace(
    "app.use('/api/orders', ordersRouter);",
    `app.use('/api/orders', ordersRouter);
app.use('/api', require('./routes/health-cached'));`
  );
}

// Write updated server.js
fs.writeFileSync(serverPath, serverContent);
console.log('✅ Server.js updated to use cached routes');
EOF

node update_server.js
rm -f update_server.js
echo "✅ Server configuration updated"

# Step 4: Create cache warming script
echo ""
echo "[Step 4/4] Creating cache warming script..."
cat > warm_cache.js << 'EOF'
const db = require('./config/database-cached');

async function warmCache() {
  console.log('\n🔥 Warming up cache...\n');
  
  try {
    // Warm product cache
    console.log('1. Loading products into cache...');
    const products = await db.products.getAll();
    console.log(`   ✅ ${products.rows.length} products cached`);
    
    // Warm dashboard stats
    console.log('2. Loading dashboard stats...');
    await db.stats.getDashboard();
    console.log('   ✅ Dashboard stats cached');
    
    // Warm inventory stats
    console.log('3. Loading inventory status...');
    await db.stats.getInventory();
    console.log('   ✅ Inventory status cached');
    
    // Warm recent orders
    console.log('4. Loading recent orders...');
    const orders = await db.orders.getRecent(20);
    console.log(`   ✅ ${orders.rows.length} recent orders cached`);
    
    // Show cache stats
    console.log('\n📊 Cache Statistics:');
    const stats = await db.getCacheStats();
    console.log(`   Keys in cache: ${stats.keys}`);
    console.log(`   Cache enabled: ${stats.enabled}`);
    
    console.log('\n✅ Cache warming complete!');
    
  } catch (error) {
    console.error('❌ Cache warming failed:', error.message);
  }
  
  await db.shutdown();
  process.exit(0);
}

// Run cache warming
warmCache();
EOF

echo "✅ Cache warming script created"

echo ""
echo "=========================================="
echo "✅ Redis Cache Applied to Routes!"
echo "=========================================="
echo ""
echo "Created files:"
echo "  - routes/orders-cached.js (main route with caching)"
echo "  - routes/health-cached.js (health check with cache)"
echo "  - warm_cache.js (cache warming script)"
echo ""
echo "Cache endpoints:"
echo "  GET /api/cache/stats - View cache statistics"
echo "  POST /api/cache/clear - Clear cache"
echo "  GET /api/health/performance - Performance metrics"
echo ""
echo "Next steps:"
echo "1. Warm the cache:"
echo "   node warm_cache.js"
echo ""
echo "2. Restart application:"
echo "   pm2 restart creative-energy-api"
echo ""
echo "3. Test cached endpoints:"
echo "   curl http://localhost:3000/api/orders/products"
echo "   curl http://localhost:3000/api/cache/stats"
echo ""
echo "4. Monitor performance:"
echo "   curl http://localhost:3000/api/health/performance"
echo "=========================================="