#!/usr/bin/env python3
"""
Migration: Add avatar_params column to character table

This migration adds the avatar_params column (JSON type) to store
DiceBear avataaars customization parameters.
"""

import sqlite3
import os
import sys

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run_migration():
    """Add avatar_params column if it doesn't exist"""

    # Path to the database
    db_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)), "instance", "app.db"
    )

    if not os.path.exists(db_path):
        print(f"[ERROR] Database not found at {db_path}")
        print("   Run the app once to create the database first.")
        return False

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if column already exists
        cursor.execute("PRAGMA table_info(character)")
        columns = [row[1] for row in cursor.fetchall()]

        if "avatar_params" in columns:
            print("[OK] Column 'avatar_params' already exists. No migration needed.")
            return True

        # Add the column
        print("Adding 'avatar_params' column to character table...")
        cursor.execute("""
            ALTER TABLE character
            ADD COLUMN avatar_params TEXT
        """)

        conn.commit()
        print("[SUCCESS] Migration completed successfully!")
        print("   Column 'avatar_params' added (JSON/TEXT type)")

        # Verify
        cursor.execute("SELECT COUNT(*) FROM character")
        character_count = cursor.fetchone()[0]
        print(f"   Existing characters: {character_count}")
        print("   All existing characters will have NULL avatar_params (which is fine)")

        return True

    except sqlite3.Error as e:
        print(f"[ERROR] Migration failed: {e}")
        return False

    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: Add avatar_params to character")
    print("=" * 60)

    success = run_migration()

    if success:
        print("\nAll done! Characters can now store avatar customization data.")
    else:
        print("\nMigration failed. Please check the errors above.")
        sys.exit(1)
