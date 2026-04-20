# Story Weaver QA Playwright Report
**Date:** 2026-04-20  
**Tester:** Claude Code (automated Playwright)  
**Target:** https://grand-light-production-68d9.up.railway.app  
**Viewport:** 1400 × 900 (primary)  
**Sessions:** 3 (context limits required splitting across sessions)

---

## Band Story Generation Results

| Band | Age Range | Result | `/generate-story` HTTP |
|------|-----------|--------|------------------------|
| 1 — Sprout | 3–5 | ✅ PASS | 200 confirmed |
| 2 — Explorer | 6–8 | ✅ PASS | 200 confirmed |
| 3 — Adventurer | 9–11 | ✅ PASS | 200 confirmed |
| 4 — Creator | 12–14 | ⚠️ PARTIAL | 200 confirmed; COPPA consent API [201] OK |
| 5 — Adolescent | 15–17 | ✅ PASS | 200 confirmed |
| 6 — Adult | 18+ | ❌ FAIL | Blocked — see BUG-001 |

---

## Bug Report

### BUG-001 — Adult Band: Create Story blocked for new users (CRITICAL)

**Component:** `lib/screens/wizard_steps/hero_creator_step.dart` — `_handleContinue()` line 601  
**Severity:** Critical — blocks all adult band story generation for new users  

**Root Cause:**  
`_handleContinue()` gates submission on `_hasAvatar`:
```dart
if (_isCreatingNew && !_hasAvatar) {
  // → "Please choose a look for your character first"
  return;
}
```
`_hasAvatar` is defined as:
```dart
bool get _hasAvatar => _generatedAvatar != null || _customAvatarFilePath != null;
```
The adult "Build Your Story" form (`CreativeBriefWidget`) has **no avatar generation UI** — it shows only `CharacterGender` (Boy/Girl) buttons which set `wizardData.characterGender` but do NOT set `_generatedAvatar`. As a result `_hasAvatar` is always `false` for new adult users.

**Observed behaviour:**  
- Selecting archetype chip → `aria-checked` updates correctly  
- Clicking "Create Story" → Flutter announces: *"Please choose a look for your character first"*  
- No `/generate-story` or `/create-character` network request fires  

**Note on gender buttons:**  
`GenderImageButton` uses `GestureDetector(onTap: …)` wrapped in `role="button"` semantic nodes. Clicking Boy/Girl correctly sets `wizardData.characterGender` (default `'Girl'`), but does not satisfy the `_hasAvatar` gate. The yellow border visible on "Girl" reflects the default `isSelected = characterGender == 'Girl'` visual state, not a user selection event.

**Reproduction:**  
1. Navigate to app, click "Let's start!"  
2. Select 18+  
3. Enter name, click Continue  
4. On "Build Your Story" form: select LOGIC ARCHITECT archetype  
5. Click "Create Story"  
6. Observe SnackBar: "Please choose a look for your character first"  

**Fix suggestion:**  
Either (a) remove the `!_hasAvatar` gate from `_handleContinue` for mature-band users who use `CreativeBriefWidget` (since they have no avatar page), or (b) add an avatar generation / selection widget to `CreativeBriefWidget`.

---

### BUG-002 — TTS Rate Limiting (429) During Session Warm-up

**Component:** `/tts/synthesize` endpoint  
**Severity:** Medium — degrades audio experience  

**Observed behaviour:**  
Console logs show repeated `429 Too Many Requests` on `/tts/synthesize` throughout test sessions (40+ occurrences in one session log). The app fires multiple TTS warm-up requests without backoff.

**Impact:** Real users navigating between screens may hear no audio for warm-up phrases if they exhaust the rate limit.

**Fix suggestion:** Add exponential backoff and/or per-session request deduplication to the TTS warm-up logic.

---

### BUG-003 — Stripe Subscription Status Returns 403 for Anonymous Users

**Component:** `/api/stripe/subscription-status/{userId}` endpoint  
**Severity:** Low — cosmetic console error; not user-visible  

**Observed:** `403 Forbidden` on subscription status calls for anonymous/unauthenticated user IDs. Expected behaviour would be `401` (unauthenticated) or `404` (no subscription record).

---

## Cross-cutting Regression Matrix

| # | Test | Result | Notes |
|---|------|--------|-------|
| 1 | Archetype chip visibility | ✅ PASS | All 4 chips visible; `aria-checked` updates on selection; yellow fill on active chip |
| 2 | Gendered images render | ✅ PASS | Boy/Girl character images load; Girl default-highlighted with yellow border |
| 3 | Gender press state registration | ❌ FAIL | See BUG-001 — visual state renders but `_hasAvatar` not set |
| 4 | TTS warm-up phrases | ⚠️ WARN | 429 rate limiting observed — see BUG-002 |
| 5 | COPPA consent — children bands | ✅ PASS | `/api/user/{anon}/consent [201]` fired for child bands |
| 6 | COPPA skipped — adult band | ✅ PASS | 18+ goes directly to "Set up your profile"; no COPPA footer shown |
| 7 | Console error audit | ⚠️ WARN | 403 Stripe (BUG-003), 429 TTS (BUG-002), Noto font warning |
| 8 | Noto font asset missing | ⚠️ WARN | Flutter warns: "Could not find a set of Noto fonts to display all missing characters" |

---

## Key Technical Findings

### Flutter Web Automation Constraints
- **Semantic overlay vs. glass-pane**: In accessibility mode, `flt-semantics-placeholder` click activates a semantic overlay. `FilterChip` widgets (`role="checkbox"`) correctly update `aria-checked` via semantic actions. `GestureDetector`-wrapped custom widgets (`role="button"`) fire visual hover/focus but do **not** propagate state changes through semantic actions.
- **Coordinate system**: CanvasKit renders visuals at slightly different viewport positions than the semantic overlay. Semantic node `getBoundingClientRect()` provides the correct Flutter layout position for glass-pane click targeting.
- **No-accessibility clicks**: `page.mouse.click(x, y)` in glass-pane mode (no accessibility) reliably hits widgets at their semantic/layout coordinates. Visual canvas position may differ by up to ~200px from layout position due to scroll offset.
- **Scroll behaviour**: `page.mouse.wheel()` correctly scrolls adult form content. Scroll does NOT reset archetype chip state.
- **Text input**: Without accessibility, `page.keyboard.type()` after `page.mouse.click()` on the text field correctly populates Flutter's `TextField` (DOM `<input>` created on focus).

### COPPA Flow
- Ages 3–17: `/api/user/{anon}/consent` POST [201] fires on age selection.
- Age 18+: No consent call; routes directly to "Set up your profile" screen.
- No sticky COPPA footer observed in adult band.

### API Endpoints Confirmed
| Endpoint | Status | When |
|----------|--------|------|
| `POST /api/user/{anon}/consent` | 201 | Child age selected |
| `GET /generate-story` | 200 | Bands 1–5 story generation |
| `GET /api/stripe/subscription-status/{userId}` | 403 | On load (anon user — expected) |
| `POST /tts/synthesize` | 429 | TTS warm-up (rate limited) |

---

## Screenshots Captured (this session, Band 6)

- `band6_clean_01_welcome.png` — Welcome screen (1400×900)
- `band6_clean_03_after_18plus.png` — "Set up your profile" screen
- `band6_clean_05_after_continue.png` — "Build Your Story" form with Alex populated
- `band6_clean_06_girl_clicked.png` — Girl visual selection (yellow border)
- `band6_clean_07_archetype_selected.png` — LOGIC ARCHITECT chip selected (yellow fill)
- `band6_clean_10_create_story_result.png` — Form after Create Story click (unchanged — blocked)

---

## Summary

**5 of 6 bands confirmed working** for `/generate-story [200]`. Band 6 (Adult) is blocked by a code-level bug where `_handleContinue()` requires an avatar that the adult form provides no UI to create. This is the primary critical finding of the QA engagement.

The TTS rate limiting (BUG-002) is a secondary concern that may degrade audio experience for real users under load.
