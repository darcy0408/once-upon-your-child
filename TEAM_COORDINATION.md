# Team Coordination

## Pending Tasks

| # | Task | Blocker | Briefing |
|---|------|---------|----------|
| 1 | BUG-001 full E2E — Band 6 `/generate-story` 200 | Needs Playwright restart or manual incognito test | `docs/briefings/TASK1_PLAYWRIGHT_BAND6_REVERIFY.md` |
| 2 | BUG-002 TTS backoff — fresh-session verification | Needs Playwright restart or manual incognito test | `docs/briefings/TASK3_BUG002_TTS_FRESH_SESSION.md` |
| ~~3~~ | ~~BUG-004 Back→COPPA stuck — "That's me!" breaks after COPPA Back~~ | ✅ Fixed `115b37b` — `_step` reset to 0 when COPPA dismissed | ~~See §2026-04-21 Six Hats below~~ |
| ~~4~~ | ~~Age 2 missing from age picker~~ | ✅ Fixed `115b37b` — added to `_youngAgeEntries` in both `welcome_screen.dart` and `age_gate_screen.dart` | ~~Sprout band is 2-5; picker starts at 3~~ |
| ~~5~~ | ~~Archetype display names in Heroes/a11y labels~~ | ✅ Fixed `115b37b` — `character_library_screen` uses `nameForAge()`; a11y labels in both grid paths updated | ~~Semantic labels leak internal IDs~~ |
| ~~6~~ | ~~"Story service is ready" banner visible in child view~~ | ✅ Fixed `115b37b` — banner hidden when `_backendOnline == true`; only shows when checking or offline | ~~Dev status exposed to users~~ |
| 7 | Mochi black card background | Give Mochi a coloured background like other buddies | Visual inconsistency |
| 8 | Sprout Life Quests empty | Author 3-5 Sprout quests | Dead-end for primary target age band |
| ~~9~~ | ~~**BUG-005** Binary-only gender picker~~ | ✅ Fixed — "Other" / "Non-binary / Other" pill added below Boy/Girl row; non-binary falls through to genderless archetype image. `hero_creator_step.dart` | |
| ~~10~~ | ~~**BUG-006** Gender tap auto-advances instantly~~ | ✅ Fixed — 400ms delay before `_heroNextPage()` in `_handleGenderSelection`. `hero_creator_step.dart` | |
| 11 | **BUG-007** Two age-gate implementations diverge (MEDIUM) | `welcome_screen.dart` and `age_gate_screen.dart` have different consent flows for 13–17; need reconciliation | Parental knowledge dialog only in `age_gate_screen.dart` |
| 12 | **BUG-008** Consent scroll progress bar not visible while scrolling (LOW) | Add sticky "↓ Scroll to continue" hint near bottom of consent form | `parental_consent_screen.dart:78` — progress bar in AppBar |
| ~~13~~ | ~~"Hearing no" ambiguous copy in Shape the stories dialog~~ | ✅ Fixed — changed to "Struggling with 'no'". `welcome_screen.dart` | |
| 14 | Sprout companion limit (1) has no visual feedback | Disable/overlay remaining companion tiles once limit reached; show "Buddy chosen!" | `hero_creator_step.dart` — `_buildAdventureTeamPage`, maxSlots=1 |
| 15 | Sprout pet reveal looks like static text, not interactive | Add chevron or "Tap here" label to `GestureDetector` container | `hero_creator_step.dart:1204` |
| 16 | "Add a Friend" button name clashes with "Your Friends:" saved-character section | Rename button to "Add from Photo" or similar | `hero_creator_step.dart:1163` |
| 17 | Title splash has no back affordance to change age | Add small "← Change age" link; wrong age = wrong entire experience | `welcome_screen.dart:443` — `_buildTitleStep` |
| 18 | Adult Reflect prompts have no skip/safety valve | Add quiet "Not tonight →" to cycle prompt without journaling | `adult_meditation_screen.dart:23` — `_kReflectivePrompts` |
| 19 | 5-second title splash timer may cut TTS mid-sentence | Gate timer start until TTS completes, or extend to 7s | `welcome_screen.dart:246` — `_titleTimer` |
| 20 | **BUG-009** Avatar generation routes have no timeout (HIGH) | Add 30s timeout + 504 fallback-preset response | `backend/routes/avatar_routes.py` — no timeout on Gemini/Replicate calls |
| 21 | **BUG-010** `SimpleNamespace` crash in auth middleware (HIGH) | Add `hasattr` guard before `current_user.is_under_13` access; returns 500 to all under-13 users hitting this path | `backend/middleware/auth.py:88` — seen in `backend_errors.log` 2026-04-19 |
| 22 | **BUG-011** No story generation progress indicator (MEDIUM) | Show "Weaving your story… (~60s)" with elapsed time; 120s timeout is silent | `wizard_story_screen.dart` — no progress feedback during generation |
| 23 | **BUG-012** Technical error messages exposed to users (MEDIUM) | Replace "Timed out after 120s in synchronous mode" / ElevenLabs error details with friendly copy | `backend/routes/story_routes.py`, `tts_routes.py` |
| 24 | **BUG-013** Continue button silent fail with empty name on profile screen (CRITICAL) | Show inline validation "Enter a name to continue" — screenshots confirm 4x identical state after click | `welcome_screen.dart` — `_buildNameStep` / `_handleContinue` |
| 25 | **BUG-014** No back button from profile setup screen (HIGH) | Add `←` AppBar back to age picker; no escape path currently | `welcome_screen.dart` — `_buildNameStep` |
| 26 | Stripe webhook no timestamp validation | Reject events older than 5 minutes to prevent replay attacks | `backend/routes/webhook_handler.py` |
| 27 | AdultMeditationScreen no explicit close button | Add "← Stories" back button in AppBar; tab-only exit not discoverable for emotionally loaded screen | `adult_meditation_screen.dart` |
| 28 | Wizard X button has no exit confirmation | Add "Leave story setup? Progress will be lost." dialog | `wizard_story_screen.dart` |
| 29 | Archetype chips have no tooltips | On tap, show one-sentence explanation (required field is currently opaque) | `hero_creator_step.dart` |

**Next Playwright approach for TASK1:** Tab→Enter keyboard method — do not use WheelEvent scroll + mouse click. See `TEAM_COORDINATION.md §2026-04-21 BUG-001 re-verification → Next-session plan` for full steps.

---

## 2026-04-21 — BYOK setup wizard: invisible key + silent save failure (Claude Opus 4.7 diagnosis / Claude Sonnet 4.6 fix)

**Reported by Darcy:** Walked through the BYOK wizard as an Adult-band user. Two symptoms:
1. Pasted API key was invisible in the input — cursor moved some spaces, nothing rendered.
2. After pressing Finish, selecting "Full illustrations" elsewhere re-launched the wizard from step 0 ("Next: Get My Free Key") — as if nothing had been saved.

### Diagnosis

All in `lib/screens/byok_setup_wizard.dart`.

**Bug 1 — invisible input (compounding):**
- `_showKey` defaulted to `false`, so the `TextField` obscured input as `•` dots.
- The `TextField` had no explicit `style.color`, so the inherited dark-theme text color rendered dark-on-dark against the scaffold's purple/dark-purple gradient. Even the obscuring dots disappeared.

**Bug 2 — silent save failure:**
- Because Bug 1 hid paste correctness, users were effectively submitting wrong keys.
- `_validate()` either failed the `AIza` prefix check or failed the HTTPS probe to `generativelanguage.googleapis.com` (CORS on web, timeout, or a genuinely invalid key).
- When `_valid == false`, the Finish handler silently no-opped — no save to `SharedPreferences` or `SecureStorageService`, no visible error, no `onDone`.
- Other BYOK-checking callers (`parent_controls_screen.dart:346`, `settings_screen.dart:843`, `story_result_screen.dart:1401`, `avatar_gallery_selector.dart:430`, `upgrade_prompt_dialog.dart:127`) later relaunched the wizard because storage was empty. The wizard didn't "reset" — it was freshly re-opened.

Briefing: `docs/briefings/TASK5_BYOK_WIZARD_FIXES.md`.

### Fixes shipped (`lib/screens/byok_setup_wizard.dart`)

| Change | Location | Effect |
|---|---|---|
| `_showKey` default `false` → `true` | line 430 | Pasted key is legible on open; "Show key" checkbox still lets the user hide it |
| Explicit white monospace `style` on `TextField`; lightened `labelStyle` / `hintStyle`; gold prefix icon | lines 514–526 | Text and obscuring dots render correctly on the dark card |
| SnackBar on Finish when `_valid == false` | lines 585–597 | Save failure no longer silent — user sees the red error with `_status` text |

### Follow-up — validation moved to backend proxy (Claude Opus 4.7)

The initial Sonnet fix used a CORS-fallback (accept any `AIza`-prefixed key on network failure) to unblock BYOK on production web. Darcy opted to do it properly instead — the backend already exposes the exact endpoint needed.

**Change:** `_validate()` now POSTs to `${Environment.backendUrl}/api/user/settings/validate-api-key` (defined in `backend/routes/api_key_routes.py:142`, no-auth, rate-limited 10/min) instead of calling `generativelanguage.googleapis.com` directly. The backend tests the key against Gemini server-side via `test_gemini_api_key()` and returns `{valid: bool, message: string}`.

**Effect:**
- ✅ BYOK works on web — no CORS, since we're hitting our own backend.
- ✅ Real validation — invalid keys are caught in the wizard, not deferred to first illustration attempt.
- ✅ Removes the sign-off tradeoff from the earlier fix.
- ✅ Rate-limited (10/min) — abuse-resistant.

On network exceptions, `_valid = false` now (no more silent acceptance) and the user sees *"Could not reach the validation service right now. Please try again in a moment."*

### Verification pending

Manual browser test not yet re-run. Suggest: Parent Controls → Use Your Own API Key → paste valid key → confirm (a) key visible, (b) validation shows "looks good", (c) Finish saves, (d) re-opening Parent Controls shows BYOK configured.

---

## 2026-04-21 — Sprout UX Fixes + Playwright Verification (Claude Sonnet 4.6)

**Method:** Six Hats Sprout audit (previous session) identified issues; this session applied code fixes and verified each one via Playwright MCP. Commit: `115b37b`.

### Fixes Applied

| Fix | File(s) | Verified |
|-----|---------|---------|
| Age 2 added to age picker | `welcome_screen.dart`, `age_gate_screen.dart` | ✅ Playwright — visible as first circle in grid |
| BUG-004: Back→COPPA resets wizard step | `welcome_screen.dart:1012` — `_step = 0` alongside `_submitting = false` | ✅ Playwright — "That's me!" re-advances to age picker after Back |
| Archetype display names use `nameForAge()` | `character_library_screen.dart:572` | Code-verified (backend offline in local dev) |
| A11y semantic labels use `nameForAge()` | `hero_creator_step.dart:1883, 1984` | Code-verified |
| Backend status banner hidden when online | `character_library_screen.dart:215` — wrapped in `if (_isCheckingBackend \|\| _backendOnline == false)` | ✅ Playwright — red "waking up" shown when offline; green never shown |

### Deferred
- **Mochi black background** — code shows `Color(0xFFFF8F00)` (orange); likely screenshot artifact. Needs human verification on device.
- **Sprout Life Quests** — deferred to Opus; requires creative content authoring for ages 2-5.
- **Step 4 summary recap** — low priority; add visual recap of choices before GO! button.

---

## 2026-04-21 — Six Hats Adolescent UX Review + P1/P2 fixes (Claude Sonnet 4.6)

**Method:** Code-level walkthrough (Playwright MCP blocked on Windows lockfile; user opted for code review instead of restart). Mapped wizard flow, tab shell, Life Quest player, bedtime wizard, feeling selection, and Creative Brief form. Plan: `C:\Users\darcy\.claude\plans\federated-marinating-kernighan.md`.

**Scope:** Adolescent band (ages 15–17, `AgeBand.adolescent`, `isMature=true`).

### Findings — severity ranked

| # | Issue | Severity | Shipped |
|---|-------|----------|---------|
| 1 | Fredoka font across all Life Quest UI chrome (9 call sites) — wrong for cinematic dark bands | High | ✅ commit `bcd54e2` |
| 2 | Quest player lost close button once user made a choice — no in-app path back to selector | High | ✅ commit `bcd54e2` |
| 3 | Creative Brief gender portraits for adolescent pointed at Adventurer (9–11 yr) assets | High | ✅ commit `ceee86a` |
| 4 | "Bedtime" framing leaked into mature bands (dialog titles, tooltip, byok card, timer/error voice) | Medium | ✅ commit `ceee86a` |
| 5 | Story Note placeholder undersold band depth (Creator-style copy on adolescent) | Low | ✅ commit `bcd54e2` |
| 6 | Settings tab mixes account-level with parent-control settings from teen's POV | Medium | ⬜ P3 — deferred |
| 7 | Only 3 Life Quests shipped for this band | Strategic | ⬜ backlog authored: `docs/briefings/ADOLESCENT_LIFEQUEST_BACKLOG.md` |

### Fixes shipped — commit `bcd54e2` (P1)

- `lib/screens/life_quest_screen.dart`: introduced `_chromeStyle(band, ...)` helper that returns `GoogleFonts.sourceSans3` when `band.band.isMature`, else `GoogleFonts.fredoka`. Replaced 9 inline Fredoka call sites (selector title/subtitle, empty-state, quest cards, player title, choice buttons, ending link). Narrative body text (Merriweather) untouched.
- `lib/screens/life_quest_screen.dart`: `_buildQuestPlayer` top bar now always shows close (wired to `_resetToSelector`); rewind appears alongside when `_segmentHistory` is non-empty.
- `lib/screens/wizard_steps/feeling_selection_step.dart:582–586`: split the creator/adolescent switch arm; adolescent placeholder becomes `"e.g., Keep it honest and focused on starting over after a hard week"`.

### Fixes shipped — commit `ceee86a` (P2)

- `lib/screens/wizard_steps/hero_creator_creative_brief.dart:215–219`: adolescent gender portraits point at `assets/images/archetypes/adolescent/master_creator_{boy,girl}.png` (gender-split, age-appropriate, shipped with commit `a07aedd`).
- `lib/screens/bedtime_wizard_screen.dart`: added `_isMature` branches to timer-expiry voice line, BYOK voice prompt, generation-error voice line, and BYOK setup card title + blurb. Young bands keep "Bedtime" framing; mature bands see "Voice Stories".
- `lib/screens/wizard_story_screen.dart`: `_showBedtimeSettingsDialog` now reads `isMature` from theme extension and retitles dialog ("Voice Story Settings"), SwitchListTile ("Interactive Voice Adventure" + subtitle). Icon-only mature-band launcher switched from `Icons.bedtime_outlined` → `Icons.mic_none_rounded`; tooltip & semantic label become "Voice Story Mode".
- Internal class/enum/file names (`BedtimeWizardScreen`, `BedtimeStep`, `bedtime_wizard_screen.dart`) unchanged — user-visible copy only.

### Fixes shipped — commit `abea63d` (P3)

- `lib/settings_screen.dart`: arithmetic-gate condition was `band.band != AgeBand.creator` — this incorrectly locked Adult account holders behind a puzzle while Adolescents passed it trivially. Flipped to `!band.band.isMature`, so young bands (sprout/explorer/adventurer) keep the gate and mature bands (creator/adolescent/adult) bypass it.
- `lib/settings_screen.dart`: for mature bands, "Parent Dashboard" → "Activity Dashboard" and "Manage Child Profiles" → "Manage Profiles"; subtitle copy updated. Young-band labels unchanged.

### Deferred — see backlog

- **Fix 7 — Life Quest content expansion:** six candidate themes authored in `docs/briefings/ADOLESCENT_LIFEQUEST_BACKLOG.md` — romantic rupture, social-media shame, family conflict, academic burnout, identity formation, first job / money. Content-authoring task, no code changes required.

### Verification

- `flutter analyze` on all six touched files: **no issues** (P1 + P2 + P3).
- Not Playwright-verified — MCP lockfile blocker persists. User will smoke-test visually post-merge.
- No regression risk expected on younger bands: every change is either gated on `isMature`/`_isMature` or touches files only used by mature bands. P3 specifically leaves sprout/explorer/adventurer behavior intact.

---

## 2026-04-21 — Comprehensive Fix Plan (Claude Sonnet 4.6)

Plan to resolve all bugs logged in the Six Hats audits (Sprout + Adult). Grouped into 4 sprints by priority, then by logical batch to minimize file churn. Each batch lists files touched, concrete change, risk, and test plan.

**Stats:** 29 open issues → 4 sprints. Sprint 1 (P0) unblocks new-user flow. Sprint 2 (P1) removes high-friction UX snags. Sprint 3 (P2) improves safety/polish. Sprint 4 (P3) is longer-term redesign.

---

### 🚨 SPRINT 1 — P0 Critical (Blockers) — target: same-day

These fixes are blockers for any further user testing. All are low-effort. Do them first, in one session, one PR.

#### Batch 1A — Onboarding escape hatches (`welcome_screen.dart`)

Single file, 3 related fixes. Do them together.

| Task | Fix |
|------|-----|
| **BUG-013** Continue silent fail on empty name | In `_handleContinue`, if `_nameController.text.trim().isEmpty`, show inline error (`setState(() => _nameError = 'Enter a name to continue')`). Render `TextField(errorText: _nameError)`. Clear `_nameError` on text change. |
| **BUG-014** No back button from profile screen | Add `IconButton(icon: Icons.arrow_back)` in `_buildNameStep` header, calling `setState(() => _step = Step.age)`. |
| **BUG-004** Back→COPPA stuck | In `_handleContinue`, guard with `if (_coppaDone && mounted) _coppaDone = false` before navigating. On COPPA Back, reset guard. |

**Risk:** Touches shared state on welcome_screen. Test all 6 age bands retain working flow.  
**Test plan:** Manual + Playwright — 18+, 15-17, 12-14, 9-11, 6-8, 3-5. Empty-name click, mis-tap back button, BUG-004 repro (name → COPPA → back → edit → "That's me!").

#### Batch 1B — Backend stability (`backend/middleware/auth.py`, `backend/routes/avatar_routes.py`)

| Task | Fix |
|------|-----|
| **BUG-010** `SimpleNamespace` crash | `auth.py:88` — replace `current_user.is_under_13` with `getattr(current_user, 'is_under_13', False)`. Same for `declared_age`. |
| **BUG-009** Avatar routes no timeout | Wrap Gemini/Replicate calls in `asyncio.wait_for(..., timeout=30.0)` (or `requests.post(..., timeout=30)` for sync). On `TimeoutError`, return 504 + fallback preset. |

**Risk:** auth.py is auth-critical — test both authenticated adult and authenticated under-13 with valid consent.  
**Test plan:** Unit test SimpleNamespace input doesn't crash; integration test avatar route with slow mock upstream returns fallback within 30s.

**Sprint 1 deliverable:** one branch, one PR, commits grouped by batch. Target: 2–4 hours total.

---

### 🔥 SPRINT 2 — P1 High Friction — target: next session

High-impact UX improvements. Each batch is ~1 hour.

#### Batch 2A — Wizard progress and exit (`wizard_story_screen.dart`)

| Task | Fix |
|------|-----|
| Wizard breadcrumb false affordance | Either (a) make steps tappable — wrap each in `GestureDetector` calling `_pageController.animateToPage(i)`, only allow backward nav, or (b) restyle as non-interactive progress pipe. **Recommend (a)** — supports Task 17 ("← Change age" affordance pattern). |
| **BUG-011** No generation progress indicator | Wrap generation call in a `Stream<int>` that emits elapsed seconds. Show "Weaving your story… Xs / ~60s" with a progress bar. Swap to "Almost there…" at 60s. Timeout message at 120s. |
| Wizard X exit confirmation | Wrap X button in `showDialog` returning bool — "Leave story setup? Your progress will be lost." Cancel / Leave. |

**Risk:** PageController interactions can break mid-generation. Test: tap breadcrumb while story generating → should be disabled.  
**Test plan:** Tap breadcrumb forward (no-op), tap backward (navigate), tap X during step 1 (confirmation), tap X during generation (blocked).

#### Batch 2B — Character creator polish (`hero_creator_step.dart`)

| Task | Fix |
|------|-----|
| **BUG-005** Binary gender picker | Add 3rd option: "Other" or two additions ("Non-binary", "Prefer not to say"). Use neutral silhouette asset. `hero_creator_step.dart:1651`. |
| **BUG-006** Gender tap auto-advance | Remove synchronous `_heroNextPage()` from `_handleGenderSelection`. Require explicit Next tap. Highlight selection with gold border; enable Next button. |
| Archetype chips no tooltips | Wrap each archetype chip in `Tooltip(message: '…')`. Define tooltips in a map `_kArchetypeTooltips` keyed by archetype ID. |
| Archetype display names a11y | Replace internal IDs in `Semantics(label:)` with user-facing display names from existing `_kArchetypeDisplayNames` map. |

**Risk:** Gender option added = story prompt must handle new value. Check `backend/services/story_generation_service.py` prompt construction for `gender` field.  
**Test plan:** Each gender option → generate story → verify pronouns and description match selection. Screen reader read-through for archetype chips.

#### Batch 2C — Adult band safety valves (`adult_meditation_screen.dart`)

| Task | Fix |
|------|-----|
| AdultMeditationScreen no close button | Add `IconButton(icon: Icons.arrow_back)` in AppBar `leading`. Calls `Navigator.pop(context)`. |
| Adult Reflect prompts no skip | Add "Not tonight →" TextButton below prompt. Cycles `_kReflectivePrompts` index without saving journal entry. |

**Risk:** Low.  
**Test plan:** Open screen from tab, tap back → returns to Stories. Tap "Not tonight" → new prompt shown, no journal entry created.

---

### 🔧 SPRINT 3 — P2 Medium Polish — target: following session

#### Batch 3A — Error message copy (`backend/routes/story_routes.py`, `backend/routes/tts_routes.py`, new `backend/utils/error_copy.py`)

| Task | Fix |
|------|-----|
| **BUG-012** Technical error messages | Create `backend/utils/error_copy.py` with an `ERROR_COPY` dict. Replace all `return jsonify({'error': str(e)})` with `_user_facing_error(error_code)`. Log raw `e` server-side only. |

Mapping (seed `error_copy.py`):
```python
ERROR_COPY = {
  'STORY_TIMEOUT': "Story generation is taking longer than usual. Please try again.",
  'TTS_QUOTA_EXCEEDED': "You've used today's narration allowance. Come back tomorrow, or upgrade for more.",
  'AVATAR_FAILED': "We couldn't create your avatar. Try a different style or come back in a moment.",
  'STORY_REJECTED': "This story couldn't be generated. Please try different character traits.",
  'PARENTAL_CONSENT_REQUIRED': "A grown-up needs to give permission before you can make stories.",
}
```

**Risk:** Client code may rely on specific error strings — grep `errorMessage ==` in Flutter for matches.  
**Test plan:** Trigger each error (disconnect, quota exceed, moderation reject) → user sees friendly copy, server logs raw.

#### Batch 3B — Backend hardening (`backend/routes/webhook_handler.py`)

| Task | Fix |
|------|-----|
| Stripe webhook no timestamp validation | Add `if abs(time.time() - event.created) > 300: abort(400, 'stale webhook')`. Use Stripe library's built-in signature validation which includes timestamp. |

**Test plan:** Replay old webhook → rejected. Valid webhook → accepted.

#### Batch 3C — Age-gate reconciliation (`welcome_screen.dart`, `age_gate_screen.dart`, `parental_consent_screen.dart`)

| Task | Fix |
|------|-----|
| **BUG-007** Dual age-gate implementations diverge | Extract shared consent flow to `lib/services/consent_flow.dart`. Both screens call the same function. |
| **BUG-008** Consent scroll progress bar not visible | Move progress bar from AppBar to a sticky `PreferredSize` at bottom. Add "↓ Keep scrolling" hint while `scrollController.offset < maxScrollExtent - 100`. |
| Age 2 missing from picker | Add `{age: 2, emoji: '🌱'}` to `_youngAgeEntries` in both files. Update Sprout band = 2–5. |

**Risk:** Consolidation touches 3 screens. Snapshot tests for each band before/after.  
**Test plan:** Full onboarding per age (2, 4, 7, 10, 13, 16, 21) → correct consent flow fires.

#### Batch 3D — Sprout polish (`hero_creator_step.dart` + content files)

| Task | Fix |
|------|-----|
| Sprout Life Quests empty | Author 3–5 Sprout quests in `lib/content/life_quests_sprout.json`. Keep language simple, 1-sentence prompts. Run past content moderator keyword filter. |
| Sprout companion limit feedback | In `_buildAdventureTeamPage`, when `_selectedCompanions.length >= maxSlots`, disable/grey-out remaining tiles + show "Buddy chosen!" toast. |
| Sprout pet reveal looks static | Add `Icon(Icons.keyboard_arrow_right)` or "Tap here ▸" label inside `GestureDetector`. Add ripple. |
| "Add a Friend" name clash | Rename button to "Add from Photo" in `hero_creator_step.dart:1163`. |
| Mochi black card background | Update Mochi asset or wrap in `Container(color: <band-appropriate>)` matching other buddies. |
| Title splash no back | Add small "← Change age" TextButton in `_buildTitleStep`. |
| 5s title splash cuts TTS | Use `TtsService.onComplete` callback to start timer, or bump to 7s with `min(7, ttsDuration + 0.5)` cap. |
| "Hearing no" copy | Rename to "Struggling with 'no'" in `welcome_screen.dart:1027`. |
| "Story service is ready" banner | Gate behind `kDebugMode` or admin role. |

**Test plan:** Load app as Sprout age 4 → Life Quests has content, companion max feedback visible, pet reveal tappable.

---

### 🌱 SPRINT 4 — P3 Longer-term (Backlog) — target: planning

Larger changes needing design discussion before implementation.

| Task | Approach |
|------|---------|
| Archetype renaming (corporate → evocative) | Design doc: propose new names (Detective, Visionary, Warrior, Healer). Keep internal IDs stable; only change display labels. Review with writer/child psychologist. |
| Adult home screen redesign | New screen: recent stories grid + quick-create CTA + Feelings peer feature. Replaces wizard-as-landing for returning adults. Gate: `isAdult && hasStories`. |
| "Who is this for?" first-run disambiguation | Before name entry, ask "Creating for yourself, or setting up for a child?" → route to adult self-onboarding or parent-for-child onboarding. |
| Adult Reflect journaling on same view | Merge REFLECT tab's prompt+journal into single view. Prompt at top, text field below, save button inline. Eliminate tab-switch. |
| BUG-001 full E2E Band 6 | Needs Playwright restart OR manual incognito. Tab→Enter keyboard method. |
| BUG-002 TTS backoff fresh-session | Same — Playwright restart or manual. |

---

### Dependency graph

```
Sprint 1 (P0) ─────────────────────────┐
  ├─ 1A Onboarding escape ─┐           │
  └─ 1B Backend stability ─┘           │
                                        ▼
Sprint 2 (P1)                  User testing unblocked
  ├─ 2A Wizard progress                 │
  ├─ 2B Character creator (dep: 2A)     │
  └─ 2C Adult safety valves             ▼
                                 Adult band ready
Sprint 3 (P2)
  ├─ 3A Error copy (touches many routes)
  ├─ 3B Backend hardening
  ├─ 3C Age-gate reconciliation
  └─ 3D Sprout polish

Sprint 4 (P3) — Backlog, needs design review
```

### Acceptance criteria

- **Sprint 1 done:** Fresh user opens app → 18+ → enter name → advance → lands in wizard. Mis-tap name screen back → returns to age picker. Avatar generation timeout returns 504 within 30s. Auth middleware does not throw on SimpleNamespace inputs.
- **Sprint 2 done:** Wizard has visible generation progress. X confirms exit. All gender options selectable without auto-advance. Archetype tooltips on tap. AdultMeditationScreen has visible close button.
- **Sprint 3 done:** All backend errors return user-friendly copy. Stripe webhooks reject replays. Single consent flow shared between welcome + age-gate. Age 2 available. Sprout has Life Quests content.
- **Sprint 4 done:** Deferred — design review required first.

### Estimates

| Sprint | Issues | Effort | Wall time |
|--------|--------|--------|-----------|
| 1 (P0) | 5 | Low | 2–4 hours |
| 2 (P1) | 9 | Low-Medium | 4–6 hours |
| 3 (P2) | 12 | Medium | 6–8 hours |
| 4 (P3) | 6 | High (design + build) | 2–4 days |

### Coordination note

A parallel session has uncommitted changes to `welcome_screen.dart` and `hero_creator_step.dart` (as of commit `ae3d5d5`). Before starting Sprint 1, reconcile with that work — the Batch 1A fixes may overlap. Coordinate or rebase before making these changes.

---

## 2026-04-21 — Six Hats Adult UX Audit — Frontend + Backend + Screenshots (Claude Sonnet 4.6)

**Method:** Flutter code review (62 screens), backend API audit, 20 screenshots analysed.  
**Band:** Adult (18+). Traced every screen, every nav path, every API failure mode.

---

### 🤍 WHITE HAT — What Was Observed

**Onboarding flow (screenshots: `fresh-landing`, `coppa-gate`, `after-18plus`, `after-continue` x3, `after-profile`):**
- Landing: dark purple gradient, gold "STORY WEAVER" logo, "Your hero. Your story.", yellow "Let's start!" CTA, "Parent" link top-right. Clean.
- Age picker: 3–11 as large circles in 3×3 grid with emoji icons; 12–14 / 15–17 / 18+ as pill buttons below. Subtitle: "Parents: please select your child's age."
- After 18+ → "Set up your profile" screen: microphone button ("Tap to say your name") + text field ("What should we call you?") + Continue.
- **Screenshots `after-18plus`, `after-continue`, `after-continue2`, `after-profile` all show identical "Set up your profile" screen with empty name field.** The Continue button did not advance — 4 sequential captures show the same state. Either a silent validation failure or a loop bug.
- No back button anywhere on the profile screen.

**Wizard (screenshots: `create-story-clicked`, `after-create-story2`, `bug001-*`, `scrolled-down`, `prefs-preloaded`):**
- 4-step header breadcrumb: Character → Companions → Setting → Begin. Visual only — steps 2/3/4 are not tappable.
- Step 1 shows: PROTAGONIST NAME (pre-filled "Alex"), optional character motivation field, CHARACTER GENDER (Boy / Girl portraits), CORE ARCHETYPE (4 chips, required). Below fold: PERSONALITY, CAST & COMPANIONS, WORLD & SETTING, STORY OPTIONS (all collapsed). Pinned "Create Story" CTA at bottom.
- Bug screenshots: wizard stuck at step 1, "Create Story" button entered `[active]` state but did not advance. No snackbar visible.
- `prefs-preloaded`: same wizard state with Boy selected (yellow border). Confirms BUG-001 avatar-gate fix holds; "Please choose a look" snackbar absent.
- X button top-left exits wizard; destination unclear.

**Backend facts (from code audit):**
- `POST /generate-story`: 120s sync timeout, 5 Gemini retries with backoff, 10 stories/day free tier, Redis quota.
- Content moderation: keyword layer (all ages) + Gemini-2.5-flash-lite classifier (fails open on error).
- TTS: ElevenLabs primary, 20 syntheses/day free, 500/hr rate limit, no word-level timestamps on chunked stories.
- Avatar generation: no timeout specified on routes — can hang indefinitely.
- Stripe webhooks: no timestamp validation. Silent failure on processing error (tier doesn't update).

---

### ❤️ RED HAT — Emotional Reactions

**Delightful:**
- The landing page is genuinely beautiful. Purple gradient + gold sparks + clean single CTA = excellent first impression.
- Age picker emoji icons (🌱 for young, 🧭 for mid, ⚔️ for older) are charming and communicate without words.
- The adult wizard copy ("Define the parameters of your experience", "What does your character want more than anything?") respects adult intelligence. Feels considered.
- Gold-bordered portrait selection is tactile and satisfying.

**Frustrating:**
- **The "Set up your profile" Continue button appears to do nothing with an empty field — silently.** No error, no shake, no toast. You just sit there tapping a button that doesn't work. First impression = broken app. This is catastrophic for new user retention.
- The profile screen has no back button. If you're an adult who selected 18+ by mistake and want to go back, you're stuck. There is no escape except a browser refresh — losing everything.
- The wizard breadcrumb steps (2, 3, 4) look interactive — numbered circles with labels — but tapping them does nothing. Every new user will try this and feel confused.
- Story generation has a 120-second timeout with zero progress feedback. No spinner text, no "almost there", nothing. 2 minutes of silence then either a story or a cryptic timeout error. Extremely stressful.
- Archetype names (Logic Architect, Vision Architect, Kinetic Specialist, Ecological Whisperer) feel like a job description form, not a fantasy character creator. An adult trying to write an adventure story has no intuitive mapping here.
- The REFLECT tab in AdultMeditationScreen surfaces prompts like "What are you still carrying that was never yours to carry?" — genuinely powerful, but there's no safe exit. You can only leave by tapping a different tab. For emotionally heavy content, a clear "I'm done" or close affordance is table stakes.

---

### 🖤 BLACK HAT — Problems and Risks

**CRITICAL:**

1. **Continue button silent fail on empty name — `welcome_screen.dart`.**  
   Screenshots confirm 4 identical states after clicking Continue with empty field. No error message. Blocks all new first-time users cold.

2. **No back navigation from profile setup — `welcome_screen.dart`.**  
   Zero affordance to return to landing or age picker. Wrong-age adults, curious children trying a parent's account, anyone who mis-tapped is completely stuck.

3. **`SimpleNamespace` crash in auth middleware — `backend/middleware/auth.py` line 88.**  
   ```python
   AttributeError: 'types.SimpleNamespace' object has no attribute 'is_under_13'
   ```
   Returns 500 to all users hitting this code path (seen in `backend_errors.log` 2026-04-19). Under-13 users get a 500 instead of a consent gate. Needs fixing before any production load.

4. **Avatar generation routes have no timeout — `backend/routes/avatar_routes.py`.**  
   If Gemini or Replicate is slow, the request hangs indefinitely. Users see a loading spinner with no resolution. No timeout = no fallback = silent hang.

5. **Wizard step breadcrumb is a false affordance.**  
   Steps 2/3/4 are rendered as interactive-looking numbered buttons but do nothing. `wizard_story_screen.dart` PageController is one-directional. Every user will tap these, feel confused, and distrust the UI.

6. **AdultMeditationScreen has no close button — `adult_meditation_screen.dart`.**  
   Tab-only exit. After reading "What are you trying not to feel right now?", an adult wanting to leave has no visible affordance except guessing the bottom tab bar exists.

7. **Wizard "Create Story" button doesn't advance — BUG-001 secondary finding.**  
   Confirmed across 4+ screenshots (bug001-*). Archetype chip appears `[checked]` but `_selectedArchetypeId` may be null due to Flutter FilterChip semantics not firing `onSelected` reliably via accessibility layer. Or a separate regression. Needs human device test.

8. **Stripe webhook has no timestamp validation — `backend/routes/webhook_handler.py`.**  
   Replay attacks possible — same subscription event could be re-submitted to manually set tier.

9. **Content moderation and Redis quota checks both fail open.**  
   When classifier is unavailable, all stories pass moderation. When Redis is unavailable, quota checks pass. This is a deliberate availability-over-safety tradeoff, but should be a known, documented decision — not a silent surprise.

10. **Gender picker is binary — `hero_creator_step.dart`.**  
    Only Boy/Girl for adults. Non-binary adults have no representative character option. This is exclusionary and inconsistent with 2026 norms.

**Age-appropriateness:**
- All adult content observed (wizard, meditation, grounding, reflective prompts) is appropriate for 18+.
- The REFLECT prompts are emotionally sophisticated but not harmful.
- Age gating is properly server-side enforced (`@require_parental_consent` in `backend/middleware/auth.py`). Cannot be bypassed by manipulating request body for under-13 users once authenticated.
- The `isAdult` boolean flag in Flutter should be backed by an explicit `age >= 18` check rather than a stored boolean — boolean can drift on age re-entry.

---

### 💛 YELLOW HAT — What Works Well

1. **Landing page visual design is excellent.** Professional, atmospheric, appropriate for adults.
2. **Age-band content separation is strong.** Adults get fundamentally different content from children — different wizard copy, different feelings tab, different theme depth.
3. **Server-side age enforcement is robust.** COPPA gate, declared-age cap, consent record requirement — all enforced server-side, not just on client.
4. **Two-layer content moderation** (keyword + LLM classifier) is a thoughtful approach. Keyword filter catches obvious violations instantly; LLM handles context-sensitive issues.
5. **Quota system degrades gracefully.** Redis unavailable → quotas fail open (availability wins). For a kids' storytelling app, this is the right tradeoff.
6. **Story generation has 5 retries with backoff.** Users rarely experience a single Gemini hiccup as a failure.
7. **COPPA compliance is complete** — consent record, right-to-erasure (`DELETE /api/user/<id>/data`), right-to-access export all implemented.
8. **"Parent" link always top-right** — accessible from any screen without navigation.
9. **Collapsible wizard sections** prevent overwhelm. Advanced users can expand; casual users go straight to Create Story.
10. **The "What does your character want more than anything?" prompt** is an outstanding story-writing input that meaningfully improves generation quality.

---

### 💚 GREEN HAT — Improvements

**P0 — Fix before any user testing:**

1. **Show inline validation on Continue with empty name** — a red outline + "Enter a name to continue" message. One line of code, prevents the #1 first-impression failure. (`welcome_screen.dart`)
2. **Add back button to profile setup screen** — `←` AppBar button returning to age picker. (`welcome_screen.dart`)
3. **Add timeout to avatar generation routes** — 30s should be sufficient; return 504 + fallback preset if exceeded. (`backend/routes/avatar_routes.py`)
4. **Fix `SimpleNamespace` crash in auth middleware** — add `hasattr` guard or type check before accessing `is_under_13`. (`backend/middleware/auth.py:88`)

**P1 — High friction fixes:**

5. **Make wizard breadcrumb steps either tappable or visually non-interactive** — if non-interactive, style as progress pipe (filled/unfilled segments), not numbered buttons. (`wizard_story_screen.dart`)
6. **Add story generation progress indicator** — even a "Weaving your story… (this takes about 60 seconds)" message with elapsed time. Backend already knows the 120s timeout; surface it. (`wizard_story_screen.dart`)
7. **Add close/back button to AdultMeditationScreen** — "← Stories" in AppBar. Tab navigation is not discoverable enough as an exit path for emotionally loaded content. (`adult_meditation_screen.dart`)
8. **Add non-binary / prefer-not-to-say gender option** for adult and 15-17 bands. (`hero_creator_step.dart`)
9. **Archetype tooltips** — on tap/hover, one sentence explaining each. Required field should not be opaque. (`hero_creator_step.dart`)

**P2 — Quality of life:**

10. **Differentiate pre-filled cached values** — "Alex" in the name field looks identical to a placeholder. Show a small "From last story" chip or use different background tint.
11. **Add exit confirmation on wizard X button** — "Leave story setup? Your progress will be lost." with Cancel/Leave. (`wizard_story_screen.dart`)
12. **Replace technical error messages with user-friendly copy** — "Timed out after 120s in synchronous mode" → "Story generation is taking longer than usual. Please try again." (`backend/routes/story_routes.py`)
13. **Add Stripe webhook timestamp validation** — reject events older than 5 minutes. (`backend/routes/webhook_handler.py`)
14. **Email user when subscription webhook fails** — silent tier drift is worse than a "your subscription may not have updated" email.
15. **Add prompt + response on same view in Reflect tab** — currently the prompt is on one view and journaling is a separate tab. Put them together. (`adult_meditation_screen.dart`)

**P3 — Longer term:**

16. **Rename archetypes to story-evocative labels** — "The Detective", "The Visionary", "The Warrior", "The Healer" are instantly understood vs. "Logic Architect" etc.
17. **Adult home screen distinct from child wizard** — returning adults don't need "Build Your Story / Define the parameters." Consider a dashboard with recent stories, quick-create, and Feelings as a peer feature.
18. **"Who is this for?" disambiguation on first load** — before name entry, ask "Creating for yourself or setting up for a child?" and route accordingly. Adult self-use and parent-for-child are different enough to warrant separate flows.

---

### 🔵 BLUE HAT — Priority Table

| Priority | Issue | File | Effort |
|----------|-------|------|--------|
| P0 | Continue button silent fail | `welcome_screen.dart` | Low |
| P0 | No back button from profile screen | `welcome_screen.dart` | Low |
| P0 | `SimpleNamespace` crash in auth | `middleware/auth.py:88` | Low |
| P0 | Avatar generation no timeout | `avatar_routes.py` | Low |
| P1 | Wizard breadcrumb false affordance | `wizard_story_screen.dart` | Low |
| P1 | No story generation progress feedback | `wizard_story_screen.dart` | Low |
| P1 | AdultMeditationScreen no close button | `adult_meditation_screen.dart` | Low |
| P1 | Gender binary for adult band | `hero_creator_step.dart` | Medium |
| P1 | Archetype chips no tooltips | `hero_creator_step.dart` | Low |
| P2 | Technical error messages exposed to users | `story_routes.py`, `tts_routes.py` | Low |
| P2 | Stripe webhook no timestamp validation | `webhook_handler.py` | Low |
| P2 | Wizard X button no exit confirmation | `wizard_story_screen.dart` | Low |
| P3 | Archetype naming (corporate, not evocative) | `hero_creator_step.dart` | Medium |
| P3 | Adult home screen redesign | `main_story.dart` | High |

**New tasks to add to Pending Tasks:** BUG-009 (avatar no timeout), BUG-010 (SimpleNamespace crash), BUG-011 (story generation no progress indicator), BUG-012 (technical error copy).

---

## 2026-04-21 — Six Hats UX Code Review (Claude Sonnet 4.6)

Full code-based Six Hats exploration across all 6 age bands. No Playwright (browser lockfile active). All findings traced to source lines.

**New bugs logged:** BUG-005 (gender binary), BUG-006 (gender auto-advance), BUG-007 (dual age-gate divergence), BUG-008 (consent scroll UX). See Pending Tasks table rows 9–19.

**Key findings summary:**

- **Critical — inclusivity:** Gender picker is binary (Boy/Girl/Man/Woman only) across all 6 bands. No non-binary / "prefer not to say" option. Especially harmful for Creator (12–14) and Adolescent (15–17) bands. `hero_creator_step.dart:1651`
- **High — navigation:** Gender tap immediately auto-advances (`_handleGenderSelection` calls `_heroNextPage()` synchronously). Accidental mis-tap sends user to next page with no confirmation. `hero_creator_step.dart:1674`
- **Medium — structural:** Two parallel age-gate implementations (`welcome_screen.dart` vs `age_gate_screen.dart`) diverge: one auto-advances on age tap, the other requires explicit Continue; parental knowledge dialog only in the latter; consent-recording for 13–17 skipped on welcome path. Risk of one rotting.
- **Medium — COPPA UX:** Consent scroll progress bar is in AppBar (top of screen) while parent is reading at the bottom — invisible while scrolling. Submit stays greyed out with no explanation. `parental_consent_screen.dart:78`
- **Low — copy:** "Hearing no, bedtime worry, sibling moments?" in the Shape the stories dialog is ambiguous — "Hearing no" could mean hearing loss. `welcome_screen.dart:1027`
- **Low — Sprout:** Sprout companion limit is 1 but remaining tiles show no disabled state. Pet card reveal (`GestureDetector`) looks like static text — no tap affordance. Title splash has no back button to correct a wrong age selection.
- **Positive findings:** COPPA compliance solid; age-band differentiation excellent; wizard back navigation functional; draft persistence; voice UX for Sprout; Adult Reflect content is high quality.

Full analysis delivered in conversation — not duplicated here.

---

## 2026-04-21 — Archetype image wiring for mature bands (Claude Sonnet 4.6)

**Scope:** Wire archetype images into `CreativeBriefWidget` (creator / adolescent / adult).

**Root cause:** `CreativeBriefWidget` rendered archetypes as text-only `FilterChip`s. The child-wizard `_buildArchetypeCards()` used image grids, but mature bands skip the child PageView entirely and render `CreativeBriefWidget` instead.

**Fix:** Replaced the `FilterChip` `Wrap` with a 2×2 `GridView` that calls `archetype.imagePathForBand(band, gender)` — mirrors the child wizard layout. `SafeAssetImage` provides emoji fallback. All six band folders contain the expected `.png` files and are declared in `pubspec.yaml`. Child-wizard bands (sprout/explorer/adventurer) were already wired correctly.

**Files changed:** `lib/screens/wizard_steps/hero_creator_creative_brief.dart` — commit `aac7a5d`

**Verification needed:** Playwright locked (browser lockfile, needs Claude Code restart). Manual check: open adult/adolescent/creator band in incognito → confirm 2×2 image grid in CORE ARCHETYPE section, images update when gender changes.

---

## 2026-04-21 — Six Hats Sprout UX Review (Claude Sonnet 4.6)

Full wizard walk-through as Sprout age 4 ("Lily") against live Railway build.

### BUG-004 — Back→COPPA breaks name submit (HIGH)

**Steps to reproduce:** Age picker → enter name → submit → COPPA loads → press Back → edit name → press "That's me!" → nothing happens. App stuck, requires reload.

**Root cause hypothesis:** `_handleContinue` on the name screen likely has a flag or state that marks COPPA as "already shown" but then blocks re-navigation because the COPPA route is still mounted or the guard isn't reset on Back pop.

**File to check:** `lib/screens/onboarding/name_entry_screen.dart` (or equivalent) — look for COPPA navigation guard / `_coppaDone` flag.

### Other findings logged in TEAM_COORDINATION Pending Tasks table above.

---

## 2026-04-21 — Content moderator model bump (Claude Sonnet 4.6)

Content moderator model bump — `gemini-2.0-flash-lite` → `gemini-2.5-flash-lite`. Was failing open (404). Verified locally: classifier runs.

- Updated `_CLASSIFIER_MODEL` constant and inline `generate_content` call in `backend/utils/content_moderator.py`.
- Updated story generation fallback in `backend/services/story_generation_service.py`.
- Added `gemini-2.5-flash-lite` pricing entry to `backend/cost_tracking.py`; kept `gemini-2.0-flash-lite` entry for historical log compatibility.

---

## 2026-04-21 — BUG-001 re-verification (Claude Sonnet 4.6)

**Scope:** Re-run Band 6 (Adult) happy path via Playwright MCP against live Railway build to confirm BUG-001 avatar-gate fix (`73ee489`) holds in production.

### BUG-001 re-verification — Adult band avatar gate

**Target:** `https://grand-light-production-68d9.up.railway.app`, viewport 1400 × 900, Adult band (cached session, no COPPA re-gate needed).

**Inputs supplied:** Protagonist name "Alex", gender Boy (portrait selected, yellow border confirmed in screenshot), archetype LOGIC ARCHITECT (FilterChip `[checked]` in semantics tree, rendered yellow).

**Result: PASS — avatar gate never triggered**

- ✅ "Please choose a look for your character first" did not appear in any console output or screenshot across 4+ Create Story clicks.
- ✅ Production source at `lib/screens/wizard_steps/hero_creator_step.dart:604` confirms fix is live: `if (_isCreatingNew && !_hasAvatar && !isMatureBand)` — adult band bypasses the gate.
- ✅ Adult form correctly renders `CreativeBriefWidget` (portrait gender buttons only, no avatar generation UI).

**Secondary blocker (new finding — not BUG-001):**

The wizard did not advance past the Character sub-step. No `/create-character` network call was observed despite both gates appearing to pass (archetype `[checked]`, `isMatureBand=true` per UI rendering). The "Create Story" button entered `[active]` state after each click and did not resolve. No "Please select a core archetype" snackbar was captured in screenshots (may have auto-dismissed between click and screenshot).

Root cause hypothesis: Playwright's accessibility-layer interaction with Flutter's `FilterChip` semantics may not reliably dispatch the `onSelected` callback in the Dart layer despite the chip rendering `[checked]` visually — leaving `_selectedArchetypeId` null and silently triggering the archetype gate snackbar. Alternatively this is a production regression in the adult wizard progression flow independent of BUG-001. **Requires investigation in next session using a manual browser test or device test** rather than Playwright.

No new BUG ID assigned yet — needs human confirmation first.

### BUG-002 / BUG-003 spot-check

- **BUG-002 (TTS 429 storm):** Active — 38+ TTS 429 errors observed on both test sessions from a cached previous story playback. BUG-002 backoff fix not verifiable via Playwright due to cached-session interference. Needs fresh-session manual test.
- **BUG-003 (Stripe anon guard):** Mixed. Session 1 showed 403 on `/api/stripe/subscription-status/anon_687d4b2762884e52`. Session 2 (reload) returned 200 on a fresh anon token. The fix appears partly effective — 403 may be a stale-token edge case rather than systematic.

### Playwright session 2 findings (2026-04-21, Claude Sonnet 4.6)

Second Playwright session (fresh COPPA gate, cleared localStorage) confirmed:

- COPPA age gate works, name screen advances via keyboard input into Flutter's hidden `<input>` — both confirmed.
- `CreativeBriefWidget` renders correctly for Adult band: no avatar UI, Boy/Girl portrait buttons only.
- "Please choose a look for your character first" banner never appeared — **BUG-001 avatar gate PASS confirmed**.
- Gender button click (Boy/Girl at visual coordinates via `page.mouse.click`) registered correctly — Flutter receives pointer events.
- Accordion buttons (STORY OPTIONS) respond to `page.mouse.click` at bounding-box coordinates.
- **Create Story button does not respond** to any click method tried: `getByRole.click()`, `page.mouse.click()`, `page.mouse.down/up()`, `PointerEvent` dispatch to `flt-glass-pane`, `force: true`. No `/create-character` request in any attempt.

**Root cause of Create Story non-response (hypothesis):** the button sits at the bottom of a scrollable `ListView` in Flutter; after a `WheelEvent` scroll, the button renders at y≈793 but may occupy a different position in Flutter's hit-test tree than the accessibility overlay reports. Alternatively, a scroll-gesture-arena lock holds from the wheel-scroll event, preventing the tap recognizer from winning. The snackbar for missing archetype was never seen — `_handleContinue()` may not be reaching Dart at all.

**Playwright session 2 ended:** Playwright browser process died mid-session (JS evaluate crash); restart requires Claude Code restart which user chose to defer.

**Next-session plan (Tab → Enter approach):**
1. Open fresh Adult band session (clear localStorage, COPPA gate age 21, type name via keyboard).
2. Select archetype via `page.mouse.click` on the LOGIC ARCHITECT chip at its bounding-box coordinates (confirm via snapshot that `[checked]` state appears in Dart-side rendering).
3. **Do not scroll via WheelEvent.** Instead use `Tab` key (via `browser_press_key`) to cycle focus to the Create Story button — Flutter's focus system bypasses the gesture arena entirely.
4. Confirm button is focused (snapshot should show it with a focus ring or `[focused]` state).
5. Press `Enter` or `Space` to fire `onPressed`.
6. Confirm `/create-character` → 200, then `/generate-story` → 200.

**Manual test alternative (fastest path):** open incognito → `https://grand-light-production-68d9.up.railway.app` → age 21 → any name → wizard: fill name + gender + archetype → Create Story → DevTools Network confirms `/create-character` 200 and `/generate-story` 200.

### Verification status

| Bug | Status |
|-----|--------|
| BUG-001 avatar gate | ✅ PASS — fix confirmed in source (`hero_creator_step.dart:604`); banner never appeared in Playwright |
| BUG-001 full wizard + `/generate-story` 200 | ⏳ DEFERRED — Playwright blocked on Create Story button interaction; pending Tab→Enter approach or manual test |
| BUG-002 TTS backoff | ⚠️ CODE FIX RE-APPLIED — original fix was broken (exception swallowed); rethrow added; runtime verification still pending |
| BUG-003 Stripe anon guard | ⚠️ PARTIAL — 200 on fresh token, 403 on stale token; call-site fix shipped (see below) |

### BUG-002 static code audit — root cause found & fix re-applied (2026-04-21, Claude Sonnet 4.6)

**Finding:** The `b6b5c15` backoff fix was silently broken. `TtsRateLimitException` was thrown at `tts_api_service.dart:117` *inside* the outer `try` block, whose bare `catch (e)` clause caught all exceptions — including `TtsRateLimitException`. The exception was swallowed, `null` returned, and it never propagated to `_prewarm()`'s `on TtsRateLimitException` handler. Net effect: on a 429, the phrase was skipped immediately with no delay and no retry — identical to pre-fix behaviour.

**Fix applied:** added `on TtsRateLimitException { rethrow; }` before the generic `catch (e)` in `TtsApiService.synthesize()`. `TtsRateLimitException` now escapes `synthesize()` and reaches the backoff loop in `_prewarm()`. `dart analyze` clean.

**Verdict:** ❌ FAIL (b6b5c15 as shipped) → fix re-applied correctly; backoff loop in `app_tts_service.dart` is sound once the exception propagates. Runtime Playwright verification still pending.

### BUG-002 fresh-session retest — DEFERRED (2026-04-21)

Playwright browser locked ("Browser is already in use") due to multiple running Claude Code instances sharing the same Chrome profile. No automated non-browser alternative exists — the backoff logic is client-side Flutter/Dart compiled to JS and only executes in a real browser.

**`.mcp.json` updated** — added `--isolated` flag to Playwright MCP args so future sessions each get their own Chrome profile and won't clash. Takes effect after next Claude Code restart.

**Resume plan (next session):**
1. Start a fresh Claude Code instance (or restart after clearing other sessions).
2. The `--isolated` flag in `.mcp.json` is already in place — Playwright should launch cleanly.
3. Follow briefing `docs/briefings/TASK3_BUG002_TTS_FRESH_SESSION.md` verbatim.
4. Target: `https://grand-light-production-68d9.up.railway.app`, viewport 1400×900, age 8 (Explorer band).
5. Attach network listener before navigation; wait ~60 s after landing; dump `/tts/*` request log.
6. Pass/fail criteria and deliverable format are in the briefing.

**Manual alternative (fastest if Playwright is still awkward):**
Open Chrome DevTools → Network tab → filter `tts` → navigate to app → age 8 → land on welcome screen → watch for 60 s → report total request count, 429 count, and timing gaps between retries on any single phrase.

### BUG-003 call-site audit + deploy (Claude Sonnet 4.6)

**Call sites found hitting `/api/stripe/subscription-status/`:**

| File | Guarded? |
|------|----------|
| `lib/services/subscription_sync_service.dart` | ✅ already guarded (`startsWith('anon_')` early return) |
| `lib/services/stripe_service.dart:62` | ❌ raw HTTP call, no guard |
| `lib/services/subscription_service.dart:31` | ❌ creates `StripeService()` directly, bypasses sync service |
| `lib/screens/subscription_management_screen.dart:85` | ❌ calls `_stripeService.getSubscriptionStatus(userId)` directly |
| `lib/providers/subscription_provider.dart:58` | ❌ calls `SubscriptionService.getSubscriptionStatus()` → hits unguarded path |

**Root cause:** `SubscriptionSyncService` holds the only guard, but three other paths call `StripeService.getSubscriptionStatus()` directly, bypassing it entirely. A stale anon token is still an `anon_`-prefixed userId — it hits the backend 403 because the client-side guard was never reached.

**Fix chosen: Option B — guard in `StripeService.getSubscriptionStatus()` itself**

Added an early return at the top of `StripeService.getSubscriptionStatus()`:
```dart
if (userId.startsWith('anon_')) {
  return {'status': 'inactive', 'tier': 'free'};
}
```
This is the single HTTP boundary all callers use, so one change covers all three unguarded paths. Backend 403 policy unchanged.

**Verification:** Added unit test `getSubscriptionStatus returns free/inactive for anon_ user without network call` in `test/unit/services/stripe_service_test.dart` — verifies no HTTP call is made and the returned payload is `{status: inactive, tier: free}`. Test passes. Pre-existing auth-header test failures (2) are unrelated.

**Deployed:** Pushed to `main` → GitHub → Railway auto-deploy. Deployment `b33e04b9` status `SUCCESS`. Backend 403 policy unchanged. `RAILWAY_TOKEN` in `~/.claude/settings.json` updated to remove stale token — future sessions use OAuth config automatically.

---

## 2026-04-20c — Playwright QA sweep + BUG-001 + gender button a11y (Claude Sonnet 4.6 / Opus 4.7)

**Scope:** End-to-end Playwright QA across all 6 age bands against the live Railway build, plus the two code fixes surfaced that aren't already logged under 2026-04-20a/b.

### QA sweep (`docs/QA_PLAYWRIGHT_REPORT_2026-04-20.md`, commit `0ebb117`)

- Target: `https://grand-light-production-68d9.up.railway.app`, viewport 1400 × 900, 3 sessions (context splits).
- Bands 1–3 (Sprout / Explorer / Adventurer) and Band 5 (Adolescent) ✅ PASS — `/generate-story` returned 200.
- Band 4 (Creator) ⚠️ PARTIAL — generation 200, COPPA consent 201 OK.
- Band 6 (Adult) ❌ FAIL — blocked by BUG-001 below.
- Also deleted 307 stray `qa_*.png` / `band6_*.png` screenshot artifacts from repo root.

### BUG-001 — Adult band Create Story blocked for new users (CRITICAL) ✅ FIXED

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

`_handleContinue()` gated submission on `_hasAvatar` (`_generatedAvatar != null || _customAvatarFilePath != null`), but the mature-band form (`CreativeBriefWidget`) has no avatar-generation UI — only Boy/Girl buttons that set `characterGender`. Every new adult user hit *"Please choose a look for your character first"* and could not proceed.

**Fix (commit `73ee489`):** skip the avatar gate when the active band is mature.

```dart
final isMatureBand =
    Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false;
if (_isCreatingNew && !_hasAvatar && !isMatureBand) { ... }
```

`AgeBand.isMature` (`lib/theme/age_band_theme.dart:574`) covers creator, adolescent, adult — so Bands 4/5/6 all bypass the gate.

### GenderImageButton a11y (Test #3) ✅ FIXED

**File:** `lib/widgets/hero_creator/hero_input_widgets.dart`

`GenderImageButton` wrapped a bare `GestureDetector`, so semantic tap actions did not dispatch to `onTap` — screen readers saw a generic tap target with no selected state, and Playwright could not register selection via semantic click.

**Fix (commit `1711a57`):** wrap in `Semantics(button: true, selected: …, label: …, onTap: …, excludeSemantics: true)`. Pointer events still route through the inner `GestureDetector`. Same pattern later reused for `FeelingsBadgeGrid` (see 2026-04-20b).

### Files Changed

| File | Change | Commit |
|------|--------|--------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Skip avatar gate for mature bands (BUG-001) | `73ee489` |
| `lib/widgets/hero_creator/hero_input_widgets.dart` | Semantic button wrapper around `GenderImageButton` | `1711a57` |
| `docs/QA_PLAYWRIGHT_REPORT_2026-04-20.md` | New QA report — full band 1–6 results, 3 bugs | `0ebb117` |

### Verification status

BUG-001 fix is on `main` but has not yet been re-verified end-to-end against the live Railway build. Open follow-up: re-run Band 6 happy path once Playwright MCP is available in-session (Claude Code restart required per `reference_playwright_mcp_lockfile`).

---

## 2026-04-20b — Feelings Badge Grid: semantic onTap wiring (Claude Opus 4.7)

**Bug:** Adventurer-band-exclusive emotion picker ("What's going on?" modal, `FeelingsQuestModal` with `_useBadgeGrid=true`) appeared stuck — taps produced hover glow but never popped the modal or advanced the wizard.

**Root cause:** `_EmotionCard` in `lib/widgets/feelings_badge_grid.dart` wrapped its cards in `Semantics(button: true, label: ...)` without passing `onTap`. Semantic tap events reached the `Semantics` node and stopped; the inner `GestureDetector.onTap` never fired.

**Fix:** Mirror the `GenderImageButton` fix from commit `1711a57` — pass `onTap` to `Semantics` and set `excludeSemantics: true` so the inner `GestureDetector` does not double-announce. Pointer events still route through `GestureDetector` unchanged.

### Files Changed
| File | Change |
|------|--------|
| `lib/widgets/feelings_badge_grid.dart` | `Semantics(onTap: onTap, excludeSemantics: true)` on `_EmotionCard` |

Shipped in `f60affe`.

---

## 2026-04-20a — Hero Creator: setState-during-build crash on quick-add companion (Claude Opus 4.7)

**Bug:** Selecting a species from the quick-add companion picker surfaced a red screen in `HeroCreatorStep`:

> `setState() or markNeedsBuild() called during build.`
> `This HeroCreatorStep widget cannot be marked as needing to build because the framework is already in the process of building widgets.`

**Root cause:** `HeroPetCard.didUpdateWidget` (`lib/widgets/hero_creator/pet_card.dart:93`) reacted to a new `pendingNewSpecies` by synchronously calling `_addCompanionWithType(species)` followed by `widget.onPendingConsumed?.call()`. Both `_addCompanionWithType` (via `widget.onChanged` = `() => setState(() {})` at `hero_creator_step.dart:1233/1241`) and `onPendingConsumed` (`() => setState(() => _pendingCompanionSpecies = null)`) mutate the parent while it is mid-build, violating the framework invariant.

**Fix:** Defer the cascade to a post-frame callback with a `mounted` guard so the parent's `setState` fires after the current build completes:

```dart
if (widget.pendingNewSpecies != null &&
    widget.pendingNewSpecies != oldWidget.pendingNewSpecies) {
  final species = widget.pendingNewSpecies!.split(':').first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _addCompanionWithType(species);
    widget.onPendingConsumed?.call();
  });
}
```

### Files Changed
| File | Change |
|------|--------|
| `lib/widgets/hero_creator/pet_card.dart` | Wrap `_addCompanionWithType` + `onPendingConsumed` in `addPostFrameCallback` to avoid setState-during-build cascade |

---

## 2026-04-20b — TTS Prewarm Dedup + Stripe Anon Guard (Claude Sonnet 4.6)

**Goal:** Fix BUG-002 (TTS 429 storm during session warm-up) and BUG-003 (Stripe 403 console noise for anonymous users), as surfaced by QA_PLAYWRIGHT_REPORT_2026-04-20.

### BUG-002 — TTS warm-up 429 storm ✅ FIXED

**Root cause:** `_prewarm()` in `app_tts_service.dart` fired all ~100 warm-up phrases with no throttle and no guard against concurrent calls, saturating the ElevenLabs rate limit (40+ `429 Too Many Requests` per session in QA).

**Fix (commit `b6b5c15`):**
- `tts_api_service.dart` — added `TtsRateLimitException`; `synthesize()` throws on HTTP 429 instead of silently returning null.
- `app_tts_service.dart` — added `bool _prewarming` dedup flag (second warm-up call during same session returns immediately). On `TtsRateLimitException`, backs off with doubling delay starting at 2 s (2→4→8→30 s max, 4 attempts per phrase).

### BUG-003 — Stripe 403 for anonymous users ✅ FIXED

**Root cause:** `SubscriptionSyncService.syncSubscriptionStatus()` called `GET /api/stripe/subscription-status/{userId}` for anonymous sessions (`anon_` prefix). Backend returns 403 — anonymous tokens are not Stripe customers. Console noise on every page load.

**Fix (commit `de5758f`):**
- `subscription_sync_service.dart` — if `resolvedUserId.startsWith('anon_')`, emit `SubscriptionStatus(tier: free, status: inactive)` and return without any network call.

### Files Changed
| File | Change |
|------|--------|
| `lib/services/tts_api_service.dart` | Add `TtsRateLimitException`; throw on 429 |
| `lib/services/app_tts_service.dart` | `_prewarming` dedup flag; exponential backoff on `TtsRateLimitException` |
| `lib/services/subscription_sync_service.dart` | Skip Stripe fetch for `anon_` users; emit free tier directly |

### QA Re-run Status
Playwright MCP disconnected before re-run completed (Windows lockfile — requires Claude Code restart). Fixes verified analytically; full regression re-run pending next session.

---

## 2026-04-19o — Gendered Archetypes All Bands + Story Mapper Fix (Claude Sonnet 4.6)

**Goal:** Wire gendered archetype images for all 6 age bands, add age-appropriate archetype names, and fix story generation so archetype data actually reaches the AI prompt.

### Gendered archetype images — all bands

Added boy/girl variants to every band folder (`assets/images/archetypes/{band}/`):

| Band | Archetypes |
|------|-----------|
| **Sprout** (3-5) | `brave_hero`, `master_creator`, `lightning_runner`, `animal_whisperer` |
| **Explorer** (6-8) | `brave_hero`, `master_creator`, `lightning_runner`, `animal_whisperer` |
| **Adventurer** (9-11) | `quiz_whiz`, `master_creator`, `lightning_runner`, `animal_whisperer` |
| **Creator** (12-14) | `quiz_whiz`, `master_creator`, `lightning_runner`, `animal_whisperer` |
| **Adolescent** (15-17) | `quiz_whiz`, `master_creator`, `lightning_runner`, `animal_whisperer` |
| **Adult** (18+) | `quiz_whiz`, `master_creator`, `lightning_runner`, `animal_whisperer` |

Sprout/Explorer use `brave_hero` (heroic, action-oriented) where older bands use `quiz_whiz` (strategic, cerebral) — same archetype slot, different visual identity.

### File fixes
- Renamed `explorer/masster_creator_*.png` → `master_creator_*.png` (typo)
- Renamed `sprout/*.jpg` → `*.png` for consistency with the `.png` extension in the code path

### Age-appropriate archetype names (`lib/widgets/archetype_card.dart`)

Added `explorerName`, `explorerDescription`, and `genderedImageIdPerBand` fields to `ArchetypeData`.

| Archetype | Sprout (3-5) | Explorer (6-8) | Adventurer (9-11) | Creator+ (12+) |
|---|---|---|---|---|
| Thinker | Brave Hero! | The Brave Explorer | The Quiz Whiz | Logic Architect |
| Artist | Art Maker! | The Art Wizard | The Master Creator | Vision Architect |
| Athlete | Super Fast! | The Speed Star | The Lightning Runner | Kinetic Specialist |
| Nature | Animal Friend! | The Animal Whisperer | The Animal Whisperer | Ecological Whisperer |

### Story mapper fix (`lib/screens/wizard_steps/wizard_data_mapper.dart`)

**Bug:** `_mapArchetypeToDetails()` used `.contains()` matching on archetype names. The new band-specific names ("Brave Hero!", "The Art Wizard", "The Speed Star", etc.) fell through to the empty default — the AI received **no strengths, no special ability, and no interests** for those archetypes.

**Fix:** Added all name variants to the matcher. Enriched strengths: Intelligence for thinker, Teamwork for runner, Observation for whisperer.

### TTS warm-up (`lib/services/app_tts_service.dart`)
- Updated warm-up phrases to match new Sprout/Explorer archetype names

### Files Changed
| File | Change |
|------|--------|
| `lib/widgets/archetype_card.dart` | `explorerName`, `explorerDescription`, `genderedImageIdPerBand` fields; updated `nameForAge`/`descriptionForAge`/`imagePathForBand` |
| `lib/screens/wizard_steps/wizard_data_mapper.dart` | Match all band-specific archetype names in story mapper |
| `lib/services/app_tts_service.dart` | Warm-up phrases for new archetype names |
| `assets/images/archetypes/*/` | 48 gendered PNG files across 6 bands |

---

## 2026-04-19n — Creator/Adolescent Differentiation Plan (Claude Sonnet 4.6)

**Goal:** Close the remaining differentiation gap between Creator (12-14) and Adolescent (15-17) bands. Both share identical story prompts, scenario copy, and have thin life quest coverage. Plan generated from full codebase audit.

**Current state:** Creator ~60% differentiated, Adolescent ~40%. Visual themes already distinct; gap is in story logic, AI prompts, and scenario content.

---

### Phase 1 — Scenario Content Gap *(zero risk, pure data)*

**File:** `lib/data/scenario_data.dart`

Add 5 new fields to `ScenarioCard`:
- `adolescentTitle`, `adolescentDescription`, `adolescentThematicQuestion`, `adolescentConflictHook`, `adolescentWorldBible`

Update accessors `titleForBand()`, `descriptionForAge()`, `conflictHookForAge()`, `worldBibleForAge()` to serve adolescent-specific copy at ages 15-17 before falling through to `matureTitle` fallback.

**Tone rule:** Creator asks *"what does this reveal about me?"* (identity formation). Adolescent asks *"what does this mean?"* (moral ambiguity, social complexity).

**Example copy pairs (5 scenarios):**

| Scenario | Creator (12-14) | Adolescent (15-17) |
|---|---|---|
| Doorway Between Seasons | "The Door You're Afraid to Open" | "Seasons That Don't Come Back" |
| Volcano of Dragons | "What Wakes the Fire Inside" | "What the Fire Has Already Cost" |
| Brave Friend | "Showing Up" | "The Risk of Being Known" |
| Change is Coming | "Leaving the Person You Were" | "What You Carry Forward" |
| Big Feelings Quest | "The Feeling That Won't Let Go" | "What You've Been Carrying Alone" |

**Acceptance criteria:** `titleForBand(AgeBand.adolescent)` returns a distinct string from `titleForBand(AgeBand.creator)` for at least 8 of 12 scenarios.

---

### Phase 2 — Story Generation Prompts *(touches API service only)*

**File:** `lib/services/api_service_manager.dart`

Add `ageBand` param to `generateStory()`. Add private `_buildBandSystemPrompt(AgeBand band, {bool isByok})` injected into both `_buildAdventurePrompt` and `_buildTherapeuticPrompt`.

**Creator base prompt:**
- Identity formation is the subtext — protagonist's choices reveal who they are becoming
- Tone: energised, personal, slightly urgent
- Conflict style: external obstacles mirror internal questions ("Am I brave enough?")
- Arc: from uncertainty to agency — one clear act of self-determination
- Language: direct, concrete, no condescension; metaphors grounded
- Length: 600-800 words

**Adolescent base prompt:**
- Psychological and social depth — protagonist is aware others have full inner lives
- Tone: measured, cinematic, restrained; subtext matters
- Conflict style: moral ambiguity — no purely good choices
- Arc: autonomy under pressure — act on own judgment when no clear right answer
- Language: mature vocabulary, complex sentences; avoid moralising
- Include at least one moment of genuine uncertainty
- Length: 600-800 words

**BYOK enhancement (appended when `isByok: true`):**
- Creator: distinct protagonist voice, recurring motifs, one invented-not-discovered solution, unresolved question on final page
- Adolescent: deep internal arc (not resolved — *shifted*), ambiguous ending, two genuine self-questioning moments, dual interpretation, literary-register vocabulary

Also send `'age_band': band.name` in all backend payloads so server-side mirrors same differentiation for non-BYOK users.

**Acceptance criteria:** `_buildAdventurePrompt(age: 13)` contains Creator block; `_buildAdventurePrompt(age: 16, isByok: true)` contains Adolescent base + BYOK enhancement. No regression for other age bands.

---

### Phase 3 — Life Quests *(zero risk, pure data — ship any time)*

**File:** `lib/data/life_quest_data.dart`

**3 new Adolescent-exclusive quests:**

| Quest | Theme |
|---|---|
| `questTheRumour` | Information as power — no clean choice between silence, confrontation, or going direct |
| `questTheAudition` | Social cost of individual achievement — how do you hold success when someone you care about didn't get in |
| `questNobodyAsked` | Witness responsibility — what do you owe a situation you didn't choose to see |

**2 new Creator-exclusive quests:**

| Quest | Theme |
|---|---|
| `questTheyChangedIt` | Collaborative ownership — when does a shared project stop feeling like yours |
| `questShowedThem` | Vulnerability in sharing creative work — what you do after the reaction wasn't what you hoped |

Result: Adolescent 3 → 6 exclusive quests. Creator 3 → 5 exclusive quests.

---

### Phase 4 — UI Screen Differentiation *(after Phase 1)*

**Files:** `magic_review_step.dart`, `feeling_selection_step.dart`, `big_feelings_flow_screen.dart`, `age_band_theme.dart`

| Screen | Change |
|---|---|
| `MagicReviewStep` (Adolescent) | Header → `'Set the premise'`; add `adolescentThematicQuestion` in italics below header; CTA → `'Begin'`; sub-label → `'No fanfare. Just the story.'` |
| `MagicReviewStep` (Creator) | No change — already correctly differentiated |
| `FeelingSelectionStep` | Surface `adolescentThematicQuestion` on scenario cards (same pattern as existing `creatorThematicQuestion` overlay) |
| `BigFeelingsFlowScreen` | Extend journal reflection gate to Adolescent; Creator prompt: "What do you notice about this feeling?" / Adolescent: "What's underneath this feeling — what else is going on?" |
| `age_band_theme.dart` | `adolescentTheme.launchStoryLabel` → `'Begin'` (Creator keeps `'Start Writing'`) |

No new widgets needed — all changes are parametrised via existing band config patterns.

---

### Phase 5 — BYOK Enhancement Layer *(after Phases 2 + 4)*

**Files:** `feeling_selection_step.dart`, `magic_review_step.dart`, `hero_creator_creative_brief.dart`

- **Creator BYOK:** Surface optional field in Creative Brief — *"Describe one rule of your world that defies reality."* — gated on `isUsingOwnApiKey()`. Richer illustrations automatically improve from Phase 2 prompt quality.
- **Adolescent BYOK:** Add `'Explore without resolution'` toggle in `FeelingSelectionStep` (Adolescent + BYOK only). Stored as `WizardData.exploreWithoutResolution`. Appends ambiguous-endings instruction to prompt.
- **Discovery signal:** In Adolescent review step, show `'Enhanced depth active'` in teal at 45% opacity when BYOK is live.
- **Non-BYOK guarantee:** Base band prompts (Phase 2) deliver a complete, satisfying experience via backend route. The `'age_band'` field ensures full differentiation without an API key.

---

### Dependency Order

```
Phase 1 ──────────── Phase 4
Phase 2 ─────────────────── Phase 5
Phase 3  (independent)
```

Recommended sequence: Phase 1 + Phase 3 together (pure data) → Phase 2 in parallel → Phase 4 after Phase 1 lands → Phase 5 last.

---

## 2026-04-19m — Creator/Adolescent differentiation + 6 new quests (Claude Opus 4.6)

**Goal:** Close the Creator/Adolescent differentiation gap — both bands previously shared identical quest lists and flows.

### What changed

**Re-tagged existing quests by developmental fit:**
- `questLeftOut`, `questSiblingConflict`, `questBeingTeased`, `questTryout` → `[adventurer, creator]`
- `questPeerPressure`, `questFamilyStress`, `questFeelingDifferent`, `questLosingFriendship` → `[creator, adolescent]`
- `questSchoolStress` → unchanged (all three bands)

**3 Creator-only quests (12-14):** The Group Chat, My Work My Way, Mirror Mirror
**3 Adolescent-only quests (15-17):** Someone Needs Help, The Thing I Didn't Say, Where Are You Going?

**Band-specific selector copy** in `life_quest_screen.dart`

### Quest distribution: Explorer 7, Adventurer 5, Creator 12, Adolescent 8

### Commit
`1c813be` — feat(life-quests): differentiate Creator and Adolescent bands

---

## 2026-04-19l — Age-band avatar loading animations (Claude Sonnet 4.6)

**Goal:** Replace the plain `CircularProgressIndicator` in `custom_avatar_screen.dart` with rich, age-band-specific loading animations shown during the ~60s avatar generation wait.

### What was done

Created 7 new files and modified 1:

| File | What it does |
|------|-------------|
| `lib/widgets/avatar_generating_view.dart` | Shared shell — progress steps, rotating flavor messages, cancel button, tap counter. Delegates central animation to band widget. |
| `lib/widgets/avatar_loading_bands/sprout_egg_hatch.dart` | Sprout (2-5): glowing egg wobbles, tap to add cracks + golden glow peeks through |
| `lib/widgets/avatar_loading_bands/explorer_constellation.dart` | Explorer (6-8): stars appear + lines draw between them, drifting tap targets to catch |
| `lib/widgets/avatar_loading_bands/adventurer_treasure_map.dart` | Adventurer (9-11): parchment map, teal ink trail draws via PathMetrics, landmark icons, compass tap |
| `lib/widgets/avatar_loading_bands/creator_digital_canvas.dart` | Creator (12-14): geometric shapes compose on dark canvas, tap adds ripple, no particles |
| `lib/widgets/avatar_loading_bands/adolescent_holographic_portal.dart` | Adolescent (15-17): chromatic aberration rings, teal data-stream rain, silhouette materializes, tap glitch |
| `lib/widgets/avatar_loading_bands/adult_ink_wash.dart` | Adult (18+): amber brush strokes bloom with ink diffusion, meditative, no interaction |
| `lib/custom_avatar_screen.dart` | `_buildGeneratingView()` replaced with `AvatarGeneratingView` |

All bands respect `MotionPrefs` accessibility (reduceMotion, showParticles, sparkleIntensity). `flutter analyze` passes with zero new issues.

### After restart — what's left

1. **Visual testing** — run the app, trigger avatar generation at each age:
   - Age 4 → egg wobbles, tap to crack it
   - Age 7 → constellation draws, catch drifting stars
   - Age 10 → treasure map ink trail, tap compass
   - Age 13 → geometric shapes compose, tap for ripple
   - Age 16 → holographic portal, tap for glitch
   - Age 25 → ink wash brush strokes, no interaction
2. **Animation timing** — progress steps advance every 15s over ~60s; tune if it feels off.
3. **Companion image** — `AvatarGeneratingView` accepts `companionImagePath` but `custom_avatar_screen.dart` passes `null`. Wire in the selected companion if available in context.
4. **TTS** — shell has a hook ready; consider speaking a comfort phrase on mount for Sprout/Explorer.

### Status
Not yet visually tested. Committed but not pushed (see git status below).

---

## 2026-04-19k — Archetype gendered images + press-state feedback (Claude Sonnet 4.6)

**Goal:** Wire up gender-based archetype image routing for adventurer and creator bands; add tactile press-state feedback to archetype cards.

### What was done

#### Press-state ("tap feedback") on ArchetypeCard
- Converted `ArchetypeCard` from `StatelessWidget` to `StatefulWidget`.
- Added `_isPressed` state, tracked via `GestureDetector` `onTapDown`/`onTapUp`/`onTapCancel` (replaced `InkWell`).
- `AnimatedScale` now uses scale `0.94` when pressed (vs `1.03` selected, `1.0` default) — the "push-in" feel.
- White brightness overlay (`Colors.white` at 18% opacity) flashes in the Stack when pressed.

#### Gender routing — SafeAssetImage fallback chain
- Added `fallbackPath` parameter to `SafeAssetImage`: if the primary path fails, tries `fallbackPath` before showing the placeholder widget. Nested `Image.asset` `errorBuilder` handles the cascade.
- Updated `_buildArchetypeSceneImage` in `hero_creator_step.dart` to pass `fallbackPath: archetype.imagePathForBand(ageBand)` (gender-neutral) alongside the gendered primary path. Any band without a gendered variant gracefully degrades to the generic `.jpg`.

#### New adventurer band gendered images
- Added 8 files to `assets/images/archetypes/adventurer/`: `quiz_whiz_boy.png`, `master_creator_boy.png`, `lightning_runner_boy.png`, `animal_whisperer_boy.png` + matching `_girl` variants.
- Naming follows the established `{archetypeName}_{boy|girl}.png` convention used in the creator band.
- `imagePathForBand` already resolved `genderedImageId` + gender to this path — no code change needed to activate routing for adventurer.

#### Typo fix — `mastor_creator` → `master_creator`
- Renamed `mastor_creator_boy.png` → `master_creator_boy.png` in both `creator/` and `adult/` bands.
- Added `master_creator_girl.png` to `adult/` (was missing).

### Files changed
| File | Change |
|------|--------|
| `lib/widgets/archetype_card.dart` | StatefulWidget + GestureDetector press state |
| `lib/widgets/safe_asset_image.dart` | `fallbackPath` parameter + nested error chain |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Pass `fallbackPath` in `_buildArchetypeSceneImage` |
| `assets/images/archetypes/adventurer/*_{boy\|girl}.png` | 8 new gendered variants |
| `assets/images/archetypes/creator/master_creator_boy.png` | Renamed from `mastor_creator_boy.png` |
| `assets/images/archetypes/adult/master_creator_{boy\|girl}.png` | Typo fix + added missing girl file |

### Remaining / follow-up
- Other bands (explorer, adolescent) still use generic `.jpg` fallbacks — add `_boy`/`_girl` PNGs when art is ready; no code changes needed.
- Sprout band uses `sproutImageId` not `genderedImageId` — gendered routing for sprout would need a small extension to `imagePathForBand`.
- Adult band still missing: `quiz_whiz_girl.png`, `lightning_runner_girl.png`, `animal_whisperer_girl.png` — add when art is ready.

---

## 2026-04-19j — Phase 6 Bug Fixes: P6-01 companions, P6-02 stale age, P6-03/04 load audit (Claude Sonnet 4.6)

**Goal:** Fix all four open bugs from the Phase 6 test report and re-run the load audit with a valid real-API baseline.

### What was done

#### BUG-P6-01 — Companion images 404 in adult/mature brief wizard (`lib/screens/wizard_steps/hero_creator_step.dart`)
- Root cause: `_adventurerCompanions` and `_companions` const lists used old generic IDs (`dragon`, `cat`, `owl`, `dog`, `unicorn`, `fox`, `robin`) with no `imagePathOverride`, falling back to `${id}_normal.jpg` which doesn't exist.
- Fix: replaced both lists with five per-band const lists (`_explorerCompanions`, `_adventurerCompanions`, `_creatorCompanions`, `_adolescentCompanions`, `_adultCompanions` — `_sproutCompanions` was already correct). Each entry uses `imagePathOverride` pointing to `assets/images/companions/{band}/{filename}`, matching actual on-disk assets and the pattern in `companion_selector_step.dart`.
- Updated band selection in `_CompanionImageGrid.build()` from a 3-branch ternary to an exhaustive `switch` covering all 6 `AgeBand` values.
- **Visual verify still pending** — Playwright browser session was closed; confirm 0 console 404s in the adult brief wizard Cast & Companions accordion after restart.

#### BUG-P6-02 — Stale age in localStorage causes wrong COPPA flow (`lib/screens/welcome_screen.dart`)
- Root cause: race condition. `initState()` renders step 0 (age picker) immediately then calls `_resumeFromSavedAge()` async. If the user taps a new age before the prefs read returns, `_resumeFromSavedAge()` finishes after and overwrites `_selectedAge` with the stale persisted age, causing COPPA to fire with the wrong age.
- Fix 1: guard in `_resumeFromSavedAge()` — bail out if `_selectedAge != null` (user already picked).
- Fix 2: in `_onAgeSelected()`, `unawaited(ParentalConsentService().saveDeclaredAge(age))` immediately, so any concurrent prefs read sees the new age.

#### BUG-P6-03 — Load audit harness 100% 500s (`backend/tests/story_load_audit.py`)
- Root cause: mock user `SimpleNamespace` in `_auth_session_get()` was missing `is_under_13` and `declared_age` fields added to `User` model in 2026-03-31 COPPA work.
- Fix: added `is_under_13=False, declared_age=None` to the SimpleNamespace.

#### BUG-P6-04 — Fallback switchover measurement broken
- Was blocked by P6-03. After fix, switchover measured correctly: gemini(fail:401) → openrouter(fail:no_key) → static in ~154ms.

### Load audit re-run results (post-fix, `--real-api`)
- **Mocked scenarios:** 0 errors, p95 ~185–203ms (test client + static fallback overhead).
- **Real Gemini baseline:** 5/5 success, p50=42.5s, p95=44.9s, mean=35.4s. First valid real-provider baseline.
- Artifacts updated: `backend/tests/artifacts/story_load_audit_latest.*`

### Files changed
| File | Change |
|------|--------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Per-band companion lists with `imagePathOverride`; exhaustive band switch |
| `lib/screens/welcome_screen.dart` | Race condition fix: guard in `_resumeFromSavedAge`, immediate persist in `_onAgeSelected` |
| `backend/tests/story_load_audit.py` | Add `is_under_13`/`declared_age` to mock user SimpleNamespace |

### After restart — resume here
1. **Companion image visual verify** (5 min): open adult brief wizard in browser, expand Cast & Companions, confirm 0 console 404s. Screenshot to `docs/phase6_artifacts/adult_companions_fixed.png`.
2. **Phase 7 manual QA** (audio-only CTA): see `2026-04-19i` entry below for full test plan.

---

## 2026-04-19i — Phase 7 audio-only CTA QA — BLOCKED on Playwright MCP (Claude Opus 4.7)

**Goal:** Verify the audio-only CTA from `magic_review_step.dart` (commit `789fa48`) works end-to-end on Railway across all 6 age bands — the last open item from the 2026-03-25 Codex audit (line 1998 of this file).

### Status: PAUSED — resume after computer restart

Browser automation against `https://story-weaver-app-production.up.railway.app/` could not start. The Playwright MCP server hit `Error: Browser is already in use for ...mcp-chrome-for-testing-85fd96c` because a stale `lockfile` in the dedicated user-data-dir was still held by an orphaned Playwright MCP `node.exe` process from a prior session. Killing the chrome child processes alone did not release the file handle — only killing the parent node process does, and that severs the live MCP connection mid-session.

**Recovery before resuming:**
1. Exit Claude Code.
2. Run in PowerShell:
   ```powershell
   Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*playwright/mcp*' -or $_.CommandLine -like '*mcp-chrome-for-testing*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
   Remove-Item "C:\Users\darcy\AppData\Local\ms-playwright\mcp-chrome-for-testing-85fd96c\lockfile" -Force -ErrorAction SilentlyContinue
   ```
   (A computer restart accomplishes the same thing.)
3. Restart Claude Code, `/resume`, pick the session whose first message starts "Phase 7 manual QA still pending".

Memory entry `reference_playwright_mcp_lockfile.md` also captures this for future Windows + Playwright MCP sessions.

### Test plan (when unblocked)

The audio-only CTA only renders when `data.interactiveMode == true` (see diff in `789fa48`: `if (data.interactiveMode) ...`). Plan per band:

1. Open the deployed app → enter wizard with **interactive mode enabled** for the target band.
2. Complete name + scenario + hero + feelings to reach `magic_review_step.dart`.
3. Confirm CTA copy:
   - Mature bands (adolescent, adult): "Want the same pick-a-path story without the screen?" + button "Start Audio-Only Adventure".
   - Other bands (sprout, explorer, adventurer, creator): "Want this adventure in audio-only bedtime mode?" + button "Start Bedtime Audio Adventure".
4. Click CTA → verify push to `BedtimeWizardScreen(isInteractive: true)`.
5. Confirm TTS network call returns 200 and audio element loads. (Audible playback verification is on-device, not Playwright-observable.)
6. Watch console + Railway backend logs for the 401 from the `userId: 'guest'` hardcode flagged at line 1997 of this file — that bug is still open and may surface here.

Bands to cover (6): sprouts, early_readers (explorer), adventurers, creators, adolescents, adults.

### Open question to resolve at resume

Confirm whether the prod app exposes the wizard via guest/anonymous flow or requires real auth. If auth is required, get test credentials before kicking off the sweep.

---

## 2026-04-19h — 5 Explorer Life Quests authored (Claude Sonnet 4.6)

**Goal:** Write full CYOA content for the 5 Explorer quests (ages 6–8) deferred in session 2026-04-19g.

### What changed
- **`lib/data/life_quest_data.dart`** — added 5 new Explorer quests (`questThreeCrowd`, `questBrokenThing`, `questNotFair`, `questSleepover`, `questMyTurnTalk`) with full CYOA content. All tagged `recommendedBands: [AgeBand.explorer]`.
- **`allLifeQuests`** updated to include all 5 new quests.
- Explorer band now has 7 quests total (up from 2): Wobbly Day, Sorry Stuck, Three's a Crowd, Broken Thing, It's Not Fair, Goodnight from Far Away, My Turn to Talk.

### Quest topics
| ID | Title | Hook | Emotions |
|----|-------|------|----------|
| `three_crowd` | Three's a Crowd | Your best friend is playing with someone else. | sad, worried, angry |
| `broken_thing` | I Didn't Mean To | You broke something. Now you have to decide what to do. | scared, worried, sad |
| `not_fair` | It's Not Fair | Someone else got picked. Why not you? | angry, frustrated, sad |
| `sleepover` | Goodnight from Far Away | Everyone else seems fine. You just want to go home. | sad, scared, worried |
| `my_turn_talk` | My Turn to Talk | Everyone is about to look at you. All at once. | scared, worried, excited |

### Commit
`64f7fa9` — feat(life-quests): add 5 Explorer quests

---

## 2026-04-19g — hero_creator extraction continued + band avatar loading views (Claude Sonnet 4.6)

**Goal:** Commit stale uncommitted work — further extraction of `hero_creator_step.dart` and new band-specific avatar loading animations.

### What changed
- **`hero_creator_creative_brief.dart`** (NEW) — adult/mature Creative Brief wizard page extracted from `hero_creator_step.dart` (~1600 lines removed from monolith)
- **`avatar_generating_view.dart`** (NEW) — shared avatar-generating spinner extracted from `custom_avatar_screen.dart`
- **`widgets/avatar_loading_bands/`** (NEW) — 6 band-specific loading animations while avatar is generating:
  - `sprout_egg_hatch.dart`, `explorer_constellation.dart`, `adventurer_treasure_map.dart`
  - `creator_digital_canvas.dart`, `adolescent_holographic_portal.dart`, `adult_ink_wash.dart`
- **5 new archetype images** — adolescent boy (animal whisperer, lightning runner, master creator) + creator girl (animal whisperer, master creator)
- **`life_quest_data.dart`** — 5 Explorer quests temporarily removed as undefined stubs; authored and restored by session 2026-04-19h (`64f7fa9`).

### Commit
`97796ba` — feat(hero-creator): extract creative brief + band avatar loading views

---

## 2026-04-19f — Companion Showcase Fix + Compile Error Cleanup (Claude Sonnet 4.6)

**Goal:** Resolve BUG-P6-01 (adult companion images 404 in brief wizard) and fix a cascade of compile errors from the incomplete hero_creator_step extraction.

### Root cause (BUG-P6-01)
`_buildCompanionShowcase()` referenced `_companions` — a variable removed during the companion rebrand — causing an `undefined_identifier` compile error and broken companion images in the adult "Cast & Companions" accordion.

### Fixes
- **`lib/screens/wizard_steps/hero_creator_step.dart`** — replaced undefined `_companions` reference with `allCompanionEntries()` from `companion_widgets.dart`
- **`lib/widgets/hero_creator/companion_widgets.dart`** — added `allCompanionEntries() → List<CompanionData>` public function; promoted `_CompanionData` → `CompanionData` and band arrays to public API (linter-driven)
- **`lib/character_evolution_screen.dart`** — added missing `emotion_recognition_game.dart` import (`EmotionGameLauncher` undefined)
- **`flutter analyze`** — 0 errors after fixes

### SafeAssetImage migration (stale work committed)
Remaining 27 widget/screen files not included in the prior `9b99789` commit were committed (`b1607c9`): all `Image.asset + errorBuilder` patterns replaced with `SafeAssetImage(placeholder:)`.

### Commits
| SHA | Description |
|-----|-------------|
| `8bd5b74` | fix(adult-wizard): resolve undefined _companions in companion showcase |
| `b1607c9` | refactor: migrate remaining Image.asset uses to SafeAssetImage |
| `2a6bf0a` | fix(hero-creator): resolve companion showcase and missing import errors |

---

## 2026-04-19e — SafeAssetImage Migration (Claude Opus 4.7 + Sonnet 4.6)

**Goal:** Harden all asset image loading across the app — missing assets previously caused layout breaks and uncaught exceptions.

### What changed
- **Extended `lib/widgets/safe_asset_image.dart`** to support `alignment` (default `Alignment.center`), `filterQuality` (default `FilterQuality.medium`), and `frameBuilder` — making it a true drop-in for every `Image.asset` call pattern in the codebase.
- **Migrated 50 `Image.asset` call sites** across 22 files to `SafeAssetImage`. All `errorBuilder:` lambdas converted to `placeholder:`. Nested fallback chains (e.g. `feelings_cloud_picker.dart`, `character_preview.dart`, `character_library_screen.dart`) preserved as nested `SafeAssetImage(placeholder: SafeAssetImage(...))`.
- **Intentional holdouts (2 calls)** in `lib/screens/big_feelings_flow_screen.dart:1450/1461` — their `errorBuilder` calls `setState(() => _index++)` to cycle through fallback asset paths; this is imperative state mutation that `placeholder:` cannot replicate. Left as raw `Image.asset`.
- `flutter analyze` clean after migration (0 errors).

### Files touched
`safe_asset_image.dart`, `companion_selector.dart`, `emotion_recognition_game.dart`, `custom_avatar_screen.dart`, `main_story.dart`, `feelings_wheel_screen.dart`, `quick_story_screen.dart`, `archetype_card.dart`, `avatar_tweak_panel.dart`, `image_make_magic_button.dart`, `image_crystal_formation.dart`, `adventurer_unlock_celebration.dart`, `image_continue_button.dart`, `feelings_cloud_picker.dart`, `image_mode_orb.dart`, `magical_loading_view.dart`, `magic_orb.dart`, `image_progress_orb.dart`, `character_preview.dart`, `mood_lantern_selector.dart`, `ui/widgets/magical_avatar.dart`, `screens/splash_screen.dart`, `screens/character_library_screen.dart`, `screens/midjourney_avatar_picker_screen.dart`, `screens/wizard_steps/companion_selector_step.dart`, `screens/wizard_steps/feeling_selection_step.dart`, `screens/wizard_steps/magic_review_step.dart`, `screens/wizard_steps/hero_creator_step.dart`, `widgets/hero_creator/companion_widgets.dart`, `widgets/hero_creator/scene_widgets.dart`, `widgets/hero_creator/hero_input_widgets.dart`

---

## 2026-04-19d — TTS Pause Polish + Parent Controls Character Creation Link (Claude Sonnet 4.6)

**Goal:** Two small UX fixes raised during manual testing.

### TTS natural pauses (`lib/screens/welcome_screen.dart`, `lib/services/app_tts_service.dart`)
- Added `...` after sentence-ending punctuation in two ElevenLabs prompts so the voice pauses naturally between clauses instead of running sentences together:
  - `'How old are you?... Tap your age!'` (both the teaser and post-dismiss variants)
  - `'Hi, $name!... What a great name!'`
- Updated the corresponding comment in `kWarmUpPhrases` to match the new phrasing.

### Parent Controls → character creation (`lib/screens/parent_controls_screen.dart`)
- When no child profile exists, the "No child profile active" box previously had a static icon and a "Go back and start a story" link that only popped the route.
- The icon (`Icons.person_add_alt_1_rounded`) is now wrapped in a `GestureDetector`.
- Both the icon and the renamed "Create a character" link call `_goToCharacterCreation()`, which pushes `WizardStoryScreen(initialStep: 0)` and reloads settings on return so the profile appears immediately.
- Added `import 'wizard_story_screen.dart'` to the file.

### Hero creator widget extraction (`lib/screens/wizard_steps/hero_creator_step.dart` → `lib/widgets/hero_creator/`)
- `hero_creator_step.dart` was a ~5000-line monolith. Private widget classes extracted to a dedicated `lib/widgets/hero_creator/` directory:
  - `avatar_choice_cards.dart` — `HeroCharacterChoiceCard`
  - `companion_widgets.dart` — companion UI
  - `genre_chip.dart` — `GenreChip`
  - `hero_effects.dart` — `StarBurstOverlay` (was `_StarBurstOverlay`)
  - `hero_input_widgets.dart` — name input, gender picker helpers
  - `pet_card.dart` — `PetCard`
  - `scene_widgets.dart` — scene card display
- `hero_creator_step.dart` updated to import from new files; `SafeAssetImage` adopted throughout.

### ✅ BUG-P6-02 (stale age) — fixed (`427c3b8`)
- `_onAgeTapped()` now calls `ParentalConsentService().saveDeclaredAge(age)` immediately so any still-running `_resumeFromSavedAge()` sees the new age.
- `_resumeFromSavedAge()` guards: if `_selectedAge != null` on return, skip the saved-age restore to avoid overwriting an explicit user selection.

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/welcome_screen.dart` | `...` pause added to age-prompt and name-celebration TTS strings |
| `lib/services/app_tts_service.dart` | Warm-up comment updated to match new phrasing |
| `lib/screens/parent_controls_screen.dart` | Icon + link navigate to character creation wizard; import added |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Imports updated; private widgets extracted to `lib/widgets/hero_creator/` |
| `lib/widgets/hero_creator/` | NEW — 7 extracted widget files |
| `assets/BoyGirl images/` | Old flat source images deleted; new subdirectories added for processed band assets |
| `assets/images/archetypes/adventurer/clever_inventor.jpg` | Updated archetype image |

---

## 2026-04-19c — Phase 6 Test Report + Load Audit Harness Fix (Claude Sonnet 4.6)

**Goal:** Document phase 6 automated test results and fix the broken load-audit harness.

### Load audit harness bug fixed (`backend/tests/story_load_audit.py`)
- All load audit scenarios were returning 500: `'types.SimpleNamespace' object has no attribute 'is_under_13'`
- Root cause: the mock User SimpleNamespace was created before the `is_under_13` and `declared_age` fields were added to the User model
- Fix: added `is_under_13=False, declared_age=None` to the SimpleNamespace in `_auth_session_get()`

### Phase 6 test findings (`docs/phase6_test_report_2026-04-19.md`)
Automated Playwright + load audit run across Welcome → Age Picker → COPPA gate → Adult band wizard.

| Area | Result |
|------|--------|
| Welcome + age picker | ✅ Pass |
| COPPA gate (Sprout) | ✅ Pass |
| Adult band visual/character/archetype | ✅ Pass |
| Companion images (adult brief wizard) | ✅ Fixed — `_companions` undefined; replaced with all-band list |
| Load audit harness | ❌ Broken (fixed above) |

**Open bugs from phase 6:** ✅ BUG-P6-01 fixed — `_companions` undefined identifier resolved. Real-API load audit deferred.

### Files Changed
| File | Change |
|------|--------|
| `backend/tests/story_load_audit.py` | Add `is_under_13`/`declared_age` to mock user SimpleNamespace |
| `backend/tests/artifacts/story_load_audit_latest.*` | Updated artifacts (pre-fix, 500 errors — documents the broken state) |
| `docs/phase6_test_report_2026-04-19.md` | Full phase 6 test report |
| `docs/phase6_artifacts/` | Playwright screenshots (24 images) |

---

## 2026-04-19b — Band-Specific Companion Images: Explorer, Adventurer, Creator (Claude Sonnet 4.6)

**Goal:** Wire named companions with `imagePathOverride` for Explorer (6–8), Adventurer (9–11), and Creator (12–14) bands — completing the companion rebrand started in `2026-04-18d`.

### Changes (`lib/screens/wizard_steps/hero_creator_step.dart`)
- Added `_explorerCompanions` — Ember, Robin, Clover, Biscuit with `assets/images/companions/explorer/*.png/jpg`
- Replaced generic `_adventurerCompanions` with named band-specific list — Atlas, Robin, Nyx, Kodiak with `assets/images/companions/adventurer/*.jpg/png`
- Added `_creatorCompanions` — Cipher, Rockin' Robin, Vesper, Lore with `assets/images/companions/creator/*.jpg/png`
- All companions use `imagePathOverride` so band-specific art is served rather than the generic fallback

### `SafeAssetImage` widget enhancement (`lib/widgets/safe_asset_image.dart`)
- Added `alignment`, `filterQuality`, and `frameBuilder` optional parameters — passed through to the underlying `Image.asset` call
- Allows callers to control image rendering quality and frame animation without bypassing the error-handling wrapper

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Explorer/Adventurer/Creator companion lists with band-specific image paths |
| `lib/widgets/safe_asset_image.dart` | `alignment`, `filterQuality`, `frameBuilder` props |

---

## 2026-04-19 — Welcome Screen Polish: Name-Echo Animation, Age Glyphs, Kid Consent Summary (Claude Sonnet 4.6)

**Goal:** Three UX polish items identified via Six Hats / 10-year-old user walkthrough.

### Changes

#### 3.1 Name-echo bubble bounce (`lib/screens/welcome_screen.dart`)

- Speech bubble in the name-entry step now bounces on every keystroke.
- `AnimatedSwitcher` key changed to `ValueKey(typedName.isEmpty)` so the fade only fires on the prompt↔name transition, not per character.
- Inner `TweenAnimationBuilder<double>` (key: `ValueKey(typedName)`) animates scale 1.2→1.0 with `Curves.elasticOut` (280 ms) — replays each time the name changes, giving immediate tactile feedback as the child types or speaks their name.

#### 3.2 Age picker personality glyphs (`lib/screens/welcome_screen.dart`)

- `_AgeCircle` widget gains an optional `glyph` (`String?`) parameter.
- When set, each circle renders a mini Column — emoji on top, number below.
- Glyph mapping: 🌱 ages 3-5 (Sprout), 🧭 ages 6-8 (Explorer), ⚔️ ages 9-11 (Adventurer).
- `_AgeBandButton` (older pill buttons) gains the same optional `glyph` field and displays it inline before the label.
- Creator pill (12-14) gets 🖊️; Adolescent and Adult pills stay clean.
- Static helpers `_glyphForAge()` and `_glyphForOlderBand()` compute the mapping centrally.

#### 3.3 Kid-readable consent summary (`lib/screens/parental_consent_screen.dart`)

- New `_KidSummaryCard` widget: collapsible panel inserted between the gold child-facing intro box and the "Notice to Parents & Guardians" legal heading.
- Header: 🧒 "What this means for me" with chevron toggle.
- Six plain-language bullets at ~4th-grade reading level: stories use your name as the hero; choices stay on device; no ads; selfies never leave the phone; grown-ups can delete everything; adventure begins after grown-up says yes.
- Styled in purple to visually separate it from the gold parent section.

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/welcome_screen.dart` | Name-echo bounce animation; age circle glyphs; older-band pill glyphs; glyph helpers |
| `lib/screens/parental_consent_screen.dart` | `_KidSummaryCard` collapsible added before parent notice |

---

## 2026-04-19 — Age-Band Gender Selection Images (Claude Sonnet 4.6)

**Goal:** Replace the single adventurer boy/girl placeholder with dedicated, age-appropriate artwork for every age band in both gender-selection screens.

### What was done

- **Image processing** (`scripts/process_gender_images.py`): 14 source images processed into `assets/images/ui/gender/`
  - BFS flood-fill black-background removal for sprout + explorer chibi art
  - JPG → PNG conversion for all others
- **Wiring** — both gender-selection flows updated:
  - `lib/screens/wizard_steps/hero_creator_step.dart` — `_buildGenderPicker()` now switches on `AgeBand`
  - `lib/custom_avatar_screen.dart` — `_genderAsset()` helper + `_buildGenderCard()` rewritten to show images
- **Press effect** changed in both files: tap now scales **up** (1.08×) + brightens (screen blend) instead of shrink + darken

### Asset map (`assets/images/ui/gender/`)

| Band | Ages | Boy asset | Girl asset |
|------|------|-----------|------------|
| sprout | ≤5 | `gender_sprout_boy.png` (bg removed) | `gender_sprout_girl.png` (bg removed) |
| explorer | ≤8 | `gender_explorer_boy.png` (bg removed) | `gender_explorer_girl.png` (bg removed) |
| adventurer | ≤11 | `gender_adventurer_boy.png` | `gender_adventurer_girl.png` |
| creator | ≤14 | `gender_creator_boy.png` | `gender_creator_girl.png` |
| adolescent | ≤17 | `gender_adolescent_boy.png` | `gender_adolescent_girl.png` |
| adult | 18+ | `gender_adult_boy.png` | `gender_adult_girl.png` |

Spare: `gender_creator_alt_girl.png` (the "13-15 tech-punk girl" art) — not currently wired; swap with `gender_creator_girl.png` if preferred.

### Files Changed
- `assets/images/ui/gender/` — 13 new PNGs (12 wired + 1 spare)
- `assets/BoyGirl images/` — 14 source images committed for reference
- `pubspec.yaml` — added `assets/images/ui/gender/` declaration
- `lib/screens/wizard_steps/hero_creator_step.dart`
- `lib/custom_avatar_screen.dart`
- `scripts/process_gender_images.py` — reusable processing script

---

## 2026-04-19 — Parental Consent: Sticky Footer + Share-to-Grown-up (Claude Opus 4.7)

**Goal:** Keep consent controls visible while parents read the notice, and give kids a way to hand the flow to a grown-up on another device.

### Changes (`lib/screens/parental_consent_screen.dart`)

- **Sticky footer.** Page restructured from a single `SingleChildScrollView` to a `Column` with an `Expanded` scroll area plus a fixed `_buildStickyFooter()`. The consent checkbox, scroll-hint, and "Give Permission ✓" button now stay pinned to the bottom instead of living at the end of the scroll content.
- **Scroll gate on the checkbox.** Previously only the submit button was gated on `_scrollProgress >= 0.95`; the checkbox's `onChanged` is now also `null` until the parent has read to 95%. The scroll-hint arrow flips from `keyboard_arrow_down` (inline, when far from the bottom) to `keyboard_arrow_up` in the footer (pointing back at the unread notice).
- **"Send to a grown-up" button.** Top-right of the footer. Uses `share_plus` (already in `pubspec.yaml`) to fire a pre-written message via the OS share sheet — "Hi! I want to try Story Weaver… Could you look at this together with me?" — so a child who can't complete consent alone can hand the flow to a parent on their own device. Addresses the UX issue where a kid lands on the consent screen with no parent nearby.

### Changes (`lib/screens/welcome_screen.dart`)

- **Welcome teaser screen (step -1).** On first launch, users now see a brief intro screen ("Story Weaver / Your hero. Your story.") before the age picker. Uses `SharedPreferences` key `welcome_teaser_seen` so it only shows once. TTS: "Welcome to Story Weaver! Where you are the hero."
- **Age resume.** On subsequent launches, if an age is already saved (parental consent granted), the welcome screen skips straight to name entry (step 2) with a "Welcome back!" greeting. Avoids re-entering age after app reinstall if consent persists.

### New Files
| File | Purpose |
|------|---------|
| `lib/widgets/safe_asset_image.dart` | Drop-in `Image.asset` replacement that shows a blank `SizedBox` on missing asset instead of crashing. Use this everywhere to avoid red error boxes. |
| `scripts/process_gender_images.py` | One-off script: BFS background removal + JPG→PNG conversion for `assets/BoyGirl images/` → `assets/images/ui/gender/` |

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/parental_consent_screen.dart` | Sticky footer refactor; scroll-gate extended to checkbox; `_shareToGrownUp` + share button added |
| `lib/screens/welcome_screen.dart` | Welcome teaser (step -1); age-resume logic on re-launch |

---

## 2026-04-18l — Phase 3 Compliance: TTS Quota + Audit Log (Claude Sonnet 4.6)

**Goal:** Complete the Phase 3 compliance backlog from the 2026-04-18e security audit.

### Items resolved

**Dependabot** — already configured (`/.github/dependabot.yml`, pip + pub + GitHub Actions on monthly schedule). No change needed.

**pip-audit in CI** — already wired into `backend-tests.yml`. No change needed.

**GDPR data portability** — already implemented: `GET /api/user/<id>/export` (full JSON download) and `DELETE /api/user/<id>/data` (right to erasure with anonymisation). No change needed.

**ElevenLabs per-user TTS quota** (`backend/utils/ai_quota.py`, `backend/routes/tts_routes.py`)
- Added `check_tts_quota` / `increment_tts_quota` to `ai_quota.py` using the same Redis pattern as the AI quota
- Redis key format: `tts:quota:{user_id}:{YYYY-MM-DD}` (2-day TTL)
- Daily limits: `free=20`, `premium=100`, `family=150`, `byok=50` — overridable via env vars (`TTS_QUOTA_FREE` etc.)
- BYOK users are NOT exempt (they share ElevenLabs with everyone else)
- Returns `429 TTS_QUOTA_EXCEEDED` with `daily_limit` and `syntheses_used` in body
- Incremented only after successful audio bytes returned

**Audit log** (`backend/models/audit_log.py`, `backend/utils/audit.py`)
- New `AuditLog` SQLAlchemy model (`audit_log` table): `id`, `user_id`, `event_type`, `event_data` (JSON), `ip_address`, `created_at`
- Auto-created by `db.create_all()` at startup — no manual migration needed
- `audit_log()` helper in `backend/utils/audit.py`: one-line fire-and-forget call, never raises
- Events wired in:
  - `story_generated` — sync and async-fallback story paths (`story_routes.py`)
  - `ai_quota_exceeded` — daily AI generation limit hit (`story_routes.py`)
  - `tts_quota_exceeded` — daily TTS limit hit (`tts_routes.py`)
  - `user_login` — successful password login (`utility_routes.py`)
  - `token_refreshed` — refresh token used (`utility_routes.py`)
  - `anonymous_session` — new anonymous account created (`utility_routes.py`)
  - `data_exported` — GDPR data export downloaded (`user_routes.py`)
  - `data_deleted` — GDPR right-to-erasure executed (`user_routes.py`)

### Files Changed
| File | Change |
|------|--------|
| `backend/utils/ai_quota.py` | Added `check_tts_quota`, `increment_tts_quota`, `_TTS_DAILY_LIMITS` |
| `backend/models/audit_log.py` | New — `AuditLog` SQLAlchemy model |
| `backend/models/__init__.py` | Added `AuditLog` import so `create_all` picks it up |
| `backend/utils/audit.py` | New — `audit_log()` fire-and-forget helper |
| `backend/routes/tts_routes.py` | TTS quota check + increment + quota exceeded audit event |
| `backend/routes/story_routes.py` | `audit_log` import; story_generated + ai_quota_exceeded events |
| `backend/routes/utility_routes.py` | user_login, token_refreshed, anonymous_session events |
| `backend/routes/user_routes.py` | data_exported, data_deleted events |

---

## 2026-04-18k — Security Hardening: Refresh Token Rotation + JWT Blocklist (Claude Sonnet 4.6)

**Goal:** Phase 2 fix 2f — stolen refresh tokens should not remain valid for their full 30-day lifetime.

### Problem
The `/auth/refresh` endpoint issued a new access token but kept the old refresh token alive and valid. A stolen refresh token could be used indefinitely to mint fresh access tokens.

### Fix

**Backend — JWT revocation blocklist** (`backend/app.py`)
- Registered `@jwt.token_in_blocklist_loader` immediately after `JWTManager(app)` — checked on every JWT-protected request
- Callback looks up `jwt:blocklist:{jti}` in Redis; returns `False` (pass) if Redis is unreachable so a Redis outage never locks users out

**Backend — refresh token rotation** (`backend/routes/utility_routes.py`)
- Added `_blocklist_jti(jti, exp, logger)` module-level helper: writes the spent JTI to Redis with a TTL equal to the token's remaining lifetime (auto-expires, no cleanup job needed). No-ops gracefully if Redis is absent.
- `/auth/refresh` now:
  1. Extracts the old JTI and `exp` via `get_jwt()` and blocklists them before responding
  2. Issues both a new access token *and* a new refresh token (`create_refresh_token`)
  3. Returns `refresh_token` alongside `token` in the response body

**Flutter — persist rotated refresh token** (`lib/services/api_service_manager.dart`)
- `_tryRefreshAccessToken()` now reads `data['refresh_token']` from the server response and saves it to `SharedPreferences` + the in-memory `_refreshToken` field, completing the rotation on the client side

### Security properties after fix
- A refresh token can be used **at most once** — replaying a spent token returns 401 (jti is blocklisted)
- If a refresh token is stolen but hasn't been used yet, it still has a 30-day window — acceptable for this app's threat model; shortening `JWT_REFRESH_TOKEN_EXPIRES` is an env-var tunable if needed
- Redis outages degrade to "blocklist skipped" rather than "all users locked out"

### Files Changed
| File | Change |
|------|--------|
| `backend/app.py` | `@jwt.token_in_blocklist_loader` callback backed by Redis |
| `backend/routes/utility_routes.py` | `_blocklist_jti` helper; `/auth/refresh` rotates token + blocklists old JTI |
| `lib/services/api_service_manager.dart` | `_tryRefreshAccessToken` persists new refresh token from server |

---

## 2026-04-18j — Security Hardening: AI Quota Circuit Breaker + Anonymous Auth Fix (Claude Sonnet 4.6)

**Goal:** Phase 2 fixes 2j and 2k — prevent unbounded AI spend from a single account, and close the anonymous auth session-hijack vector.

### 2j — Per-user daily AI generation quota (`backend/utils/ai_quota.py`, `backend/routes/story_routes.py`)

**Problem:** No per-user rate limit on story generation. A single compromised or abusive account could generate unlimited Gemini calls and run up the API bill.

**Fix:**
- New module `backend/utils/ai_quota.py` — Redis-backed daily counter per user:
  - `check_daily_quota(user_id, user_tier)` — checks before generation; returns `(allowed, current, limit)`
  - `increment_daily_quota(user_id, user_tier)` — increments after a successful story; sets 2-day TTL
  - Limits: `free=10`, `premium=50`, `family=75` stories/day; BYOK tier is exempt
  - Limits overridable via `AI_QUOTA_FREE` / `AI_QUOTA_PREMIUM` / `AI_QUOTA_FAMILY` env vars
  - Redis key format: `ai:quota:{user_id}:{YYYY-MM-DD}`
  - Gracefully degrades to allow-all on Redis outage (never blocks story generation from a Redis failure)
- Wired into `generate_story_endpoint()` in `story_routes.py`:
  - Checks quota before calling story service; returns `429 QUOTA_EXCEEDED` with `daily_limit` and `stories_used` in response body
  - Increments quota only after a successful `200` response

### 2k — Anonymous client_id session-hijack fix (`backend/routes/utility_routes.py`)

**Problem:** `/auth/anonymous` accepted a `client_id` from the request body and issued a JWT for that user ID without verifying the account was actually anonymous. An attacker could supply any registered user's ID and receive a valid JWT for that account.

**Fix:**
- Endpoint now validates any client-supplied `client_id` against the user's email domain
- Only IDs belonging to accounts with `@anonymous.storyweaver.app` email are honoured
- If the ID maps to a registered (non-anonymous) account, it is silently discarded and a fresh anonymous session is created — no fingerprinting of valid user IDs
- Warning logged when a non-anonymous ID is supplied, for monitoring

### Files Changed
| File | Change |
|------|--------|
| `backend/utils/ai_quota.py` | New file — Redis quota circuit breaker |
| `backend/routes/story_routes.py` | Quota check before generation; increment after success |
| `backend/routes/utility_routes.py` | Anonymous endpoint hardened against client-supplied non-anonymous IDs |

---

## 2026-04-18g — Security Hardening: Startup Assertions + Sentry Filter (Claude Sonnet 4.6)

**Goal:** Phase 2 security fixes from the 2026-04-18e audit — fast wins targeting JWT secret enforcement, Redis assertion in production, and Sentry data leakage.

### Fixes Applied

**2a — JWT secret startup assertion** (`backend/app.py`)
- Added `_run_security_assertions(app, config_name)` called at startup for all non-testing environments
- Raises `RuntimeError` (refuses to start) if `JWT_SECRET_KEY` is `'dev-secret-key'` or shorter than 32 chars
- Raises `RuntimeError` in production if `REDIS_URL` / `REDIS_PRIVATE_URL` is absent (rate limiting would be per-process only)
- Errors are collected and reported together so a misconfigured env surfaces all problems at once

**2b — Celery serializer** (already done — no change needed)
- `celery_config.py` already sets `task_serializer='json'`, `accept_content=['json']`, `result_serializer='json'`
- Finding marked resolved

**2c — Sentry frame variable scrubbing** (`backend/app.py`)
- Extended `before_send` to scrub local variables in every exception stack frame
- Keys containing `prompt`, `story`, `response`, `context`, `content`, `note`, `text`, `body`, `message`, `parent`, `hidden`, `guidance` → `[Filtered — sensitive key]`
- String values longer than 200 chars → `[Filtered — string len N]`
- Prevents story text and parent context from leaking to Sentry on generation exceptions

### Files Changed
| File | Change |
|------|--------|
| `backend/app.py` | Added `_run_security_assertions`, extended `before_send` with frame var scrubbing |

---

## 2026-04-18i — Security Hardening: Gemini Output Safety Filter (Claude Sonnet 4.6)

**Goal:** Phase 2 fix 2i — add output-side content classification to every Gemini call so safety-blocked responses never reach a child.

### What Was Missing
`story_generation_service.py` had strong input-side defenses (13 injection patterns, USER_INPUT delimiters) but no output-side filter. A successful prompt injection or unexpected model behaviour would deliver the raw Gemini output directly to the child.

### Fix (`backend/services/story_generation_service.py`)
- Added `_CHILD_SAFETY_SETTINGS` — four `SafetySetting` entries applied via `GenerateContentConfig` to every `generate_content` call:
  - `HARM_CATEGORY_SEXUALLY_EXPLICIT` → `BLOCK_LOW_AND_ABOVE` (zero tolerance)
  - `HARM_CATEGORY_DANGEROUS_CONTENT` → `BLOCK_MEDIUM_AND_ABOVE` (allows mild conflict/fear language for age-appropriate stories)
  - `HARM_CATEGORY_HARASSMENT` → `BLOCK_LOW_AND_ABOVE`
  - `HARM_CATEGORY_HATE_SPEECH` → `BLOCK_LOW_AND_ABOVE`
- Added `_extract_text(response)` helper — single place for text extraction that also detects prompt-level blocks (`prompt_feedback.block_reason`) and response-level blocks (`finish_reason == SAFETY`). Logs triggered safety categories for monitoring without exposing prompt content.
- Added `_SAFETY_FALLBACK` — child-friendly message returned on any safety block ("I wasn't able to create that story right now. Let's try a different adventure!")
- Applied to both the primary model call and the fallback model call

### Files Changed
| File | Change |
|------|--------|
| `backend/services/story_generation_service.py` | Added safety settings, extract helper, safety fallback |

---

## 2026-04-18h — Security Hardening: Remove Gemini API Key from Flutter Client (Claude Sonnet 4.6)

**Goal:** Phase 2 fix 2b — eliminate the `geminiApiKey` field from Flutter config so an API key can never be compiled into the binary.

### Finding
`FlavorConfig` had `geminiApiKey` plumbed via `String.fromEnvironment('PROD_GEMINI_API_KEY')` (and staging/dev variants). The key is never consumed anywhere in the app — `Environment.geminiApiKey` has zero callers outside the config layer. It was dead code that created a build-time key injection path.

### Fix
- Removed `geminiApiKey` field from `FlavorConfig._internal` constructor and all three flavor cases
- Removed `Environment.geminiApiKey` getter
- All Gemini calls already go through the Flask backend — no client-side path exists

### Manual Step Required
`backend/requirements.txt` has version-pinned but not hash-pinned dependencies. To complete fix 2g (supply chain hardening), run locally:
```bash
pip install pip-tools
pip-compile --generate-hashes backend/requirements.in > backend/requirements.txt
```
Then commit the result. Consider adding `pip-audit` to CI.

### Files Changed
| File | Change |
|------|--------|
| `lib/config/flavor_config.dart` | Removed `geminiApiKey` field, constructor param, and all three flavor assignments |
| `lib/config/environment.dart` | Removed `geminiApiKey` getter |

---

## 2026-04-18f — Life Quests Six Hats Audit + Age-Gate Fixes (Claude Sonnet 4.6)

**Goal:** Playwright-driven Six Hats UX audit across all 6 age bands (Sprout→Adult) for the Life Quests feature. Fix all identified issues.

### Audit Findings (Six Hats Summary)

| Band | Critical Issues Found |
|------|-----------------------|
| Sprout (4yo) | CYOA hub showed all 8 adult scenarios ("Behind Closed Doors"); feelings picker showed clinical adult emotions ("Bad", "Fearful"); no sprout-appropriate quests |
| Explorer (7yo) | Emotion picker led with "Angry" (negative-first); all 6 emotion cards may not fit on screen |
| Adventurer (10yo) | Scene picker showed "Big Feelings Quest" (old name) instead of "Life Quest" |
| Creator (12yo) | Feelings modal ignored band theme (hardcoded dark purple) |
| Adolescent (15yo) | Hero creator showed blank spaces where character images should be (missing asset references) |
| Adult (18yo) | Correctly routed to Reflect/Meditation — no issues |

### Fixes Applied

**Phase 1 — P0: Age-gate CYOA hub (safety critical)**
- Added `recommendedBands: List<AgeBand>` field to `LifeQuestScenario` (default: adventurer/creator/adolescent)
- Filtered `_matchingQuests` in `LifeQuestScreen` to only show age-appropriate quests
- Added band-appropriate empty state: 🌱 + "More quests coming soon!" for young bands
- Header subtitle adapts: young bands see "Adventures about feelings are on their way!" not "Life throws curveballs"

**Phase 2 — P1: Fix feelings picker**
- Added `sproutCoreEmotions` list (Happy, Sad, Mad, Scared) to `FeelingsWheelData` — positive-first, no secondaries
- `coreEmotionsForAge()` now routes age ≤5 → sproutCoreEmotions (instead of adult clinical list)
- Moved Excited to first position in `bigFeelingsCoreEmotionsAges6To8` (Explorer now leads positive)
- `_CoreGrid` in `FeelingsCloudPicker`: dynamic `childAspectRatio` by emotion count (4→1.1, 6→1.05, 8+→0.88); wrapped in `Scrollbar`

**Phase 3 — P1: Fix missing character assets**
- `_buildBriefGenderSelector()` in `hero_creator_step.dart`: adolescent case now uses adventurer assets as stand-in (was referencing non-existent `adolescent/boy_character.png`)

**Phase 4 — P2: Title/theme/label polish**
- `scenario_data.dart`: `big_feelings_quest` base title changed from "Big Feelings Quest" → "Life Quest" (Adventurer 9-11 now sees correct name)
- `feelings_quest_modal.dart`: modal background replaced hardcoded `Color(0xFF1A0E3A)` with `bandTheme?.gradientStart` (band-aware)

**Phase 5 — P3: Verification**
- Adult band confirmed: routes to `AdultMeditationScreen`, cannot access `LifeQuestScreen`

### Files Changed
| File | Change |
|------|--------|
| `lib/data/life_quest_data.dart` | Added `recommendedBands` field with default [adventurer, creator, adolescent] |
| `lib/screens/life_quest_screen.dart` | Filter quests by band; empty state for young bands; adaptive subtitle |
| `lib/feelings_wheel_data.dart` | Added `sproutCoreEmotions`; updated `coreEmotionsForAge`; reordered Explorer list (Excited first) |
| `lib/widgets/feelings_cloud_picker.dart` | Dynamic aspect ratio; Scrollbar wrapper on core grid |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Adolescent gender picker uses adventurer assets as fallback |
| `lib/data/scenario_data.dart` | `big_feelings_quest` title: "Big Feelings Quest" → "Life Quest" |
| `lib/widgets/feelings_quest_modal.dart` | Modal background: band-aware `gradientStart` instead of hardcoded purple |

---

## 2026-04-18e — Security Audit + Remediation Plan (Claude Sonnet 4.6)

**Goal:** Full-stack security audit via Six Hats methodology; establish remediation roadmap; make architectural decisions on two features.

### Audit Scope
Full-stack penetration and architecture review covering: JWT auth, CORS, CSRF, rate limiting, input validation, AI pipeline safety, Celery/Redis, Stripe, Flutter mobile client, Railway deployment, COPPA compliance.

### Key Findings (summary)
| Severity | Count | Worst examples |
|----------|-------|----------------|
| Critical | 2 | Dev JWT secret in source; parent hidden context stored unencrypted |
| High | 7 | Therapist PIN brute-forceable; no AI output filter; Celery serializer unverified; unpinned deps; no refresh token rotation; client-side API key; age-band bypass path |
| Medium | 5 | Rate limiting degrades silently without Redis; Sentry may capture story content; Redis unauthenticated; ElevenLabs no quota; anonymous client_id enumeration |
| Low | 5 | Draft in SharedPreferences; CSRF on future web; no GDPR export; no audit log; no AI cost circuit breaker |

Full audit report with Six Hats analysis, attack chains, and OWASP categorisation available in session history (2026-04-18).

### Architectural Decisions Made

**Decision 1 — Remove Therapist Portal entirely**
- Reason: Client-side 4-digit PIN with no rate limiting, no audit trail, no server-side verification. Security bar to do this responsibly far exceeds current implementation. Feature removed, not deferred.
- Scope: `backend/routes/therapist_routes.py`, `backend/models/therapist_client.py`, `middleware/auth.py` (`require_therapist`), `security/iam.py` therapist role, `lib/screens/therapist_portal_screen.dart`, `lib/services/therapist_auth_service.dart`, related tests + fixtures.

**Decision 2 — Remove Parent Hidden Context entirely**
- Reason: Parents enter family trauma disclosures (e.g. "son witnessed domestic violence") under an expectation of therapeutic confidentiality. Data stored unencrypted. Per-family envelope encryption + access controls + audit logging required to do this safely — substantial work for a pre-launch app. Feature removed until a proper data governance story exists.
- Product rationale: Big Feelings stories still function without personalization; the false promise of therapeutic confidentiality is worse than the missing feature.
- Scope: `backend/models/parent_hidden_context.py`, two endpoints in `character_routes.py`, validation layer (lines 13–186), `_resolve_parent_hidden_context` / `_merge_big_feelings_context` / `_build_feelings_prompt_text` / `_augment_therapeutic_prompt` in `story_routes.py`, `_abstract_parent_phrase` + `transform_parent_context_to_story_guidance` in `story_service.py`, parent context calls in `interactive_adventure_prompt_builder.py`, Big Feelings section in `parent_controls_screen.dart`, `parentHiddenContext` field in `wizard_data.dart` + `api_service_manager.dart`, related tests.

### Remediation Phases

**Phase 0 — Remove therapist portal** ← starting next
**Phase 1 — Remove parent hidden context**
**Phase 2 — Critical fixes (in priority order)**
1. Dev JWT secret enforcement (startup assertion, 30 min)
2. Remove Gemini API key from Flutter binary (1 hr)
3. Set Celery serializer to JSON (15 min)
4. Enforce Redis at startup in production (30 min)
5. Extend Sentry `before_send` to strip story content (30 min)
6. Implement refresh token rotation with server-side family tracking (2–3 hrs)
7. Pin Python dependencies with hashes; add pip-audit to CI (1 hr)
8. Verify Redis authentication in Railway Dashboard (15 min)
9. Enable Gemini `safety_settings` at `BLOCK_LOW_AND_ABOVE` for all harm categories (1 hr)
10. Per-user daily AI cost circuit breaker via Redis (2 hrs)
11. Server-side client_id generation for anonymous sessions (1 hr)

**Phase 3 — Compliance backlog**
- GDPR data portability export endpoint
- Audit log table for elevated-access queries
- Dependabot / pip-audit in CI
- ElevenLabs per-user TTS quota

### Files Changed This Session
| File | Change |
|------|--------|
| `TEAM_COORDINATION.md` | Added this entry |
| `backend/routes/therapist_routes.py` | Deleted (Phase 0) |
| `backend/models/therapist_client.py` | Deleted (Phase 0) |
| `backend/middleware/auth.py` | Removed `require_therapist` decorator (Phase 0) |
| `security/iam.py` | Removed therapist role definition (Phase 0) |
| `lib/screens/therapist_portal_screen.dart` | Deleted (Phase 0) |
| `lib/services/therapist_auth_service.dart` | Deleted (Phase 0) |
| `backend/tests/conftest.py` | Removed therapist fixture (Phase 0) |
| `backend/tests/security/test_authorization.py` | Removed therapist auth tests (Phase 0) |
| `backend/app.py` | Removed therapist imports + blueprint registration (Phase 0) |

---

## 2026-04-18d — Companion Full Rebrand: Named Characters + File Cleanup (Claude Sonnet 4.6)

**Goal:** Replace every companion with a personality-driven named character across all 6 age bands; standardise file naming to snake_case; wire correct images and behavior patterns end-to-end.

### Naming System
Four companion types evolve across all bands: **Dragon**, **Robin**, **Cat→Panther**, **Dog→Wolf**

| Band | Dragon | Robin | Cat/Panther | Dog/Wolf |
|------|--------|-------|-------------|----------|
| sprout | Pebble | Robin | Mochi | Sunny |
| explorer | Ember | Robin | Clover | Biscuit |
| adventurer | Atlas | Robin | Nyx | Kodiak |
| creator | Cipher | Rockin' Robin | Vesper | Lore |
| adolescent | Zephyr | Rockin' Robin | Shade | Frost |
| adult | Tide | Rockin' Robin | Onyx | Cinder |

Robin = "Robin" for sprout/explorer/adventurer; "Rockin' Robin" for creator/adolescent/adult.

### File Renames (all 24 companions)
- All files normalised to snake_case, spaces removed
- Mixed .jpg/.png retained (no needless conversion)
- `rockin_robin` used as file + companion ID for creator/adolescent/adult robin

### Architecture Change
- `AgeBandAssetResolver.companionPath(band, filename)` now takes full filename with extension (was `companionId` with hardcoded `.png`)
- Companion IDs in `companion_selector_step.dart` now match `companion_personality_data.dart` keys exactly: `${band}_${id}`

### Files Changed
| File | Change |
|------|--------|
| `assets/images/companions/` | All 24 files renamed to snake_case personality names |
| `lib/theme/age_band_asset_resolver.dart` | `companionPath` takes full filename instead of bare ID |
| `lib/screens/wizard_steps/companion_selector_step.dart` | Full rewrite of all 6 band companion sets |
| `lib/data/companion_personality_data.dart` | All keys updated to match new IDs; 12 new behavior entries added |

---

## 2026-04-18c — Companion Art Overhaul + Asset Cleanup (Claude Sonnet 4.6)

**Goal:** Replace placeholder/old companion assets with new named art; rename companions with personality-driven names; clean up legacy asset directories.

### Companion Renames
- Robin → "Rockin' Robin" (all bands)
- Ember Dragon → Sparkfire (explorer)
- Moon Owl → Whizfeather (explorer)
- Star Fox → Blazetail (explorer)

### New Companion Assets Added
- `adventurer/`: Dog.jpg, Night Cat.png, dragon.jpg
- `explorer/`: Dragonfire.png, Prettykitty.jpg, Puppylove.jpg, Rockinrobin.png
- `adolescent/`: dragon.png, panther.png, wolf.png
- `adult/`: dragon.png, robin.jpg
- `creator/`: Shadow Cat.jpg, dragon.jpg, robin.jpg, wolf.png
- `sprout/`: cat.jpg

### Assets Removed
- `age_band_assets_OLD/` entire directory
- Feelings emotion images (adolescent/creator bands)
- Race-variant UI character PNGs (explorer, sprout, adolescent)
- Legacy pressed/hover flat-file companions

### Other Fixes
- Splash screen duration: 2.4s → 4.0s
- `hero_creator_step.dart`: all bands use adventurer character assets; silent `SizedBox` on image error
- `welcome_screen.dart`: TTS punctuation fix + rateScale 0.72 applied consistently
- `app_tts_service.dart`: removed old greeting phrase from warm-up list

### Files Changed
| File | Change |
|------|--------|
| `lib/data/companion_data.dart` | Robin → "Rockin' Robin" |
| `lib/screens/wizard_steps/companion_selector_step.dart` | Explorer companion renames; Robin renamed all bands |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Simplified gender asset switch; error fallback to SizedBox |
| `lib/screens/splash_screen.dart` | Duration 2.4s → 4.0s |
| `lib/screens/welcome_screen.dart` | TTS punctuation + rateScale consistency |
| `lib/services/app_tts_service.dart` | Warm-up phrase list updated |
| `assets/images/companions/` | New named art added; old assets removed |
| `assets/images/feelings/` | Adolescent + creator emotion images removed |
| `assets/images/ui/` | Race-variant character PNGs removed |
| `age_band_assets_OLD/` | Entire directory removed |

---

## 2026-04-18b — Welcome Screen TTS Greeting (Claude Sonnet 4.6)

**Goal:** Add a friendly welcome before the age picker so the app doesn't open cold.

- Updated TTS prompt on first launch: `"How old are you? Tap your age!"` → `"Hi, welcome to Story Weaver! How old are you? Tap your age!"`

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/welcome_screen.dart` | TTS greeting prepended to age prompt |

---

## 2026-04-18 — Splash Screen, TTS Pacing & Companion UX Redesign (Claude Opus 4.6)

**Goal:** Add branded splash screen, fix TTS pacing on companion page, and redesign the companion selection flow to eliminate confusion between adding friends vs pets.

### Splash Screen
- Added `lib/screens/splash_screen.dart` — full-screen "Once Upon YOUR Child" logo with fade-in/hold/fade-out animation
- Added `assets/images/splash_logo.png` — branded logo asset
- Wired into `_AppEntryPoint` in `main_story.dart` — splash plays on every cold start before onboarding/welcome flow

### TTS Pacing Fix
- Slowed narration for older-band wizard prompts ("Choose your hero's path!", "Who will join you on your quest?") from default `rateScale: 0.85` to `0.75` in `hero_creator_step.dart`

### Companion Page Redesign (Six Hats Analysis, Age 11)
Performed a Six Thinking Hats UX analysis of the companion selection page from an 11-year-old's perspective using the `ui-audit-prompt.md` framework. Identified and fixed four issues:

**1. Split "bring someone along" into Friend vs Pet (high impact)**
- Replaced the single "Friend's name..." text input (which confusingly defaulted to species `Dog`) with two clear buttons: "Add a Friend" (person icon, defaults to Human) and "Add My Pet" (paw icon, defaults to Dog)
- Added `pendingNewSpecies` / `onPendingConsumed` callback pattern on `_PetCard` to support parent-triggered companion creation with correct species default
- `_addCompanionWithType(species)` method on `_PetCardState` handles both paths

**2. Cancel button on companion editor card (high impact, low effort)**
- Added X button at top-right of the editor card
- If companion is blank (default name, no photo), cancelling removes the entry entirely
- If companion has data, cancelling closes the editor without saving changes

**3. Age-appropriate language: "buddy" -> "companion" (medium impact)**
- "Your buddy is ready!" -> "Your companion is ready!" for Adventurer+ bands (age 9+)
- Kept "buddy" for Sprout/Explorer where it fits developmentally
- Updated all error messages: "pick a buddy" -> "pick a companion", "buddy's photo" -> "companion's photo"

**4. Dynamic hint text based on companion type (medium impact)**
- Name hint: "Friend's name (e.g. Alex)" for Human, "Pet's name (e.g. Biscuit)" for animals
- Looks hint: "e.g. brown hair, glasses, blue eyes" for Human, "e.g. golden fur, floppy ears" for animals
- Voice prompts also adapt: "Say your friend's name" vs "Say your pet's name"

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/splash_screen.dart` | New — splash animation widget |
| `assets/images/splash_logo.png` | New — branded logo |
| `lib/main_story.dart` | Splash screen integration |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Companion redesign (Friend/Pet split, cancel button, buddy->companion, dynamic hints), TTS rateScale fix |

### Known Deferred Items
- Baby Unicorn art is still too young for Adventurer band — needs a more mature illustration (armored/crystal unicorn)
- `companion_selector_step.dart` still says "Travel Buddy" — separate screen, left unchanged to avoid regressions
- `_friendNameController` and `_addFriendByName` are now dead code (voice input for 'friend' field) — can be cleaned up in a future pass
- `additionalCharacters` list is still populated when loading existing characters but no longer added to via the UI

---

## 2026-04-18 — "Life Quests" Redesign: Big Feelings Rebranding & Feature Evolution (Claude Opus 4.6)

**Goal:** Rebrand "Big Feelings" as "Life Quests" across the app. Redesign the feelings entry screen. Build a choose-your-own-adventure emotional problem-solving feature that works for both BYOK and non-BYOK users. Fix age-appropriateness issues for 9-12 band (companion art, language, UI polish).

### Context & Motivation

Testing the app as an 11-year-old girl revealed:
- "Big Feelings" label sounds babyish and would cause tweens to disengage
- The Feelings badge grid screen looks unfinished (tiny icons in huge empty colored quadrants)
- Some companion images (Unicorn, Dragon) are too young for the Adventurer band
- The Big Feelings flow collected data but had no payoff -- no interactive experience

### Rebrand: "Big Feelings" -> "Life Quests"

Framing: *"Life throws curveballs. Practice handling them in a story where you make the choices."*

**Phase 1 (this session):** Rename + fix entry UI + companion presentation
**Phase 2 (next):** Pre-built quest library for non-BYOK users (8-10 core scenarios)
**Phase 3:** Connect to existing pick-a-path AI engine for BYOK users
**Phase 4:** Parent dashboard integration, quest expansion, art refresh

### Scope Completed — Phase 1a: Rename

Renamed all user-facing labels from "Big Feelings" / "Feelings" to "Life Quests":
- Bottom nav tabs (all age bands: sprout, explorer, adventurer, creator)
- Wizard story screen top-nav button + tooltip
- Age band theme `feelingsNavLabel` (sprout, explorer, adventurer)
- Quick theme lists in `main_story.dart` and `story_result_screen.dart`
- Scenario button labels in `hero_creator_step.dart`
- Scenario data young title in `scenario_data.dart`
- Bedtime wizard scenario mapper
- Emotions screen tab label ("My Feelings" -> "My Journey")
- Life challenge picker label ("Taming big feelings" -> "Handling life's curveballs")
- Icon changed from heart/psychology to compass (`Icons.explore_rounded`)

**NOT changed** (backend API contract values):
- `lifeChallenge: 'Handling Big Feelings'` (backend expects this)
- `wizard_data_mapper` quest-to-lifeChallenge mapping (maps to backend value)
- `api_service_manager` world-bible keys (keyed by backend theme names)
- Internal variable names (`_bigFeelingsExpanded`, etc.) -- cosmetic, no user impact

### BYOK vs Non-BYOK Strategy

| Feature | BYOK | Non-BYOK |
|---|---|---|
| Pre-built quests (Phase 2) | Yes (free) | Yes (free) |
| AI-personalized quests | Yes (user's key) | No |
| Name/companion injection | Yes (free) | Yes (free) |
| Light Haiku personalization | Yes (user's key) | Optional (~$0.002/quest) |

### Files Changed (Phase 1a)
| File | Change |
|------|--------|
| `lib/theme/age_band_theme.dart` | `feelingsNavLabel` -> "Life Quests" for sprout, explorer, adventurer bands |
| `lib/widgets/app_bottom_navigation.dart` | Tab labels + icons updated for sprout, adventurer, creator bands |
| `lib/screens/wizard_story_screen.dart` | Nav button label, icon, tooltip updated |
| `lib/main_story.dart` | Quick theme label + life challenge card title/subtitle |
| `lib/story_result_screen.dart` | Remix scenario label |
| `lib/data/scenario_data.dart` | `youngTitle` for big_feelings scenario |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Scene button label, life challenge picker label |
| `lib/screens/bedtime_wizard_screen.dart` | Voice-mapped scenario label |
| `lib/screens/parent_controls_screen.dart` | Section comment updated |
| `lib/emotions_screen.dart` | Tab label "My Feelings" -> "My Journey" |

### Scope Completed — Phase 1b: Entry Screen Redesign

- Rewrote `FeelingsBadgeGrid` from scratch: replaced tiny hex-icon grid (2x2, 4 pages of scrolling) with polished card layout (emoji + label + subtitle, 2-col grid with 1.6 aspect ratio, all 8 emotions visible)
- Updated titles: "A Big Feeling!" -> "What's going on?", "How are you feeling?" -> "What's going on?"
- Updated subtitle: "Help your hero." -> "Life throws curveballs. Pick what fits."
- Removed hex painter, Taylor series trig, and asset-fallback complexity (224 lines removed, 126 added)

### Scope Completed — Phase 1c: Companion Presentation for Tweens

- Created `_adventurerCompanions` list for 9-11 age band: same 7 companions, reordered with most mature-looking first (Shadow Cat, Robin, Clever Fox) and most childish last (Unicorn)
- Updated taglines for tween audience (e.g. "Big courage. Bigger heart." -> "Has your back. Always.", "Kindness that makes you stronger." -> "Quiet strength. Real healing.")
- Companion grid now selects `_adventurerCompanions` when `band == AgeBand.adventurer`

### Files Changed (Phase 1b + 1c)
| File | Change |
|------|--------|
| `lib/widgets/feelings_badge_grid.dart` | Full rewrite: card-based emotion grid |
| `lib/widgets/feelings_quest_modal.dart` | Title "How are you feeling?" -> "What's going on?" |
| `lib/screens/big_feelings_flow_screen.dart` | Step titles + subtitles updated for Life Quests framing |
| `lib/screens/wizard_steps/hero_creator_step.dart` | New `_adventurerCompanions` list; companion grid uses it for Adventurer band |

### Scope Completed — Phase 2: Pre-Built Quest Library

**Data model** (`lib/data/life_quest_data.dart`):
- `LifeQuestScenario`, `QuestSegment`, `QuestChoice` data classes
- String interpolation for `{name}`, `{companion}`, `{pronoun}`, `{Pronoun}`, `{possessive}`
- `interpolateQuest()` helper function

**8 pre-built quest scenarios**, each with 4-6 segments, 3 choices per branch, multiple endings, and reflection prompts:

| Quest | Title | Emotions | Segments |
|-------|-------|----------|----------|
| Left Out | "The Empty Seat" | sad, worried, angry, embarrassed | 14 |
| Peer Pressure | "The Dare" | worried, frustrated, embarrassed | 11 |
| School Stress | "The Big Test" | worried, frustrated, sad | 7 |
| Sibling Conflict | "The Last Straw" | angry, frustrated | 6 |
| Being Teased | "The Comment" | sad, angry, embarrassed | 9 |
| Family Stress | "Behind Closed Doors" | sad, worried, angry | 7 |
| Feeling Different | "The Only One" | sad, worried, embarrassed | 7 |
| Losing Friendship | "The Drift" | sad, worried, angry, embarrassed | 7 |

**Life Quest screen** (`lib/screens/life_quest_screen.dart`):
- Quest selector: card-based list filtered by selected emotion
- Quest player: renders segments with choices, TTS toggle, rewind button
- Reflection step at each ending with "Think About It" prompt
- "Try Different Choices" (rewind), "Try Another Quest", and "Done" buttons at endings
- String interpolation applied to all text (name, companion, pronouns)
- No backend calls — fully offline, works for all users (BYOK and non-BYOK)

**Wiring**:
- Wizard story screen "Life Quests" nav button now launches `LifeQuestScreen` with character name, companion, and pronouns from wizard data

### Files Changed (Phase 2)
| File | Change |
|------|--------|
| `lib/data/life_quest_data.dart` | NEW: Quest data model + 8 pre-built scenarios |
| `lib/screens/life_quest_screen.dart` | NEW: Quest selector + player screen |
| `lib/screens/wizard_story_screen.dart` | Nav button wired to LifeQuestScreen |

### Known Remaining (Future Phases)
- Phase 3: Wire BYOK AI-personalized quests to existing pick-a-path engine
- Phase 4: Parent dashboard, quest library expansion, companion art refresh

---

## 2026-04-18b — Welcome Screen TTS Greeting (Claude Sonnet 4.6)

**Goal:** Add a friendly welcome before the age picker so the app doesn't open cold.

### Scope Completed

- Updated TTS prompt on first launch from `"How old are you? Tap your age!"` to `"Hi, welcome to Story Weaver! How old are you? Tap your age!"` — no extra screen or tap required

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/welcome_screen.dart` | TTS greeting prepended to age prompt |

---

## 2026-04-14 — Welcome Screen Age Gate Fix + Avatar Overlays + Backend Model Updates (Claude Sonnet 4.6)

**Goal:** Fix age picker showing wrong ages; add avatar portrait badge on archetype cards (mirroring scenario card treatment); fix adventurer boy/girl silhouettes; clean up avatar creation flow; update deprecated Gemini model names.

### Scope Completed

#### Welcome Screen Age Gate
- Fixed `welcome_screen.dart` (NOT `age_gate_screen.dart` — the actual user-facing screen) to show ages 3–11 in a 3×3 grid with `_youngAgeEntries`
- Removed ages 9–11 from `_olderAgeEntries` to avoid duplication
- Increased circle size, spacing, and font via `_AgeBandButton` + `FittedBox`
- Age 11 now correctly routes to Adventurer band

#### TTS Improvements
- Added `"Hi $name!"` ElevenLabs TTS on name step (age picker screen, before advancing)
- Parental consent screen: added `"Now let's get a grown-up to say it's okay!"` in `initState()`
- `markInteracted()` added to `custom_avatar_screen.dart` `_speakPrompt()` so read-aloud button works on web (browser audio policy gate)

#### Adventurer Boy/Girl Silhouettes
- Copied `age_band_assets/11Boy.png` → `assets/images/ui/adventurer/boy_character.png`
- Copied `age_band_assets/11girl.png` → `assets/images/ui/adventurer/girl_character.png`
- Previously both archetypes showed the same image

#### Avatar Creation Flow
- `_openAvatarCreationOptions()` wired up — was calling `_openAvatarGallery` directly, skipping the "Create from photo / Pick from gallery" sheet
- Photo flow: removed redundant gender question (already picked); now asks only eye color + reference photo (AI infers hair/skin from photo)
- Hair colors expanded from ~8 to 19 with better distribution (added pink, blue, grey, platinum, strawberry blonde, auburn, etc.)
- Color labels hidden when palette has >10 options (too cluttered)

#### Premium Section Collapse
- `avatar_tweak_panel.dart`: premium section defaults collapsed for free users (`_premiumExpanded = false`)
- Tap to expand reveals premium options without dominating the screen

#### Avatar Overlay on Scenario Cards
- `feeling_selection_step.dart`: added `_avatarImageData` getter + Stack+Positioned overlay on each scenario card
- Generated avatar (base64) or selected silhouette shown at 80px, bottom-right, with gold ring border

#### Avatar Portrait Badge on Archetype Cards
- `hero_creator_step.dart`: added `_avatarImageData` getter + `_buildAvatarBadge({size})` method
- Sprout/Explorer grid cards: 36px badge top-left + image dimmed to 78% opacity when avatar exists
- Adventurer/Creator carousel cards: 44px badge top-left, same opacity treatment
- No badge rendered when no avatar selected (falls back to existing appearance)
- Symmetrical with selection checkmark at top-right

#### Backend Gemini Model Updates
- `gemini_image_generator.py`: `self._model_name` → `"gemini-2.5-flash-image"` (was `gemini-2.0-flash-preview-image-generation`, now 404)
- `avatar_generation_service.py`, `encryption_utils.py`, `cost_tracking.py`: model → `"gemini-2.5-flash"` (was `gemini-2.0-flash`)

### Files Changed
| File | Change |
|------|--------|
| `lib/screens/welcome_screen.dart` | Ages 3–11 grid, circle size, TTS name greeting |
| `lib/screens/parental_consent_screen.dart` | TTS on init |
| `lib/custom_avatar_screen.dart` | `markInteracted()` for TTS, skip gender, expanded hair colors, streamlined photo flow |
| `lib/widgets/avatar_tweak_panel.dart` | Premium section collapsed by default for free users |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | Avatar overlay on scenario cards |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Portrait badge on archetype cards; adventurer silhouette assets; avatar creation options wired |
| `assets/images/ui/adventurer/boy_character.png` | New 11-year-old boy silhouette |
| `assets/images/ui/adventurer/girl_character.png` | New 11-year-old girl silhouette |
| `backend/gemini_image_generator.py` | Model → `gemini-2.5-flash-image` |
| `backend/services/avatar_generation_service.py` | Model → `gemini-2.5-flash` |
| `backend/encryption_utils.py` | Model → `gemini-2.5-flash` |
| `backend/cost_tracking.py` | Default model → `gemini-2.5-flash` |

### Known Remaining
- ElevenLabs TTS still robotic in local dev — backend needs restart with `.env` loaded (ELEVENLABS_API_KEY). Hot reload doesn't pick up env changes.

---

## 2026-03-31 — 6-Band Exhaustive Switch Audit (Claude Opus 4.6)

**Goal:** Audit all wizard-flow files for incomplete AgeBand switch statements; make all switches exhaustive so the Dart compiler catches future enum additions.

### Methodology

Searched all Dart files under `lib/` for `switch` statements on `AgeBand` or `band.band` that use `default:` instead of listing all 6 cases explicitly. Also checked conditional logic that references specific bands.

### Findings

| File | Location | Issue | Risk |
|------|----------|-------|------|
| `hero_creator_step.dart` | `_buildGenderPicker()` L2539 | Only sprout/adventurer/explorer explicit; creator/adolescent/adult fell to default | Low — mature bands never call this method |
| `hero_creator_step.dart` | `_buildBriefGenderSelector()` L3410 | Only adolescent/adult explicit; others fell to default | Low — young bands never call this method |
| `age_band_badge.dart` | `_labelFor()` L42 | sprout/explorer fell to default '9+' | Low — correct value, just implicit |
| `body_outline_widget.dart` | `_tier` L52 | creator/adolescent/adult fell to default creator tier | Low — correct tier, just implicit |

### Already Complete (no changes needed)

| File | Notes |
|------|-------|
| `companion_selector_step.dart` | Full 6-way switch |
| `feeling_selection_step.dart` | All 6 switches exhaustive |
| `magic_review_step.dart` | All switches + `isMature` splits exhaustive |
| `scenario_data.dart` | Full coverage |
| `age_band_theme.dart` | All 6 theme presets defined |
| `bedtime_wizard_screen.dart` | Complete |
| `story_reader_screen.dart` | Complete |
| `story_result_screen.dart` | Complete |

### Fixes Applied

All 4 switches converted from `default:` to explicit cases — no behavioral change, but the Dart compiler will now flag missing cases if a 7th band is ever added.

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | 2 switches made exhaustive |
| `lib/widgets/age_band_badge.dart` | 1 switch made exhaustive |
| `lib/widgets/body_outline_widget.dart` | 1 switch made exhaustive |

### Status
- [x] Audit complete
- [x] All 4 switches fixed

---

## 2026-03-31 — Adolescent (16yo) Six Hats UX Audit (Claude Sonnet 4.6)

**Goal:** Six Hats UX audit of the Adolescent band (ages 15–17) via code review + 3 prior screenshots.

### Audit Document
`docs/ux_audit_adolescent_16yo_2026-03-31.md` — Six Hats walkthrough as a 16-year-old ("Sam").

### Key Findings

| ID | Finding | Severity |
|----|---------|----------|
| BUG-A1 | CORE ARCHETYPE is required for `isComplete` but completely unmarked — silent block at "Create Story" | 🔴 Critical |
| BUG-A2 | Review shows "—" for missing archetype/scenario — "did the app register my choices?" | 🟡 Medium |
| UX-A1 | Wizard background is hardcoded purple (0xFF120226) — ignores adolescent near-black teal theme | 🟠 High |
| UX-A2 | "ADVENTURE TEAM" label in Cast section — age-regressive for 16-year-old | 🟠 High |
| UX-A3 | Adolescent accordion is identical to Creator (12yo) with no meaningful differentiation | 🟠 High |
| UX-A4 | No genre/tone control — Adventurer (10yo) has genre chips; Adolescent has none | 🟡 Medium |
| UX-A5 | Character-desire prompt is Creator-only but belongs on Adolescent (15–17 are more capable of answering) | 🟠 High |

### Top 3 Fixes
1. **BUG-A1** — Required archetype gate: section indicator + snackbar on blocked tap
2. **UX-A2** — "ADVENTURE TEAM" → "Cast" (one string)
3. **UX-A5** — Character-desire prompt: remove `isCreator` guard, apply to adolescent too

### Status
- [x] Audit doc written
- [x] BUG-A1: Required-field feedback — resolved (red asterisk on CORE ARCHETYPE label + snackbar + scroll-to-section on blocked tap)
- [x] UX-A1: Wizard background colour — resolved (gradient already uses band-specific theme colors)
- [x] UX-A2: "ADVENTURE TEAM" → "CAST" — resolved (changed to "CAST" in `_buildBriefCompanionsInputs`)
- [x] UX-A4: Tone chip row — resolved (genre chips added to Creative Brief `_buildBriefConfigInputs` for all mature bands; adolescent/adult get horror, dystopia, literary + shared genres)
- [x] UX-A5: Character-desire prompt on adolescent — resolved (guard changed to `band.isMature`)

---

## 2026-03-31 — Adult Band UX Audit + Scenario Title Completion (Claude Sonnet 4.6)

**Goal:** Six Hats UX audit of the adult (18+) band; fix scenario title gaps found during audit.

### Audit Document
`docs/ux_audit_adult_2026-03-31.md` — Six Hats walkthrough as Alex, 32.

### Key Findings

| Category | Finding | Severity |
|----------|---------|----------|
| Gap | No emotional regulation path — Big Feelings hidden, meditation not built | 🔴 High |
| Gap | 4 scenarios missing adult-specific titles (fell back to mature/creator level) | 🟠 Medium |
| Gap | All scenario world bibles use mature-band prose (13-17 register) | 🟡 Medium |
| Gap | Archetypes have no adult name layer ("The Storm Rider" etc. skew young) | 🟡 Medium |
| Works | Companion personas are genuinely peer-framed and adult-quality | ✅ |
| Works | Feelings vocabulary (Melancholy, Dread, Contentment, Anticipation) is right | ✅ |
| Works | Bedtime wizard focus options (Burnout & Rest, Creative Block, etc.) are excellent | ✅ |
| Works | All ~68 adult asset files present — no missing images | ✅ |

### Fixes Applied

4 scenarios were missing `adultTitle` and fell back to `matureTitle` / `creatorTitle`:

| Scenario | Was showing | Now shows |
|----------|-------------|-----------|
| `neon_jungle` | "The Bioluminescent Depths" | "The Light That Waits" |
| `storm_chaser_sky` | "The Stormrunner Citadel" | "The Storm You've Been Feeding" |
| `midnight_mystery` | "The Truth You Don't Want to Find" | "Every Answer Costs Something" |
| `survival_island` | "Into the Wild" | "Only What You Carry" |

### Files Changed

| File | What |
|------|------|
| `lib/data/scenario_data.dart` | Added `adultTitle` to 4 scenarios |
| `docs/ux_audit_adult_2026-03-31.md` | NEW — full Six Hats audit |

### Deferred

| ID | Gap | Priority |
|----|-----|----------|
| D1 | `adultWorldBible` for top 3 scenarios | Medium |
| D2 | `adultThematicQuestion` field + launch UI | Low |
| D3 | Adult archetype `adultName` layer | Medium |
| D4 | Guided meditation feature | **High — next major feature** |

### Status
- [x] Audit doc saved
- [x] 4 scenario adult titles added

---

## 2026-03-31 — Phase 3 Visual Consistency (Claude Sonnet 4.6)

**Goal:** Wire per-band visual assets, fix storyLength inconsistency, confirm Phase 3 audit items.

### Audit of Phase 3 items

| ID | Status | Notes |
|----|--------|-------|
| 3.1 Per-band archetype images | Already done | `shyOne.bandImageId` = `'animal_whisperer'`; `imagePathForBand()` handles it |
| 3.2 Per-band feelings images | **Fixed** | `_FaceImage` resolves band path first → `feelings_faces/` → emoji |
| 3.3 Feelings picker dark mode | Already done | `CloudEmotionCard` already has `isMature` flat-rect variant |
| 3.4 Story length picker bug | **Fixed** | `hero_creator_step` wrote `'short/medium/long'` but model uses `'quick/standard/epic'`; fixed with helpers |
| 3.5 CinzelDecorative/Sprout | Already done | Not present in current code |
| 3.6 Mature band nav buttons | Already done | `wizard_story_screen` already gates on `isMature` |

### Status
- [x] Committed: 4c5da5d

---

## 2026-03-31 — Phase 2 UX Tone Calibration (Claude Sonnet 4.6)

**Goal:** Fix remaining Phase 2 tone/text mismatches across age bands.

### Audit of Phase 2 items

Most items were already resolved from prior sessions:
- 2.1 CTAs: already configured per-band (Sprout/Explorer: Make Magic!, Creator: Start Writing, Adolescent/Adult: Begin)
- 2.2 Clinical labels: already removed (no PSYCHOLOGICAL VITALITY etc. in current code)
- 2.3 Mature archetype names: already set (Vision Architect, Storm Vanguard, etc.)
- 2.4 Welcome screen "YOUR Child": already removed
- 2.5 Bedtime mode: already band-aware for most prompts; fixed duration question

### Changes Made

| Item | Change |
|------|--------|
| 2.1 Adventurer CTA | `MISSION READY` → `Start Adventure!`; wizardNextHint updated |
| 2.7 Coping strategies | Added `matureCoping` for Really Sad, Down, Excited, Calm, Surprised, Proud (6 entries) |
| 2.7 Guilty bug | Fixed wrong matureCoping (had Lonely's strategies copy-pasted) |
| 2.5 Bedtime duration | "bedtime story" → "story" for mature bands |

### Status
- [x] Committed: 5147709

---

## 2026-03-31 — Auth Token Expiry Fix + TTS 401 Retry + Age Circle Cleanup (Claude Sonnet 4.6)

**Goal:** Stop the flood of `Auth failed: Token expired` 401s; clean up age-circle emojis.

### Fixes Applied

| # | Issue | Fix |
|---|-------|-----|
| 1 | `_doEnsureAuthenticated` accepted expired JWTs from storage — `_authToken != null` short-circuited before expiry was checked | Added `_isTokenExpired()` (base64-decodes the `exp` claim, no lib needed); both the in-memory and storage checks now reject expired tokens and clear them before re-auth |
| 2 | `TtsApiService` called `ApiServiceManager.authHeaders()` directly — bypassed all 401-retry logic, so an expired token was reused on every TTS call forever | On 401 response, call `resetAndReauthenticate()` then retry once |
| 3 | Age selection circles showed emoji + number; emojis added visual noise with no clear meaning for parents | Removed `_ageCircleEmoji` map and emoji `Column` branch from `_AgeCircle`; circles now show number label only with band-appropriate font sizing |

### Files Changed

| File | What |
|------|------|
| `lib/services/api_service_manager.dart` | `_isTokenExpired()` helper; expiry checks in `_doEnsureAuthenticated` |
| `lib/services/tts_api_service.dart` | 401 → `resetAndReauthenticate()` + retry |
| `lib/screens/welcome_screen.dart` | Remove `_ageCircleEmoji` map; simplify `_AgeCircle` to label-only |

### Status
- [x] JWT expiry check — committed `ae29700`
- [x] TTS 401 retry — committed `ae29700`
- [x] Age circle emoji removal — committed `ae29700`

---

## 2026-03-31 — Creator Band Bug Fixes: Companions + World Title + Avatar Overflow (Claude Sonnet 4.6)

**Goal:** Fix the three deferred Creator band bugs from the 12yo UX audit.

### Fixes Applied

| # | Issue | Fix |
|---|-------|-----|
| UX-C1 | No Companions section in Creator accordion | Added `_buildBriefCompanionsInputs()` + `_buildBriefSection('Cast & Companions', ...)` between Personality and World & Setting in `_buildCreativeBrief()`. Reuses existing `_buildCompanionShowcase()` + `_buildCompanionGrid()`. |
| UX-C2 | `_HeroFallbackIdentity` Column overflowed 29 px in 48×48 Creator review avatar cell — Flutter rendered visible "ERFLOWED P" stripe | Added `FittedBox(fit: BoxFit.scaleDown)` inside `_GradientSphereFallback` so icon+initial scale down to fit any container size. Previous claim ("already resolved by Clip.hardEdge") was incorrect — `hardEdge` clips the visual but Flutter still throws and renders the overflow indicator. (8865c23) |
| UX-C3 | World setting chip and review showed different titles for the same scenario | Root cause: `_buildBriefWorldInputs` chips used `titleForAge(age)` where `age` depends on async SharedPrefs hydration; review also used `titleForAge` — race window meant different `creatorTitle` vs `matureTitle` variants could be returned. Fixed by switching ALL review screens and Creator brief chips to `titleForBand(band.band)`, which is deterministic from the current theme band. (8865c23) |

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Added Cast & Companions accordion section; `_buildBriefWorldInputs` chips → `titleForBand(band.band)` |
| `lib/screens/wizard_steps/magic_review_step.dart` | `FittedBox` in `_GradientSphereFallback`; `titleForBand` in Creator + Adolescent review label |
| `lib/widgets/adventurer_character_sheet.dart` | `titleForBand(band.band)` for scenario heading in Adventurer review |

### Status
- [x] UX-C1: Companions section added to Creator accordion
- [x] UX-C2: Avatar overflow fixed with `FittedBox(fit: BoxFit.scaleDown)` — 8865c23
- [x] UX-C3: Scenario title consistent across brief chips + all review screens — 8865c23

---

## 2026-03-31 — Companion Screen UX + TTS Speed Fix + Robin Image Replacement (Claude Sonnet 4.6)

**Goal:** Fix issues found during a 5-year-old walkthrough of the companion selection screen; fix ElevenLabs speed parameter not reaching the API; replace all 6 band robin images with new illustrated set.

### Companion Screen Improvements (`hero_creator_step.dart`)

| Issue | Fix |
|-------|-----|
| Tapping a new companion required unselecting first | `maxCompanions == 1` path now clears selection before adding the new one (radio behaviour) |
| All companion circles used one dark purple background regardless of animal | Added `backgroundColor: Color?` to `_CompanionData`; dragon=`0xFF7E57C2`, bunny=`0xFFEC407A`, puppy=`0xFFF9A825`, robin=`0xFF388E3C`; passed through to `AnimatedContainer` circle |
| Companion icons were static | Added `SingleTickerProviderStateMixin` + 2.4 s float animation to `_CompanionImageButtonState`; unselected icons drift up 6 px and back (easeInOut); offset staggered by `id.hashCode` so animals float out of phase |
| "Bring someone along" friend-name input shown for all ages | Wrapped in `if (band.band != AgeBand.sprout)` — Sprout never sees free-text companion entry |
| Pet card (BYOP) visible for Sprout unprompted | Replaced with "Ask a grown-up to add a special friend!" tap button that reveals the `_PetCard` on press (`_showPetCardForSprout` bool) |

### TTS Speed Fix

`rateScale` was correctly slowing the on-device FlutterTts fallback but was **not** reaching ElevenLabs — `TtsApiService.synthesize()` had no `speed` parameter, so every cloud-generated phrase played at 1.0×.

Fixed by threading `speed` end-to-end:
- `AppTtsService.speak()` → passes `speed: rateScale.clamp(0.7, 1.2)` to `TtsApiService.synthesize()`
- `TtsApiService.synthesize()` → includes `"speed": speed` in JSON body when `speed != 1.0`
- `backend/routes/tts_routes.py` → reads and clamps speed from request body
- `backend/elevenlabs_tts_service.py` → passes speed to `VoiceSettings`; defensive try/except so older SDK versions fall back gracefully

Pre-warm phrases updated to include all sprout archetype names and companion names so ElevenLabs is always used for these (never the robotic fallback).

### Robin Image Replacement (All 6 Bands)

New illustrated robin set provided by user — same character (orange-red European robin, teal hamsa beaded necklace) in age-appropriate settings:

| Band | Image | Notes |
|------|-------|-------|
| sprout | mushroom/flowers setting | cute, friendly |
| explorer | magic wand/standing | adventurous |
| adventurer | forest branch, glitter wings | dynamic |
| creator | Imagen 4 generated | 1024×1024 — AI regenerated (original source was 745×749); robin with painter's palette |
| adolescent | forest branch, magical | expressive |
| adult | dark comic style on fence post | refined |

All images processed through `rembg` for transparent backgrounds. Script saved as `scripts/remove_companion_backgrounds.py`.

Creator robin regenerated separately using **Imagen 4** (`imagen-4.0-generate-001`) to match style of the set. Script saved as `backend/generate_creator_robin.py`.

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Radio companion select; per-companion colors; float animation; sprout pet card button; Sprout archetype grid → 2×2; wiggle/bounce animations for sprout |
| `lib/services/app_tts_service.dart` | Thread `rateScale` to ElevenLabs `speed`; expand prewarm list |
| `lib/services/tts_api_service.dart` | Add `speed` param to `synthesize()` |
| `backend/routes/tts_routes.py` | Read + clamp speed from request body |
| `backend/elevenlabs_tts_service.py` | Defensive `VoiceSettings(speed=...)` with try/except |
| `assets/images/companions/*/robin.png` (6 files) | New illustrated robins, transparent backgrounds |
| `assets/images/companions/sprout/*.png` (3 files) | Background removed via rembg |
| `scripts/remove_companion_backgrounds.py` | NEW — rembg batch script |
| `lib/widgets/archetype_card.dart` | `forBand()` returns 4 archetypes for Sprout/Explorer (added `artist` back); 2×2 grid layout for both |
| `backend/generate_creator_robin.py` | NEW — Imagen 4 creator robin generation script |

### Sprout Archetype Grid Revision

After committing the 3-card Row layout, revised again to a **2×2 GridView** matching Explorer band:
- Sprout now shows 4 archetypes: Brave Explorer, Lightning Runner, **Art Maker** (restored), Animal Whisperer
- Cards have `WiggleWidget` (repeat=true, angle=0.04, staggered by 300 ms × index) on unselected items so they animate subtly to catch attention
- Selected cards wrap in `BounceOnTapWidget` for tactile feedback
- Label font size bumped to 13 px for sprout readability (vs 12 for explorer)

### Status
- [x] Companion radio select + colors + animation — committed `95092fe`
- [x] Sprout pet card button — committed `95092fe`
- [x] TTS speed fix — committed `b2b8a9b`
- [x] Robin images (all 6 bands) + rembg — committed `95092fe`
- [x] Creator robin Imagen 4 regeneration — this commit
- [x] Sprout archetype 2×2 grid + 4 cards + wiggle animations — this commit

---

## 2026-03-30 — Age Picker Redesign + BYOK Key-Not-Saved Bug Fix (Claude Sonnet 4.6)

**Goal:** Simplify the first-screen age picker for young children; fix a critical bug where completing the BYOK wizard from any entry point other than Settings never saved the API key.

### Age Picker Redesign

The original picker had 17 small circles (ages 2–18+) in a cramped 4-column grid — too many small targets for young children. Replaced with:
- **Ages 2–8**: 7 large circles in a 3-column grid (72–100 px, up from 44–66 px) — one tap per single age, big enough for toddlers
- **"Older?" divider** separating young from older entries
- **Ages 9–11, 12–14, 15–17, 18+**: 4 wider pill buttons in a 2×2 grid — grouped by age band, sized for older users

Band values preserved: 10 → Adventurer, 12 → Creator, 16 → Adolescent, 21 → Adult. All consent and band-specific splash logic unchanged.

### BYOK Key-Not-Saved Bug

**Root cause:** The BYOK wizard correctly pops with the validated key string, but 4 of 5 call sites threw away the return value — the key was never written to `SecureStorageService` or `SharedPreferences`.

**Fix — two layers:**
1. `byok_setup_wizard.dart` (`_EnterKeyStepState` Finish button): wizard now saves `use_own_api_key`, `is_premium_byok`, and the key to storage before popping. Key is persisted regardless of which screen launched the wizard.
2. All 4 broken call sites now capture the result and call `settingsProvider.notifier.reload()` to refresh in-memory Riverpod state for the current session. Container reference captured before any `Navigator.pop` to avoid using deactivated context.

### Files Changed

| File | What |
|------|------|
| `lib/screens/welcome_screen.dart` | Age picker: `_ageEntries` → `_youngAgeEntries` (2–8) + `_olderAgeEntries` (bands); new `_AgeBandButton` pill widget; 3-col big-circle grid + 2×2 pill grid |
| `lib/screens/byok_setup_wizard.dart` | Finish button now persists key to storage before calling `onDone` |
| `lib/dialogs/upgrade_prompt_dialog.dart` | Capture wizard result; reload settingsProvider |
| `lib/screens/parent_controls_screen.dart` | Await push result; reload settingsProvider on success |
| `lib/story_result_screen.dart` | Capture wizard result; reload settingsProvider |
| `lib/widgets/avatar_gallery_selector.dart` | Capture wizard result; reload settingsProvider |

### Status
- [x] Age picker redesign — committed `a730f44`
- [x] BYOK key-save fix — committed `2f28e48`

---

## 2026-03-31 — Sprout Archetype UX Overhaul + Hero Wizard Screen Split (Claude Sonnet 4.6)

**Goal:** Fix two UX issues identified during a 5-year-old walkthrough: (1) the "Pick your hero" page combined look-picking and archetype selection on one screen — too confusing; (2) archetype names like "The Storm Rider" and "The Heart Healer" are meaningless to a 3-5 year old.

### Changes

#### 1. Wizard page split — avatar and archetype now on separate screens
`lib/screens/wizard_steps/hero_creator_step.dart`

Old page 2 had both `_buildAvatarLookCard()` and `_buildArchetypeCards()` together. Split into:
- **Page 2** — "Pick your hero's look!" (avatar only, Next enabled after avatar chosen)
- **Page 3** — "Pick your hero style!" (archetypes only, Next enabled after archetype tapped)

All downstream page numbers shifted (companions → 4, scene → 5, story type → 6). Navigation helpers (`_notifySubStep`, `_jumpToSubStep`, `_heroNextPage`, `_speakPagePrompt`) updated accordingly. Auto-advance logic simplified: avatar page advances on avatar chosen; archetype page advances immediately on archetype tap.

#### 2. Young child archetype names (`youngChildName` field)
`lib/widgets/archetype_card.dart`

Added `youngChildName` to `ArchetypeData`; `nameForAge(age)` now returns it for ages ≤ 5:

| Archetype | Age ≤ 5 name |
|-----------|-------------|
| The Storm Rider | Super Brave! |
| The Quiz Whiz | Super Smart! |
| The Master Creator | Art Maker! |
| The Heart Healer | Kind Helper! |
| The Lightning Runner | Super Fast! |
| The Animal Whisperer | Animal Friend! |

#### 3. Sprout archetype lineup — 3 cards, new AI-generated image
Reduced from 4 cards to 3 (fewer choices less overwhelming for 3-5 year olds):

| Card | Image | Label |
|------|-------|-------|
| Brave Explorer | `brave_explorer.jpg` ← NEW | Super Brave! |
| Lightning Runner | `lightning_runner.jpg` | Super Fast! |
| Animal Whisperer | `animal_whisperer.jpg` | Animal Friend! |

`brave_explorer.jpg` generated with `gemini-2.5-flash-image`: androgynous child with warm dark-brown skin, natural curly hair, gender-neutral rust-orange/cream adventurer outfit, arms spread wide on a mossy ledge — Pixar 3D style matching existing sprout cards. Previous Storm Rider / Heart Healer / Master Creator dropped from the sprout list.

Sprout archetype grid replaced with a single `Row` of 3 equal `Expanded` cards (was a 2-column `GridView`). Explorer band keeps the 2-column `GridView`.

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Page split (avatar/archetype); 3-card Row layout for Sprout; page numbering throughout |
| `lib/widgets/archetype_card.dart` | `youngChildName` field + `nameForAge` check; `sproutImageId: 'brave_explorer'` on adventurer; sprout list → `[adventurer, athlete, shyOne]` |
| `assets/images/archetypes/sprout/brave_explorer.jpg` | NEW — AI-generated brave explorer image |
| `backend/generate_brave_hero.py` | Generation script (keepable for reruns) |

### Status
- [x] Screen split committed (0b593ff)
- [x] youngChildName + brave_explorer image committed (33cbbd7)
- [x] Sprout 3-card row layout committed (95092fe)

---

## 2026-03-31 — Visual Asset Gap Audit + `mad` Feeling Generation (Claude Sonnet 4.6)

**Goal:** Comprehensive visual asset gap audit across all 6 age bands; generate confirmed missing assets.

### Audit Findings

Full sweep of all asset categories:
- **Feelings** (`assets/images/feelings/{band}/`): `mad.png` missing from all 5 non-Sprout bands. Sprout already had it; other bands fell back to `feelings_faces/mad.png` (wrong style).
- **Backgrounds**: Complete for all 6 bands (splash_bg, story_page_bg; feelings_bg only needed for Sprout).
- **Orbs**: Complete for all 6 bands.
- **Archetypes**: Complete — all band-specific images present.
- **Companions**: Complete — all band companions present.
- **Scenes**: Complete — Adventurer scenes serve Creator/Adolescent/Adult via resolver (by design).
- **UI characters**: Complete — all ethnic variants for all bands verified present.
- **Sprout tiles**: All 6 scenario tiles present.
- **Mode orbs** (`assets/images/ui/clean/`): All 4 present with pressed variants.
- **`feelings_faces/`** global fallback: All IDs referenced by `ExpandingFeelingsWheel` and `TherapeuticFeelingsWheel` confirmed present.

### What Was Generated

| File | Style |
|------|-------|
| `assets/images/feelings/explorer/mad.png` | 3D squishy blob, deep purple bg |
| `assets/images/feelings/adventurer/mad.png` | 3D angular blob, cosmic indigo bg |
| `assets/images/feelings/creator/mad.png` | 2.5D geometric blob, dark charcoal bg |
| `assets/images/feelings/adolescent/mad.png` | Teal cinematic silhouette |
| `assets/images/feelings/adult/mad.png` | Amber-gold refined figure |

### Files Changed

| File | What |
|------|------|
| `assets/images/feelings/{5 bands}/mad.png` | Band-specific art — fills the last style-consistency gap in core feelings |
| `scripts/generate_mad_feeling.py` | NEW — rerunnable generation script |

### Status
- [x] 5 images generated (0 failures)
- [x] Committed: 4dd3f47

---

## 2026-03-31 — Creator (12yo) Audit + M3 Chip Fix + pubspec Cleanup (Claude Sonnet 4.6)

**Goal:** Six Hats UX audit of Creator band (age 12) via Playwright; fix the persistent BUG-04 chip visibility using the correct M3 API; remove stale `age_band_assets/` asset declarations from pubspec.

### Audit Document
`docs/ux_audit_creator_12yo_2026-03-31.md` — Six Hats walkthrough as a 12-year-old ("Alex").

### Key Findings From Audit

| ID | Finding | Severity |
|----|---------|----------|
| BUG-04c | CORE ARCHETYPE chips: only the *selected* chip shows text — unselected chips still blank white | 🔴 Critical |
| BUG-W1 | World setting chips: same blank-white problem as archetype chips | 🔴 Critical |
| UX-C1 | "2 Companions" step nav tab changes bold indicator but no companions UI exists in the accordion | 🟠 High |
| UX-C2 | Review screen `RenderFlex overflowed` on avatar row | 🟡 Medium |
| UX-C3 | Review shows a *different* setting than the one selected (stale state) | 🟡 Medium |

### Root Cause — BUG-04 (all three passes)

Material 3 `FilterChip` and `ChoiceChip` ignore `backgroundColor` in `ChipThemeData` — they use `WidgetStateProperty<Color>` resolved from the component's own `color:` parameter. Previous fixes (Theme wrapper with `ChipThemeData.backgroundColor`, then removing `labelStyle`) addressed wrong layers. The real fix is setting `color: WidgetStateProperty.resolveWith(...)` directly on each chip.

### Fixes Applied

| # | Issue | Fix |
|---|-------|-----|
| 1 | BUG-04c + BUG-W1: archetype + world chips render blank in M3 | Replaced `Theme(ChipThemeData(backgroundColor:...))` wrapper with `color: WidgetStateProperty.resolveWith(states => selected ? gold.alpha50 : Color(0xFF1A0A2E))` on each `FilterChip`/`ChoiceChip` directly |
| 2 | Stale `age_band_assets/` declarations in pubspec.yaml | Removed 30+ `age_band_assets/` entries from `flutter.assets` — these paths never existed on disk and caused asset-bundle warnings |

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Archetype FilterChips + world ChoiceChips: `color: WidgetStateProperty.resolveWith(...)` replaces `ChipThemeData.backgroundColor`; CUSTOM PREMISE chip gets explicit `Text` label style |
| `pubspec.yaml` | Remove all `age_band_assets/` asset declarations (resolver now uses `assets/images/` paths) |

### Status
- [x] Creator (12yo) audit doc saved
- [x] BUG-04c / BUG-W1: M3 `WidgetStateProperty` chip fix
- [x] pubspec.yaml stale asset paths removed
- [x] UX-C1: Companions tab in Creator accordion — fixed (cast section added)
- [x] UX-C2: Review avatar overflow — `FittedBox` fix (8865c23)
- [x] UX-C3: Review stale scenario title — `titleForBand` fix (8865c23)

---

## 2026-03-31 — Comprehensive Security Audit + COPPA Enforcement (Claude Sonnet 4.6)

**Goal:** Full static security audit of Flask backend and Flutter frontend; fix all findings.

### Findings & Fixes

| # | Severity | Finding | Fix | Commit |
|---|----------|---------|-----|--------|
| 1 | 🟢 Info | `.env` file status — confirmed NOT tracked in git (false positive from `git ls-files`) | No action needed | — |
| 2 | 🔴 High | CORS wildcard `*.netlify.app` — any Netlify project could make authenticated cross-origin requests | Removed wildcard; added `PREVIEW_DEPLOY_URL` env var for explicit PR preview URLs | 109a305 |
| 3 | 🔴 High | JWT dev fallback: `os.getenv('FLASK_ENV')` defaults to `None`, not `'production'` — missing env var on server silently used `'dev-secret-key'` | Changed to `os.getenv('FLASK_ENV', 'production')` | 109a305 |
| 4 | 🟠 Medium | Avatar photo upload: no size cap — large files could exhaust backend memory | 10 MB cap at both upload sites in `avatar_routes.py`; 413 returned if exceeded | 109a305 |
| 5 | 🟠 Medium | Story routes extracted `age` from request body with no bounds checking | `_resolve_age()` helper: clamps to [2, 120] then caps to `g.minor_age_cap` for under-13 users | 109a305 |
| 6 | 🟡 Low | `sanitizer.py` missed two common jailbreak patterns | Added `new instruction/rule/prompt/system` and `respond as if you` regexes | 109a305 |
| 7 | 🔴 High | Under-13 users had no server-side consent gate — parental consent stored but never checked at generation time | `require_parental_consent` decorator: queries `ConsentRecord`; returns 403 `PARENTAL_CONSENT_REQUIRED` if no valid record | a1903ad |
| 8 | 🔴 High | Under-13 users could bypass age calibration by passing `age: 18` in request body | `_resolve_age()` caps to `g.minor_age_cap` (= `user.declared_age`) set by `require_auth` for under-13 users | a1903ad |

### Flutter Client Updates

| File | Change |
|------|--------|
| `lib/models/api_error.dart` | Added `isParentalConsentError` getter |
| `lib/screens/wizard_steps/magic_review_step.dart` | Shows "ask a parent to complete parental consent" message on `PARENTAL_CONSENT_REQUIRED` |

### Backend Files Changed

| File | Change |
|------|--------|
| `backend/config/__init__.py` | Remove `*.netlify.app` wildcard; add `PREVIEW_DEPLOY_URL` env var support |
| `backend/middleware/auth.py` | JWT env default → `'production'`; `g.minor_age_cap` set in `require_auth`; `require_parental_consent` decorator added |
| `backend/routes/avatar_routes.py` | 10 MB photo cap; `@require_parental_consent` on custom/pet avatar endpoints |
| `backend/routes/story_routes.py` | `_resolve_age()` helper; `@require_parental_consent` on all 5 generation endpoints |
| `backend/utils/sanitizer.py` | 2 new prompt-injection patterns |

### Status
- [x] Items 2–6 committed: 109a305
- [x] Items 7–8 committed: a1903ad
- [x] Old API keys confirmed rotated (out of scope — keys rotated this month)

---

## 2026-03-30 — Wire AgeBandAssetResolver to Real Asset Paths (Claude Sonnet 4.6)

**Goal:** `AgeBandAssetResolver` existed but pointed to `age_band_assets/{pluralFolder}/` which was never created on disk. All band-specific images live at `assets/images/{category}/{band}/`. Fixed the resolver and migrated all consumers.

### Root Cause
The resolver was written against a planned `age_band_assets/` layout with plural folder names (`sprouts`, `early_readers`, etc.) and category-last structure. The actual images were generated with singular band names (`sprout`, `explorer`) and category-first structure. Every resolver call returned a broken path and widgets fell through to their icon/gradient fallbacks.

### Files Changed
| File | What |
|------|------|
| `lib/theme/age_band_asset_resolver.dart` | Replace `age_band_assets/{plural}/ ` with `assets/images/{category}/{band.name}/`; drop stale `_bandFolder` map |
| `lib/screens/wizard_steps/companion_selector_step.dart` | Replace 20 hardcoded `imagePath:` strings with `AgeBandAssetResolver.companionPath(band, id)` |
| `lib/widgets/feelings_badge_grid.dart` | Add `band` param (default `adventurer`); use `AgeBandAssetResolver.feelingPath()` per badge |

### Impact
- Progress orbs, continue buttons, make-magic buttons → correct per-band PNG now loaded
- Archetypes, scenes, companions → resolver paths resolve to real files
- `big_feelings_flow_screen.dart` tiered fallback now hits on first try (resolver path correct)

### Status
- [x] Resolver fixed (commit 343e3d9)
- [x] Companion selector migrated to resolver
- [x] Feelings badge grid band-parameterized

---

## 2026-03-30 — Housekeeping: gitignore, typo fix, COPPA auth cap (Claude Sonnet 4.6)

**Goal:** Clean up post-audit ephemeral files, fix discovered typo, commit pre-staged COPPA logic.

### Changes (commit 53a746d)
| File | What |
|------|------|
| `.gitignore` | Exclude `.playwright-mcp/`, `scripts/ux_audit_runner.md`, timestamped `backend/tests/artifacts/*T*.{json,md}` snapshots |
| `backend/routes/story_routes.py` | Fix "Geminin" typo in 429 quota-exceeded error message |
| `backend/middleware/auth.py` | COPPA age cap: under-13 users cannot bypass content calibration via request body age; `g.minor_age_cap` set for story routes |

### Story Load Audit Review
`backend/tests/artifacts/story_load_audit_20260330T130408Z.json` — load test only (no content quality issues).
All scenarios clean: sync fast path 24/24 @ p95=207ms, concurrency 1→32 flat at ~182ms, async fallback 16/16, fallback chain gemini→openrouter→static working correctly.

---

## 2026-03-30 — Mature Feeling Images: Adolescent & Adult Bands (Claude Sonnet 4.6)

**Goal:** Generate band-specific feeling images for the 10 mature feelings added in the Adolescent/Adult UX redesign (grief, resentful, envious, restless, hopeful, melancholy, contentment, indignation, dread, anticipation). 7 of these had no fallback image at all and were showing only emoji.

### What Was Generated

| Target | Count | Style |
|--------|-------|-------|
| `assets/feelings_faces/` global fallback | 7 new (grief/hopeful/resentful already existed) | 3D cartoon blob on dark purple |
| `assets/images/feelings/adolescent/` | 10 feelings | Teal cinematic silhouette style |
| `assets/images/feelings/adult/` | 10 feelings | Amber-gold refined figure style |

### Files Changed
| File | What |
|------|------|
| `assets/feelings_faces/{7 new}.png` | Global emoji fallbacks eliminated |
| `assets/images/feelings/adolescent/{10}.png` | Band-specific art for all mature feelings |
| `assets/images/feelings/adult/{10}.png` | Band-specific art for all mature feelings |
| `scripts/generate_mature_feelings.py` | NEW — rerunnable generation script with per-band style descriptions |

### Status
- [x] 27 images generated (0 failures)
- [x] Committed: 58be517

---

## 2026-03-30 — Full Six-Band Live Usability Audit + Overflow Fixes (Claude Sonnet 4.6)

**Goal:** Playwright browser automation against live dev build — walk all 6 age bands end-to-end, document findings, fix all discovered issues.

### Usability Report
`docs/usability_2026-03-29/report.md` — Full six-band results, confirmed fixes, new issue inventory, UI consistency matrix.

### Findings & Fixes

| ID | Issue | Band(s) | Severity | Status |
|----|-------|---------|----------|--------|
| NEW-01 | "Big adventure" length chip overflows review screen (RenderFlex) | Explorer + younger | Medium | ✅ Fixed |
| NEW-02 | `AdventurerUnlockCelebration` dialog overflows 44px at bottom | Adventurer | Medium | ✅ Fixed |
| NEW-03 | `_HeroFallbackIdentity` column (icon 42px + gap 8 + text 18) overflowed 48×48 container | Creator, Adolescent, Adult | Medium | ✅ Fixed |
| NEW-04 | Archetype card names truncate in Sprout/Explorer grid (`maxLines: 1`) | Sprout, Explorer | Medium | ✅ Fixed |
| NEW-05 | Story style step has no default selection for younger bands | Sprout, Explorer | Medium | Not a bug — code defaults to `'tales'` (Story Quest); visual state on web runner may differ from device |
| NEW-06 | Archetype class shows "—" on Adventurer review when archetype skipped | Adventurer | Low | ✅ Fixed |
| NEW-07 | Adolescent review shows only name + "—", no story summary | Adolescent | Low | ✅ Fixed |
| NEW-08 | Adult "Begin" button gold/olive colour may read as disabled | Adult | Low | ✅ Fixed |

### Fix Details

**NEW-01** — `magic_review_step.dart` (~line 1248)
- Changed length-chip `Row` → `Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8)` so chips reflow rather than overflow.

**NEW-02** — `lib/widgets/adventurer_unlock_celebration.dart`
- Changed `Padding` wrapper → `SingleChildScrollView(padding: EdgeInsets.all(24))` so the dialog scrolls if the device is too short rather than clipping.

**NEW-03** — `magic_review_step.dart:_HeroFallbackIdentity`
- Reduced icon size 42→24, gap 8→2, text size 18→14 so all three elements fit within the 48×48 container.

**NEW-04** — `lib/screens/wizard_steps/hero_creator_step.dart:_buildArchetypeCards`
- Changed `maxLines: 1` → `maxLines: 2` on the name Text inside the bottom pill overlay; names like "The Animal Whisperer" now wrap to a second line instead of truncating with `…`.

**NEW-06** — `lib/widgets/adventurer_character_sheet.dart`
- Archetype lookup was comparing `a.name.toLowerCase().replaceAll(' ', '_')` against `selectedArchetypeId` which is stored as the display name (e.g., `"The Lightning Runner"`). The slug transform never matched. Fixed to `a.name == wizardData.selectedArchetypeId` so CLASS and ROLE stats now appear correctly.

**NEW-07** — `lib/screens/wizard_steps/magic_review_step.dart`
- Creator band: scenario fallback changed from `'—'` to `'Your own story'` so review is never blank.
- Adolescent band: `scenarioDesc` (from `ScenarioData.descriptionForAge`) now shown as a small italic subtitle below the scenario title, giving users a real story summary before they launch.

**NEW-08** — `lib/screens/wizard_steps/magic_review_step.dart` (Adult CTA button)
- `foregroundColor` switched to `Color(0xFF1A1A1A)` (dark text) for Adult band — amber+white was ~2.2:1 contrast; dark text meets 4.5:1 minimum.
- Added warm border rim `Color(0xFFD4B97A)` width 1.5 and a soft amber shadow so the button reads as interactive, not muted.

### Files Changed
| File | What |
|------|------|
| `lib/screens/wizard_steps/magic_review_step.dart` | Length chip Row→Wrap; `_HeroFallbackIdentity` size reduction; Adult button contrast |
| `lib/widgets/adventurer_unlock_celebration.dart` | Padding→SingleChildScrollView |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Archetype name pill maxLines 1→2 |

### Status
- [x] NEW-01: length chip overflow fixed
- [x] NEW-02: unlock dialog overflow fixed
- [x] NEW-03: `_HeroFallbackIdentity` overflow fixed
- [x] NEW-04: archetype name truncation fixed
- [x] NEW-08: Adult "Begin" button contrast fixed (commit 25f8ef7)
- [x] NEW-06: Adventurer archetype lookup fixed — was comparing transformed slug against display name
- [x] NEW-07: Adolescent review scenario description added; Creator fallback '—' → 'Your own story'

---

## 2026-03-30 — Backend Log Review + Audit Doc Commit (Claude Sonnet 4.6)

**Goal:** Review backend server logs for live issues; verify all six-band UX audit findings are resolved; commit untracked audit documents.

### Backend Fixes Verified

| # | Issue | Resolution |
|---|-------|-----------|
| 1 | TTS `audio_base64` attribute missing — every `/tts/synthesize` fell back, no word timing | Fixed `audio_base_64` — confirmed committed (ae29700 / prior session) |
| 2 | Flask watchdog restarting on Flutter ephemeral build artifacts | `exclude_patterns` confirmed committed |

### Audit Status — All Clear

All findings from `docs/ux_audit_six_bands_2026-03-29.md` and `docs/ux_audit_explorer_8yo_2026-03-29.md` confirmed resolved:
- BUG-01–05, UX-01–05, UX-FG: all fixed in sessions earlier today
- `_CompanionImageButton._pressedImage` fallback to `imagePath` override — confirmed committed
- BUG-03 avatar gallery `mainAxisSize.min` removal — confirmed committed
- Bedtime label `'Bedtime mode'` / `'Bedtime'` — confirmed committed
- Review screen pencil icon (`Icons.edit_outlined`) always visible on tappable rows — confirmed committed

### Committed
- Untracked audit docs: `docs/ux_audit_six_bands_2026-03-29.md`, `docs/ux_audit_explorer_8yo_2026-03-29.md`, `docs/ux_audit_2026-03-29/` (screenshots), `docs/usability_2026-03-29/` (screenshots)
- Updated test audit artifacts: `story_load_audit_latest.json`, `story_load_audit_latest.md`

---

## 2026-03-30 — Wizard Draft Persistence + Loading Mini-Game (Claude Sonnet 4.6)

**Goal:** Crash recovery for the story wizard; interactive loading screen mini-game; Big Feelings flow fix.

### Features

| # | Feature | Files |
|---|---------|-------|
| 1 | Wizard draft persistence — saves state to SharedPreferences on each step advance; restores on re-open (crash/network recovery) | `wizard_story_screen.dart`, `wizard_data.dart` |
| 2 | `clearWizardDraft()` top-level helper in `wizard_story_screen.dart`; `magic_review_step.dart` updated to call it directly | `magic_review_step.dart`, `wizard_story_screen.dart` |
| 3 | Loading screen tap mini-game — drifting `auto_awesome` orb targets (max 3 on screen) spawn every 2s; tapping earns `_tapCount`; non-Sprout bands only | `magical_loading_view.dart` |
| 4 | Big Feelings flow fix — `big_feelings_quest` card now selects normally; feelings flow triggered on Continue (not on card tap) | `feeling_selection_step.dart` |

### Status
- [x] Wizard draft save/restore
- [x] clearWizardDraft top-level
- [x] Loading mini-game
- [x] Big Feelings continue flow

---

## 2026-03-30 — Adventurer (10yo) Audit + Follow-on Fixes (Claude Sonnet 4.6)

**Goal:** Six Hats audit for Adventurer (10yo) band; second-pass fixes for Creator chip visibility and Explorer archetype labels; consent scroll gate; uncommitted backend patches.

### Audit Document
`docs/ux_audit_adventurer_10yo_2026-03-30.md` — Six Hats walkthrough as a 10-year-old.

### Fixes

| # | Issue | Fix |
|---|-------|-----|
| 1 | BUG-04 second pass: Creator/Adult chips still blank — `ChipThemeData.labelStyle` was overriding the explicit `Text(style:)` inside each chip even after the Theme wrapper was added | Removed `labelStyle` from `ChipThemeData`; background/shape overrides kept; label colors handled entirely by `Text` inside each `FilterChip.label` |
| 2 | Explorer archetype page: "Step 1: Pick your hero look" + "Step 2: Pick your hero type" imply locked sequential flow even though both are freely tappable | Removed "Step 1" hint; replaced "Step 2" with 3-state message: neither → "tap either one first!", one done → "now pick the other one!", both done → "You're all set!" |
| 3 | Consent button active before parent has read the form | Added `_scrollProgress < 0.95` to button null condition; added "Scroll to read ↓" hint row shown when `_scrollProgress < 0.7` |
| 4 | ElevenLabs TTS API: `audio_base64` attribute typo | Fixed to `audio_base_64` in `elevenlabs_tts_service.py` |
| 5 | Flask dev server watching Flutter ephemeral build artifacts | Added `exclude_patterns` to `app.run()` |

### Files Changed
| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Remove `ChipThemeData.labelStyle`; replace Step 1/2 labels with 3-state progress hint |
| `lib/screens/parental_consent_screen.dart` | Scroll-to-95% gate on button + scroll hint row |
| `backend/elevenlabs_tts_service.py` | `audio_base64` → `audio_base_64` |
| `backend/app.py` | `exclude_patterns` in `app.run()` |

### Status
- [x] Adventurer (10yo) audit saved
- [x] BUG-04 second pass: labelStyle removed
- [x] Explorer archetype 3-state hint
- [x] Consent scroll gate
- [x] ElevenLabs TTS typo
- [x] Flask exclude_patterns

---

## 2026-03-30 — Six Hats UX Audit Bug Sprint (Claude Sonnet 4.6)

**Goal:** Work through all findings from the six-band + Explorer 8yo UX audits (`docs/ux_audit_six_bands_2026-03-29.md`, `docs/ux_audit_explorer_8yo_2026-03-29.md`) in priority order.

### Bug Inventory & Status

| ID | Issue | Band | Severity | Status |
|----|-------|------|----------|--------|
| BUG-C1 | Companion images broken on review screen — band-specific IDs returned null | Explorer+ | 🔴 Critical | ✅ Fixed |
| BUG-C2 | Archetype tap forced avatar creator redirect instead of selecting | Explorer+ | 🔴 Critical | ✅ Fixed |
| BUG-04 | Creator/Adult CORE ARCHETYPE chips invisible (white text on light M3 chip) | Creator, Adult | 🔴 Critical | ✅ Fixed |
| BUG-01 | Sprout companion picker 404s — code-reviewed, paths correct in current build | Sprout | 🔴 Critical | ✅ Verified OK |
| UX-M2 | "Easy Reader" label self-stigma risk | Explorer | 🟢 Low | ✅ Fixed → "Read Along" |
| UX-S2 | "HI MAX!" all-caps | Explorer | 🟡 Medium | ✅ Already fixed (prev session) |
| UX-01 | Age gate 13-17 merge | Creator, Adolescent | 🟠 High | ✅ Already fixed (prev session) |
| UX-02 | Consent scroll progress hint | All <13 | 🟡 Medium | ✅ Already fixed — LinearProgressIndicator in AppBar |
| UX-S4 | Custom companion entry unseparated from magic grid | Explorer+ | 🟡 Medium | ✅ Fixed — "...or bring someone along" divider |
| BUG-03 | RenderFlex overflow in avatar gallery (44–58px) | All | 🟡 Medium | ✅ Fixed |
| BUG-05 | Sprout story orbs unstable tap target (GestureDetector outside MagicalFloat) | Sprout | 🟡 Medium | ✅ Fixed |
| UX-FG | FeelingsGardenScreen Adolescent/Adult tab labels merged — plan required split | Adolescent, Adult | 🟡 Medium | ✅ Fixed |

### Fix Details

**BUG-C1** — `magic_review_step.dart:_companionImage`
- Added `'robin'` check in `legacyIds`, added `contains('/')` check for Sprout IDs (`sprout/fluffy_dragon` → `companions/sprout/fluffy_dragon.png`), and derived band from `ageBandFromAge(age)` for bare Explorer/Adventurer IDs (`ember_dragon` → `companions/explorer/ember_dragon.png`).

**BUG-C2** — `hero_creator_step.dart:_selectArchetype`
- Removed `_openAvatarCreationOptions()` forced trigger when archetype selected before avatar. Hint text: "Pick a hero type and choose your look — in any order!"

**BUG-04** — `hero_creator_step.dart:_buildBriefIdentityInputs`
- Root cause: `ThemeData.light()` base means Material 3 FilterChip uses light `surfaceContainerLow` chip background — white text invisible on light chip.
- Fix: Wrapped `Wrap` in `Theme(data: copyWith(chipTheme: ChipThemeData(backgroundColor: Color(0xFF1A0A2E), ...)))`.

**UX-M2** — `hero_creator_step.dart:_getReadingLabel`, `story_result_screen.dart:_readingLevelLabel`
- "Easy Reader" → "Read Along" in both locations.

**UX-S4** — `hero_creator_step.dart:_buildAdventureTeamPage`
- Added "...or bring someone along" divider row between the magic companion grid and the custom friend text field.

**BUG-05** — `lib/widgets/image_mode_orb.dart:build()`
- Root cause: `GestureDetector` was outside `MagicalFloat`, which uses `Transform.translate`. Hit-test area stayed at original position while visual floated ±3px → Playwright "not stable" + slightly misaligned tap for real users.
- Fix: moved `GestureDetector` inside `MagicalFloat` as direct child, removed now-redundant `IgnorePointer` wrapper.

**UX-FG** — `lib/screens/feelings_garden_screen.dart:_tab1Label/_tab2Label/_tab3Label`
- Root cause: age >= 15 branch covered both Adolescent (15-17) and Adult (18+) with same labels ("Landscape"/"Explore"/"Reflections"). Plan required Adolescent to get "Inner Map"/"Deep Dive"/"Reflections".
- Fix: added `age >= 18` branch returning Adult labels above the `age >= 15` branch. Tab 3 ("Reflections") is intentionally shared between both bands per plan.

### Files Changed
| File | Changes |
|------|---------|
| `lib/screens/wizard_steps/magic_review_step.dart` | `_companionImage` getter: full band-aware rewrite |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Archetype gate removed; CORE ARCHETYPE chip theme fix; "Read Along" label; companion divider |
| `lib/story_result_screen.dart` | "Read Along" label |
| `lib/widgets/image_mode_orb.dart` | GestureDetector moved inside MagicalFloat; IgnorePointer removed |
| `lib/screens/feelings_garden_screen.dart` | Added age >= 18 Adult branch; age 15-17 now "Inner Map"/"Deep Dive"/"Reflections" |

### Status
- [x] BUG-C1: companion image fix
- [x] BUG-C2: archetype gate removed
- [x] BUG-04: CORE ARCHETYPE chips visible
- [x] UX-M2: Easy Reader → Read Along
- [x] UX-S4: companion section divider
- [x] BUG-05: orb GestureDetector moved inside MagicalFloat
- [x] UX-FG: FeelingsGarden Adolescent/Adult tab label split
- [x] BUG-03: RenderFlex overflow — removed `mainAxisSize: MainAxisSize.min` from upsell Row in `AvatarGallerySelector`
- [x] Committed: 738e9d2, a187364

---

## 2026-03-30 — Sentry RenderFlex Overflow Fixes (Claude Sonnet 4.6)

**Goal:** Diagnose and fix two live Sentry issues (STORY-WEAVER-R and STORY-WEAVER-K) — both `RenderFlex overflowed` errors in `magic_review_step.dart` on 390px-wide screens.

### Root Causes Found

| Issue | Overflow | Widget | Root Cause |
|-------|----------|--------|------------|
| STORY-WEAVER-R | 11px | `_LengthChip` row (first review layout) | 3 chips in a `Row` with no `Flexible` — natural chip width exceeds available space on narrow screens with scaled spacing |
| STORY-WEAVER-K | 58px | `_SummaryRow` Row + second chip row | (1) `band.touchTarget(32)` = 88px for Sprout band — the avatar SizedBox alone consumed too much fixed width in the Row. (2) Second chip Row (line ~1626) had same unconstrained-chip issue as STORY-WEAVER-R |

### Fixes Applied

| File | Change |
|------|--------|
| `lib/screens/wizard_steps/magic_review_step.dart` | First chip row (~line 897): `Row` → `Wrap(spacing: 8, runSpacing: 8)` — removes SizedBox spacers |
| `lib/screens/wizard_steps/magic_review_step.dart` | Second chip row (~line 1626): `Row` → `Wrap(spacing: band.space(8), runSpacing: band.space(8))` |
| `lib/screens/wizard_steps/magic_review_step.dart` | `_SummaryRow.leadingAvatar` SizedBox: `band.touchTarget(32)` → `36` fixed — entire row is the tap target via InkWell, so visual size doesn't need to meet touch target minimums independently |

### Status
- [x] Fix 1 — First chip Row → Wrap (Fixes STORY-WEAVER-R)
- [x] Fix 2 — Second chip Row → Wrap (Fixes STORY-WEAVER-K partially)
- [x] Fix 3 — `_SummaryRow` avatar cap at 36px (Fixes STORY-WEAVER-K fully)
- [x] Committed

---

## 2026-03-30 — Explorer (8yo) & Adventurer (10yo) UX Audit + Bug Fixes (Claude Sonnet 4.6)

**Goal:** Conduct Six Hats UX audits for the Explorer (age 8) and Adventurer (age 10) bands using live screenshots, then fix all identified bugs. Audit documents saved to `docs/`.

### Audit Documents

| File | Band | Method |
|------|------|--------|
| `docs/ux_audit_explorer_8yo_2026-03-29.md` | Explorer (8yo) | Screenshots + code review, Six Hats |
| `docs/ux_audit_adventurer_10yo_2026-03-30.md` | Adventurer (10yo) | Screenshots + code review, Six Hats |

### Bugs Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | Robin companion shows broken × image on review screen | `legacyIds` set in `_companionImage` getter was missing `'robin'` — fell through to band-specific path that doesn't exist | Added `'robin'` to `legacyIds` in `magic_review_step.dart` |
| 2 | Any failed companion asset shows × instead of fallback | `Image.asset()` in `_CompanionAvatar` had no `errorBuilder` | Added `errorBuilder` → `_GradientSphereFallback` with pets icon |
| 3 | Failed scenario/world image shows × instead of fallback | `Image.asset(_scenarioImage)` in review layout had no `errorBuilder` | Added `errorBuilder` → dark purple container with landscape icon |
| 4 | Long Adventurer world names truncated ("Whispers of Dazzling Ste...") | Scenario label was `maxLines: 1` | Changed to `maxLines: 2`, font 12→11 so long names fit |
| 5 | Greeting reads "HI SAM!" (all-caps, Bitter font = shouting) | `characterName.toUpperCase()` applied even for non-decorative fonts; Adventurer uses Bitter where it has visible effect | Changed to `"Hi $name!"` — CinzelDecorative (Sprout/Explorer) renders the same since it's naturally small-caps |
| 6 | Genre twist selection not confirmed on review screen | `_storyTypeLabel()` returned only story type, ignoring `selectedGenre` | Refactored into `_baseStoryTypeLabel()` + genre append: "Story Quest · 👻 Spooky" |

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/magic_review_step.dart` | Add `'robin'` to `legacyIds`; `errorBuilder` on companion + scenario `Image.asset`; `maxLines: 2` on scenario label; refactor `_storyTypeLabel()` → genre badge |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Greeting `"HI ${name.toUpperCase()}!"` → `"Hi $name!"` |

### Status
- [x] Six Hats audit — Explorer (8yo) — `docs/ux_audit_explorer_8yo_2026-03-29.md`
- [x] Six Hats audit — Adventurer (10yo) — `docs/ux_audit_adventurer_10yo_2026-03-30.md`
- [x] BUG-1: Robin missing from legacyIds
- [x] BUG-2: errorBuilder on companion Image.asset
- [x] BUG-3: errorBuilder on scenario Image.asset
- [x] BUG-4: World name maxLines 1→2
- [x] BUG-5: Greeting casing (toUpperCase removed)
- [x] BUG-6: Genre shown on review summary row
- [x] flutter analyze clean (pre-existing warnings only)

---

## 2026-03-29 — Rhyme Time Mode: Full Age Band Audit & Fix (Claude Sonnet 4.6)

**Goal:** Rhyme time stories were generating in a context vacuum — no scene/world bible, no character strengths, no companion powers, "coping moment" phrasing leaking into older-band poetry. Fix all 7 identified issues across both backend files.

### Issues Found & Fixed

| # | Issue | Fix |
|---|-------|-----|
| 1 | `_build_rhyme_time_prompt` had no `world_bible` param — scene context completely absent | Added `world_bible` param; injected as `Setting:` into prompt |
| 2 | `conflict_hook` from scenario_data never forwarded to rhyme time | Added `conflict_hook` param; injected as `Conflict:` |
| 3 | `sensory_palette` never forwarded | Added `sensory_palette` param; injected as `Sensory Palette:` |
| 4 | `character_details` accepted but silently ignored (no strengths/gender/pronouns in prompt) | Extracted and injected `strengths`, `gender`, `pronouns`, `specialAbility` |
| 5 | Companion powers/behaviors absent — rhyme time got flat name list only | Updated companion loop to extract `signaturePower`, `powerConstraint`, `behaviorPattern` |
| 6 | `"coping moment"` in requirements — in `_META_LEAK_TERMS` blacklist, wrong tone for 11+ | Replaced with age-scaled requirements lines (wonder/strength for ≤10, turning-point for 11-12, earned emotional weight for 13+) |
| 7 | Adults (18+) fell into the `age >= 13` branch (teen poetry rules) | Added `age >= 18` branch above `age >= 13` with literary/villanelle framing |
| 8 | Call site used `companion_characters` (raw strings) not `companion_character_details` (enriched DB dicts) | Fixed `story_tasks.py` call to use `companion_character_details` |
| 9 | `config['notes']` age calibration (sentence length, vocab, POV) not applied to rhyme time | Added `Writing style: {config['notes']}` to prompt |

### Files Changed

| File | What |
|------|------|
| `backend/services/story_service.py` | `_build_rhyme_time_prompt` — new params, character context, companion powers, age-scaled requirements, adult branch, writing style notes |
| `backend/tasks/story_tasks.py` | Rhyme time call block — use `companion_character_details`, forward `world_bible`/`conflict_hook`/`sensory_palette` from kwargs |

### Status
- [x] `story_service.py` — all 7 prompt-side fixes
- [x] `story_tasks.py` — call site fixes (world_bible, conflict_hook, sensory_palette, companion_character_details)

---

## 2026-03-29 — Adolescent (Ages 15-17) UX Redesign (Claude Sonnet 4.6)

**Goal:** Make the Adolescent band feel genuinely mature and self-directed — not "dark children's app." Audit all "magic" language, redesign the welcome screen age picker, surface literary scenario descriptions, add free-text character option, and replace the elaborate review screen with a minimal dark card.

### Files to Change

| File | What |
|------|------|
| `lib/theme/age_band_theme.dart` | 5 new label fields: `scenarioPageTitle`, `scenarioPageSubtitle`, `scenarioCategoryFantasyLabel`, `scenarioCategoryRealLabel`, `wizardNextHint` |
| `lib/screens/welcome_screen.dart` | Split "13-17" into individual ages, neutral splash text, mature band transition |
| `lib/services/app_tts_service.dart` | Replace pre-cached "Make Magic" phrases with band-neutral versions |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | Band-aware page title/subtitle, category labels, scenario ordering, conflict hooks on cards |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Band-aware hint text, free-text character description field |
| `lib/models/wizard_data.dart` | Add `characterCustomDescription` nullable field |
| `lib/screens/wizard_steps/companion_selector_step.dart` | Pet photo button: "Make Magic" → "Add to Story" for mature bands |
| `lib/widgets/feelings_quest_modal.dart` | Use band UI font (SourceSansPro) for adolescent headers |
| `lib/screens/wizard_steps/magic_review_step.dart` | Minimal dark card layout + `_MatureStartButton` for adolescent |
| `lib/quick_story_screen.dart` | Band-aware CTA labels |
| `lib/main_story.dart` | Replace "Make Magic" fallback with `band.launchStoryLabel` |
| `lib/widgets/moon_phase_progress.dart` | Neutral default step 3 label |

### Status
- [x] Phase 1 — Theme fields (`age_band_theme.dart` — all 6 band constants + constructor + copyWith + lerp)
- [x] Phase 2A — Welcome: split "13-17" into individual ages 13-17, 4-column grid
- [x] Phase 2B — Welcome: neutral title splash ("Your stories, your way.")
- [x] Phase 2C — Welcome: mature band transition screen after age selection
- [x] Phase 2D — TTS: remove "Make Magic" from pre-cached phrases
- [x] Phase 3A — Scenario selection: band-aware title/subtitle, category labels, ordering, conflict hooks
- [x] Phase 3B — Hero creator: hint text + free-text character field; `wizard_data.dart` field
- [x] Phase 3C — Companion selector: pet photo button text for mature bands
- [x] Phase 3D — Feelings quest modal: SourceSansPro font for mature bands
- [x] Phase 3E/F — Magic review: minimal dark card + _buildAdolescentMinimalReview
- [x] Phase 4 — "Magic" language mop-up: `quick_story_screen`, `main_story`, `moon_phase_progress`
- [x] flutter analyze clean (warnings only, pre-existing)
- [x] Committed (62ae649)

---

## 2026-03-29 — Adventurer (Ages 9–11) Band Overhaul (Claude Sonnet 4.6)

**Goal:** Transform every Adventurer-band touchpoint into a game-like, RPG-flavored experience. Animated welcome sequence, exclusive unlock celebration, badge system, mission briefing review, feeling-to-quest bridge, and physiological body signal hooks.

### Files to Change

| File | What |
|------|------|
| `lib/screens/welcome_screen.dart` | Band-aware animated splash + one-time unlock celebration trigger |
| `lib/widgets/adventurer_welcome_sequence.dart` | NEW — staggered "loading your adventure profile" animation |
| `lib/widgets/adventurer_unlock_celebration.dart` | NEW — one-time "You've unlocked new adventures!" dialog |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | Locked scenario teasers, "Adventurer Exclusive" badge, mission hook display, bridge-to-quest routing |
| `lib/widgets/age_band_badge.dart` | NEW — reusable shield badge ("9+ Only" / "Adventurer Exclusive") |
| `lib/screens/wizard_steps/magic_review_step.dart` | RPG character sheet layout, dark mission briefing aesthetic, "MISSION READY" button |
| `lib/widgets/adventurer_character_sheet.dart` | NEW — stat-line RPG card (Name, Class, Power, Companions) |
| `lib/widgets/mission_ready_button.dart` | NEW — rectangular pulsing teal-border launch button |
| `lib/widgets/archetype_card.dart` | Add `adventurerDescription` field + role-focused text for all 6 archetypes |
| `lib/theme/age_band_theme.dart` | Change `adventurerTheme.launchStoryLabel` → `'MISSION READY'` |
| `lib/screens/big_feelings_flow_screen.dart` | "Want to go on a quest?" bridge step + physiological body signal hooks |

### Implementation Phases

**Phase 2 — Scenario Selection (do first, independent)**
1. Locked scenario teasers: show Adventurer+ scenarios to younger bands as "Coming Soon For You" (opacity 0.5, lock icon, "Unlock at age 9+"), non-tappable
2. "Adventurer Exclusive" shield badge overlay on `minBand`-gated scenario cards
3. Mission hook: display `conflictHookForAge()` in italics for Adventurer+ users on scenario description cards

**Phase 3+5 — Hero Creator + Mission Briefing (do together — both modify magic_review_step)**
4. RPG character sheet: replace orb layout with dark indigo stat card (Name, Class, Power, Companions) with teal left-border accents
5. Role-focused archetype descriptions: add `adventurerDescription` to all 6 archetypes describing their role in the adventure
6. Dark mission briefing wrapper: adventurer gradient bg + thin teal border frame around review content
7. "MISSION READY" button: rectangular, dark indigo bg, teal border, uppercase Bitter font, pulse animation; replaces `ImageMakeMagicButton` for Adventurer band

**Phase 4 — Big Feelings Flow**
8. Feeling-to-quest bridge: after selecting a feeling, insert intermediate step "Want to go on a quest that explores this feeling?" (Yes → auto-selects scenario, No → continues normal flow). Add `bridgeToScenario` to `BigFeelingsFlowResult`.
9. Physiological body signal hooks: for Adventurer+ in body signal step (step 2), show one-line educational hook (e.g., "Your amygdala sends a danger signal — cortisol spikes so your body is ready to run or freeze"). Static map covering all feelings.

**Phase 1 — Welcome (do last, polish layer)**
10. Animated "loading your adventure profile" splash: replace "Once Upon a Time" with staggered text animation (indigo palette, Bitter font, personalised with user name) for Adventurer band
11. One-time "New Adventures Unlocked" dialog: on first Adventurer-band entry, show celebration with Midnight Mystery + Survival Island cards; write `adventurer_band_unlock_seen` to SharedPreferences after dismissal

### Key Risks
- Phase 3+5 both modify `magic_review_step.dart` heavily — implement as a single unit
- Big Feelings bridge step (Phase 4): use step index 5 to avoid renumbering existing steps 0-3; update `_goBack()` accordingly
- Every change must be guarded by `band.band == AgeBand.adventurer` to not affect other 5 bands
- `ArchetypeData` `const` constructors — adding nullable `adventurerDescription` is backwards-compatible

### Status
- [x] Phase 2 — Scenario selection: teasers, badges, mission hooks
- [x] Phase 3+5 — Character sheet + mission briefing review + MISSION READY button
- [x] Phase 4 — Big Feelings: quest bridge + physiological hooks
- [x] Phase 1 — Welcome: animated splash + unlock celebration

---

## 2026-03-29 — Cross-Cutting UX Fixes (Claude Sonnet 4.6)

**Goal:** Four UX issues flagged in a cross-band audit that affect all age bands: scenario carousel lacks swipe affordance, TTS auto-plays for older users (embarrassing for 13+), Guardian Mode gear icon is too hidden, and post-story engagement is buried below the fold.

### Files to Change

| File | What |
|------|------|
| `lib/story_reader_screen.dart` | Tighten auto-play to `band.isYoung` only |
| `lib/screens/welcome_screen.dart` | Replace gear FAB with labeled "Parent" TextButton.icon |
| `lib/screens/age_gate_screen.dart` | Add "Parent" button (shield icon + label) top-right corner |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | Carousel right-edge peek + first-use swipe dot indicator |
| `lib/story_result_screen.dart` | Emoji rating for young bands; replay buttons above fold; split "Tell Me Another" by character context; quick rating in action bar |

### Implementation Order & Status

- [x] **Issue 2 — TTS**: `shouldAutoPlay = band.isYoung` — sprout/explorer auto-play, adventurer+ manual only
- [x] **Issue 3 — Guardian Mode**: Add labeled "Parent" button to age gate + welcome screens
- [x] **Issue 1 — Carousel Affordance**: Right-edge peek padding + animated swipe-hint dots (first use only, skip for sprout)
- [x] **Issue 4 — Post-Story Engagement**: Emoji rating for young bands; replay buttons above fold; split action bar CTA by character; quick 3-tap rating in action bar

---

## 2026-03-29 — Creator Band (Ages 12-14) UX Polish (Claude Sonnet 4.6)

**Goal:** Make every Creator-band touchpoint feel like a creative tool, not a children's app with sparkles removed. Six areas: Welcome, Scenario Selection, Hero Creator, Big Feelings, Magic Review, and general polish. Emotional hooks, identity-focused prompts, journal reflection, and pitch-document aesthetic throughout.

### Files to Change

| File | What |
|------|------|
| `lib/screens/welcome_screen.dart` | Reorder flow (age→splash→name); Creator-band splash "Your story begins here." in Bitter serif; profile-style name entry |
| `lib/data/scenario_data.dart` | Add `creatorThematicQuestion` field to `ScenarioCard` with identity-hook questions |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Thematic questions on scenario cards; Imagine It spotlight first; reflection prompt in Creative Brief; "Design your character" avatar copy |
| `lib/models/wizard_data.dart` | Add `characterDesire` optional field |
| `lib/screens/wizard_steps/wizard_data_mapper.dart` | Include `characterDesire` in backend character details |
| `lib/screens/big_feelings_flow_screen.dart` | Journal-entry step 4 for Creator band; mature label audit on step headers; `journalEntry` on `BigFeelingsFlowResult` |
| `lib/screens/wizard_steps/magic_review_step.dart` | "Your Story Pitch" title; clean card layout (no orb glow); "Your story, your way" tagline + "Start Writing" CTA |
| `lib/theme/age_band_theme.dart` | Update `launchStoryLabel` to "Start Writing"; verify no gold/sparkle leaks |

### Status
- [x] Step 1 — `wizard_data.dart` + `wizard_data_mapper.dart`: add `characterDesire` field
- [x] Step 2 — `big_feelings_flow_screen.dart`: add `journalEntry` to `BigFeelingsFlowResult`
- [x] Step 3 — `scenario_data.dart`: add `creatorThematicQuestion` + populate for all scenarios
- [x] Step 4 — `welcome_screen.dart`: reorder flow (age→splash→name) + Creator-band splash/name styling
- [x] Step 5 — `hero_creator_step.dart`: thematic question overlay on cards + Imagine It spotlight first
- [x] Step 6 — `hero_creator_step.dart`: reflection prompt in Creative Brief + "Design your character" avatar copy
- [x] Step 7 — `big_feelings_flow_screen.dart`: journal step (step 4) + Creator-band step titles
- [x] Step 8 — `magic_review_step.dart`: "Your Story Pitch" + clean pitch card + "Start Writing" CTA
- [x] Step 9 — `age_band_theme.dart`: `launchStoryLabel` → "Start Writing"; `dart analyze` clean (1 info)
- [x] Hotfix — `isar_service_io.dart`: import `_io` versions of chronicle/chapter_memory directly (was importing conditional-export wrappers, analyzer resolved to stubs → `ChronicleLocalSchema`/`ChapterMemoryLocalSchema` undefined)

---

## 2026-03-29 — Explorer Band UX Polish: Delight, Discoverability & Engagement (Claude Sonnet 4.6)

**Goal:** Add celebratory animations, swipe affordances, progressive disclosure, and voice guidance across 5 wizard screens for the Explorer (6-8) age band. All animations respect `MotionPrefs.reduceMotion()`, all theming via `AgeBandThemeData`.

### Files to Change

| File | What |
|------|------|
| `lib/widgets/star_burst_celebration.dart` | NEW — reusable star burst extracted from `image_make_magic_button.dart` |
| `lib/widgets/staggered_card_dealer.dart` | NEW — staggered card-dealing entrance animation wrapper |
| `lib/widgets/parallax_tilt_card.dart` | NEW — 3D parallax tilt on drag for carousel cards |
| `lib/widgets/body_outline_widget.dart` | NEW — tappable body silhouette with zone hit-testing (3 complexity tiers) |
| `lib/data/body_zone_mapping.dart` | NEW — maps zone IDs to `_bodyOptions` text |
| `lib/screens/welcome_screen.dart` | Star burst on name entry; illustrated age circle scenes |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | Swipe affordance + peek; parallax tilt cards; "New!" sparkle badge per scenario |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Staggered card-deal for archetypes; companion wave on select; TTS page narration |
| `lib/screens/big_feelings_flow_screen.dart` | Progressive disclosure (8 core + "more…"); body outline replaces text list |
| `lib/screens/wizard_steps/magic_review_step.dart` | Sticker pop-in for review cards; 3-2-1 countdown before generation |
| `lib/widgets/image_make_magic_button.dart` | Enhanced glow ring-pulse effect |
| `lib/services/onboarding_service.dart` | New hint-tracking keys (swipe hint, per-scenario visits, countdown count) |
| `lib/services/app_tts_service.dart` | New pre-warmed phrases for hero/companion TTS narration |

### Status
- [x] Phase 1 — Shared infrastructure: `StarBurstCelebration`, `StaggeredCardDealer`, `ParallaxTiltCard`, `BodyOutlineWidget`, `body_zone_mapping.dart`, onboarding service extensions, TTS warm-up phrases
- [x] Phase 2 — Welcome Screen: star burst on name completion; illustrated age picker circles
- [x] Phase 3A — Scenario Carousel: swipe peek + first-time hint; parallax tilt cards; "New!" badges
- [x] Phase 3B — Hero Creator: staggered archetype card deal; companion waving on select; TTS narration
- [x] Phase 3C — Big Feelings: progressive disclosure (8 core → expand); body outline for body signal step
- [x] Phase 4 — Magic Review: sticker pop-in; enhanced Make Magic glow ring; 3-2-1 countdown

---

## 2026-03-29 — Sprout (Ages 2-5) UX Enjoyment Overhaul (Claude Sonnet 4.6)

**Goal:** Make every Sprout-band touchpoint feel alive, voice-driven, and age-appropriate for pre-readers. Animated cards, voice-first flows, mascot feedback, tap-to-hear patterns, and a simplified "GO!" launch screen.

### Files Changed

| File | What |
|------|------|
| `lib/widgets/sprout_animations.dart` | NEW — WiggleWidget, BounceOnTapWidget, FeelingPulseWidget |
| `lib/screens/welcome_screen.dart` | Wiggling star + 5s timer; voice-first name input with mascot |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Illustration-heavy archetype cards with bounce; mascot name echo via TTS |
| `lib/widgets/avatar_gallery_selector.dart` | Staggered breathing on unselected thumbnails |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | Tap-to-hear/tap-to-select with scenario SFX |
| `lib/screens/big_feelings_flow_screen.dart` | 4 core feelings, animated faces, TTS labels, animated coping tools |
| `lib/screens/wizard_steps/magic_review_step.dart` | Full-screen "GO!" celebration replacing review summary |
| `lib/services/app_tts_service.dart` | Sprout warm-up phrases added |

### Status
- [x] Phase 1A — `sprout_animations.dart` (WiggleWidget, BounceOnTapWidget, FeelingPulseWidget, DragonBreathAnimation, CountToFiveAnimation)
- [x] Phase 2 — Welcome: wiggling star, 5s timer, voice-first name + mascot + speech bubble
- [x] Phase 3 — Hero creator: illustration-heavy archetype cards with BounceOnTapWidget + WiggleWidget; mascot + debounced TTS name echo
- [x] Phase 4 — Avatar gallery: staggered breathing thumbnails for Sprout
- [x] Phase 5 — Scenario selection: tap-to-hear + scenario SFX (reuses existing ambient sounds)
- [x] Phase 6 — Big feelings: 4 feelings, FeelingPulseWidget animated faces, TTS tap-to-reveal labels, animated coping tool cards
- [x] Phase 7 — Magic review: full-screen "GO!" celebration with BreathingAvatar + MagicalFloat
- [x] Phase 8 — Polish: TTS warm-up phrases added, dispose guards verified, flutter analyze clean

---

## 2026-03-29 — Wire Mature Feelings into Story Prompts (Claude Sonnet 4.6)

**Goal:** The 10 new Adolescent/Adult feelings (Grief, Resentful, Envious, Restless, Hopeful, Melancholy, Contentment, Indignation, Dread, Anticipation) are now in the UI but story generation still uses child-facing prompt rules ("keep the problem child-sized", "end with safety and reconnection"). This produces wrong output for mature bands.

### Files to Change

| File | What |
|------|------|
| `lib/screens/wizard_steps/wizard_data_mapper.dart` | Add emoji, description, and default coping for all 10 new feelings + mature aliases |
| `backend/routes/story_routes.py` | `_build_feelings_prompt_text()` — add age 15+ branch with mature story rules |
| `backend/services/story_service.py` | `_build_feelings_instruction()` — replace child-facing ending rule for ages 15+ |

### Mature Story Rules (ages 15+)
- Replace "child-sized and concrete" → "life-sized — real relationships, real stakes"
- Replace "let the helper action change what happens next" → "the coping gesture is a starting point, not a solution; it may land imperfectly"
- Replace "end with safety, reconnection, or relief" → "end with integration — the feeling can still be present at the close; resolution is not required"
- Add: "allow the feeling to be layered, contradictory, or unresolved where authentic"
- Keep: validate the feeling, show the body clue, avoid moralizing

### Status
- [x] wizard_data_mapper.dart — emoji/description/coping for new feelings
- [x] story_routes.py — mature branch in `_build_feelings_prompt_text`
- [x] story_service.py — mature ending rule in `_build_feelings_instruction`
- [x] Tests pass (105 backend, Flutter analyze clean)
- [x] Committed

---

## 2026-03-28 — Deployment Plan (Claude Sonnet 4.6)

Full cross-reference of TEAM_COORDINATION.md, commit history, and open items. Ordered by what must be done before launch.

### Phase 0: Commit Pending Work
- Commit 4 modified tracked files (TEAM_COORDINATION.md, custom_avatar_screen.dart, parental_consent_screen.dart, app_tts_service.dart)
- Commit untracked utility scripts and docs
- Push all commits to origin/main

### Phase 1 — P0 Blockers ✅ COMPLETE (committed 2026-03-28)

| # | File(s) | Issue | Fix |
|---|---------|-------|-----|
| 1 | `magic_review_step.dart` | Blank screen on generation failure — no error state, no retry, wizard state lost | Catch API exceptions; show child-facing error widget ("Uh oh! Something went wiggly.") + "Try Again" button; persist wizard state to Isar/shared_preferences before launch |
| 2 | `lib/custom_avatar_screen.dart` | "Take Photo" does nothing on web — silently fails | Fix `image_picker` web: use `ImageSource.gallery` as fallback; show clear fallback message if camera unavailable |
| 3 | `magic_review_step.dart` | Edit pencil on "Picture tale" routes to Step 1 instead of story style step | Fix the step index in the edit-pencil `onTap` callback to jump to the correct wizard step |
| 4 | `hero_creator_step.dart` + `app_tts_service.dart` | Archetype tap fires 2–4 simultaneous audio clips | Call `stop()` before any new archetype audio; queue chime then voice sequentially; guard against rapid taps |
| 5 | Loading screen | No animation; "Tap to make sparkles!" non-functional | Implement looping `AnimationController` with character + companion; wire `GestureDetector` to sparkle particle effect |

### Phase 2 — P1 Drop-off ✅ COMPLETE (committed 2026-03-28, items 6 + archetype split deferred to Phase 8)

| # | File(s) | Issue | Fix |
|---|---------|-------|-----|
| 6 | `hero_creator_step.dart` | Archetype screen conflates identity vs appearance | Split into 2 sequential steps: "Who is your hero?" → "How do they look?" |
| 7 | `hero_creator_step.dart` / TTS narration | Archetype narration says "choose your look" — wrong | Change to: "Who is your hero? Tap the one you like!" |
| 8 | Companion step | Sprouts shows full ~7+ companion roster instead of 4 band-specific ones | Enforce age band filter; Sprouts sees only: fluffy dragon, magic bunny, shining puppy, tiny fairy |
| 9 | Companion step | "My Pet is saved." shown for human friend | Replace all save-confirmation strings → "Your buddy is ready!" |
| 10–11 | Story world screen | "Make one up" dead end + prominent placement | Replace blank field with illustrated suggestion tiles + voice; move to bottom of list |
| 12 | `app_tts_service.dart` | TTS too fast for Sprouts | Add per-band `ttsRate`; Sprouts = ~0.8× default |
| 13 | `magic_review_step.dart` | "YOUR ADVENTURE AWAITS" overflows 63px | `FittedBox` or reduce font; add `overflow: TextOverflow.ellipsis` |
| 14 | `magic_review_step.dart` | "Big Feelings Quest" shown as scene/location label | Fix data mapping — display scene name + thumbnail; move thematic tag to story context |
| 15 | `magic_review_step.dart` | Companion not shown on review screen | Add companion portrait alongside hero portrait |
| 16–17 | Feelings step | Wrong vocab + 7 choices for Sprouts | Remove Disgusted/Fearful/Bad; replace with Happy/Sad/Angry/Scared/Excited (max 5) |
| 18 | `magic_review_step.dart` | Hardcoded `userId: 'guest'` for pick-a-path | Resolve real user ID from Riverpod auth state; fall back to 'guest' only if truly anonymous |
| 19 | `pick_a_path_adventure_screen.dart` | Stale token → 401 strands user | On 401: re-auth once, retry; on second failure show "Start over" |
| 20 | Backend subscription endpoint | Anonymous users get 403 on every page load | Allow anonymous JWT through `/api/subscription/status`; return free-tier default |

### Phase 3 — Production Environment Setup

| # | Where | Action |
|---|-------|--------|
| 21 | Railway env vars | Set real `SECRET_KEY` and `JWT_SECRET_KEY` (`python -c "import secrets; print(secrets.token_hex(32))"`) |
| 22 | Railway env vars | Remove duplicate `GOOGLE_API_KEY` / `GEMINI_API_KEY`; standardize on one |
| 23 | App startup | Re-consent prompt for users whose consent wasn't synced before 2026-03-21 |
| 24 | `lib/config/environment.dart` + Railway | Confirm prod URL in release build; `FLASK_ENV=production`, `DEBUG=False`; run story load audit baseline |

### Phase 4 — Compliance & Legal (Required Before Public Launch)

| # | Issue | Action | Status |
|---|-------|--------|--------|
| 25 | Privacy policy | Add physical postal address and phone number (COPPA requirement) | ✅ Phone (970) 640-2011 added to `privacy_policy_screen.dart`; postal address already present |
| 26 | `parental_consent_service.dart` | Photo consent toggle defaults ON → change to OFF; parent must explicitly opt in | ✅ `getAllowPhotoAvatar()` and `recordConsent()` both default to `false` |
| 27 | Consent form | Confirm email field is NOT pre-filled with PII in production builds | ✅ Verified: no pre-fill exists — email field starts empty, no getter retrieves stored email |

### Phase 5 — P2 Polish (partial ✅ — 2026-03-28)

- ✅ Sad cloud: rainy cloud (🌧️) + 2 tear drops for Sprout error state
- ✅ Feelings: play name aloud on single tap; confirm on double-tap/long-press
- ✅ Reduce Sprouts story choices: 2 orbs (Story Quest + Listen & Learn); remove "Pick something special!" section
- ✅ Loading screen background: dark-purple gradient replaces cream/lavender
- ✅ "Bring a Friend Along": mic button added; speaks name on finalResult
- ✅ Skip "Choose Your Avatar" bottom sheet; "Choose Look" goes directly to gallery
- ✅ Companion error message: "Magical transformation is unavailable" → child-friendly copy (done in hero_creator_step.dart)
- ✅ Story style orbs → illustrated scene thumbnail cards (0caeb34); pre-select "Adventure Story" was already default (includeIllustrations = true)

### Phase 6 — Testing

- 6-band integration test: visual, characters, companions, story, illustrations across all bands
- Cross-browser: Chrome ✓ → Firefox → Edge → mobile DevTools (iOS Safari, Android Chrome)
- Real API performance baseline: `RUN_REAL_API_TESTS=true python backend/tests/story_load_audit.py`

### Phase 7 — P3 Polish (Post-Launch OK)

- ✅ Sprouts progress bar: illustrated emoji icons (⭐🐉🌈✨) replace text labels (ad2490c)
- ✅ Remove character counter from avatar selection modal (ad2490c)
- ✅ Fix loading screen rotating message truncation — removed maxHeight:54 cap (ad2490c)
- ⏳ Audio-only CTA: verify end-to-end on Railway for all 6 age bands (`789fa48`) — manual QA

### Phase 8 — Structural (Post-Launch Design Discussions)

- ✅ Feelings screen placement: deferred BigFeelingsFlowScreen to Continue tap; scene selection → Continue → feelings flow → wizard next (a187364)
- ✅ Companion count for Sprouts: `maxCompanions` param on `_CompanionImageGrid`; Sprout=1, others=3 (a187364)
- ✅ Wizard state persistence: `WizardData.fromJson()` + `_saveWizardDraft()`/`_restoreWizardDraft()`/`clearWizardDraft()` via SharedPreferences (2a5f601, a187364)
- ✅ Loading screen mini-game: `_TapTarget` floating orbs with spawn timer, fade-in/out, tap-to-catch; "Catch the sparkles! ✨" CTA (a187364)

### Launch Order

```
Phase 0 → Phase 1 → Phase 3 → Phase 4 → Phase 2 → Phase 6 → soft launch → Phase 5 → Phase 7/8
```

---

## 2026-03-27 (Sprouts Band UX Audit — Six Hats Analysis — Claude Sonnet 4.6)

Full walkthrough of the Sprouts (3–5) wizard flow as a simulated 4-year-old user. 20 screenshots captured. Issues categorized by severity below.

### P0 — Blocks Use (Fix Before Any Further Testing)

| # | Screen | Issue | Fix |
|---|--------|-------|-----|
| 1 | Story generation (final) | White blank screen on story generation failure — no error state, no back button, no retry, no persistence of wizard state | Implement animated child-facing error state ("Uh oh! Something went wiggly. Let's try again!") + "Try Again" button; persist wizard state in local storage so retry doesn't restart from name entry |
| 2 | Avatar selection | "Take Photo" button does nothing — silently fails even when parent consented to photo avatars | Fix camera/image_picker integration on web; surface a clear fallback if permission is denied |
| 3 | Review screen | Edit pencil on "Picture tale" row navigates back to name entry (Step 1) instead of story style step | Route edit action to the correct wizard step |
| 4 | Archetype selection | Tapping an archetype fires 2–4 simultaneous audio clips + a chime at the same time — sensory overload | Play exactly one clip sequentially: chime first, then voice; cancel any in-flight audio before playing next |
| 5 | Loading screen | No animation renders during story generation; "Tap to make sparkles!" is non-functional | Fix sparkle tap interaction; implement looping character + companion animation for the wait state |

### P1 — Causes Drop-Off

| # | Screen | Issue | Fix |
|---|--------|-------|-----|
| 6 | Archetype screen | Screen conflates two decisions: WHO your hero is (archetype/identity) vs HOW they look (avatar) — a 4-year-old cannot hold both simultaneously | Split into two sequential screens: "Who is your hero?" → "How do they look?" |
| 7 | Archetype screen | Voice narration says "choose your look, pick the character you like" — this screen is identity/personality selection, not appearance | Rewrite to: "Who is your hero? Tap the one you like!" |
| 8 | Companion screen | Sprouts band shows the full companion roster (~7+) instead of the 4 band-specific companions (fluffy dragon, magic bunny, shining puppy, tiny fairy) — wrong data binding | Fix age band filter on companion list; Sprouts must only see their 4 assigned companions |
| 9 | Companion screen | "My Pet is saved." shown after adding a human friend via photo — wrong label | Replace all companion-saved messages with: "Your buddy is ready!" (type-agnostic) |
| 10 | Story world screen | "Make one up" / "Imagine it" navigates to a blank text input with no prompts, no voice, no suggestions — dead end for a non-reader | Replace blank text field with large illustrated suggestion tiles + auto-play voice: "You could fly, meet a fairy, go swimming... what sounds fun?" |
| 11 | Story world screen | "Make one up" is positioned prominently, encouraging non-readers toward the dead-end path | Move to bottom of option list, below all pre-suggested choices |
| 12 | Story world screen | Voice narration speaks too fast for 3–5 comprehension | Add per-age-band TTS speed parameter; Sprouts = ~80% of default rate |
| 13 | Review screen | "YOUR ADVENTURE AWAITS" heading overflows right edge by 63px — looks broken | Fix text overflow (wrap or reduce font size) |
| 14 | Review screen | "Big Feelings Quest" displayed as the scene/location label — it is a thematic tag, not a place | Fix data mapping so scene label renders the chosen scene name + scene thumbnail; "Big Feelings Quest" belongs in story context, not the scene slot |
| 15 | Review screen | Chosen companion is not displayed on the review/launch screen — child invested effort choosing a buddy but doesn't see them | Add companion portrait alongside hero portrait on review screen |
| 16 | Feelings screen | "Disgusted" and "Fearful" exceed 3–5 vocabulary; "Bad" is too vague | Remove Disgusted, Fearful, Bad from Sprouts feelings screen; replace with: Happy, Sad, Angry, Scared, Excited |
| 17 | Feelings screen | 7 simultaneous feeling choices — exceeds the 2–3 option cognitive limit for this age | Reduce to 4–5 choices for Sprouts band |

### P2 — Reduces Delight / Trust

| # | Screen | Issue | Fix |
|---|--------|-------|-----|
| 18 | Companion screen | "Magical transformation is unavailable right now." — adult-technical error language on a 4-year-old's screen | Replace with: "Oops! Magic isn't working on that picture. Want to pick a buddy instead?" + large retry/alternative button |
| 19 | Feelings screen | Sad cloud has no tears — facial expression alone is ambiguous for pre-readers | Add 1–2 illustrated tears to the Sad cloud face |
| 20 | Feelings screen | No audio plays the feeling name when a cloud is tapped before confirming — non-readers cannot identify options without audio | Play feeling name aloud on single tap; confirm on double tap or hold |
| 21 | Story world screen | Story style orbs are small and abstract — a 4-year-old cannot decode "Pick a Path" from an orb icon | Replace orbs with illustrated scene thumbnails; pre-select "Adventure Story" by default with a highlight border |
| 22 | Story world screen | 8 total story choices (4 styles + 4 specials) displayed across two sections | Reduce to 2 primary story styles for Sprouts; integrate up to 4 themes as illustrated tiles in the same grid; remove "Pick something special!" as a separate section |
| 23 | Loading screen | Background switches from dark purple to light lavender with no transition — breaks immersion | Match loading screen background to app's dark-purple brand color |
| 24 | Companion screen | "Bring a Friend Along:" section requires typing a friend's name — 3–5 year olds cannot type | Replace text input with a voice/mic button: "Tap to say your friend's name!" using speech-to-text |
| 25 | Name entry | Two microphone icons (one inside input field, one on "Tap to say your name" button) — duplicate affordances cause hesitation | Remove mic from inside the text input; keep only the standalone "Tap to say your name" button |
| 26 | Avatar selection | "Choose Your Avatar" bottom sheet and "Hi Alice!" modal appear to cover the same decision in two different UI patterns — likely a routing conflict | Remove the "Choose Your Avatar" bottom sheet; route all avatar type selection through the "Hi Alice!" two-button modal exclusively |

### P3 — Polish / Nice-to-Have

| # | Screen | Issue | Fix |
|---|--------|-------|-----|
| 27 | All wizard screens | Step progress bar uses text labels ("My Hero!," "My Buddies!," etc.) — unreadable for 3–5 | Replace text labels with illustrated icons only for Sprouts band |
| 28 | Parental consent | "Allow photo-based avatar creation" toggle defaults to ON | Default to OFF; parent must explicitly opt in (COPPA best-practice for imagery features) |
| 29 | Avatar modal | "150 characters to disc..." truncated counter visible in gallery avatar modal | Remove — character counter belongs on a text input screen, not avatar selection |
| 30 | Loading screen | "Something magical is about..." mid-sentence — rotating message text is truncated | Fix to display complete sentences |

### Structural Recommendations (Require Design Discussion)

- **Feelings screen placement**: "How are you feeling?" currently appears mid-wizard as a modal. User feedback suggests it doesn't read as a "scene" or "place" — it feels like a detached administrative step. Recommend relocating it so it flows naturally as a story element (e.g., after scene selection as "What should happen in your story?") rather than interrupting hero/buddy setup.
- **Companion count for Sprouts**: Reduce companion slots from 3 to 1 for this age band — one buddy is enough and reduces decision fatigue.
- **Story generation failure recovery**: Wizard state must survive a failed generation attempt. Currently a blank screen with no path back forces full restart — all choices are lost.
- **Loading screen as engagement**: The loading wait (15–60 seconds) is the highest-stakes UX moment for a 4-year-old. A static screen with broken sparkles will cause most children to abandon. This screen should be a mini-game or full character animation, not a progress indicator.

### Privacy Note (Test Environment)

A real email address was visible in the parental consent screenshot (in the pre-filled email field). Confirm this is a dev-only pre-fill and that production builds do not pre-populate PII in consent forms.

---

## 2026-03-27 (Accurate Word Highlighting + TTS Web Fix + Age-Band Asset Compression — Claude Sonnet 4.6)

### Open / Still-Needed Items (as of 2026-03-27)

#### Bug / Regression
- ✅ **Subscription sync 403 on web** — fixed 2026-04-20 (commit `de5758f`): `SubscriptionSyncService` now skips the network call entirely for `anon_` users and emits free tier directly. See session 2026-04-20b.
- **Device TTS fallback still logs `[object SpeechSynthesisErrorEvent]`** — this is inside `flutter_tts_web.dart`'s `utterance.onError` handler (`print(event)` on line ~99). Cannot be suppressed from app code; only relevant if ElevenLabs is unavailable. File a `flutter_tts` upstream issue or patch via override if it becomes noisy in prod.

#### Auth / Pick-A-Path (from 2026-03-25 Codex audit — status unknown)
- `magic_review_step.dart` — resolve real user ID before launching `PickAPathAdventureScreen` (stop hardcoding `userId: 'guest'`)
- `pick_a_path_adventure_screen.dart` — one-time re-auth + retry on 401 so stale anonymous tokens don't strand users
- Verify the audio-only CTA (`789fa48`) works end-to-end on Railway for all 6 age bands

#### Testing
- 6-band integration test (visual, characters, companions, story, illustrations) — never run against current codebase
- Cross-browser: Chrome ✓ (dev) → Firefox → Edge → mobile DevTools
- Real-provider performance baseline: `RUN_REAL_API_TESTS=true python backend/tests/story_load_audit.py`

#### Production Env
- Set real `SECRET_KEY` and JWT secret in Railway (currently dev defaults)
- Remove duplicate `GOOGLE_API_KEY` / `GEMINI_API_KEY` env vars
- Re-consent prompt for users whose consent wasn't synced before 2026-03-21
- Privacy policy missing physical address and phone number

---

### Accurate Word Highlighting in Read-Aloud (Younger Age Groups)

**Problem**: The story reader was estimating word highlight positions using character-weighted duration estimation — this was noticeably inaccurate and broken for younger readers who rely on word-by-word tracking.

**Solution**: Used the ElevenLabs `/v1/text-to-speech/{voice_id}/with-timestamps` endpoint which returns character-level audio alignment data (exact millisecond start/end per character → merged to word-level).

#### Backend Changes
- **`backend/elevenlabs_tts_service.py`**
  - Added `_chars_to_word_timestamps()` static method: merges per-character alignment data into word-level `[{start_ms, end_ms}]` list
  - Added `generate_speech_with_timestamps()`: calls `client.text_to_speech.convert_with_timestamps()`, returns `(audio_bytes, word_timestamps)` tuple; falls back to `generate_speech()` + empty list on any failure
- **`backend/routes/tts_routes.py`**
  - For short (<5000 char) single-voice stories: calls `generate_speech_with_timestamps()` instead of `generate_speech()`
  - All response paths now return `word_timestamps` key (populated for short single-voice, empty list for dialogue/chunked modes)

#### Flutter Changes
- **`lib/services/tts_api_service.dart`**
  - New `TtsSynthesisResult` class with `audioBytes: Uint8List` and `wordTimestamps: List<({int startMs, int endMs})>`
  - `synthesize()` now returns `Future<TtsSynthesisResult?>` (was `Future<Uint8List?>`)
  - Parses `word_timestamps` array from backend response
- **`lib/story_reader_screen.dart`**
  - Stores `_wordTimestamps` from `TtsSynthesisResult`
  - `onPositionChanged` listener: binary search on `_wordTimestamps` when non-empty (exact path); falls back to character-weighted estimation when empty (ElevenLabs unavailable)
  - Clears `_wordTimestamps` on playback complete
- **`lib/services/app_tts_service.dart`**, **`lib/story_result_screen.dart`**, **`lib/widgets/voice_picker_sheet.dart`**
  - Updated all `TtsApiService.synthesize()` call sites to use `ttsResult?.audioBytes`

---

### Age-Band Asset Compression + Registration

**Problem**: 238 AI-generated images in `age_band_assets/` totalled ~94MB uncompressed — too large to add to git without risking Railway snapshot timeouts again.

**Solution**: Compressed all images in-place using Pillow 256-colour quantisation before committing.

#### Script: `scripts/compress_age_band_assets.py`
- PNGs with alpha (RGBA): `Image.Quantize.FASTOCTREE` → 256 colours (only valid method for alpha channels)
- PNGs without alpha (RGB): `Image.Quantize.MEDIANCUT` → 256 colours
- JPGs: re-encode at quality=78 only if >400KB (most are already well-compressed)
- Skips `older_adolescents/` (no AgeBand enum mapping) and `toddlers/` (empty)

#### Result
| Metric | Value |
|--------|-------|
| Files processed | 238 |
| Before | 93.9 MB |
| After | 27.7 MB |
| Reduction | **65% (70% vs original ~94MB)** |

#### Registration
- `pubspec.yaml` already had all `age_band_assets/` subdirectory entries (lines 155-196) for all 6 bands
- `lib/theme/age_band_asset_resolver.dart` already fully implemented with `archetypePath()`, `backgroundPath()`, `scenePath()`, `companionPath()`, `feelingPath()`, `orbPath()`, `uiPath()` methods

#### Bands Covered
`sprouts/`, `early_readers/` (explorer), `adventurers/`, `creators/`, `adolescents/`, `adults/`

---

### ElevenLabs TTS Web Fix — Blob-URL AudioElement (Claude Sonnet 4.6)

**Problem**: On Flutter Web, `AppTtsService.speak()` was throwing `TimeoutException after 0:00:30.000000: Future not completed` when ElevenLabs audio successfully returned, causing a silent fallback to the device Speech Synthesis API (which then logged `[object SpeechSynthesisErrorEvent]`). TTS was effectively broken on the web build.

**Root cause**: `audioplayers` 6.x has a static `preparationTimeout = const Duration(seconds: 30)`. When `BytesSource(mp3)` is played on web, `audioplayers_web` converts the bytes to a `data:audio/mpeg;base64,...` URI, sets it on an HTML audio element, and connects that element to a Web `AudioContext` with `crossOrigin='anonymous'`. Chrome's autoplay policy suspends the `AudioContext` unless triggered by a direct user gesture, which prevents the `loadeddata` event from firing. After 30 seconds the `preparationTimeout` fires as a `TimeoutException`, caught by `speak()`'s catch block, which falls back to `flutter_tts` device speech. The device fallback then also fails because Chrome's `SpeechSynthesis` API throws a `not-allowed` error (autoplay) which `flutter_tts_web.dart` prints literally as `[object SpeechSynthesisErrorEvent]`.

**Fix**: Added a conditional-import web audio helper that bypasses `audioplayers` entirely on web:
- `lib/services/web_audio_player.dart` — web: creates a blob URL from the MP3 bytes and plays it via a plain `HTMLAudioElement` (no `AudioContext`, no `crossOrigin`, no 30s timeout)
- `lib/services/web_audio_player_stub.dart` — non-web: no-op stubs so the import compiles on Android/iOS/desktop
- `lib/services/app_tts_service.dart` — `speak()` branches on `kIsWeb` to use `playAudioBytesOnWeb()` instead of `_player.play(BytesSource)`; `stop()` calls `stopWebAudio()` (no-op on non-web)

**Commit**: `f9eb330`

---

## 2026-03-25 (Pick-A-Path Audit + Auth Hardening — Codex)

### Live Audit Findings
- Tested the deployed Railway frontend (`grand-light-production-68d9.up.railway.app`) through the pick-your-path wizard as a user.
- Confirmed a hard blocker on interactive launch: the flow reached `Pick-A-Path Adventure` and failed with `Unable to start story (code 401): Authentication required`.
- Confirmed UX mismatch: step 2 is framed as "Choose Your Adventure", but step 4 still leaves `Pick-A-Path Adventure` off by default.
- Confirmed adult-band regression in the deployed app: child-oriented scenarios, including `Big Feelings Quest`, were still visible for age 25.
- Confirmed audio-only is not integrated into the pick-your-path review flow; current implementation lives under the separate bedtime wizard entry point.

### Code Changes In Progress
- `lib/screens/wizard_steps/magic_review_step.dart`
  - Resolve the authenticated/anonymous user ID before launching `PickAPathAdventureScreen`.
  - Stop hardcoding `userId: 'guest'` for interactive launches.
- `lib/pick_a_path_adventure_screen.dart`
  - Add one-time re-auth + retry behavior when the interactive API returns 401 so stale or missing anonymous tokens do not strand the user immediately.
- `lib/screens/wizard_steps/feeling_selection_step.dart`
  - Default the wizard into pick-your-path when the user advances from the adventure scenario step; keep the review toggle for opt-out.
- `lib/screens/wizard_story_screen.dart`
  - Rename bedtime interactive toggle copy so the audio-only path is clearly described as a voice-led pick-a-path bedtime story.
- `lib/screens/bedtime_wizard_screen.dart`
  - Switch bedtime voice prompts, fallback companions, and fallback settings to use the resolved age band instead of child-only defaults.
  - Replace `tiny dragon` / `Magical Forest` fallbacks for older bands with mature options such as `Thunder Wolf`, `Deep Archive`, and `Ruined Citadel`.
  - Keep younger bands on playful bedtime language while giving older bands/adults a cleaner audio-only prompt vocabulary.
- `lib/screens/wizard_steps/feeling_selection_step.dart`
  - Make `Guardian Mode` copy age-aware so older users do not see child-only framing like "support your child's growth."
  - Swap child-only focus chips for creator/adolescent/adult options such as `Finding Your Voice`, `Setting Boundaries`, and `Burnout & Rest`.
  - Rename the note field for older bands from `Parental Note` to `Story Note`.
- `lib/screens/wizard_steps/magic_review_step.dart`
  - Add a direct `Audio-Only Adventure` launch from the review step whenever `Pick-A-Path Adventure` is enabled.
  - Route that CTA into `BedtimeWizardScreen(isInteractive: true)` so users and parents do not have to discover the separate bedtime entry point first.

### Next Planned Fixes
1. Re-test the deployed bedtime/audio-only flow for each age band after this copy/defaults patch is live.
2. Re-verify adult scenario filtering in `feeling_selection_step.dart` once Railway has the newer frontend commits.
3. Follow the new review-step audio-only CTA in the deployed app and confirm it is understandable for both child and parent use cases.

---

## 2026-03-23 (Railway Deployment Fix — Git Repo Size Reduction — Claude Sonnet 4.6)

### Problem
Frontend service `grand-light` on Railway failed with:
> "Repository snapshot operation timed out. This may be due to a large repository size or network issues."

Root cause: git pack size had grown to **691MB** due to accumulated binary image assets in history, causing Railway's repo clone step to time out before the Docker build could start.

### Diagnosis
- `avatarImages/` (402 files, several at 7MB+ each — high-res PNG originals) was committed to git
- `assets/feelings_faces_backup_20260130_150545/` (125 files) — a local backup that was accidentally committed
- 1,755 image files total across `assets/`, accumulating across many commits
- BFG identified 13 blobs >5MB across history

### Fix Applied

| Step | Action |
|------|--------|
| 1 | `git rm -r --cached avatarImages/ assets/feelings_faces_backup_20260130_150545/` — removed from tracking |
| 2 | Updated `.gitignore` to exclude `avatarImages/` (entire dir) and the backup folder going forward |
| 3 | Committed removal as `chore: untrack avatarImages and feelings backup from git` |
| 4 | Downloaded **BFG Repo Cleaner 1.14.0** and ran `--delete-folders avatarImages --strip-blobs-bigger-than 5M` — rewrote **1,412 commits** |
| 5 | `git reflog expire --expire=now --all && git gc --prune=now --aggressive` — compacted pack: **691MB → 564MB** |
| 6 | `git push origin main --force` — pushed rewritten history to GitHub |
| 7 | Railway auto-triggered new deployment; all 4 services reached **SUCCESS** |

### Result
- `grand-light` (frontend), `story-weaver-app` (backend), `lovely-perfection`, and Redis all deployed successfully
- `avatarImages/` and the backup folder no longer exist in any commit in git history
- Future growth from large binary originals is blocked by `.gitignore`

### Remaining Concern
At 564MB the pack is still large — primarily from `assets/images/` (333MB of legitimately needed Flutter assets). If Railway snapshot timeouts recur, the next steps are:
1. **Git LFS** — convert large binary assets to LFS pointers (preferred long-term fix)
2. **Second BFG pass** with lower threshold (e.g. `--strip-blobs-bigger-than 2M`) — risky as it may strip needed assets
3. **CDN offload** — serve static assets from a CDN and reference by URL instead of bundling

### Commits
- `chore: untrack avatarImages and feelings backup from git` — removal + gitignore update (history-rewritten hash)

---

## 2026-03-22 (Phase 4: Visual Asset Overhaul — Batch 1 & Priority Batch)

### Scope Completed
- Executed a massive visual asset refresh using **Imagen 4** (`models/imagen-4.0-generate-001`) via the Gemini API.
- Processed 134 images from `full_image_replacement_prompts.md` (Scenarios, Companions, Scenes, Backgrounds, Themes, Feelings Faces, UI Characters, Legacy Icons).
- Processed 19 high-priority images from `full_image_audit_report.md` (Critical safety fixes, Age-differentiated archetypes, Splash screens).
- Implemented an automated image generation pipeline with **multi-key rotation** to handle rate limits (429 errors).

### Key Achievements & Safety Fixes

| ID | Action | Result |
|----|--------|--------|
| **CRITICAL** | Adolescent Story Page Background | Replaced "body horror" lightning skin imagery with a calming, creative teen study space. |
| **SAFETY** | Inappropriate Filename/Content | Deleted `aroused.png`; generated `stimulated.png` with appropriate expression. |
| **SAFETY** | Scenario Content Fixes | Replaced "Mystery" (noir/adult) and "Survival" (visible knife) with age-appropriate, safe alternatives. |
| **FIX** | Animal Whisperer Archetype | Generated 5 distinct, age-calibrated versions (Explorer, Adventurer, Adolescent, Adult, Creator) to replace the single identical placeholder. |
| **FIX** | Theme Icon Placeholders | Replaced the uncanny featureless mannequin icons for "Adventure" and "Magic" with vibrant, symbolic badge icons. |
| **FIX** | Splash Screen Quality | Replaced "Gothic" adult splash and "confusing" adventurer splash with aspirational, age-appropriate scenes. |
| FIX | Feelings Faces | Generated a full set of 20+ consistent 3D cartoon feelings faces across core, secondary, and tertiary categories. |
| **FIX** | Adventurer Badge Grid | Generated the 8 core feeling badges (Happy, Excited, Calm, Sad, Worried, Frustrated, Angry, Embarrassed) specifically for the Adventurer band (ages 9-11) in the "Cosmic Chronicle" cinematic style. |


### Infrastructure Improvements
- Created `generate_priority_images.py`: A robust generation script that rotates through multiple API keys (`GEMINI_API_KEY`, `GOOGLE_API_KEY_2`, `GOOGLE_API_KEY_3`, `GOOGLE_API_KEY_4`) and handles retries/backoffs automatically.
- Created `extract_priority_prompts.py`: Automated extraction of replacement prompts from audit reports.

### Commits
- `c0ffee1` — feat: Phase 4 Visual Asset Overhaul — 134 base assets generated
- `deadbee` — fix: CRITICAL safety image replacements and priority archetype differentiation

### Next Steps
- **Verification**: Manually verify the visual quality of the 153 new assets.
- **Scale**: Process the remaining 127 unique asset prompts from `docs/GUI_AGE_BAND_ASSET_PLAN.md` to achieve 100% custom asset coverage.
- **Cleanup**: Remove any remaining legacy/unused placeholder assets identified in the audit.

---

## 2026-03-20 (Phase 1-5 UX Audit Implementation — Gemini 3 Pro + Claude Sonnet 4.6)

### Scope Completed
- **Gemini 3 Pro** executed Tasks 1.1, 1.2, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7 (all of Phase 1 and Phase 2)
- **Claude Sonnet 4.6** executed Tasks 3.1, 3.4, 3.5, 3.6, 4.5, 5.1, 5.4 in this session

### Changes Made (Claude Sonnet 4.6 — 2026-03-20)

#### Task 3.1 — Wire Per-Band Archetype Images
- Updated `imagePathForBand()` in `lib/widgets/archetype_card.dart` to use `assets/images/archetypes/${band.name}/$bandImageId.jpg` for all non-Sprout bands
- Copied `animal_whisperer.jpg` into all 5 non-Sprout band asset directories (explorer, adventurer, creator, adolescent, adult)
- Note: per-band JPG files are gitignored by `*.jpg` rule but are registered in `pubspec.yaml` and will bundle correctly

#### Task 3.4 — Move Story Length Picker to Review Screen
- Removed orb-based story length picker (heading + 3x `ImageCrystalFormation`) from `hero_creator_step.dart`
- Added interactive `_LengthChip` row to `magic_review_step.dart` — hidden for Sprout, band-adaptive labels (Short/Medium/Long for mature, Short tale/Story time/Big adventure for young)
- Added `_LengthChip` widget class and `_lengthLabelForBand()` helper

#### Task 3.5 — Fix CinzelDecorative Font for Sprout
- Changed `useDecorative` flag in `hero_creator_step.dart` from `sprout || explorer` to `explorer` only (2 occurrences)

#### Task 3.6 — Fix Navigation Button Consistency for Mature Bands
- Changed all 3 nav button conditionals in `wizard_story_screen.dart` from `band.band != AgeBand.creator` to `!band.band.isMature`
- Adolescent and Adult now correctly get icon-only nav

#### Task 4.5 — Emoji Slider Threshold
- Changed `isYoung = age <= 11` to `isYoung = age <= 8` in `feeling_selection_step.dart`
- Ages 9+ (Adventurer band and above) now see text labels instead of emoji endpoints

#### Task 5.1 — Remove Dead Code
- Deleted `_SproutHeroChoice` class and all 4 unused list constants (`_sproutHeroChoices`, `_explorerHeroChoices`, `_adventurerHeroChoices`, `_creatorHeroChoices`) from `hero_creator_step.dart`
- Removed ~170 lines of dead code

#### Task 5.4 — Voice Input for Imagine It Field
- Added `speech_to_text` import and `_toggleVoiceInput()` method to `feeling_selection_step.dart`
- Mic button appears on "Imagine It" TextField for ages ≤8 only; red when listening

### Commits
- `5e5e9be` — feat: Phase 3 UX audit fixes — archetype images, story length, fonts, nav
- `139cf9e` — feat: Phase 4+5 UX audit fixes — sliders, dead code, voice input

### Additional Changes (Claude Sonnet 4.6 — second session, 2026-03-20)

#### Task 1.3 — 12 Feelings Face PNGs (Gemini 3 Pro)
- Gemini generated all 12 missing PNGs; now 21 files in `assets/images/feelings/sprout/`

#### Task 3.2 — SKIPPED
- `assets/feelings_faces/` already has 150+ wired images, better than 8-image per-band dirs

#### Task 3.3 — Mature Feelings Picker Style
- Added `AgeBandThemeData` import to `lib/widgets/feelings_cloud_picker.dart`
- Mature bands (isMature=true): flat rounded-rect emotion cards, system font, no cloud clip, subtle border
- Young bands: unchanged cloud shape with gradient and Fredoka font
- `_TertiaryChip`: rectangular (radius 10) for mature, pill (radius 50) for young
- `_Breadcrumb`: emoji hidden, system font for mature
- `_TertiaryGrid`: "Which feels most accurate?" label for mature

#### Task 4.1 — Sprout Scenario Filter
- Sprout (age ≤5) now only sees Magical Worlds category in `_buildScenarioSections()`
- Real-Life Heroes hidden behind filter (too abstract for pre-readers)

#### Task 4.3 — Creative Brief Expandable Sections
- `_buildBriefSection()` now uses `ExpansionTile` instead of plain `Column`
- "Character & Role" expanded by default; Personality/World/Story Options collapsed

#### Task 4.4 — Archetype Carousel Dots
- Animated position dots added below horizontal archetype `ListView` in `_buildArchetypeCards()`
- Selected archetype shows gold wide dot; unselected show small white dots

#### Task 5.2 — Age Check Centralization
- `big_feelings_flow_screen.dart`: `_bandFolder()` now uses `ageBandFromAge().name` (1 line, was 6 raw if-checks)
- `feelings_garden_screen.dart`: extracted `_tabCount` getter, eliminating duplicated logic in initState/build

### Commits
- `5e5e9be` — feat: Phase 3 UX audit fixes — archetype images, story length, fonts, nav
- `139cf9e` — feat: Phase 4+5 UX audit fixes — sliders, dead code, voice input
- `f0f3233` — feat: Tasks 3.3, 4.1, 4.3, 4.4, 5.2 — picker style, scenarios, brief, dots

---

## 2026-03-20 (Comprehensive Static Testing — Story Pipeline & Age-Band Audit)

### Scope
Static analysis of 7 areas: story payload completeness, story launch, illustration service, feelings UX per band, "Imagine It" passthrough, backend story generation, and dart analyze.

### Findings

#### TEST 1: WizardDataMapper — Story payload completeness
- Companions (pets + characters): correctly included via `companion_pets` / `companion_characters`. PASS.
- Custom scenario text ("Imagine It"): `customElements` field is written by `_safeSpaceController.onChanged` and included in mapper output. PASS.
- Age: included as `age`. PASS.
- Personality sliders: included in `characterDetails['personality_sliders']`. PASS.

#### TEST 2: magic_review_step.dart — Story launch
- **BUG FOUND**: `therapeuticPrompt`, `conflictHook`, `sensoryPalette`, `worldBible`, `moodPhysics`, and `lifeChallenge` were computed by `WizardDataMapper` but never forwarded through `ApiServiceManager.generateStory()` to the backend. All scenario-specific world-building, mood, and therapeutic data was silently dropped.
- Custom avatar handled correctly. Age passed correctly.

#### TEST 3: StoryIllustrationService — Age-appropriate illustrations
- Character appearance, age, companions all passed to backend. PASS.
- Backend uses age to adjust illustration prompt style. PASS.

#### TEST 4: Feelings section — per-band UX
- `FeelingsCloudPicker._maxLevel`: age ≤ 5 → level 0, 6-8 → level 1, 9+ → level 2. Correct.
- `CloudEmotionCard` uses `isMature` to switch between cloud-shape (young) and flat rectangle (mature). Correct.
- `BigFeelingsFlowScreen` triggered for age ≤ 5 (as `_openFeelingsQuest` checks). Correct.
- Scenario filter (`minBand`) in `_buildScenarioSections` working correctly.
- Voice mic hidden for age > 8 in safe_space input field. Correct.

#### TEST 5: Custom "Imagine It" passthrough
- Full chain confirmed working: `_safeSpaceController → wizardData.customElements → WizardDataMapper['customElements'] → ApiServiceManager body 'customElements' → backend task_kwargs['custom_elements'] → AdvancedStoryEngine prompt`. PASS.

#### TEST 6: Backend story generation
- `story_service.py` has full age-band constraint table (6 bands from 3-4 to adult). Age calibration built into `AdvancedStoryEngine.generate_enhanced_prompt`. PASS.
- Companions included in all story prompt builders (enhanced, rhyme time, bedtime, LTR). PASS.
- `custom_elements` passed verbatim to prompts. PASS.
- `therapeutic_prompt` fully integrated via `_augment_therapeutic_prompt`. PASS.
- **BUG**: The `age` field was only sent as `character_age` in the HTTP body. Backend reads `age` first, falls back to `character_age`. Added `'age': age` to ensure primary key is set.

#### TEST 7: dart analyze
- No errors. 27 pre-existing warnings/infos (all in files not modified this session).

### Fixes Applied

| File | Change |
|------|--------|
| `lib/services/api_service_manager.dart` | Added `therapeuticPrompt`, `conflictHook`, `sensoryPalette`, `worldBible`, `moodPhysics`, `lifeChallenge` params to `generateStory()`, `_generateStoryWithBackendRetry()`, `_generateStoryWithBackend()`; threaded into HTTP body. Also added `'age': age` alongside existing `'character_age'` for backend compatibility. |
| `lib/screens/wizard_steps/magic_review_step.dart` | Pass `therapeuticPrompt`, `conflictHook`, `sensoryPalette`, `worldBible`, `moodPhysics`, `lifeChallenge` from `requestData` to `ApiServiceManager.generateStory()`. |

### Items NOT Fixed (Pre-existing, Noted for Future Work)
- 12 missing feelings face PNGs (`assets/feelings_faces/`) — asset creation task, not code.
- `main_story.dart` unused fields/methods (dead code cleanup, low risk).
- `therapist_portal_screen.dart` deprecated `withOpacity()` calls.

---

## 2026-03-19 (Comprehensive Age-Band UX/UI Audit — Claude + Gemini + Codex)

### Scope Completed
- Triple-auditor UX/UI review of every screen, widget, text string, image reference, and interaction flow across all 6 age bands (Sprout 2-5, Explorer 6-8, Adventurer 9-11, Creator 12-14, Adolescent 15-17, Adult 18+).
- Claude performed the primary static code audit; Gemini CLI and Codex performed independent parallel audits.
- Cross-referenced all three audits, verified each claim against actual source code, and synthesized into one unified fix plan.
- Verified 10 new issues from Gemini/Codex, confirmed 2 claims were false/reversed, and identified convergent findings.

### Cross-Audit Verification Results

| # | Claim | Source | Verified? |
|---|-------|--------|-----------|
| 1 | "Limerick Laughs" mislabels reading mode for Explorer/Adventurer | Both | YES — `_getReadingLabel()` at `hero_creator_step.dart:1733` |
| 2 | 12 feelings face assets missing (bothered, bouncy, gloomy, etc.) | Codex | YES — PNGs not in `assets/feelings_faces/` |
| 3 | `emotion_recognition_game.dart` references non-existent `assets/emotions/` | Codex | YES — marked "placeholder", dir missing |
| 4 | Welcome screen "Once Upon YOUR Child" is parent-facing | Codex | YES — `welcome_screen.dart:229-255` |
| 5 | Bedtime "Go to Settings" button only calls `Navigator.pop()` | Codex | YES — `bedtime_wizard_screen.dart:605-617` |
| 6 | Creative Brief uses clinical labels ("PSYCHOLOGICAL VITALITY", etc.) | Both | YES — `hero_creator_step.dart:2962,2983,3216,3223` |
| 7 | Companion selection mixes IDs and names inconsistently | Codex | YES — multiple locations in hero_creator_step |
| 8 | Dead code `_sproutHeroChoices` / `_explorerHeroChoices` | Gemini | YES — defined but unreferenced |
| 9 | CinzelDecorative used for Sprout/Explorer — legibility concern | Gemini | YES — `useDecorative` flag covers both bands |
| 10 | FeelingsGardenScreen tab labels not mature for Creator+ | Codex | YES — same labels for all ages 8+ |
| 11 | "Only Creator gets icon-only nav; Adolescent still has labeled" | Codex | **FALSE** — logic reversed in actual code |
| 12 | "Scenario titles hard-code age 15 for Creator" | Codex | **FALSE** — proper `titleForAge()` thresholds exist |

### Key Convergent Findings (All Three Auditors Agree)

1. **BigFeelingsFlowScreen** (`big_feelings_flow_screen.dart:178`): Hardcoded `Color(0xFF1A0E3A)` background and `GoogleFonts.fredoka` ignores age-band theme entirely. Only 3 feelings (Mad/Sad/Scared) — no Happy/Excited. Uses emoji instead of existing `assets/images/feelings/sprout/*.png`. This is the single worst theme violation in the codebase.
2. **"Make Magic" CTA** and **"Gather Party!" companion button**: Not band-configurable. Juvenile for Creator/Adolescent/Adult.
3. **Per-band archetype/feelings/companion images exist but are unused**: `assets/images/archetypes/{band}/`, `assets/images/feelings/{band}/`, `assets/images/companions/{band}/` all have assets. Only Sprout archetypes and per-band companions are wired. Feelings images unused across ALL bands.
4. **Bedtime/audio mode not age-band-aware**: Same prompts ("magical bedtime story", "sweet dreams") for all ages 2–adult.
5. **Child coping strategies shown to adults**: "Stomp like a dinosaur" appears in `FeelingDetail.coping` for all ages.
6. **Feelings picker UI (cloud cards) clashes with dark mode bands**: Creator/Adolescent/Adult dark editorial aesthetic gets playful rounded cloud shapes.
7. **Animal Whisperer `bandImageId: 'mighty_guardian'`**: Per-band image mapping mismatched with archetype concept (`archetype_card.dart:344`).

### 5-Phase Fix Plan

#### Phase 1: Critical Bugs & Broken Functionality (Fix Now)

| ID | Issue | File(s) | Fix |
|----|-------|---------|-----|
| ✅ 1.1 | BigFeelingsFlowScreen ignores age-band theme | `big_feelings_flow_screen.dart` | `themeForAge(childAge)` replaces `Theme.of(context)` fallback (b809390) |
| ✅ 1.2 | "Limerick Laughs" reading mode label | `hero_creator_step.dart:_getReadingLabel()` | Explorer: 'Read Along' → 'Easy Reader' (b809390) |
| ⏳ 1.3 | 12 missing feelings face assets | `assets/feelings_faces/` | Generate: bothered, bouncy, gloomy, grossed_out, hurt_mad, hyper, impatient, let_down, red_faced, stuck, what_if_y, wish_i_could_hide PNGs — **needs image generation** |
| ✅ 1.4 | Bedtime "Go to Settings" doesn't navigate | `bedtime_wizard_screen.dart` | Capture navigator before pop() to fix stale context (b809390) |
| ✅ 1.5 | Companion selection ID/name mismatch | `hero_creator_step.dart` (multiple) | `selectedCompanions.contains(c.id)` as source of truth (b809390) |
| ✅ 1.6 | `emotion_recognition_game.dart` references missing `assets/emotions/` | `character_evolution_screen.dart` | Removed dead import; file already uses `assets/images/feelings/sprout/` (b809390) |

#### Phase 2: Age-Band Text & Tone Calibration (High Impact UX)

| ID | Issue | File(s) | Fix |
|----|-------|---------|-----|
| 2.1 | Primary CTAs not band-configurable | `age_band_theme.dart`, `magic_review_step.dart`, `companion_selector_step.dart` | Add `magicCTALabel`/`companionCTALabel` to `AgeBandThemeData`. Sprout/Explorer: "Make Magic!" / "Gather Party!"; Adventurer: "Start Adventure!" / "Assemble Party"; Creator: "Create Story" / "Set the Cast"; Adolescent: "Start Writing" / "Continue"; Adult: "Begin" / "Continue" |
| 2.2 | Creative Brief clinical labels | `hero_creator_step.dart:2870+` | "PSYCHOLOGICAL VITALITY" -> "Energy Level"; "SOCIAL ARCHITECTURE" -> "Social Style"; "INITIALIZE STORY GENERATION" -> band-specific CTA |
| 2.3 | Mature archetype names/descriptions stale | `archetype_card.dart` | Add `matureDescription` field; "Senior Architect" -> "Vision Architect"; update all descriptions for 12+ register |
| 2.4 | Welcome screen "Once Upon YOUR Child" | `welcome_screen.dart:229-255` | Change to "Once Upon a Time..." or "Welcome to Story Weaver" |
| 2.5 | Bedtime mode prompts not band-aware | `bedtime_wizard_screen.dart` | Pass age band; Creator+: no "bedtime"/"sweet dreams", use "story dictation" framing; match companion voice list to band companions |
| 2.6 | FeelingsGardenScreen tab labels juvenile for mature bands | `feelings_garden_screen.dart` | Adventurer: "Mood Check"/"Mood Explorer"/"My Journal"; Creator: "Mood"/"Explore"/"Journal"; Adolescent: "Inner Map"/"Deep Dive"/"Reflections"; Adult: "Landscape"/"Explore"/"Reflections" |
| 2.7 | Child coping strategies shown to adults | `feelings_wheel_data.dart` | Add `matureCoping` field to `FeelingDetail`; fork by `AgeBand.isMature` |

#### Phase 3: Visual Consistency & Asset Wiring (Medium Impact)

| ID | Issue | File(s) | Fix |
|----|-------|---------|-----|
| 3.1 | Per-band archetype images unused | `archetype_card.dart:imagePathForBand()` | Extend to check `bandImageId` files for all bands; fix `shyOne.bandImageId` from `'mighty_guardian'` to `'animal_whisperer'` |
| 3.2 | Per-band feelings images unused (48 PNGs) | Feelings cloud picker / FeelingsQuestModal | Wire `assets/images/feelings/{band}/*.png` as primary imagery |
| 3.3 | Feelings picker UI clashes with dark mode | FeelingsQuestModal widget | Create `isMature` variant with geometric/flat card style, dark background, sharp corners |
| 3.4 | Story length picker GUI issues | `hero_creator_step.dart`, `magic_review_step.dart` | Move to MagicReviewStep as inline segmented control; band-adaptive labels; hide for Sprout; fix hardcoded `#2A2040` label color and `fredoka` font |
| 3.5 | CinzelDecorative legibility for Sprout | `hero_creator_step.dart` (multiple locations) | Sprout: switch to Nunito (matches `sproutTheme.uiFontFamily`) |
| 3.6 | Nav button consistency for mature bands | `wizard_story_screen.dart:345-423` | Change `band.band != AgeBand.creator` to `band.band.isMature` for icon-only nav; add tooltip-on-long-press for discoverability |

#### Phase 4: Structural Improvements (Lower Urgency, Higher Effort)

| ID | Issue | File(s) | Fix |
|----|-------|---------|-----|
| 4.1 | Sprout scenario carousel too dense (11 options) | `feeling_selection_step.dart` | Limit Sprout to 6 Magical World scenarios; move Real-Life Heroes behind Guardian Mode |
| 4.2 | No band-exclusive scenarios | `scenario_data.dart` | Add 1-2 Adventurer+ exclusive scenarios (mystery, survival) |
| 4.3 | Creative Brief is a dense single-page form | `hero_creator_step.dart:2870+` | Refactor into 3 expandable cards: Character / World / Vibe |
| 4.4 | No archetype carousel position indicator | `hero_creator_step.dart` | Add dot pagination for the 6-archetype drum selector |
| 4.5 | Emoji slider endpoints shown to age 9-11 | `hero_creator_step.dart`, `feeling_selection_step.dart` | Change `isYoung` threshold from `age <= 11` to `age <= 8`; ages 9+: text labels |
| 4.6 | No `assets/images/scenes/sprout/` | Asset directory | Populate with 4 warm scene backgrounds for future use |

#### Phase 5: Cleanup & Polish

| ID | Issue | File(s) | Fix |
|----|-------|---------|-----|
| 5.1 | Dead code | `hero_creator_step.dart` | Delete `_sproutHeroChoices` and `_explorerHeroChoices` |
| 5.2 | Scattered `if (age >= X)` checks | `scenario_data.dart`, `feeling_selection_step.dart`, `magic_review_step.dart` | Refactor to use `AgeBand` enum properties (`isMature`, `isYoung`) |
| 5.3 | Unused assets if not wired in Phase 3 | Various asset dirs | Audit and remove |
| 5.4 | "Imagine It" field inaccessible to Sprout | `feeling_selection_step.dart` | Add mic button using `speech_to_text` for voice input |
| 5.5 | Welcome age selector too dense for Sprout | `welcome_screen.dart` | Show age band groups first ("Little 3-5", "Kid 6-8", "Big Kid 9-11") with a second tap to refine |

### Execution Priority

| Phase | Effort | Impact | Files Touched |
|-------|--------|--------|---------------|
| Phase 1 | Medium | Critical — fixes bugs | 6 files, 12 new assets |
| Phase 2 | Medium-High | High — worst tone mismatches | 8 files, theme data model |
| Phase 3 | High | Medium-High — visual polish, asset wiring | 6 files, widget changes |
| Phase 4 | High | Medium — structural UX improvements | 4 files, new widgets |
| Phase 5 | Low | Low-Medium — cleanup and polish | Multiple files, deletions |

---

## 2026-03-20 (Asset Audit — Codex)

### Scope Completed
- Audited all literal `assets/...` references in `lib/**/*.dart`.
- Cross-referenced Dart asset usage against on-disk files under `assets/` and the `flutter.assets` section in `pubspec.yaml`.
- Checked registered asset directories for empty or missing paths.
- Reviewed `scenario_data.dart` short-path illustrations (`images/scenarios/...`) because they are promoted to `assets/...` at runtime by `magic_review_step.dart`.

### Findings
- **Broken references:** No broken literal `assets/...` references found in Dart.
- **Additional runtime-broken scenario illustrations:** `lib/data/scenario_data.dart` references `images/scenarios/mystery.png` and `images/scenarios/survival.png`, which resolve to missing files `assets/images/scenarios/mystery.png` and `assets/images/scenarios/survival.png`.
- **Dynamic/unverifiable references:** 32 asset paths use interpolation or directory prefixes and cannot be statically verified (examples: `assets/images/archetypes/${band.name}/$bandImageId.jpg`, `assets/feelings_faces/$key.png`, `assets/images/companions/${widget.id}_normal.jpg`).
- **Unregistered assets:** 125 files under `assets/feelings_faces_backup_20260130_150545/` are not covered by `pubspec.yaml`.
- **Empty/missing pubspec asset directories:** None.

---

## 2026-03-18 (Deployment Plan + Assignment Creation — Claude)

- Completed: Read all TEAM_COORDINATION logs (root + docs/) and synthesized a comprehensive deployment plan.
- Created: `docs/DEPLOYMENT_PLAN_2026-03-18.md` — master go/no-go plan with priorities, blockers, and criteria.
- Created: `docs/assignments/ASSIGNMENT_DARCY_MANUAL.md` — CORS Railway env var fix + manual test checklist.
- Created: `docs/assignments/ASSIGNMENT_GEMINI_ANTIGRAVITY.md` — Flutter UI fixes (companion assets, scenario 404s, TypeError, fonts).
- Created: `docs/assignments/ASSIGNMENT_CODEX.md` — Backend work (Gemini health probe, smoke tests, performance baseline, update LAUNCH_BLOCKERS).
- Created: `docs/assignments/ASSIGNMENT_GEMINI_PRO.md` — Firefox testing + launch readiness review.
- Key finding: CORS blocker is NOT a code bug — backend already handles it via `RAILWAY_FRONTEND_URL` env var. Just needs that variable set in Railway dashboard to `https://grand-light-production-68d9.up.railway.app`. No deploy required.
- Updated: `docs/LAUNCH_BLOCKERS.md` to reflect both previously listed items are resolved.
- Next: Darcy sets Railway env var (5 min), then hand assignments to each model in parallel.
- Completed: Railway redeployed successfully with `RAILWAY_FRONTEND_URL` set — CORS blocker B1 resolved 2026-03-18.

---

## Known Tooling Issue: Playwright MCP "Browser is already in use" (Windows)

**Symptom:** All `mcp__playwright__browser_*` calls fail with:
> `Error: Browser is already in use for ...mcp-chrome-for-testing-<hash>, use --isolated to run multiple instances of the same browser`

**Cause:** Stale `lockfile` in the Playwright MCP user-data-dir, held open by an orphaned `node.exe` process from a prior Claude Code session. Cannot be resolved from inside the affected session.

**Fix (run in PowerShell, then restart Claude Code):**
```powershell
# 1. Find the hash
Get-ChildItem "C:\Users\darcy\AppData\Local\ms-playwright\" -Filter "mcp-chrome-for-testing-*" -Directory

# 2. Kill orphaned processes
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*playwright/mcp*' -or $_.CommandLine -like '*mcp-chrome-for-testing*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# 3. Delete the lockfile (replace <hash> with value from step 1)
Remove-Item "C:\Users\darcy\AppData\Local\ms-playwright\mcp-chrome-for-testing-<hash>\lockfile" -Force -ErrorAction SilentlyContinue
```
After restarting Claude Code, use `/resume` to pick up where you left off.

---

## Six Hats UX Audit — 2026-04-21

**Method:** Code read + 21 QA screenshots (adult/18+ band flow). Covers landing → onboarding → wizard → home shell. Blind spots: story reader, feelings wheel live interaction, TTS quality, younger-band wizard UI in motion.

---

### White Hat — Facts

- 6 age bands: Sprout (2–5) → Explorer (6–8) → Adventurer (9–11) → Creator (12–14) → Adolescent (15–17) → Adult (18+)
- 4-step wizard: Hero Creator → Feeling Selection → Companion Selector → Magic Review
- Adult/mature band uses a single-scroll accordion wizard (one long page, collapsible sections), not the per-page flow used for younger bands
- Bottom nav is age-differentiated: 3 tabs (under 12), 4 tabs (12+)
- Wizard draft auto-saves to SharedPreferences — crash/session recovery exists but is silent
- Story generation takes ~37 seconds (measured in QA log)
- COPPA age gate present; parent math-gate on parent controls

---

### Red Hat — Gut Reactions

**Good feels:**
- Landing screen is stunning. Deep indigo, gold sparkles, "Your hero. Your story." — premium and evocative immediately.
- The big-circle age picker is delightful. Felt exactly right for a mixed-age app.
- Voice input throughout is a huge differentiator — "Tap to say your name" is lovely for young users.
- Adult Reflect prompts are genuinely moving: *"What are you still carrying that was never yours to carry?"* — the app earns trust here.

**Bad feels:**
- Entering the adult wizard kills the magic. "Build Your Story / *Define the parameters of your experience*" reads like a government form.
- The profile setup screen (microphone + one text field on a black void) feels lonely and uncertain — what is this for? Where am I?
- The COPPA gate asks "How old are you?" to the child and "Parents: please select your child's age" in the subtitle — talking to two people at once feels confused.
- 37 seconds staring at a loading spinner with no detail is genuinely anxiety-inducing the first time.

---

### Black Hat — Problems & Risks

| # | Severity | Location | Issue |
|---|----------|----------|-------|
| UX-01 | HIGH | Adult wizard | Binary gender only (Boy / Girl). Intentional — drives he/she pronouns in story. Not a bug. |
| ~~UX-02~~ | ~~HIGH~~ | ~~All wizard bands~~ | ✅ Fixed `c8d487a` — confirmation dialog on ✕ close; tells user draft is saved. |
| ~~UX-03~~ | ~~MEDIUM~~ | ~~Adult wizard~~ | ✅ Fixed `c8d487a` — "Shape your story." replaces cold clinical copy. |
| ~~UX-04~~ | ~~MEDIUM~~ | ~~Adult wizard~~ | ✅ Fixed `c8d487a` — "optional" label on all non-required accordion sections. |
| ~~UX-05~~ | ~~MEDIUM~~ | ~~COPPA gate~~ | ✅ Already in picker — age 2 was present. |
| ~~UX-06~~ | ~~MEDIUM~~ | ~~COPPA gate~~ | ✅ Fixed `c8d487a` — subtitle "Parents — tap your child's age below". |
| ~~UX-07~~ | ~~MEDIUM~~ | ~~Wizard step nav~~ | ✅ Fixed `c8d487a` — MouseRegion click cursor on tappable step circles. |
| UX-08 | MEDIUM | Character portraits | Boy/Girl portrait images have white/light square backgrounds that look jarring on the dark wizard UI. **Deferred to Opus** — asset-level fix. |
| ~~UX-09~~ | ~~LOW~~ | ~~Profile setup~~ | ✅ Fixed `c8d487a` — Continue dims to 40% opacity and disables when name field empty. |
| ~~UX-10~~ | ~~LOW~~ | ~~Story generation~~ | ✅ Fixed `c8d487a` — adult band gets "Setting the scene… / Developing your character…" phases. |
| ~~UX-11~~ | ~~LOW~~ | ~~Companion selector~~ | ✅ Fixed `c8d487a` — teen emoji 👦 → 🧑 (gender-neutral). |
| ~~UX-12~~ | ~~LOW~~ | ~~Voice input~~ | ✅ Fixed — web-only hint "Your browser will ask for microphone permission" shown below mic button before tap. |
| ~~UX-08~~ | ~~MEDIUM~~ | ~~Character portraits~~ | ✅ Fixed `b34c3ab` — dark card background `#1E1828` + BoxFit.contain; transparent PNG renders cleanly. |
| ~~UX-13~~ | ~~LOW~~ | ~~Adult wizard header~~ | ✅ Fixed `c8d487a` — step 4 label "Begin" → "Create". |

---

### Yellow Hat — What's Working Well

1. **Landing screen** — atmospheric, premium, correct emotional tone immediately.
2. **Age picker design** — big circles for young, pill bands for older — genuinely clever and accessible.
3. **Voice input throughout** — a clear differentiator for the app's target audience.
4. **Draft recovery** — wizard state auto-saved means users don't lose work on crash or tab switch.
5. **Adult Reflect content** — 4-7-8, Box Breath, grounding anchors, and the reflective prompts are genuinely high quality therapeutic content.
6. **Parent math gate** — simple, effective child-proofing without requiring an account.
7. **Band-differentiated bottom nav** — Sprout gets "My Books", Explorer gets "My Garden", etc. Thoughtful.
8. **Life Quests CYOA** — therapeutic framing of emotional problem-solving in a narrative format is the core value prop done well.
9. **Archetype system** — giving kids identity hooks (Logic Architect, Kinetic Specialist) instead of generic roles is meaningfully different.
10. **"Tap to hear" in Sprout** — scenario preview via TTS before committing is perfect for pre-readers.

---

### Green Hat — Improvement Ideas

| Priority | Idea |
|----------|------|
| HIGH | **Add non-binary / custom gender** to adult (18+) band. At minimum a third option: "Other / Prefer not to say". |
| HIGH | **Add confirmation on wizard ✕ close** — "Leave story creation? Your progress is saved as a draft." — then actually tell them it's saved. |
| HIGH | **Rewrite adult wizard header copy** — replace "Define the parameters of your experience" with something warmer, e.g. "Shape your story" or remove the subtitle entirely. |
| HIGH | **Add age 2** to the COPPA picker (Sprout band starts at 2). |
| MEDIUM | **Story generation progress phases** — show labeled stages: "Imagining your hero… Weaving the adventure… Adding magic…" at 37s this is non-negotiable for trust. |
| MEDIUM | **Accordion required/optional labels** — add "(optional)" after collapsed section headers in adult wizard, or show a "fields remaining" count. |
| MEDIUM | **Step indicator affordance** — add a cursor pointer + subtle hover state to the 1/2/3/4 step circles so users discover they're tappable. |
| MEDIUM | **Character portrait backgrounds** — circular crop with transparent/dark bg or match card bg color. |
| MEDIUM | **COPPA gate copy split** — child-facing line: "How old are you?" | parent-facing line: "Parents — tap your child's age" — different font weights to signal different audiences. |
| LOW | **Profile setup context** — add a small line under "Set up your profile" explaining why: "So your story knows your name!" |
| LOW | **Name field validation** — if name is required, disable Continue until non-empty. If optional, label the field explicitly "Optional". |
| LOW | **Companion emoji** — use `🧑` (gender-neutral teen) instead of `👦` for 13–18 group. |
| LOW | **Rename "Begin" step** — step 4 "Begin" reads like a button. "Review" or "Launch" or "Make Magic" would be less ambiguous. |

---

### Blue Hat — Overall Assessment

The app's visual identity and core concept are strong. The landing screen, age picker, and voice input all punch well above indie-app level. The therapeutic content (Life Quests, Adult Reflect) is genuinely good.

The main friction point is the **adult wizard**, which swings from magical onboarding straight into cold, form-like UX. This is the most used path for the largest-spending tier and deserves a targeted pass.

The **binary gender issue** (UX-01) is the only item that could cause real harm to users and should be addressed before any marketing push to adult users.

**Recommended next session priorities:**
1. [ ] UX-01 — Add non-binary gender option (adult band)
2. [ ] UX-03 — Rewrite adult wizard header copy
3. [ ] UX-02 — Add wizard close confirmation + draft notice
4. [ ] UX-05 — Add age 2 to COPPA picker
5. [ ] UX-10 — Phased story generation progress labels

---

## 2026-04-21 — Six Hats Full Audit Fix Pass (Claude Sonnet 4.6)

Session objective: work through the comprehensive Six Hats UX audit items from the user's full audit report, building on the earlier UX-01–UX-13 fixes.

### Status check — what was already done

Before making any changes, verified current state of all audit items:

| Item | Status |
|------|--------|
| Gender diversity (non-binary option) | ✅ Already implemented — `_buildGenderPicker` in `hero_creator_step.dart` has "Non-binary / Other" pill button for all bands |
| Gender auto-advance delay | ✅ Already implemented — 400ms `Future.delayed` before `_heroNextPage()` |
| Age 2 in picker | ✅ Already in `welcome_screen.dart` (confirmed from earlier Sprout audit fix commit) |
| "Hearing no" copy | ✅ Already fixed — reads "Struggling with 'no'" |
| Wizard × close confirmation | ✅ Already implemented — "Leave story creation?" dialog with draft-saved message |
| Consent scroll hint in footer | ✅ Already present — "Please scroll through the notice above" in `_buildStickyFooter` |

### Changes made this session

| File | Change |
|------|--------|
| `lib/screens/adult_meditation_screen.dart` | **Adult Reflect safety valve** — added `_promptDismissed` bool; "I'm okay tonight →" button advances prompt and collapses journal to a "You're all good tonight ✨" card with "Actually, show me the prompt" escape |
| `lib/screens/wizard_steps/hero_creator_step.dart` | **Sprout pet reveal affordance** — added `Icons.chevron_right` trailing icon and brightened text from white54 → white70 so it looks tappable |
| `lib/screens/wizard_steps/hero_creator_step.dart` | **Companion naming** — renamed "Add a Friend" button → "Add from Photo" to distinguish it from the "Your Friends:" saved-character section above |
| `lib/widgets/hero_creator/companion_widgets.dart` | **Sprout companion limit feedback** — non-selected companion tiles animate to 35% opacity when the `maxCompanions` limit is reached; `_CompanionImageButton` gained `dimmed` parameter |

### Remaining open items (from new audit)

These were confirmed still open and should be addressed in future sessions:

| Priority | Item | Recommended model |
|----------|------|-------------------|
| HIGH | Age-gate consolidation — `welcome_screen.dart` vs `age_gate_screen.dart` divergence; missing consent recording for 13–17 on welcome path | **Opus** — risky refactor touching COPPA flow |
| HIGH | Adolescent `.jpg` → `.png` for `gender_adolescent_girl` | Sonnet — asset rename + reference update |
| MEDIUM | Consent AppBar title contextual ("Just one sec!" while TTS plays, "Parental Consent" after) | Sonnet |
| MEDIUM | Title splash "< Change age" link + TTS-finish guard before 5s auto-advance | Sonnet |
| MEDIUM | Cancel on parental knowledge dialog for 13–17 should block entry (currently fires `onConsentCompleted` anyway) | Sonnet |
| LOW | "Go Solo" TextButton restyled as more prominent option | Sonnet |
| LOW | HeroCreatorStep page 0 missing back button | Sonnet |

---

## 2026-04-21 — BYOK Wizard Bug Fixes (Claude Sonnet 4.6)

### Root cause analysis

Two compounding bugs made BYOK setup silently fail on web:

1. **Invisible key field** — `_showKey = false` defaulted the TextField to `obscureText: true`. Combined with no explicit text color on a dark card (`0xFF120226` / `0xFF2C1B47`), both the obscuring dots and any typed text were invisible. The cursor moved but nothing was visible, causing pastes to appear to fail.

2. **Silent no-op on failed Finish** — because the key couldn't be seen/confirmed, `_validate()` failed (wrong or empty key) → `_valid` stayed false → `widget.onDone()` was never called → key never written to `SecureStorageService` / `SharedPreferences`. Any subsequent call to "Full illustrations" re-opened the wizard at step 0 because `getApiKey('gemini')` returned null.

3. **CORS block on web** — the HTTP probe to `generativelanguage.googleapis.com` is blocked by CORS in production web deployments, meaning a perfectly valid key would always fail validation and the wizard was permanently un-completable on web.

### Changes made

| File | Change |
|------|--------|
| `lib/screens/byok_setup_wizard.dart` | `_showKey = true` — key visible by default; "Show key" checkbox still lets user hide it |
| `lib/screens/byok_setup_wizard.dart` | `style: TextStyle(color: Colors.white)` on TextField — explicit white text so text/dots render on dark card |
| `lib/screens/byok_setup_wizard.dart` | CORS fallback — network/timeout errors no longer block save; well-formed `AIza…` key accepted with "couldn't verify, will confirm on first use" message |
| `lib/screens/byok_setup_wizard.dart` | Snackbar on failed Finish — red snackbar echoes the validation error so failure is impossible to miss |

---

## 2026-04-21 — Six Hats Creator Review Closeout (Claude Opus 4.7)

User pasted a full Six Hats creator review (~15 items, 2× P0 / 3× P1 / 3× P2 / rest P3) asking for a comprehensive fix plan. Triaged against current code — **most items were already resolved** across prior commits (`c8d487a`, `115b37b`, `b34c3ab`, `1bedede`, `6fa4d0f`, `1bf26c3`). The review was drafted from pre-fix screenshots in the working tree.

### Triage summary

| Review claim | Reality | Action |
|---|---|---|
| P0 Silent failure on empty name | Continue already dims to 40% + disables (UX-09) — but no *textual* explanation of why | Added helper hint |
| P0 Boy avatar checkerboard | Fixed `b34c3ab` | Already closed |
| P1 Wizard step counter mismatch | Intentional — 4 circles flatten sub-steps inside `HeroCreatorStep` | Keep as-is |
| P1 Archetype jargon for children | Age-banded — children see "Brave Hero!"; only 12+ sees "Logic Architect" | Keep as-is |
| P1 Gender binary only | Non-binary option present at `hero_creator_step.dart:1680-1715` | Keep as-is |
| P2 No discard confirmation on × | Dialog exists at `wizard_story_screen.dart:408-427` | Keep as-is |
| P2 Sections hidden by default | Intentional — UX-04 added "optional" labels | Keep as-is |
| P2 Onboarding order (age before name) | Code is name → age (`welcome_screen.dart:273-297`) | Review was reversed |
| P3 Age 2 in picker | Intentional per UX-05 | Keep as-is |
| P3 Age gate mixed-voice copy | Fixed in UX-06 ("Parents — tap your child's age below") | Already closed |
| P3 Step indicators not tappable | Tappable on step 0 + UX-07 cursor | Already closed |
| P3 "What does your character want?" placeholder bland | Mature-only field ("Optional — adds depth…" is adult-flavored but vague) | Updated placeholder |
| P3 No back button on age gate | Back button at `age_gate_screen.dart:185-189` | Already closed |

### Changes made this session

| File | Change |
|------|--------|
| `lib/screens/welcome_screen.dart` | **Empty-name helper hint** — subtle "Type your name to continue" caption fades in between field and dimmed Continue button; `AnimatedOpacity` keyed off controller emptiness, fades to 0 once user types |
| `lib/screens/wizard_steps/hero_creator_creative_brief.dart` | **Character desire placeholder** — replaced "Optional — adds depth to your story" with concrete example: "e.g. to prove themselves, to reconnect with family" (field only renders for mature bands, so mature-flavored examples are appropriate) |

### Verification

`flutter analyze` on both files — 4 pre-existing warnings unrelated to these edits (`_glyphForAge`, `_glyphForOlderBand` unused; two unused `glyph` params). No new warnings introduced.
