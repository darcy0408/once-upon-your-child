import os
import sys

# Set env vars
os.environ['FLASK_ENV'] = 'development'
os.environ['JWT_SECRET_KEY'] = 'dev-secret-key'
os.environ['SECRET_KEY'] = 'dev-secret-key'

print("Setting up paths...")
sys.path.append(os.getcwd())

print("Importing app...")
try:
    from backend.app import create_app
    print("App imported.")
    app = create_app('development')
    print("App created.")
    print(f"App config JWT_SECRET_KEY: {app.config.get('JWT_SECRET_KEY')}")
    print(f"App config SECRET_KEY: {app.config.get('SECRET_KEY')}")
    
    with app.app_context():
        print("App context active.")
        from backend.database import db
        print(f"DB Engine: {db.engine}")
        from backend.models.user import User
        print(f"User model: {User}")
        
except Exception as e:
    print(f"CRASHED: {e}")
    import traceback
    traceback.print_exc()
