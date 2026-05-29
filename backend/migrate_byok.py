"""
Database migration script to add BYOK fields to existing User table.
Run this once to upgrade the database schema.
"""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask
from sqlalchemy import text

from backend.config import config_by_name
from backend.database import db


def create_migration_app():
    """Create a minimal Flask app for running schema migrations."""
    app = Flask(__name__)
    app.config.from_object(config_by_name["dev"])
    db.init_app(app)
    return app


def run_migration():
    """Add BYOK fields to User table if they don't exist."""
    app = create_migration_app()

    with app.app_context():
        print("Running BYOK database migration...")

        try:
            engine_name = db.engine.name
            print(f"Database engine: {engine_name}")

            columns_sql = {
                "gemini_api_key_encrypted": 'ALTER TABLE "user" ADD COLUMN gemini_api_key_encrypted TEXT',
                "has_byok": 'ALTER TABLE "user" ADD COLUMN has_byok BOOLEAN DEFAULT FALSE NOT NULL',
                "stories_generated_this_month": 'ALTER TABLE "user" ADD COLUMN stories_generated_this_month INTEGER DEFAULT 0 NOT NULL',
                "illustrations_generated_this_month": 'ALTER TABLE "user" ADD COLUMN illustrations_generated_this_month INTEGER DEFAULT 0 NOT NULL',
                "usage_reset_date": 'ALTER TABLE "user" ADD COLUMN usage_reset_date TIMESTAMP',
            }

            with db.engine.connect() as conn:
                if engine_name == "postgresql":
                    existing = conn.execute(
                        text(
                            "SELECT column_name FROM information_schema.columns WHERE table_name='user'"
                        )
                    )
                    existing_columns = {row[0] for row in existing}
                else:
                    existing = conn.execute(text('PRAGMA table_info("user")'))
                    existing_columns = {row[1] for row in existing}

                for column_name, migration in columns_sql.items():
                    if column_name in existing_columns:
                        print(f"[SKIP] Column already exists: {column_name}")
                        continue
                    try:
                        conn.execute(text(migration))
                        conn.commit()
                        print(f"[OK] Added column: {column_name}")
                    except Exception as e:
                        print(f"[ERROR] Failed to add {column_name}: {e}")

            print("")
            print("[OK] Migration completed successfully!")
            print("")
            print("New User fields added:")
            print("  - gemini_api_key_encrypted (TEXT)")
            print("  - has_byok (BOOLEAN)")
            print("  - stories_generated_this_month (INTEGER)")
            print("  - illustrations_generated_this_month (INTEGER)")
            print("  - usage_reset_date (TIMESTAMP)")

        except Exception as e:
            print("")
            print(f"[ERROR] Migration failed: {e}")
            import traceback

            traceback.print_exc()


if __name__ == "__main__":
    run_migration()
