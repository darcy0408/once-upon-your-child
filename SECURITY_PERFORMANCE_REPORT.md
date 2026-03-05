# Security & Performance Review Report

**Date:** January 15, 2026
**Project:** Story Weaver App Backend
**Reviewer:** Claude Code Security Analysis

---

## Executive Summary

This report identifies **7 CRITICAL**, **5 HIGH**, **8 MEDIUM**, and **4 LOW** severity issues across security and performance categories. The most urgent issues involve missing authentication/authorization on sensitive endpoints, allowing potential account takeover and data exposure.

---

## CRITICAL SECURITY ISSUES

### 1. IDOR Vulnerability - User Routes (CRITICAL)
**File:** `backend/routes/user_routes.py:52-106`

**Issue:** The `/api/user/<user_id>/usage-stats` and `/api/user/<user_id>/cancel-subscription` endpoints accept any user_id without verifying the requester's identity.

```python
@user_routes.route('/api/user/<user_id>/usage-stats', methods=['GET'])
def get_usage_stats(user_id):
    user = db.session.get(User, user_id)  # No authentication check!
```

**Impact:** Any user can:
- View any other user's subscription status and usage data
- Cancel any other user's subscription

**Fix Required:**
```python
@user_routes.route('/api/user/<user_id>/usage-stats', methods=['GET'])
@jwt_required()
def get_usage_stats(user_id):
    current_user = get_jwt_identity()
    if current_user != user_id:
        return jsonify({'error': 'Unauthorized'}), 403
    # ... rest of code
```

---

### 2. Unauthenticated Admin Routes (CRITICAL)
**File:** `backend/routes/admin_routes.py:11-154`

**Issue:** Admin endpoints have NO authentication or authorization:
- `/admin/run-db-optimization` - Can modify database indexes
- `/admin/add-missing-columns` - Can alter database schema

**Impact:** Anyone can execute database schema modifications in production.

**Fix Required:** Add admin role verification:
```python
@admin_bp.route("/admin/run-db-optimization", methods=["POST"])
@jwt_required()
@admin_required  # Custom decorator to check admin role
def run_db_optimization():
```

---

### 3. Unauthenticated Analytics Endpoints (CRITICAL)
**File:** `backend/analytics_routes.py:115-281`

**Issue:** All analytics endpoints are publicly accessible:
- `/admin/analytics/overview` - Exposes business metrics
- `/admin/analytics/users` - Exposes all user emails and subscription data
- `/admin/analytics/stories` - Exposes user activity
- `/admin/cost-report` - Exposes API cost data

**Impact:** Complete data breach - user PII (emails, IDs, subscription tiers) exposed to anyone.

---

### 4. Missing Authorization on Character Operations (CRITICAL)
**File:** `backend/routes/character_routes.py:18-31`

**Issue:** Character update/delete endpoints don't verify ownership:
```python
@character_bp.route("/characters/<string:char_id>", methods=["DELETE"])
def delete_character_endpoint(char_id: str):
    response, status_code = character_service.delete_character(char_id)
```

**Impact:** Any user can delete/modify any other user's characters.

---

### 5. Weak JWT Secret Key Fallback (CRITICAL)
**File:** `backend/app.py:300`

```python
app.config['JWT_SECRET_KEY'] = app.config.get('JWT_SECRET_KEY', 'dev-secret-key')
```

**Impact:** If JWT_SECRET_KEY is not set in production, tokens can be forged using the known default key.

**Fix:** Remove fallback or fail if not set in production:
```python
if is_production() and not app.config.get('JWT_SECRET_KEY'):
    raise ValueError("JWT_SECRET_KEY must be set in production")
```

---

### 6. Hardcoded Anonymous User Password (CRITICAL)
**File:** `backend/app.py:287`

```python
anon.set_password('anonymous_guest_password')
```

**Impact:** Predictable password for anonymous user account.

---

### 7. Insecure CORS Configuration (CRITICAL)
**File:** `backend/config/__init__.py:115`

```python
"*"  # Allow all origins in dev to support random Flutter web ports
```

**Issue:** Wildcard CORS origin allows any website to make authenticated requests.

**Concern:** This is flagged as "dev only" but verify it's not active in production.

---

## HIGH SEVERITY ISSUES

### 8. No Rate Limiting on Admin Routes (HIGH)
**Files:** `backend/routes/admin_routes.py`, `backend/analytics_routes.py`

Admin and analytics routes have no rate limiting, enabling enumeration attacks.

---

### 9. Story Report Endpoint Information Disclosure (HIGH)
**File:** `backend/routes/story_routes.py:486-496`

The `/report-story` endpoint logs story previews without sanitization and has no authentication.

---

### 10. User ID Sanitization Bypass Potential (HIGH)
**File:** `backend/routes/story_routes.py:56-57`

```python
if user_id and user_id.startswith("user_"):
    user_id = user_id.replace("user_", "")
```

Incomplete sanitization - only removes first occurrence.

---

### 11. Lazy User Account Creation Without Validation (HIGH)
**File:** `backend/routes/story_routes.py:60-76`

```python
new_user = User(
    id=user_id,
    username=f"user_{user_id[:8]}",
    email=f"{user_id}@storyweaver.app"
)
new_user.set_password("anonymous_guest")  # Predictable password!
```

Creates accounts with predictable passwords for any user_id.

---

### 12. API Key Validation Endpoint Abuse (HIGH)
**File:** `backend/routes/api_key_routes.py:161-211`

The `/api/user/settings/validate-api-key` endpoint is unauthenticated and makes actual API calls, enabling:
- API key enumeration
- Cost amplification attacks

---

## MEDIUM SEVERITY ISSUES

### 13. Sensitive Data in Logs (MEDIUM)
**Files:** Multiple

API keys are partially logged:
- `backend/config/__init__.py:14` - Logs masked API key
- `backend/app.py:201-203` - Logs masked API key

---

### 14. Error Details Exposed to Users (MEDIUM)
**Files:** Multiple routes

Stack traces and internal error details returned in responses:
```python
return jsonify({"error": str(e)}), 500  # Exposes internal details
```

---

### 15. Missing Input Validation (MEDIUM)
**File:** `backend/routes/story_routes.py`

- `age` field not validated for range (could be negative or unrealistic)
- `num_images` capped at 4 but other fields unbounded

---

### 16. Potential Denial of Service via Story Length (MEDIUM)
**File:** `backend/tasks/story_tasks.py:248-260`

Min word thresholds can cause retry loops with costly AI calls.

---

### 17. Image Download Without Size Limits (MEDIUM)
**File:** `backend/routes/story_routes.py:588-608`

External images downloaded without size validation:
```python
img_resp = requests.get(image_url, timeout=10)
```

Could lead to memory exhaustion.

---

### 18. SQL in Admin Routes (MEDIUM - Mitigated)
**File:** `backend/routes/admin_routes.py:15-25`

Uses `text()` for raw SQL but statements are hardcoded, not user-controllable.

---

### 19. Missing CSRF Protection (MEDIUM)
No CSRF tokens on state-changing endpoints.

---

### 20. Insecure Cookie Configuration Not Verified (MEDIUM)
JWT cookie security flags (HttpOnly, Secure, SameSite) not explicitly configured.

---

## LOW SEVERITY ISSUES

### 21. Debug Logging in Production (LOW)
**File:** `backend/app.py:17-24`

Logging level set to DEBUG unconditionally.

---

### 22. Deprecated datetime.utcnow() Usage (LOW)
**Files:** Multiple

Using `datetime.utcnow()` which is deprecated in Python 3.12+.

---

### 23. Missing Content-Type Validation (LOW)
Endpoints accept JSON but don't strictly validate Content-Type header.

---

### 24. Unhandled File Handle in Error Logging (LOW)
**File:** `backend/routes/story_routes.py:161-164`

```python
with open("backend_last_error.log", "w") as f:
    f.write(error_trace)
```

No error handling for file write failures.

---

## PERFORMANCE ISSUES

### P1. N+1 Query Pattern (HIGH)
**File:** `backend/analytics_routes.py:186-189`

```python
stories_query = Story.query.options(
    db.joinedload(Story.user),
    db.joinedload(Story.characters)
)
```

Good use of joinedload here, but verify other queries.

---

### P2. Missing Database Indexes Dependency (MEDIUM)
**File:** `backend/routes/admin_routes.py`

Index creation is manual via admin endpoint rather than migrations. Indexes may be missing.

Recommended indexes (verify they exist):
- `stories(user_id, created_at)` - For user story queries
- `stories(theme)` - For theme filtering
- `users(subscription_tier)` - For tier filtering

---

### P3. In-Memory Rate Limiting (MEDIUM)
**File:** `backend/app.py:125-126`

```python
storage_uri="memory://"
```

Rate limits not shared across workers/instances.

---

### P4. Simple Cache Without TTL Management (LOW)
**File:** `backend/app.py:129`

```python
cache = Cache(app, config={'CACHE_TYPE': 'simple'})
```

In-memory cache, not distributed.

---

### P5. Synchronous Image Downloads (MEDIUM)
**File:** `backend/routes/story_routes.py:588`

Image downloads block the request thread.

---

### P6. Story Generation Retry Without Backoff (LOW)
**File:** `backend/tasks/story_tasks.py:221-278`

Retries happen immediately without exponential backoff.

---

## POSITIVE FINDINGS

1. **SQLAlchemy ORM Used Correctly** - Parameterized queries prevent SQL injection
2. **Password Hashing** - Using werkzeug's secure password hashing (`backend/models/user.py:37-41`)
3. **Stripe Webhook Verification** - Proper signature validation (`backend/routes/webhook_handler.py:28-39`)
4. **API Key Encryption** - Using AES-256-CBC for BYOK keys (`backend/encryption_utils.py`)
5. **Rate Limiting Infrastructure** - Flask-Limiter configured on most endpoints
6. **Slow Query Logging** - Queries over 1s are logged (`backend/app.py:311-321`)
7. **Content Filtering** - Story content is filtered before returning

---

## RECOMMENDED IMMEDIATE ACTIONS

### Priority 1 (This Week)
1. Add authentication to ALL admin/analytics routes
2. Add ownership verification to user_routes endpoints
3. Add ownership verification to character operations
4. Remove JWT secret key fallback in production
5. Verify CORS wildcard is disabled in production

### Priority 2 (Next 2 Weeks)
1. Add rate limiting to admin routes
2. Sanitize error responses in production
3. Add input validation ranges (age, etc.)
4. Add image download size limits

### Priority 3 (Next Month)
1. Implement CSRF protection
2. Add distributed rate limiting (Redis)
3. Add distributed caching (Redis)
4. Review and add missing database indexes

---

## SECURITY CHECKLIST FOR DEPLOYMENT

- [ ] JWT_SECRET_KEY is set to a strong random value
- [ ] ENCRYPTION_KEY is set for BYOK encryption
- [ ] STRIPE_WEBHOOK_SECRET is configured
- [ ] CORS wildcard ("*") is NOT in allowed origins
- [ ] DEBUG mode is disabled
- [ ] Admin routes require authentication
- [ ] Database indexes are created
- [ ] Rate limiting storage uses Redis (for multi-instance)

---

*Report generated by automated security analysis. Manual penetration testing recommended before production deployment.*
