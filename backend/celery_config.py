import os
from celery import Celery

# Get Redis URL from environment with a sensible default for local development
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# Initialize Celery app
celery = Celery(
    "story_weaver",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=["backend.tasks.story_tasks"],
)

# Celery configuration
celery.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=600,  # 10 minute max per task
    result_expires=3600,  # Results expire after 1 hour
)
