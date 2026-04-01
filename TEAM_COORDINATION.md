# Team Coordination

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

## 2026-03-31 — Creator Band Bug Fixes: Companions + World Title Mismatch (Claude Sonnet 4.6)

**Goal:** Fix the two remaining deferred Creator band bugs from the 12yo UX audit.

### Fixes Applied

| # | Issue | Fix |
|---|-------|-----|
| UX-C1 | No Companions section in Creator accordion | Added `_buildBriefCompanionsInputs()` + `_buildBriefSection('Cast & Companions', ...)` between Personality and World & Setting in `_buildCreativeBrief()`. Reuses existing `_buildCompanionShowcase()` + `_buildCompanionGrid()`. |
| UX-C3 | World setting chip shows `titleForAge(15)` but review reads `titleForAge(characterAge)` — different strings for same scenario | Fixed `_buildBriefWorldInputs` to use `widget.wizardData.characterAge ?? 15` instead of hardcoded `15` |
| UX-C2 | RenderFlex overflow on avatar circle in Creator review | Already resolved — `_GradientSphereFallback` has `clipBehavior: Clip.hardEdge`, `_HeroFallbackIdentity` uses Icon(20)/Text(12) which fit in 48×48 |

### Files Changed

| File | What |
|------|------|
| `lib/screens/wizard_steps/hero_creator_step.dart` | Added Cast & Companions accordion section; fixed world title age |

### Status
- [x] UX-C1: Companions section added to Creator accordion
- [x] UX-C3: World title now matches between chip and review
- [x] UX-C2: Confirmed already resolved

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
- [ ] UX-C1: Companions tab in Creator accordion — deferred
- [ ] UX-C2/C3: Review screen stale state + overflow — deferred

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
| NEW-06 | Archetype class shows "—" on Adventurer review when archetype skipped | Adventurer | Low | Deferred |
| NEW-07 | Adolescent review shows only name + "—", no story summary | Adolescent | Low | Deferred |
| NEW-08 | Adult "Begin" button gold/olive colour may read as disabled | Adult | Low | Deferred |

### Fix Details

**NEW-01** — `magic_review_step.dart` (~line 1248)
- Changed length-chip `Row` → `Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8)` so chips reflow rather than overflow.

**NEW-02** — `lib/widgets/adventurer_unlock_celebration.dart`
- Changed `Padding` wrapper → `SingleChildScrollView(padding: EdgeInsets.all(24))` so the dialog scrolls if the device is too short rather than clipping.

**NEW-03** — `magic_review_step.dart:_HeroFallbackIdentity`
- Reduced icon size 42→24, gap 8→2, text size 18→14 so all three elements fit within the 48×48 container.

**NEW-04** — `lib/screens/wizard_steps/hero_creator_step.dart:_buildArchetypeCards`
- Changed `maxLines: 1` → `maxLines: 2` on the name Text inside the bottom pill overlay; names like "The Animal Whisperer" now wrap to a second line instead of truncating with `…`.

### Files Changed
| File | What |
|------|------|
| `lib/screens/wizard_steps/magic_review_step.dart` | Length chip Row→Wrap; `_HeroFallbackIdentity` size reduction |
| `lib/widgets/adventurer_unlock_celebration.dart` | Padding→SingleChildScrollView |
| `lib/screens/wizard_steps/hero_creator_step.dart` | Archetype name pill maxLines 1→2 |

### Status
- [x] NEW-01: length chip overflow fixed
- [x] NEW-02: unlock dialog overflow fixed
- [x] NEW-03: `_HeroFallbackIdentity` overflow fixed
- [x] NEW-04: archetype name truncation fixed
- [ ] NEW-06/07/08: deferred (low priority)

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

| # | Issue | Action |
|---|-------|--------|
| 25 | Privacy policy | Add physical postal address and phone number (COPPA requirement) |
| 26 | `lib/screens/parental_consent_screen.dart` | Photo consent toggle defaults ON → change to OFF; parent must explicitly opt in |
| 27 | Consent form | Confirm email field is NOT pre-filled with PII in production builds; guard with `kDebugMode` |

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
- **Subscription sync 403 on web** — anonymous users hit `{"error": "Access denied"}` when the app tries to sync subscription status. Visible in dev console on every load. Likely the `/api/subscription/status` endpoint rejecting anonymous tokens — needs backend auth middleware check.
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
