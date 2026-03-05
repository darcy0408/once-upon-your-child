"""
Add avatar_data column to existing characters table
Run this once to upgrade your database
"""
import sqlite3
import os

# Find the database file
db_paths = [
    'backend/config/characters.db',
    'config/characters.db',
    'characters.db',
    'backend/app.db',
    'app.db'
]

db_path = None
for path in db_paths:
    if os.path.exists(path):
        db_path = path
        break

if not db_path:
    print("Could not find database file!")
    print("Searched in:")
    for path in db_paths:
        print(f"  - {path}")
    exit(1)

print(f"Found database: {db_path}")

# Connect to database
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Check if column already exists
cursor.execute("PRAGMA table_info(character)")
columns = [col[1] for col in cursor.fetchall()]

if 'avatar_data' in columns:
    print("✓ avatar_data column already exists!")
else:
    print("Adding avatar_data column...")
    try:
        # Add the column (SQLite doesn't support ALTER TABLE ADD COLUMN with JSON type directly)
        cursor.execute("ALTER TABLE character ADD COLUMN avatar_data TEXT")
        conn.commit()
        print("✓ avatar_data column added successfully!")
    except Exception as e:
        print(f"Error adding avatar_data column: {e}")
        conn.rollback()

if 'avatar_params' in columns:
    print("✓ avatar_params column already exists!")
else:
    print("Adding avatar_params column...")
    try:
        cursor.execute("ALTER TABLE character ADD COLUMN avatar_params TEXT")
        conn.commit()
        print("✓ avatar_params column added successfully!")
    except Exception as e:
        print(f"Error adding avatar_params column: {e}")
        conn.rollback()

# Verify
cursor.execute("PRAGMA table_info(character)")
columns = [col[1] for col in cursor.fetchall()]
print(f"\nCurrent columns in character table:")
for col in columns:
    print(f"  - {col}")

conn.close()

print("\n✓ Database updated! Restart your Flask backend.")
