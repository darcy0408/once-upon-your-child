#!/usr/bin/env python3
"""
Migration: gift subscriptions.

Adds one table:
  - `gift_code` — prepaid gift-subscription redemption codes. See
    backend/models/gift_code.py for the full design writeup (hash-at-rest,
    idempotent purchase creation, atomic redemption, expiry sweep).

This works against both SQLite (local dev) and PostgreSQL (Railway). It is
idempotent — safe to run repeatedly. The table is also created at app boot via
`db.create_all()` (the model is imported by `backend/routes/webhook_handler.py`,
which app.py imports before create_all), so a fresh Railway deploy does not
need this script run manually; it exists as the canonical migration record and
for explicit/managed runs.

Usage:
    python -m backend.migrations.add_gift_code
"""

import os
import sys

# Allow running as a script: add repo root to path.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from sqlalchemy import inspect  # noqa: E402

from backend.app import create_app  # noqa: E402
from backend.database import db  # noqa: E402

# Importing the model ensures the table is registered before create_all().
from backend.models.gift_code import GiftCode  # noqa: E402,F401


def run_migration():
    """Apply the gift-subscriptions schema change idempotently."""
    env = os.environ.get("FLASK_ENV", "production")
    app = create_app(env)

    with app.app_context():
        print(f"Running gift-subscriptions migration (env={env})...")
        inspector = inspect(db.engine)
        existing_tables = set(inspector.get_table_names())

        if "gift_code" in existing_tables:
            print("  - gift_code table already exists; skipping.")
        else:
            print("  - Creating gift_code table ...")

        # create_all only builds tables that do not yet exist.
        db.create_all()
        print("Gift-subscriptions migration complete.")
        return True


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: gift subscriptions")
    print("=" * 60)
    try:
        run_migration()
        print("\nAll done.")
    except Exception as exc:  # noqa: BLE001
        print(f"\nMigration failed: {exc}")
        sys.exit(1)
