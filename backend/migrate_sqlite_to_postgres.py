import sqlite3
import psycopg2
import os
import json
from datetime import datetime

# SQLite connection
sqlite_conn = sqlite3.connect('characters.db')
sqlite_cursor = sqlite_conn.cursor()

# PostgreSQL connection
pg_conn = psycopg2.connect(os.getenv('DATABASE_URL'))
pg_cursor = pg_conn.cursor()

# Migrate characters
print("Migrating characters...")
sqlite_cursor.execute("SELECT * FROM character")
characters = sqlite_cursor.fetchall()

for char in characters:
    # Parse JSON fields
    personality_traits = json.loads(char[13] or '[]')
    personality_sliders = json.loads(char[14] or '{}')
    siblings = json.loads(char[15] or '[]')
    friends = json.loads(char[16] or '[]')
    likes = json.loads(char[17] or '[]')
    dislikes = json.loads(char[18] or '[]')
    fears = json.loads(char[19] or '[]')
    strengths = json.loads(char[20] or '[]')
    goals = json.loads(char[21] or '[]')

    # Insert into PostgreSQL
    pg_cursor.execute("""
        INSERT INTO character (
            id, name, age, gender, role, magic_type, challenge,
            character_type, superhero_name, mission, hair, eyes, outfit,
            personality_traits, personality_sliders, siblings, friends,
            likes, dislikes, fears, strengths, goals, comfort_item, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                  %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        char[0], char[1], char[2], char[3], char[4], char[5], char[6],
        char[7], char[8], char[9], char[10], char[11], char[12],
        json.dumps(personality_traits),
        json.dumps(personality_sliders),
        json.dumps(siblings),
        json.dumps(friends),
        json.dumps(likes),
        json.dumps(dislikes),
        json.dumps(fears),
        json.dumps(strengths),
        json.dumps(goals),
        char[22],
        datetime.fromisoformat(char[23]) if char[23] else datetime.utcnow()
    ))

pg_conn.commit()
print(f"Migrated {len(characters)} characters")

# Close connections
sqlite_cursor.close()
sqlite_conn.close()
pg_cursor.close()
pg_conn.close()

print("Migration complete!")
