# Task 3 — BUG-002 TTS Backoff Fresh-Session Verification

**Model:** Sonnet
**Estimated effort:** 15–25 min

## Background

**BUG-002** (TTS 429 storm during session warm-up) was fixed on 2026-04-20b in commit `b6b5c15`:

- `lib/services/tts_api_service.dart` — throws `TtsRateLimitException` on HTTP 429.
- `lib/services/app_tts_service.dart` — `_prewarming` dedup flag + exponential backoff (2 → 4 → 8 → 30s, 4 attempts) on `TtsRateLimitException`.

The 2026-04-21 re-verification attempt (`TEAM_COORDINATION.md` §2026-04-21) was **inconclusive**: 38+ 429s were observed, but the session had cached TTS playback from a previous story, so the observed storm may not have been the warm-up path at all.

## Your job

Run the test on a **fresh, uncached session** and determine whether the backoff fix works.

## Target

- **URL:** `https://grand-light-production-68d9.up.railway.app`
- **Viewport:** 1400 × 900
- **Session:** Fresh Playwright context — **no stored state, no cached story, no persisted TTS audio cache**. Use `browser.newContext()` without a `storageState`.

## Test procedure

1. Launch a clean Playwright context.
2. Before navigating, attach a network listener that records all requests to:
   - `api.elevenlabs.io`
   - `/tts/*` (any path containing `tts`)
   - Record method, URL, status, timestamp.
3. Navigate to the target URL.
4. Pass the age gate with age 8 (Explorer band — has TTS warm-up on welcome).
5. Land on welcome / main screen. **Do not start a story** — we're measuring the warm-up path, not playback.
6. Wait ~60 seconds, capturing all TTS-related network activity.
7. Dump the captured requests to the report.

## Pass criteria

- ✅ Total 429 count stays **bounded** — a handful of retries per phrase (≤4), not a storm.
- ✅ Time gaps between retries on the same phrase show the backoff curve: ~2s, ~4s, ~8s, ~30s (allow ±20% jitter).
- ✅ After a phrase exhausts its retries, no further requests for that phrase fire in the session.
- ✅ A second page load in the same context does not re-trigger a full warm-up (`_prewarming` dedup).

## Fail criteria

- ❌ 429 count climbs linearly (>10 within 30 s) with no discernible backoff spacing.
- ❌ Retries fire faster than 2 s apart.
- ❌ Reloading the page re-fires the entire warm-up battery despite dedup flag.

## Deliverable

1. Append a section to the 2026-04-21 entry in `TEAM_COORDINATION.md`:
   - Header: `### BUG-002 re-verification — fresh session`
   - Total TTS request count
   - Total 429 count
   - Observed retry spacing (sample one phrase, list its retry timestamps)
   - Verdict: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL with reason
2. Commit: `docs(team): log 2026-04-21 BUG-002 fresh-session re-verification — <pass|fail>`.

## Notes

- If the phrase-level retry timestamps are ambiguous (mixed with other requests), filter by the full request URL — each phrase has a distinct text payload or cache key.
- If you see 0 429s in a fresh session, that's also a valid PASS — it may just mean the rate limit reset. The key question is whether *when* 429s happen, the backoff is enforced. Inspect console output for `TtsRateLimitException` + "backing off" log lines if you can — grep `lib/services/app_tts_service.dart` for the log strings.
- Reference files:
  - `lib/services/tts_api_service.dart` — `TtsRateLimitException`
  - `lib/services/app_tts_service.dart` — `_prewarm()`, `_prewarming` flag, backoff logic
  - `TEAM_COORDINATION.md` §2026-04-20b and §2026-04-21 — prior context
