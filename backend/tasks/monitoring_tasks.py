"""Scheduled reliability monitoring (FMEA findings SE1, B2, W1/W2).

Runs on the Celery-beat schedule (see backend/celery_config.py). Every tick it
checks signals that otherwise fail completely silently and raises an alertable
Sentry warning when a threshold is breached:

  - Celery broker queue depth — a backlog means the single worker is stuck or
    overwhelmed (W1/W2) and tasks are piling up unprocessed.
  - data-retention purge heartbeat staleness — the daily COPPA/GDPR purge has
    stopped firing (B2). `retention:last_run` is written to Redis by
    backend.tasks.retention_tasks after each successful purge.

Note: this task runs on the same worker it monitors, so a fully wedged worker
delays the monitor too. It still catches a growing backlog and a stale purge
once it does run; a truly independent monitor would need separate infra.
"""
import json
import os
from datetime import datetime, timezone

from celery.utils.log import get_task_logger

# Prevent default app initialization during import — this task needs only
# Redis, not a Flask app context.
os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")

from backend.celery_config import celery

logger = get_task_logger(__name__)

# Thresholds — overridable via env so they can be tuned without a code deploy.
QUEUE_DEPTH_ALERT_THRESHOLD = int(os.getenv("QUEUE_DEPTH_ALERT_THRESHOLD", "20"))
RETENTION_HEARTBEAT_MAX_AGE_HOURS = int(
    os.getenv("RETENTION_HEARTBEAT_MAX_AGE_HOURS", "36")
)
# Default Celery queue name for the Redis broker (kombu stores it as a list).
_CELERY_QUEUE_NAME = os.getenv("CELERY_DEFAULT_QUEUE", "celery")


def _redis_client():
    """Return a Redis client, or None when no Redis URL is configured."""
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    import redis as _redis_lib

    return _redis_lib.from_url(redis_url, socket_connect_timeout=2)


def _alert(signal: str, **detail) -> None:
    """Emit an alertable reliability signal: a WARNING log plus a Sentry message.

    The log line is the guaranteed signal; the Sentry message is what the
    dashboard alert rules key off. Sentry failures (e.g. the SDK not yet
    initialised on a fresh worker) degrade silently to the log.
    """
    logger.warning("RELIABILITY ALERT: %s %s", signal, detail)
    try:
        import sentry_sdk

        with sentry_sdk.push_scope() as scope:
            scope.set_tag("reliability_signal", signal)
            for key, value in detail.items():
                scope.set_tag(key, value)
            sentry_sdk.capture_message(signal, level="warning")
    except Exception:  # noqa: BLE001 — monitoring must never raise
        logger.debug("Sentry capture for %s failed", signal, exc_info=True)


@celery.task(name="backend.tasks.monitoring_tasks.system_monitor_task")
def system_monitor_task() -> dict:
    """Beat-scheduled reliability check. Returns a summary dict of what it saw."""
    result: dict = {}
    client = _redis_client()
    if client is None:
        logger.warning("system_monitor_task: no REDIS_URL — monitoring skipped")
        return {"skipped": "no_redis"}

    # --- Celery queue depth (W1 / W2) ---
    try:
        depth = client.llen(_CELERY_QUEUE_NAME)
        result["queue_depth"] = depth
        if depth >= QUEUE_DEPTH_ALERT_THRESHOLD:
            _alert(
                "celery_queue_depth_high",
                depth=depth,
                threshold=QUEUE_DEPTH_ALERT_THRESHOLD,
            )
    except Exception:  # noqa: BLE001
        logger.warning("system_monitor_task: queue-depth check failed", exc_info=True)

    # --- Data-retention purge heartbeat staleness (B2) ---
    try:
        raw = client.get("retention:last_run")
        if raw is None:
            # No heartbeat ever written. Expected briefly after a fresh deploy
            # (the purge runs daily at 03:30 UTC) — log only, do not alert.
            result["retention_heartbeat"] = "missing"
            logger.info("system_monitor_task: retention heartbeat not yet present")
        else:
            data = json.loads(raw)
            last = datetime.fromisoformat(data["timestamp"])
            if last.tzinfo is None:
                last = last.replace(tzinfo=timezone.utc)
            age_hours = (datetime.now(timezone.utc) - last).total_seconds() / 3600.0
            result["retention_heartbeat_age_hours"] = round(age_hours, 1)
            if age_hours > RETENTION_HEARTBEAT_MAX_AGE_HOURS:
                _alert(
                    "retention_purge_heartbeat_stale",
                    age_hours=round(age_hours, 1),
                    max_age_hours=RETENTION_HEARTBEAT_MAX_AGE_HOURS,
                )
    except Exception:  # noqa: BLE001
        logger.warning(
            "system_monitor_task: retention-heartbeat check failed", exc_info=True
        )

    logger.info("system_monitor_task summary: %s", result)
    return result
