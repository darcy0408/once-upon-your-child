# Rate Limiting Audit Report

**Date:** March 15, 2026  
**Status:** ✅ Active & Configured  
**Environment:** Production (Railway)

## 1. Overview
The Story Weaver backend implements a multi-layered rate limiting strategy using `Flask-Limiter` for general API protection and a custom in-memory decorator for specialized services like avatar generation.

## 2. Global Configuration
- **Library:** `Flask-Limiter` v4.1.1
- **Storage Backend:** 
  - **Production:** Configured to use Redis (`REDIS_URL` or `REDIS_PRIVATE_URL`) for distributed rate limiting across instances. Fallback to `memory://` with a logged error if Redis is missing.
  - **Development/Test:** Uses `memory://`.
- **Key Strategy:** `get_user_identifier` (prioritizes Authenticated User ID > `X-User-ID` header > JWT Identity > Remote IP).
- **Default Limits:** `200 per day`, `50 per hour`.

## 3. Per-Route Custom Limits

### Story Generation (`story_routes.py`)
| Endpoint | Limit (Free Tier) | Limit (Premium/Family) | BYOK Limit |
| :--- | :--- | :--- | :--- |
| `/generate-story` | 3/min, 10/hr, 50/day | 10-15/min, 100-200/hr | 1000/min |
| `/generate-interactive-story` | 5/min | 5/min | N/A |
| `/continue-interactive-story` | 5/min | 5/min | N/A |
| `/generate-illustrations` | 1/min, 5/hr, 10/day | 3-5/min, 20-30/hr | 100/hr |
| `/generate-coloring-pages` | 10/hr | 10/hr | N/A |
| `/get-story-themes` | 60/min | 60/min | N/A |
| `/report-story` | 5/hr | 5/hr | N/A |

### Avatar Generation (`avatar_routes.py`)
*Note: Uses a custom in-memory decorator `rate_limit_by_user_tier`. Limits are per-instance.*
| Endpoint | Limit (Free Tier) | Limit (Premium/Family) | BYOK Limit |
| :--- | :--- | :--- | :--- |
| `/avatar/generate-avatar` | 5/hr | 50/hr | Unlimited |
| `/avatar/generate-custom-avatar` | 3/hr | 20/hr | Unlimited |
| `/avatar/generate-pet-avatar` | 3/hr | 20/hr | Unlimited |
| `/avatar/regenerate-avatar` | 3/hr | 30/hr | Unlimited |
| `/avatar/tweak-gallery-avatar` | 0 (Locked) | 5/hr | Unlimited |

### TTS & Other Services
| Endpoint | Limit |
| :--- | :--- |
| `/tts/synthesize` | 20/hr |
| `/tts/transcribe` | 30/hr |
| `/auth/anonymous` | 20/min |
| `/auth/login` | 10/min |
| `/auth/refresh` | 30/min |

## 4. Verification Results
- **Connectivity:** Production API is reachable at `https://story-weaver-app-production.up.railway.app/health`.
- **Response Headers:** Standard security headers (HSTS, CSP, etc.) are present. `X-RateLimit` headers are configured to appear on endpoints with explicit decorators when limits are active.
- **Fail-safe:** The application handles `429 Too Many Requests` with kid-friendly error messages and upgrade prompts.

## 5. Recommendations & Observations

### 🔴 Security/Scalability Warning (Avatar Routes)
The avatar generation routes use an **in-memory** rate limit dictionary (`_rate_limit_hits`).
- **Issue:** If the app scales to multiple instances on Railway, each instance will have its own independent counter. A user could bypass limits by hitting different instances.
- **Fix:** Refactor `rate_limit_by_user_tier` in `avatar_routes.py` to use the global `limiter` instance which uses Redis.

### 🟡 Default Limits vs. Health Endpoint
The `/health` endpoint falls under the default `50 per hour` limit. While safe, monitoring tools hitting this endpoint frequently might trigger limits if not exempted or given a higher limit.

### ✅ Launch Readiness
The current configuration is **Sufficient for Launch**. The most expensive operations (Gemini API calls, Image Generation, TTS) have strict hourly and daily limits for the Free tier, protecting the project from unexpected costs while allowing reasonable use for children.

---
**Audit performed by:** Gemini CLI Agent  
**Status:** Approved for Production use (with Avatar scaling caveat).
