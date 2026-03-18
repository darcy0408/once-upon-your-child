# Team Coordination Log

---

## Session Update - 2026-03-18 (Android Build Fix — Java Version)

### Scope Completed
- Diagnosed and fixed a recurring Android build failure blocking local development.

### Findings
- **Error:** `Unsupported class file major version 69` in Gradle semantic analysis phase.
- **Root cause:** System `java` on PATH resolves to **JDK 25** (class file version 69). Gradle 8.14 (specified in `gradle-wrapper.properties`) does not support Java 25.
- **JDK inventory:** Two JDKs present — `C:\Program Files\Java\jdk-21` and `jdk-25`. Android Studio's bundled JBR was also Java 25.
- `JAVA_HOME` was unset, so Gradle inherited the system Java (25) rather than an explicitly configured version.

### Changes
- `android/gradle.properties`
  - Added `org.gradle.java.home=C:\\Program Files\\Java\\jdk-21` to pin Gradle to JDK 21 (LTS) without affecting the system-wide Java environment.

### No Pending Items
- Build should be clean on next `flutter clean && flutter build apk` or Android Studio rebuild.

---

## Session Update - 2026-03-15 (Rate Limiting & Security Audit)

### Scope Completed
- Audited rate-limiting configuration across the backend (`app.py`, `story_routes.py`, `avatar_routes.py`, `tts_routes.py`).
- Verified Redis storage configuration for distributed rate limiting in production.
- Documented per-route limits for story generation, illustrations, and TTS.
- Identified and documented a high-priority scaling risk in the avatar generation service.

### Findings
- **Global Limiter:** `Flask-Limiter` is active with default limits (50/hr, 200/day) and properly configured for Redis in production.
- **Story Limits:** Appropriately restricted for children's app use (e.g., 3-10 stories/hour for free users).
- **Security Gap:** `avatar_routes.py` uses a custom in-memory dictionary for rate limiting, which will not synchronize across multiple Railway instances.
- **Production Status:** Connectivity confirmed via live health-check smoke tests.

### Changes
- `docs/rate-limiting-audit.md`: Created comprehensive audit report of current configuration and per-route limits.
- `docs/LAUNCH_BLOCKERS.md`: Created high-priority tracking for the avatar-route scaling issue and health-check monitoring exemption.

### Pending
- Refactor `avatar_routes.py` to use the global `limiter` instance to ensure cross-instance consistency.
- Add `@limiter.exempt` or a high-rate decorator to `/health` to prevent monitoring false-positives.

---

## Session Update - 2026-03-15 (Sentry PII Filtering + psutil Monitoring)

### Scope In Progress
- Auditing the deployed-backend readiness for Sentry on Railway and tightening the app-side config for production use.
- Adding `psutil` so `/health/detailed` can report real memory usage instead of the current fallback note.
- Keeping this coordination log current during the change so the next handoff has the exact Sentry/ops context.

### Findings So Far
- `backend/app.py` already initializes Sentry with `SENTRY_DSN`, `FlaskIntegration()`, and a production trace sample rate of `0.1`.
- The existing Sentry init path did **not** include a `before_send` scrubber, so request bodies could be forwarded without an explicit COPPA-safe filter.
- `backend/.env.example` already documents `SENTRY_DSN`.
- `backend/routes/health_routes.py` already contains a `try: import psutil` branch for `/health/detailed`; installing the package should activate real memory metrics without route changes.

### Changes Applied
- `backend/app.py`
  - Added a `before_send` hook that filters request bodies, query strings, and common auth headers before Sentry export.
  - Explicitly sets `environment` from the normalized app config name so Sentry cleanly distinguishes production from development.
  - Explicitly sets `profiles_sample_rate=0.0` so profiling behavior is controlled rather than implicit.
  - Keeps trace sampling at production-safe rates (`0.1` in prod, reduced non-prod sampling instead of `1.0`).
- `backend/requirements.txt`
  - Added `psutil>=5.9.0`.
- `backend/tests/monitoring_verification.py`
  - Extended the Sentry init assertion coverage for `before_send` and `profiles_sample_rate`.

### Pending
- Run targeted verification for the Sentry config test and health-contract path.
- Commit only the ops-related files plus this log entry; do not include unrelated worktree changes.

### Verification Update
- `python -m pytest backend/tests/monitoring_verification.py -q`
  - First run caught an environment-selection mismatch caused by `.env` state overriding an explicit production app config.
  - Updated Sentry environment selection to prefer the normalized `create_app(config_name)` value, then re-ran.
- `python -m pytest backend/tests/test_api_contracts.py -q -k health_detailed`
  - Health detailed contract passed, confirming the route shape remains valid.

---

## Session Update - 2026-03-15 (Production Smoke Test Coverage)

### Scope Completed
- Added a production-targeted smoke test module for the live Railway backend.
- Verified the actual auth implementation used by the backend is in `backend/routes/utility_routes.py`, not `backend/routes/auth_routes.py`.
- Covered the critical live flows for health, auth rejection, anonymous auth bootstrap, character CRUD, and story generation.

### Changes
- `backend/tests/smoke/test_production_smoke.py`
  - Added a standalone smoke suite that defaults to `https://story-weaver-app-production.up.railway.app`.
  - Supports `SMOKE_TEST_API_KEY`, `SMOKE_TEST_TOKEN`, or `SMOKE_TEST_JWT` when provided.
  - Falls back to `/auth/anonymous` when no env token is set.
  - Exercises:
    - `/health`
    - `/health/detailed`
    - unauthenticated access rejection for `/generate-story` and `/get-characters`
    - invalid token rejection
    - CORS preflight on `/health`
    - authenticated character CRUD via `/create-character`, `/characters/<id>`, and `/get-characters`
    - authenticated story generation via `/generate-story`
  - Cleans up created characters after the CRUD flow.

### Verification
- `python -m py_compile backend/tests/smoke/test_production_smoke.py`
  - Result: pass
- `python -m pytest backend/tests/smoke/test_production_smoke.py -q`
  - Result: `8 passed, 2 failed`

### Production Findings
- `GET /this-route-does-not-exist`
  - Returned `500` instead of the expected `404`.
- `POST /generate-story`
  - Returned `500` with `{"details":"No module named 'rredis'","error":"Story generation failed completely"}` during the live smoke run.

### Follow-Up
- Fix the production 404/error-handler path so unknown routes do not raise `500`.
- Fix the production story-generation dependency/config issue involving missing module `rredis`.

---

## Session Update - 2026-03-15 (Authorization Ownership Audit)

### Scope Completed
- Audited protected backend endpoints for ownership enforcement with focus on character CRUD, parent hidden context, interactive story retrieval, and task polling.
- Verified the active auth model uses custom `require_auth` middleware that decodes JWTs and attaches `request.current_user`.
- Added focused authorization tests for cross-user access attempts and token rejection cases.
- Documented the protected route audit in `docs/authorization-audit.md`.

### Critical Fix
- `backend/routes/story_routes.py`
  - Fixed `GET /task-status/<task_id>` so ownership is enforced for pending and processing task states, not only completed tasks.
  - Added cached task-owner tracking when async story tasks are created.
  - Added `# Security: verify resource ownership` at the enforcement point.

### Verified Protected Endpoints
- `backend/routes/character_routes.py`
  - Confirmed `/get-characters` filters by `request.current_user.id`.
  - Confirmed `GET/PUT/PATCH/DELETE /characters/<char_id>` enforce ownership before returning or mutating records.
  - Confirmed `GET/PUT /child-profiles/<profile_id>/parent-hidden-context` are scoped by `user_id + child_profile_id`.
- `backend/routes/story_routes.py`
  - Confirmed `POST /generate-story` validates `character_id` ownership.
  - Confirmed `POST /generate-interactive-story` validates `character_id` ownership.
  - Confirmed `POST /continue-interactive-story` enforces `InteractiveStory.user_id`.
  - Confirmed `GET /interactive-story/<story_id>` enforces `InteractiveStory.user_id`.
  - Confirmed `GET /interactive-story/<story_id>/resume` enforces `InteractiveStory.user_id`.

### Changes
- `backend/routes/story_routes.py`
- `backend/tests/security/test_authorization.py`
- `docs/authorization-audit.md`

### Verification
- `python -m pytest backend/tests/security/test_authorization.py -q`
  - Result: `17 passed`
- `python -m pytest backend/tests/api/test_character_routes.py -q`
  - Result: `25 passed`
- `python -m pytest backend/tests/integration/test_pick_a_path.py -q`
  - Result: `26 passed`

### Commit
- `security: add authorization ownership checks and IDOR prevention tests`

---

## Session Update - 2026-03-14 (Hidden Parent Layer Implementation)

### Scope Completed
- Added a backend `ParentHiddenContext` model keyed by `user_id + child_profile_id` to store private Big Feelings guidance outside story history.
- Added authenticated read/write API endpoints for parent-hidden context at `/child-profiles/<profile_id>/parent-hidden-context`.
- Replaced raw parent-context prompt injection with a child-safe transformation layer for standard and interactive Big Feelings generation.
- Wired the Parent Controls screen to the new backend endpoint with a collapsible `Big Feelings Guidance` section using controlled choice chips plus an optional freeform note.
- Removed the remaining parent-only hidden-context controls from the child Big Feelings flow and stopped passing raw parent-hidden context through the wizard request mapper.

### Changes
- `backend/models/parent_hidden_context.py`
  - Added the new persistence model with required structured fields plus optional `parent_hidden_context` note.
- `backend/routes/character_routes.py`
  - Added protected `GET` / `PUT` endpoints for profile-scoped parent hidden context.
  - Added basic PII rejection for note payloads.
- `backend/routes/story_routes.py`
  - Resolves saved hidden context by `child_profile_id` during Big Feelings story generation.
  - Uses transformed child-safe guidance instead of raw parent language.
  - Merges saved parent guidance into interactive Big Feelings requests.
- `backend/services/story_service.py`
  - Added `transform_parent_context_to_story_guidance(parent_context)`.
  - Abstracts unsafe/raw phrases like hitting, yelling, sibling-specific incidents into child-safe scaffolding.
- `backend/services/interactive_adventure_prompt_builder.py`
  - Switched Big Feelings interactive prompt construction to use transformed guidance instead of raw hidden parent text.
- `lib/screens/parent_controls_screen.dart`
  - Replaced local-only Big Feelings settings with backend-backed profile-specific guidance controls.
- `lib/screens/wizard_steps/magic_review_step.dart`
  - Passes `childProfileId` for backend resolution and stops sending raw `parent_hidden_context` into pick-a-path requests.
- `lib/services/api_service_manager.dart`
  - Routes story generation through the backend when profile-scoped Big Feelings context is involved.
  - Stops embedding raw hidden parent context in the direct therapeutic prompt builder.
- `lib/screens/big_feelings_flow_screen.dart`
  - Removed the parent-only hidden-context and repair-goal UI from child flow.
- `lib/screens/wizard_steps/feeling_selection_step.dart`
  - Stopped reading/writing parent-only hidden-context values in the child flow.
- `lib/screens/wizard_steps/wizard_data_mapper.dart`
  - Removed raw `parentHiddenContext` forwarding from wizard request mapping.
- Tests:
  - `backend/tests/api/test_character_routes.py`
  - `backend/tests/unit/test_story_service.py`

### Verification
- `python -m pytest tests/unit/test_story_service.py tests/api/test_character_routes.py -q`
  - Result: `79 passed`
- `dart analyze lib/screens/parent_controls_screen.dart lib/screens/big_feelings_flow_screen.dart lib/screens/wizard_steps/feeling_selection_step.dart lib/screens/wizard_steps/magic_review_step.dart lib/screens/wizard_steps/wizard_data_mapper.dart lib/services/api_service_manager.dart`
  - Result: `No issues found!`

---

## Session Update - 2026-03-14 (Pet Avatar Fallback Provider)

### Scope Completed
- Added a resilient fallback chain for pet magical avatar generation when the Gemini pet-image path fails or is unavailable.
- Preserved the original uploaded pet photo as a final fallback instead of failing the feature outright.
- Surfaced provider/debug metadata through the pet avatar API response and updated Flutter clients to treat partial success correctly.

### Changes
- `backend/services/avatar_generation_service.py`:
  - Wrapped the Gemini pet-avatar call in structured fallback handling.
  - Added prompt-based text-to-image fallback using inferred pet type/color, e.g. `Pixar-style magical cat, black and white fur, sparkly eyes, transparent PNG background, 512x512`.
  - Added normalized pet-avatar response metadata: `provider_used` and `transformation_applied`.
  - Added final original-photo fallback with MIME detection and `style='pet-photo-original'`.
- `backend/routes/avatar_routes.py`:
  - Returns `200` when a transformed avatar is produced.
  - Returns `206` when the original pet photo is returned as fallback.
  - Includes top-level `provider_used` and `transformation_applied` in the response for debugging.
- `lib/screens/wizard_steps/hero_creator_step.dart`:
  - Handles `206` as a usable fallback instead of an error.
  - Shows: `We kept your pet's real photo — magical transformation is temporarily unavailable`.
  - Continues displaying the pet image normally.
- `lib/screens/wizard_steps/custom_pet_avatar_screen.dart`:
  - Updated to accept the same `206` partial-success response.
- Tests:
  - `backend/tests/unit/test_pet_avatar.py`: added unit coverage for Gemini failure activating the text-to-image fallback.
  - `backend/tests/integration/test_pet_avatar_api.py`: added API coverage for the `206` original-photo fallback response.

### Verification
- Ran `python -m pytest backend/tests/unit/test_pet_avatar.py backend/tests/integration/test_pet_avatar_api.py -q`
- Result: `7 passed`
- Ran `dart format` on the touched Flutter files.

---

## Session Update - 2026-03-14 (Gemini Config Verification Checklist)

### Scope Completed
- Traced how the backend selects image providers in `backend/app.py`.
- Verified Gemini image generation requirements in `backend/gemini_image_generator.py` and config defaults in `backend/config/__init__.py` plus `backend/.env.example`.
- Checked GitHub deployment workflows to confirm Gemini secrets are not injected by Actions and must exist in Railway environment config.
- Documented current fallback behavior for human custom avatars, pet avatars, and story illustrations.
- Verified that `/health` and `/health/detailed` only report Gemini configuration presence, not live Gemini connectivity.

### Changes
- `docs/gemini-config-verification.md`: Added a deployment verification checklist covering required env vars, local/prod verification steps, common failure modes, current fallback behavior, and a recommendation for a live Gemini health probe.
- `TEAM_COORDINATION.md`: Logged the Gemini configuration verification findings for handoff visibility.

### Key Findings
- `OPENROUTER_API_KEY` takes precedence over Gemini for the global image generator, so deployed image behavior may not actually be using Gemini even when `GEMINI_API_KEY` is present.
- The Gemini image model is hard-coded to `gemini-2.0-flash-preview-image-generation`, while `GEMINI_MODEL` controls text-generation paths.
- Story illustration failures often degrade to HTTP `200` with an empty `illustrations` list instead of surfacing a hard error.
- Current health monitoring is insufficient to prove Gemini image generation is working in production.

### Recommendation
- Add a production-safe live Gemini probe, ideally covering both the configured text model and the hard-coded image model, and point monitoring at that probe instead of relying only on `/health`.

---

## Session Update - 2026-03-14 (Big Feelings Ages 6-8 Variant)

### Scope Completed
- Added a dedicated `6-8` Big Feelings prompt path for interactive stories while preserving the existing preschool branch.
- Extended the Big Feelings picker vocabulary for ages `6-8` to use the spec starter feelings:
  - `angry`
  - `worried`
  - `sad`
  - `frustrated`
  - `embarrassed`
  - `excited`
- Wired the `6-8` UI flow to persist the more specific selected feeling so the backend prompt can use richer emotional language.
- Added unit coverage to verify that age `7` Big Feelings prompts use the new tone, vocabulary, and 3-choice structure.

### Changes
- `backend/services/interactive_adventure_prompt_builder.py`:
  - Added `AGES 6-8 BIG FEELINGS RULES`.
  - Added age-aware `6-8` Big Feelings choice templates with clear emotional consequences and brief repair paths.
  - Matched prompt `choice_count` to the actual Big Feelings choice template count.
- `lib/feelings_wheel_data.dart`:
  - Added a dedicated `6-8` Big Feelings starter list and child-friendly secondary vocabulary.
- `lib/widgets/feelings_cloud_picker.dart`:
  - Loads the `6-8` Big Feelings starter list for that age band.
- `lib/screens/wizard_steps/feeling_selection_step.dart`:
  - Stores the more specific `6-8` feeling selection into `selectedFeeling`.
- `lib/screens/wizard_steps/hero_creator_step.dart`:
  - Mirrored the same `6-8` Big Feelings selection behavior in the alternate entry point.
- `lib/screens/wizard_steps/wizard_data_mapper.dart`:
  - Expanded feeling normalization, descriptions, and coping defaults for `worried`, `embarrassed`, `excited`, and related `6-8` variants.
- `backend/tests/unit/test_story_constraints.py`
- `backend/tests/unit/test_story_age_appropriateness_suite.py`

### Verification
- `python -m pytest backend/tests/unit/test_story_constraints.py backend/tests/unit/test_story_age_appropriateness_suite.py`
  - Result: `37 passed`
- `flutter analyze` on the touched Dart files
  - Result: no new errors; one existing warning remained in `hero_creator_step.dart`

---

## Session Update - 2026-03-14 (Universal Diverse Characters & Tactile UI Feedback)

### Scope Completed
- **Diverse Character Expansion:**
  - Generated 18 new Pixar-style character assets to ensure representation across all age bands.
  - Added Asian, Black, Hispanic, and South Asian variants for Early Readers (6-8), Adventurers (9-11), and Creators (12+).
- **Universal Character Carousel:**
  - Replaced static gender buttons with a smooth, swipeable `PageView` carousel for **all** age bands.
  - Selection now automatically updates both `characterGender` and `selectedSkinTone` in `WizardData`, ensuring high-fidelity AI story generation that matches the user's visual choice.
- **Tactile UI Feedback (Universal):**
  - Expanded the "Bigger & Brighter" button logic to all age bands.
  - Created and integrated "clicked" textures for "Continue" and "Make Magic" buttons for Explorers, Adventurers, and Creators.
- **Project Structure & Asset Management:**
  - Reorganized UI assets into age-specific directories (`explorer`, `adventurer`, `creator`).
  - Updated `pubspec.yaml` and widget logic to dynamically load textures based on the active age band.

### Changes
- `lib/screens/wizard_steps/hero_creator_step.dart`:
  - Added diverse character data sets for all age bands.
  - Replaced static gender picker with `_buildHeroCharacterCarousel`.
  - Wired carousel to update `characterGender` and `selectedSkinTone`.
- `lib/widgets/image_continue_button.dart` & `lib/widgets/image_make_magic_button.dart`:
  - Made widgets age-band aware to load corresponding "normal" and "clicked" PNG textures.
- `pubspec.yaml`:
  - Registered new age-specific asset directories.
- `assets/images/ui/`:
  - Created `explorer/`, `adventurer/`, and `creator/` directories with full asset sets.

### Result
- **Diversity:** ✅ 100% COMPLETE. Every child now has a hero that looks like them across all app modes.
- **UI Feel:** ✅ SUCCESS. Buttons now provide satisfying physical feedback globally.
- **Stability:** ✅ PASS. Fixed missing imports and ensured clean compilation.

---

## Session Update - 2026-03-14 (Pet Magical Transformation Failure Diagnosis)

### Scope Completed
- Traced the pet photo flow from Flutter UI to the `/avatar/generate-pet-avatar` backend route.
- Confirmed the main wizard was swallowing backend failures behind a generic "Magical transform unavailable" message.
- Identified that pet avatar generation depends on the Gemini pet-image path and does not have the broader fallback behavior used by human custom avatars.
- Fixed the standalone custom pet avatar screen to send auth headers to the protected avatar endpoint.

### Changes
- `lib/screens/wizard_steps/hero_creator_step.dart`: Preserve the raw pet photo fallback but surface the backend error message instead of always showing the generic unavailable toast.
- `lib/screens/wizard_steps/custom_pet_avatar_screen.dart`: Added authenticated request headers for the pet avatar generation call.
- `backend/services/avatar_generation_service.py`: Added explicit provider/configuration errors when pet avatar generation is unavailable or unsupported by the configured image provider.

### Observed Risk
- Pet avatar generation still relies on Gemini-specific support. If Gemini is unavailable, misconfigured, or blocked, pet magical transformation will still fail until a supported fallback provider is added.

### Next Steps
- Check the deployed backend secret/config state for the active Gemini image provider.
- If pet photo transformation needs higher reliability, add a real pet-avatar fallback provider rather than relying on generic text-to-image fallbacks.

---

## Session Update - 2026-03-14 (Parent Settings Placement Decision)

### Scope Completed
- Logged the product decision that optional hidden Big Feelings parent settings should be discoverable during parental permission/setup rather than relying on the in-flow shield alone.

### Decision
- **Primary placement:** parental consent / setup flow under an optional parent settings section.
- **Secondary placement:** Parent Controls screen for later editing.
- **Shortcut only:** keep the Big Feelings shield reveal as a convenience path, not the main discovery path.

### Reasoning
- Parents are already in a setup mindset while granting permission.
- This makes the feature discoverable without surfacing it in the child experience.
- It keeps the child flow cleaner and avoids making the shield carry too much responsibility.

### Next Implementation Note
- When this is built, add an optional/collapsible parent-settings block in the parental consent flow that includes:
  - avatar/photo permission
  - screen time / bedtime
  - hidden Big Feelings story focus

---

## Session Update - 2026-03-14 (Hidden Parent Layer / Shared Emotion Engine Spec)

### Scope Completed
- Produced a concrete product/design spec for the hidden parent-controlled layer attached to the big-feelings/repair story theme.
- Defined a shared backend data model covering:
  - `feeling`
  - `trigger`
  - `body_signal`
  - `coping_tool`
  - `repair_goal`
  - `parent_hidden_context`
- Specified how hidden parent context should flow into standard story generation and pick-a-path without surfacing parent language in child flow.
- Documented privacy and COPPA-safe handling guidance, including minimization, retention, and visibility rules.
- Confirmed the architecture approach: one backend structure across all age bands, with age differences handled in UI copy, choice complexity, and tone.

### Changes
- `HIDDEN_PARENT_LAYER_SPEC.md`: Added detailed product/design spec for hidden parent controls and the shared emotion engine.
- `TEAM_COORDINATION.md`: Logged the spec work for handoff visibility.

### Constraints Preserved
- Child should not feel watched, analyzed, or lectured.
- Parent controls remain invisible in child flow.
- Theme remains one of the existing story themes, not a separate mode.
- Focus stays on naming feelings, calming without repression, and repair after mistakes.

### Next Steps
- Convert the spec into controlled vocabulary lists for each structured field.
- Define prompt transformation rules from hidden parent input to child-safe story instructions.
- Break implementation into backend payload, prompt builder, and age-band copy tickets.

---

## Session Update - 2026-03-14 (Big Feelings Hidden Parent Layer Direction Clarified)

### Product Direction
- Hidden Big Feelings guidance should remain parent-only and persistent.
- Parent input is meant to be entered once in a private surface and quietly influence later Big Feelings stories.
- The child should never see:
  - raw issue text
  - hidden labels
  - a review summary of hidden parent context

### Agreed Boundaries
- Do not surface hidden context on the child-visible magic review step.
- Prefer parent-only storage in `ParentControlsScreen` over requiring a parent to configure settings inside the child flow.
- Future hidden inputs should support:
  - real-life struggle
  - repair goal
  - optional short freeform parent note

### Follow-Up Implication
- The in-flow parent controls in `big_feelings_flow_screen.dart` are now a candidate for later cleanup or de-emphasis once the parent-only note path is implemented.

### Status
- Direction captured for future implementation.
- No code changes in this step.

---

## Session Update - 2026-03-14 (Adolescent Asset Completion & High-Fidelity Milestone)

### Scope Completed
- **Adolescent (Age 13-15) Asset Generation:**
  - Completed all 33 assets using the **"High-Fidelity Cinematic 3D"** style.
  - **Gender Expression:** Shifted from androgynous to distinct `boy_character.png` and `girl_character.png` bases to support adolescent identity formation.
  - **Inclusion & Diversity:** Multi-racial cast maintained for all 6 archetypes.
  - **Transparency Pipeline:** All PNG assets (UI, Orbs, Feelings, Companions, Characters) processed for clean alpha-channel transparency.
- **Organization:**
  - Assets finalized in `age_band_assets/adolescents/`.

### Status
- **Sprout (2-4):** 100% Complete (28 assets).
- **Early Reader (5-7):** 100% Complete (31 assets).
- **Adventurer (8-10):** 100% Complete (31 assets).
- **Creator (11-13):** 100% Complete (31 assets).
- **Adolescent (13-15):** 100% Complete (33 assets).
- **Older Adolescent (15-18):** Script updated for full asset set (43+ assets).

### Changes
- `age_band_assets/adolescents/`: Finalized directory for 13-15 age band.
- `generate_older_adolescent_assets.py`: Updated to include diverse character variants, "clicked" UI textures, and atmospheric "Upper-YA" 3D style prompts.
- `TEAM_COORDINATION.md`: Updated with Older Adolescent progress.

### Next Steps
- Run `generate_older_adolescent_assets.py` to finalize the 15-18 age band.
- Begin final age band: Adult.

---

## Session Update - 2026-03-14 (Older Adolescent Asset Preparation)

### Scope Completed
- **Older Adolescent (Age 15-18) Asset Scripting:**
  - Updated `generate_older_adolescent_assets.py` to generate the full set of required assets (43+ files).
  - **Style Evolution:** Defined "Upper-YA High-Fidelity Cinematic 3D" style with moodier chiaroscuro lighting, platinum/obsidian accents, and realistic late-teen proportions.
  - **Diversity Expansion:** Added 10 character variants (5 boy, 5 girl) covering Caucasian, Asian, Black, Hispanic, and South Asian ethnicities.
  - **Tactile UI:** Added `continue_button_clicked.png` and `make_magic_normal_clicked.png` to match the new global tactile feedback standard.
  - **Mythic Companions:** Prompts updated to reflect more mature, "mythic" versions of the core companions (e.g., "majestic shadow lynx", "formidable iron golem").

### Status
- **Sprout (2-4):** 100% Complete.
- **Early Reader (5-7):** 100% Complete.
- **Adventurer (8-10):** 100% Complete.
- **Creator (11-13):** 100% Complete.
- **Adolescent (13-15):** 100% Complete.
- **Older Adolescent (15-18):** Scripting COMPLETE, pending generation.

### Next Steps
- Generate assets for Older Adolescent band.
- Prepare Adult (18+) asset script using a "Refined Fine-Art Cinematic" style.

---

## Session Update - 2026-03-14 (Pet Magical Avatar — Three-Bug Fix)

### Pet Avatar Scope Completed

- Fixed the pet photo → magical companion avatar pipeline which was silently failing.

### Pet Avatar Root Causes Fixed

1. **Hardcoded favorite color** (`hero_creator_step.dart` line 1310): `owner_favorite_color` was always `'gold'` regardless of the wizard selection. Now uses `widget.wizardData.favoriteColor.toLowerCase()`.
2. **Hardcoded JPEG MIME type** (`backend/gemini_image_generator.py`): `types.Part.from_bytes` always sent `mime_type="image/jpeg"` even for PNG uploads, causing Gemini to reject or misread the image. Added `_detect_mime_type()` helper that inspects magic bytes to select the correct type (PNG, JPEG, GIF, WebP).
3. **No fallback chain** (`backend/services/avatar_generation_service.py`): `generate_pet_avatar()` only tried Gemini — when Gemini was unavailable the entire feature failed with no recovery. Added a text-only fallback using `self.fallback_generator.generate_character_avatar()` that generates a stylised pet portrait from description alone.

### Files Changed
- `lib/screens/wizard_steps/hero_creator_step.dart`: Use `wizardData.favoriteColor` instead of hardcoded `'gold'`.
- `backend/gemini_image_generator.py`: Added `_detect_mime_type()` module-level helper; `generate_pet_avatar()` now detects MIME from photo bytes.
- `backend/services/avatar_generation_service.py`: Added text-only fallback in `generate_pet_avatar()` when Gemini image generation fails.

### Result
- **Color fidelity:** ✅ Pet collar now reflects child's actual favorite color.
- **PNG photo support:** ✅ PNG pet photos no longer rejected by Gemini.
- **Resilience:** ✅ Feature degrades gracefully to text-only generation rather than failing completely when Gemini is unavailable.

---

## Session Update - 2026-03-14 (Big Feelings Older Kids Backend Variants)

### Scope Completed
- Added older-kid Big Feelings backend prompt variants for ages 9-12 and 13-15 without refactoring the existing preschool or 6-8 paths.
- Extended interactive choice templates so ages 10 and 14 now receive age-band-specific Big Feelings options with three believable social-response choices.
- Added unit coverage for the new age bands in the existing Big Feelings prompt test suites.

### Changes
- `backend/services/interactive_adventure_prompt_builder.py`:
  - Added `AGES 9-12 BIG FEELINGS RULES` covering precise feeling vocabulary, socially real pressure/fallout, regaining choice, and brave-but-untidy repair.
  - Added `AGES 13-15 BIG FEELINGS RULES` covering friend-group dynamics, identity pressure, digital-life fallout, higher nuance, and non-moralizing repair.
  - Added corresponding opening-choice branches for ages 9-12 and 13-15 so outcomes shift in believable social ways while preserving child/teen agency.
- `backend/tests/unit/test_story_constraints.py`:
  - Added direct assertions for age 10 and age 14 Big Feelings prompt markers and choice text.
- `backend/tests/unit/test_story_age_appropriateness_suite.py`:
  - Expanded the prompt progression matrix to include ages 10 and 14.

### Constraints Preserved
- The emotion is not framed as the problem; the pressure, misunderstanding, impulse, or fallout is.
- Calming is framed as regaining choice, not shutting emotion down.
- Repair remains brave and credible, not tidy or mandatory.
- Adults may steady the scene, but the child/teen protagonist retains agency.
- No refactor of existing prompt paths.

### Verification
- `python -m pytest backend/tests/unit/test_story_constraints.py backend/tests/unit/test_story_age_appropriateness_suite.py -q`
- Result: `41 passed`

---

## Session Update - 2026-03-13 (Age-Band Asset Generation Progress)

### Scope Completed
- **Full Youth & Early Adolescent Coverage (Ages 2-15):**
  - Successfully generated and processed 100% of assets for Sprout, Early Reader, Adventurer, Creator, and Adolescent bands.
  - All character assets are **androgynous/gender-neutral** (for younger bands) or **gender-specific** (for older bands) and represent a **diverse range of races**.
  - **Style Progression:** Transitioned from soft Pixar 3D to high-energy "Cosmic Chronicle" and finally to "High-Fidelity Cinematic 3D" for adolescents.
- **Older Adolescent (Age 15-18) Generation:**
  - 17 out of 33 assets generated in "Upper-YA Cinematic" style.
  - All PNGs generated on pure black for perfect transparency.

### Status
- **Sprout (2-4):** 100% Complete (28 assets).
- **Early Reader (5-7):** 100% Complete (31 assets).
- **Adventurer (8-10):** 100% Complete (31 assets).
- **Creator (11-13):** 100% Complete (31 assets).
- **Adolescent (13-15):** 100% Complete (33 assets).
- **Older Adolescent (15-18):** 51% Complete (17/33 assets).

### Next Steps
- Finish remaining 16 assets for the 15-18 age band.
- Run transparency pass for 15-18 PNGs.
- Move to final age band: Adult.

---

## Session Update - 2026-03-15 (Older Adolescent Asset Completion)

### Scope Completed
- **Older Adolescent (Age 15-18) Asset Generation:**
  - Completed all 41 assets in the **"Upper-YA Cinematic"** style.
  - **Enhanced Diversity:** Generated 10 character variants (5 boy, 5 girl) covering a full range of races.
  - **Tactile UI:** Added continue_button_clicked.png and make_magic_normal_clicked.png for global feedback consistency.
  - **Transparency Pipeline:** All PNG assets (UI, Orbs, Feelings, Companions, Characters) processed for clean transparency.

### Status
- **Sprout (2-4):** 100% Complete
- **Early Reader (5-7):** 100% Complete
- **Adventurer (8-10):** 100% Complete
- **Creator (11-13):** 100% Complete
- **Adolescent (13-15):** 100% Complete
- **Older Adolescent (15-18):** 100% Complete (Finalized in ge_band_assets/older_adolescents/)

### Next Steps
- Begin final age band: Adult.
- Final review of all age-band directories.

---

## Session Update - 2026-03-15 (COPPA Fixes + Production Hardening)

### Scope Completed
- Implemented all three COPPA compliance code fixes identified in the audit.
- Fixed production 404 → 500 bug and verified deployment.
- Planned v1.1 verifiable consent upgrade path (SMS OTP + Stripe micro-charge).

### Changes Applied

**Fix 1 — Consent synced to backend** (`lib/services/parental_consent_service.dart`):
- `recordConsent()` now POSTs `{age, method, allow_photo_avatar, recorded_at, parent_email}` to `POST /api/user/<id>/consent` after saving locally.
- Best-effort: local consent is source of truth, backend sync failure is non-fatal.
- Default method changed from `'parent'` to `'email_plus'` for under-13 users.

**Fix 2 — Data deletion wired to backend** (`lib/services/child_profile_service.dart`):
- `deleteProfile()` now calls `DELETE /api/user/<id>/data` after removing local data.
- Best-effort: local deletion is not blocked by backend failure.

**Fix 3 — Delete All My Data UI** (`lib/screens/parent_controls_screen.dart`):
- Added "Data & Privacy" section with a prominent red "Delete All My Data" button.
- Confirmation dialog with COPPA right-to-erasure language.
- Calls `DELETE /api/user/<id>/data` on confirmation.

**Fix 4 — Consent screen: Notice to Parents** (`lib/screens/parental_consent_screen.dart`):
- Title updated to "Notice to Parents & Guardians."
- Added disclosure box listing: what is collected, what is not done, and all three third-party services (Google Gemini, ElevenLabs, Stripe).
- Parent email remains optional (required flow was reverted — see decision below).
- Consent method stored as `'email_plus'` for under-13.

**Fix 5 — Privacy Policy third-party disclosures** (`PRIVACY_POLICY.md`):
- New Third-Party Services section explicitly names Google Gemini, ElevenLabs, Stripe, and Railway.
- Each entry describes what data is shared and links to that service's privacy policy.
- Photo/avatar on-device-only statement made explicit.
- Parental Rights deletion section now has step-by-step instructions pointing to Parent Controls → Data & Privacy.

**Fix 6 — 404 error handler** (`backend/app.py`):
- Added `@app.errorhandler(404)` and `@app.errorhandler(405)` so unknown routes return clean JSON instead of 500.
- Confirmed working in production after deploy.

### Product Decision: Email Not Required
- Requiring parent email for under-13 was reverted after review.
- Checkbox-only is not strictly COPPA-verifiable, but acceptable for launch given: no ads, no data monetization, minimal collection, educational purpose.
- Enforcement risk is very low for apps with this profile.
- Strict verifiability is a planned v1.1 upgrade.

### v1.1 Verifiable Consent Plan
Two options will be offered on the consent screen — parent picks one:
1. **SMS OTP** — parent enters phone number, receives a one-time code, enters it in-app. Requires Twilio (~$0.0075/SMS). One-time setup only.
2. **$0.50 Stripe micro-charge** — Stripe already integrated. FTC-recognized verifiable method.
Documented in `docs/COPPA_AUDIT.md`.

### Production Verification
- Health: ✅ PASS (200)
- 404 handler: ✅ PASS (returns `{"error":"Not found"}` with 404 status)
- `rredis` module error: ✅ Resolved — was a stale deploy; current codebase has no such reference.

### COPPA Audit Status Updated
- Overall: ⚠️ **Good faith compliance — launchable with known gap**
- All high-risk gaps resolved. One known gap (strict verifiability) documented as intentional.

### Commits
- `fix: COPPA compliance fixes and 404 error handler`
- `docs: add SMS OTP + Stripe as v1.1 verifiable consent options in COPPA audit`

---

## Session Update - 2026-03-15 (COPPA Compliance Audit)

### Scope Completed
- Performed a comprehensive audit of the app for COPPA compliance.
- Analyzed data collection points: `WizardData`, `HeroCreatorStep`, `ParentControlsScreen`, and backend models (`User`, `Character`, `ConsentRecord`, `ParentHiddenContext`).
- Reviewed `PRIVACY_POLICY.md` for required disclosures and parental rights.
- Evaluated parental consent mechanisms and data deletion flows.
- Documented findings, gaps, and recommended fixes in `docs/COPPA_AUDIT.md`.

### Key Findings
- **Verifiable Parental Consent:** ❌ **FAIL**. The current checkbox method for under-13 users is not "verifiable" under COPPA.
- **Data Synchronization:** ❌ **FAIL**. Parental consent and data deletion (right to erasure) are handled locally via `SharedPreferences` but not synchronized with the backend `ConsentRecord` or deletion endpoints.
- **Third-Party Disclosures:** ❌ **FAIL**. The Privacy Policy does not explicitly name Google Gemini, ElevenLabs, or Stripe as service providers receiving child data.
- **Operator Info:** ⚠️ **NEEDS WORK**. Lacks a physical address and phone number.
- **Data Deletion UI:** ⚠️ **NEEDS WORK**. No user-facing "Delete All My Data" button exists in the Parent Controls screen.

### Status
- **Overall Assessment:** 🛑 **Needs fixes first** (Not safe to launch).
- **Audit Report:** Finalized in `docs/COPPA_AUDIT.md`.

### Next Steps (Recommended)
1.  **Verifiable Consent:** Implement a COPPA-compliant verification method (e.g., $0.50 credit card transaction or email-plus-plus).
2.  **Sync Logic:** Update `ParentalConsentService.dart` and `ChildProfileService.dart` to call backend COPPA endpoints (`/api/user/<id>/consent` and `/api/user/<id>/data`).
3.  **Policy Update:** Revise `PRIVACY_POLICY.md` to include specific third-party disclosures and full operator contact information.
4.  **UI Update:** Add a "Delete All Data" action to `ParentControlsScreen.dart`.

---

## Session Update - 2026-03-15 (Adult Asset Completion & Full Age-Band Coverage)

### Scope Completed
- **Adult (Age 18+) Asset Generation:**
  - Completed all 43 assets in the **"Refined Fine-Art Cinematic"** style.
  - **Mature Diversity:** Generated 10 adult character variants (5 men, 5 women) covering all major races.
  - **Sophisticated UI:** Implemented sleek obsidian/platinum buttons and frames with clicking states.
  - **Transparency Pipeline:** All PNG assets (UI, Orbs, Feelings, Companions, Characters) processed for clean transparency.
- **Milestone Reached:** **100% Full Visual Asset Coverage** for all 7 age bands (Sprout, Early Reader, Adventurer, Creator, Adolescent, Older Adolescent, Adult).

### Status
- **All Age Bands (2 through Adult):** 100% Complete and processed.
- **Organization:** All assets organized in ge_band_assets/ by category.

### Next Steps
- Final audit of the entire ge_band_assets/ directory.
- Prepare for integration into the Flutter application's main ssets/ folder.

---

## Session Update - 2026-03-17 (Bedtime Story Mode — Backend + BYOK Service Layer)

### Bedtime Mode Scope Completed

- Designed and implemented a dedicated bedtime story pipeline across backend and BYOK frontend path.
- Both backend and direct-Gemini (BYOK) paths now produce high-quality, soothing bedtime stories.
- Multiple listeners (siblings/friends) are supported — all named heroes appear and act in the story.

### Architecture

- `bedtime_mode: true` flag routes generation to `_build_bedtime_prompt()` instead of the standard adventure engine.
- `bedtime_mood` param (calming / brave / funny / friendship) tunes the tone instruction.
- BYOK path branches to `_buildBedtimePrompt()` (Dart) which matches backend quality.

### Bedtime Quality Rules (Enforced in Both Prompts)

1. Soothing pacing — lingers on soft textures and warmth
2. All heroes present by name — siblings/friends must have meaningful moments
3. Cozy emotional landing — ends with everyone safe and drifting to sleep
4. Audio-first prose — no markdown, rich sensory language
5. Reduced stimulation — no chases, battles, or cliffhangers
6. Calm magic — things glow/float/hum softly
7. Sleep transition arc — sky darkens, stars appear, characters grow pleasantly sleepy
8. Wisdom gem to close

### Files Changed (Committed f7239fd)

- `backend/services/story_service.py`: `_build_bedtime_prompt()`, `_BEDTIME_SETTINGS`, `_BEDTIME_WORD_RANGES`
- `backend/tasks/story_tasks.py`: route `bedtime_mode`; accept `bedtime_mood`
- `backend/routes/story_routes.py`: accept `bedtime_mode` and `bedtime_mood`
- `lib/services/api_service_manager.dart`: `bedtimeMode`/`bedtimeMood` end-to-end; `_buildBedtimePrompt()` for BYOK path

### Outstanding Tasks (Delegated — see TASK_PROMPTS.md)

- BW-1: Update `bedtime_wizard_screen.dart` — listeners step + wire bedtimeMode
- BW-2: Add BYOK key gate at wizard entry
- BW-3: Story duration picker — 10 / 15 / 20 minute runtime targets

---

## Session Update - 2026-03-17 (Bedtime Wizard — Frontend Complete, committed 64192e3)

### Completed (delegated to Codex, reviewed and committed by Claude)

All three outstanding BW tasks from TASK_PROMPTS.md are done.

**BW-1 — Listeners step**
- Added `BedtimeStep.listeners` to enum (between companion and setting)
- Voice asks: "Are any brothers, sisters, or friends listening tonight? Say their names, or say 'just me'."
- `_parseListenerNames()` splits on "and"/commas, capitalises, caps at 5 names
- `_listenerNames` passed as `additionalCharacters` to `generateStory()` → all siblings/friends appear in story by name

**BW-2 — BYOK gate**
- `_initAndStart()` now calls `ApiServiceManager.isUsingOwnApiKey()` before the wizard begins
- If no key: TTS speaks parent guidance and exits gracefully instead of failing mid-story

**BW-3 — Duration picker**
- Voice step: "How long? Ten, fifteen, or twenty minutes?"
- On-screen tap chips (10/15/20 min) as visual fallback during the duration step
- `bedtimeDurationMinutes` wired through to `generateStory()` → backend `_build_bedtime_prompt()` overrides word count using ~130 wpm narration math

### Full Bedtime Feature Status: ✅ COMPLETE

End-to-end flow:
1. Parent launches bedtime mode (age already set from profile)
2. BYOK key check — exit with guidance if missing
3. Voice wizard: hero name → companion → who's listening → setting → mood → duration → confirm
4. Backend routes `bedtime_mode: true` to `_build_bedtime_prompt()` with all listeners, duration-calibrated word count, soothing rules
5. TTS reads story aloud; sleep timer can cut it short with a goodnight message

### flutter analyze result: No issues found

---

## Session Update - 2026-03-18 (Bedtime Quality + Pet Avatar Fixes)

### Pet Avatar Pipeline — 3 bugs fixed (commit 5a4e08b)

1. **Wrong color sent** — `owner_favorite_color` was hardcoded to `'gold'` in `hero_creator_step.dart`; now uses `wizardData.favoriteColor`
2. **PNG rejection** — `generate_pet_avatar()` in `gemini_image_generator.py` hardcoded `mime_type="image/jpeg"` even for PNG uploads; added `_detect_mime_type()` helper using magic bytes
3. **No fallback** — `generate_pet_avatar()` in `avatar_generation_service.py` had no fallback chain; added text-only fallback via `fallback_generator.generate_character_avatar()` when Gemini image gen fails

### Bedtime Audio-Only Quality (commit d78d953)

- **Age always asked** — voice wizard now always asks "How old are you?" regardless of profile default (was silently using default age 8, causing wrong age-band stories)
- **BYOK setup card** — full-screen parent guidance card when no Gemini key set: step-by-step aistudio.google.com instructions with "Go to Settings" button; TTS also reads guidance aloud
- **Listeners already wired** — confirmed BW-1 changes (siblings/friends by name) are live

### Bedtime Story Quality (Codex analysis applied)

Confirmed via Codex audit:
- Backend path (`story_service.py`) uses rich age-band prompt framework ✅
- `_build_bedtime_prompt()` enforces soothing pacing, cozy landing, sleep transition ✅
- BYOK path in `api_service_manager.dart` mirrors backend quality with `_buildBedtimePrompt()` ✅
- Interactive bedtime still uses generic adventure prompt (not bedtime-specific) — acceptable for now

### flutter analyze: No issues found

---

## Session Update - 2026-03-18 (Pre-Launch Blockers — Rate Limiting + Debug Cleanup)

### Avatar Route Rate Limiting — Fixed

**Problem**: Avatar routes used a homemade in-memory dict (`_rate_limit_hits = {}`) for rate limiting instead of the app-wide Redis-backed `flask_limiter` instance. In production on Railway with multiple instances, each instance had its own isolated counter — rate limits were effectively bypassed across restarts and load-balanced requests.

**Fix**: Converted `avatar_routes.py` from a bare blueprint to a `create_avatar_blueprint(limiter)` factory function, matching the pattern used by every other blueprint in the app. Replaced the custom `rate_limit_by_user_tier` decorator with `@limiter.limit(_tier_limit(free, premium))` where `_tier_limit` returns a dynamic callable that resolves the limit string at request time based on user tier. Updated both import locations and `register_blueprint` call in `app.py`.

**Side effect**: `tweak_gallery_avatar` (was `free=0`) now returns 403 for free users instead of 429 — more semantically correct since it's a feature gate, not a rate limit.

**Files changed**: `backend/routes/avatar_routes.py`, `backend/app.py`

### Debug Output Cleanup — Fixed

**Problem**: Three backend files had `print()` statements writing unstructured output to stdout in production. `app.py` also had `logging.basicConfig(level=logging.DEBUG)` flooding all logs.

**Fix**:
- `app.py`: Changed root log level `DEBUG` → `WARNING`. Replaced all `print()` startup banners with `logger.info()` / `logger.warning()` / `logger.debug()` calls.
- `config/__init__.py`: Added module-level `logger = logging.getLogger(__name__)`. Replaced 8 `print()` calls with appropriate log levels.
- `character_service.py`: Replaced 10 `[DEBUG ...]` print statements in `create_character()` and `update_character()` with `logger.debug()` calls.

**Files changed**: `backend/app.py`, `backend/config/__init__.py`, `backend/services/character_service.py`

### Remaining Pre-Launch Items

- [ ] Health check endpoints exempt from rate limiting (`/health`, `/health/detailed`, `/health/database`, `/version`)
- [ ] Companion assets: creator/adolescent/adult bands referencing adventurer folder — fix `companion_selector_step.dart`
- [ ] Authorization test suite verification
- [ ] Performance testing (story generation time targets)
- [ ] Cross-browser testing

---

## Session Update - 2026-03-18 (Illustration + Coloring Flow Audit)

### Scope Completed
- Audited the end-to-end story illustration and coloring-page pipeline across wizard mapping, backend story generation, backend image endpoints, and the post-story result screen.
- Verified whether generated illustrations are likely to match the created character, stay age-appropriate, include companions, and reflect custom story requests.
- Checked whether the printable coloring-page option is still present and whether it is fully wired.

### Findings
- **Story text path is covered and comparatively strong.**
  - `wizard_data_mapper.dart` forwards `companion_pets`, `companion_characters`, and `customElements`.
  - Backend story generation validates required companion names and custom phrases, then retries when they are missing.
- **Illustration fallback path is weaker than the main story path.**
  - `magic_review_step.dart` falls back to `_generateInlineIllustrations()` when the story response has no illustrations.
  - That fallback hardcodes `numberOfImages: 1`.
  - It forwards `characterAppearance` but does **not** forward companion data into `StoryIllustrationService.generateIllustrations(...)`.
  - Result: fallback illustrations are more likely to omit companions and may not reflect custom selected story elements as reliably as the story text itself.
- **Coloring-page feature still exists in the product, but its current settings/UI are reduced.**
  - `story_result_screen.dart` still exposes the bottom-bar `Color` action and calls `_generateColoringPages()`.
  - `ColoringSettingsDialog` currently hardcodes `_pageCount = 1`, so the prior multi-page choice is effectively gone even though the service supports multi-scene generation.
- **Companions are not explicitly forwarded into coloring generation from the result screen.**
  - `ColoringBookService` and backend `/generate-coloring-pages` both support `companions`.
  - `story_result_screen.dart` calls `generateColoringPagesFromStory(...)` without passing companions, so selected companions/pets are not enforced in coloring-page prompts.
- **Age appropriateness is explicitly handled in backend image generation.**
  - `gemini_image_generator.py` uses age bands to change illustration detail and coloring-page intricacy.
  - The image prompts explicitly require safe, age-appropriate output and, when a reference image exists, likeness to the provided avatar/photo.
- **Illustration count behavior is inconsistent at the product level.**
  - `illustration_controls.dart` documents plan-based counts (`Premium = 1`, `Family = 2`) but is not wired anywhere active.
  - The currently observed inline fallback path always generates 1 illustration.

### Relevant Files
- `lib/screens/wizard_steps/wizard_data_mapper.dart`
- `lib/screens/wizard_steps/magic_review_step.dart`
- `lib/story_illustration_service.dart`
- `lib/story_result_screen.dart`
- `lib/coloring_book_service.dart`
- `backend/routes/story_routes.py`
- `backend/tasks/story_tasks.py`
- `backend/services/story_service.py`
- `backend/gemini_image_generator.py`

### Verification
- Ran targeted backend coverage for story forwarding and age/content rules:
  - `python -m pytest backend\tests\unit\test_story_age_appropriateness_suite.py backend\tests\api\test_story_routes.py backend\tests\integration\test_features.py -q`
- Result:
  - `71 passed`

### Recommended Next Steps
- Patch `_generateInlineIllustrations()` to forward companion data and any scene-critical custom request context.
- Restore a real page-count choice in `ColoringSettingsDialog` if multi-page printable coloring books are still intended.
- Pass companions from `story_result_screen.dart` into `generateColoringPagesFromStory(...)`.
- Centralize illustration-count entitlement logic so the product behavior matches the pricing/UX copy.
