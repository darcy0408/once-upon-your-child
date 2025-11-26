# Grok - Week 4 Tasks (Final Backend Polish & Launch Prep)

**Assigned to**: Grok
**Priority**: HIGH - Production infrastructure finalization
**Timeline**: Week 4 (Nov 26 - Dec 3)
**Status**: Weeks 2-3 Complete ✅ (All infrastructure, analytics, monitoring)

---

## 📊 Current Status

### ✅ Weeks 2-3 Completed
- GR1-GR6: Complete backend infrastructure
- GR3.1-GR3.4: Progressive unlocks, analytics, quality scoring, monitoring
- All monitoring and logging systems operational
- Stripe initialization fix deployed

### 📋 Week 4 Focus
Production hardening, API optimization, and deployment automation

---

## Task GR4.1: API Rate Limiting Enhancement (Priority: HIGH)

**Objective**: Protect against abuse and ensure fair usage.

### Current State
- Basic rate limiting in place (10/min story generation, 5/min interactive)
- IP-based limiting

### Enhancements Needed

1. **Add User-Based Rate Limiting**
   ```python
   # backend/app.py

   from flask_limiter import Limiter
   from flask_limiter.util import get_remote_address

   def get_user_identifier():
       """Get user ID from request or fall back to IP"""
       # Try to get user ID from session/token
       user_id = session.get('user_id') or request.headers.get('X-User-ID')
       if user_id:
           return f"user:{user_id}"
       return f"ip:{get_remote_address()}"

   limiter = Limiter(
       app,
       key_func=get_user_identifier,
       storage_uri="memory://"
   )

   # Different limits for different tiers
   @app.route('/generate-story', methods=['POST'])
   @limiter.limit("3/minute; 10/hour", key_func=lambda: get_user_tier_key('free'))
   @limiter.limit("10/minute; 100/hour", key_func=lambda: get_user_tier_key('premium'))
   def generate_story():
       pass
   ```

2. **Add Tier-Specific Limits**
   - Free: 3/min, 10/hour, 50/day
   - Premium: 10/min, 100/hour, unlimited/day
   - Family: 15/min, 200/hour, unlimited/day
   - BYOK: No limits

3. **Add Cost Protection**
   ```python
   # Protect against expensive API calls

   @app.route('/generate-illustrations', methods=['POST'])
   @limiter.limit("2/minute; 10/hour")
   def generate_illustrations():
       # Extra protection for image generation (expensive)
       pass
   ```

4. **Add Rate Limit Headers**
   ```python
   # Return rate limit info in response headers

   @app.after_request
   def add_rate_limit_headers(response):
       # Add X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
       return response
   ```

### Testing:
- [ ] Free tier limits enforced correctly
- [ ] Premium tier gets higher limits
- [ ] BYOK users bypass limits
- [ ] Rate limit headers accurate
- [ ] Abuse scenarios blocked

---

## Task GR4.2: Database Optimization & Indexing (Priority: HIGH)

**Objective**: Improve query performance for analytics and user data.

### Implementation Steps:

1. **Add Indexes for Common Queries**
   ```sql
   -- Add indexes to improve analytics performance

   CREATE INDEX idx_stories_created_at ON stories(created_at DESC);
   CREATE INDEX idx_stories_user_id ON stories(user_id);
   CREATE INDEX idx_users_created_at ON users(created_at);
   CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
   CREATE INDEX idx_subscriptions_status ON subscriptions(status);

   -- Composite indexes for common filters
   CREATE INDEX idx_stories_user_created ON stories(user_id, created_at DESC);
   CREATE INDEX idx_users_tier_created ON users(subscription_tier, created_at);
   ```

2. **Optimize Slow Queries**
   ```python
   # backend/analytics_routes.py

   # BEFORE (slow - full table scan)
   stories = Story.query.all()
   premium_users = [s for s in stories if s.user.tier == 'premium']

   # AFTER (fast - indexed query)
   premium_stories = Story.query.join(User).filter(
       User.subscription_tier == 'premium'
   ).all()
   ```

3. **Add Query Pagination**
   ```python
   # Prevent loading entire tables into memory

   @analytics_bp.route('/stories')
   def get_stories():
       page = request.args.get('page', 1, type=int)
       per_page = request.args.get('per_page', 50, type=int)

       stories = Story.query.order_by(Story.created_at.desc()).paginate(
           page=page,
           per_page=per_page,
           error_out=False
       )

       return jsonify({
           'items': [s.to_dict() for s in stories.items],
           'total': stories.total,
           'page': page,
           'pages': stories.pages,
       })
   ```

4. **Add Database Connection Pooling Tuning**
   ```python
   # backend/app.py

   app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
       'pool_size': 10,              # Number of connections to keep open
       'pool_recycle': 3600,          # Recycle connections after 1 hour
       'pool_pre_ping': True,         # Check connection health before use
       'max_overflow': 20,            # Allow 20 extra connections if needed
   }
   ```

### Testing:
- [ ] Indexes created successfully
- [ ] Analytics queries <500ms
- [ ] Pagination works correctly
- [ ] Connection pool stable under load

---

## Task GR4.3: Automated Deployment Pipeline (Priority: MEDIUM)

**Objective**: Streamline deployment process with automated checks.

### Implementation Steps:

1. **Add Pre-Deployment Checks Script**
   ```bash
   # scripts/pre-deploy-checks.sh (NEW)

   #!/bin/bash
   set -e

   echo "🔍 Running pre-deployment checks..."

   # Check 1: Backend tests pass
   echo "✓ Running backend tests..."
   cd backend
   python -m pytest tests/ -v
   cd ..

   # Check 2: Flutter tests pass
   echo "✓ Running Flutter tests..."
   flutter test

   # Check 3: Backend starts without errors
   echo "✓ Testing backend startup..."
   cd backend
   timeout 10 python app.py &
   sleep 5
   kill %1 || true
   cd ..

   # Check 4: Flutter build succeeds
   echo "✓ Testing Flutter web build..."
   flutter build web --release

   # Check 5: No secrets in code
   echo "✓ Checking for exposed secrets..."
   ! grep -r "sk_live_" lib/ backend/ || (echo "ERROR: Stripe live key found in code!" && exit 1)
   ! grep -r "AIza" lib/ backend/ || (echo "WARNING: API key found in code (verify it's example only)")

   echo "✅ All pre-deployment checks passed!"
   ```

2. **Add Deployment Script**
   ```bash
   # scripts/deploy.sh (NEW)

   #!/bin/bash
   set -e

   echo "🚀 Starting deployment to Railway..."

   # Run pre-deployment checks
   ./scripts/pre-deploy-checks.sh

   # Commit changes
   echo "📝 Committing changes..."
   git add .
   git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"

   # Push to main (triggers Railway deployment)
   echo "📤 Pushing to GitHub..."
   git push origin main

   # Wait for deployment
   echo "⏳ Waiting for Railway deployment..."
   sleep 30

   # Health check
   echo "🏥 Checking backend health..."
   curl -f https://story-weaver-app-production.up.railway.app/health || (echo "ERROR: Health check failed!" && exit 1)

   echo "✅ Deployment complete!"
   ```

3. **Add Rollback Script**
   ```bash
   # scripts/rollback.sh (NEW)

   #!/bin/bash
   set -e

   echo "⚠️  ROLLBACK: Reverting to previous deployment..."

   # Get last good commit
   LAST_COMMIT=$(git log --oneline -2 | tail -1 | cut -d' ' -f1)

   echo "Rolling back to commit: $LAST_COMMIT"

   # Reset to previous commit
   git reset --hard $LAST_COMMIT

   # Force push (triggers Railway deployment)
   git push origin main --force

   echo "✅ Rollback complete!"
   echo "⚠️  Remember to fix the issue before next deployment"
   ```

### Testing:
- [ ] Pre-deployment checks catch errors
- [ ] Deployment script works end-to-end
- [ ] Rollback script reverts successfully
- [ ] Health checks verify deployment

---

## Task GR4.4: Cost Monitoring & Alerts (Priority: MEDIUM)

**Objective**: Track and alert on API costs to prevent surprise bills.

### Implementation Steps:

1. **Add Cost Tracking**
   ```python
   # backend/services/cost_tracking.py (NEW)

   class CostTracker:
       # Approximate costs (update based on actual pricing)
       COSTS = {
           'story_generation': 0.002,      # ~$0.002 per story
           'illustration': 0.01,           # ~$0.01 per image
           'interactive_choice': 0.001,    # ~$0.001 per choice
       }

       @staticmethod
       def track_cost(operation: str, user_id: str, user_tier: str):
           """Track API costs by operation"""

           # Don't track BYOK users (they pay directly)
           if user_tier == 'byok':
               return

           cost = CostTracker.COSTS.get(operation, 0)

           # Log to database for analytics
           db.session.add(CostEvent(
               user_id=user_id,
               operation=operation,
               cost=cost,
               tier=user_tier,
               created_at=datetime.utcnow()
           ))
           db.session.commit()

           # Check if daily budget exceeded
           daily_total = CostTracker.get_daily_total()
           if daily_total > DAILY_BUDGET_LIMIT:
               CostTracker.send_alert(f"Daily API cost exceeded: ${daily_total:.2f}")
   ```

2. **Add Cost Analytics Endpoint**
   ```python
   # backend/analytics_routes.py

   @analytics_bp.route('/admin/analytics/costs')
   def get_cost_analytics():
       """Get API cost breakdown"""

       today = datetime.utcnow().date()
       week_ago = today - timedelta(days=7)

       costs = db.session.query(
           func.date(CostEvent.created_at).label('date'),
           CostEvent.operation,
           func.sum(CostEvent.cost).label('total_cost'),
           func.count(CostEvent.id).label('count')
       ).filter(
           CostEvent.created_at >= week_ago
       ).group_by(
           func.date(CostEvent.created_at),
           CostEvent.operation
       ).all()

       return jsonify({
           'daily_costs': [
               {
                   'date': c.date.isoformat(),
                   'operation': c.operation,
                   'cost': float(c.total_cost),
                   'count': c.count
               }
               for c in costs
           ],
           'total_week': sum(c.total_cost for c in costs)
       })
   ```

3. **Add Budget Alerts**
   - Daily budget alert at $10
   - Weekly budget alert at $50
   - Per-operation anomaly detection

### Testing:
- [ ] Costs tracked for all operations
- [ ] BYOK users not tracked
- [ ] Analytics endpoint accurate
- [ ] Alerts fire at thresholds

---

## Task GR4.5: Production Monitoring Dashboard (Priority: LOW)

**Objective**: Create simple dashboard for monitoring production health.

### Implementation Steps:

1. **Add Metrics Endpoint**
   ```python
   # backend/app.py

   @app.route('/admin/metrics')
   def get_metrics():
       """Get real-time system metrics"""

       return jsonify({
           'timestamp': datetime.utcnow().isoformat(),
           'uptime_seconds': time.time() - app.start_time,
           'requests_per_minute': get_rpm(),
           'average_response_time_ms': get_avg_response_time(),
           'error_rate_percent': get_error_rate(),
           'active_users': get_active_user_count(),
           'database_connections': db.engine.pool.size(),
           'cache_hit_rate': get_cache_hit_rate(),
       })
   ```

2. **Create Simple HTML Dashboard**
   ```html
   <!-- backend/templates/dashboard.html (NEW) -->

   <!DOCTYPE html>
   <html>
   <head>
       <title>Story Weaver - Production Dashboard</title>
       <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
   </head>
   <body>
       <h1>Story Weaver Production Dashboard</h1>

       <div id="metrics">
           <div class="metric">
               <h3>Uptime</h3>
               <p id="uptime">Loading...</p>
           </div>
           <div class="metric">
               <h3>Requests/Min</h3>
               <p id="rpm">Loading...</p>
           </div>
           <div class="metric">
               <h3>Error Rate</h3>
               <p id="error-rate">Loading...</p>
           </div>
           <div class="metric">
               <h3>Active Users</h3>
               <p id="active-users">Loading...</p>
           </div>
       </div>

       <script>
           // Auto-refresh every 10 seconds
           setInterval(updateDashboard, 10000);
           updateDashboard();

           function updateDashboard() {
               fetch('/admin/metrics')
                   .then(r => r.json())
                   .then(data => {
                       document.getElementById('uptime').textContent =
                           Math.floor(data.uptime_seconds / 3600) + ' hours';
                       document.getElementById('rpm').textContent =
                           data.requests_per_minute;
                       document.getElementById('error-rate').textContent =
                           data.error_rate_percent.toFixed(2) + '%';
                       document.getElementById('active-users').textContent =
                           data.active_users;
                   });
           }
       </script>
   </body>
   </html>
   ```

### Testing:
- [ ] Metrics endpoint returns accurate data
- [ ] Dashboard refreshes automatically
- [ ] All metrics display correctly

---

## Priority Order

1. **GR4.1**: API Rate Limiting (HIGH - abuse protection)
2. **GR4.2**: Database Optimization (HIGH - performance)
3. **GR4.4**: Cost Monitoring (MEDIUM - budget protection)
4. **GR4.3**: Deployment Automation (MEDIUM - efficiency)
5. **GR4.5**: Monitoring Dashboard (LOW - nice-to-have)

---

## Deliverables

- [ ] Enhanced rate limiting with tier-based limits
- [ ] Database indexes for all common queries
- [ ] Automated deployment pipeline with checks
- [ ] Cost tracking and budget alerts
- [ ] Production monitoring dashboard (optional)
- [ ] Update DEPLOYMENT_STATUS.md
- [ ] Update TEAM_COORDINATION.md

---

## Success Criteria

- [ ] Rate limiting protects against abuse
- [ ] Database queries <500ms
- [ ] Deployments fully automated
- [ ] Cost tracking prevents surprise bills
- [ ] Production metrics visible in dashboard
- [ ] Zero security vulnerabilities

---

## Notes

- **Rate limiting is critical**: Prevents abuse and cost overruns
- **Database performance matters**: Analytics will be slow without indexes
- **Automation reduces errors**: Manual deployments are error-prone
- **Cost monitoring is essential**: AI APIs can get expensive quickly

All tasks prepare the infrastructure for production-scale usage!
