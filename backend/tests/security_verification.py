
import pytest
import json
from backend.models.user import User
from backend.models.character import Character
from backend.database import db

# Note: We rely on 'app' fixture from conftest.py which provides active app_context.

@pytest.fixture
def admin_user(app):
    # No extra app_context logic needed if conftest provides it
    user = db.session.get(User, 'admin_test')
    if not user:
        user = User(
            id='admin_test',
            username='admin_test',
            email='admin@test.com',
            role='admin'
        )
        user.set_password('password')
        db.session.add(user)
        db.session.commit()
    yield user
    # Cleanup
    # db.session.delete(user) # In session scope, cleanup might be handled by db.drop_all or careful deletes
    # For now explicit delete is safe usually
    db.session.delete(user)
    db.session.commit()

@pytest.fixture
def regular_user(app):
    user = db.session.get(User, 'user_test')
    if not user:
        user = User(
            id='user_test',
            username='user_test',
            email='user@test.com',
            role='user'
        )
        user.set_password('password')
        db.session.add(user)
        db.session.commit()
    yield user
    db.session.delete(user)
    db.session.commit()

@pytest.fixture
def user_character(app, regular_user):
    char = Character(
        id='char_test',
        name='Test Char',
        age=10,
        user_id=regular_user.id
    )
    db.session.add(char)
    db.session.commit()
    yield char
    c = db.session.get(Character, 'char_test')
    if c:
        db.session.delete(c)
        db.session.commit()

@pytest.fixture
def auth_headers(app, regular_user):
    from flask_jwt_extended import create_access_token
    token = create_access_token(identity=regular_user.id)
    return {'Authorization': f'Bearer {token}'}

@pytest.fixture
def admin_auth_headers(app, admin_user):
    from flask_jwt_extended import create_access_token
    token = create_access_token(identity=admin_user.id)
    return {'Authorization': f'Bearer {token}'}

def test_admin_route_access_denied_no_auth(client):
    """Test admin route without auth."""
    # Use the client directly
    response = client.get('/admin/analytics/overview')
    assert response.status_code == 401

def test_admin_route_access_denied_regular_user(client, auth_headers):
    """Test admin route with regular user auth."""
    response = client.get('/admin/analytics/overview', headers=auth_headers)
    assert response.status_code == 403

def test_admin_route_access_granted_admin(client, admin_auth_headers):
    """Test admin route with admin user auth."""
    response = client.get('/admin/analytics/overview', headers=admin_auth_headers)
    assert response.status_code == 200
    data = json.loads(response.data)
    # The analytics route returns various keys
    assert 'total_users' in data or 'today' in data or 'users' in data

def test_endor_protection_user_stats(client, regular_user, auth_headers):
    """Test user cannot access another user's stats."""
    other_id = 'other_user_id'
    response = client.get(f'/api/user/{other_id}/usage-stats', headers=auth_headers)
    assert response.status_code == 403

def test_idor_protection_delete_other_character(client, app, user_character):
    """Test attacker cannot delete valid user's character."""
    # Create attacker
    attacker = db.session.get(User, 'attacker')
    if not attacker:
        attacker = User(id='attacker', username='att', email='att@test.com', role='user')
        attacker.set_password('password')
        db.session.add(attacker)
        db.session.commit()
    
    from flask_jwt_extended import create_access_token
    token = create_access_token(identity=attacker.id)
    attacker_headers = {'Authorization': f'Bearer {token}'}
    
    try:
        # Corrected URL path
        response = client.delete(f'/characters/{user_character.id}', headers=attacker_headers)
        assert response.status_code == 403
        
    finally:
        u = db.session.get(User, 'attacker')
        if u:
            db.session.delete(u)
            db.session.commit()
