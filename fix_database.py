import sqlite3
import os

# Find all app.db files and fix them
db_paths = [
    'backend/app.db',
    'instance/app.db',
    'backend/instance/app.db',
]

for db_path in db_paths:
    if os.path.exists(db_path):
        print(f"Fixing database: {db_path}")
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='character';")
        if cursor.fetchone():
            # Check if avatar_params column exists
            cursor.execute("PRAGMA table_info(character);")
            columns = [row[1] for row in cursor.fetchall()]

            if 'avatar_params' not in columns:
                print(f"  Adding avatar_params column...")
                cursor.execute("ALTER TABLE character ADD COLUMN avatar_params TEXT;")
                conn.commit()
                print(f"  Column added successfully")
            else:
                print(f"  Column already exists")
        else:
            print(f"  Character table not found, skipping")

        conn.close()
    else:
        print(f"Database not found: {db_path}")

print("\nDone!")
