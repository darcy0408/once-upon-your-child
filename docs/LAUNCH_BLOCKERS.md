> **ARCHIVED 2026-07-03** — superseded by [`LAUNCH_READINESS.md`](../LAUNCH_READINESS.md). Describes an earlier stack/plan (pre-Cloudflare, pre-OpenAI/Azure migration) and is kept for historical reference only — do not use it to judge current launch status.

# Launch Blockers & High Priority TODOs
**Last updated:** 2026-03-18

## 🔴 Active Blockers

### ~~B1 — CORS: Production Frontend URL Not in Allowed Origins~~
- ✅ RESOLVED 2026-03-18: `RAILWAY_FRONTEND_URL` set in Railway backend env, redeployed successfully.

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
