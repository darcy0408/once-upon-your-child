from sqlalchemy import text
from backend.database import db
from flask import current_app
import logging

logger = logging.getLogger(__name__)

def migrate_role_column():
    """Add role column to user table if it doesn't exist"""
    try:
        with current_app.app_context():
            # Check if column exists
            inspector = db.inspect(db.engine)
            columns = [c['name'] for c in inspector.get_columns('user')]
            
            if 'role' not in columns:
                logger.info("Adding 'role' column to user table...")
                with db.engine.connect() as conn:
                    conn.execute(text("ALTER TABLE user ADD COLUMN role VARCHAR(20) DEFAULT 'user' NOT NULL"))
                    conn.commit()
                logger.info("Successfully added 'role' column")
            else:
                logger.info("'role' column already exists")
                
    except Exception as e:
        logger.error(f"Migration failed: {e}")

if __name__ == "__main__":
    from backend.app import create_app
    app = create_app()
    with app.app_context():
        migrate_role_column()
