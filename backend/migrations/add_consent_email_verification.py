#!/usr/bin/env python3
"""
Migration: COPPA email-verified parental consent.

Adds:
  - `verified` BOOLEAN column to the `consent_record` table.
  - the `consent_verification_code` table (transient, hashed verification
    codes for the parental-consent email round trip).

This works against both SQLite (local dev) and PostgreSQL (Railway). It is
idempotent — safe to run repeatedly. The same schema change is also applied
at app boot in backend/app.py (db.create_all() + an ALTER TABLE guard) so a
fresh Railway deploy does not need this script run manually; it exists as the
canonical migration record and for explicit/managed runs.

Usage:
    python -m backend.migrations.add_consent_email_verification
"""

import os
import sys

# Allow running as a script: add repo root to path.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from sqlalchemy import inspect, text  # noqa: E402

from backend.app import create_app  # noqa: E402
from backend.database import db  # noqa: E402

# Importing the models ensures both tables are registered before create_all().
from backend.models.consent_record import (  # noqa: E402,F401
    ConsentRecord,
    ConsentVerificationCode,
)


def run_migration():
    """Apply the consent email-verification schema changes idempotently."""
    env = os.environ.get("FLASK_ENV", "production")
    app = create_app(env)

    with app.app_context():
        print(f"Running consent email-verification migration (env={env})...")
        inspector = inspect(db.engine)
        existing_tables = set(inspector.get_table_names())

        # 1. Add `verified` column to consent_record if missing.
        if "consent_record" in existing_tables:
            consent_cols = {c["name"] for c in inspector.get_columns("consent_record")}
            if "verified" in consent_cols:
                print("  - consent_record.verified already present; skipping.")
            else:
                print("  - Adding consent_record.verified ...")
                with db.engine.connect() as conn:
                    conn.execute(
                        text(
                            "ALTER TABLE consent_record "
                            "ADD COLUMN verified BOOLEAN DEFAULT FALSE NOT NULL"
                        )
                    )
                    conn.commit()
                print("    done.")
        else:
            print("  - consent_record table not found; create_all() will build it.")

        # 2. Create consent_verification_code table if missing.
        if "consent_verification_code" in existing_tables:
            print("  - consent_verification_code table already exists; skipping.")
        else:
            print("  - Creating consent_verification_code table ...")
            # create_all only builds tables that do not yet exist.
            db.create_all()
            print("    done.")

        print("Consent email-verification migration complete.")
        return True


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: COPPA email-verified parental consent")
    print("=" * 60)
    try:
        run_migration()
        print("\nAll done.")
    except Exception as exc:  # noqa: BLE001
        print(f"\nMigration failed: {exc}")
        sys.exit(1)
