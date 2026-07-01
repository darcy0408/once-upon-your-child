# The Crux Choice — Design & Build Plan (Adolescent antihero)

**Goal:** Make the Adolescent (15–17) antihero chapter interactive at its moral apex. The
chapter generates Beats 1–4 + the *setup* of Beat 5 (the two-sided choice), **pauses** and
presents two noir option cards; a **second** generation writes Beats 5–7 (resolution +
aftermath) conditioned on the chosen option, emitting `saga_state` whose `defining_choice`
= the chosen path — so the choice **comes due next issue** via the existing consequence
callback.

Why this design (not full branching, not the kids' interactive engine): morally-grey YA works
through the *depth* of a few pivotal choices, not branch-at-every-beat breadth. One high-stakes
choice at the apse the prompt already builds toward (Beat 5) is the gold-standard register
(Life is Strange / prestige-YA), reuses the whole saga loop, and starts dark instead of
fighting a whimsical engine.

## Principle: additive, single-shot path untouched
The existing `_build_superhero_prompt_adolescent` single-shot builder and the
`generate_story_endpoint` / `generate_story_task` path stay byte-for-byte unchanged. A
feature flag (`cruxChoiceEnabled`) falls back to the single call instantly. Only adolescent +
superhero + flag-on takes the new path.

## Pipeline (verified)
- Client: `magic_review_step._doLaunchStoryCreation` → `ApiServiceManager.generateStory` (one call)
  → renders in **`StoryResultScreen`** (reader layout for age ≥ 11). Saga folded via `recordIssue`.
- Backend: `story_routes.generate_story_endpoint` (sync-first, 202-poll fallback) →
  `story_tasks.generate_story_task` → `PromptService.build_story_prompt` → `_build_superhero_prompt_adolescent`
  (7 beats + `saga_state`) → `_generate_story_text_with_metadata` → moderation → `Story` row.

## Backend design
- Refactor the adolescent builder's shared setup (power/villain/problem, identity fields,
  `continuity_block`, `callback_mandate`) into a private `_antihero_brief(...)` returning a context
  object. **The single-shot builder must produce identical output — guard with a golden/snapshot test.**
- `_build_antihero_prompt_part1(...)` → Beats 1–4 + crux setup; JSON: `pages[4]` + `crux` (one-line)
  + `choices:[{id:"a",text},{id:"b",text}]` (two genuinely two-sided, in-voice options). **No `saga_state`.**
- `_build_antihero_prompt_part2(part1_prose, chosen_choice, ...)` → Beats 5–7; JSON: `pages[3]` +
  full `saga_state` with `defining_choice`/`what_it_cost` **templated from the chosen choice** so the model can't drift.
- `story_tasks`: `run_antihero_part1/2(**kwargs)` wrap prompt-build + LLM + extract + **moderation (both calls)**.
  Part 2 persists the assembled `Story` (Beats 1–7).
- `story_routes`: factor `_build_antihero_task_kwargs`; add `POST /generate-antihero-crux` (runs part 1,
  caches context under a `continuation_token` in Redis ~30-min TTL, **charges quota once here**) and
  `POST /generate-antihero-resolution` (`{continuation_token, choice_id}` → part 2, moderate, persist, return).

## Client design
- `ApiServiceManager.generateAntiheroCrux/Resolution`; parse `crux`/`choices`/`continuation_token`
  in `story_generation_result`.
- `magic_review_step`: adolescent crux branch; **defer `recordIssue` until resolution lands** (`onCruxResolved`).
- `StoryResultScreen`: hold `_continuationToken`/`_cruxChoices`/`_resolutionPages`; render Beats 1–4 (existing
  pager), then `_buildCruxChoicePage` with two noir `_CruxChoiceCard`s; on tap call resolution (reuse
  `MagicalLoadingView`), append Beats 5–7, then fire `onCruxResolved(superheroMeta)`. Assemble pages 1–7 for save.

## Saga wiring (no model change)
Part 2's `saga_state.defining_choice` (templated from the choice) → `superhero_meta.saga_state` →
existing `HeroSaga.recordIssue` auto-captures it into `keyChoices` (+ `what_it_cost`→`whatItCost`) →
next issue's `prior_saga.key_choices` re-injects it into the continuity block → consequence callback.

## Risks
2-call latency (hidden behind reading time; part 1 is shorter) · partial failure between calls (30-min TTL,
idempotent retry, never `recordIssue` until part 2) · **moderate BOTH calls incl. the model-authored choice cards**
· quota charged once (part 1) · saved-story assembled on part-2 completion only · web/CanvasKit choice cards are
plain Material (safe).

## Phased build order
1. **Backend prompt layer + tests** — extract `_antihero_brief`; `_build_antihero_prompt_part1/_part2`; golden test the unchanged single-shot builder; unit-test the two contracts.
2. **Backend run helpers + routes + token cache + tests** — `run_antihero_part1/2`, the two routes, Redis continuation token, moderation on both, Story persist on part 2, quota-once; saga-threading test (`defining_choice` == chosen text).
3. **Client API + state** — `generateAntiheroCrux/Resolution`, result parsing, crux branch with deferred `recordIssue`.
4. **Client UI** — `_buildCruxChoicePage` + noir `_CruxChoiceCard`, append-resolution, saved-story assembly, web smoke.
5. **Feature flag + end-to-end** — verify next issue replays the choice via `prior_saga.key_choices`.

## Status
- [x] Phase 1 — backend prompt layer (`_antihero_brief` + part1/part2 builders; 68 tests, single-shot byte-identical)
- [x] Phase 2 — routes + run helpers (`/generate-antihero-crux` + `/generate-antihero-resolution`, `run_antihero_part1/2`, Redis continuation token, moderation on both, quota-once; shipped in #273)
- [x] Phase 3 — client API + models (`AntiheroCruxResult`/`CruxChoice`, `ApiServiceManager.generateAntiheroCrux`/`generateAntiheroResolution`, `FeatureFlags.cruxChoiceEnabled` default OFF; 7 unit tests)
- [x] Phase 4 — client UI (`StoryResultScreen` crux mode: end-of-story page becomes the two noir `_CruxChoiceCard`s; on tap → resolution → splice Beats 5-7 → `onCruxResolved`)
- [x] Phase 5 — flag wiring + deferred saga (crux branch in `magic_review_step._doLaunchStoryCreation`; `recordIssue` deferred to `onCruxResolved`). **e2e against prod is flag-gated (owner device-verify before flipping `cruxChoiceEnabled` on).**
