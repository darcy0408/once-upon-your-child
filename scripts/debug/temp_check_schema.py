import sqlite3
import os

db_path = 'characters.db'
if not os.path.exists(db_path):
    # Try backend/characters.db?
    if os.path.exists(os.path.join('backend', 'characters.db')):
        db_path = os.path.join('backend', 'characters.db')

print(f"Checking DB at: {db_path}")

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(user)")
    columns = cursor.fetchall()
    print("Columns in 'user' table:")
    found_role = False
    for col in columns:
        print(col)
        if col[1] == 'role':
            found_role = True
    
    if found_role:
        print("SUCCESS: 'role' column exists.")
    else:
        print("FAILURE: 'role' column MISSING.")
    conn.close()
except Exception as e:
    print(f"Error: {e}")
