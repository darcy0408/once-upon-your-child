# MT-012 — Age-Gate Consolidation Refactor — Implementation Plan

> **Status:** READ-ONLY plan. Author: planning agent. Implementer: Opus.
> **Working directory:** `C:/dev/story-weaver-app`
> **Branch:** `main`
> **Date authored:** 2026-04-25
> **Reference docs:** `docs/MANUAL_TASKS.md` (MT-012), `docs/COPPA_AUDIT.md`, `docs/QA_PLAYWRIGHT_REPORT_2026-04-24.md` §MT-012

---

## 0. TL;DR — read this first

**The premise of MT-012 is partly stale.** `lib/screens/age_gate_screen.dart` no longer exists. It was deleted in commit `430563d` on 2026-04-21 ("BUG-007: delete dead age_gate_screen.dart (never instantiated)"). Today there is exactly **one** age-gate flow: `WelcomeScreen._handleContinue` (`lib/screens/welcome_screen.dart:1058`).

But MT-012 still has a real, COPPA-relevant payload that has not been resolved:

1. The compliance bug "13–17 path may not record consent correctly" **still exists** in `WelcomeScreen._handleContinue`, regardless of which file holds it.
2. The deleted `age_gate_screen.dart` had a different (better, in one specific way) consent treatment for 13–17 — a parent-acknowledgement dialog gated `recordConsent`. Welcome's current code records consent **unconditionally** for 13+ with `method: 'self_attested'`, and never asks for any acknowledgement.
3. A stale test (`test/goldens/key_screens_golden_test.dart:10,126`) still imports the deleted file. `flutter test test/goldens/` is broken on `main`.

Net: **the refactor work is small and surgical, not architectural.** No second screen to consolidate. The task is to (a) decide and implement the correct 13–17 consent semantic, (b) clean up the broken golden, (c) document the decision.

---

## 1. Investigation phase — what to read

Read in this order:

1. `lib/screens/welcome_screen.dart` (full file — 1383 lines). Focus on `_handleContinue` (line 1058–1158) and `_onAgeSelected` (line 233–266).
2. `lib/screens/parental_consent_screen.dart` (full file — 671 lines). Note the `_isUnder13` getter (line 39) and `_submitConsent` (line 550) which sets `method` based on under-13 status.
3. `lib/services/parental_consent_service.dart` (182 lines). `recordConsent` (line 68) is the single sink for compliance state — local prefs + best-effort POST to `/api/user/<id>/consent`.
4. `lib/main_story.dart:83-175` — `_AppEntryPoint` is the entry-point router. Note `_checkOnboarding` reads age + name + `needsReConsent` (cutoff `2026-03-21`).
5. `backend/middleware/auth.py:108-153` — `require_parental_consent` decorator. Only fires for `is_under_13` users; 13–17 bypass entirely. So the **frontend-side consent record for 13–17 has no backend gate enforcing it** — this is informational, not behavioral.
6. `backend/models/user.py:34-35` — `is_under_13` is a Boolean column derived from `declared_age`. No equivalent flag for 13–17.
7. `docs/sessions/2026-04-22-1216-7df8.md` — the session that created MT-012; confirms divergence framing was authored against the now-deleted file.
8. `TEAM_COORDINATION.md:376` — historical record of BUG-007 = `age_gate_screen.dart` deletion.
9. `test/goldens/key_screens_golden_test.dart:10, 123-136` — broken test that still references the deleted file.
10. `docs/QA_PLAYWRIGHT_REPORT_2026-04-24.md:105-108, 130-135` — Playwright observation that consent POST fires for age 12 but capture for age 16 was inconclusive.

**git archaeology required:** `git show 430563d^:lib/screens/age_gate_screen.dart` to recover the historical version of the deleted screen for comparison. (Already done in this plan — see §2.)

**Trace for callers:** `Grep` confirms only `main_story.dart:173` instantiates `WelcomeScreen`. There is no second entry point.

---

## 2. Diagnosis — exact behavioral divergence

### Current code path: `welcome_screen.dart:1058-1158` (`_handleContinue`)

| Cohort | Path | Consent recorded? | Method |
|---|---|---|---|
| <13 | `if (_selectedAge! < 13)` block lines 1067–1145 | ✅ Yes — only after parent completes `ParentalConsentScreen` and returns `granted == true`. `recordConsent` happens inside `ParentalConsentScreen._submitConsent` (line 553). | `'email_verified'` (under-13 path) |
| 13–17 | Falls through to lines 1147–1158 | ✅ Yes — unconditional, **no UI confirmation**. | `'self_attested'` |
| 18+ | Same fall-through, lines 1147–1158 | ✅ Yes — unconditional. | `'self_attested'` |

### Historical (deleted) `age_gate_screen.dart:_handleContinue` (per `git show 430563d^`)

| Cohort | Path | Consent recorded? | Method |
|---|---|---|---|
| <13 | `if (_selectedAge! < 13)` | ✅ Yes — same `ParentalConsentScreen` flow. | `'email_verified'` |
| 13–17 | `_captureParentalKnowledgeConsent()` dialog | **Conditional** — only if user tapped "I Understand" in a dialog ("If you are under 18, please make sure a parent or guardian knows you are using this app."). Cancel → no consent recorded, but the screen still completed. | `'self_attested'` |
| 18+ | Same dialog | Same — also gated behind the dialog. | `'self_attested'` |

### The divergence, concretely

The historical screen had an extra acknowledgement gate for `<18` users. The current `WelcomeScreen` does not. Two interpretations:

- **Interpretation A (current code is correct):** the dialog was vestigial UX cruft. Recording consent unconditionally for 13+ is *more* compliant — the record always exists. `'self_attested'` is honest about the method. ✅ This is the present behavior.
- **Interpretation B (current code is buggy):** 13–17 are still minors. `'self_attested'` for a 14-year-old without any parental acknowledgement is misleading on the consent record. The deleted screen at least surfaced "tell a parent" — current welcome screen does not.

**The actual MT-012 framing in `docs/MANUAL_TASKS.md:37`** says "users aged 13–17 on the welcome path may not record COPPA consent correctly." That framing is **factually wrong as of today's code** — they always record consent. The Playwright report's "inconclusive" observation for age 16 is consistent with consent firing but the network log not being retained, not with consent being skipped.

**However**, two adjacent issues are real and worth fixing inside this ticket:

1. **`'self_attested'` is recorded with no UI evidence the user attested anything.** The age picker tap is the only interaction. There is no checkbox, dialog, or notice acknowledging "I confirm I am this age" / "a parent knows." This is a thin compliance posture for the 13–17 cohort.
2. **`ConsentRecord` rows for 13–17 users are written to the backend** (via the best-effort POST in `parental_consent_service.dart:90`) but `require_parental_consent` only enforces them for under-13 (`auth.py:130`). So the backend has rows it doesn't gate on. Not a bug, but a coherence gap worth knowing.

### The actual COPPA risk

COPPA itself (15 USC §6501) covers under-13 only. 13–17 is **not federally COPPA-regulated** — it is a "best practice / state law" zone (e.g., California AADC, FTC's age-appropriate design guidance). The under-13 path in `WelcomeScreen._handleContinue` is correct and properly gated. The 13–17 path is a UX-and-policy question, not a federal-COPPA bug.

### File:line citations

- `lib/screens/welcome_screen.dart:1067` — under-13 branch
- `lib/screens/welcome_screen.dart:1147-1158` — 13+ branch (no acknowledgement, immediate `recordConsent`)
- `lib/screens/welcome_screen.dart:1150-1153` — `recordConsent(method: 'self_attested')`
- `lib/screens/parental_consent_screen.dart:553-558` — under-13 consent submission
- `lib/services/parental_consent_service.dart:68-101` — `recordConsent` (local + backend POST)
- `backend/middleware/auth.py:130` — backend COPPA gate (only `is_under_13`)
- `test/goldens/key_screens_golden_test.dart:10, 123-136` — broken import (this is concrete CI breakage)

---

## 3. Design options

### Option A — Minimal: clean stale references, document current behavior, add lightweight 13–17 attestation

**Scope:**
- Delete the `AgeGateScreen` import + golden test in `test/goldens/key_screens_golden_test.dart`.
- Add a single-tap acknowledgement step to `_handleContinue` between the age tap and the unconditional `recordConsent` for 13–17 (e.g., a `showDialog` similar to the deleted screen's "I Understand"). 18+ skips it.
- Update `docs/COPPA_AUDIT.md` with the rationale and close MT-012.

**Tradeoffs:**
- COPPA risk: **unchanged for under-13** (already correct). Improved attestation evidence for 13–17.
- Refactor scope: ~50 LOC across 2 files + 1 doc.
- Test surface: small. One golden test deleted; one new dialog-existence widget test added.
- Backwards-compat: zero impact on already-onboarded users (age + consent already persisted; new dialog only fires on first onboarding).

### Option B — Centralize: extract a shared `AgeGateController` service used by `_handleContinue`

**Scope:**
- Move the age-cohort branching logic out of `WelcomeScreen` into a `lib/services/age_gate_controller.dart`. Method: `Future<bool> resolveConsent(BuildContext, age)` returning whether to proceed.
- `WelcomeScreen` calls into it; future screens (re-consent, parent override) reuse the same logic.

**Tradeoffs:**
- COPPA risk: net-neutral if behavior preserved; introduces non-zero risk that the extraction subtly changes the under-13 path.
- Refactor scope: 150–250 LOC, new file, new test surface. Requires careful diff of pre/post behavior.
- Test surface: large — every consent path needs unit tests against the new service.
- Backwards-compat: zero on persisted state, but flow is more invasive to verify.

### Option C — Status quo + deletion of MT-012 as already-resolved

**Scope:**
- Delete the broken golden test entry only.
- Close MT-012 with a note: "premise stale, 13–17 always records consent today; backend `require_parental_consent` only fires for under-13 by design."

**Tradeoffs:**
- COPPA risk: unchanged. The 13–17 attestation thinness is left as-is.
- Refactor scope: 1 LOC plus doc.
- Test surface: removes broken test only.
- Backwards-compat: zero.

---

## 4. Recommended path — **Option A**

Pick A. Reasoning:

- Darcy is solo. Option B's refactor risk is not justified by its payoff — there is no second screen to consolidate.
- Option C leaves the 13–17 attestation thin. Even if it's not federal-COPPA-required, recording `'self_attested'` for a 14-year-old without any UI affirmation is the kind of detail a regulator's auditor or a state AG's office under California AADC would flag. A 2-second "I am this age and a parent knows I'm using this app" dialog costs nothing and produces real attestation evidence in the consent record.
- A is the **lowest-risk option that addresses the MT-012 framing** ("13–17 records consent correctly"). After A: the 13–17 record is recorded *and* tied to a documented user gesture. That's a defensible posture.

---

## 5. Step-by-step implementation (Option A)

Order matters — do top to bottom in one PR.

### Step 1 — Verify the working tree

```
git status
git log --oneline -1 -- lib/screens/age_gate_screen.dart   # should be 430563d
git log --oneline -1 -- test/goldens/key_screens_golden_test.dart
ls lib/screens/age_gate_screen.dart                          # should not exist
```

### Step 2 — Add a 13–17 acknowledgement to `_handleContinue`

File: `lib/screens/welcome_screen.dart`

In `_handleContinue` (line 1058), between the `< 13` block (ends line 1145) and the `13+` consent recording (lines 1147–1158), insert a guard for the 13–17 cohort. Use a `showDialog<bool>` that:

- Title: "Just so you know"
- Body: "Story Weaver is for ages 13 and up. If you're under 18, please make sure a parent or guardian knows you're using this app."
- Actions: "Cancel" → returns false → reset `_submitting` and `_step = 1` (back to age picker). "I understand" → returns true → proceed.
- For age >= 18: skip the dialog, proceed directly.

Pseudocode insertion at line 1147 (before the existing fall-through):

```dart
// 13–17: brief acknowledgement before recording self-attested consent.
// 18+: skip dialog and proceed.
if (_selectedAge! < 18) {
  if (!mounted) return;
  AppTtsService.instance.stop();
  final acknowledged = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A0533),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Just so you know',
          style: GoogleFonts.fredoka(color: _goldColor, fontSize: 22)),
      content: const Text(
        'Story Weaver is for ages 13 and up. If you\'re under 18, please '
        'make sure a parent or guardian knows you\'re using this app.',
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _goldColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('I understand'),
        ),
      ],
    ),
  );
  if (acknowledged != true) {
    if (mounted) setState(() { _submitting = false; _step = 1; });
    return;
  }
}
```

The existing `recordConsent(... method: 'self_attested')` at line 1150 stays as-is. The acknowledgement is now a hard prerequisite for the 13–17 cohort.

**Why not change the `method` string?** The historical screen used `'self_attested'`; the parental consent screen distinguishes via `_isUnder13` (line 39). Keeping the same string preserves backend `ConsentRecord.consent_method` field continuity. No backend migration needed.

### Step 3 — Fix the broken golden test

File: `test/goldens/key_screens_golden_test.dart`

- Line 10: delete `import 'package:story_weaver_app/screens/age_gate_screen.dart';`
- Lines 19–32: keep `_StubConsentService` (other tests may reference it; check).
- Lines 123–136: delete the entire `testWidgets('Age gate screen', ...)` block.
- Optional: delete the corresponding `test/goldens/age_gate_screen.png` if present.

Run `flutter analyze test/goldens/` after. Verify `flutter test test/goldens/key_screens_golden_test.dart` runs (will likely produce other golden mismatches unrelated to MT-012 — only the compile error from the missing import is in scope).

### Step 4 — Add a widget test for the new 13–17 dialog

File: `test/screens/welcome_screen_age_gate_test.dart` (new file)

Two cases:
- Tap age 16 → dialog appears with "Just so you know" title.
- Tap "I understand" → `recordConsent` is called once with `age: 16, method: 'self_attested'`.
- Tap "Cancel" → `recordConsent` is NOT called; flow returns to age picker.

Stub `ParentalConsentService` with a recording mock (mirror `_StubConsentService` pattern from the goldens file).

### Step 5 — Update docs

- `docs/COPPA_AUDIT.md`: add a row to the checklist or a sub-bullet under §1 noting that 13–17 users now see a parent-awareness acknowledgement dialog before `'self_attested'` consent is recorded.
- `docs/MANUAL_TASKS.md`: flip MT-012 to `done`. Append `(closed by <session-id>)`. Note that the original framing was stale (`age_gate_screen.dart` already deleted in `430563d`) and the actual fix was the 13–17 attestation gate + golden test cleanup.
- `TEAM_COORDINATION.md`: add a session-close row.

### Step 6 — No backend changes

Verify by re-reading `backend/middleware/auth.py:130` — it gates only `is_under_13`. The 13–17 acknowledgement is purely a frontend evidentiary gesture. No model changes, no migration, no new endpoints.

### Step 7 — No data migration for existing users

`_AppEntryPoint._checkOnboarding` (`lib/main_story.dart:110`) reads `age` + `savedName` from prefs and skips welcome entirely if both exist. Already-onboarded 13–17 users will not see the new dialog — they have already passed the gate with their existing consent record. This is intentional (do not retroactively re-gate them; they already self-attested by completing the original flow).

If a stricter posture is desired later: bump `_reConsentCutoff` (currently `2026-03-21`) for under-13 only — the existing logic at `main_story.dart:119-122` does not re-consent 13+ users. Leave as-is for this PR.

---

## 6. Test plan

### Per-cohort manual test matrix (clear app state between each)

| Cohort | Age tapped | Expected | Verify |
|---|---|---|---|
| Under-13 | 4 (Sprout) | Existing flow: Welcome → name → age → splash → `ParentalConsentScreen` → grant → home | `POST /api/user/<id>/consent` fires with `consent_method: 'email_verified'`. No regression. |
| Under-13 | 12 (Creator, exactly under 13) | Same as above | `consent_method: 'email_verified'`, `child_age: 12` |
| **Edge: exactly-13** | 13 — but the picker exposes `12 – 14` (value `12`) and `15 – 17` (value `16`); there is **no UI for raw 13** | n/a — 13 is unselectable in the current picker. Note this; do not "fix" in this PR. | n/a |
| 13–17 | 16 (via `15 – 17` pill, value 16) | New dialog "Just so you know" appears; tapping "I understand" → consent recorded; tapping "Cancel" → returns to age picker | `POST /api/user/<id>/consent` fires once with `consent_method: 'self_attested'`, `child_age: 16` only after "I understand". On Cancel, no POST. |
| 18+ | 21 (via `18+` pill) | No dialog. Direct flow to home. | `POST /api/user/<id>/consent` fires with `consent_method: 'self_attested'`, `child_age: 21`. No dialog interception. |

**Edge: cancel from dialog after tapping age.** Verify that:
- `_submitting` resets to false.
- `_step` returns to 1 (age picker).
- TTS is stopped.
- Tapping a different age then re-confirming the dialog persists the *new* age (not the cancelled one).

**Edge: backgrounded mid-dialog.** Verify the dialog survives app resume on web (Material `barrierDismissible: false` + `if (!mounted) return` guards).

### Playwright (production Railway URL only)

Reference: `memory/reference_playwright_target.md` — local DDC dev server lacks COOP/COEP headers; only Railway prod works for Playwright. Use `page.mouse.click(x, y)` + `page.keyboard.type(text, {delay})` — synthetic DOM events do not work in Flutter CanvasKit.

Sequence:
1. Open Railway prod URL in incognito (clear `localStorage` first via `page.evaluate(() => localStorage.clear())`).
2. Splash → name "QA16" → age picker → tap `15 – 17`.
3. Wait for title splash (7s timer) or click to advance.
4. Capture network log starting at this point.
5. **Expect:** dialog "Just so you know" visible. Screenshot.
6. Click "I understand" coordinates.
7. **Expect in network log:** `POST /api/user/anon_<id>/consent` with body `{"child_age": 16, "consent_method": "self_attested", "allow_photo_avatar": false}` returning `201`. Screenshot.
8. Repeat with age `21` (`18+` pill). **Expect no dialog**, direct to home, same POST with `child_age: 21`.
9. Repeat with age `4`. **Expect existing `ParentalConsentScreen`** unchanged. POST should fire with `consent_method: 'email_verified'`.

### Flutter unit/widget tests

- `test/screens/welcome_screen_age_gate_test.dart` (new) — dialog presence + cancel/confirm semantics for 13–17.
- `test/goldens/key_screens_golden_test.dart` — should compile (broken import removed). Other goldens unchanged.
- Run `flutter analyze` — should be clean.

### CI signal

After this PR, `flutter test test/goldens/key_screens_golden_test.dart` should at minimum compile (any pre-existing golden image diffs are out of scope and tracked separately).

---

## 7. Rollout / rollback considerations

### Single PR — yes

The change is contained:
- 1 source file modified (`lib/screens/welcome_screen.dart`)
- 1 test file modified (`test/goldens/key_screens_golden_test.dart`)
- 1 test file added (`test/screens/welcome_screen_age_gate_test.dart`)
- 3 doc files updated (`docs/MANUAL_TASKS.md`, `docs/COPPA_AUDIT.md`, `TEAM_COORDINATION.md`)

Ship as one PR. No staging/feature flag needed — the under-13 path is unchanged, and the 13–17 dialog is additive UX with no schema impact.

### Rollback

Trivial — revert the welcome_screen.dart hunk. No DB rows need cleanup. The new dialog is fail-safe: cancelling it just sends the user back to the age picker; no half-state is persisted.

### No migration needed

- Already-onboarded under-13 users: untouched (re-consent cutoff `2026-03-21` already exists for them at `main_story.dart:102`).
- Already-onboarded 13–17 users: untouched. Their existing consent rows remain valid; the new dialog only fires for first-time onboarding.
- Backend `ConsentRecord` table: no schema change, same `consent_method` strings.

### Production verification

After merge + deploy, Darcy should sanity-check on Railway prod with one fresh-session age-16 walkthrough, confirming the dialog appears and the POST fires (Phase C of the Playwright plan).

---

## 8. Risks / open questions to escalate to Darcy before coding

1. **Premise of MT-012 is stale.** The task description says "two diverging paths" and references `lib/screens/age_gate_screen.dart`. That file was deleted in `430563d` (2026-04-21) — five days before this plan was written. Confirm with Darcy whether MT-012 should be: (a) re-scoped to the 13–17 attestation thinness identified in §2 (this plan's recommendation), (b) closed as "premise resolved by 430563d," or (c) something else not yet articulated. **Do not start coding until Darcy confirms.**

2. **Picker has no UI for exact age 13.** `_olderAgeEntries` jumps from `12 – 14` (value 12) to `15 – 17` (value 16). A user who is literally 13 has no truthful choice. This is pre-existing and not in MT-012's framing; flag to Darcy whether to address in this PR (probably no — out of scope, separate ticket).

3. **`'self_attested'` semantics for a 14-year-old.** Even with the new acknowledgement dialog, the consent record's `consent_method` is `'self_attested'`. For California AADC posture, Darcy may eventually want a third method (e.g., `'minor_attested_with_parent_notice'`). Flag for v1.1 — do not change in this PR.

4. **Backend `require_parental_consent` does not gate 13–17.** This is by design (federal COPPA scope). If Darcy later wants 13–17 gated server-side, it requires a new column on `User` (e.g., `is_minor` derived from `declared_age < 18`) and a new decorator. Out of scope for MT-012.

5. **The deleted `_captureParentalKnowledgeConsent` dialog allowed Cancel to record consent.** Re-read of the historical code (§2) shows that on Cancel, the function exited without recording. This plan replicates that semantic. Confirm with Darcy this is the intended behavior — i.e., a 14-year-old who cancels the dialog returns to the age picker rather than getting silently logged-in with no consent record.

6. **Playwright network-capture-per-navigate fragility.** `docs/QA_PLAYWRIGHT_REPORT_2026-04-24.md:107` notes that the consent POST capture for age 16 was "inconclusive" because Phase C network logs were not retained. Darcy should ensure the network log is captured continuously across the full age-16 walkthrough during verification (not per-navigate).

7. **Re-consent cutoff (`2026-03-21`) only re-prompts under-13 users.** If the privacy policy is updated again and 13–17 users should be re-prompted, the logic at `main_story.dart:119` needs widening (`if (age != null && age < 13)` → `if (age != null && age < 18)`). Out of scope for MT-012; flag for whoever next bumps the policy.

---

## Critical Files for Implementation

- `C:/dev/story-weaver-app/lib/screens/welcome_screen.dart`
- `C:/dev/story-weaver-app/lib/screens/parental_consent_screen.dart`
- `C:/dev/story-weaver-app/lib/services/parental_consent_service.dart`
- `C:/dev/story-weaver-app/test/goldens/key_screens_golden_test.dart`
- `C:/dev/story-weaver-app/docs/MANUAL_TASKS.md`
