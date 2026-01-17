import sqlite3
import os

db_path = 'backend/config/characters.db'
if not os.path.exists(db_path):
    print(f"DB not found at {db_path}")
    # try root
    db_path = 'characters.db'

print(f"Connecting to {db_path}")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    print("Attempting to add 'role' column...")
    # SQLite doesn't support IF NOT EXISTS in ADD COLUMN well in older versions, but let's try
    try:
        cursor.execute("ALTER TABLE user ADD COLUMN role VARCHAR(20) DEFAULT 'user'")
        print("Column added.")
    except sqlite3.OperationalError as e:
        if 'duplicate column' in str(e):
            print("Column already exists.")
        else:
            print(f"Error adding column: {e}")
            
    conn.commit()
    print("Changes committed.")
    
    # Verify
    cursor.execute("PRAGMA table_info(user)")
    cols = cursor.fetchall()
    role_exists = any(c[1] == 'role' for c in cols)
    print(f"Verification: role exists? {role_exists}")

except Exception as e:
    print(f"Script failed: {e}")
finally:
    conn.close()
