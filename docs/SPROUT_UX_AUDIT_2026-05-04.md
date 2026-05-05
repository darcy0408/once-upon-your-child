# Sprout UX Audit — 2026-05-04

## Summary

Sprout (ages 2-5) has a clearly articulated design intent in `lib/theme/age_band_theme.dart` (touch target min **88px**, headingScale **1.15**, bodyScale **1.1**, large rounded corners, Nunito font, simple action-oriented labels). The wizard flow itself (Hero Creator pages 1-6, scene picker, story-type picker, GO! launch) honours the spirit of this intent — the picture-driven scene tiles, oversized GO! button, big mic primary input, and TTS narration are all Sprout-grade. The auto-advance behaviour (taps confirm and progress) and the Sprout-only "ask a grown-up" pet pattern are particularly well-judged.

The recurring problems are **inconsistency** rather than absent intent: many widgets ignore the band's `touchTargetMin`/`bodyScale` and hard-code values calibrated for Explorer (12-13px subtitles, 64-pixel hits, EdgeInsets sized for older fingers). The other recurring theme is **mature-vocabulary leakage**: top-level scaffolding (AppBar, popup menu, age picker labels, Chronicles dialog, Library banner, character library "My Characters") was built for the Explorer-and-up surface and isn't getting the Sprout treatment. The result is a wizard that feels Sprout-grade in the middle but exposes pre-readers to "Achievement Journey", "Subscription", "Chronicles", "Settings", typed text fields, and a free-text genre dialog whenever they leave the wizard happy path.

## Findings

### S-001 — Achievements card uses 18sp/14sp body text on home screen
**Where:** `lib/main_story.dart:1158-1213`
**Issue:** `_buildAchievementsOverviewCard` is rendered for every band including Sprout. Title text is `fontSize: 18`, subtitle is the default ~14sp, "% badges unlocked" footer is `Colors.green.shade900.withValues(alpha:0.7)` body — all below the 18sp Sprout body floor. Card also reads "Achievement Journey", which a 3-year-old won't decode.
**Impact:** Medium
**Recommendation:** For Sprout, replace card with a single big "Your Stars" badge (just the unlock count and 1 emoji) at 28sp+, or hide the achievements overview entirely on the Sprout home.
**Effort:** S (single conditional in `_buildAchievementsOverviewCard`)

### S-002 — Story Pack tiles render 100×110 with 11sp labels
**Where:** `lib/main_story.dart:1056-1117`
**Issue:** SEL Story Pack horizontal cards are hard-coded `width: 100`, `height: 110`, with title `fontSize: 11`. For Sprout band the design intent calls for 88px+ touch targets and 18sp body text. The "Big Feelings" rename for Sprout (line 1100-1102) helps but the size doesn't.
**Impact:** High
**Recommendation:** When `band.band == AgeBand.sprout`, render 140×140 tiles with 16sp+ bold labels and crop the list to 3 packs (Big Feelings, Family, Standing Up). Keep emoji at 36sp.
**Effort:** S

### S-003 — Home AppBar exposes "Story Creator" + Subscription badge + "more_vert" menu
**Where:** `lib/main_story.dart:518-722`
**Issue:** Sprout users see an AppBar title "Story Creator" (concept), a tier badge ("Premium"/"Family"), an "X left today" pill, an upgrade-star, and a 7-item PopupMenuButton with labels "Achievements", "Offline Stories", "Coloring Book", "My Stories", "My Chronicles", "Group Story", "Settings". A 4-year-old can't read most of these and shouldn't be navigating to Settings.
**Impact:** High
**Recommendation:** For Sprout, replace AppBar with a centered "Stories" mascot logo + a single big parent-gate gear (icon-only, dim) on the right. Move power-user features behind the parent gate. The bottom nav already gives Sprout 3 tabs — that's enough.
**Effort:** M (conditional AppBar render)

### S-004 — Character portrait card "Adventure" CTA is 11sp inside a 130×~200 card
**Where:** `lib/main_story.dart:1380-1467`
**Issue:** `_CharacterPortraitCard` is hard-coded `width: 130`, name text `fontSize: 14`, age line `fontSize: 11`, CTA badge `fontSize: 11`. The whole card is the band-agnostic Explorer purple gradient (line 1387). Sprout sees the same 130×200 horizontal-scrolling list.
**Impact:** High
**Recommendation:** When Sprout, render full-width character cards (one per row, ~340×140), avatar 96px, name 22sp, no age/role line (3yo doesn't read it), CTA replaced with an oversized golden play arrow icon (no text).
**Effort:** M

### S-005 — Quick-play orb (28×28) hidden inside character card
**Where:** `lib/main_story.dart:1471-1486`
**Issue:** The lightning-bolt quick-play overlay is `width: 28, height: 28`. That's 60% below the 44px iOS minimum, ~31% of the Sprout 88px target. A toddler's finger covers the whole card; precise selection of an in-card overlay is unrealistic.
**Impact:** High
**Recommendation:** Remove the quick-play overlay for Sprout (single tap on the card already routes to wizard which auto-fills), or at minimum scale to 56×56 for `band == sprout`.
**Effort:** S

### S-006 — Welcome teaser CTA "Let's start!" sits at bottom of viewport on small screens
**Where:** `lib/screens/welcome_screen.dart:373-440`
**Issue:** The teaser stacks Icon (72) + 24 gap + title (34sp, ~46px tall) + 16 + tagline (22sp two-line, ~58px) + 40 + button. On a 368×640 viewport with SafeArea, the "Let's start!" button sits very near the fold. The whole screen is a tap target (`GestureDetector(onTap:_dismissTeaser)` at line 376), but the explicit button is the affordance children look for.
**Impact:** Low
**Recommendation:** Pin the "Let's start!" button to the bottom 25% of the viewport (Align(Alignment.bottomCenter)), or shorten the icon+title spacing for ≤640 height.
**Effort:** S

### S-007 — Welcome screen forces typed name even for Sprout
**Where:** `lib/screens/welcome_screen.dart:629-720`
**Issue:** After the teaser, Sprout (ages 3-5) sees the same name flow as everyone else. The mic button (88×88, line 591-614) is the primary, but the TextField below it is the *only path forward when speech isn't enabled* and the "Type your name to continue" hint at line 668 is unreadable to a 3yo. Auto-focusing the field (line 638) raises the keyboard. A Sprout user with mic disabled is completely blocked.
**Impact:** Medium
**Recommendation:** When the recorded age maps to Sprout AND speech is unavailable, show a "Hand the phone to a grown-up" panel with an icon button labelled "Grown-up — type my name". Don't autofocus.
**Effort:** S

### S-008 — Hero name-step uses 20sp typed label, 18sp hint — under Sprout body floor
**Where:** `lib/screens/wizard_steps/hero_creator_step.dart:1820-1865`
**Issue:** Sprout-specific name input renders the typed-name TextField at `fontSize: 20` (line 1830) and hint at `fontSize: 18` (line 1842). Surrounding scaffold is good (88px mic, 22sp button label), but if a parent types the toddler's name they see it at 20sp. Should match the Sprout title scale (28sp+).
**Impact:** Low
**Recommendation:** Bump typed-name fontSize to 24, hint to 20, with FontWeight.w800.
**Effort:** S

### S-009 — Gender picker tiles fixed at 140×180 — half-width on landscape, ignore band
**Where:** `lib/screens/wizard_steps/hero_creator_step.dart:1695-1719`
**Issue:** Hard-coded `width: 140, height: 180` for both gender buttons regardless of band. On a 368×640 device, 2×140 + spacing(32) = 312px which fits, but Sprout intent is "as big as possible". Also no third "Either/Both" option so a child whose gender isn't binary has no path forward.
**Impact:** Medium
**Recommendation:** For Sprout, use `LayoutBuilder` to size each tile at `(maxWidth - 32) / 2` (≈168px on 368px viewport). Add a small "skip" or "Both!" option, or rename "Boy/Girl" to "Like a boy/Like a girl/Both!" for less binary feel.
**Effort:** S

### S-010 — Archetype card title overlay 13sp inside 2×2 grid of small images
**Where:** `lib/screens/wizard_steps/hero_creator_step.dart:1916-2015`
**Issue:** Sprout uses a 2×2 GridView with `childAspectRatio: 1.4` (line 1924) and an overlay text capsule with `fontSize: isSprout ? 13 : 12` (line 1983). On a 368×640 phone, each card is ~165×118 — fine size — but 13sp bold-on-dark-overlay is below the Sprout 18sp body floor and the overlay only covers the bottom strip of the card.
**Impact:** Medium
**Recommendation:** Bump Sprout label to 18sp bold, increase overlay capsule padding to `vertical: 6`, and consider 1×4 vertical list (one tall card per row) so each archetype gets full image area + readable name. The wiggle on unselected cards (line 2001) is good — keep it.
**Effort:** S

### S-011 — Companion grid `CompanionImageGrid` inherits non-Sprout sizing
**Where:** `lib/screens/wizard_steps/hero_creator_step.dart:1178-1185` + `lib/widgets/hero_creator/companion_widgets.dart:387,606,712,725`
**Issue:** `CompanionImageGrid` and orb sizes use `(band.touchTargetMin / 64.0 * 100)` formulas (companion_widgets.dart:387, 606) which yield ~138 for Sprout — that part scales. But the labels under companion orbs are hard-coded `fontSize: 11` (lines 712, 725, 819) and chip labels are 13-14sp (lines 807, 819). Sprout names need to be 16sp+ to be legible alongside the picture.
**Impact:** Medium
**Recommendation:** Pass `band.body(16)` as the label size into the orb/chip labels in `companion_widgets.dart` instead of literals.
**Effort:** S

### S-012 — "Big Feelings" feelings quest modal close button is 22sp icon only
**Where:** `lib/widgets/feelings_quest_modal.dart:84-101`
**Issue:** Close icon `Icon(Icons.close, color: Colors.white60, size: 22)` inside a 48px column (line 84). For Sprout the iOS minimum 44px is met but the icon itself at 22 + low-contrast white60 is hard to spot. There is no "back to home" affordance — only close. Title "How do you feel?" at 22sp (line 116) is fine.
**Impact:** Low
**Recommendation:** For Sprout, use a 36sp solid-white close icon inside a 64×64 tappable.
**Effort:** S

### S-013 — Story-type "Listen & Learn" card at full-width 18sp — good, but page has no progressive disclosure
**Where:** `lib/screens/wizard_steps/hero_creator_story_type_page.dart:378-422`
**Issue:** The Sprout-only `_buildSproutModeCard` renders three big cards (full-width, 22sp label, 14sp description, 44sp emoji). Cards themselves are well-sized. Concern: "Story Quest", "Rhyme Time", "Listen & Learn" arranged vertically push the PressableArrowButton off the fold on a 368×640 phone — the last card + arrow + hint require scrolling. Also the description on Listen & Learn says "Easy words to say along!" which is fine but "Story Quest" / "Rhyme Time" are still concept names a 3yo doesn't decode without the icon.
**Impact:** Medium
**Recommendation:** Reduce to 2 visible Sprout cards by default ("Story" + "Songs"), with "Listen & Learn" behind a small "More?" disclosure. OR shrink each card to `vertical: 14` padding and 36sp emoji so all three fit above the fold.
**Effort:** S

### S-014 — Wish/extra-prompt input is hidden for Sprout — good, but Explorer's prompt grid leaks back when band fallback fires
**Where:** `lib/screens/wizard_steps/hero_creator_story_type_page.dart:596-599`
**Issue:** Sprout correctly skips both `_buildWishPromptButtons` and `_buildWishTextInput`. Confirmed correct. (Mentioned for completeness; no fix.) However, if `Theme.of(context).extension<AgeBandThemeData>()` returns null (the `?? explorerTheme` fallback at line 331), Sprout users see the explorer prompt grid. Defensive check is good but worth verifying band hydration race in `wizard_story_screen.dart`.
**Impact:** Low
**Recommendation:** Read band from `_wizardData.characterAge` directly in this widget rather than the ThemeExtension when characterAge < 6, eliminating fallback risk.
**Effort:** S

### S-015 — Magical loading view min container width 280px, message panel 12-13sp
**Where:** `lib/widgets/magical_loading_view.dart:201, 644-651`
**Issue:** `panelWidth` clamp `(280.0, 460.0)` is fine, but the rotating phase message is `bodyMedium` (~16sp) which is on the edge for Sprout, and the 4-step progress dots have labels at `fontSize: 9` (line 645). Toddler can't read "Entering your world / Finding your hero / Writing the story / Almost ready!" at 9sp. Sprout-specific loading content (lines 706-895) wisely replaces the loom with the bouncing companion + 5-star countdown — that part is excellent. But the shared bottom panel (status text, phase message, step dots, sparkle counter) renders for Sprout too.
**Impact:** Medium
**Recommendation:** For `widget.isSproutBand`, hide the 4-step progress wrap (line 608-658) entirely — the 5-star constellation already serves the same purpose. Bump status text to 24sp+ and remove the rotating phase messages (a Sprout doesn't need 11 flavors).
**Effort:** S

### S-016 — Loading view "Cancel" button is plain TextButton at default size
**Where:** `lib/widgets/magical_loading_view.dart:693-699`
**Issue:** The cancel TextButton uses default Material sizing (~36px touch target). A frustrated 4-year-old who wants to back out has only this small text-only "Cancel". No icon, no Sprout language.
**Impact:** Low
**Recommendation:** For Sprout, replace with a 64×64 round button labeled "🛑 Stop" or hide entirely (Sprout loads are short and they can wait through the star game).
**Effort:** S

### S-017 — GO! button is 120px tall and 52sp — perfect — but recap 18-22sp scrolls off small screens
**Where:** `lib/screens/wizard_steps/magic_review_step.dart:849-898, 919-974`
**Issue:** The GO! button is excellent (120px height, 52sp). The Sprout recap card above it (lines 919-974) uses 18sp/20sp text and shows up to 3 rows ("I am X / Going to Y / With Z"). Combined with the BreathingAvatar (160×160, line 808), the "Ready to go?" header (32sp, line 786), and required SafeArea, the button is below the fold on most 368×640 phones — content is `Expanded(SingleChildScrollView)` so it scrolls, but a toddler doesn't scroll deliberately.
**Impact:** Medium
**Recommendation:** Pin GO! to the bottom 30% of viewport (already in a `Padding`), and shrink the recap to a single-row "🦸 I am Darcy" pill at 22sp, omitting scenario/buddy details (the avatar + companion image already convey this visually).
**Effort:** S

### S-018 — Generation error widget says "Uh oh! Something went wiggly" at 22sp — good — but "Try Again" is the only path
**Where:** `lib/screens/wizard_steps/magic_review_step.dart:2548-2614`
**Issue:** Sprout error UI is well-styled (22sp, friendly emoji, big retry button). However retry is the *only* action. If the failure is persistent (auth lost, 503 backend), the child loops forever. No "back to home" or "tell a grown-up" branch.
**Impact:** Medium
**Recommendation:** Below the "Try Again" button add a smaller "🏠 Go home" TextButton that pops the wizard, plus a "Show grown-up" link that displays the underlying error in a parent-gated dialog.
**Effort:** S

### S-019 — Chronicles list dialog uses TextField + Genre dropdown — Sprout cannot type
**Where:** `lib/screens/chronicles_list_screen.dart:265-337`
**Issue:** `_NewChronicleDialog` requires text input (line 305-309) and a dropdown of "Fantasy / Sci-Fi / Mystery / Adventure / Magic" (line 278-284). For Sprout (age ≤5), even though the screen header is correctly relabelled "Our Stories 📚" (line 36) and `_emptyState` says "No stories yet! Start a new one! 🌟" (line 44), the actual creation flow demands typing — which a 4yo can't do.
**Impact:** High
**Recommendation:** When `widget.character.age <= 5`, skip the dialog entirely on the "Start a new story!" tap and route directly to `WizardStoryScreen(initialCharacter: character)`. The character is already chosen; the wizard supplies the rest.
**Effort:** S

### S-020 — Chronicles screen title falls back to "Chronicles" word for >10
**Where:** `lib/screens/chronicles_list_screen.dart:34-40`
**Issue:** Confirmed Sprout-correct title `Our Stories 📚` for ≤5. Good. Note: subtitle on each chronicle card includes "${chapterCount} chapter • ${genre}" (line 224) which surfaces "Fantasy/Sci-Fi" labels back to a Sprout reading the saved-stories list. (Sprout-only `_savedStories` block at lines 184-198 avoids this; but if a parent created a chronicle with the dialog, the chronicle row at lines 213-251 will show.)
**Impact:** Low
**Recommendation:** For Sprout, suppress the genre/chapter-count subtitle on chronicle cards.
**Effort:** S

### S-021 — Top wizard nav has "Heroes / Bedtime / Big Feelings" 10sp labels
**Where:** `lib/screens/wizard_story_screen.dart:716-751`
**Issue:** `_LabeledNavButton` icons are 22sp, labels are `fontSize: 10` (line 742). Even for the youngest band the labels are below the 18sp Sprout floor. The icon-with-tiny-label pattern is already a step toward kid-friendliness over a tooltip but the label is unreadable.
**Impact:** Medium
**Recommendation:** Bump label to `fontSize: 12` minimum for explorer, `fontSize: 14` for sprout (with FontWeight.bold). Increase tap target padding to `horizontal: 10, vertical: 8` so total hit zone exceeds 60px wide.
**Effort:** S

### S-022 — Bottom nav icons scale (good) but labels clamp at 14sp max
**Where:** `lib/widgets/app_bottom_navigation.dart:31-32, 130-137`
**Issue:** `labelFontSize = (12 * bodyScale).clamp(10.0, 14.0)`. Sprout bodyScale 1.1 → 13.2, clamped to 13.2 (under 14 ceiling). For Sprout the floor should be 16sp. Icon size scales correctly to 33sp.
**Impact:** Medium
**Recommendation:** Change clamp to `(10.0, 18.0)` so Sprout's 1.1 scale lands at 13.2 — still below ideal. Better: add explicit Sprout branch `if (band == sprout) labelFontSize = 16`.
**Effort:** S

### S-023 — Imagine It / Make One Up Sprout panel mic 80×80, idea chips 26sp — solid
**Where:** `lib/screens/wizard_steps/hero_creator_scene_page.dart:203-437`
**Issue:** This is *exemplary* Sprout UX — single big mic, three big idea chips with emoji, green confirmation banner, grown-up text-field fallback. No fix needed. Reference implementation for other panels.
**Impact:** Low (positive)
**Recommendation:** Use as the pattern for fixing S-007 and the Chronicles dialog (S-019).
**Effort:** N/A

### S-024 — "Welcome back!" page 0 lands on Sprout with 14sp Fredoka subtitle
**Where:** `lib/screens/wizard_steps/hero_creator_step.dart:707-734`
**Issue:** Page 0 ("Welcome back!" returning-user picker) shows `Tap your character to continue.` at `fontSize: 14`, and `HeroCharacterChoiceCard` (avatar_choice_cards.dart:101-128) uses 14sp "Is this X?" header and 20sp name in CinzelDecorative — a *fantasy* font wholly inappropriate for Sprout (the band font is Nunito).
**Impact:** Medium
**Recommendation:** In `HeroCharacterChoiceCard`, branch on `band.band == AgeBand.sprout` and use Nunito 24sp for name, 16sp for the "Is this X?" prompt, and bump card padding from 12 to 18.
**Effort:** S

### S-025 — Character library "My Characters" appbar + delete confirm dialog
**Where:** `lib/screens/character_library_screen.dart:202-209, 110-130`
**Issue:** Character library is reachable from the wizard top-nav (`Heroes` button, wizard_story_screen.dart:597-610). Title is hard-coded "My Characters" (line 205). Delete confirm dialog uses "Delete Character?" / "Are you sure you want to delete X? This cannot be undone." (line 113-115) — destructive language and "cannot be undone" phrasing isn't Sprout-friendly. A 4yo could tap delete and then hit Delete on the confirm.
**Impact:** Medium
**Recommendation:** Hide the long-press/delete affordance for Sprout entirely (delete is a parent task, gate behind parent dialog). Title to "My Heroes ✨" for sprout/explorer. Empty-state text 16sp "Create your first character to get started!" (line 280) should be 22sp+.
**Effort:** M

### S-026 — Story Pack accent color "Life Quest" gets renamed to "Big Feelings" but other tiles ("Unfairness", "New Beginnings") remain abstract
**Where:** `lib/main_story.dart:989-1032, 1100-1102`
**Issue:** Pack labels "Unfairness", "New Beginnings", "Standing Up", "Family" are abstractions a 3yo doesn't parse. Subtitles ("Reach out & connect", "When things feel wrong") are 11sp.
**Impact:** Medium
**Recommendation:** For Sprout, rewrite to noun-verb concrete labels: "Friends!", "When it's not fair", "Trying new things", "Brave!", "My Family". Drop subtitles entirely (the emoji + word is enough). Or hide story packs for Sprout (the SEL framing is for parents anyway — they pick from the wizard).
**Effort:** S

### S-027 — Wizard top-nav row crowded: Bedtime / Heroes / Big Feelings / Chronicles fight for 360px
**Where:** `lib/screens/wizard_story_screen.dart:535-667`
**Issue:** When Sprout band, the top nav row contains: progress (MoonPhaseProgress, scaled `band.spacingScale`=1.2), `_LabeledNavButton(Big Feelings)`, `_LabeledNavButton(Heroes)`, optionally Chronicles IconButton, `_LabeledNavButton(Bedtime)`. On a 368px viewport with 1.2× scale that's >400px of demand, leading to label truncation or overflow. Each `_LabeledNavButton` only has 6px horizontal padding.
**Impact:** Medium
**Recommendation:** For Sprout, drop the Bedtime button from the wizard top nav (already on home screen via parent gate), and don't show Chronicles inline — they're parent-discovery features.
**Effort:** S

### S-028 — Sprout pet card "Ask a grown-up" prompt at 13sp
**Where:** `lib/screens/wizard_steps/hero_creator_step.dart:1248-1276`
**Issue:** The Sprout-only "Ask a grown-up to add your real pet!" prompt is correctly hidden behind a gate (line 1249) but rendered at `fontSize: 13` (line 1267). This is exactly the kind of message that needs to be parent-readable at arm's length.
**Impact:** Low
**Recommendation:** Bump to 16sp, and add a small lock icon to signal parent-gated.
**Effort:** S

## Suggested next-session priority

1. **S-019** — Chronicles "New" dialog blocks Sprout entirely (typing required). High impact, S effort. One-liner: skip dialog for age ≤ 5.
2. **S-003** — Home AppBar exposes too much chrome; replace with Sprout-mode minimal header. High impact, M effort.
3. **S-002** + **S-026** — Story Pack tiles too small + concept labels. Pair fix: render Sprout-specific 140×140 tiles with concrete labels. High impact, S effort.
4. **S-004** + **S-005** — Character portrait cards are Explorer-sized (130px) with 28×28 quick-play overlay. High impact, M effort. Pair fix.
5. **S-015** — MagicalLoadingView shared bottom panel pollutes Sprout loading screen with 9sp step dots. Medium impact, S effort.
6. **S-018** — Generation error has only "Try Again" — needs "go home" escape. Medium impact, S effort.
7. **S-024** — "Welcome back!" returning-user picker uses CinzelDecorative on Sprout. Medium impact, S effort.

These seven cover the most visible Sprout-specific gaps and are all 1-2 hour edits except S-003 (half-day) and S-004 (half-day).

## Out of scope

- **All-bands typography concerns:** Many AppBar / dialog / SnackBar messages app-wide use 12-14sp text. Only the Sprout-facing surface is in scope here, but a system-wide audit of `fontSize: 11/12/13/14` literals would benefit Explorer too.
- **`A.descriptionForAge`** archetype description copy: Sprout cards skip descriptions (good), but the Explorer copy could be tightened — out of scope.
- **Achievement system itself:** "Achievement Journey" framing is Explorer+ ; Sprout simply shouldn't see it (S-001), but redesigning achievements is its own session.
- **Parent gate flow / parental_consent_screen** copy: confirmed 18sp+ already, no action needed.
- **`big_feelings_quest`, scenario data:** content layer (titles via `titleForAge`) is already age-aware — `lib/data/scenario_data.dart` not investigated in detail; assumed correct given the breadcrumb.
- **Color contrast:** Many Sprout overlays use white70/white60 on the 0xFF2D1B42→0xFF8B3A6B gradient. May fail WCAG AA on some hues — separate accessibility audit territory.
- **Subscription / paywall flows:** PremiumUpgradeScreen wasn't walked. If Sprout users can hit a paywall mid-wizard ("Upgrade to Premium" star icon, main_story.dart:587-606), that's a separate parent-gate question.
- **`feelings_cloud_picker.dart` core grid:** age ≤5 correctly only shows level-0 cards (line 87-91), and Sprout label is "How do you feel?" — confirmed good. The 28sp emoji breathing animation and squircle card design are Sprout-grade. Out of scope.
