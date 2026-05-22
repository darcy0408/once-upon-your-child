#!/usr/bin/env python3
"""Migration: add `task_id` and `content` columns to the story table (R2).

Reliability finding R2: a completed async story's Celery result expires after
`result_expires` (1 hour). The story row previously persisted only metadata
(title/theme/themes), so once the result expired the generated story content
was permanently lost. These two columns let /task-status recover a finished
story from the database:

  task_id  - the Celery task id the story was generated under (indexed)
  content  - the full story payload JSON returned to the client

This script connects directly with SQLAlchemy and does NOT boot the Flask app,
so it needs no service env vars beyond a database URL. It is idempotent:
columns that already exist are skipped.

Usage
-----
Prod Postgres (run from your local machine, once the repo is linked):

  railway login                       # if the CLI token has expired
  railway link                        # pick: radiant-tranquility / production
  railway run --service Postgres python backend/migrations/add_content_and_task_id_to_story.py

Running with `--service Postgres` injects DATABASE_PUBLIC_URL, which is
reachable from outside Railway (the internal DATABASE_URL is not). The script
prefers DATABASE_PUBLIC_URL automatically.

Local SQLite dev database:

  python backend/migrations/add_content_and_task_id_to_story.py
"""
import os
import sys


def _resolve_db_url() -> str:
    """Pick a database URL.

    Prefers DATABASE_PUBLIC_URL (reachable when run locally via
    `railway run --service Postgres`), then DATABASE_URL, then the local
    SQLite dev database. Normalises Railway's legacy `postgres://` scheme.
    """
    url = os.getenv("DATABASE_PUBLIC_URL") or os.getenv("DATABASE_URL")
    if not url or not url.strip():
        return "sqlite:///backend/instance/app.db"
    url = url.strip()
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql://", 1)
    return url


def run_migration() -> bool:
    """Add the `task_id` and `content` columns to the `story` table if absent."""
    from sqlalchemy import create_engine, inspect, text

    db_url = _resolve_db_url()
    # Never print credentials — show only the host/db portion of the URL.
    safe_display = db_url.split("@")[-1] if "@" in db_url else db_url
    print(f"Target database: {safe_display}")

    engine = create_engine(db_url)
    try:
        inspector = inspect(engine)

        if "story" not in inspector.get_table_names():
            print("[ERROR] table 'story' does not exist — wrong database?")
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

        with engine.begin() as conn:
            for stmt in ddl_statements:
                print(f"  executing: {stmt}")
                conn.execute(text(stmt))

        print("[SUCCESS] migration complete — 'task_id' and 'content' are present on 'story'.")
        return True
    except Exception as exc:  # noqa: BLE001 — surface any DDL failure clearly
        print(f"[ERROR] migration failed: {exc}")
        return False
    finally:
        engine.dispose()


if __name__ == "__main__":
    print("=" * 64)
    print("Migration: add task_id + content to the story table (R2)")
    print("=" * 64)
    ok = run_migration()
    if not ok:
        sys.exit(1)
    print("\nDone.")
