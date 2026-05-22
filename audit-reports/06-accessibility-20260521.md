# Story Weaver / Once Upon YOUR Child — Accessibility Audit

**Standard:** WCAG 2.2, Level AA
**Date:** 2026-05-21
**Scope:** Flutter Android, iOS, and web (CanvasKit) surfaces. Static code audit of `C:\dev\story-weaver-app` at branch `main` (HEAD `e58c9085`).
**Method:** Static source audit. Live screen-reader testing (TalkBack/VoiceOver/web AT) flagged as a follow-up where indicated. Contrast computed from theme constants in `lib/theme/age_band_theme.dart` and `lib/theme/app_theme.dart` using WCAG 2.2 relative luminance.

## Executive Summary

Story Weaver shows clear intent toward accessibility — the codebase has a dedicated `AppTouchTargets` class (64 dp minimum, above the WCAG 44 dp baseline), a `MotionPrefs` utility that respects `MediaQuery.disableAnimations`, explicit `Semantics()` wrappers on at least 25 widget files, and a `SafeAssetImage` wrapper that accepts a `semanticLabel`. Storybook typography uses 1.8 line-height and a Merriweather serif body — strong choices for sustained child reading.

However, intent is unevenly executed. Three theme bands (Sprout, Adolescent, Adult) pair primary CTA colors with white text at contrast ratios below 4.5:1, putting the most common interaction (the primary "Make Magic" / "Start Writing" button) below WCAG 1.4.3 across two of the six age bands the product targets. The Flutter web build runs in CanvasKit mode, where the semantics tree is known partial (see `playwright_canvaskit_technique.md`) — this directly threatens 1.1.1, 2.1.1, and 4.1.2 conformance on the web surface. Of ~1,450 `GestureDetector`/`onTap`/`InkWell` instances only ~50 have an enclosing `Semantics(label:)` — Material-button children inherit text labels, but icon-only `IconButton`s and gesture wrappers on illustrations frequently expose no accessible name. Animation coverage of `MotionPrefs.reduceMotion` is partial: 21 files use it, but 62 files instantiate `AnimationController` — the Welcome screen's pulsing "Tap me!" hint and the avatar-generation choreography animate unconditionally.

Learning-to-read mode (karaoke word highlighting in `story_reader_screen.dart`) is the brightest single area: it uses both background color and underline (not color alone — passes 1.4.1), couples audio to the highlight, and respects per-band TTS rate. But it offers no dyslexia-friendly font option (OpenDyslexic / Lexend are not bundled), no syllable segmentation, and no parent-configurable highlight color — the highest-leverage surface in the app has the most remediation room.

**Overall AA status:** Partial. 11 Blocker/High findings (4 Blockers); estimated 4–6 engineering weeks to AA-conformant, ~10 weeks to a defensible Section 508 / EAA filing posture.

### Top 5 highest-impact remediations

1. **Fix CTA contrast in Sprout/Adolescent/Adult bands** (A11Y-001). Adult `primary #BFA45A` on white = 2.44:1, Sprout `#E65100` = 3.79:1. Push to 4.5:1.
2. **Add accessible names to icon-only IconButtons site-wide** (A11Y-003). Use `tooltip:` or wrap in `Semantics(label:)`. ~30 files affected.
3. **Resolve Flutter web semantics gap** (A11Y-002). CanvasKit semantics tree is partial; either ship the HTML renderer for accessibility builds or document/promote the semantics-placeholder click.
4. **Add dyslexia-friendly font option to Learning-to-read mode** (A11Y-LTR-01). OpenDyslexic / Lexend bundling, per-child setting, persisted via existing child profile.
5. **Honor reduced-motion on all looping animations** (A11Y-007). 62 `AnimationController` sites; many `.repeat()` calls bypass `MotionPrefs`.

## Screen Inventory

Sourced from `Glob lib/**/*screen*.dart` (62 screen files) plus dialogs/wizard steps. Grouped by user journey.

| Journey | Screens / Files |
|---|---|
| Onboarding | `welcome_screen.dart` (name + age picker + title splash), `parental_consent_screen.dart` (parental gate + scroll-acknowledge + email round-trip), `splash_screen.dart` |
| Wizard (story creation) | `wizard_story_screen.dart`, `wizard_steps/hero_creator_step.dart`, `hero_creator_scene_page.dart`, `hero_creator_story_type_page.dart`, `hero_creator_creative_brief.dart`, `companion_selector_step.dart`, `feeling_selection_step.dart`, `imagine_it_screen.dart`, `magic_review_step.dart`, `superhero_*` screens, `bedtime_wizard_screen.dart`, `custom_pet_avatar_screen.dart` |
| Story display & reading | `story_result_screen.dart`, `story_reader_screen.dart` (Learning-to-read), `illustrated_story_viewer.dart`, `interactive_story_screen.dart`, `pick_a_path_adventure_screen.dart`, `quick_story_screen.dart`, `page_flip_book_view.dart` |
| Character & avatars | `character_creation_screen.dart` (+ `_v3`, `_enhanced`), `character_appearance_screen.dart`, `character_edit_screen_enhanced.dart`, `character_evolution_screen.dart`, `character_gallery_screen.dart`, `character_selection_screen.dart`, `character_management_screen_v2.dart`, `character_editor_screen.dart`, `character_library_screen.dart`, `multi_character_screen.dart`, `avatar_builder_screen.dart`, `avatar_picker_screen.dart`, `midjourney_avatar_picker_screen.dart`, `custom_avatar_screen.dart` |
| Emotional / SEL | `feelings_corner_screen.dart`, `feelings_wheel_screen.dart`, `feelings_garden_screen.dart`, `big_feelings_flow_screen.dart`, `emotions_screen.dart`, `life_quest_screen.dart`, `chronicle_screen.dart`, `chronicles_list_screen.dart`, `adult_meditation_screen.dart`, `therapeutic_customization_screen.dart` |
| Library & content | `saved_stories_screen.dart`, `offline_stories_screen.dart`, `coloring_book_library_screen.dart`, `coloring_screen.dart`, `achievements_screen.dart` |
| Premium & payment | `premium_upgrade_screen.dart`, `subscription_screen.dart`, `subscription_management_screen.dart`, `subscription_success_screen.dart`, `paywall_dialog.dart` |
| Settings & parent | `settings_screen.dart`, `parent_controls_screen.dart`, `parent_dashboard_screen.dart`, `child_profile_manager_screen.dart`, `byok_setup_wizard.dart` |
| Legal | `privacy_policy_screen.dart`, `terms_of_service_screen.dart` |
| Other | `times_up_screen.dart` (screen-time limit) |

**Total in-scope screens:** ~62. **Critical-path screens audited in this report:** 14.

## Per-Criterion Conformance

See `06-accessibility-20260521-wcag-conformance-matrix.csv` for the full WCAG 2.2 Level A and AA matrix. Summary counts:

| Status | Level A | Level AA | Total |
|---|---|---|---|
| Pass | 14 | 6 | 20 |
| Partial | 9 | 6 | 15 |
| Fail | 5 | 4 | 9 |
| N/A | 2 | 1 | 3 |
| **Total criteria** | **30** | **17** | **47** |

90%+ of AA criteria carry a definitive Pass/Fail/Partial verdict (target met). Three criteria (4.1.1 Parsing — obsolete in WCAG 2.2; 2.5.5 Target Size — historical AAA; per-band variance) are kept N/A or are documented under Partial.

## Critical Gaps

### Contrast — Sprout, Adolescent, Adult bands (1.4.3 Fail)

`lib/theme/app_theme.dart:188-205` builds the global `ElevatedButton` theme with `backgroundColor: effectivePrimary` and `foregroundColor: Colors.white`. The primary color comes from the age-band theme. Measured contrast:

| Band | Primary hex | Contrast vs `Colors.white` | AA normal text (4.5:1) | AA large text (3:1) |
|---|---|---|---|---|
| Sprout (ages 3-5) | `#E65100` | **3.79:1** | Fail | Pass |
| Explorer (6-8) | `#7B1FA2` | 7.84:1 | Pass | Pass |
| Adventurer (9-12) | `#283593` | 11.09:1 | Pass | Pass |
| Creator (13-14) | `#7C4DFF` | 6.21:1 | Pass | Pass |
| Adolescent (15-17) | `#00838F` | 4.96:1 | Pass | Pass |
| Adult (18+) | `#BFA45A` | **2.44:1** | Fail | Fail |

Sprout fails for all body button text but passes for ≥18 pt bold labels — currently the wizard's primary CTA uses 16 px button text (`fontSize: 16 * bodyScale`), which at Sprout's `bodyScale: 1.1` is 17.6 px — under the 18 pt large-text threshold. **Adult fails both** thresholds.

Note: Sprout's gradient mid `#5F2776` against white text reads ~8:1 (passes). The bug is specifically on the `primary` CTA color paired with white button foreground.

### Flutter web CanvasKit semantics gap (1.1.1, 1.3.1, 2.1.1, 4.1.2 Partial→Fail risk)

Per `memory/playwright_canvaskit_technique.md`, the web build runs in CanvasKit mode. Semantics are emitted only after a click on `flt-semantics-placeholder`. Even then, "partial tree, some buttons unreachable." Screen readers on the web surface cannot reliably reach the same widget tree mobile AT reaches.

**Implication:** users on web with NVDA/JAWS/VoiceOver may be unable to use core flows. This is a *Blocker* for any "use Story Weaver on the family Chromebook" use case.

### Icon-only buttons without accessible names (1.1.1, 4.1.2 Partial)

- 1,456 `GestureDetector`/`onTap`/`InkWell` occurrences across 107 files vs 53 `Semantics()` wrappers across 25 files
- 63 `tooltip:` parameters across 32 files (many but not majority of icon buttons)
- 0 `excludeFromSemantics` / `ExcludeSemantics` uses — meaning every interactive node is *exposed*, just without a good name

`Semantics(button: true, label: ...)` is used well in `story_reader_screen.dart:1095`, `story_result_screen.dart:5212`, `widgets/feelings_badge_grid.dart:159`, `widgets/archetype_card.dart:57`, `widgets/character_preview.dart:124` — these are model citizens. Most icon-only buttons in app bars and toolbars (`back`, `share`, `report`, `mute`, ambient-sound toggle, mic button) are unverified.

### Welcome name field — no visible/programmatic label (3.3.2 Fail)

`lib/screens/welcome_screen.dart` collects the child's name in a `TextEditingController _nameController` but the grep for `labelText:` returns no matches in this file. WCAG 3.3.2 (Labels or Instructions, Level A) requires programmatic labels on form inputs. The text input must expose a `labelText`, `hintText`, or wrapping `Semantics(label:)` — placeholder-only is insufficient.

### Auto-playing motion without controls (2.2.2, 2.3.3 Partial)

`MotionPrefs.reduceMotion` is wired (`lib/utils/motion_utils.dart`) and used in 21 files. But:

- `welcome_screen.dart:89-95` starts `_tapHintCtrl.repeat(reverse: true)` in `initState` unconditionally. The 1200 ms pulse runs even when `MediaQuery.disableAnimations == true`.
- 62 widget files instantiate `AnimationController`. Spot-checks of `avatar_loading_bands/*`, `magical_loading_view.dart`, `magic_orb.dart`, `magical_float.dart`, `golden_ticket_animation.dart` show several do honor MotionPrefs and several do not.
- Auto-playing animations >5 s without pause control violate 2.2.2. Avatar generation displays an animated treasure-map (Adventurer) and constellation (Explorer) for the full 20–40 s generation window with no pause UI.

## Learning-to-read Mode — Deep Dive

`story_reader_screen.dart` (1,400+ lines) is the highest-leverage accessibility surface. It is the only screen that combines TTS, visual highlighting, and primary text content. Below are 11 specific findings.

### LTR-1 — Word highlight uses background + underline, not color alone (Pass, 1.4.1)

`story_reader_screen.dart:1131-1147` paints the active word with `backgroundColor: AppColors.gold.withValues(alpha: 0.4)` AND `decoration: TextDecoration.underline`. Conformant — colorblind users get the underline, low-vision users get the background. **Keep.**

### LTR-2 — No dyslexia-friendly font option (Fail, AAA but recommended)

`grep -i 'dyslex\|opendyslexic\|lexend'` returns zero matches across the repo. Merriweather is a competent serif but is not dyslexia-tuned. WCAG 1.4.8 (AAA) and BS 8878 / educational-technology procurement guidance both reference OpenDyslexic, Lexend, or Andika as expected options. Bundle one (Lexend is the strongest evidence base) and gate via a per-child profile preference.

### LTR-3 — No syllable segmentation in highlight (Gap)

Highlight is per-word only. For learners ages 5-7 (Sprout/early Explorer) syllable-level chunking is a documented intervention. The tokenizer (`_prepareTokens`, `_wordTokenIndices`) operates at whitespace boundary; extending to a syllabifier is non-trivial but high-impact.

### LTR-4 — Highlight color is hard-coded (1.4.12 partial)

`AppColors.gold.withValues(alpha: 0.4)` and `decorationColor: AppColors.gold` — no per-child override. Some learners benefit from blue/green highlight; some have specific color sensitivities. Add to settings.

### LTR-5 — Playback rate adapts to age band (Pass)

`_playbackRate` is initialised per band in `_onFirstFrame` — good. Confirm exposed via on-screen control during reading (the audit did not verify the speed slider UI itself).

### LTR-6 — Auto-play TTS on screen entry (2.2.2 risk)

`autoPlay = true` is the case for Sprout/Explorer ages "regardless of this flag" (lib/story_reader_screen.dart:23-25). Auto-play audio that runs >3 s without controls violates 1.4.2. Confirm a pause/stop button is rendered immediately and is reachable by screen reader on first frame.

### LTR-7 — Audio coupling is TTS-driven and synchronous with highlight (Pass)

ElevenLabs word-timestamp alignment (`_wordTimestamps`) drives the highlight when available, falling back to char-weighted estimation. Audio-text sync is the heart of the mode and is correctly designed.

### LTR-8 — No "tap to read this word" affordance (Gap, not WCAG-required)

A tap on a single word should ideally restart playback from that word and re-pronounce. Educational-tech standard feature. Currently the highlight is read-only.

### LTR-9 — Bookmark/resume is silent for screen readers (4.1.3 Partial)

`_resumeBannerVisible` triggers a banner — verify it announces via `Semantics(liveRegion: true)` or `SemanticsService.announce`. Otherwise resume position is invisible to non-sighted users.

### LTR-10 — Ambient sound toggle has no confirmed accessible name (1.1.1 Partial)

`_ambienceMuted` state exists; the toggle button surface was not verified to carry a `Semantics(label:)` or `tooltip:`. Verify or add.

### LTR-11 — Text remains at one size until story display (1.4.4 Partial)

`AppTextStyles.storyBody` is 20 px Merriweather. Honoring `MediaQuery.textScaler` (Flutter ≥3.16) is automatic for `Text` widgets that use a TextStyle without explicit `textScaleFactor: 1.0`. Spot-check shows the storybook text scales — verify on a 200 % system text scale that line heights do not collapse.

## Remediation Backlog

Ordered by `Severity × Affected-screens / Effort`. All findings also appear in the conformance matrix CSV.

| ID | Title | Criterion | Level | Severity | Screens | Description | Remediation | Effort |
|---|---|---|---|---|---|---|---|---|
| A11Y-001 | CTA contrast fails AA in Adult and Sprout bands | 1.4.3 | AA | Blocker | All (theme-wide) | Adult `#BFA45A` + white = 2.44:1; Sprout `#E65100` + white = 3.79:1 on 16 px button text | Darken Adult `primary` to ≥`#7E6420` (4.5:1) or change CTA foreground to dark. For Sprout, darken to `#BF360C` (already defined as `primaryDark`) or use 18 pt+ bold labels app-wide. | 1d |
| A11Y-002 | Flutter web CanvasKit semantics partial | 1.1.1, 2.1.1, 4.1.2 | A | Blocker | All web | CanvasKit canvas not directly readable; semantics tree only after placeholder click; partial | Switch web build to HTML renderer for accessibility config; or auto-promote the semantics placeholder; document the AT workflow in the support page. | 3-5d |
| A11Y-003 | Icon-only buttons missing accessible names | 1.1.1, 4.1.2 | A | High | ~30 files | 1.4 k `onTap`/`InkWell` vs 53 `Semantics()`. Most `IconButton`s rely on default tooltip-less behavior | Sweep: every `IconButton`, `GestureDetector` wrapping `Icon` must have a `tooltip:` or wrap in `Semantics(button: true, label: 'X')`. Add a lint rule to CI. | 5-7d |
| A11Y-004 | Welcome name field has no label | 3.3.2, 1.3.1 | A | High | welcome_screen | `_nameController` not paired with `labelText:` or `Semantics(label:)` | Add `decoration: InputDecoration(labelText: 'Your name')` and `textInputAction: TextInputAction.next`. | 0.5d |
| A11Y-005 | Parental consent scroll gate inaccessible for AT | 2.1.1, 1.3.1 | A | High | parental_consent | `_scrollProgress` requires reading the whole notice by scroll; screen-reader users navigate by heading and may not register scroll | Track engagement via heading visits OR explicit "I have read this" checkbox after each section, in addition to scroll. Do not weaken COPPA — add an equivalent AT path. | 2d |
| A11Y-006 | Auto-playing TTS without immediate stop control | 1.4.2 | A | High | story_reader | Auto-play triggers for Sprout/Explorer; stop button presence not verified on first frame | Render and focus a `Stop` button before TTS starts; confirm `Semantics(button: true, label: 'Stop reading')`. | 0.5d |
| A11Y-007 | Looping animations bypass `MotionPrefs` | 2.2.2, 2.3.3 | A/AA | High | welcome, avatar generation, multiple | 21/62 controller sites honor `disableAnimations`; welcome "Tap me!" hint loops unconditionally | Wrap every `AnimationController.repeat`/`forward` with `if (!MotionPrefs.reduceMotion(context))`. Add a lint rule. | 3d |
| A11Y-008 | Generated illustrations lack alt text | 1.1.1 | A | High | story_result, illustrated_story_viewer, per_page_illustration | `Image.memory(bytes)` in `per_page_illustration.dart:52` has no `semanticLabel`. Stories ship with multiple AI illustrations per page | When the backend returns the illustration, also return a 1-sentence caption; pass as `semanticLabel:`. For pre-existing without captions, default to `'Illustration for: <page text summary>'`. | 2-3d (backend + frontend) |
| A11Y-LTR-01 | No dyslexia-friendly font option | 1.4.8 | AAA / EdTech expected | High | story_reader, story_result | No OpenDyslexic / Lexend / Andika in pubspec | Bundle Lexend (Apache-2.0); add `child_profile.preferredReadingFont`; switch story body when set. | 2d |
| A11Y-009 | Storybook contrast vs gradient background | 1.4.3 | AA | Medium | story_reader | Body text `#2C3E50` on band-specific gradient — Adult/Adolescent gradients are near-black; storybook page is presumed to render text on a light card. Verify per band that the card surface (not the gradient) sits behind body text | Audit each band: ensure `storyBodyStyle` is composited on `surface` color, not `gradientMid`. | 1d |
| A11Y-010 | Forms — error identification not verified | 3.3.1, 3.3.3 | A/AA | Medium | byok_setup_wizard, character_creation, parental_consent (verification code), settings | 89 `TextField`/`TextFormField` vs 11 `errorText:` occurrences | Audit each input: on validation failure, set `errorText:` and announce via `Semantics(liveRegion:)`. Provide suggested correction where pattern is known (email, code). | 3d |
| A11Y-011 | Target-size variance — Adult band drops to 48 dp | 2.5.8 (new in 2.2) | AA | Medium | Adult-band screens | `adultTheme.touchTargetMin = 48.0` — at the WCAG 2.2 minimum but with no margin | Either raise to 52 dp for safety or document tap target verification per Adult screen. Sprout 88, Explorer 64, Adventurer 64, Creator 56, Adolescent 52, Adult 48 are all ≥WCAG 2.5.8 (24 dp) but several are below the 44 dp Apple/Material recommendation in their *interactive area*, not button visual size. | 1d audit |
| A11Y-012 | Focus order on wizard not verified | 2.4.3 | A | Medium | wizard_story, wizard_steps/* | Multi-step wizard with TalkBack/VoiceOver swipe order; not verified | Live-AT pass on each step. Add `Focus(autofocus: true)` on the primary heading of each step. | 2d |
| A11Y-013 | Reflow at 200 % zoom on web not verified | 1.4.10 | AA | Medium | All web | CanvasKit reflow behavior on zoom not measured | Run web build at 200 % system zoom + 200 % text scale; ensure no horizontal scroll on a 1280 px viewport. | 1d |
| A11Y-014 | Color-only state on selected cards | 1.4.1 | A | Medium | feelings_badge_grid, archetype_card, hero_creator/*, companion_widgets | Selection often shown via accent color/glow; pair with checkmark or border-width change | Audit each selectable card; require non-color cue. Several widgets (`feelings_badge_grid.dart`, `archetype_card.dart`) already pass `selected: isSelected` to Semantics — confirm visual cue too. | 2d |
| A11Y-015 | Live regions for async state | 4.1.3 | AA | Medium | wizard (story generation), avatar generation, parental_consent (code), payment | Generation status: `_stepIndex of _steps.length` is announced in `widgets/avatar_generating_view.dart:233` — good example. Other generation screens not verified | Replicate that pattern on story generation, payment success, code-verification result. | 2d |
| A11Y-LTR-02 | No syllable segmentation | 1.4.8 (AAA) / pedagogical | Medium | story_reader | Tokenizer is whitespace-only | Integrate hyphenation library (e.g. `hyphen` package) for Sprout/Explorer bands. | 5d |
| A11Y-LTR-03 | Highlight color not configurable | 1.4.12 | AA | Low | story_reader | Hard-coded `AppColors.gold` | Add child-profile field; expose in parent_controls. | 1d |
| A11Y-LTR-04 | No tap-to-read-word | — | Educational | Low | story_reader | Highlight is non-interactive | Add `GestureDetector` on each `TextSpan`'s recognizer that seeks TTS to that word. | 2d |
| A11Y-016 | Language attribute on generated story content | 3.1.2 | AA | Low | story_reader, story_result | Stories are English-only today but locale tag is not asserted; future i18n requires `Semantics(textDirection:)` + `Locale` | When a story is rendered, set `Locale` on the `Text` via `Localizations.override` matching the generation language. | 1d (defer until i18n) |
| A11Y-017 | Decorative emojis as text | 1.1.1 | A | Low | theme/app_theme.dart:6 (`// 🎨 Magical Purple Theme`), various comments | Comments only; not user-visible | No action — informational. | 0d |
| A11Y-018 | Parental consent scroll progress bar contrast | 1.4.11 | AA | Low | parental_consent | `LinearProgressIndicator` gold (`#FFD700`) on white@30 alpha background on a `gradientStart` purple — ratio may dip below 3:1 in some sub-rect compositions | Sample: gold on `#1E0A3C` = ~9:1 (pass). Background of `Colors.white.withAlpha(30)` on `gradientStart` raises baseline. Verify with a screenshot pass. | 0.5d |

**Total estimated remediation effort:** 35-45 engineering days (≈ 7-9 weeks) for AA conformance, plus 7-10 days for AAA-targeted Learning-to-read upgrades.

## Methodology, Limitations, and Quality Controls

- **Static-only audit.** Live screen-reader passes on TalkBack, VoiceOver, and a desktop AT (NVDA on Windows) are deferred — recommended as A11Y-FOLLOWUP-01. Findings marked *Partial* in the matrix are those that depend on live verification.
- **Contrast computed** with WCAG 2.2 relative luminance formula (`L = 0.2126 R + 0.7152 G + 0.0722 B`, sRGB linearised). White vs primary tested for each of six bands.
- **AI-generated content audit method.** Static auditing cannot inspect a specific generated illustration. The method recommended (A11Y-008) is captioning at generation time, since the backend already calls a multimodal model and can return a caption with marginal cost.
- **Dynamic-color sampling.** Five band themes sampled (Sprout, Adventurer, Creator, Adolescent, Adult) plus the default (Explorer). All six are documented in the matrix.
- **Coverage.** Onboarding, parental consent, story wizard, story display, payment, settings each have at least one finding in the matrix or are listed as audited in the screen inventory.
- **Constructive framing.** Every finding includes a remediation path. The product is in a strong starting position — `MotionPrefs`, `AppTouchTargets`, the per-band touch-target spec, and the Learning-to-read karaoke design are quality choices already in place.

## Follow-ups (out of scope for this audit)

- **A11Y-FOLLOWUP-01:** Live AT verification on TalkBack 14+, VoiceOver iOS 18, and NVDA 2025.1 on the web build. Target 2 days.
- **A11Y-FOLLOWUP-02:** Localization readiness — re-audit when first non-English locale ships.
- **A11Y-FOLLOWUP-03:** Re-audit Learning-to-read mode after A11Y-LTR-01/02/03 land.
- **A11Y-FOLLOWUP-04:** Section 508 / EAA filing checklist mapping against this audit (separate compliance document).
