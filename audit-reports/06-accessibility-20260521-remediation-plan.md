# Accessibility Remediation Plan — WCAG 2.2 AA

**Source audit:** `06-accessibility-20260521.md`
**Date drafted:** 2026-05-21
**Target:** WCAG 2.2 Level AA conformance, plus AAA-level upgrades to Learning-to-read mode.
**Estimated total effort:** 7–9 engineering weeks (AA), +1–2 weeks (LTR upgrades), +1 week (verification & sign-off).
**Suggested track:** one engineer with ~20% of an a11y-consultant time-share for live AT testing.

## Strategy

Group fixes by *risk class* and *workflow*, not by criterion. Three sweeps (icon labels, motion guards, selection cues) account for ~60% of effort but only ~20% of files — bundle them. Theme/CTA changes ship first (single-file diff, highest user impact). Web CanvasKit and Learning-to-read are stand-alone tracks. Backend captioning is the only finding requiring server changes.

**Sequencing rule:** before any sweep, land its lint/analyzer rule so regressions are blocked in CI. Sweeps that ship without a guardrail will rot.

## Phase Overview

| Phase | Focus | Calendar | Eng days | Ships behind flag? |
|---|---|---|---|---|
| 0 | Foundation: lint rules, AT harness, GitHub project | Week 1 | 3 | No |
| 1 | Quick blockers (theme contrast, name label, TTS stop) | Week 1–2 | 3 | No (theme can ship straight) |
| 2 | Icon-label sweep + Motion sweep + Selection-cue sweep | Week 2–4 | 13 | No, but per-PR |
| 3 | Web CanvasKit a11y resolution | Week 4–5 | 5 | Yes (renderer choice) |
| 4 | Forms / error identification sweep | Week 5–6 | 3 | No |
| 5 | Generated illustration captions (backend + frontend) | Week 5–7 | 3 | Yes (backend feature flag) |
| 6 | Learning-to-read upgrades (Lexend, settings, syllables) | Week 6–9 | 10 | Yes (child profile pref) |
| 7 | Live AT verification, reflow, focus-order, sign-off | Week 9–10 | 5 | No |
| **Total** | | **~10 weeks** | **~45 days** | |

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

### 1.1 A11Y-001 — CTA contrast fix (1 day)

File: `lib/theme/age_band_theme.dart`

```dart
// Adult — replace primary so white text reaches 4.5:1
primary: Color(0xFF8C7240),       // was #BFA45A (2.44:1)
primaryLight: Color(0xFFBFA45A),  // promote old primary to light
primaryDark: Color(0xFF6E5832),

// Sprout — same idea or change foreground globally for Sprout
primary: Color(0xFFBF360C),       // was #E65100 (3.79:1) — passes at 5.6:1
primaryLight: Color(0xFFE65100),
primaryDark: Color(0xFF8B2A05),
```

Verify after change with a quick contrast calculator. Update visual snapshots if any reference the old colors. No API changes.

**Acceptance:** measured contrast ≥ 4.5:1 in `light()` ElevatedButton theme for every band; verify via unit test that computes contrast from `effectivePrimary` vs `Colors.white`.

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

## Phase 3 — Web CanvasKit Resolution (5 days)

The hardest finding because the right answer is architectural.

### 3.1 Decision: choose renderer strategy

Three viable options:

| Option | Pros | Cons | Effort |
|---|---|---|---|
| A. Ship HTML renderer for web | Real DOM, screen-readers work natively, axe-core results actionable | Slower paint, font-rendering differences, ~30% bundle size hit | 2d |
| B. Stay on CanvasKit + auto-promote semantics-placeholder | One codebase | Still partial — known buttons unreachable | 1d |
| C. Dual-build: HTML for accessibility config, CanvasKit default | Best of both | Two build pipelines, two deploy paths in nginx | 4d |

**Recommendation:** Option C, gated on a `?renderer=html` query parameter for now, defaulting to CanvasKit. If usage data shows web a11y matters at scale, flip the default.

### 3.2 Implementation

- Build config: `flutter build web --web-renderer html` produces a second output to `build/web-html/`.
- Nginx route: serve `/a/*` from the HTML build, `/*` from CanvasKit.
- Update `web/index.html` to detect `?renderer=html` and redirect to `/a/`.
- Document the AT user path in support content: "if you use a screen reader, please use [link]/a/".
- Reapply the CSP `connect-src` gstatic fix (see memory note `flutter_web_csp_gstatic.md`) to the HTML build's `index.html`.

### 3.3 Reflow at 200% (A11Y-013)

Once HTML renderer is on `/a/`, run:
```bash
playwright test --grep "reflow 200%"
```
Add a test that opens each critical screen at `deviceScaleFactor: 1, viewport: 640x800` with `--force-prefers-reduced-motion` and `--force-device-scale-factor=2`. Assert no horizontal scroll.

**Acceptance:** NVDA + Chrome on `/a/welcome` announces "Your name, edit box"; can complete wizard step 1 with keyboard only.

## Phase 4 — Forms Sweep (3 days)

### 4.1 A11Y-010 — Error identification

**Scope:** every `TextFormField` and `TextField` with validation. Audit list:
- `byok_setup_wizard.dart` — API key inputs
- `character_creation_screen*.dart` — character name
- `parental_consent_screen.dart` — email + verification code
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

### 4.2 A11Y-005 — Parental consent scroll gate AT path

Add a non-scroll path that satisfies CMP-6 for AT users:
- Render 3 section checkboxes ("I have read: Data Collection / Sharing / Rights"). All three checked + the existing `_consentGiven` checkbox = consent given.
- Track via `consent_method: 'sections_acknowledged_at'`. Still records that all three were touched (timestamps + UA hint), so it has no less rigor than scroll.

Coordinate with legal — this is a change to consent flow and may need wording review. Do not weaken the parental-gate multiplication challenge (that is the COPPA §312.5 mechanism, not the readability gate).

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

- `pubspec.yaml`: add `google_fonts: ^6.x` is already present; switch to `GoogleFonts.lexend(...)` and bundle the font for offline (Lexend is Apache-2.0).
- `lib/theme/age_band_theme.dart`: add `dyslexiaFriendlyStoryFontFamily: 'Lexend'` per band.
- `lib/services/child_profile_service.dart`: add `preferredReadingFont: String? // null = default, 'lexend' = on`.
- `lib/story_reader_screen.dart` + `story_result_screen.dart`: read profile pref; build storybook text style with Lexend when set.
- Parent controls: toggle with explainer "Some readers find Lexend easier — especially helpful for dyslexia."

**Acceptance:** toggle in parent controls → story renders Lexend immediately on next open; persists across launches.

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

### 7.1 Live AT pass

- TalkBack (Android 14+) on a physical Pixel: walk the critical journey once per band.
- VoiceOver (iOS 18) on iPhone: same walk.
- NVDA 2025.x + Chrome on `/a/` HTML build: same walk.
- Each pass produces a recording archived to `audit-reports/06-accessibility-20260521-at-recordings/`.

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
| Phase 3 Option C doubles deploy complexity | Medium | Medium | Decide before starting; document nginx route in runbook |
| Backend caption costs balloon | Low | Low | Already ~$0.002/image, cap at one caption per illustration, no retries |
| Lexend bundle increases initial paint | Low | Medium | Lazy-load; only when profile pref is on |
| AT pass uncovers issues not in this plan | Medium | Medium | Reserve 2 days in Phase 7 for follow-up fixes |
| Sweep PRs introduce regressions | Medium | High | Golden semantics tests in each PR; lint rules prevent silent regressions |
| Phase 4.2 parental-consent change needs legal review | High | Medium | Open the legal-review ticket on Day 1 of Phase 4 in parallel |
| Sprout band darker primary loses "playful" feel | Medium | Low | Show two options to design before merging; consider keeping #E65100 but switching to dark text |

## Rollout Strategy

- **Phase 1** (contrast, label, TTS stop): straight-to-main, no flag. These are bug fixes.
- **Phase 2** (sweeps): straight-to-main per PR; each PR small enough to revert.
- **Phase 3** (web): the HTML renderer build behind `/a/` path is itself the rollout mechanism. No flag needed.
- **Phase 5** (captions): backend behind `ILLUSTRATION_CAPTIONS_ENABLED` env var on Railway; flip per environment. Frontend can call old API safely if the field is missing (`state.caption ?? 'Story illustration'`).
- **Phase 6** (Learning-to-read): per-child-profile preference. Off by default for existing profiles; surfaced on parent-controls page with an explainer. No global flag needed since opt-in per child.

## Open Questions for the User

1. **Web a11y posture:** is `/a/` HTML-renderer path the right call, or do you want to push to single-codebase CanvasKit + hope Flutter improves the semantics tree?
2. **Sprout primary CTA color:** keep `#E65100` and switch foreground to dark for that one band, or darken to `#BF360C`? Affects the "playful sunset" feel.
3. **Lexend default:** opt-in only, or on by default for Sprout/Explorer where dyslexia prevalence is highest in the demographic?
4. **Parental consent scroll gate:** is legal/CMP-6 review willing to accept section checkboxes as an equivalent acknowledgement path? Required for Phase 4.2.
5. **AT consultant time-share:** does Anthropic have an a11y consultant retainer, or should we budget for a contractor on Phase 7?

## Tracking

- Master ticket: file as `A11Y-EPIC-2026Q2` linking all sub-issues.
- Weekly check-in: Friday 30 min, review the phase tracker.
- Burndown: 45 eng days / 10 weeks = ~5 days / week. Realistic if this is the primary thread for one engineer.
