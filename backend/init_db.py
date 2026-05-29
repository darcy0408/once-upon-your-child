#!/usr/bin/env python3
"""Initialize the database by creating all tables."""

import os
import sys

# Add the parent directory to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app import create_app
from backend.database import db

# Import all models to ensure they're registered


def init_database():
    """Create all database tables."""
    app = create_app("development")

    with app.app_context():
        # Drop all tables first (optional - comment out if you want to keep existing data)
        # db.drop_all()

        # Create all tables
        db.create_all()

        print("✅ Database tables created successfully!")
        print(f"📁 Database location: {app.config.get('SQLALCHEMY_DATABASE_URI')}")


if __name__ == "__main__":
    init_database()
