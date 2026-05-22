# Accessibility Remediation Plan — WCAG 2.2 AA

**Source audit:** `06-accessibility-20260521.md`
**Date drafted:** 2026-05-21
**Decisions locked:** 2026-05-22 (see "Decisions Locked" section below)
**Target:** WCAG 2.2 Level AA conformance, plus AAA-level upgrades to Learning-to-read mode.
**Estimated total effort:** ~8 engineering weeks (AA), +1–2 weeks (LTR upgrades), +1 week (self-run verification).
**Suggested track:** one engineer, self-run AT verification (no consultant in initial scope).

## Decisions Locked (2026-05-22)

1. **Web a11y:** Start with a ~1-day investigation spike to characterise what NVDA/VoiceOver actually reach on the current Flutter build before committing to any architecture. No dual-build commitment yet. (Phase 3 rewritten.)
2. **Sprout CTA contrast:** Keep the bright `#E65100`; make Sprout CTAs ≥18 pt bold so the 3:1 large-text threshold applies. A test asserts Sprout button text stays large+bold. (Phase 1.1.)
3. **Lexend:** Default story font for Sprout and Explorer bands everywhere; Merriweather stays default for Adventurer/Creator/Adolescent/Adult; per-child override in both directions. (Phase 6.1.)
4. **Parental consent (A11Y-005):** Removed from this plan. Folded into the pre-launch consent rework (the workstream that re-enables the COPPA email round-trip), so the consent flow is reviewed once.
5. **Phase 7 verification:** Self-run using the audit checklist and recipe. A paid third-party accessibility verification is deferred until a specific grant application requires an external attestation.

## Strategy

Group fixes by *risk class* and *workflow*, not by criterion. Three sweeps (icon labels, motion guards, selection cues) account for ~60% of effort but only ~20% of files — bundle them. Theme/CTA changes ship first (single-file diff, highest user impact). Web CanvasKit and Learning-to-read are stand-alone tracks. Backend captioning is the only finding requiring server changes.

**Sequencing rule:** before any sweep, land its lint/analyzer rule so regressions are blocked in CI. Sweeps that ship without a guardrail will rot.

## Phase Overview

| Phase | Focus | Calendar | Eng days | Ships behind flag? |
|---|---|---|---|---|
| 0 | Foundation: lint rules, AT harness, GitHub project | Week 1 | 3 | No |
| 1 | Quick blockers (theme contrast, name label, TTS stop) | Week 1–2 | 3 | No (theme can ship straight) |
| 2 | Icon-label sweep + Motion sweep + Selection-cue sweep | Week 2–4 | 13 | No, but per-PR |
| 3 | Web a11y: investigation spike, then scoped follow-up | Week 4–5 | 1 + (1–4 TBD) | Decided by spike |
| 4 | Forms / error identification sweep | Week 5 | 3 | No |
| 5 | Generated illustration captions (backend + frontend) | Week 5–7 | 3 | Yes (backend feature flag) |
| 6 | Learning-to-read upgrades (Lexend, settings, syllables) | Week 6–9 | 10 | Lexend per-band default; syllables behind child pref |
| 7 | Self-run AT verification, reflow, focus-order, sign-off | Week 9–10 | 5 | No |
| **Total** | | **~8–9 weeks** | **~41–44 days** | |

Note: A11Y-005 (parental-consent scroll gate) was removed from Phase 4 — it is folded into the pre-launch consent rework.

## Phase 0 — Foundation (3 days)

Land before any sweep PRs. Without these, fixes regress immediately.

### 0.1 Analyzer / lint rules

File: `analysis_options.yaml`

```yaml
analyzer:
  errors:
    use_full_hex_values_for_flutter_colors: warning
linter:
  rules:
    - use_decorated_box  # encourages explicit semantics on raw GestureDetector
```

Custom lint via `custom_lint` package — three rules:

1. `no_unlabelled_icon_button` — flag `IconButton(icon: Icon(...))` without `tooltip:`.
2. `no_unguarded_repeat` — flag `AnimationController.repeat(` outside an `if (!MotionPrefs.reduceMotion(context))` guard.
3. `no_unlabelled_form_field` — flag `TextField`/`TextFormField` without `decoration.labelText` or wrapping `Semantics(label:)`.

Acceptance: CI fails on new violations; existing violations enumerated as TODOs.

### 0.2 AT verification harness

- Document a TalkBack/VoiceOver test recipe: install steps, swipe order, what to record.
- Wire `flutter_test`'s `SemanticsTester` into the existing test suite for golden semantics-tree tests on five critical screens (welcome, parental_consent, wizard_story, story_reader, story_result).
- For web: install `@axe-core/cli` and add a workflow that runs `axe http://localhost:8080` against the local web build.

### 0.3 GitHub project / tracking

- Create labels `a11y-blocker`, `a11y-high`, `a11y-medium`, `a11y-low`.
- File one issue per A11Y-### ID from the audit. Link the issue body to `06-accessibility-20260521.md`.
- Add an `a11y` milestone with target date Week 10.

## Phase 1 — Quick Blockers (3 days)

Three single-file fixes that ship the biggest user-visible improvements per engineering hour.

### 1.1 A11Y-001 — CTA contrast fix — DONE 2026-05-22

Two distinct fixes — Adult is a color change, Sprout is a type-size change (decision #2). Both landed; regression tests in `test/accessibility_test.dart` (group "A11Y-001 — age band CTA contrast").

**Adult band** — `lib/theme/age_band_theme.dart` (applied):

```dart
// primary darkened so white button text reaches WCAG AA — measured 5.2:1
primary: Color(0xFF806A38),       // was #BFA45A (2.44:1)
primaryLight: Color(0xFFBFA45A),  // brand amber-gold preserved here
primaryDark: Color(0xFF5E4F2A),
```

**Sprout band** — keep `primary: #E65100`. Instead, guarantee Sprout CTA text qualifies as WCAG "large text" (≥18 pt, or ≥14 pt bold) so the 3:1 threshold applies and the existing 3.79:1 passes.

`lib/theme/app_theme.dart` builds the global `ElevatedButton` text style at `fontSize: 16 * band.bodyScale, fontWeight: FontWeight.w600`. For Sprout (`bodyScale: 1.1`) that is 17.6 px w600 — just under the 18 pt large-text line. Bump it:

```dart
// In AppTheme.light(), elevatedButtonTheme textStyle:
textStyle: TextStyle(
  // Sprout: force >=18pt bold so CTA text is WCAG "large text" (3:1 applies).
  fontSize: band.band == AgeBand.sprout
      ? 18.0
      : 16 * band.bodyScale,
  fontWeight: band.band == AgeBand.sprout
      ? FontWeight.bold
      : FontWeight.w600,
),
```

**Acceptance:**
- Unit test computes contrast from `effectivePrimary` vs `Colors.white` for every band; Adult ≥ 4.5:1.
- Unit/golden test asserts the Sprout `ElevatedButton` resolved text style is `fontSize >= 18 && fontWeight >= FontWeight.bold` — this is the guardrail that keeps the large-text compliance argument from silently breaking.
- Update any visual snapshots referencing the old Adult color.

### 1.2 A11Y-004 — Welcome name field label (0.5 day)

File: `lib/screens/welcome_screen.dart`

Find the `TextField(controller: _nameController, ...)` and add:

```dart
TextField(
  controller: _nameController,
  decoration: const InputDecoration(
    labelText: 'Your name',
    hintText: 'What should we call you?',
  ),
  textInputAction: TextInputAction.next,
  autofillHints: const [AutofillHints.givenName],
  // ...existing
)
```

**Acceptance:** TalkBack swipe over the field announces "Your name, edit box."

### 1.3 A11Y-006 — TTS stop control on auto-play (0.5 day)

File: `lib/story_reader_screen.dart`

Confirm a Stop / Pause button is in the widget tree at first frame, has `Semantics(button: true, label: 'Stop reading')`, and is the first focusable control. If absent, add ahead of any `_tts.speak()` call in `_onFirstFrame`.

**Acceptance:** open story with `autoPlay: true` on Sprout → screen reader's first announcement includes "Stop reading, button."

### 1.4 A11Y-LTR-03 — Highlight color setting (1 day)

Files:
- `lib/services/child_profile_service.dart` — add `preferredHighlightColor: Color`.
- `lib/screens/parent_controls_screen.dart` — add color picker.
- `lib/story_reader_screen.dart:1131-1147` — replace `AppColors.gold` with `profile.preferredHighlightColor`.

**Acceptance:** changing the color in parent controls persists and renders next time the story opens.

## Phase 2 — Three Sweeps (13 days)

Each sweep ships as a series of small PRs (one folder at a time) so review stays focused.

### 2.1 A11Y-003 — Icon-button label sweep (5–7 days)

**Scope:** ~30 files touching `IconButton`, `InkWell(child: Icon(...))`, `GestureDetector(child: Icon(...))`.

**Pattern A** (preferred — IconButton):
```dart
IconButton(
  icon: const Icon(Icons.share),
  tooltip: 'Share story',
  onPressed: _share,
)
```

**Pattern B** (when tooltip not desired, e.g. always-visible toolbar):
```dart
Semantics(
  button: true,
  label: 'Share story',
  child: GestureDetector(onTap: _share, child: const Icon(Icons.share)),
)
```

**Targets (in priority order):**
1. `story_reader_screen.dart` — playback toolbar
2. `story_result_screen.dart` — share/report/save/rate
3. `wizard_steps/*` — back/next on every step
4. `parent_controls_screen.dart` — every settings toggle
5. `settings_screen.dart`
6. Remaining widget toolbars

PR strategy: one PR per file group above. Each PR carries golden semantics tests for that screen.

**Acceptance:** custom lint `no_unlabelled_icon_button` passes; semantics-tree golden tests find a non-empty `label` for every interactive node.

### 2.2 A11Y-007 — MotionPrefs sweep (3 days)

**Scope:** 62 `AnimationController` instantiation sites; today 21 honor `MotionPrefs.reduceMotion`.

**Standard pattern:**
```dart
@override
void initState() {
  super.initState();
  _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (MotionPrefs.reduceMotion(context)) {
    _ctrl.stop();
    _ctrl.value = 1.0;   // settle to end state, not zero, so visual is intact
  } else if (!_ctrl.isAnimating) {
    _ctrl.repeat(reverse: true);
  }
}
```

**Targets:**
1. `welcome_screen.dart:89-95` — pulsing "Tap me!" hint
2. `widgets/magical_loading_view.dart`, `magic_orb.dart`, `magical_float.dart`, `golden_ticket_animation.dart`
3. `widgets/avatar_loading_bands/*` — all five band-specific loaders
4. `widgets/star_burst_celebration.dart` — celebration on consent etc.
5. Remaining `AnimationController` users not yet using `MotionPrefs`

**Acceptance:** custom lint `no_unguarded_repeat` passes; manual test: enable "Reduce motion" in OS, open each band's loader, confirm static end-state.

### 2.3 A11Y-014 — Selection-cue sweep (2 days)

Every selectable card must signal selection with at least *two* of: border, checkmark, color, scale change. Color alone is insufficient.

**Scope:** `widgets/feelings_badge_grid.dart`, `archetype_card.dart`, `hero_creator/*`, `companion_widgets.dart`, `pet_card.dart`, `avatar_gallery_selector.dart`.

**Pattern:**
```dart
Semantics(
  button: true,
  selected: isSelected,                                  // already in code
  label: '$name${isSelected ? ', selected' : ''}',
  child: Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: isSelected ? band.accent : Colors.transparent,
        width: isSelected ? 3 : 1,                        // non-color cue
      ),
    ),
    child: Stack(children: [
      child,
      if (isSelected) Positioned(top: 8, right: 8, child: Icon(Icons.check_circle)),
    ]),
  ),
)
```

**Acceptance:** with system "Differentiate without color" enabled, every selectable card visibly differs when selected.

### 2.4 Sweep deliverables checklist

- [ ] Lint rules from Phase 0 active and green
- [ ] Each sweep behind its own PR series
- [ ] Each PR includes at least one semantics golden test
- [ ] Sweeps merged in order: 2.1 → 2.2 → 2.3 (so the icon-label-tree assumptions hold for the rest)

## Phase 3 — Web a11y: Investigation Spike, then Scoped Follow-up (1 day spike + 1–4 days TBD)

Decision #1: do not commit to an architecture up front. The Flutter web a11y story has moved fast, and the standalone HTML renderer has been progressively deprecated — assuming it exists on the current build is unsafe. Characterise reality first.

### 3.1 Investigation spike (1 day)

Produce a short findings memo: `audit-reports/06-accessibility-2026MMDD-web-spike.md`.

Establish:
1. **Flutter version and available renderers.** `flutter --version`; check whether `--web-renderer html` is still accepted or whether the build is CanvasKit/skwasm-only.
2. **What AT actually reaches today.** Build the web app, run NVDA + Chrome and VoiceOver + Safari against `welcome`, `parental_consent`, `wizard_story` step 1, `story_reader`. Click the `flt-semantics-placeholder` to enable semantics first (see memory `playwright_canvaskit_technique.md`). Record: which controls are announced, which are silent, whether focus order works, whether the name field is reachable.
3. **Auto-promote feasibility.** Test whether enabling semantics on first user gesture (rather than requiring the placeholder click) is configurable or needs a shim.
4. **Web traffic share.** Pull analytics — what fraction of sessions are web vs iOS/Android. This sizes how much the web gap actually matters.

### 3.2 Decision gate

The spike memo ends with a recommendation picking one of:
- **Coverage already acceptable** → just fill in `Semantics()` wrappers as part of the Phase 2 sweeps; no extra web work. (0 extra days.)
- **Fixable with a semantics shim** → auto-promote semantics + targeted wrappers. (~1–2 days.)
- **HTML renderer still available and gap is severe + web traffic material** → dual-build at `/a/`. (~4 days; reapply the CSP gstatic fix per memory `flutter_web_csp_gstatic.md`.)
- **Gap severe but web traffic immaterial** → document iOS/Android as the supported AT surface, add a "best on the mobile app" note for screen-reader users, log as accepted limitation. (~0.5 day.)

Bring the recommendation back before starting the follow-up work.

### 3.3 Reflow at 200% (A11Y-013)

Independent of the renderer decision. Add a Playwright test that opens each critical screen with `--force-device-scale-factor=2` at a 1280 px viewport and asserts no horizontal scroll. Run against whatever web build the spike settles on.

## Phase 4 — Forms Sweep (3 days)

A11Y-005 (parental-consent scroll gate) is **not** in this phase — per decision #4 it is folded into the pre-launch consent rework. The consent screen's own form inputs (email, verification code) are also handled there, so they are excluded from the 4.1 scope below to avoid touching that screen twice.

### 4.1 A11Y-010 — Error identification

**Scope:** every `TextFormField` and `TextField` with validation, excluding `parental_consent_screen.dart`. Audit list:
- `byok_setup_wizard.dart` — API key inputs
- `character_creation_screen*.dart` — character name
- `settings_screen.dart` — settings inputs

**Pattern:**
```dart
TextFormField(
  decoration: InputDecoration(
    labelText: 'Email address',
    errorText: _emailError,
    helperText: 'For COPPA-verified consent',
  ),
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (value) {
    if (!ParentalConsentService.isValidEmail(value ?? '')) {
      return 'Please enter a valid email like name@example.com';
    }
    return null;
  },
)
```

Couple with a `SemanticsService.announce(_emailError ?? '', TextDirection.ltr)` when an error first appears so screen readers catch it.

### 4.2 A11Y-005 — handed off to the pre-launch consent rework

Not done here. The recommended approach is carried forward as a requirement for that workstream:

> Add an AT-accessible alternative to the scroll-to-bottom gate — three section-acknowledgement checkboxes ("I have read: Data Collection / Sharing / Rights"), tracked as `consent_method: 'sections_acknowledged'` with per-section timestamps. Checkboxes are keyboard/screen-reader operable and are arguably stronger evidence of review than a scroll position. Do not weaken the parental-gate multiplication challenge (the COPPA §312.5 mechanism). Get the consent-flow wording reviewed when the email round-trip is re-enabled.

## Phase 5 — Generated Illustration Captions (3 days)

### 5.1 Backend (A11Y-008)

In the illustration-generation worker (Celery task that calls OpenRouter Gemini Image):

```python
# After image generation, ask the same model for a 1-sentence caption.
caption = call_caption_model(image_bytes, page_text)
# Persist alongside the image bytes
illustration.caption = caption
illustration.save()
```

Cost: ~$0.002 / image (text generation is cheap vs the image itself per `openrouter_image_pricing.md`).

API change: `/illustration` endpoint already returns image bytes — add `caption: str` field.

### 5.2 Frontend (A11Y-008)

File: `lib/widgets/per_page_illustration.dart:52`

```dart
Image.memory(
  bytes,
  fit: BoxFit.cover,
  gaplessPlayback: true,
  semanticLabel: state.caption ?? 'Story illustration',
)
```

Plus update `PageIllustrationState` to carry `caption`.

**Acceptance:** TalkBack swipe across a story page reads the page text then the illustration caption.

## Phase 6 — Learning-to-Read Upgrades (10 days)

The highest-leverage user-facing improvement.

### 6.1 A11Y-LTR-01 — Lexend font (2 days)

Decision #3: Lexend is the **default** story font for Sprout and Explorer bands everywhere; Merriweather stays default for Adventurer/Creator/Adolescent/Adult. A per-child profile preference can override in either direction.

- `lib/theme/age_band_theme.dart`:
  - Add `'Lexend'` cases to `_googleFontCreator` and `_googleFontTextThemeCreator` (Lexend is OFL/Apache-compatible; `GoogleFonts.lexend`).
  - `sproutTheme` and `explorerTheme`: change `storyFontFamily` from `'Merriweather'` to `'Lexend'`.
  - `adventurerTheme`, `creatorTheme`, `adolescentTheme`, `adultTheme`: keep `storyFontFamily: 'Merriweather'`.
- `lib/services/child_profile_service.dart`: add `preferredReadingFont: String?` — `null` means "use the band default", `'lexend'` / `'merriweather'` force a choice.
- `lib/story_reader_screen.dart` + `story_result_screen.dart`: resolve the effective story font as `profile.preferredReadingFont ?? band.storyFontFamily`; build the storybook text style from that.
- `lib/screens/parent_controls_screen.dart`: add a three-way control — "Reading font: Default / Lexend (easier for many readers) / Classic serif" — with an explainer that Lexend is research-designed to support reading fluency and can help readers with dyslexia.
- Bundle Lexend for offline use so cached/offline stories render correctly.

**Acceptance:**
- Fresh Sprout or Explorer profile renders stories in Lexend with no setting changed.
- Fresh Adventurer+ profile renders stories in Merriweather.
- Overriding `preferredReadingFont` in parent controls flips the font on next story open and persists across launches; offline stories also respect it.

### 6.2 A11Y-LTR-02 — Syllable segmentation (5 days)

- Add `hyphen` Dart package (or vendor a small syllabifier — Knuth-Liang patterns for en-US).
- In `_prepareTokens`, after whitespace tokenisation, run each token through the syllabifier; produce a parallel `_syllableTokenIndices` map.
- Add a child-profile setting `highlightGranularity: 'word' | 'syllable'` defaulted to `word`. Show syllable mode only for Sprout/Explorer.
- Render each syllable as a `TextSpan` so the highlight can shift across syllables; keep current word-level highlight as the union.

**Acceptance:** on Sprout band with syllable mode on, TTS pace and visual highlight track sub-word chunks. No layout shift compared to word mode.

### 6.3 A11Y-LTR-04 — Tap-to-read-word (2 days)

In `story_reader_screen.dart` build the `TextSpan` with a `TapGestureRecognizer` that:
1. Stops current playback
2. Seeks to that word's timestamp (from `_wordTimestamps`)
3. Resumes playback

Add `Semantics(label: word + ', tap to read aloud')` on each word.

**Acceptance:** TalkBack double-tap on any word re-pronounces it.

### 6.4 A11Y-LTR-05 — Live region for bookmark/resume (1 day)

Wrap the resume banner reveal in `Semantics(liveRegion: true)` and announce via `SemanticsService.announce('Resuming from where you left off', TextDirection.ltr)` on show.

## Phase 7 — Verification & Sign-off (5 days)

### 7.1 Self-run AT pass

Decision #5: run this yourself against the audit checklist; no consultant in initial scope.

- TalkBack (Android 14+) on a physical or emulated device: walk the critical journey once per band.
- VoiceOver (iOS 18) on iPhone or simulator: same walk.
- NVDA 2025.x + Chrome on whatever web build the Phase 3 spike settled on: same walk.
- Use the screen-by-screen checklist in `06-accessibility-20260521.md` as the script — each Partial-status criterion in the conformance matrix is a specific thing to confirm.
- Each pass produces a screen recording archived to `audit-reports/06-accessibility-20260521-at-recordings/`.
- Log anything the audit did not predict as a new A11Y-### finding; the 2-day buffer in this phase absorbs follow-up fixes.
- A paid third-party verification is deferred until a grant application requires an external attestation — at that point this recording archive plus the conformance matrix is the handoff package.

### 7.2 Reflow + zoom (A11Y-013)

Browser at 200% zoom + system text scale 200%; viewport 320 CSS px wide. Run on welcome, parental_consent, wizard_story (each step), story_reader, story_result, parent_controls. No horizontal scroll allowed except in code blocks.

### 7.3 Focus order (A11Y-012)

For each step of the wizard, sweep TalkBack through. The order must match visual top-to-bottom, left-to-right. Add `Focus(autofocus: true)` to the primary heading per step where focus jumps incorrectly.

### 7.4 Re-run conformance matrix

Re-score `06-accessibility-20260521-wcag-conformance-matrix.csv`. Target: 0 Fail, ≤3 Partial after Phase 7. Any remaining Partial must have a documented compensating-control note.

### 7.5 Compliance artifact

Produce `audit-reports/06-accessibility-2026MMDD-conformance-statement.md` — a public-facing WCAG 2.2 AA conformance statement suitable for the website's accessibility page and for grant applications.

## Dependency Graph

```
0.1 lint rules ──┬──> 2.1 icon sweep
                 ├──> 2.2 motion sweep
                 └──> 4.1 forms sweep

0.2 AT harness ──> 7.1 live AT pass

1.1 contrast ──> (independent)
1.2 name label ──> (independent)
1.3 TTS stop ──> 6.3 tap-to-read

2.1 icon sweep ──┐
2.2 motion sweep ─┼──> 7.1 live AT pass
2.3 selection ───┤
4.1 forms ───────┤
3.x web ─────────┘

5.1 backend caption ──> 5.2 frontend caption

6.1 Lexend ──> 6.2 syllables (shares profile pref plumbing)
```

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Phase 3 spike concludes a dual-build is needed, doubling deploy complexity | Low | Medium | Spike sizes web traffic first; dual-build only chosen if traffic is material; document nginx route in runbook if so |
| Backend caption costs balloon | Low | Low | Already ~$0.002/image, cap at one caption per illustration, no retries |
| Lexend bundle increases initial paint | Low | Medium | Lazy-load; only when profile pref is on |
| AT pass uncovers issues not in this plan | Medium | Medium | Reserve 2 days in Phase 7 for follow-up fixes |
| Sweep PRs introduce regressions | Medium | High | Golden semantics tests in each PR; lint rules prevent silent regressions |
| Phase 4.2 parental-consent change needs legal review | High | Medium | Open the legal-review ticket on Day 1 of Phase 4 in parallel |
| Sprout large-text compliance silently breaks if a CTA ships below 18pt bold | Medium | Medium | Golden test asserts Sprout ElevatedButton text stays >=18pt bold (Phase 1.1); custom lint can extend to flag raw Sprout buttons |

## Rollout Strategy

- **Phase 1** (contrast, label, TTS stop): straight-to-main, no flag. These are bug fixes.
- **Phase 2** (sweeps): straight-to-main per PR; each PR small enough to revert.
- **Phase 3** (web): rollout mechanism depends on the spike outcome — either no change (sweeps cover it), a semantics shim, a documented limitation, or a dual-build. Decided at the section 3.2 gate.
- **Phase 5** (captions): backend behind `ILLUSTRATION_CAPTIONS_ENABLED` env var on Railway; flip per environment. Frontend can call old API safely if the field is missing (`state.caption ?? 'Story illustration'`).
- **Phase 6** (Learning-to-read): Lexend is a band-default change (Sprout/Explorer) — it ships on for those bands with no per-profile action, and `preferredReadingFont` lets any child override either way. Existing Sprout/Explorer profiles get Lexend on next launch. Syllable mode stays a child-profile preference, default off, surfaced only for Sprout/Explorer.

## Open Questions for the User

All five planning questions were resolved on 2026-05-22 — see "Decisions Locked" near the top of this document. The only decision still pending is internal to Phase 3: the renderer/coverage choice produced by the investigation spike (section 3.2), which returns for review before any web follow-up work begins.

## Tracking

- Master ticket: file as `A11Y-EPIC-2026Q2` linking all sub-issues.
- Weekly check-in: Friday 30 min, review the phase tracker.
- Burndown: 45 eng days / 10 weeks = ~5 days / week. Realistic if this is the primary thread for one engineer.
