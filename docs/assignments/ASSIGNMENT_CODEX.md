# Assignment: Codex GPT 5.4 — Backend Python Work
**Date:** 2026-03-18
**Tool:** Codex GPT 5.4
**Language:** Python / Flask

You are working on the Story Weaver children's storytelling app.
Repo root: `C:/dev/story-weaver-app`
Backend is Python/Flask in `backend/` directory.
Do not touch Flutter/Dart files in `lib/` for this assignment.

After completing each task, update `TEAM_COORDINATION.md` at the repo root with a session entry, then commit:
```bash
git add <changed files> TEAM_COORDINATION.md
git commit -m "fix: <short description>"
```

---

## Task 1 — Add Live Gemini Health Probe (HIGH PRIORITY)

**Problem:** The current `/health` and `/health/detailed` endpoints only check if `GEMINI_API_KEY` is present (config check), but do NOT verify Gemini actually works. If the key is wrong or Gemini is down, the health check still shows green. This is misleading for monitoring.

**Goal:** Add a lightweight live Gemini probe to `/health/detailed` that makes a minimal real call to verify both the text model and image model are reachable.

**Files to edit:**
- `backend/routes/health_routes.py`
- `backend/services/` (add a small probe helper if needed)

**Requirements:**
1. The probe must be optional — if `GEMINI_API_KEY` is not set, skip it gracefully
2. The probe must be fast — use a minimal prompt like `"Say OK"` to the text model; skip or stub the image probe to avoid cost
3. Add a `gemini_probe` field to the `/health/detailed` JSON response:
   ```json
   {
     "gemini_probe": {
       "text_model": "ok",
       "image_model": "skipped",
       "latency_ms": 234
     }
   }
   ```
   Or on failure:
   ```json
   {
     "gemini_probe": {
       "text_model": "error: <message>",
       "image_model": "skipped"
     }
   }
   ```
4. Do not fail the overall health check if the probe fails — just report it as a field
5. The probe should not run on the `/health` (simple) endpoint, only on `/health/detailed`

**Verify:** Run `python -c "from backend.app import create_app; app = create_app('testing'); client = app.test_client(); import json; r = client.get('/health/detailed'); print(json.dumps(json.loads(r.data), indent=2))"` and confirm `gemini_probe` appears in the response.

---

## Task 2 — Re-Run Production Smoke Tests (HIGH PRIORITY)

**Note:** Only do this AFTER the CORS Railway env var has been set by Darcy (see `ASSIGNMENT_DARCY_MANUAL.md` Step 1). If CORS isn't fixed yet, the story generation test will still fail — skip Task 2 until it is.

**Goal:** Run the production smoke test suite and document current pass/fail status.

**Steps:**
1. Run the smoke tests against production:
   ```bash
   cd C:/dev/story-weaver-app
   python -m pytest backend/tests/smoke/test_production_smoke.py -v
   ```
2. Document each test result in `TEAM_COORDINATION.md`
3. If any tests fail with new errors (not CORS), investigate and fix them
4. Expected: all 10 tests pass after CORS fix

**Known previous state:** 8/10 passed. The 2 failures were:
- 500 on unknown routes (now fixed — 404 handler added)
- `rredis` module error in story generation (resolved — stale deploy)

---

## Task 3 — Real-Provider Performance Baseline (MEDIUM)

**Goal:** Run the story load audit with a real Gemini API key to establish actual production performance numbers.

**Steps:**
1. Verify `GEMINI_API_KEY` is set in `backend/.env`
2. Run:
   ```bash
   cd C:/dev/story-weaver-app/backend
   RUN_REAL_API_TESTS=true python tests/story_load_audit.py
   ```
   On Windows:
   ```bash
   set RUN_REAL_API_TESTS=true && python tests/story_load_audit.py
   ```
3. Document the results in `TEAM_COORDINATION.md` — specifically:
   - p50, p95, p99 story generation times
   - Fallback switchover latency
   - Concurrency ramp results
4. If any thresholds are exceeded, note which ones

**Targets from `backend/tests/story_load_thresholds.py`:**
- Verify thresholds pass: `python tests/story_load_thresholds.py`

---

## Task 4 — Update LAUNCH_BLOCKERS.md (DOCS)

**Goal:** `docs/LAUNCH_BLOCKERS.md` is stale — both items listed there have been fixed. Update it to reflect current reality.

**Steps:**
1. Read `docs/LAUNCH_BLOCKERS.md`
2. The two items listed (avatar rate limiting, health check exemption) were both fixed on 2026-03-18
3. Replace the content with the current actual blockers from `docs/DEPLOYMENT_PLAN_2026-03-18.md`
4. Commit the update

---

## Reference: Import Path Note

The repo has a known import path quirk. Always import from the repo root, not from inside `backend/`:
```bash
# Correct (from repo root):
python -c "from backend.app import create_app; ..."
python -m pytest backend/tests/...

# Wrong (from inside backend/):
cd backend && python -c "from app import create_app; ..."  # fails
```
