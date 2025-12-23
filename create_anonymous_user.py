#!/usr/bin/env python3
"""
Railway Database Fix - Create Anonymous User
Fixes the foreign key constraint issue for anonymous story generation
"""
import os
import sys

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

def create_anonymous_user():
    """Create anonymous user in database"""

    # Set production environment
    os.environ['FLASK_ENV'] = 'prod'

    try:
        from backend.database import db
        from backend.models.user import User
        from backend.app import create_app

        print("Creating Flask app...")
        app = create_app()

        with app.app_context():
            print("Checking for anonymous user...")

            # Check if anonymous user exists
            anonymous_user = db.session.get(User, 'anonymous')
            if anonymous_user:
                print("✅ Anonymous user already exists!")
                return True

            print("Creating anonymous user...")
            anon = User(
                id='anonymous',
                username='anonymous',
                email='anonymous@storyweaver.app'
            )
            anon.set_password('anonymous_guest_password')

            db.session.add(anon)
            db.session.commit()

            print("✅ Anonymous user created successfully!")
            return True

    except Exception as e:
        print(f"❌ Error creating anonymous user: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = create_anonymous_user()
    sys.exit(0 if success else 1)