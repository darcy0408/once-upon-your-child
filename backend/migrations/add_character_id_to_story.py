#!/usr/bin/env python3
"""
Migration: Add character_id column to story table

Closes the recall loop for repeat characters. With character_id we can pull a
character's prior themes/characters_featured and feed them back into the
prompt so the AI varies/builds on past adventures instead of looping the same
dragon-rescue every time.

Nullable + indexed. Supports both SQLite (local dev) and Postgres (Railway
prod). Detects from DATABASE_URL.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _run_sqlite():
    import sqlite3

    db_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)), "instance", "app.db"
    )
    if not os.path.exists(db_path):
        # Try alternate filename used by DevelopmentConfig.
        alt_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)), "characters.db"
        )
        if os.path.exists(alt_path):
            db_path = alt_path
        else:
            print(f"[ERROR] SQLite database not found at {db_path} or {alt_path}")
            return False

    conn = None
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute("PRAGMA table_info(story)")
        existing = {row[1] for row in cursor.fetchall()}

        if "character_id" in existing:
            print("[OK] Column 'character_id' already exists on story. Skipping.")
            return True

        print("Adding 'character_id' column to story table (SQLite)...")
        cursor.execute("ALTER TABLE story ADD COLUMN character_id VARCHAR(36)")
        # SQLite cannot add an indexed column in one ALTER; CREATE INDEX separately.
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_story_character_id ON story(character_id)"
        )
        conn.commit()
        print("[SUCCESS] Added story.character_id (VARCHAR(36)) + index.")
        return True
    except sqlite3.Error as e:
        print(f"[ERROR] SQLite migration failed: {e}")
        return False
    finally:
        if conn:
            conn.close()


def _run_postgres(database_url: str):
    try:
        import psycopg2
    except ImportError:
        print("[ERROR] psycopg2 not installed; cannot run Postgres migration.")
        return False

    # Normalize the URL form SQLAlchemy uses back to libpq form.
    if database_url.startswith("postgresql://"):
        pg_url = database_url.replace("postgresql://", "postgres://", 1)
    else:
        pg_url = database_url

    conn = None
    try:
        conn = psycopg2.connect(pg_url)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'story' AND column_name = 'character_id'
            """)
        if cursor.fetchone():
            print("[OK] Column 'character_id' already exists on story. Skipping.")
            return True

        print("Adding 'character_id' column to story table (Postgres)...")
        cursor.execute("ALTER TABLE story ADD COLUMN character_id VARCHAR(36)")
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_story_character_id ON story(character_id)"
        )
        conn.commit()
        print("[SUCCESS] Added story.character_id (VARCHAR(36)) + index.")
        return True
    except Exception as e:  # noqa: BLE001
        print(f"[ERROR] Postgres migration failed: {e}")
        if conn:
            conn.rollback()
        return False
    finally:
        if conn:
            conn.close()


def run_migration():
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if database_url and (
        database_url.startswith("postgres://")
        or database_url.startswith("postgresql://")
    ):
        return _run_postgres(database_url)
    return _run_sqlite()


if __name__ == "__main__":
    print("=" * 60)
    print("Database Migration: Add character_id to story")
    print("=" * 60)

    success = run_migration()
    if not success:
        sys.exit(1)
