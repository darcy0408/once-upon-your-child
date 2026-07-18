import logging
import os

from celery import Celery
from celery.schedules import crontab

# MT-364: Celery's own success tracer (celery.app.trace) logs the FULL
# return value of every task at INFO level by default — the format string
# is "Task X[id] succeeded in Ys: {retval}" (see celery/app/trace.py
# build_tracer's `_does_info` gate). For generate_story_task, that return
# value IS the complete personalized story payload: the child's real name
# (restored from the HERO_1 pseudonym — see M-7 in story_tasks.py) plus
# every companion name, dumped to worker stdout (which ships off-box to
# Railway/Sentry) on every single successful story generation, regardless
# of anything the task itself does to keep its own logs PII-free.
#
# Silence just this one internal logger. It's evaluated once, lazily, the
# first time a task's tracer is built (cached on the Task object after
# that) — so this must run at import time, before any task ever executes.
# Celery's own worker bootstrap (`setup_logging_subsystem`) only reconfigures
# the root logger, the multiprocessing logger, and "celery.task" — it never
# touches "celery.app.trace" — so this explicit level sticks regardless of
# the worker's --loglevel flag. Our application logger
# (backend.tasks.story_tasks, a sibling under "celery.task") is completely
# unaffected and keeps reporting attempt counts, timings, and other
# non-PII diagnostics at INFO.
logging.getLogger("celery.app.trace").setLevel(logging.WARNING)

# Get Redis URL from environment
# If not present, default to memory/cache to avoid connection errors on localhost


def _fix_redis_scheme(url: str | None) -> str | None:
    """Normalize non-standard Redis URL schemes (e.g. rredis://) to redis://."""
    if url and url.startswith("rredis://"):
        return "redis://" + url[len("rredis://") :]
    return url


REDIS_URL = _fix_redis_scheme(os.getenv("REDIS_URL"))
CELERY_BROKER_URL = _fix_redis_scheme(os.getenv("CELERY_BROKER_URL"))
CELERY_RESULT_BACKEND = _fix_redis_scheme(os.getenv("CELERY_RESULT_BACKEND"))


def _as_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return str(value).strip().lower() in ("1", "true", "yes", "on")


# Initialize Celery app
celery = Celery(
    "story_weaver",
    broker=CELERY_BROKER_URL or REDIS_URL or "memory://",
    backend=CELERY_RESULT_BACKEND or REDIS_URL or "cache+memory://",
    include=[
        "backend.tasks.story_tasks",
        # CMP-5 / PP-13: data-retention purge task. Must be in `include` so the
        # worker and the celery-beat scheduler can resolve it by name.
        "backend.tasks.retention_tasks",
        # SE1: scheduled reliability monitoring (Celery queue depth + the
        # data-retention purge heartbeat). Also resolved by name via beat.
        "backend.tasks.monitoring_tasks",
        # Gift subscriptions: daily sweep that expires redeemed gift codes
        # once their time-boxed entitlement lapses (see models/gift_code.py
        # and tasks/subscription_tasks.py for the design writeup).
        "backend.tasks.subscription_tasks",
    ],
)

task_always_eager = _as_bool("CELERY_TASK_ALWAYS_EAGER", False)
task_eager_propagates = _as_bool("CELERY_TASK_EAGER_PROPAGATES", task_always_eager)
task_store_eager_result = _as_bool("CELERY_TASK_STORE_EAGER_RESULT", task_always_eager)

# Celery configuration
celery.conf.update(
    # broker_url and result_backend are set via REDIS_URL or config.py
    # broker_url='redis://localhost:6379/0',
    # result_backend='redis://localhost:6379/0',
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_always_eager=task_always_eager,
    task_eager_propagates=task_eager_propagates,
    task_store_eager_result=task_store_eager_result,
    task_track_started=True,
    task_time_limit=600,  # 10 minute max per task
    result_expires=3600,  # Results expire after 1 hour
    # CMP-5 / PP-13: Celery-beat schedule. The data-retention purge runs once
    # daily at 03:30 UTC (low-traffic window). The actual inactivity window is
    # configured separately via DATA_RETENTION_INACTIVE_DAYS (default 730).
    # Beat must be running for this to fire. Beat is NOT embedded in the worker
    # (embedded `-B` is a dev-only convenience and dies with the worker) — it
    # runs as its own dedicated `celery-beat` Railway service in railway.toml.
    beat_schedule={
        "data-retention-purge-inactive-accounts": {
            "task": "backend.tasks.retention_tasks.purge_inactive_accounts_task",
            "schedule": crontab(hour=3, minute=30),
        },
        # SE1: reliability monitor — checks Celery queue depth and the
        # data-retention purge heartbeat every 10 minutes and raises an
        # alertable Sentry warning when a threshold is breached.
        "system-reliability-monitor": {
            "task": "backend.tasks.monitoring_tasks.system_monitor_task",
            "schedule": crontab(minute="*/10"),
        },
        # Gift subscriptions: expire redeemed gift codes whose time-boxed
        # entitlement has lapsed. Runs daily, staggered from the retention
        # purge above. See tasks/subscription_tasks.py.
        "gift-entitlement-expiry-sweep": {
            "task": "backend.tasks.subscription_tasks.expire_gift_entitlements_task",
            "schedule": crontab(hour=4, minute=0),
        },
    },
)
