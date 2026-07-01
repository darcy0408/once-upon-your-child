#!/usr/bin/env python3
"""
Migration: analytics event sink (paywall funnel instrumentation, MT-249).

Adds one table:
  - `analytics_events` — one append-only row per funnel/paywall event
                         (e.g. `paywall_viewed`, `avatar_limit_hit`). Written
                         best-effort by `services/event_tracking_service.py`.

This works against both SQLite (local dev) and PostgreSQL (Railway). It is
idempotent — safe to run repeatedly. The same table is also created at app
boot via `db.create_all()` (the model is imported by
`backend/models/__init__.py`), so a fresh Railway deploy does not need this
script run manually; it exists as the canonical migration record and for
explicit/managed runs.

Usage:
    python -m backend.migrations.add_analytics_events
"""

import os
import sys

# Allow running as a script: add repo root to path.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from sqlalchemy import inspect  # noqa: E402

from backend.app import create_app  # noqa: E402
from backend.database import db  # noqa: E402

# Importing the model ensures the table is registered before create_all().
from backend.models.analytics_event import AnalyticsEvent  # noqa: E402,F401


def run_migration():
    """Apply the analytics_events schema change idempotently."""
    env = os.environ.get("FLASK_ENV", "production")
    app = create_app(env)

    with app.app_context():
        print(f"Running analytics_events migration (env={env})...")
        inspector = inspect(db.engine)
        existing_tables = set(inspector.get_table_names())

        if "analytics_events" in existing_tables:
            print("  - analytics_events table already exists; skipping.")
        else:
            print("  - Creating analytics_events table ...")

        # create_all only builds tables that do not yet exist.
        db.create_all()
        print("analytics_events migration complete.")
        return True


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: analytics events")
    print("=" * 60)
    try:
        run_migration()
        print("\nAll done.")
    except Exception as exc:  # noqa: BLE001
        print(f"\nMigration failed: {exc}")
        sys.exit(1)
