#!/usr/bin/env python3
"""Migration: add `task_id` and `content` columns to the story table (R2).

Reliability finding R2: a completed async story's Celery result expires after
`result_expires` (1 hour). The story row previously persisted only metadata
(title/theme/themes), so once the result expired the generated story content
was permanently lost. These two columns let /task-status recover a finished
story from the database:

  task_id  - the Celery task id the story was generated under (indexed)
  content  - the full story payload JSON returned to the client

Unlike the older migration scripts in this directory (which hard-code SQLite),
this runs against whatever DATABASE_URL points to (PostgreSQL in production,
SQLite locally) via the app's SQLAlchemy engine. It is idempotent: columns
that already exist are skipped.

Usage:
  Local:       python backend/migrations/add_content_and_task_id_to_story.py
  Prod (Railway, against the shared Postgres):
               railway run --service story-weaver-app \\
                 python backend/migrations/add_content_and_task_id_to_story.py
"""
import os
import sys

# Make the `backend` package importable when run as a script.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Don't let importing the app kick off the default app init.
os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")


def run_migration() -> bool:
    """Add the `task_id` and `content` columns to the `story` table if absent."""
    from sqlalchemy import inspect, text

    from backend.app import create_app
    from backend.database import db

    config_name = os.getenv("FLASK_CONFIG") or "prod"
    if config_name not in {"dev", "prod", "production", "testing"}:
        config_name = "prod"

    app = create_app(config_name)
    with app.app_context():
        engine = db.engine
        inspector = inspect(engine)

        if "story" not in inspector.get_table_names():
            print("[ERROR] table 'story' does not exist — run the app once to create it first.")
            return False

        existing = {col["name"] for col in inspector.get_columns("story")}
        ddl_statements = []

        if "task_id" in existing:
            print("[OK] column 'task_id' already exists — skipping.")
        else:
            ddl_statements.append("ALTER TABLE story ADD COLUMN task_id VARCHAR(64)")
            ddl_statements.append(
                "CREATE INDEX IF NOT EXISTS ix_story_task_id ON story (task_id)"
            )

        if "content" in existing:
            print("[OK] column 'content' already exists — skipping.")
        else:
            ddl_statements.append("ALTER TABLE story ADD COLUMN content JSON")

        if not ddl_statements:
            print("[OK] nothing to do — both columns already present.")
            return True

        try:
            with engine.begin() as conn:
                for stmt in ddl_statements:
                    print(f"  executing: {stmt}")
                    conn.execute(text(stmt))
        except Exception as exc:  # noqa: BLE001 — surface any DDL failure clearly
            print(f"[ERROR] migration failed: {exc}")
            return False

        print("[SUCCESS] migration complete — 'task_id' and 'content' are present on 'story'.")
        return True


if __name__ == "__main__":
    print("=" * 64)
    print("Migration: add task_id + content to the story table (R2)")
    print("=" * 64)
    ok = run_migration()
    if not ok:
        sys.exit(1)
    print("\nDone.")
