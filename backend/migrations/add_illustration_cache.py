#!/usr/bin/env python3
"""
Migration: persistent illustration cache (image-gen cost reduction).

Adds one table:
  - `illustration_cache` — one row per unique (illustration inputs ->
                           generated image). A cache hit on a story re-read
                           returns the stored image, skipping both the paid
                           provider call and the monthly illustration quota.

This works against both SQLite (local dev) and PostgreSQL (Railway). It is
idempotent — safe to run repeatedly. The same table is also created at app
boot via `db.create_all()` (the model is imported by
`backend/models/__init__.py`), so a fresh Railway deploy does not need this
script run manually; it exists as the canonical migration record and for
explicit/managed runs.

Usage:
    python -m backend.migrations.add_illustration_cache
"""
import os
import sys

# Allow running as a script: add repo root to path.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from sqlalchemy import inspect  # noqa: E402

from backend.app import create_app  # noqa: E402
from backend.database import db  # noqa: E402
# Importing the model ensures the table is registered before create_all().
from backend.models.illustration_cache import IllustrationCache  # noqa: E402,F401


def run_migration():
    """Apply the illustration cache schema change idempotently."""
    env = os.environ.get('FLASK_ENV', 'production')
    app = create_app(env)

    with app.app_context():
        print(f"Running illustration cache migration (env={env})...")
        inspector = inspect(db.engine)
        existing_tables = set(inspector.get_table_names())

        if 'illustration_cache' in existing_tables:
            print("  - illustration_cache table already exists; skipping.")
        else:
            print("  - Creating illustration_cache table ...")

        # create_all only builds tables that do not yet exist.
        db.create_all()
        print("Illustration cache migration complete.")
        return True


if __name__ == '__main__':
    print("=" * 60)
    print("Database Migration: illustration cache")
    print("=" * 60)
    try:
        run_migration()
        print("\nAll done.")
    except Exception as exc:  # noqa: BLE001
        print(f"\nMigration failed: {exc}")
        sys.exit(1)
