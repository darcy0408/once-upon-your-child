# Launch Blockers & High Priority TODOs

## 🔴 High Priority

### Backend - Avatar Route Rate Limiting
- **Issue:** Avatar generation routes in `backend/routes/avatar_routes.py` use a custom in-memory rate limiter (`rate_limit_by_user_tier`) instead of the global `limiter` instance.
- **Impact:** Rate limits are not shared across multiple production instances (resets on restart or if user hits different scaling nodes).
- **Task:** Refactor `rate_limit_by_user_tier` to use the `limiter` instance from `app.py` so it can leverage Redis storage in production.

## 🟡 Medium Priority

### Monitoring - Health Check Exemption
- **Issue:** The `/health` endpoint is subject to default rate limits (50/hr).
- **Impact:** Automated monitoring services might get 429 errors.
- **Task:** Explicitly exempt `/health` or give it a very high limit.
