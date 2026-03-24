# Team Coordination

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
| 1.1 | BigFeelingsFlowScreen ignores age-band theme | `big_feelings_flow_screen.dart` | Accept `childAge` param; use `AgeBandThemeData` gradient+font; add Happy/Excited feelings; use `assets/images/feelings/sprout/*.png` |
| 1.2 | "Limerick Laughs" reading mode label | `hero_creator_step.dart:_getReadingLabel()` | Explorer: "Easy Reader"; Adventurer: "Chapter Reader"; keep Creator+ as "First Chapter" |
| 1.3 | 12 missing feelings face assets | `assets/feelings_faces/` | Generate: bothered, bouncy, gloomy, grossed_out, hurt_mad, hyper, impatient, let_down, red_faced, stuck, what_if_y, wish_i_could_hide PNGs |
| 1.4 | Bedtime "Go to Settings" doesn't navigate | `bedtime_wizard_screen.dart:605-617` | Replace `Navigator.pop()` with actual settings navigation |
| 1.5 | Companion selection ID/name mismatch | `hero_creator_step.dart` (multiple) | Standardize all companion selection to use `c.id` consistently |
| 1.6 | `emotion_recognition_game.dart` references missing `assets/emotions/` | `emotion_recognition_game.dart:243` | Refactor to use `assets/feelings_faces/` or remove dead file |

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
