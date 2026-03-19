# Story Weaver — Deployment Plan 2026-03-18

**Status:** ~90% done. All code features complete. Manual testing and one production config change remain before launch.
**Goal:** Fix CORS (5-min Railway config), verify all features work end-to-end, ship.

---

## Remaining Items by Priority

### 🔴 BLOCKER — Must Fix Before Any Testing

| # | Item | Assigned To | File |
|---|------|------------|------|
| B1 | CORS: set `RAILWAY_FRONTEND_URL` in Railway backend dashboard | **Darcy (manual)** | Railway env config |
| B2 | Companion assets: creator/adolescent/adult load from wrong folder | **Gemini Antigravity** | `lib/screens/wizard_steps/companion_selector_step.dart` |

### 🟠 HIGH — Fix Before Launch

| # | Item | Assigned To | File |
|---|------|------------|------|
| H1 | Scenario card art returns 404 in production | **Gemini Antigravity** | `assets/images/scenarios/`, `pubspec.yaml` |
| H2 | TypeError: `Cannot read properties of undefined (reading 'toString')` | **Gemini Antigravity** | Dart wizard files |
| H3 | Add live Gemini health probe (text + image) | **Codex** | `backend/routes/health_routes.py` |
| H4 | Re-run production smoke tests after CORS fix | **Codex** | `backend/tests/smoke/test_production_smoke.py` |

### 🟡 MEDIUM — Fix Before Launch if Possible

| # | Item | Assigned To | File |
|---|------|------------|------|
| M1 | Font warnings (Noto missing-glyph) | **Gemini Antigravity** | `pubspec.yaml` or font declarations |
| M2 | Real-provider performance baseline | **Codex** | `backend/tests/story_load_audit.py` |

### 🟢 TESTING — Required Before Launch

| # | Item | Assigned To |
|---|------|------------|
| T1 | Manual integration: 6 age bands × (visual, characters, companions, story, illustrations) | **Darcy (manual)** |
| T2 | Cross-cutting: BYOK, custom avatar, pet avatar, parent hidden context, bedtime mode | **Darcy (manual)** |
| T3 | Cross-browser: Chrome + Firefox + Edge + Mobile Chrome | **Darcy (manual)** |
| T4 | Firefox testing (previously unstable/incomplete) | **Gemini Pro** |

### 📝 DOCS — Update As Work Completes

| # | Item | Assigned To |
|---|------|------------|
| D1 | Update `docs/LAUNCH_BLOCKERS.md` (both items there are already fixed) | **Codex** |
| D2 | Update `TEAM_COORDINATION.md` after each task | **Each model** |

---

## What Is Already Done (Do Not Re-Do)

- Avatar route rate limiting (Redis-backed) ✅
- Health route limiter exemptions ✅
- API key security + authorization ownership ✅
- Android JDK 21 pin ✅
- Performance instrumentation + load tests (mock) ✅
- Companion data forwarding to illustrations + coloring ✅
- ColoringSettingsDialog 1-5 page picker ✅
- Age-band UI expansion (6 bands) ✅
- All age-band assets (Sprout → Adult) ✅
- Illustration count entitlement by subscription tier ✅
- COPPA fixes + "Delete All My Data" UI ✅
- 404 error handler ✅
- Bedtime mode end-to-end ✅
- Pet avatar fallback chain ✅
- Big Feelings age variants (6-8, 9-12, 13-15) ✅
- Hidden parent layer ✅
- Diverse character carousel ✅
- Backend cold start fix (removed unused google.api_core import) ✅
- Debug output cleanup (print → logger) ✅

---

## Quick Start (Local Dev)

```bash
# Start backend
cd C:/dev/story-weaver-app/backend
python app.py

# Start Flutter web (separate terminal)
cd C:/dev/story-weaver-app
flutter run -d chrome

# Verify backend
curl http://127.0.0.1:5000/health
```

---

## CORS Fix Details (B1 — Darcy only, 5 minutes)

The backend's `ALLOWED_ORIGINS` list reads from the `RAILWAY_FRONTEND_URL` env var.
The production frontend URL is `https://grand-light-production-68d9.up.railway.app` but this
env var is not set in the Railway backend service.

**Steps:**
1. Go to Railway dashboard → backend service → Variables tab
2. Add: `RAILWAY_FRONTEND_URL` = `https://grand-light-production-68d9.up.railway.app`
3. Railway will redeploy automatically
4. Test: open `https://grand-light-production-68d9.up.railway.app` in Chrome and run through the story wizard

No code change needed — the config already handles this correctly once the env var exists.

---

## Assignments Index

- `docs/assignments/ASSIGNMENT_DARCY_MANUAL.md` — Railway config + manual testing checklist
- `docs/assignments/ASSIGNMENT_GEMINI_ANTIGRAVITY.md` — Flutter/Dart UI fixes
- `docs/assignments/ASSIGNMENT_CODEX.md` — Backend Python work
- `docs/assignments/ASSIGNMENT_GEMINI_PRO.md` — Firefox testing + launch readiness

---

## Go / No-Go Criteria

Launch when ALL of the following are true:
- [ ] CORS fixed (B1) — story wizard completes in production Chrome
- [ ] Companion assets load correctly in all age bands (B2)
- [ ] Scenario card art shows (H1) — or explicitly accepted as known cosmetic gap
- [ ] TypeError resolved (H2)
- [ ] Manual integration: at least 4/6 age bands fully pass
- [ ] Cross-browser: Chrome + Edge pass core wizard
- [ ] Production smoke tests: all 10 pass
