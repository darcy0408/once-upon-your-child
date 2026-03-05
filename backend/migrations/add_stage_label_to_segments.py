"""
Database Migration: Add stage_label to StorySegment
Adds kid-friendly stage label for storybook-style progress indicator.

Run this migration with:
    python -m backend.migrations.add_stage_label_to_segments
"""
from backend.app import create_app
from backend.database import db
from sqlalchemy import text


def run_migration():
    """Add stage_label column to story_segment table"""
    print("Starting stage_label migration...")

    import os
    config_name = os.getenv('FLASK_ENV', 'development')
    app = create_app(config_name)

    with app.app_context():
        try:
            # Check if column already exists
            inspector = db.inspect(db.engine)
            existing_columns = [col['name'] for col in inspector.get_columns('story_segment')]

            # Add stage_label column if it doesn't exist
            if 'stage_label' not in existing_columns:
                print("Adding stage_label column to story_segment...")
                db.session.execute(text("""
                    ALTER TABLE story_segment
                    ADD COLUMN stage_label VARCHAR(100)
                """))
                print("[OK] Added stage_label column")
            else:
                print("[SKIP] stage_label column already exists")

            db.session.commit()
            print("\n[SUCCESS] Migration completed successfully!")
            print("   - Added stage_label column for kid-friendly progress labels")

        except Exception as e:
            db.session.rollback()
            print(f"\n[ERROR] Migration failed: {e}")
            raise


def rollback_migration():
    """Remove stage_label column"""
    print("WARNING: This will remove stage_label column!")
    confirmation = input("Type 'REMOVE' to confirm: ")

    if confirmation != "REMOVE":
        print("Rollback cancelled.")
        return

    import os
    config_name = os.getenv('FLASK_ENV', 'development')
    app = create_app(config_name)

    with app.app_context():
        try:
            print("Removing stage_label column...")
            db.session.execute(text("""
                ALTER TABLE story_segment
                DROP COLUMN IF EXISTS stage_label
            """))
            print("[OK] Removed stage_label column")

            db.session.commit()
            print("\n[SUCCESS] Rollback completed successfully!")

        except Exception as e:
            db.session.rollback()
            print(f"\n[ERROR] Rollback failed: {e}")
            raise


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--rollback":
        rollback_migration()
    else:
        run_migration()
