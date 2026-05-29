#!/usr/bin/env python3
"""Migration: add `prompt_template_id` + `prompt_revision_hash` to story (F-01 / MT-187).

Audit 05 Critical finding F-01: prompts had no version metadata anywhere, so a
regression on (say) Sprout Superhero was a forensic exercise rather than a
single SQL query. These two columns make every persisted Story self-describing:

  prompt_template_id    VARCHAR(40)  -- e.g. "T6_SUPERHERO_SPROUT"
  prompt_revision_hash  VARCHAR(16)  -- sha256[:16] of the builder's live source

Population is handled by ``backend/services/prompt_versioning.py`` at story
generation time. Legacy rows and the anonymous / interactive-story paths stay
NULL by design — both columns are nullable.

This script connects directly with SQLAlchemy and does NOT boot the Flask app,
so it needs no service env vars beyond a database URL. It is idempotent:
columns that already exist are skipped.

Usage
-----
Prod Postgres (run from your local machine, once the repo is linked):

  railway login                       # if the CLI token has expired
  railway link                        # pick: radiant-tranquility / production
  railway run --service Postgres python backend/migrations/add_prompt_versioning_to_story.py

Running with ``--service Postgres`` injects DATABASE_PUBLIC_URL, which is
reachable from outside Railway (the internal DATABASE_URL is not). The script
prefers DATABASE_PUBLIC_URL automatically.

Local SQLite dev database:

  python backend/migrations/add_prompt_versioning_to_story.py
"""

import os
import sys


def _resolve_db_url() -> str:
    """Pick a database URL.

    Prefers DATABASE_PUBLIC_URL (reachable when run locally via
    ``railway run --service Postgres``), then DATABASE_URL, then the local
    SQLite dev database. Normalises Railway's legacy ``postgres://`` scheme.
    """
    url = os.getenv("DATABASE_PUBLIC_URL") or os.getenv("DATABASE_URL")
    if not url or not url.strip():
        return "sqlite:///backend/instance/app.db"
    url = url.strip()
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql://", 1)
    return url


def run_migration() -> bool:
    """Add the two prompt-versioning columns to the ``story`` table if absent."""
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

        if "prompt_template_id" in existing:
            print("[OK] column 'prompt_template_id' already exists — skipping.")
        else:
            ddl_statements.append(
                "ALTER TABLE story ADD COLUMN prompt_template_id VARCHAR(40)"
            )

        if "prompt_revision_hash" in existing:
            print("[OK] column 'prompt_revision_hash' already exists — skipping.")
        else:
            ddl_statements.append(
                "ALTER TABLE story ADD COLUMN prompt_revision_hash VARCHAR(16)"
            )

        if not ddl_statements:
            print("[OK] nothing to do — both columns already present.")
            return True

        with engine.begin() as conn:
            for stmt in ddl_statements:
                print(f"  executing: {stmt}")
                conn.execute(text(stmt))

        print(
            "[SUCCESS] migration complete — F-01 prompt-versioning columns are present on 'story'."
        )
        return True
    except Exception as exc:  # noqa: BLE001 — surface any DDL failure clearly
        print(f"[ERROR] migration failed: {exc}")
        return False
    finally:
        engine.dispose()


if __name__ == "__main__":
    print("=" * 64)
    print("Migration: add F-01 prompt-versioning columns to story (MT-187)")
    print("=" * 64)
    ok = run_migration()
    if not ok:
        sys.exit(1)
    print("\nDone.")
