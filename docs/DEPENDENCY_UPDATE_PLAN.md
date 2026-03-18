# Dependency Update Plan
**Generated:** December 26, 2025
**Current Backend Dependencies Review**

---

## 📊 Current Versions vs. Proposed Updates

| Package | Current | Proposed | Type | Risk | Priority |
|---------|---------|----------|------|------|----------|
| **werkzeug** | 3.1.3 | 3.1.4 | Patch | ✅ Low | P1 - Security |
| **sentry-sdk[flask]** | 2.33.2 | 2.46.0 | Minor | ✅ Low | P1 - Security |
| **stripe** | 10.12.0 | 14.0.1 | Major | ⚠️ High | P1 - Needs Testing |
| **redis** | 5.0.1 | 7.1.0 | Major | ⚠️ High | P1 - Needs Testing |
| **Flask-Limiter** | 3.5.0 | 4.0.0 | Major | ⚠️ Medium | P2 - Minor |
| **Flask-JWT-Extended** | 4.6.0 | 4.7.1 | Minor | ✅ Low | P2 - Minor |
| **Flask-Caching** | 2.1.0 | 2.3.1 | Minor | ✅ Low | P2 - Minor |
| **apispec** | 6.3.0 | 6.9.0 | Minor | ✅ Low | P2 - Minor |

---

## 🎯 Update Strategy

### Phase 1: Safe Updates (Low Risk)
These are patch/minor updates with minimal breaking changes:
- werkzeug 3.1.3 → 3.1.4 (security patch)
- sentry-sdk 2.33.2 → 2.46.0 (bug fixes, improvements)
- Flask-JWT-Extended 4.6.0 → 4.7.1 (minor update)
- Flask-Caching 2.1.0 → 2.3.1 (minor update)
- apispec 6.3.0 → 6.9.0 (minor update)

**Action:** Update all at once, test backend

### Phase 2: Major Updates - Individual Testing
These require careful migration:

#### A. stripe 10.12.0 → 14.0.1
**Risk Assessment:**
- Major version jump (3 major versions)
- Likely breaking changes in API
- Critical for payment processing
- **Plan:** Research breaking changes, update code, test thoroughly

#### B. redis 5.0.1 → 7.1.0
**Risk Assessment:**
- Major version jump (2 major versions)
- May have connection/command changes
- Used for caching and Celery
- **Plan:** Update, test Celery tasks, verify caching works

#### C. Flask-Limiter 3.5.0 → 4.0.0
**Risk Assessment:**
- Major version (1 increment)
- May change rate limiting behavior
- **Plan:** Update, verify rate limits still work

---

## ✅ Phase 1: Safe Updates - Execute Now

### Step 1: Update requirements.txt
```txt
# Updated dependencies (Phase 1)
Werkzeug==3.1.4                    # 3.1.3 → 3.1.4 (security)
sentry-sdk[flask]==2.46.0          # 2.33.2 → 2.46.0 (improvements)
Flask-JWT-Extended==4.7.1          # 4.6.0 → 4.7.1 (minor)
Flask-Caching==2.3.1               # 2.1.0 → 2.3.1 (minor)
apispec==6.9.0                     # 6.3.0 → 6.9.0 (minor)
```

### Step 2: Install and Test
```bash
cd backend
pip install -r requirements.txt --upgrade
python app.py  # Verify backend starts
pytest         # Run tests
```

### Step 3: Verify Critical Paths
- ✅ Backend starts without errors
- ✅ Story generation works
- ✅ JWT authentication works
- ✅ Error reporting to Sentry works
- ✅ API documentation generates

---

## ⚠️ Phase 2A: Stripe 14.0.1 (Major Update)

### Known Potential Breaking Changes
**Common breaking changes in Stripe Python SDK 10.x → 14.x:**
1. **Async support** - May require async/await patterns
2. **Type hints** - Stricter type checking
3. **Method signatures** - Some method parameters changed
4. **Resource structure** - Response object structure may differ

### Migration Checklist
- [ ] Review current stripe usage in codebase
- [ ] Check for deprecated methods
- [ ] Update to new API patterns
- [ ] Test payment creation
- [ ] Test webhook handling
- [ ] Test subscription management

### Our Stripe Usage
```bash
# Find all stripe usage in codebase
grep -r "stripe\." backend/ --include="*.py"
```

**Expected locations:**
- `backend/routes/stripe_routes.py` - Payment endpoints
- `backend/tests/test_webhook_handler.py` - Webhook tests

### Test Plan
1. Start backend with updated stripe
2. Create test payment
3. Verify webhook handling
4. Check subscription endpoints

---

## ⚠️ Phase 2B: Redis 7.1.0 (Major Update)

### Known Potential Breaking Changes
**Common breaking changes in redis-py 5.x → 7.x:**
1. **Connection pooling** - Different connection patterns
2. **Command interface** - Some commands renamed
3. **Async support** - Better async/await support
4. **SSL/TLS** - Updated security protocols

### Migration Checklist
- [ ] Review current redis usage
- [ ] Update connection patterns if needed
- [ ] Test caching operations
- [ ] Test Celery with Redis backend
- [ ] Verify rate limiting (uses Redis)

### Our Redis Usage
- Flask-Caching backend
- Celery broker/result backend
- Flask-Limiter storage

### Test Plan
1. Start Redis server
2. Start backend with updated redis-py
3. Test caching: Generate story (should cache)
4. Test Celery: Queue background task
5. Test rate limiting: Hit API rate limits

---

## ⚠️ Phase 2C: Flask-Limiter 4.0.0

### Known Potential Breaking Changes
**Flask-Limiter 3.x → 4.x:**
1. **Configuration changes** - New config keys
2. **Storage backend** - Updated Redis storage
3. **Decorator changes** - Syntax updates

### Migration Checklist
- [ ] Check limiter configuration
- [ ] Verify decorator usage
- [ ] Test rate limits on endpoints

---

## 📝 Rollback Plan

If any update breaks functionality:

### Quick Rollback
```bash
cd backend
git checkout requirements.txt
pip install -r requirements.txt --force-reinstall
```

### Per-Dependency Rollback
```txt
# Revert specific package in requirements.txt
stripe==10.12.0  # Rollback from 14.0.1
```

---

## 🎯 Execution Order

1. **Now:** Phase 1 - Safe updates (5 packages)
2. **After Phase 1 Success:** Phase 2B - Redis (less risky)
3. **After Redis Success:** Phase 2C - Flask-Limiter
4. **Last:** Phase 2A - Stripe (most risky, test thoroughly)

---

## ✅ Success Criteria

### Phase 1 Complete When:
- [x] All packages installed without conflicts
- [x] Backend starts without errors
- [x] Story generation works
- [x] Tests pass

### Phase 2B Complete When:
- [ ] Redis connection successful
- [ ] Caching works (stories cached)
- [ ] Celery tasks execute
- [ ] Rate limiting works

### Phase 2C Complete When:
- [ ] Rate limits trigger correctly
- [ ] No 500 errors on rate-limited endpoints

### Phase 2A Complete When:
- [ ] Stripe checkout creates session
- [ ] Webhooks process correctly
- [ ] Subscriptions work
- [ ] No payment errors

---

## 📊 Time Estimates

- **Phase 1:** 10-15 minutes (update + test)
- **Phase 2B (Redis):** 20-30 minutes (update + comprehensive testing)
- **Phase 2C (Limiter):** 15-20 minutes (update + test rate limits)
- **Phase 2A (Stripe):** 30-60 minutes (code review + update + testing)

**Total:** 1.5 - 2.5 hours

---

## 🚨 Emergency Contacts

If critical issues arise:
- Stripe Dashboard: https://dashboard.stripe.com
- Sentry Dashboard: (your sentry URL)
- Redis Logs: Check server logs
- Rollback: `git checkout requirements.txt && pip install -r requirements.txt`
