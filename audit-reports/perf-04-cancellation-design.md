# PERF-04 Design Proposal: Illustration Cancellation on User Abort

Date: 2026-05-27
Status: Design — awaiting decision before implementation
Audit finding: high. User-abort burns quota and money on illustrations that will never be seen.

## Goal

When the user leaves the story before all illustrations finish, stop the
unstarted illustration calls so the user's quota and the project's
provider-spend aren't burned on images that will never be viewed.

## Current behavior (verified)

`lib/services/per_page_illustration_prefetcher.dart:400-409` — `dispose()`
sets a local `_disposed = true` flag and clears the local queue. Any
already-submitted backend request continues to completion server-side; the
client just throws away the response.

`backend/openrouter_image_generator.py` / `cloudflare_image_generator.py` /
`replicate_image_generator.py` — after PERF-03, each generator submits up to
3 image requests concurrently per story via `ThreadPoolExecutor`. There is
**no** in-task signal to stop the unsubmitted work mid-batch. Once the task
starts, it runs to completion.

On Replicate specifically, a prediction can be cancelled via its REST API
(`POST /v1/predictions/{id}/cancel`) — that's a real lever that today goes
unused.

## Design

### Backend

**New endpoint**: `POST /cancel-task/<task_id>` (auth-required, ownership-checked
via the existing `_resolve_task_owner` helper).

- Sets a Redis key: `cancel:task:<task_id> = 1` with TTL ~10 min (long enough
  to outlive any in-flight generation but short enough to self-clean).
- Returns 202 immediately; the actual cancellation is best-effort.

**Cancellation check** added at three points:

1. `backend/tasks/story_tasks.py` — between major phases (after Gemini story
   generation, before moderation; after moderation, before illustration
   batch). Skip the next phase if `cancel:task:<task_id>` is set.

2. Per-image submission loop in
   `backend/openrouter_image_generator.py`, `replicate_image_generator.py`,
   `cloudflare_image_generator.py` — inside the `_one(i, ...)` function the
   PERF-03 refactor added, before each provider call. Return `None` if
   cancelled. Pre-sized result list filters Nones out as it already does.

3. `backend/replicate_image_generator.py` polling loop — for predictions
   already submitted, call Replicate's
   `client.predictions.cancel(prediction_id)` when the cancel flag flips,
   so the running prediction stops billing. Most other providers don't expose
   a per-call cancel; for those, the in-flight call runs to completion (waste
   of one call's worth, not the whole batch — acceptable).

**Cancellation helper** (one place):

```python
# backend/utils/task_cancellation.py
import os
from flask import current_app

def is_cancelled(task_id: str) -> bool:
    if not task_id:
        return False
    try:
        return bool(current_app.cache.get(f"cancel:task:{task_id}"))
    except Exception:
        return False  # fail open: cancellation is best-effort
```

Plumbing `task_id` into the image generators requires adding it to their
kwargs — the generators don't currently know about Celery task IDs. Either
threadlocal stash on Celery's `current_task.request.id`, or pass through the
kwargs from `story_tasks.py`. The kwargs route is cleaner.

### Frontend

**Hook into prefetcher.dispose()**:

```dart
// lib/services/per_page_illustration_prefetcher.dart:400 (around dispose)
Future<void> dispose() async {
  _disposed = true;
  _queue.clear();
  // PERF-04: tell the backend we're done, so unstarted images don't burn
  // quota. Fire-and-forget; cancellation is best-effort on both sides.
  if (_currentTaskId != null) {
    unawaited(_apiService.cancelTask(_currentTaskId!));
  }
  _client.close();
}
```

Add `cancelTask(taskId)` to whatever API service wraps backend calls (likely
`lib/services/api_service.dart` or similar — verify file). One POST to
`/cancel-task/<id>`, ignore response.

### What this design does NOT do

- It does **not** abort in-flight HTTP requests on the Flutter side. Dart's
  http package can't cancel a request mid-flight cleanly. The
  client-side abort is purely "stop checking the result"; the wire request
  finishes on the backend.
- It does **not** abort a provider call that's already mid-stream. Only
  unstarted work in the batch and (for Replicate) cancellable predictions
  are stopped.
- It does **not** delete a partially-completed Story row. The cancel is a
  cost-saver, not a state-rollback. Whatever pages got generated stay
  recoverable via `/task-status` (R2 path in story_routes.py).

## Effort estimate

- New `/cancel-task` endpoint: ~30 lines, S.
- `is_cancelled` helper + 3 check sites: ~50 lines across 4 files, S.
- Replicate per-prediction cancel: ~15 lines, S.
- Plumb `task_id` into the image generators' kwargs: ~10 lines × 4 files, S.
- Flutter `cancelTask` API call + prefetcher hook: ~30 lines, S.
- **Total: about half a day, fully self-contained.**

## Open questions before implementation

1. What's the actual hot path on the Dart side that holds `task_id`? Need
   to confirm `per_page_illustration_prefetcher.dart` knows its task id
   (or get it from wherever it does).
2. Which Flask cache backend backs `cache.get` — Redis or in-memory? For
   the cancel signal to reach the Celery worker, both sides must read the
   same store. With prod Redis, that's fine; the eager-mode dev path may
   need a fallback.
3. Quota refund policy: if the user cancels mid-batch, do we refund the
   unstarted illustration quota? Current quota deduction probably happens
   at task start. Decide whether cancellation refunds.
4. Should the cancel endpoint also be hit on app suspend (background
   transition) or only on explicit user navigation? Probably explicit
   only — background isn't necessarily abandonment.

## Related findings

- Independent of PERF-01 (streaming) — both can land in either order.
- After PERF-03 (parallel illustrations), the value of PERF-04 increases:
  parallel illustrations means at the moment of cancel, more images are
  in-flight, more is saved by stopping the not-yet-started ones.
