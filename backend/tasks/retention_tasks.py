"""Scheduled data-retention task (CMP-5 / PP-13).

Runs on the Celery-beat schedule (see backend/celery_config.py). Once per day
it anonymises every account that has been inactive beyond the configured
retention window (``DATA_RETENTION_INACTIVE_DAYS``, default 730 days), enforcing
the deletion promise in PRIVACY_POLICY.md.

The heavy lifting lives in backend.services.data_retention.purge_inactive_accounts;
this module only wires it into Celery with a Flask app context.
"""

import json
import os
from datetime import datetime, timezone

from celery.utils.log import get_task_logger

# Prevent default app initialization during import so we control app context.
os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")

from backend.celery_config import celery

logger = get_task_logger(__name__)

# Lazy Flask app initialization to avoid circular imports (mirrors story_tasks).
_flask_app = None


def _write_retention_heartbeat(summary: dict) -> None:
    """Best-effort heartbeat write so the daily purge can be monitored.

    Stores the current UTC timestamp plus the purge summary as JSON under the
    Redis key ``retention:last_run`` with NO expiry, so an external check can
    alert if the purge silently stops running. A Redis outage logs a warning
    but never fails the purge task itself.
    """
    try:
        redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
        if not redis_url:
            logger.warning(
                "Data-retention purge: no REDIS_URL/REDIS_PRIVATE_URL — "
                "heartbeat not written"
            )
            return
        import redis as _redis_lib

        r = _redis_lib.from_url(redis_url, socket_connect_timeout=2)
        payload = json.dumps(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "summary": summary,
            }
        )
        r.set("retention:last_run", payload)
    except Exception as exc:
        logger.warning("Data-retention purge: failed to write heartbeat (%s)", exc)


def get_flask_app():
    """Lazy initialization of the Flask app to avoid circular imports."""
    global _flask_app
    if _flask_app is None:
        from backend.app import create_app  # lazy import breaks circular dep

        _config_name = os.getenv("FLASK_CONFIG") or "dev"
        if _config_name not in {"dev", "prod", "production", "testing"}:
            _config_name = "dev"
        _flask_app = create_app(_config_name)
    return _flask_app


@celery.task(name="backend.tasks.retention_tasks.purge_inactive_accounts_task")
def purge_inactive_accounts_task():
    """Celery entry point for the daily data-retention purge.

    Anonymises accounts inactive beyond DATA_RETENTION_INACTIVE_DAYS. Safe to
    run repeatedly: already-anonymised and recently-active accounts are skipped.
    Returns the purge summary dict (also visible in the Celery result backend).
    """
    from backend.services.data_retention import purge_inactive_accounts

    app = get_flask_app()
    with app.app_context():
        logger.info("Data-retention purge task triggered by Celery beat")
        summary = purge_inactive_accounts()
        logger.info(
            "Data-retention purge task finished: purged=%d scanned=%d errors=%d",
            summary.get("purged", 0),
            summary.get("scanned", 0),
            summary.get("errors", 0),
        )
        _write_retention_heartbeat(summary)
        return summary
