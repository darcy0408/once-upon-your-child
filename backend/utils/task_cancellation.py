"""PERF-04: best-effort Celery-task cancellation via a Redis flag.

Clients POST `/cancel-task/<task_id>` when the user abandons a generation;
the worker checks the flag between phases and skips remaining work. The
flag is best-effort:

- A lost cancel just lets a generation finish (cost = one extra story).
- A stuck cancel auto-clears via the 10-minute TTL.
- A Redis outage fails open (the generation proceeds) so an infrastructure
  hiccup never aborts a paying user's request.
"""
import logging
import os

logger = logging.getLogger(__name__)

_CANCEL_TTL_SECONDS = 600  # outlives any plausible generation


def _get_redis():
    """Connect to Redis using the same env-var pattern as ai_quota._get_redis."""
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    try:
        import redis as redis_lib
        client = redis_lib.from_url(redis_url, socket_connect_timeout=1)
        client.ping()
        return client
    except Exception as exc:
        logger.warning("task_cancellation: Redis unavailable (%s)", exc)
        return None


def _key(task_id: str) -> str:
    return f"cancel:task:{task_id}"


def request_cancellation(task_id: str | None) -> bool:
    """Set the cancel flag for `task_id`.

    Returns True when the flag was written; False if `task_id` was empty
    or Redis was unreachable.
    """
    if not task_id:
        return False
    client = _get_redis()
    if client is None:
        return False
    try:
        client.setex(_key(task_id), _CANCEL_TTL_SECONDS, "1")
        return True
    except Exception as exc:
        logger.warning("task_cancellation: write failed (%s)", exc)
        return False


def is_cancelled(task_id: str | None) -> bool:
    """Read the cancel flag.

    Fail-open: returns False on any error so a Redis hiccup never aborts
    an in-progress generation. Callers should check between phases, not in
    tight loops — the helper opens a fresh Redis connection per call.
    """
    if not task_id:
        return False
    client = _get_redis()
    if client is None:
        return False
    try:
        return bool(client.get(_key(task_id)))
    except Exception:
        return False


def clear_cancellation(task_id: str | None) -> None:
    """Drop the cancel flag. Best-effort cleanup at task completion so the
    key doesn't linger past its useful life (TTL would clean up otherwise)."""
    if not task_id:
        return
    client = _get_redis()
    if client is None:
        return
    try:
        client.delete(_key(task_id))
    except Exception:
        pass
