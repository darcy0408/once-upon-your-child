# Gemini Task: Railway Backend Production Verification

## Priority: HIGH
**Assigned to:** Gemini CLI
**Estimated time:** 20-30 minutes
**Status:** Backend deployed on Railway, needs production hardening

---

## 🎯 Objective

Verify all backend endpoints work correctly on Railway, add production monitoring enhancements, and ensure the backend is fully production-ready.

---

## 📊 Current Status

✅ **Backend Deployed:** https://story-weaver-app-production.up.railway.app
✅ **Frontend Deployed:** https://grand-light-production-68d9.up.railway.app
✅ **CORS Configured:** Frontend can communicate with backend
✅ **Database Connected:** PostgreSQL on Railway
✅ **Stripe Integrated:** Both tiers working

⏳ **Needs:** Final endpoint verification and production hardening

---

## Task 1: Test All Critical Endpoints

### 1.1: Health Check
```bash
curl https://story-weaver-app-production.up.railway.app/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "database": "ok",
  "has_api_key": true,
  "model": "models/gemini-2.5-flash"
}
```

**Verify:**
- [ ] Returns 200 OK
- [ ] Database shows "ok"
- [ ] API key is detected
- [ ] Model is correct

### 1.2: Story Generation Endpoint
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{
    "character_name": "Luna",
    "theme": "Adventure",
    "age": 7
  }'
```

**Expected:**
- Returns 200 OK
- Response contains story text
- Story has title and wisdom_gem
- Response time < 10 seconds

**Verify:**
- [ ] Story generates successfully
- [ ] No 500 errors
- [ ] Check Railway logs for any warnings

**If it fails:** Note the error message and Railway logs

### 1.3: Interactive Story Endpoints

**Start Interactive Story:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "character": "Alex",
    "theme": "Mystery",
    "age": 10
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
    "character": "Alex",
    "theme": "Mystery",
    "age": 10,
    "choice": "Investigate the sound",
    "story_so_far": "Alex heard a strange noise...",
    "choices_made": ["Enter the old house"]
  }'
```

**Expected:**
- [ ] Returns continuation
- [ ] New choices provided
- [ ] Story flows logically

### 1.4: Stripe Endpoints

**Create Checkout Session (Premium):**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "premium",
    "user_id": "test_user_gemini"
  }'
```

**Expected:**
- [ ] Returns checkout_url
- [ ] URL starts with https://checkout.stripe.com/
- [ ] Session ID provided

**Create Checkout Session (Family):**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "family",
    "user_id": "test_user_gemini"
  }'
```

**Expected:**
- [ ] Returns checkout_url
- [ ] Different session ID than premium

**Check Subscription Status:**
```bash
curl https://story-weaver-app-production.up.railway.app/api/stripe/subscription-status/test_user_123
```

**Expected:**
- [ ] Returns JSON with status and tier
- [ ] Default: `{"status": "inactive", "tier": "free"}`

---

## Task 2: Add stripe_configured to Health Endpoint

The health endpoint is missing the `stripe_configured` field that Grok noted.

**File:** `backend/app.py`

**Find the health endpoint** (search for `@app.route('/health'`)

**Add after the Gemini checks:**
```python
# Stripe check
stripe_api_key = os.getenv('STRIPE_API_KEY')
health_status['stripe_configured'] = bool(stripe_api_key)
if stripe_api_key:
    health_status['stripe_premium_price'] = bool(os.getenv('STRIPE_PRICE_ID_PREMIUM'))
    health_status['stripe_family_price'] = bool(os.getenv('STRIPE_PRICE_ID_FAMILY'))
```

**After making the change:**
1. Commit with message: `[AGENT SYNC | YYYY-MM-DD HH:MM:SS] Feat: Add Stripe configuration to health endpoint`
2. Push to trigger Railway redeploy
3. Wait 2-3 minutes for deploy
4. Test health endpoint again - should now show stripe fields

---

## Task 3: Test Error Handling

### 3.1: Test Invalid Requests

**Missing required field:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected:**
- [ ] Returns 400 Bad Request (NOT 500)
- [ ] Error message is clear
- [ ] Logged in Railway

**Invalid Stripe tier:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "invalid",
    "user_id": "test"
  }'
```

**Expected:**
- [ ] Returns 400 Bad Request
- [ ] Error message: "Invalid subscription tier" or similar

### 3.2: Check Railway Logs

Go to Railway dashboard → Backend service → Logs

**Look for:**
- [ ] No unexpected errors
- [ ] All requests being logged
- [ ] No database connection issues
- [ ] No Stripe API errors

---

## Task 4: Performance Testing

### 4.1: Response Time Check

Test each endpoint 3 times and note average response time:

```bash
time curl -s https://story-weaver-app-production.up.railway.app/health
```

**Target response times:**
- Health endpoint: < 200ms
- Story generation: < 10 seconds
- Stripe checkout: < 1 second

**Document results:**
```markdown
### Performance Baseline (2025-11-24)
- Health: [X]ms
- Story generation: [X]s
- Stripe checkout: [X]ms
```

### 4.2: Concurrent Request Test

Test if backend handles multiple requests:

```bash
# Run 5 health checks simultaneously
for i in {1..5}; do
  curl -s https://story-weaver-app-production.up.railway.app/health &
done
wait
```

**Expected:**
- [ ] All 5 requests complete successfully
- [ ] No timeouts
- [ ] No errors in Railway logs

---

## Task 5: Database Connection Verification

### 5.1: Check Character Routes

If you have character endpoints, test them:

```bash
# List characters (if endpoint exists)
curl https://story-weaver-app-production.up.railway.app/api/characters

# Create character (if endpoint exists)
curl -X POST https://story-weaver-app-production.up.railway.app/api/characters \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TestChar",
    "age": 8
  }'
```

**If these endpoints don't exist, that's OK - skip this section**

### 5.2: Database Connection Pool

In Railway logs, look for:
- [ ] No "too many connections" errors
- [ ] No "connection refused" errors
- [ ] Database queries completing quickly

---

## Task 6: Environment Variables Verification

### 6.1: Check Railway Variables

In Railway dashboard → Backend service → Variables

**Verify these are set:**
- [ ] `GEMINI_API_KEY`
- [ ] `GEMINI_MODEL` (should be models/gemini-2.5-flash)
- [ ] `DATABASE_URL` (auto-generated by Railway PostgreSQL)
- [ ] `STRIPE_API_KEY`
- [ ] `STRIPE_PRICE_ID_PREMIUM`
- [ ] `STRIPE_PRICE_ID_FAMILY`
- [ ] `STRIPE_WEBHOOK_SECRET`
- [ ] `ALLOWED_ORIGINS` (should be https://grand-light-production-68d9.up.railway.app)

**If any are missing:** Alert user immediately

---

## Task 7: Update TEAM_COORDINATION.md

After completing all tests, add this entry:

```markdown
- 2025-11-24 · Gemini → Team: BACKEND VERIFICATION COMPLETE ✅
  - All endpoints tested on Railway production deployment
  - Health endpoint: ✅ [status/issues found]
  - Story generation: ✅ [response time: Xs]
  - Interactive stories: ✅ [working/issues found]
  - Stripe integration: ✅ [both tiers tested]
  - Error handling: ✅ [400s return correctly]
  - Performance: ✅ [baseline documented]
  - Database: ✅ [connections stable]
  - Added stripe_configured to health endpoint
  - Status: Backend production-ready
```

---

## Verification Checklist

Before marking complete:

- [ ] Health endpoint returns 200 with all fields
- [ ] Story generation works (tested successfully)
- [ ] Interactive stories work (both endpoints)
- [ ] Stripe checkout works (both tiers)
- [ ] Error handling returns proper 400 errors
- [ ] Performance baselines documented
- [ ] Railway logs show no critical errors
- [ ] Environment variables verified
- [ ] stripe_configured added to health endpoint
- [ ] TEAM_COORDINATION.md updated

---

## 🚨 Stop and Alert If:

- ❌ Story generation returns 500 errors
- ❌ Database connection fails
- ❌ Stripe integration not working
- ❌ Any environment variables missing
- ❌ Response times > 15 seconds

---

## Git Commit Template

```bash
git commit -m "[AGENT SYNC | YYYY-MM-DD HH:MM:SS] Feat: Add Stripe health check to backend

Enhanced health endpoint with Stripe configuration status:
- Added stripe_configured boolean
- Added stripe_premium_price check
- Added stripe_family_price check

All backend endpoints verified on Railway production.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Expected Outcome

✅ **Production-Ready Backend:**
- All endpoints verified working
- Stripe health check added
- Performance documented
- Error handling validated
- Ready for user traffic

**Backend is solid and ready for Codex to test the frontend integration!** 🚀
