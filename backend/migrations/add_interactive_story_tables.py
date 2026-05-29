"""
Database Migration: Add Interactive Adventure Story Tables
Creates tables for the new interactive story system with branching narratives,
inventory tracking, and persistent state management.

Run this migration with:
    python -m backend.migrations.add_interactive_story_tables
"""

from backend.app import create_app
from backend.database import db
from backend.models import (
    InteractiveStory,
    StorySegment,
    StoryChoice,
    InventoryItem,
    StoryState,
)


def run_migration():
    """Create all interactive story tables"""
    print("Starting interactive story tables migration...")

    import os

    config_name = os.getenv("FLASK_ENV", "development")
    app = create_app(config_name)

    with app.app_context():
        # Create all tables defined in the models
        # SQLAlchemy will only create tables that don't exist
        db.create_all()

        print("[OK] Created table: interactive_story")
        print("[OK] Created table: story_segment")
        print("[OK] Created table: story_choice")
        print("[OK] Created table: inventory_item")
        print("[OK] Created table: story_state")
        print("\nMigration completed successfully!")


def rollback_migration():
    """Drop all interactive story tables (use with caution!)"""
    print("WARNING: This will delete all interactive story data!")
    confirmation = input("Type 'DELETE' to confirm: ")

    if confirmation != "DELETE":
        print("Rollback cancelled.")
        return

    import os

    config_name = os.getenv("FLASK_ENV", "development")
    app = create_app(config_name)

    with app.app_context():
        # Drop tables in reverse order of dependencies
        StoryChoice.__table__.drop(db.engine, checkfirst=True)
        print("[OK] Dropped table: story_choice")

        StorySegment.__table__.drop(db.engine, checkfirst=True)
        print("[OK] Dropped table: story_segment")

        InventoryItem.__table__.drop(db.engine, checkfirst=True)
        print("[OK] Dropped table: inventory_item")

        StoryState.__table__.drop(db.engine, checkfirst=True)
        print("[OK] Dropped table: story_state")

        InteractiveStory.__table__.drop(db.engine, checkfirst=True)
        print("[OK] Dropped table: interactive_story")

        print("\nRollback completed.")


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--rollback":
        rollback_migration()
    else:
        run_migration()
