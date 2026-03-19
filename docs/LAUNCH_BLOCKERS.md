# Launch Blockers & High Priority TODOs
**Last updated:** 2026-03-18

## 🔴 Active Blockers

### B1 — CORS: Production Frontend URL Not in Allowed Origins
- **Issue:** Backend `ALLOWED_ORIGINS` reads from `RAILWAY_FRONTEND_URL` env var, which is not set.
  Production frontend (`https://grand-light-production-68d9.up.railway.app`) calls are blocked by CORS on all story/character routes.
- **Impact:** Core wizard cannot complete in production. Story generation, character persistence all fail.
- **Fix:** Railway dashboard → backend service → Variables → add `RAILWAY_FRONTEND_URL=https://grand-light-production-68d9.up.railway.app`
- **Effort:** 5 minutes, no code change, no redeploy needed (Railway auto-redeploys on var change)
- **Assigned:** Darcy (manual step only)

### B2 — Companion Assets Load From Wrong Folder
- **Issue:** `companion_selector_step.dart` loads companion images for creator/adolescent/adult age bands from the `adventurer` folder.
- **Impact:** Companions look wrong/mismatched for older kids and adult stories.
- **Fix:** Update asset path logic in `companion_selector_step.dart` to use the correct age-band subfolder.
- **Assigned:** Gemini Antigravity — see `docs/assignments/ASSIGNMENT_GEMINI_ANTIGRAVITY.md`

## 🟠 High Priority (Fix Before Launch)

### H1 — Scenario Card Art 404s
- `assets/images/scenarios/*.png` return 404 in production. Adventure/theme cards fall back to emoji.
- **Assigned:** Gemini Antigravity

### H2 — TypeError During Wizard
- Browser console: `TypeError: Cannot read properties of undefined (reading 'toString')` during wizard use.
- **Assigned:** Gemini Antigravity

### H3 — No Live Gemini Health Probe
- Health endpoints only check config presence, not live Gemini connectivity.
- **Assigned:** Codex

### H4 — Production Smoke Tests Not Re-Run After CORS Fix
- Need to re-run after B1 is fixed to confirm all 10 smoke tests pass.
- **Assigned:** Codex

## 🟡 Previously Listed (Now Resolved — Do Not Re-Do)

### ~~Backend - Avatar Route Rate Limiting~~
- ✅ RESOLVED 2026-03-18: Converted avatar routes to use global Redis-backed `limiter` instance.
  Custom in-memory `_rate_limit_hits` dict removed. `avatar_routes.py` now uses factory pattern matching all other blueprints.

### ~~Monitoring - Health Check Exemption~~
- ✅ RESOLVED 2026-03-18: All four health endpoints (`/health`, `/version`, `/health/detailed`, `/health/database`) are now exempt from rate limiting via `limiter.exempt(...)` in `health_routes.py`.
