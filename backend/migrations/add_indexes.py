import sys
import os

# Add parent directory to path to allow imports
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.database import db
from backend.app import create_app
from sqlalchemy import text


def run_migration():
    """
    Add missing indexes to the database.
    """
    app = create_app("production")

    with app.app_context():
        print("Running database index migration...")

        # Define indexes to create
        indexes = [
            # Story table indexes
            "CREATE INDEX IF NOT EXISTS idx_stories_user_created ON stories (user_id, created_at)",
            "CREATE INDEX IF NOT EXISTS idx_stories_theme ON stories (theme)",
            # User table indexes
            "CREATE INDEX IF NOT EXISTS idx_users_role ON users (role)",
            "CREATE INDEX IF NOT EXISTS idx_users_subscription ON users (subscription_tier)",
        ]

        try:
            for sql in indexes:
                print(f"Executing: {sql}")
                db.session.execute(text(sql))

            db.session.commit()
            print("Successfully added all indexes.")

        except Exception as e:
            print(f"Error adding indexes: {e}")
            db.session.rollback()


if __name__ == "__main__":
    run_migration()
