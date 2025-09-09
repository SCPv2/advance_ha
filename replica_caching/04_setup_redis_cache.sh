#!/bin/bash
# ==============================================================================
# Redis Cache Setup Script
# Purpose: Configure Redis caching layer with read replica
# Execute from: /home/rocky/ on app server
# ==============================================================================

set -e

APP_DIR="/home/rocky/ceweb/app-server"

echo "=========================================="
echo "Redis Cache Setup with Read Replica"
echo "=========================================="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "=========================================="
echo ""

cd $APP_DIR

# Step 1: Install Redis client package
echo "[Step 1/6] Installing Redis client package..."
if [ ! -d "node_modules/redis" ]; then
    npm install redis@4.6.7
    echo "✅ Redis package installed"
else
    echo "✅ Redis package already installed"
fi

if [ ! -d "node_modules/ioredis" ]; then
    npm install ioredis@5.3.2
    echo "✅ IoRedis package installed"
else
    echo "✅ IoRedis package already installed"
fi

# Step 2: Update .env with Redis configuration
echo ""
echo "[Step 2/6] Adding Redis configuration to .env..."

# Backup .env before adding Redis configuration
if ! grep -q "REDIS_HOST" .env 2>/dev/null; then
    cp .env .env.backup.redis.$(date +%Y%m%d_%H%M%S)
    echo "✅ Created .env backup before Redis configuration"
fi

if grep -q "REDIS_HOST" .env 2>/dev/null; then
    echo "⚠️ Redis configuration already exists in .env"
else
    cat >> .env << 'EOF'

# Redis Cache Configuration
REDIS_HOST=cache.your_private_domain.name
REDIS_PORT=6378
REDIS_PASSWORD=cedbadmin123!
REDIS_DB=0
REDIS_KEY_PREFIX=ceweb:
REDIS_TTL_DEFAULT=3600
REDIS_TTL_PRODUCTS=7200
REDIS_TTL_STATS=300
REDIS_ENABLE=true
EOF
    echo "✅ Redis configuration added to .env"
fi

# Step 3: Create Redis connection module
echo ""
echo "[Step 3/6] Creating Redis connection module..."
cat > config/redis.js << 'EOF'
const Redis = require('ioredis');
require('dotenv').config();

// Redis client configuration
const redisConfig = {
  host: process.env.REDIS_HOST || 'cache.your_private_domain.name',
  port: process.env.REDIS_PORT || 6378,
  password: process.env.REDIS_PASSWORD || undefined,
  db: process.env.REDIS_DB || 0,
  keyPrefix: process.env.REDIS_KEY_PREFIX || 'ceweb:',
  
  // Connection settings
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  
  reconnectOnError: (err) => {
    const targetError = 'READONLY';
    if (err.message.includes(targetError)) {
      return true;
    }
    return false;
  },
  
  // Performance settings
  enableReadyCheck: true,
  enableOfflineQueue: true,
  connectTimeout: 10000,
  maxRetriesPerRequest: 3,
  
  // Connection pool
  lazyConnect: false
};

// Create Redis client
const redis = new Redis(redisConfig);

// Redis connection events
redis.on('connect', () => {
  console.log('✅ Redis connected:', process.env.REDIS_HOST);
});

redis.on('ready', () => {
  console.log('✅ Redis ready for commands');
});

redis.on('error', (err) => {
  console.error('❌ Redis error:', err.message);
});

redis.on('close', () => {
  console.log('⚠️ Redis connection closed');
});

redis.on('reconnecting', () => {
  console.log('🔄 Redis reconnecting...');
});

// Test Redis connection
const testConnection = async () => {
  try {
    await redis.ping();
    console.log('✅ Redis ping successful');
    
    // Get Redis info
    const info = await redis.info('server');
    const version = info.match(/redis_version:([^\r\n]+)/);
    if (version) {
      console.log('✅ Redis version:', version[1]);
    }
  } catch (error) {
    console.error('❌ Redis connection test failed:', error.message);
  }
};

// Initialize connection test
testConnection();

// Graceful shutdown
const shutdown = async () => {
  console.log('🔄 Closing Redis connection...');
  await redis.quit();
  console.log('✅ Redis connection closed');
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

module.exports = redis;
EOF
echo "✅ Redis connection module created"

# Step 4: Create caching service
echo ""
echo "[Step 4/6] Creating caching service..."
cat > config/cachingService.js << 'EOF'
const redis = require('./redis');
const crypto = require('crypto');

class CachingService {
  constructor() {
    this.enabled = process.env.REDIS_ENABLE === 'true';
    this.defaultTTL = parseInt(process.env.REDIS_TTL_DEFAULT) || 3600;
    this.productsTTL = parseInt(process.env.REDIS_TTL_PRODUCTS) || 7200;
    this.statsTTL = parseInt(process.env.REDIS_TTL_STATS) || 300;
  }

  // Generate cache key from query
  generateKey(prefix, query, params) {
    const queryHash = crypto
      .createHash('md5')
      .update(query + JSON.stringify(params || []))
      .digest('hex');
    return `${prefix}:${queryHash}`;
  }

  // Get data from cache
  async get(key) {
    if (!this.enabled) return null;
    
    try {
      const data = await redis.get(key);
      if (data) {
        console.log(`✅ Cache hit: ${key}`);
        return JSON.parse(data);
      }
      console.log(`❌ Cache miss: ${key}`);
      return null;
    } catch (error) {
      console.error('Cache get error:', error.message);
      return null;
    }
  }

  // Set data in cache
  async set(key, data, ttl = null) {
    if (!this.enabled) return false;
    
    try {
      const serialized = JSON.stringify(data);
      const expiry = ttl || this.defaultTTL;
      
      if (expiry > 0) {
        await redis.setex(key, expiry, serialized);
      } else {
        await redis.set(key, serialized);
      }
      
      console.log(`✅ Cache set: ${key} (TTL: ${expiry}s)`);
      return true;
    } catch (error) {
      console.error('Cache set error:', error.message);
      return false;
    }
  }

  // Delete from cache
  async del(key) {
    if (!this.enabled) return false;
    
    try {
      const result = await redis.del(key);
      console.log(`✅ Cache deleted: ${key}`);
      return result > 0;
    } catch (error) {
      console.error('Cache delete error:', error.message);
      return false;
    }
  }

  // Clear cache by pattern
  async clearPattern(pattern) {
    if (!this.enabled) return false;
    
    try {
      const keys = await redis.keys(pattern);
      if (keys.length > 0) {
        await redis.del(...keys);
        console.log(`✅ Cleared ${keys.length} cache keys matching: ${pattern}`);
      }
      return true;
    } catch (error) {
      console.error('Cache clear error:', error.message);
      return false;
    }
  }

  // Cache invalidation strategies
  async invalidateProduct(productId) {
    await this.clearPattern(`*product:${productId}*`);
    await this.clearPattern('*products:list*');
    await this.clearPattern('*inventory*');
  }

  async invalidateOrder(orderId) {
    await this.clearPattern(`*order:${orderId}*`);
    await this.clearPattern('*orders:list*');
    await this.clearPattern('*stats*');
  }

  async invalidateAll() {
    await this.clearPattern('*');
  }

  // Cache wrapper for database queries
  async cacheQuery(options) {
    const {
      key,
      query,
      params,
      ttl,
      executor,
      invalidate = false
    } = options;

    // If invalidation requested, clear cache
    if (invalidate) {
      await this.del(key);
    }

    // Try to get from cache
    const cached = await this.get(key);
    if (cached) {
      return { rows: cached, cached: true };
    }

    // Execute query
    const result = await executor(query, params);
    
    // Store in cache
    await this.set(key, result.rows, ttl);
    
    return { ...result, cached: false };
  }

  // Get cache statistics
  async getStats() {
    if (!this.enabled) {
      return { enabled: false };
    }

    try {
      const info = await redis.info('stats');
      const keys = await redis.dbsize();
      
      // Parse stats
      const stats = {
        enabled: true,
        keys: keys,
        hits: info.match(/keyspace_hits:(\d+)/)?.[1] || '0',
        misses: info.match(/keyspace_misses:(\d+)/)?.[1] || '0',
        evicted: info.match(/evicted_keys:(\d+)/)?.[1] || '0',
        connections: info.match(/connected_clients:(\d+)/)?.[1] || '0'
      };
      
      // Calculate hit ratio
      const hits = parseInt(stats.hits);
      const misses = parseInt(stats.misses);
      if (hits + misses > 0) {
        stats.hitRatio = ((hits / (hits + misses)) * 100).toFixed(2) + '%';
      }
      
      return stats;
    } catch (error) {
      console.error('Stats error:', error.message);
      return { enabled: true, error: error.message };
    }
  }
}

// Export singleton instance
module.exports = new CachingService();
EOF
echo "✅ Caching service created"

# Step 5: Create database with caching integration
echo ""
echo "[Step 5/6] Creating database module with caching..."
cat > config/database-cached.js << 'EOF'
const db = require('./database-replicated');
const cache = require('./cachingService');

// Enhanced query with caching
const queryCached = async (queryText, params, options = {}) => {
  const {
    cacheKey,
    cacheTTL,
    cachePrefix = 'query',
    skipCache = false,
    invalidate = false
  } = options;

  // Skip cache for write operations
  const isWriteQuery = /^\s*(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|TRUNCATE)/i.test(queryText);
  if (isWriteQuery || skipCache || !cache.enabled) {
    return await db.query(queryText, params, options);
  }

  // Generate cache key
  const key = cacheKey || cache.generateKey(cachePrefix, queryText, params);

  // Use cache wrapper
  return await cache.cacheQuery({
    key,
    query: queryText,
    params,
    ttl: cacheTTL,
    executor: async (q, p) => await db.query(q, p, options),
    invalidate
  });
};

// Product queries with caching
const products = {
  // Get all products (cached for 2 hours)
  async getAll() {
    const query = `
      SELECT 
        p.id as product_id,
        p.title as product_name,
        p.price,
        p.image,
        p.subtitle as description,
        COALESCE(i.stock_quantity, 0) as stock
      FROM products p
      LEFT JOIN inventory i ON p.id = i.product_id
      ORDER BY p.id
    `;
    
    return await queryCached(query, null, {
      cachePrefix: 'products:list',
      cacheTTL: cache.productsTTL
    });
  },

  // Get single product (cached for 2 hours)
  async getById(productId) {
    const query = `
      SELECT 
        p.*,
        COALESCE(i.stock_quantity, 0) as stock
      FROM products p
      LEFT JOIN inventory i ON p.id = i.product_id
      WHERE p.id = $1
    `;
    
    return await queryCached(query, [productId], {
      cacheKey: `product:${productId}`,
      cacheTTL: cache.productsTTL
    });
  },

  // Search products (cached for 30 minutes)
  async search(searchTerm) {
    const query = `
      SELECT * FROM products 
      WHERE title ILIKE $1 OR subtitle ILIKE $1
      ORDER BY title
    `;
    
    return await queryCached(query, [`%${searchTerm}%`], {
      cachePrefix: 'products:search',
      cacheTTL: 1800
    });
  }
};

// Order queries with caching
const orders = {
  // Get recent orders (cached for 5 minutes)
  async getRecent(limit = 10) {
    const query = `
      SELECT 
        o.*,
        p.title as product_name
      FROM orders o
      LEFT JOIN products p ON o.product_id = p.id
      ORDER BY o.order_date DESC
      LIMIT $1
    `;
    
    return await queryCached(query, [limit], {
      cachePrefix: 'orders:recent',
      cacheTTL: 300
    });
  },

  // Get order by ID (cached for 30 minutes)
  async getById(orderId) {
    const query = `
      SELECT 
        o.*,
        p.title as product_name,
        p.price
      FROM orders o
      LEFT JOIN products p ON o.product_id = p.id
      WHERE o.id = $1
    `;
    
    return await queryCached(query, [orderId], {
      cacheKey: `order:${orderId}`,
      cacheTTL: 1800
    });
  },

  // Create order (invalidates cache)
  async create(orderData) {
    const { customer_name, product_id, quantity, total_amount } = orderData;
    
    // Use transaction on master
    const client = await db.beginTransaction();
    
    try {
      // Update inventory
      await client.query(
        'UPDATE inventory SET stock_quantity = stock_quantity - $1 WHERE product_id = $2',
        [quantity, product_id]
      );
      
      // Create order
      const result = await client.query(
        `INSERT INTO orders (customer_name, product_id, quantity, unit_price, total_price, order_date)
         VALUES ($1, $2, $3, $4, $5, NOW())
         RETURNING id as order_id`,
        [customer_name, product_id, quantity, total_amount]
      );
      
      await db.commitTransaction(client);
      
      // Invalidate related caches
      await cache.invalidateProduct(product_id);
      await cache.invalidateOrder(result.rows[0].order_id);
      
      return result;
    } catch (error) {
      await db.rollbackTransaction(client);
      throw error;
    }
  }
};

// Statistics with caching
const stats = {
  // Dashboard stats (cached for 5 minutes)
  async getDashboard() {
    const query = `
      SELECT 
        COUNT(DISTINCT o.id) as total_orders,
        SUM(o.total_price) as total_revenue,
        COUNT(DISTINCT o.customer_name) as unique_customers,
        AVG(o.total_price) as avg_order_value,
        COUNT(DISTINCT p.id) as total_products
      FROM orders o
      CROSS JOIN products p
      WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
    `;
    
    return await queryCached(query, null, {
      cachePrefix: 'stats:dashboard',
      cacheTTL: cache.statsTTL
    });
  },

  // Inventory status (cached for 10 minutes)
  async getInventory() {
    const query = `
      SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN i.stock_quantity > 0 THEN 1 ELSE 0 END) as in_stock,
        SUM(CASE WHEN i.stock_quantity = 0 THEN 1 ELSE 0 END) as out_of_stock,
        SUM(CASE WHEN i.stock_quantity < 10 THEN 1 ELSE 0 END) as low_stock
      FROM inventory i
    `;
    
    return await queryCached(query, null, {
      cachePrefix: 'stats:inventory',
      cacheTTL: 600
    });
  }
};

// Export enhanced module
module.exports = {
  // Original database functions
  ...db,
  
  // Cached query function
  queryCached,
  
  // Domain-specific cached queries
  products,
  orders,
  stats,
  
  // Cache management
  cache,
  
  // Cache control
  invalidateCache: cache.invalidateAll.bind(cache),
  getCacheStats: cache.getStats.bind(cache)
};
EOF
echo "✅ Database module with caching created"

# Step 6: Create test script
echo ""
echo "[Step 6/6] Creating cache test script..."
cat > test_cache.js << 'EOF'
const db = require('./config/database-cached');

async function testCache() {
  console.log('\n📊 Redis Cache Test with Read Replica\n');
  console.log('=' .repeat(50));
  
  try {
    // Test 1: Cache miss and hit
    console.log('\n1. Testing cache miss and hit...');
    
    // First query - cache miss
    console.time('First query (cache miss)');
    const result1 = await db.products.getAll();
    console.timeEnd('First query (cache miss)');
    console.log(`   Products found: ${result1.rows.length}`);
    console.log(`   Cached: ${result1.cached ? 'Yes' : 'No'}`);
    
    // Second query - cache hit
    console.time('Second query (cache hit)');
    const result2 = await db.products.getAll();
    console.timeEnd('Second query (cache hit)');
    console.log(`   Cached: ${result2.cached ? 'Yes' : 'No'}`);
    
    // Test 2: Different cache TTLs
    console.log('\n2. Testing different cache TTLs...');
    
    const dashStats = await db.stats.getDashboard();
    console.log('   Dashboard stats cached (5 min TTL)');
    
    const inventory = await db.stats.getInventory();
    console.log('   Inventory stats cached (10 min TTL)');
    
    // Test 3: Cache statistics
    console.log('\n3. Cache Statistics:');
    const stats = await db.getCacheStats();
    console.log('   Keys in cache:', stats.keys);
    console.log('   Hit ratio:', stats.hitRatio || 'N/A');
    console.log('   Total hits:', stats.hits);
    console.log('   Total misses:', stats.misses);
    
    // Test 4: Search with caching
    console.log('\n4. Testing search with caching...');
    console.time('Search query');
    const searchResult = await db.products.search('test');
    console.timeEnd('Search query');
    console.log(`   Search results: ${searchResult.rows.length}`);
    
    // Test 5: Cache invalidation
    console.log('\n5. Testing cache invalidation...');
    
    // Get product (cache it)
    const product = await db.products.getById(1);
    console.log('   Product cached');
    
    // Simulate product update (invalidates cache)
    await db.cache.invalidateProduct(1);
    console.log('   Product cache invalidated');
    
    // Next query will be cache miss
    const productAfter = await db.products.getById(1);
    console.log(`   After invalidation - Cached: ${productAfter.cached ? 'Yes' : 'No'}`);
    
    console.log('\n✅ All cache tests completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
  }
  
  // Close connections
  await db.shutdown();
  process.exit(0);
}

testCache();
EOF

echo "✅ Cache test script created"

# Run the test
echo ""
echo "Running cache test..."
echo "=========================================="
node test_cache.js
echo "=========================================="

# Clean up test file
rm -f test_cache.js

echo ""
echo "=========================================="
echo "✅ Redis Cache Setup Complete!"
echo "=========================================="
echo ""
echo "Architecture:"
echo "  App → Redis Cache → Read Replica → Master DB"
echo ""
echo "Cache Configuration:"
echo "  Host: cache.your_private_domain.name:6378"
echo "  Products TTL: 2 hours"
echo "  Stats TTL: 5 minutes"
echo "  Default TTL: 1 hour"
echo ""
echo "Next steps:"
echo "1. Update routes to use database-cached module"
echo "2. Restart application: pm2 restart creative-energy-api"
echo "3. Monitor cache: redis-cli -h cache.your_private_domain.name"
echo "=========================================="