"""
Database migration script to add BYOK fields to existing User table.
Run this once to upgrade the database schema.
"""
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app import create_app
from backend.database import db
from sqlalchemy import text

def run_migration():
    """Add BYOK fields to User table if they don't exist."""
    app = create_app('dev')
    
    with app.app_context():
        print("Running BYOK database migration...")
        
        try:
            # Check if we're using PostgreSQL or SQLite
            engine_name = db.engine.name
            print(f"Database engine: {engine_name}")
            
            if engine_name == 'postgresql':
                # PostgreSQL migration
                migrations = [
                    # Add gemini_api_key_encrypted column
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='gemini_api_key_encrypted') THEN
                            ALTER TABLE "user" ADD COLUMN gemini_api_key_encrypted TEXT;
                        END IF;
                    END $$;
                    """,
                    # Add has_byok column
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='has_byok') THEN
                            ALTER TABLE "user" ADD COLUMN has_byok BOOLEAN DEFAULT FALSE NOT NULL;
                        END IF;
                    END $$;
                    """,
                    # Add stories_generated_this_month column
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='stories_generated_this_month') THEN
                            ALTER TABLE "user" ADD COLUMN stories_generated_this_month INTEGER DEFAULT 0 NOT NULL;
                        END IF;
                    END $$;
                    """,
                    # Add illustrations_generated_this_month column
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='illustrations_generated_this_month') THEN
                            ALTER TABLE "user" ADD COLUMN illustrations_generated_this_month INTEGER DEFAULT 0 NOT NULL;
                        END IF;
                    END $$;
                    """,
                    # Add usage_reset_date column
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='usage_reset_date') THEN
                            ALTER TABLE "user" ADD COLUMN usage_reset_date TIMESTAMP;
                        END IF;
                    END $$;
                    """,
                ]
            else:
                # SQLite migration
                migrations = [
                    'ALTER TABLE user ADD COLUMN gemini_api_key_encrypted TEXT',
                    'ALTER TABLE user ADD COLUMN has_byok BOOLEAN DEFAULT 0 NOT NULL',
                    'ALTER TABLE user ADD COLUMN stories_generated_this_month INTEGER DEFAULT 0 NOT NULL',
                    'ALTER TABLE user ADD COLUMN illustrations_generated_this_month INTEGER DEFAULT 0 NOT NULL',
                    'ALTER TABLE user ADD COLUMN usage_reset_date TIMESTAMP',
                ]
            
            with db.engine.connect() as conn:
                for migration in migrations:
                    try:
                        conn.execute(text(migration))
                        conn.commit()
                        print(f"✓ Applied migration")
                    except Exception as e:
                        # Column might already exist, that's ok
                        if "already exists" in str(e).lower() or "duplicate column" in str(e).lower():
                            print(f"⊘ Migration already applied (column exists)")
                        else:
                            print(f"✗ Migration failed: {e}")
            
            print("\n✓ Migration completed successfully!")
            print("\nNew User fields added:")
            print("  - gemini_api_key_encrypted (TEXT)")
            print("  - has_byok (BOOLEAN)")
            print("  - stories_generated_this_month (INTEGER)")
            print("  - illustrations_generated_this_month (INTEGER)")
            print("  - usage_reset_date (TIMESTAMP)")
            
        except Exception as e:
            print(f"\n✗ Migration failed: {e}")
            import traceback
            traceback.print_exc()

if __name__ == '__main__':
    run_migration()
