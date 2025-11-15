import pytest
from backend.app import create_app
from backend.database import db

@pytest.fixture(scope='module')
def app():
    """Instance of Main flask app"""
    app = create_app('development')
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    return app

@pytest.fixture(scope='module')
def client(app):
    """Flask test client"""
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
        yield client
        with app.app_context():
            db.drop_all()