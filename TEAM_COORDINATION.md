# Team Coordination

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

### Delegation Guidance

- **Phase 1.1** (BigFeelingsFlowScreen): Complex widget rework — needs careful theme integration. Best for Claude or senior dev.
- **Phase 1.2, 1.3, 1.6, 5.1**: Simple label/asset fixes — delegatable to Codex or Gemini.
- **Phase 2.1** (CTA labels): Touches theme data model + multiple widgets. Best for Claude.
- **Phase 2.2** (Creative Brief rewrite): String changes only — delegatable to Codex/Gemini.
- **Phase 3.1-3.2** (Asset wiring): Medium complexity — Codex or Gemini with clear instructions.
- **Phase 4.3** (Creative Brief refactor): Major widget architecture change — best for Claude.
- **Phase 1.3** (Generate 12 face assets): Requires AI image generation or manual art creation — Darcy/design tool.

### Next Steps
- Begin Phase 1 implementation (BigFeelingsFlowScreen theme fix + Limerick Laughs label fix as first targets).
- Generate 12 missing feelings face assets (requires design/AI art tool, not code change).
- Darcy to review plan and confirm phase prioritization.

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

## 2026-03-18

- Completed: fixed the unsecured API key routes in `backend/routes/api_key_routes.py` so `/api/user/settings/api-key` and `/api/user/usage` now require JWT auth and use `request.current_user` instead of trusting `X-User-ID`.
- Completed: registered the API key blueprint in `backend/app.py`; before this, the BYOK endpoints existed in code but returned `404` because they were never mounted.
- Completed: added authorization coverage in `backend/tests/security/test_authorization.py` for API key, story, therapist, and achievement routes, and added the missing `therapist_user` fixture in `backend/tests/conftest.py`.
- Verification: `cd backend && python -m pytest tests/security/ -v` passed with `97 passed` on 2026-03-18.
- Verification note: the exact import check command `cd backend && python -c "from app import create_app; app = create_app('testing'); print('OK')"` still fails because this repo's current import layout mixes package-relative imports with top-level execution. A package-safe equivalent succeeded: `python -c "import sys; sys.path.insert(0, r'C:\\dev\\story-weaver-app'); from backend.app import create_app; app = create_app('testing'); print('OK')"`.
- In progress: adding per-phase story generation perf instrumentation in `backend/tasks/story_tasks.py` and extending `backend/tests/story_load_audit.py` with real-provider, fallback switchover, and concurrency-ramp coverage.
- Completed: `cd backend && python tests/story_load_audit.py` now passes and writes fresh audit artifacts with the new fallback switchover line (`~4573ms`) and concurrency ramp table.
- Completed: `cd backend && python tests/story_load_thresholds.py` passes with the new `concurrency_ramp_c16` checks.
- Completed: manual Flask test-client verification shows `/generate-story` responses now include `story._perf`, and `backend.tasks.story_tasks` emits `perf phase=` debug lines for prompt build, AI call, validation, and total task.
- Next: real-provider baseline remains gated behind `--real-api` / `RUN_REAL_API_TESTS=true` and was not executed because `GEMINI_API_KEY` is not set in this environment.
- Completed: illustration/count wiring and coloring follow-up fixes are now present in the Flutter layer:
  - `magic_review_step.dart` fallback illustration generation now forwards companion data, carries `customElements` into `sceneRequirements`, and uses subscription-based counts (`family=2`, `premium/free=1`).
  - `story_illustration_service.dart` now supports `sceneRequirements` and folds those requirements into the scene description sent to `/generate-illustrations`.
  - `story_result_screen.dart` now forwards companion data into `generateColoringPagesFromStory(...)` and appends `customElements` to coloring scene prompts.
  - `ColoringSettingsDialog` now exposes a real 1-5 page picker instead of hardcoding a single page.
- Coordination note: there are two coordination logs in the repo right now (`TEAM_COORDINATION.md` at repo root and `docs/TEAM_COORDINATION.md`). This thread has updated both at different points; prefer keeping the root file current for active handoff unless the docs copy is explicitly needed.
- Verification gap: targeted analyzer runs for the touched Dart files were attempted, but both `flutter analyze` and `dart analyze` timed out in this environment before returning diagnostics, so only code inspection and repo-state verification were completed here.
- Completed: Comprehensive UI aesthetic audit for Age Band adaptations. Addressed hardcoded colors in `app_bottom_navigation.dart`, updated `ArchetypeCard` to use dynamic layout sizes and proper `AgeBandThemeData` colors, corrected the hardcoded yellow highlighting in `magic_review_step.dart`, and ensured the "Export to Coloring Book" action is appropriately hidden for younger age bands in `story_result_screen.dart`.
- Completed: Verified and merged `age_band_assets` directories into `assets/images/ui` and `assets/images/orbs` to ensure all 6 age bands correctly load their variant image buttons and progress orbs correctly.

## 2026-03-19 (Phase 1 Fixes - BigFeelingsFlowScreen Theme Isolation)
- Completed: Fixed `BigFeelingsFlowScreen` to respect the age-band theme system by passing `childAge` parameter. Used `AgeBandThemeData` for gradients and fonts. Added "Happy" and "Excited" options, and replaced emojis with band-specific face images for feelings.

## 2026-03-19 (Task 1.2 - Reading Label Rename)
- Completed: Updated `lib/screens/wizard_steps/hero_creator_step.dart` so `_getReadingLabel()` now maps Explorer to `Easy Reader` and Adventurer to `Chapter Reader`, while leaving older bands on `First Chapter`.
- Completed: Updated `lib/screens/wizard_steps/magic_review_step.dart` so the learning-to-read review label now says `Rhyme Time story` instead of `Limerick Laughs story`.
- Verification: `rg -n "Limerick Laughs" lib` returns no matches after the change.

## 2026-03-19 (Task 1.4 - Bedtime Settings CTA)
- Completed: Updated `lib/screens/bedtime_wizard_screen.dart` so the 'Go to Settings' button now navigates to the `ParentControlsScreen` instead of just calling `Navigator.pop()`.
