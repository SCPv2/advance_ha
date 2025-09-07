#!/bin/bash
# ==============================================================================
# Redis Cache Performance Test
# Purpose: Benchmark caching layer with read replica
# Execute from: /home/rocky/ on app server
# ==============================================================================

set -e

APP_DIR="/home/rocky/ceweb/app-server"

echo "=========================================="
echo "Redis Cache Performance Test"
echo "=========================================="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "=========================================="
echo ""

cd $APP_DIR

# Step 1: Create performance benchmark script
echo "[Step 1/4] Creating performance benchmark script..."
cat > benchmark_cache.js << 'EOF'
const db = require('./config/database-cached');
const { performance } = require('perf_hooks');

class PerformanceTester {
  constructor() {
    this.results = {
      cache_tests: [],
      database_tests: [],
      comparison: {}
    };
  }

  async measureTime(name, fn) {
    const start = performance.now();
    const result = await fn();
    const end = performance.now();
    const duration = Math.round(end - start);
    
    console.log(`   ${name}: ${duration}ms`);
    return { duration, result };
  }

  async testCachePerformance() {
    console.log('\n📊 Cache Performance Benchmark\n');
    console.log('=' .repeat(60));

    try {
      // Test 1: Cold start (cache miss)
      console.log('\n1. Cold Start Performance (Cache Miss):');
      await db.cache.invalidateAll();
      
      const cold1 = await this.measureTime('Products query (cold)', 
        () => db.products.getAll());
      
      const cold2 = await this.measureTime('Dashboard stats (cold)', 
        () => db.stats.getDashboard());
      
      const cold3 = await this.measureTime('Inventory status (cold)', 
        () => db.stats.getInventory());
      
      this.results.cache_tests.push({
        type: 'cold_start',
        products: cold1.duration,
        dashboard: cold2.duration,
        inventory: cold3.duration
      });

      // Test 2: Warm cache (cache hit)
      console.log('\n2. Warm Cache Performance (Cache Hit):');
      
      const warm1 = await this.measureTime('Products query (warm)', 
        () => db.products.getAll());
      
      const warm2 = await this.measureTime('Dashboard stats (warm)', 
        () => db.stats.getDashboard());
      
      const warm3 = await this.measureTime('Inventory status (warm)', 
        () => db.stats.getInventory());
      
      this.results.cache_tests.push({
        type: 'warm_cache',
        products: warm1.duration,
        dashboard: warm2.duration,
        inventory: warm3.duration
      });

      // Test 3: Direct database queries (bypass cache)
      console.log('\n3. Direct Database Performance (No Cache):');
      
      const direct1 = await this.measureTime('Products query (direct)', 
        () => db.masterPool.query(`
          SELECT p.*, COALESCE(i.stock_quantity, 0) as stock
          FROM products p
          LEFT JOIN inventory i ON p.product_id = i.product_id
          ORDER BY p.product_id
        `));
      
      const direct2 = await this.measureTime('Dashboard stats (direct)', 
        () => db.masterPool.query(`
          SELECT 
            COUNT(DISTINCT o.order_id) as total_orders,
            SUM(o.total_amount) as total_revenue
          FROM orders o
          WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
        `));
      
      this.results.database_tests = {
        products_direct: direct1.duration,
        dashboard_direct: direct2.duration
      };

      // Test 4: Load test with multiple concurrent requests
      console.log('\n4. Concurrent Load Test:');
      
      const concurrentRequests = 10;
      const concurrentStart = performance.now();
      
      const promises = [];
      for (let i = 0; i < concurrentRequests; i++) {
        promises.push(db.products.getAll());
        promises.push(db.stats.getDashboard());
      }
      
      await Promise.all(promises);
      const concurrentEnd = performance.now();
      const concurrentDuration = Math.round(concurrentEnd - concurrentStart);
      
      console.log(`   ${concurrentRequests * 2} concurrent requests: ${concurrentDuration}ms`);
      console.log(`   Average per request: ${Math.round(concurrentDuration / (concurrentRequests * 2))}ms`);

      // Test 5: Cache invalidation impact
      console.log('\n5. Cache Invalidation Test:');
      
      // Prime cache
      await db.products.getAll();
      
      const invalidationStart = performance.now();
      await db.cache.invalidateAll();
      const invalidationTime = Math.round(performance.now() - invalidationStart);
      
      console.log(`   Cache invalidation time: ${invalidationTime}ms`);

      // Test 6: Different query patterns
      console.log('\n6. Query Pattern Performance:');
      
      // Simple select
      const simple = await this.measureTime('Simple SELECT', 
        () => db.queryCached('SELECT COUNT(*) FROM products', null, {
          cachePrefix: 'simple_count',
          cacheTTL: 300
        }));
      
      // Complex JOIN
      const complex = await this.measureTime('Complex JOIN', 
        () => db.queryCached(`
          SELECT p.product_name, COUNT(o.order_id) as order_count
          FROM products p
          LEFT JOIN orders o ON p.product_id = o.product_id
          GROUP BY p.product_id, p.product_name
          ORDER BY order_count DESC
        `, null, {
          cachePrefix: 'complex_join',
          cacheTTL: 600
        }));

      // Calculate performance improvements
      this.calculateImprovements();
      
      // Show final results
      this.showResults();

    } catch (error) {
      console.error('\n❌ Benchmark failed:', error.message);
      throw error;
    }
  }

  calculateImprovements() {
    const cold = this.results.cache_tests.find(t => t.type === 'cold_start');
    const warm = this.results.cache_tests.find(t => t.type === 'warm_cache');
    
    if (cold && warm) {
      this.results.comparison = {
        products_improvement: Math.round((cold.products - warm.products) / cold.products * 100),
        dashboard_improvement: Math.round((cold.dashboard - warm.dashboard) / cold.dashboard * 100),
        inventory_improvement: Math.round((cold.inventory - warm.inventory) / cold.inventory * 100),
        products_speedup: Math.round(cold.products / warm.products * 10) / 10,
        dashboard_speedup: Math.round(cold.dashboard / warm.dashboard * 10) / 10
      };
    }
  }

  showResults() {
    console.log('\n' + '=' .repeat(60));
    console.log('📊 PERFORMANCE BENCHMARK RESULTS');
    console.log('=' .repeat(60));
    
    const cold = this.results.cache_tests.find(t => t.type === 'cold_start');
    const warm = this.results.cache_tests.find(t => t.type === 'warm_cache');
    
    if (cold && warm) {
      console.log('\n🔥 Cache Performance Impact:');
      console.log(`   Products Query:`);
      console.log(`     Cold: ${cold.products}ms → Warm: ${warm.products}ms`);
      console.log(`     Improvement: ${this.results.comparison.products_improvement}%`);
      console.log(`     Speed-up: ${this.results.comparison.products_speedup}x faster`);
      
      console.log(`\n   Dashboard Stats:`);
      console.log(`     Cold: ${cold.dashboard}ms → Warm: ${warm.dashboard}ms`);
      console.log(`     Improvement: ${this.results.comparison.dashboard_improvement}%`);
      console.log(`     Speed-up: ${this.results.comparison.dashboard_speedup}x faster`);
      
      console.log(`\n   Inventory Status:`);
      console.log(`     Cold: ${cold.inventory}ms → Warm: ${warm.inventory}ms`);
      console.log(`     Improvement: ${this.results.comparison.inventory_improvement}%`);
    }
    
    // Cache efficiency
    console.log('\n💾 Cache Efficiency:');
    if (warm.products < 50) {
      console.log('   ✅ Excellent cache performance (<50ms)');
    } else if (warm.products < 100) {
      console.log('   ✅ Good cache performance (<100ms)');
    } else {
      console.log('   ⚠️ Cache performance could be improved');
    }
    
    console.log('\n🎯 Recommendations:');
    if (this.results.comparison.products_improvement > 70) {
      console.log('   ✅ Cache is highly effective for product queries');
    }
    if (this.results.comparison.dashboard_improvement > 50) {
      console.log('   ✅ Cache is effective for dashboard queries');
    }
    console.log('   💡 Consider increasing cache TTL for better performance');
    console.log('   💡 Monitor cache hit ratio in production');
    
    console.log('\n' + '=' .repeat(60));
  }

  async getCacheStats() {
    console.log('\n📈 Current Cache Statistics:');
    const stats = await db.getCacheStats();
    
    console.log(`   Enabled: ${stats.enabled}`);
    console.log(`   Keys in cache: ${stats.keys || 0}`);
    console.log(`   Hit ratio: ${stats.hitRatio || 'N/A'}`);
    console.log(`   Total hits: ${stats.hits || 0}`);
    console.log(`   Total misses: ${stats.misses || 0}`);
    console.log(`   Connected clients: ${stats.connections || 0}`);
  }
}

async function runBenchmark() {
  const tester = new PerformanceTester();
  
  try {
    await tester.getCacheStats();
    await tester.testCachePerformance();
    
    console.log('\n✅ Benchmark completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Benchmark failed:', error);
  }
  
  await db.shutdown();
  process.exit(0);
}

// Run the benchmark
runBenchmark();
EOF

echo "✅ Performance benchmark script created"

# Step 2: Create cache monitoring script
echo ""
echo "[Step 2/4] Creating cache monitoring script..."
cat > monitor_cache.sh << 'EOF'
#!/bin/bash
# Cache monitoring script

echo "🔍 Redis Cache Monitoring"
echo "========================"

# Check Redis connection
echo ""
echo "1. Redis Connection Status:"
if timeout 5 bash -c "</dev/tcp/cache.cesvc.net/6378" 2>/dev/null; then
    echo "   ✅ Redis server reachable"
else
    echo "   ❌ Redis server unreachable"
fi

# Check application cache stats
echo ""
echo "2. Application Cache Statistics:"
curl -s http://localhost:3000/api/cache/stats | jq '.cache_stats' 2>/dev/null || echo "   ⚠️ Cache stats endpoint not available"

# Check health with cache status
echo ""
echo "3. Health Check with Cache Status:"
curl -s http://localhost:3000/api/health | jq '.cache' 2>/dev/null || echo "   ⚠️ Health endpoint not available"

# Check performance metrics
echo ""
echo "4. Performance Metrics:"
curl -s http://localhost:3000/api/health/performance | jq '.performance.cache' 2>/dev/null || echo "   ⚠️ Performance endpoint not available"

# Show recent PM2 logs related to cache
echo ""
echo "5. Recent Cache Activity (PM2 logs):"
pm2 logs creative-energy-api --lines 20 --nostream 2>/dev/null | grep -i -E "(cache|redis)" | tail -5 || echo "   ⚠️ No recent cache activity in logs"

echo ""
echo "========================"
echo "Monitor script completed"
EOF

chmod +x monitor_cache.sh
echo "✅ Cache monitoring script created"

# Step 3: Create load testing script
echo ""
echo "[Step 3/4] Creating load testing script..."
cat > load_test_cache.sh << 'EOF'
#!/bin/bash
# Load testing for cache performance

echo "🚀 Cache Load Testing"
echo "===================="

# Function to run concurrent requests
run_load_test() {
    local endpoint=$1
    local concurrent=$2
    local total=$3
    local name=$4
    
    echo ""
    echo "Testing $name:"
    echo "  Endpoint: $endpoint"
    echo "  Concurrent: $concurrent"
    echo "  Total requests: $total"
    
    # Run ab (Apache Bench) if available
    if command -v ab >/dev/null 2>&1; then
        ab -n $total -c $concurrent -q http://localhost:3000$endpoint 2>/dev/null | grep -E "(Requests per second|Time per request|Failed requests)" || echo "  ⚠️ ab test failed"
    else
        echo "  ⚠️ Apache Bench (ab) not installed"
        
        # Alternative: Use curl in background
        echo "  Using curl for basic testing..."
        start_time=$(date +%s)
        
        for i in $(seq 1 $concurrent); do
            (
                for j in $(seq 1 $((total/concurrent))); do
                    curl -s $endpoint > /dev/null 2>&1
                done
            ) &
        done
        
        wait
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        rps=$(echo "scale=2; $total / $duration" | bc -l)
        
        echo "  ✅ Completed in ${duration}s"
        echo "  ✅ Rate: ${rps} requests/second"
    fi
}

# Test 1: Products endpoint (should be cached)
run_load_test "/api/orders/products" 5 50 "Products API (Cached)"

# Test 2: Dashboard stats (should be cached)
run_load_test "/api/orders/dashboard/stats" 3 30 "Dashboard Stats (Cached)"

# Test 3: Health check
run_load_test "/api/health" 2 20 "Health Check"

# Test 4: Cache stats
run_load_test "/api/cache/stats" 2 10 "Cache Statistics"

echo ""
echo "🎯 Load Test Summary:"
echo "   Check cache hit ratio after the tests:"
echo "   curl http://localhost:3000/api/cache/stats | jq '.cache_stats.hitRatio'"
echo ""
echo "===================="
EOF

chmod +x load_test_cache.sh
echo "✅ Load testing script created"

# Step 4: Run performance benchmark
echo ""
echo "[Step 4/4] Running performance benchmark..."
echo "=========================================="
node benchmark_cache.js
echo "=========================================="

# Clean up
rm -f benchmark_cache.js

echo ""
echo "=========================================="
echo "✅ Cache Performance Testing Complete!"
echo "=========================================="
echo ""
echo "Available monitoring tools:"
echo "  ./monitor_cache.sh      - Real-time cache monitoring"
echo "  ./load_test_cache.sh    - Load testing for cache"
echo ""
echo "API endpoints for testing:"
echo "  GET /api/cache/stats       - Cache statistics"
echo "  GET /api/health/performance - Performance metrics"
echo "  POST /api/cache/clear      - Clear cache (admin)"
echo ""
echo "Continuous monitoring:"
echo "  watch -n 5 './monitor_cache.sh'"
echo "=========================================="