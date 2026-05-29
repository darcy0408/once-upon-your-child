#!/usr/bin/env python3
"""
Migration: Add themes / characters_featured / emotional_arc columns to story table

Stores Gemini-extracted metadata so future stories can recall "what has this
child explored before" without embeddings. JSON columns persist as TEXT in
SQLite — same pattern as Character.personality_traits.
"""

import sqlite3
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run_migration():
    db_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)), "instance", "app.db"
    )

    if not os.path.exists(db_path):
        print(f"[ERROR] Database not found at {db_path}")
        print("   Run the app once to create the database first.")
        return False

    new_columns = [
        ("themes", "TEXT"),
        ("characters_featured", "TEXT"),
        ("emotional_arc", "VARCHAR(120)"),
    ]

    conn = None
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute("PRAGMA table_info(story)")
        existing = {row[1] for row in cursor.fetchall()}

        added = []
        for name, type_decl in new_columns:
            if name in existing:
                print(f"[OK] Column '{name}' already exists. Skipping.")
                continue
            print(f"Adding '{name}' column to story table...")
            cursor.execute(f"ALTER TABLE story ADD COLUMN {name} {type_decl}")
            added.append(name)

        conn.commit()

        if added:
            print(f"[SUCCESS] Added {len(added)} column(s): {', '.join(added)}")
        else:
            print("[OK] No migration needed — all columns already present.")
        return True

    except sqlite3.Error as e:
        print(f"[ERROR] Migration failed: {e}")
        return False

    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: Add themes columns to story")
    print("=" * 60)

    success = run_migration()

    if not success:
        sys.exit(1)
