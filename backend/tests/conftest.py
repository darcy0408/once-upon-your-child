import pytest
from backend.app import create_app
from backend.database import db as _db
from backend.routes.auth_routes import auth_bp
from backend.routes.progression_routes import progression_bp
from backend.routes.story_routes import story_bp
from backend.routes.character_routes import character_bp

@pytest.fixture
def app():
    """Create and configure a new app instance for each test."""
    # create a temporary file to isolate the database for each test
    app = create_app('development')
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['TESTING'] = True

    with app.app_context():
        _db.create_all()
        app.register_blueprint(auth_bp, url_prefix='/auth')
        app.register_blueprint(progression_bp, url_prefix='/progression')
        app.register_blueprint(story_bp, url_prefix='/story')
        app.register_blueprint(character_bp, url_prefix='/character')
        
        # Ensure database is accessible for health check
        try:
            _db.session.execute(_db.text('SELECT 1'))
            _db.session.commit()
        except Exception as e:
            print(f"Error during database setup in test fixture: {e}")
            _db.session.rollback()

        yield app

        _db.session.remove()
        _db.drop_all()


@pytest.fixture
def client(app):
    """A test client for the app."""
    return app.test_client()