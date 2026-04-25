# Consolidated Playwright Re-verification — 2026-04-24

**Model:** Sonnet (Opus only if the age-gate divergence surfaces as a new bug)
**Estimated effort:** 45–70 min
**Prerequisite:** Fresh Claude Code instance so `--isolated` flag from `.mcp.json` (commit `bc4071b`) activates and the Windows Playwright lockfile doesn't collide with a sibling session.

## Background

Six open manual-verification tasks have accumulated over the last two weeks. All code fixes are shipped and deployed to Railway; only live-browser confirmation remains. Running them in one Playwright session avoids redundant COPPA gates, warm-ups, and context churn.

## Scope — what this closes

| # | ID | Task | Commit(s) | Prior briefing |
|---|----|------|-----------|----------------|
| 1 | MT-005 (c29c) | **BUG-001** — Adult band Create Story E2E through `POST /generate-story` 200 | `73ee489` | `TASK1_PLAYWRIGHT_BAND6_REVERIFY.md` |
| 2 | MT-011 (2571) | **BUG-002** — TTS backoff curve (2/4/8/30s, ≤4 retries) on a fresh Explorer session | `16d4dac`, `b6b5c15` | `TASK3_BUG002_TTS_FRESH_SESSION.md` |
| 3 | MT-009 (c4ea) | **BUG-003** — No `/api/stripe/subscription-status/anon_*` 403s | `6d71454` | — |
| 4 | MT-008 (8a9d) | Archetype **2×2 image grid** renders for Creator/Adolescent/Adult (not text `FilterChip`); gold border on tap | `aac7a5d` | — |
| 5 | MT-005 (247a, duplicate ID) | Gender picker **boy/girl images** render correctly across all 6 bands | `bf94b8b` | — |
| 6 | MT-007 (d1c2) | **BYOK wizard** — key visible (white on `0xFF120226`), Finish saves, wizard does not relaunch on "Full illustrations" | `62b09a6`, `b8f8009` | — |

## Target

- **URL:** `https://grand-light-production-68d9.up.railway.app`
- **Viewport:** 1400 × 900
- **Renderer:** Railway production build (NOT local `flutter run -d chrome` — debug mode stalls Playwright at `DDC is about to load 1/2 scripts`; learned in session `d1c2`).

## Setup (once)

1. **Confirm no sibling Claude Code instance is holding the Playwright browser profile.** If another is open, close it first, then restart this instance so `--isolated` in `.mcp.json` activates. If you still see `Browser is already in use`, see `memory/reference_playwright_mcp_lockfile.md`.
2. Open a **fresh isolated Playwright context** (no `storageState`, no persisted cache).
3. **Install global network listener** capturing `url + method + status + timestamp + timing` for:
   - `api.elevenlabs.io` and any path containing `/tts/`
   - `/api/stripe/subscription-status/*`
   - `/generate-story`
   - Any 4xx/5xx
4. **Install console listener** — capture `TtsRateLimitException` / "backing off" log lines and any uncaught Dart exceptions.

> **Flutter canvas gotcha:** `document.images` is empty on Flutter web (session `8a9d` confirmed). Use the MCP `browser_take_screenshot` / `browser_snapshot` tools for visual assertions, not DOM image inspection.

## Execution order

The order matters — TTS must run on a truly cold session, BYOK should run last because it mutates user settings.

### Phase A — Explorer (age 8) — BUG-002 TTS backoff (fresh context first)

1. New isolated context. Navigate to target URL. Pass COPPA with age **8** (Explorer band — has TTS warm-up on welcome).
2. Land on welcome/home. **Do not start a story** — we're measuring the warm-up path, not playback.
3. Keep the network listener active, wait **~60 seconds**.
4. While waiting, screenshot the gender picker (Boy + Girl) and verify Explorer assets `5-7 year old boy.png` / `5-7 year old girl.png` render (addresses MT-005/247a Explorer row; no need to re-enter this band later).
5. Reload the page in the **same context** and confirm warm-up does NOT re-fire a full battery (`_prewarming` dedup flag).
6. Record:
   - Total TTS request count
   - Total 429 count
   - One phrase's retry timestamp list (pick the most-retried phrase)

**Pass criteria (MT-011):**
- ≤4 retries per phrase (hard cap absent but soft cap expected)
- Retry spacing approximates 2/4/8/30s with ±20% jitter
- No 429 storm (no >10 429s in any 30s window)
- Reload does not re-trigger full warm-up

**Fail criteria:** linear 429 climb, retries <2s apart, or reload re-fires warm-up.

### Phase B — Adult (age 21) — BUG-001 + BUG-003 + archetype grid + adult gender (new fresh context)

1. New isolated context. Pass COPPA with age **21**.
2. Verify gender picker renders `boy adult.png` / `girl adult.png` (MT-005/247a adult row).
3. Tap Create Story → Hero Creator.
4. Enter character name, age, select gender (Boy or Girl via `GenderImageButton`). **Do NOT** generate an avatar — mature bands don't expose one; that's exactly what BUG-001 regresses on.
5. Scroll to **CORE ARCHETYPE** section in the creative brief. Screenshot.
   - Confirm 2×2 `GridView` of image cards (NOT text `FilterChip`).
   - Images should match selected gender.
   - Tap one archetype → gold border appears + check-mark overlay (MT-008 adult row).
6. Tap **Continue**.
   - **Pass (BUG-001):** no "Please choose a look for your character first" banner; wizard advances past Hero Creator.
   - **Fail:** banner appears or wizard stuck.
7. Complete remaining wizard steps (Feeling → Companion → Magic Review) → tap Generate.
8. **Assert `POST /generate-story` returns 200.** Capture the duration — flag if >20s (session `c29c` saw a 37s response once).
9. **Assert ZERO 403s** on `/api/stripe/subscription-status/anon_*` across the entire session network log (MT-009 / BUG-003).

### Phase C — Adolescent (age 16)

1. New isolated context. Pass COPPA with age **16**.
2. Verify gender picker renders `gender_adolescent_boy.png` / `gender_adolescent_girl.png`. Both must be `.png` — the parallel session reconciled `.jpg` → `.png`; flag if either is missing or renders as broken image.
3. Open Create Story → Hero Creator → enter name + select gender.
4. Scroll to Core Archetype. Screenshot + tap to confirm 2×2 grid + gold border (MT-008 adolescent row).
5. **Watch for `POST /api/user/<id>/consent`** in the network log for the 13–17 path. MT-012 flagged that `welcome_screen.dart` vs `age_gate_screen.dart` may silently skip COPPA consent recording. If absent, record as new finding (don't fix here — too risky for this pass).

### Phase D — Creator (age 13)

1. New isolated context. Age **13**.
2. Gender picker: verify `14 boy.jpg` / `14 girl.jpg`.
3. Archetype grid screenshot + tap confirm (MT-008 creator row).

### Phase E — Adventurer (age 10) + Sprout (age 4) — gender picker only

1. Age **10** (Adventurer) — verify `8-10 year old boy.jpg` / `8-10 year old girl.jpg`. Archetype UI is still text chips for this band (by design) — skip grid check.
2. Age **4** (Sprout) — verify `sprouts_boy.png` / `sprouts_girl.png`. Same — no archetype grid.

### Phase F — BYOK wizard (MT-007)

Run last because it writes a key to user settings.

1. In a fresh Creator-band context (or any band that exposes BYOK), open the **BYOK setup wizard** from subscription/settings.
2. Paste a real `AIza…` test key (use your own test key, not a production customer key).
3. **Screenshot the key field.** Text must render **white on dark `0xFF120226`** and be legible. `_showKey` should default to `true` (commit `62b09a6`).
4. Tap **Finish**. Observe `POST /api/user/settings/validate-api-key` → expect 200, no CORS error (backend proxy from `b8f8009` should handle it).
5. Navigate elsewhere in the app and trigger a "Full illustrations" action.
   - **Pass:** BYOK wizard does NOT relaunch at step 0.
   - **Fail:** wizard reopens.
6. If blank page at `DDC is about to load 1/2 scripts`: that's the debug-mode trap — verify you're hitting the Railway prod URL, not localhost.

## Teardown + deliverable

1. Dump consolidated network + console logs.
2. Write `docs/QA_PLAYWRIGHT_REPORT_2026-04-24.md`, mirroring the layout of `docs/QA_PLAYWRIGHT_REPORT_2026-04-20.md`. One section per MT:
   - MT-ID + task name
   - Pass / fail / partial verdict
   - Evidence: status codes, retry timestamps, screenshot paths
3. In `docs/MANUAL_TASKS.md`, flip each completed item from `[open]` → `[done] (closed by <session-id>)`.
4. Close the session via the `/close-session` skill (writes the per-session file, updates `TEAM_COORDINATION.md` index).
5. Commit:
   ```
   docs(qa): log 2026-04-24 consolidated Playwright re-verification
   ```

## Risk notes

- **Debug-DDC trap** (session `d1c2`): do not run against `flutter run -d chrome`. Production Railway build only.
- **Lockfile clash**: if any sibling Claude Code instance is open, the Playwright MCP will deadlock even with `--isolated` in some cases. Close siblings before start.
- **Age-gate COPPA divergence** (MT-012): the 13–17 path through `welcome_screen.dart` vs `age_gate_screen.dart` may silently skip consent recording. Phase C watches for the consent POST; if absent, record as new finding but do not attempt a fix in this pass — it's a COPPA-risk refactor that needs Opus.
- **Flutter canvas renderer**: screenshot for visual assertions, not DOM.
- **Duplicate MT-005 IDs**: MANUAL_TASKS.md has two open `MT-005` entries (one from `c29c` for BUG-001, one from `247a` for gender images). This plan covers both; when flipping to done, annotate with the originating session ID to disambiguate.

## Reference files

- `lib/screens/wizard_steps/hero_creator_step.dart` — BUG-001 fix site (search `isMatureBand`)
- `lib/screens/wizard_steps/hero_creator_creative_brief.dart` — archetype grid (MT-008)
- `lib/services/tts_api_service.dart` — `TtsRateLimitException` rethrow (`16d4dac`)
- `lib/services/app_tts_service.dart` — `_prewarm()` backoff loop (`b6b5c15`)
- `lib/services/stripe_service.dart` — anon guard (`6d71454`)
- `lib/screens/byok_setup_wizard.dart` — BYOK UI (`62b09a6`)
- `backend/routes/api_key_routes.py:142` — BYOK validation proxy (`b8f8009`)
- `docs/QA_PLAYWRIGHT_REPORT_2026-04-20.md` — report format to mirror
- `memory/reference_playwright_mcp_lockfile.md` — lockfile recovery
