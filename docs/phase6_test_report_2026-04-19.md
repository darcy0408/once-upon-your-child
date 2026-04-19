# Phase 6 Test Report
**Date:** 2026-04-19  
**Tester:** Claude Code (automated — Playwright/Chromium + load audit)  
**App build:** localhost:60807 (Flutter web, dev server)  
**Backend:** localhost:5000 (Flask dev)

---

## Summary

| Area | Result |
|------|--------|
| Welcome + age picker | ✅ Pass |
| COPPA gate (Sprout) | ✅ Pass |
| Adult band visual/character/archetype | ✅ Pass |
| Companion images (adult brief wizard) | ❌ **FAIL — 7 images 404** |
| Load audit (mocked scenarios) | ❌ **FAIL — harness broken** |
| Real-API performance baseline | ❌ **Did not run** (blocked by harness bug) |
| Cross-browser: Firefox, WebKit | ⚪ Not verifiable (MCP Playwright = Chromium only) |
| Cross-browser: Edge | ⚪ Skipped (Chromium engine = same result) |
| Mobile: iOS Safari, Android Chrome | ⚪ Deferred — user will do manual pass |

**3 new bugs found. 1 test-harness bug found.**

---

## Detailed Findings

### ✅ Welcome Screen
- Dark purple background, STORY WEAVER branding, gold sparkle logo renders correctly
- "Let's start!" yellow CTA, "Parent" link top-right — both present
- Screenshot: `docs/phase6_artifacts/welcome_chromium.png`

### ✅ Age Picker
- All 6 bands visible: ages 3–11 as individual circles + 12–14 / 15–17 / 18+ as range pills
- "Older?" divider label present
- Screenshot: `docs/phase6_artifacts/age_picker.png`

### ✅ COPPA Gate — Sprout (age 4)
- Fires immediately after name entry for age < 13 ✓
- Correct text: "Your child (age 4) would like to use Story Weaver. As required by COPPA…"
- Scroll enforcement active before checkbox can be checked ✓
- "I am a parent/guardian" checkbox present (unchecked by default) ✓
- "Send to a grown-up" share link present ✓
- Screenshot: `docs/phase6_artifacts/sprout_wizard_entry.png`, `sprout_consent_scrolled.png`

### ✅ Adult Band (18+) — Visual + Character
- Skips COPPA gate correctly ✓
- **Distinct adult UX vs child bands confirmed:**
  - Name entry: "Set up your profile" / "What should we call you?" / "Continue →" (vs Sprout's "What's your name?" / "That's me!")
  - Wizard theme: near-black background (not childish dark purple), amber gold accents
  - Step labels: Character → Companions → Setting → Begin (adult-appropriate)
  - Heading: "Build Your Story / Define the parameters of your experience."
- **Character section:** Adult portrait art (realistic male/female faces) ✓
- **UX-A5 fixed:** "What does your character want more than anything?" prompt present ✓
- **BUG-A1 fixed:** CORE ARCHETYPE `*` required marker present ✓
- **Adult archetypes:** LOGIC ARCHITECT, VISION ARCHITECT, KINETIC SPECIALIST, ECOLOGICAL WHISPERER ✓ (not childish names)
- **Accordion sections:** CHARACTER & ROLE, PERSONALITY, CAST & COMPANIONS, WORLD & SETTING — all present
- Screenshots: `docs/phase6_artifacts/adult2_after_age_select.png`, `adult_wizard_archetypes.png`

---

## Bugs Found

### BUG-P6-01 — Companion Images 404 in Adult Brief Wizard 🔴
**Severity:** High — companions render broken/fallback for adult band  
**File:** `lib/companion_selector.dart`  
**Symptom:** 7 console 404s when CAST & COMPANIONS accordion expanded:
```
companions/dragon_normal.jpg (404)
companions/owl_normal.jpg (404)
companions/cat_normal.jpg (404)
companions/dog_normal.jpg (404)
companions/unicorn_normal.jpg (404)
companions/fox_normal.jpg (404)
companions/robin_normal.jpg (404)
```
**Root cause:** `lib/companion_selector.dart` (lines ~15–51) still references pre-rebrand generic filenames (`dog.jpg`, `cat.jpg`, `dragon.jpg` etc.). The companion rebrand (2026-04-18c/d) renamed all companions to named characters (`cinder`, `onyx`, `rockin_robin`, `tide` etc.) and moved files to band subdirectories, but this legacy widget was not updated.  
**Note:** `companion_selector_step.dart` (the newer per-band wizard) was correctly updated. Only the brief-style mature wizard uses the legacy `companion_selector.dart`.  
**Fix needed:** Update `lib/companion_selector.dart` companion definitions to use `AgeBandAssetResolver.companionPath()` with the new named files, matching the pattern already used in `companion_selector_step.dart`.

---

### BUG-P6-02 — Stale Age Persists in localStorage Across Sessions 🟡
**Severity:** Medium — wrong COPPA flow can trigger for returning users  
**Symptom:** After completing a Sprout (age 4) flow session, reloading the app and selecting 18+ from the age picker still triggers the COPPA consent screen showing "Your child (age 4)." The new age selection did not override the persisted age.  
**Reproduction:** 
1. Start as age 4 (enters COPPA gate)
2. Reload without clearing storage
3. Select 18+ from age picker
4. Submit name → COPPA gate appears with old "age 4"  
**Fix needed:** Age selection on the welcome screen should clear/overwrite previously persisted age state before navigating to name entry.

---

### BUG-P6-03 — Load Audit Harness Broken: Missing `is_under_13` on Mock User 🔴
**Severity:** High — the entire load audit produces invalid results  
**File:** `backend/tests/story_load_audit.py`, function `_auth_session_get()` (line ~252)  
**Symptom:** 100% HTTP 500 on all scenarios (sync fast path, timeout fallback, quota, real-API, concurrency ramp):
```
error: "'types.SimpleNamespace' object has no attribute 'is_under_13'"
```
**Root cause:** The mock user `SimpleNamespace` returned by `_auth_session_get` is missing `is_under_13` (and likely `declared_age`) which were added to the `User` model in the COPPA compliance work (2026-03-31, `backend/models/user.py:35`). `backend/middleware/auth.py:88` accesses `current_user.is_under_13` which crashes against the mock.  
**Fix:** Add missing fields to the mock:
```python
return SimpleNamespace(
    id="story-load-audit-user",
    email="story-load-audit@example.com",
    role="user",
    subscription_tier="premium",
    is_under_13=False,        # add
    declared_age=None,        # add
)
```
**Impact:** The `--real-api` run did NOT actually hit Gemini (every request 500'd before reaching AI); the 5 "real-API" requests returned in ~1ms each (not the expected ~60s). No real performance baseline was captured.

---

### BUG-P6-04 — Fallback Switchover Measurement Broken 🟡
**Severity:** Medium — monitoring gap  
**File:** `backend/tests/story_load_audit.py`, `measure_fallback_switchover()`  
**Symptom:** `fallback_switchover: total=1ms provider_sequence=unknown`  
**Root cause:** Blocked by BUG-P6-03 (500 before reaching provider logic), so `_perf` data is never populated. Secondary issue: even if the harness is fixed, the `provider_sequence` key may not be populated in the error path. Needs separate verification after BUG-P6-03 is fixed.

---

## Pre-Existing Issues (Not New)

| Issue | Status |
|-------|--------|
| `GET /api/stripe/subscription-status/...` → 403 for anonymous users | Pre-existing; visible in console on every load |
| `GET /api/stripe/...` 403 | Known — Phase 2 item #20 partial fix allows anonymous through `/api/subscription/status` but Stripe-specific endpoint still rejects |

---

## Cross-Browser Status

| Browser | Status | Notes |
|---------|--------|-------|
| Chrome (Chromium) | ✅ Tested | Primary test above |
| Edge | ⚪ Not run | Same Chromium engine; differences would be negligible |
| Firefox | ⚪ Not testable via automation | MCP Playwright only supports Chromium profile; would require standalone Playwright script or manual |
| Safari (WebKit) | ⚪ Not testable via automation | Same constraint |
| iOS Safari | ⚪ Deferred | Requires real device or BrowserStack |
| Android Chrome | ⚪ Deferred — user manual pass | |

---

## Bands Not Fully Walked (Wizard Interior)

Bands below were not navigated past name entry/COPPA gate due to automation constraints (Flutter CanvasKit + COPPA scroll gate):

| Band | Welcome/Age picker | COPPA gate | Wizard interior |
|------|-------------------|------------|-----------------|
| Sprout (3–5) | ✅ | ✅ fires correctly | ⚪ not navigated |
| Explorer (6–8) | ✅ | ✅ expected (< 13) | ⚪ not navigated |
| Adventurer (9–11) | ✅ | ✅ expected (< 13) | ⚪ not navigated |
| Creator (12–14) | ✅ | ✅ expected (12–13) | ⚪ not navigated |
| Adolescent (15–17) | ✅ | ⚪ not tested | ⚪ not navigated |
| Adult (18+) | ✅ | ✅ correctly skipped | ✅ full visual pass |

Recommend manual walkthrough for Sprout through Adolescent wizard interiors, particularly verifying:
- Sprout companion count = 4 (not 7+) — Phase 2 item #8
- Sprout feelings vocabulary = 5 items max — Phase 2 items #16–17
- Adolescent wizard theming (near-black teal, not purple) — UX-A1

---

## Load Audit Baseline

**Status:** Invalid — blocked by BUG-P6-03. All scenarios returned 100% errors.  
**Previous valid baseline:** `backend/tests/artifacts/story_load_audit_20260318T153543Z.json` (2026-03-18)  
**Action required:** Fix BUG-P6-03 and re-run before treating as a valid baseline.

Rate-limit reset check (runs independently of mock user) **did pass**:
- Limit: 2/s on probe route ✓
- 3rd request → 429 ✓  
- After 1.2s wait → 200 ✓

---

## Artifacts

```
docs/phase6_artifacts/
  welcome_chromium.png
  age_picker.png
  sprout_wizard_entry.png
  sprout_consent_scrolled.png
  adult2_after_age_select.png       ← adult "Set up your profile" screen
  adult_wizard_archetypes.png       ← adult Character & Role accordion
  adult_companions_expanded.png     ← Cast & Companions (broken images)
backend/tests/artifacts/
  story_load_audit_20260419T144853Z.json   ← invalid run (all 500s)
  story_load_audit_20260419T144853Z.md
```
