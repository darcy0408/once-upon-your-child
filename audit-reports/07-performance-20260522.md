# Story Weaver Performance Audit (07)

Date: 2026-05-22
Scope: Flutter client (mobile + web), Flask + Celery + Redis backend, Isar local
DB, Railway deploy, Gemini story + illustration pipeline.
Author: Performance audit pass 07.

## Executive Summary

Story Weaver's user-visible latency is dominated by AI calls, not client code.
The Flutter cold start is healthy (~1.8s p50 estimate) and the wizard has only
minor, fixable jank. The pain is the wait for an AI-generated story and its
illustrations.

Top 5 hotspots and the projected impact of fixing each:

1. **No streaming on story generation (Critical).** The user watches a blank
   spinner for an estimated 40-110s while the whole story is generated,
   validated, and moderated before anything renders. Streaming pages as they
   arrive brings time-to-first-paragraph under ~5s - a perceived-latency cut of
   roughly 90% with no change in total compute.
2. **Sync-then-async fallback double-generates (Critical).** On timeout the
   backend abandons a synchronous attempt and restarts generation
   asynchronously, so the unhappy path pays for ~two full stories (120-240s).
   Collapsing to one path removes the ~240s p99 tail.
3. **Sequential illustration generation (Critical).** A 4-image story renders
   images one at a time (~90-300s). Generating them concurrently cuts wall time
   toward a single image (~30-90s) at identical token cost.
4. **114 MiB Android App Bundle (High).** ~73 MiB of raw PNG assets are bundled.
   Converting to WebP and resizing to display resolution should land the AAB
   under 50 MiB, more than halving install and first-download size.
5. **Firebase init blocks cold start (High).** `Firebase.initializeApp()` runs
   before the first frame though analytics collection is disabled at init.
   Deferring it post-frame removes 100-500ms from every launch.

Fixing hotspots 1-3 targets the dominant complaint (the generation wait); 4-5
are low-effort install-size and startup wins.

Caveat: this audit ran from a static checkout. Build sizes and the cold-start
call sequence are measured; all latency figures are code-derived estimates with
sample size 0 - no device profiling or load test was possible, so the audit's
>=50-sample rigor target is not met. Recommendation R0 is to capture real
baselines before committing to the fix projections above.

## Status as of 2026-05-27 (follow-up session)

Live status of each finding. Companion docs in `audit-reports/` for design
proposals and the toolchain hypothesis.

| ID | Status | Notes |
|----|--------|-------|
| PERF-01 | Backend done; UI consumer pending | Slices 1-4 implemented: `StoryGenerationService.generate_story_stream`; `_try_gemini` emits `partial_story:<task_id>` to Redis on each chunk; `/task-status` returns `partial_text` on PROCESSING/PENDING-with-partial; `generateStory(..., onPartial:)` callback plumbed in Dart. Slice 5 (story_result_screen consumer) deferred — UX-design call on partial-render presentation |
| PERF-02 | Closed (stale) | Already implemented as "A3" + "X2" in `story_routes.py:734-802` before this audit ran |
| PERF-03 | Done | 3 image generators parallelized via `ThreadPoolExecutor`, concurrency cap via `ILLUSTRATION_CONCURRENCY` env (default 3). `gemini_image_generator.py` deliberately left alone — audited reference was a string-assembly helper, not a gen loop |
| PERF-04 | Backend foundation done | `backend/utils/task_cancellation.py` (helper); `POST /cancel-task/<task_id>` (auth + ownership); `generate_story_task` bails early when flag is set. PENDING: per-image cancel checks (need `task_id` threaded into the 4 image generators), Flutter `prefetcher.dispose()` hook. Design in `perf-04-cancellation-design.md` |
| PERF-05 | Done | Firebase init deferred to post-frame in `main.dart` |
| PERF-06 | Done | `isar_service_io.dart:39` — `inspector: !kReleaseMode` |
| PERF-07 | Closed (stale) | WebP conversion already complete from a prior session; 0 PNGs remain in 11 target dirs; see `perf-07-webp-finding.md` |
| PERF-08 | Source done, regen blocked | `@Index` on theme/isFavorite/isInteractive added in source; harmless. Inert until `build_runner` regen — see toolchain doc |
| PERF-09 | Blocked | Railway MCP token expired this session; needs re-auth before checking service memory |
| PERF-10 | Done | TTS prewarm now bounded by 45s wall-clock budget; phrase list untouched |
| PERF-11 | Blocked | Bundle with PERF-01 implementation — per-page moderation only makes sense atop streaming |
| PERF-12 | Done | Companion DB lookups batched (one `IN`-query); output order preserved |
| PERF-13 | Done | `SafeAssetImage` gained `cacheWidth`/`cacheHeight`; theme cards decode at ~600px instead of source resolution |
| PERF-14 | Pending | Needs running-app verification, not autonomous-safe |
| PERF-15 | Done | `ListView.builder` in `main_story.dart` and `child_profile_switcher.dart`. `achievements_screen.dart:152` correctly identified by the agent as a false positive (already optimal — dynamic content is in a child `GridView.builder`) |
| PERF-16 | Done | `main.dart.js` measured at 15.2 MiB uncompressed; CanvasKit 32 MiB |
| R0 | Runbook ready | `r0-baseline-capture-runbook.md` — execute when device + staging available |
| Toolchain (related) | Hypothesis ready | `toolchain-fix-research.md` — pin `analyzer: ^5.12.0` instead of 6.3.0; one-line test |

The whole project passes `flutter analyze` clean after these changes
(verified 2026-05-27). `flutter build web --release` builds cleanly.
Working tree is uncommitted at audit-author request.

## Measurement Limitations

This audit was run from a read-only repository checkout. The following
measurements are **empirical** (directly observed): build artifact sizes,
dependency graph, asset inventory, gunicorn configuration, and the cold-start
call sequence.

All **latency figures are code-derived estimates**. No device profiling
(`--trace-startup`, DevTools timeline), no synthetic load test, and no
Railway/Flower/Redis metrics run was possible in this environment. Per the
audit's error-handling rules, timing degrades to code-path analysis with
reduced precision. Consequently every row in the per-segment table carries a
**sample size of 0** and an `Environment` of "code-derived estimate". The
audit's statistical-rigor target (>=50 samples per p95) is **not met** and
cannot be met without a profiling run; estimates are presented as ordering and
order-of-magnitude guidance, not validated baselines. Fabricating sample data
to satisfy the schema would defeat the purpose of an empirical audit, so it was
not done. See Recommendation R0.

## Performance Budget

Targets as specified for this audit. One target is flagged as infeasible under
the current architecture.

| Metric | Target | Feasible as stated | Note |
|--------|--------|--------------------|------|
| App cold start | <= 2s | Borderline | Achievable after deferring Firebase init (see PERF-05) |
| Story generation p50 | <= 8s | No | A synchronous full-story LLM call cannot finish in 8s. Re-baseline around streaming: time-to-first-paragraph <= 5s |
| Story generation p95 | <= 20s | No | Same; current p95 estimate ~110s |
| Frame rate | >= 60fps (frames <16ms) | Yes | Reachable; wizard has fixable jank sources |

The p50/p95 story-generation targets assume a fast atomic response. The product
generates a multi-page story plus runs a validation loop and an LLM moderation
pass; that is inherently tens of seconds. The realistic, user-honest budget is a
**perceived-performance** budget: stream the first paragraph within 5s and show
deterministic progress thereafter. This is treated as the working target below.

## Baseline Measurements

Empirical (directly measured 2026-05-22):

| Item | Value | Source |
|------|-------|--------|
| `app-release.aab` | 114.4 MiB (120,005,846 bytes) | build/app/outputs/bundle/release |
| R8 `mapping.txt` | 39.8 MiB | build/app/outputs/mapping/release |
| Bundled assets (registered in pubspec) | ~73 MiB | pubspec.yaml:121-180 + du |
| `assets/.png-backup` | 358 MiB | Not registered - repo bloat, not shipped |
| `assets/BoyGirl images` | 28 MiB | Not registered - repo bloat, not shipped |
| Dart source files | 332 | lib/ |
| gunicorn config | 2 workers, prefork, 120s timeout | railway.toml:17 |
| Celery task time limit | 600s | backend/celery_config.py |
| Web JS bundle | not built | No build/web present |
| iOS IPA | not built | No artifact present |

Per-segment latency estimates: see `perf-traces/segment-latency.csv`.
Cold-start step-by-step trace: see `perf-traces/coldstart-path.md`.
Bundle inventory: see `perf-traces/bundle-inventory.csv`.

## Hotspot Map

Ranked by user-visible impact. Severity scale: Critical = user-facing latency
exceeds target by >= 2x; High = significant but below 2x or install/concurrency
impact; Medium = noticeable; Low = minor.

| Rank | Hotspot | Segment | Severity | User-visible impact |
|------|---------|---------|----------|---------------------|
| 1 | Synchronous full-story generation, no streaming | Story generation | Critical | User stares at a spinner 40-110s with zero content |
| 2 | Sync-then-async fallback double-generates on timeout | Story generation | Critical | Unhappy path pays for ~2 full generations: 120-240s |
| 3 | Sequential multi-image illustration generation | Illustration | Critical | 4-image story takes 90-300s instead of ~1x single image |
| 4 | 114 MiB AAB / ~73 MiB raw-PNG bundled assets | Bundle size | High | Large install, slow first download, Play Store friction |
| 5 | Firebase init blocks cold start | Cold start | High | +100-500ms before first frame, every launch |

Secondary hotspots (PERF-04, 06, 08-15) are listed in Recommendations.

## Per-Segment Latency

All values code-derived estimates; sample size 0. Full CSV in
`perf-traces/segment-latency.csv`.

| Segment | p50 | p95 | Dominant cost |
|---------|-----|-----|---------------|
| Cold start (subsequent launch) | 1.8s | 3.2s | Isar open + Firebase init |
| Cold start (first-ever launch) | 2.6s | 4.8s | + SharedPrefs->Isar migration (one-time) |
| Wizard frame build | 12ms | 22ms | Large `build()` rebuilds, image decode on UI thread |
| Story generation - happy path | 55s | 110s | Gemini API roundtrip + validation loop |
| Story generation - unhappy path | 130s | 240s | Sync attempt times out, async retry regenerates |
| LLM content moderation | 15s | 30s | Serial post-generation classifier call |
| Illustration - per image (Gemini) | 30s | 90s | Provider API roundtrip |
| Illustration - 4-image set (sequential) | 90s | 300s | No parallelism across images |
| Isar story-list query | 50ms | 100ms | Load-all + filter in Dart, no index |
| Flask non-generation request | 120ms | 400ms | Per-request DB work |

Outlier note (p99 >> p95): the story-generation p99 (~300s) is driven by the
unhappy fallback path stacking a sync timeout, an async retry, a failed
validation pass, and a moderation-triggered regeneration. This is a distinct
failure mode, not a tail of the baseline distribution, and is addressed by
PERF-02 and PERF-11 independently of the happy-path budget.

## Findings

Schema: ID | Hotspot | Segment | Impact | Current | Target | File:Line |
Remediation | Effort (S < 0.5d, M 0.5-2d, L > 2d).

| ID | Hotspot | Segment | Impact | Current | Target | File:Line | Remediation | Effort |
|----|---------|---------|--------|---------|--------|-----------|-------------|--------|
| PERF-01 | No streaming; user waits for whole story | Story generation | Critical | p50 ~55s blank wait | First paragraph <= 5s | backend/services/story_generation_service.py:140 | Stream pages as generated; emit time-to-first-paragraph; render pages incrementally client-side | L |
| PERF-02 | Sync-then-async fallback regenerates on timeout | Story generation | Critical | Unhappy path 120-240s | Single generation path | backend/routes/story_routes.py:476,692 | Pick one path. Keep async+polling; drop the sync attempt, or cap it at 45s and reuse its partial result instead of restarting | M |
| PERF-03 | Multi-image illustration generated sequentially | Illustration | Critical | 4 imgs 90-300s | ~1x single-image latency | backend/gemini_image_generator.py:141; backend/openrouter_image_generator.py:233 | Generate images concurrently (thread pool / asyncio.gather) with a batch wall-clock cap | M |
| PERF-04 | No cancellation when user abandons story | Illustration | High | Discarded pages still generate, burn quota + cost | Abort in-flight on screen dispose | lib/services/per_page_illustration_prefetcher.dart:400 | Send a cancel signal to backend on dispose; add a backend abort token that stops Replicate polling / skips unstarted images | M |
| PERF-05 | Firebase init blocks first frame | Cold start | High | +100-500ms every launch | Off critical path | lib/main.dart:87 | Move FirebaseAnalyticsService.initialize() into the existing postFrameCallback (collection is disabled at init, nothing is lost) | S |
| PERF-06 | Isar inspector enabled in release | Cold start / DB | Medium | DB-open + per-txn overhead in prod | Inspector off in release | lib/services/isar_service_io.dart:39 | Set `inspector: !kReleaseMode` | S |
| PERF-07 | 114 MiB AAB; ~73 MiB raw PNG assets bundled | Bundle size | High | Large install / slow first load | < 50 MiB AAB | pubspec.yaml:121-180 | Convert bundled PNGs to WebP; resize to max display resolution; drop unused archetype variants | M |
| PERF-08 | Story list loaded from JSON and filtered in Dart | Story display / DB | High | O(n) 50-100ms per screen open | Indexed query < 10ms | lib/storage_service.dart:12; lib/saved_stories_screen.dart:87 | Query stories through Isar with `@Index` on theme / isFavorite; paginate | M |
| PERF-09 | gunicorn 2 prefork workers, 120s timeout | Backend concurrency | High | 2 concurrent long requests saturate the service | 4+ workers; long work off request thread | railway.toml:17 | Raise worker count; move /generate-interactive-story onto Celery so it does not pin a worker | S |
| PERF-10 | TTS prewarm fires ~100 phrase syntheses with retries | Cold start / network | Medium | 30-60s network saturation, 429 risk | Bounded, lazy prewarm | lib/services/app_tts_service.dart:221 | Cap prewarm phrase count, add a total wall-clock timeout, prewarm lazily on first reader open | M |
| PERF-11 | LLM moderation runs serially after generation | Story generation | High | +10-30s; failure triggers full regeneration | Overlap with generation | backend/tasks/story_tasks.py:1335 | Run moderation per-page as pages stream in; only regenerate the flagged page, not the whole story | M |
| PERF-12 | N+1 companion/character DB lookups | Story generation | Low | 25-250ms under load | Single batched query | backend/tasks/story_tasks.py:806 | Fetch all companion characters in one query | S |
| PERF-13 | Large images decoded on UI thread | Wizard flow | Medium | Scroll jank, frames > 16ms | Decode at display size | lib/quick_story_screen.dart:260 | Wrap theme/avatar images in `ResizeImage`; `precacheImage` on route entry | S |
| PERF-14 | Creation screens rebuild whole form per keystroke | Wizard flow | Medium | Input lag during character creation | Scoped rebuilds | lib/character_creation_screen_enhanced.dart:821 | Split into smaller widgets; isolate text fields so typing does not rebuild avatar preview | M |
| PERF-15 | `ListView(children: [...])` on dynamic lists | Story display | Medium | Whole list materialized; laggy scroll | Lazy `ListView.builder` | lib/achievements_screen.dart:152 | Convert dynamic lists to `ListView.builder` | S |
| PERF-16 | Web JS bundle never measured | Bundle size | Unconfirmed | Unknown | Measured baseline | n/a | Run `flutter build web --release`, measure `main.dart.js` + CanvasKit, re-audit | S |

## Coverage Check

| Area | Measured | Method |
|------|----------|--------|
| Client startup | Yes | Cold-start path trace from main.dart |
| Wizard flow | Yes | Code review of creation screens (PERF-13/14) |
| Story generation | Yes | Backend pipeline trace (PERF-01/02/11/12) |
| Story display | Yes | Isar + ListView review (PERF-08/15) |
| Offline access | Yes | offline_story_cache O(n) JSON load identified |
| Payments | Yes | SubscriptionService deferred post-frame; network retry path reviewed - not a latency hotspot |

## Recommendations

Ordered by user-visible impact per unit effort.

**R0 - Establish real baselines (prerequisite).** Run `flutter build` with
`--trace-startup` on a representative mid-tier 2022 Android device and a modern
iOS device; capture a DevTools timeline through the wizard; run >=50 synthetic
story generations against a non-production environment. Without this, every
number in this report stays an estimate. The audit's statistical-rigor target
cannot be satisfied any other way.

**R1 - Stream the story (PERF-01).** The single largest perceived-latency win.
Stream pages from Gemini and render them as they arrive so the first paragraph
appears within ~5s. Re-baseline the budget around time-to-first-paragraph.

**R2 - Collapse the dual generation path (PERF-02).** Eliminate the
sync-then-async fallback that regenerates on timeout. This removes the ~240s
unhappy-path tail with no architectural rewrite.

**R3 - Parallelize illustrations (PERF-03).** Generate the N images of a story
concurrently. Cuts a 4-image set from ~300s p95 toward a single-image latency.

**R4 - Cheap cold-start wins (PERF-05, PERF-06).** Defer Firebase init and
disable the Isar inspector in release. Combined: ~100-500ms off every launch,
both small edits.

**R5 - Shrink the bundle (PERF-07).** Convert bundled PNGs to WebP and resize to
display resolution; this is the project's standing WebP-rewrite work applied to
the asset bundle. Target an AAB under 50 MiB.

**R6 - Index local queries and parallelize moderation (PERF-08, PERF-11).**
Index Isar story queries; run moderation per-page alongside streaming so it
stops being a serial 10-30s tax.

### Cost-of-performance tradeoff

- **Saves user time AND provider cost:** PERF-03 (parallel images - same token
  spend, less wall time), PERF-04 (cancellation - stops paying for discarded
  illustrations), PERF-08 (local index - no provider involved).
- **Saves user time, neutral on cost:** PERF-01, PERF-02, PERF-05, PERF-11.
- **Saves cost, neutral on user time:** illustration cache (already in place and
  effective per the pipeline trace).

### Perceived-performance notes

The illustration prefetcher already does the right thing: background fetch with
idle/queued/loading/ready/failed states and skeleton rendering. Story-text
generation does not - it offers a single undifferentiated spinner. Bringing the
story flow up to the prefetcher's standard (skeleton + deterministic progress +
incremental reveal) is most of the perceived-performance gap. Do not remove
loading animations that aid child comprehension purely to chase a metric.

## Environment-Parity and Unconfirmed Items

- PERF-16: web JS bundle is unmeasured because no web build exists. Flagged
  Unconfirmed, not closed.
- Railway container cold start is unmeasured (no metrics access). A
  production-vs-staging perf gap, if later observed, must be resolved by
  environment-parity work, not by profiling production.
- All latency rows are Unconfirmed pending R0. They are internally consistent
  with the code paths but have not been reproduced under load.
