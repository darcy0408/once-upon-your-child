import pytest
from flask import jsonify, request
from backend.middleware.auth import require_auth, require_admin, require_owner, optional_auth
import jwt
from datetime import datetime, timedelta
import os
from backend.models.user import User
from backend.database import db

# Test routes to verify decorators
def setup_test_routes(app):
    if '/test/auth' in [rule.rule for rule in app.url_map.iter_rules()]:
        return

    @app.route('/test/auth')
    @require_auth
    def test_auth():
        return jsonify({'message': 'authenticated', 'user_id': request.current_user.id})

    @app.route('/test/admin')
    @require_auth
    @require_admin
    def test_admin():
        return jsonify({'message': 'admin_access'})

    @app.route('/test/owner/<user_id>')
    @require_auth
    @require_owner('user_id')
    def test_owner(user_id):
        return jsonify({'message': 'owner_access', 'user_id': user_id})

    @app.route('/test/owner-misconfigured')
    @require_auth
    @require_owner('missing_user_id_param')
    def test_owner_misconfigured():
        return jsonify({'message': 'should_not_reach'})

    @app.route('/test/optional')
    @optional_auth
    def test_optional():
        user_id = request.current_user.id if request.current_user else None
        return jsonify({'message': 'optional_access', 'user_id': user_id})

@pytest.fixture(autouse=True)
def mock_auth_secret(mocker):
    """Ensure authentication uses the same secret as the test tokens."""
    return mocker.patch('backend.middleware.auth._get_jwt_secret', return_value='dev-secret-key')

def test_require_auth_valid_token(app, client, test_user, auth_headers):
    setup_test_routes(app)

    response = client.get('/test/auth', headers=auth_headers)
    assert response.status_code == 200
    assert response.json['message'] == 'authenticated'
    assert response.json['user_id'] == test_user.id

def test_require_auth_missing_token(app, client):
    setup_test_routes(app)
    
    response = client.get('/test/auth')
    assert response.status_code == 401
    assert 'Authentication required' in response.json['error']

def test_require_auth_invalid_token(app, client):
    setup_test_routes(app)
    
    headers = {'Authorization': 'Bearer invalid-token'}
    response = client.get('/test/auth', headers=headers)
    assert response.status_code == 401
    assert 'Invalid token' in response.json['error']

def test_require_auth_expired_token(app, client):
    setup_test_routes(app)
    
    payload = {
        'user_id': 'test_user_123',
        'exp': datetime.utcnow() - timedelta(hours=1)
    }
    expired_token = jwt.encode(payload, 'dev-secret-key', algorithm='HS256')
    headers = {'Authorization': f'Bearer {expired_token}'}
    
    response = client.get('/test/auth', headers=headers)
    assert response.status_code == 401
    assert 'Token expired' in response.json['error']


def test_require_auth_user_not_found(app, client):
    setup_test_routes(app)

    payload = {
        'user_id': 'ghost_user_404',
        'exp': datetime.utcnow() + timedelta(hours=1)
    }
    token = jwt.encode(payload, 'dev-secret-key', algorithm='HS256')
    headers = {'Authorization': f'Bearer {token}'}

    response = client.get('/test/auth', headers=headers)
    assert response.status_code == 401
    assert response.json['error'] == 'User not found'

def test_require_admin_success(app, client):
    setup_test_routes(app)

    admin_id = 'admin_user_99'
    with app.app_context():
        admin = User(id=admin_id, username='admin_test', email='admin@test.com', role='admin')
        admin.set_password('password')
        db.session.add(admin)
        db.session.commit()

    # Generate token for this specific user
    payload = {
        'user_id': admin_id,
        'exp': datetime.utcnow() + timedelta(hours=1)
    }
    token = jwt.encode(payload, 'dev-secret-key', algorithm='HS256')
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

    response = client.get('/test/admin', headers=headers)
    assert response.status_code == 200
    assert response.json['message'] == 'admin_access'
def test_require_admin_failure(app, client, test_user, auth_headers):
    setup_test_routes(app)
    
    # User role is 'free' by default (not admin)
    response = client.get('/test/admin', headers=auth_headers)
    assert response.status_code == 403
    assert 'Admin access required' in response.json['error']

def test_require_owner_success(app, client, test_user, auth_headers):
    setup_test_routes(app)
    
    response = client.get(f'/test/owner/{test_user.id}', headers=auth_headers)
    assert response.status_code == 200
    assert response.json['message'] == 'owner_access'
    assert response.json['user_id'] == test_user.id

def test_require_owner_failure(app, client, test_user, auth_headers):
    setup_test_routes(app)
    
    # Attempt to access another user's resource
    response = client.get('/test/owner/another_user_id', headers=auth_headers)
    assert response.status_code == 403
    assert 'Access denied' in response.json['error']

def test_optional_auth_with_user(app, client, test_user, auth_headers):
    setup_test_routes(app)
    
    response = client.get('/test/optional', headers=auth_headers)
    assert response.status_code == 200
    assert response.json['user_id'] == test_user.id

def test_optional_auth_without_user(app, client):
    setup_test_routes(app)
    
    response = client.get('/test/optional')
    assert response.status_code == 200
    assert response.json['user_id'] is None


def test_optional_auth_invalid_token_graceful(app, client):
    setup_test_routes(app)

    headers = {'Authorization': 'Bearer malformed.token.value'}
    response = client.get('/test/optional', headers=headers)

    assert response.status_code == 200
    assert response.json['message'] == 'optional_access'
    assert response.json['user_id'] is None


def test_require_owner_missing_param_returns_400(app, client, test_user, auth_headers):
    setup_test_routes(app)

    response = client.get('/test/owner-misconfigured', headers=auth_headers)
    assert response.status_code == 400
    assert response.json['error'] == 'Invalid request'

def test_idor_protection_detailed(app, client, test_user, auth_headers):
    """Test detailed IDOR protection scenarios."""
    setup_test_routes(app)
    
    # 1. Owner can access their own data
    resp = client.get(f'/test/owner/{test_user.id}', headers=auth_headers)
    assert resp.status_code == 200
    
    # 2. User CANNOT access another user's ID
    resp = client.get('/test/owner/victim_user_999', headers=auth_headers)
    assert resp.status_code == 403
    assert resp.json['error'] == 'Access denied'
    
    # 3. Path traversal attempt in ID
    resp = client.get(f'/test/owner/../admin', headers=auth_headers)
    # Flask/Werkzeug might handle this differently, but it shouldn't allow ownership bypass
    assert resp.status_code != 200 or resp.json.get('message') != 'admin_access'
