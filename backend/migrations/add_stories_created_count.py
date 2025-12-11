#!/usr/bin/env python3
"""
Migration: Add stories_created_count column to user table

This migration adds the stories_created_count column that's defined
in the User model but may be missing from older local databases.
"""

import sqlite3
import os
import sys

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def run_migration():
    """Add stories_created_count column if it doesn't exist"""

    # Path to the database
    db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'instance', 'app.db')

    if not os.path.exists(db_path):
        print(f"[ERROR] Database not found at {db_path}")
        print("   Run the app once to create the database first.")
        return False

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if column already exists
        cursor.execute("PRAGMA table_info(user)")
        columns = [row[1] for row in cursor.fetchall()]

        if 'stories_created_count' in columns:
            print("[OK] Column 'stories_created_count' already exists. No migration needed.")
            return True

        # Add the column
        print("Adding 'stories_created_count' column to user table...")
        cursor.execute("""
            ALTER TABLE user
            ADD COLUMN stories_created_count INTEGER DEFAULT 0 NOT NULL
        """)

        # Update existing users to have count = 0
        cursor.execute("UPDATE user SET stories_created_count = 0 WHERE stories_created_count IS NULL")

        conn.commit()
        print("[SUCCESS] Migration completed successfully!")
        print("   Column 'stories_created_count' added with default value 0")

        # Verify
        cursor.execute("SELECT COUNT(*) FROM user")
        user_count = cursor.fetchone()[0]
        print(f"   Updated {user_count} user(s)")

        return True

    except sqlite3.Error as e:
        print(f"[ERROR] Migration failed: {e}")
        return False

    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    print("=" * 60)
    print("Database Migration: Add stories_created_count")
    print("=" * 60)

    success = run_migration()

    if success:
        print("\nAll done! You can now run the app.")
    else:
        print("\nMigration failed. Please check the errors above.")
        sys.exit(1)
