import os
import sys

# Force dev environment BEFORE importing anything
os.environ['FLASK_ENV'] = 'development'
os.environ['JWT_SECRET_KEY'] = 'dev-secret-key'
os.environ['SECRET_KEY'] = 'dev-secret-key'  # Required by Config class

# Add project root to path
sys.path.append(os.getcwd())

try:
    from backend.migrations.add_role_column import migrate_role_column
    from backend.app import create_app
    
    # Re-apply force dev environment AFTER imports (in case .env overwrote them)
    os.environ['FLASK_ENV'] = 'development'
    os.environ['JWT_SECRET_KEY'] = 'dev-secret-key'
    os.environ['SECRET_KEY'] = 'dev-secret-key'

    if __name__ == "__main__":
        print("Initializing app in development mode for migration...")
        app = create_app('development')
        with app.app_context():
            print("Running migration...")
            migrate_role_column()
except Exception as e:
    print(f"Migration script failed with error: {e}")
    # Print traceback
    import traceback
    traceback.print_exc()
    sys.exit(1)
