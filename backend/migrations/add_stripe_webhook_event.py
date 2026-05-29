#!/usr/bin/env python3
"""
Migration: Stripe webhook idempotency / replay-dedup (security finding M-3).

Adds two tables:
  - `stripe_webhook_event`      — one row per accepted Stripe `event.id`
                                  (unique constraint = the replay-dedup key).
  - `stripe_subscription_cursor` — per-user high-water mark of the most recent
                                   Stripe event timestamp that changed
                                   subscription state (out-of-order guard).

This works against both SQLite (local dev) and PostgreSQL (Railway). It is
idempotent — safe to run repeatedly. The same tables are also created at app
boot via `db.create_all()` (the models are imported by
`backend/routes/webhook_handler.py`, which app.py imports before create_all),
so a fresh Railway deploy does not need this script run manually; it exists as
the canonical migration record and for explicit/managed runs.

Usage:
    python -m backend.migrations.add_stripe_webhook_event
"""

import os
import sys

# Allow running as a script: add repo root to path.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from sqlalchemy import inspect  # noqa: E402

from backend.app import create_app  # noqa: E402
from backend.database import db  # noqa: E402

# Importing the models ensures both tables are registered before create_all().
from backend.models.stripe_event import (  # noqa: E402,F401
    StripeWebhookEvent,
    StripeSubscriptionCursor,
)


def run_migration():
    """Apply the Stripe webhook idempotency schema changes idempotently."""
    env = os.environ.get("FLASK_ENV", "production")
    app = create_app(env)

    with app.app_context():
        print(f"Running Stripe webhook idempotency migration (env={env})...")
        inspector = inspect(db.engine)
        existing_tables = set(inspector.get_table_names())

        for table in ("stripe_webhook_event", "stripe_subscription_cursor"):
            if table in existing_tables:
                print(f"  - {table} table already exists; skipping.")
            else:
                print(f"  - Creating {table} table ...")

        # create_all only builds tables that do not yet exist.
        db.create_all()
        print("Stripe webhook idempotency migration complete.")
        return True


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: Stripe webhook idempotency (M-3)")
    print("=" * 60)
    try:
        run_migration()
        print("\nAll done.")
    except Exception as exc:  # noqa: BLE001
        print(f"\nMigration failed: {exc}")
        sys.exit(1)
