from backend.app import create_app
from backend.database import db
import sqlalchemy
from sqlalchemy import text

def fix_schema():
    app = create_app('development')
    with app.app_context():
        engine = db.engine
        inspector = sqlalchemy.inspect(engine)
        columns = [c['name'] for c in inspector.get_columns('character')]
        
        expected_columns = [
            ('avatar_data', 'JSON'),
            ('avatar_params', 'JSON'),
            ('character_type', 'VARCHAR(50)'),
            ('superhero_name', 'VARCHAR(100)'),
            ('mission', 'TEXT'),
            ('hair', 'VARCHAR(50)'),
            ('eyes', 'VARCHAR(50)'),
            ('outfit', 'VARCHAR(200)'),
            ('personality_traits', 'JSON'),
            ('personality_sliders', 'JSON'),
            ('siblings', 'JSON'),
            ('friends', 'JSON'),
            ('likes', 'JSON'),
            ('dislikes', 'JSON'),
            ('fears', 'JSON'),
            ('strengths', 'JSON'),
            ('goals', 'JSON'),
            ('pets', 'JSON'),
            ('comfort_item', 'VARCHAR(200)'),
            ('role', 'VARCHAR(50)'),
            ('magic_type', 'VARCHAR(50)'),
            ('challenge', 'TEXT')
        ]
        
        for col_name, col_type in expected_columns:
            if col_name not in columns:
                print(f"Adding column {col_name} to character table...")
                try:
                    with engine.connect() as conn:
                        conn.execute(text(f"ALTER TABLE character ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                    print(f"  Successfully added {col_name}")
                except Exception as e:
                    print(f"  Error adding {col_name}: {e}")
            else:
                print(f"Column {col_name} already exists.")

if __name__ == "__main__":
    fix_schema()
