# PERF-01 Design Proposal: Streaming Story Generation

Date: 2026-05-27
Status: Design — awaiting decision before implementation
Audit finding: critical. p50 ~55s blank-spinner wait; target time-to-first-paragraph (TTFP) ~5s.

## Goal

Render the story incrementally so the user sees content within ~5s while the
remaining pages continue generating in the background. The total compute is
unchanged — perceived latency drops by ~90% on the happy path.

## Current architecture (relevant to the decision)

```
client ──POST /generate-story─▶ Flask request thread
                                  │
                                  ├─▶ (sync attempt) ThreadPoolExecutor wraps
                                  │     generate_story_task; blocks request
                                  │     thread for up to ~75-240s.
                                  │
                                  └─▶ (on timeout/error) Celery .delay()
                                        │
                                        ▼
                                  lovely-perfection worker
                                        │
                                        ▼
                                  Gemini single call → full story →
                                  validation loop → moderation →
                                  Story row persisted → result in Redis
                                        ▲
client ◀──poll /task-status/<id>─┘
```

The worker emits no intermediate progress today. The full story arrives only
when generation+validation+moderation all complete.

## Three transport options

### Option A — Incremental polling (RECOMMENDED)

The worker writes each page (or each prompt-chunk completion) to a Redis hash
keyed by `task_id` as it finishes. `/task-status/<task_id>` is enhanced to
return whatever pages have completed so far plus a `progress` discriminator.
Client polls every ~2-3s and renders the partial story.

```
worker phase                       redis key:value                  client view
──────────────────────────────────────────────────────────────────────────────
gemini call returns                progress:<id> = generating       (skeleton)
parse page 1                       pages:<id>:0 = {…page 1 JSON…}   page 1 renders
parse page 2                       pages:<id>:1 = …                 page 2 renders
…
moderation pass complete           progress:<id> = complete         story finalized
```

**Pros**
- No new infrastructure. Worker→Redis→Flask→client is already the path used
  for final results — this is the same wire with finer-grained writes.
- Survives client disconnects naturally (state lives in Redis).
- Trivially compatible with gunicorn prefork workers (no long-lived
  connections held in the request thread).
- Backwards compatible: clients that don't poll for partials still get the
  final result.

**Cons**
- Client makes more HTTP calls (one every 2-3s). Adds load on the Flask side.
- Polling interval is the floor for TTFP — picking 2s sets TTFP at min ~2s
  after page 1 lands.
- Worker has to know how to emit per-page state, which means the Gemini call
  needs to be either streamed or post-parsed into pages before completion.
  Gemini SDK does support streamed generation; the worker would need to
  consume chunks rather than awaiting the full response.

**File touch points (~6-10 files, M-L effort)**
- `backend/services/story_generation_service.py:140-245` — switch from
  `generate_content` to `generate_content_stream`, parse pages as chunks arrive.
- `backend/tasks/story_tasks.py` — accept the streaming generator, write
  each parsed page to Redis as it materializes. New helper `_emit_page(task_id, idx, page)`.
- `backend/celery_config.py` — confirm Redis client config is shared with the
  Flask side (it already is via REDIS_URL).
- `backend/routes/story_routes.py:847` (`/task-status`) — return
  `{status: "streaming", pages: [...completed...], total_expected: N}` when a
  generation is in-flight with partial state.
- `lib/services/story_polling_service.dart` (or whatever does /task-status
  polling now — verify) — switch from "wait for complete" to "render as pages
  arrive."
- `lib/story_result_screen.dart` and `lib/illustrated_story_viewer.dart` —
  accept a `Stream<StoryPage>` (or repeated rebuilds with a growing page list)
  and render incrementally.
- Probably a new `StoryStreamState` model on the Dart side.

**Risk**
- The Gemini stream API may return content in token-sized chunks that don't
  align with page boundaries. The worker needs a tolerant parser that
  identifies page breaks from the streamed text. Page format is currently
  delimited (numbered headings, JSON structure?) — verify before committing.

### Option B — Server-Sent Events (SSE)

Add a new `/stream-story?task_id=<id>` endpoint. Flask returns a streaming
response that subscribes to a Redis pub/sub channel; worker publishes per-page
events. Client opens an EventSource (or http chunked-response consumer on
mobile).

**Pros**
- True push, no polling overhead.
- Lower latency on each page handoff (worker emits → server forwards
  immediately).

**Cons**
- New infrastructure: Flask SSE pattern requires holding the request thread
  open for the duration of the generation, which conflicts with the
  gunicorn-prefork-2-workers config (PERF-09). Switching to a threaded /
  gevent worker class is a real change.
- Mobile HTTP client support for EventSource is decent (Dart `http` package
  supports streamed responses) but more brittle on flaky networks than
  polling — reconnect/resume semantics need handling.
- Sentry/observability stack assumes short-lived requests; long-lived stream
  requests will distort RED metrics.

**File touch points**
- New blueprint or new route in `backend/routes/story_routes.py`.
- Redis pub/sub wiring in the worker.
- `Dockerfile` / `railway.toml` gunicorn config: switch to `--worker-class gevent`
  or use a separate streaming-only service.
- Client SSE consumer in Dart.

**Risk**
- Holding 1 of 2 gunicorn workers open for the whole streaming duration is
  worse than today for concurrency. Either bump workers (PERF-09) AND switch
  worker class, or accept the regression.

### Option C — Chunked HTTP on `/generate-story` itself

Have `/generate-story` itself return a chunked response, streaming pages out
of the request thread as they're generated.

**Pros**
- One endpoint, no polling, no SSE infra.

**Cons**
- Generation runs in the Celery worker, not the request thread, so the
  request thread would still need to subscribe to a Redis pub/sub bridge
  for the worker's progress — same complexity as SSE, just on the original
  endpoint.
- Inherits the same prefork-worker concurrency problem as SSE.
- No graceful resume on network drop (mid-stream disconnect = lost story).

**Recommendation: skip.** All the downsides of SSE without the cleaner
separation.

## Recommendation: Option A (polling)

Best fit for the existing Celery+Redis+gunicorn-prefork architecture. No
infra change required. Worker simply gains "emit per-page" semantics; client
gains "render partial state" semantics. Two cleanly scoped changes.

Polling interval suggestion: **2.5s for first 15s, 4s after**. Adaptive
backoff keeps TTFP tight while reducing late-stage poll load.

## Open questions before implementation

1. Does Gemini's streamed-generation output preserve page-delimited structure
   well enough for a tolerant parser, or do we get token-level chunks that
   need accumulation? (Inspect: `backend/services/story_generation_service.py`
   for current parse logic; test against `generate_content_stream`.)
2. Are page breaks marked in the prompt template such that a streaming parser
   can recognize them? (Inspect: `backend/services/prompt_service.py`.)
3. The LLM moderation pass (PERF-11) currently runs on the whole story after
   generation. Under streaming, moderation should run per-page as pages
   arrive — that's the PERF-11 unlock. Bundle the design.
4. Backwards-compat policy: do we keep the current /task-status final-only
   response shape, or break-and-bump?
5. Quota deduction is currently done on the route after the sync attempt
   succeeds (`story_routes.py:730`). Under streaming, when does the quota
   tick — first page? final page? Probably final, so a partial-only failure
   doesn't consume quota.

## Effort estimate

- Backend: 1-2 days for stream parsing + Redis emit + route changes.
- Frontend: 1-2 days for partial-render handling and per-page reveal.
- Combined: ~3-4 days end-to-end, plus an integration session.

## Related findings

- PERF-11 (per-page moderation) becomes feasible only after PERF-01 lands.
  Bundle the two.
- PERF-02 is closed; this proposal doesn't change the sync-then-async flow,
  it adds a partial-state polling layer on top of the existing async path.
