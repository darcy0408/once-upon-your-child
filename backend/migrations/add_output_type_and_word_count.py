"""
Database Migration: Add output_type and word_count to StorySegment
Adds new fields to support CONTINUE/CHOICE flow and word count tracking
for the improved UX design.

Run this migration with:
    python -m backend.migrations.add_output_type_and_word_count
"""
from backend.app import create_app
from backend.database import db
from sqlalchemy import text


def run_migration():
    """Add output_type and word_count columns to story_segment table"""
    print("Starting output_type and word_count migration...")

    import os
    config_name = os.getenv('FLASK_ENV', 'development')
    app = create_app(config_name)

    with app.app_context():
        try:
            # Check if columns already exist
            inspector = db.inspect(db.engine)
            existing_columns = [col['name'] for col in inspector.get_columns('story_segment')]

            # Add output_type column if it doesn't exist
            if 'output_type' not in existing_columns:
                print("Adding output_type column to story_segment...")
                # SQLite-compatible syntax (no IF NOT EXISTS)
                db.session.execute(text("""
                    ALTER TABLE story_segment
                    ADD COLUMN output_type VARCHAR(20) NOT NULL DEFAULT 'CHOICE'
                """))
                print("[OK] Added output_type column")
            else:
                print("[SKIP] output_type column already exists")

            # Add word_count column if it doesn't exist
            if 'word_count' not in existing_columns:
                print("Adding word_count column to story_segment...")
                db.session.execute(text("""
                    ALTER TABLE story_segment
                    ADD COLUMN word_count INTEGER
                """))
                print("[OK] Added word_count column")
            else:
                print("[SKIP] word_count column already exists")

            # Update existing segments to calculate word count
            print("Calculating word counts for existing segments...")
            db.session.execute(text("""
                UPDATE story_segment
                SET word_count = (
                    LENGTH(content) - LENGTH(REPLACE(content, ' ', '')) + 1
                )
                WHERE word_count IS NULL AND content IS NOT NULL
            """))
            print("[OK] Updated word counts for existing segments")

            db.session.commit()
            print("\n[SUCCESS] Migration completed successfully!")
            print("   - Added output_type column (default: 'CHOICE')")
            print("   - Added word_count column")
            print("   - Calculated word counts for existing segments")

        except Exception as e:
            db.session.rollback()
            print(f"\n[ERROR] Migration failed: {e}")
            raise


def rollback_migration():
    """Remove output_type and word_count columns"""
    print("WARNING: This will remove output_type and word_count columns!")
    confirmation = input("Type 'REMOVE' to confirm: ")

    if confirmation != "REMOVE":
        print("Rollback cancelled.")
        return

    import os
    config_name = os.getenv('FLASK_ENV', 'development')
    app = create_app(config_name)

    with app.app_context():
        try:
            # Remove word_count column
            print("Removing word_count column...")
            db.session.execute(text("""
                ALTER TABLE story_segment
                DROP COLUMN IF EXISTS word_count
            """))
            print("[OK] Removed word_count column")

            # Remove output_type column
            print("Removing output_type column...")
            db.session.execute(text("""
                ALTER TABLE story_segment
                DROP COLUMN IF EXISTS output_type
            """))
            print("[OK] Removed output_type column")

            db.session.commit()
            print("\n✅ Rollback completed successfully!")

        except Exception as e:
            db.session.rollback()
            print(f"\n❌ Rollback failed: {e}")
            raise


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--rollback":
        rollback_migration()
    else:
        run_migration()
