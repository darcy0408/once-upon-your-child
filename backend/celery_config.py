import os
from celery import Celery
from celery.schedules import crontab

# Get Redis URL from environment
# If not present, default to memory/cache to avoid connection errors on localhost

def _fix_redis_scheme(url: str | None) -> str | None:
    """Normalize non-standard Redis URL schemes (e.g. rredis://) to redis://."""
    if url and url.startswith("rredis://"):
        return "redis://" + url[len("rredis://"):]
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
        # worker (and the embedded beat scheduler) can resolve it by name.
        "backend.tasks.retention_tasks",
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
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
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
    # Beat must be running for this to fire — the worker is started with the
    # embedded beat scheduler (`celery worker -B`); see railway.toml.
    beat_schedule={
        "data-retention-purge-inactive-accounts": {
            "task": "backend.tasks.retention_tasks.purge_inactive_accounts_task",
            "schedule": crontab(hour=3, minute=30),
        },
    },
)
