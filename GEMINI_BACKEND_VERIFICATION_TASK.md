# Gemini Task: Backend Verification & Production Hardening

## Priority: MEDIUM
**Assigned to:** Gemini CLI
**Estimated time:** 30-40 minutes
**Status:** Backend deployed and working, needs final verification and hardening

---

## 🎯 Objective

Verify all backend endpoints are working correctly on Railway, implement comprehensive error logging, add health monitoring enhancements, and ensure production readiness.

---

## 📊 Current Status

✅ **Deployed on Railway**: https://story-weaver-app-production.up.railway.app
✅ **Stripe Integration**: Working (both tiers tested)
✅ **Database**: PostgreSQL connected
✅ **Environment Variables**: All configured

⚠️ **Needs**: Final verification, enhanced monitoring, error handling review

---

## Task 1: Comprehensive Endpoint Testing

### 1.1: Test Health Endpoint

```bash
curl https://story-weaver-app-production.up.railway.app/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "database": "ok",
  "has_api_key": true,
  "model": "models/gemini-2.5-flash",
  "environment": "production"
}
```

**Verify:**
- [ ] Returns 200 OK
- [ ] All fields present
- [ ] Database shows "ok"
- [ ] API key detected

### 1.2: Test Story Generation Endpoint

```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{
    "character_name": "Test Hero",
    "theme": "Adventure",
    "age": 7
  }'
```

**Expected:**
- Returns 200 OK
- Contains story text
- Has title and wisdom_gem fields

**Verify:**
- [ ] Story generates successfully
- [ ] Response time < 10 seconds
- [ ] No errors in Railway logs

### 1.3: Test Interactive Story Endpoints

**Generate Interactive Story:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "character": "Test Hero",
    "theme": "Adventure",
    "age": 8
  }'
```

**Expected:**
- [ ] Returns story segment
- [ ] Includes 2-3 choices
- [ ] Each choice has id and text

**Continue Interactive Story:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "character": "Test Hero",
    "theme": "Adventure",
    "age": 8,
    "choice": "Go into the forest",
    "story_so_far": "Once upon a time...",
    "choices_made": ["Start adventure"]
  }'
```

**Expected:**
- [ ] Returns next segment
- [ ] New choices provided
- [ ] Story continues logically

### 1.4: Test Stripe Endpoints

**Already tested by Claude, but verify once more:**

```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "premium",
    "user_id": "gemini_test_user"
  }'
```

**Expected:**
- [ ] Returns checkout_url
- [ ] URL starts with https://checkout.stripe.com/
- [ ] Session ID provided

**Test Subscription Status:**
```bash
curl https://story-weaver-app-production.up.railway.app/api/stripe/subscription-status/test_user_123
```

**Expected:**
- [ ] Returns JSON with status and tier
- [ ] Default response: `{"status": "inactive", "tier": "free"}`

---

## Task 2: Enhanced Error Logging

### 2.1: Add Request ID Tracking

Add a request ID middleware to track requests through the system.

**File:** `backend/app.py`

**Add after imports:**
```python
import uuid
from flask import g

@app.before_request
def add_request_id():
    g.request_id = str(uuid.uuid4())[:8]
    logger.info(f"[{g.request_id}] {request.method} {request.path}")

@app.after_request
def log_response(response):
    logger.info(f"[{g.request_id}] Response: {response.status_code}")
    return response
```

**Purpose:** Track individual requests through logs for debugging

### 2.2: Enhanced Error Handler

Update error handling to include more context:

**File:** `backend/app.py`

```python
@app.errorhandler(Exception)
def handle_error(error):
    request_id = getattr(g, 'request_id', 'unknown')
    logger.exception(f"[{request_id}] Unhandled error: {error}")

    # Don't expose internal errors in production
    if app.config.get('ENV') == 'production':
        return jsonify({
            'error': 'Internal server error',
            'request_id': request_id
        }), 500
    else:
        return jsonify({
            'error': str(error),
            'request_id': request_id
        }), 500
```

### 2.3: API Rate Limit Logging

Add logging when rate limits are hit:

**File:** `backend/app.py` (after Flask-Limiter setup)

```python
@app.errorhandler(429)
def ratelimit_handler(e):
    request_id = getattr(g, 'request_id', 'unknown')
    logger.warning(f"[{request_id}] Rate limit exceeded: {request.endpoint}")
    return jsonify({
        'error': 'Rate limit exceeded',
        'retry_after': e.description
    }), 429
```

---

## Task 3: Health Endpoint Enhancement

### 3.1: Add More Health Checks

**File:** `backend/app.py` - Update `/health` endpoint

```python
@app.route('/health', methods=['GET'])
def health_check():
    health_status = {
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0',  # Add versioning
    }

    # Database check
    try:
        db.session.execute('SELECT 1')
        health_status['database'] = 'ok'
    except Exception as e:
        health_status['database'] = 'error'
        health_status['database_error'] = str(e)
        health_status['status'] = 'degraded'

    # Gemini API check
    health_status['has_api_key'] = bool(os.getenv('GEMINI_API_KEY'))
    health_status['model'] = os.getenv('GEMINI_MODEL', 'not-set')

    # Stripe check
    health_status['stripe_configured'] = bool(os.getenv('STRIPE_API_KEY'))
    health_status['stripe_premium_price'] = bool(os.getenv('STRIPE_PRICE_ID_PREMIUM'))
    health_status['stripe_family_price'] = bool(os.getenv('STRIPE_PRICE_ID_FAMILY'))

    # Environment
    health_status['environment'] = os.getenv('RAILWAY_ENVIRONMENT', 'unknown')

    status_code = 200 if health_status['status'] == 'ok' else 503
    return jsonify(health_status), status_code
```

---

## Task 4: Database Query Optimization Check

### 4.1: Review Character Routes

**File:** `backend/routes/character_routes.py`

**Check for N+1 queries:**
- Are we loading characters efficiently?
- Do we need eager loading for relationships?

**Add logging for slow queries:**
```python
import time

@character_routes.before_request
def start_timer():
    g.start_time = time.time()

@character_routes.after_request
def log_query_time(response):
    if hasattr(g, 'start_time'):
        duration = time.time() - g.start_time
        if duration > 1.0:  # Log slow queries
            logger.warning(f"Slow request: {request.path} took {duration:.2f}s")
    return response
```

### 4.2: Add Database Connection Pool Monitoring

**File:** `backend/app.py`

```python
# After database initialization
@app.route('/health/database', methods=['GET'])
def database_health():
    """Detailed database health check"""
    try:
        # Check connection pool
        pool = db.engine.pool
        return jsonify({
            'status': 'ok',
            'pool_size': pool.size(),
            'checked_in': pool.checkedin(),
            'checked_out': pool.checkedout(),
            'overflow': pool.overflow()
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500
```

---

## Task 5: Webhook Security Verification

### 5.1: Verify Webhook Signature Validation

**File:** `backend/routes/webhook_handler.py`

**Ensure signature verification is active:**
```python
@webhook_routes.route('/stripe', methods=['POST'])
def stripe_webhook():
    payload = request.data
    sig_header = request.headers.get('Stripe-Signature')

    if not STRIPE_WEBHOOK_SECRET:
        logger.error("Webhook secret not configured")
        return jsonify({'error': 'Webhook not configured'}), 500

    try:
        # This line MUST be present for security
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET
        )

        logger.info(f"Webhook received: {event['type']}")
        # ... handle event

    except ValueError as e:
        logger.error(f"Invalid payload: {e}")
        return jsonify({'error': 'Invalid payload'}), 400
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"Invalid signature: {e}")
        return jsonify({'error': 'Invalid signature'}), 400
```

**Verify:**
- [ ] Signature verification is enabled
- [ ] Invalid signatures are rejected
- [ ] Webhook secret is loaded from environment

---

## Task 6: Production Environment Configuration

### 6.1: Verify Production Settings

**Check Railway environment variables are set:**

```bash
# Use Railway CLI or dashboard to verify:
railway variables list
```

**Required variables:**
- [ ] `GEMINI_API_KEY`
- [ ] `GEMINI_MODEL`
- [ ] `DATABASE_URL`
- [ ] `STRIPE_API_KEY`
- [ ] `STRIPE_WEBHOOK_SECRET`
- [ ] `STRIPE_PRICE_ID_PREMIUM`
- [ ] `STRIPE_PRICE_ID_FAMILY`

### 6.2: Add Environment Detection

**File:** `backend/app.py`

```python
def is_production():
    return os.getenv('RAILWAY_ENVIRONMENT') == 'production'

# Use throughout app for conditional logic
if is_production():
    # Production-specific settings
    app.config['DEBUG'] = False
    app.config['TESTING'] = False
else:
    # Development settings
    app.config['DEBUG'] = True
```

---

## Task 7: Testing & Verification

### 7.1: Load Testing (Light)

Test the backend can handle concurrent requests:

**Simple Load Test Script:**
```bash
# Create test_load.sh
for i in {1..10}; do
  curl -s https://story-weaver-app-production.up.railway.app/health &
done
wait
echo "All requests completed"
```

**Run and verify:**
- [ ] All requests return 200 OK
- [ ] No timeout errors
- [ ] Railway logs show all requests processed

### 7.2: Error Scenario Testing

**Test invalid requests:**
```bash
# Missing required field
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected:**
- [ ] Returns 400 Bad Request (not 500)
- [ ] Error message is helpful
- [ ] Error is logged properly

**Test invalid Stripe tier:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{"tier": "invalid"}'
```

**Expected:**
- [ ] Returns 400 Bad Request
- [ ] Error message: "Invalid subscription tier"

---

## Task 8: Documentation Update

### 8.1: Update TEAM_COORDINATION.md

```markdown
- 2025-11-24 · Gemini → Team: BACKEND VERIFICATION COMPLETED ✅
  - All endpoints tested and verified on Railway
  - Enhanced error logging with request ID tracking
  - Health endpoint upgraded with detailed checks
  - Webhook security verified
  - Database query monitoring added
  - Load testing passed (10 concurrent requests)
  - Production environment variables confirmed
  - Files modified: backend/app.py, backend/routes/webhook_handler.py
  - Status: ✅ Production ready
```

### 8.2: Create API Documentation (Optional but Recommended)

**File:** `backend/API_ENDPOINTS.md`

Document all endpoints:
- `/health` - Health check
- `/generate-story` - Story generation
- `/generate-interactive-story` - Interactive story start
- `/continue-interactive-story` - Interactive story continuation
- `/api/stripe/create-checkout-session` - Create Stripe session
- `/api/stripe/subscription-status/<user_id>` - Get subscription status
- `/api/webhooks/stripe` - Stripe webhook handler

---

## Verification Checklist

Before marking complete:

- [ ] All endpoints return expected responses
- [ ] Error logging enhanced with request IDs
- [ ] Health endpoint shows all system status
- [ ] Webhook signature verification confirmed
- [ ] Database query monitoring added
- [ ] Production environment variables verified
- [ ] Load testing completed successfully
- [ ] Error scenarios handled gracefully
- [ ] No critical errors in Railway logs
- [ ] TEAM_COORDINATION.md updated

---

## 🚨 Stop and Alert If:

- ❌ Any core endpoint returns 500 errors
- ❌ Database connection fails
- ❌ Stripe integration not working
- ❌ Webhook signature validation is missing
- ❌ Gemini API key not configured

---

## Git Commit Template

```bash
git commit -m "[AGENT SYNC | YYYY-MM-DD HH:MM:SS] Feat: Backend production hardening

Enhanced backend for production readiness:
- Added request ID tracking for all requests
- Enhanced health endpoint with detailed checks
- Improved error handling and logging
- Verified webhook signature validation
- Added database query performance monitoring
- Tested all endpoints on Railway

All systems verified and production ready.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Expected Outcome

✅ **Production-Ready Backend:**
- All endpoints verified and working
- Comprehensive error logging in place
- Health monitoring enhanced
- Security verified (webhook signatures)
- Performance monitoring added
- Graceful error handling
- Ready for user traffic

**This ensures the backend is bulletproof for launch!** 🚀
