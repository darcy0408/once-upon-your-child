"""Cross-worker task-ownership tracking via Redis.

/task-status is polled repeatedly and can land on ANY gunicorn worker process
on each request. The owner record written when a task is created must
therefore live somewhere every worker (and the Celery worker service) can see
— a per-process cache does not work.

Before this module existed, ownership was cached via Flask-Caching's `cache`
object, whose CACHE_TYPE defaults to "simple" (an in-process dict) and is
never overridden for production (see backend/config/__init__.py). With
multiple gunicorn workers behind the same URL, whichever worker happened to
handle the original POST /generate-story cached the owner in ITS OWN memory;
a poll that landed on a different worker saw a cache miss, fell through to
Celery result metadata (which does not carry `user_id` for PENDING/PROCESSING
states), and got treated as "owner unknown" -> 404 "Task not found" — even
though the task was genuinely in flight. Polling the same task_id repeatedly
would flip between 200 "processing" and 404 depending on which worker
answered. Storing the owner directly in Redis (shared by every worker and the
Celery worker service) fixes the split-brain.

Mirrors the existing `task_cancellation.py` Redis pattern: best-effort, fails
open/degrades gracefully on any Redis hiccup rather than raising.
"""

import logging
import os

logger = logging.getLogger(__name__)

_OWNER_TTL_SECONDS = 60 * 60 * 24  # 24h — generous vs. any plausible poll window


def _get_redis():
    """Connect to Redis using the same env-var pattern as task_cancellation._get_redis."""
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    try:
        import redis as redis_lib

        client = redis_lib.from_url(redis_url, socket_connect_timeout=1)
        client.ping()
        return client
    except Exception as exc:
        logger.warning("task_owner: Redis unavailable (%s)", exc)
        return None


def _key(task_id: str) -> str:
    return f"task-owner:{task_id}"


def cache_task_owner(task_id: str | None, user_id) -> None:
    """Record which user owns `task_id` in the shared Redis store.

    Best-effort: a Redis outage just means /task-status falls back to
    whatever ownership info the Celery result itself carries.
    """
    if not task_id or not user_id:
        return
    client = _get_redis()
    if client is None:
        return
    try:
        client.setex(_key(task_id), _OWNER_TTL_SECONDS, str(user_id))
    except Exception:
        logger.warning("task_owner: write failed for %s", task_id, exc_info=True)


def resolve_task_owner(task_id: str | None, task) -> str | None:
    """Look up the owning user for `task_id`.

    Checks the shared Redis record first — this is what makes ownership
    visible regardless of which gunicorn worker (or Celery process) answers
    the request — then falls back to the Celery task's own `info`/`result`
    metadata for callers that stashed `user_id` there directly. Returns None
    when no owner can be determined at all.
    """
    if not task_id:
        return None

    client = _get_redis()
    if client is not None:
        try:
            cached_owner = client.get(_key(task_id))
        except Exception:
            logger.warning("task_owner: read failed for %s", task_id, exc_info=True)
            cached_owner = None
        if cached_owner:
            if isinstance(cached_owner, bytes):
                cached_owner = cached_owner.decode("utf-8", errors="replace")
            return str(cached_owner)

    info = getattr(task, "info", None)
    if isinstance(info, dict) and info.get("user_id"):
        return str(info["user_id"])

    result = getattr(task, "result", None)
    if isinstance(result, dict) and result.get("user_id"):
        return str(result["user_id"])

    return None
