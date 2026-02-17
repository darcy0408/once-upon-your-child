import pytest
import json
from flask import jsonify, request
from backend.middleware.auth import require_auth, require_admin, require_owner, optional_auth
import jwt
from datetime import datetime, timedelta, timezone
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
        'exp': int((datetime.now(timezone.utc) - timedelta(hours=1)).timestamp())
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
        'exp': int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
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
        'exp': int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
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

# ============================================================================
# NEW AUTHENTICATION TESTS (Token Refresh & Login)
# ============================================================================

def test_get_anonymous_token_new_user(app, client):
    """Test creating a brand new anonymous user."""
    client_id = 'new_anon_device_777'
    payload = {'client_id': client_id}
    
    response = client.post('/auth/anonymous', 
                          data=json.dumps(payload), 
                          headers={'Content-Type': 'application/json'})
    
    assert response.status_code == 200
    assert 'token' in response.json
    assert response.json['user_id'] == client_id
    assert response.json['is_anonymous'] is True
    
    # Verify user was created in DB
    with app.app_context():
        user = db.session.get(User, client_id)
        assert user is not None
        assert user.id == client_id
        db.session.delete(user)
        db.session.commit()

def test_get_anonymous_token_existing_user_refresh(app, client):
    """Test 'refreshing' token for existing anonymous user (same client_id)."""
    client_id = 'existing_device_888'
    
    # Pre-create the user
    with app.app_context():
        user = User(id=client_id, username='existing_guest', email=f'{client_id}@anonymous.storyweaver.app')
        user.set_password('random')
        db.session.add(user)
        db.session.commit()
        
    payload = {'client_id': client_id}
    response = client.post('/auth/anonymous', 
                          data=json.dumps(payload), 
                          headers={'Content-Type': 'application/json'})
    
    assert response.status_code == 200
    assert 'token' in response.json
    assert response.json['user_id'] == client_id
    
    # Ensure no duplicate user was created
    with app.app_context():
        count = User.query.filter_by(id=client_id).count()
        assert count == 1
        
        # Cleanup
        user = db.session.get(User, client_id)
        db.session.delete(user)
        db.session.commit()

def test_login_success(app, client):
    """Test successful login with credentials."""
    username = 'login_test_user'
    password = 'secure_password'
    
    with app.app_context():
        user = User(id='login_uid_123', username=username, email='login@test.com')
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        
    payload = {'username': username, 'password': password}
    response = client.post('/auth/login', 
                          data=json.dumps(payload), 
                          headers={'Content-Type': 'application/json'})
    
    assert response.status_code == 200
    assert 'token' in response.json
    
    # Cleanup
    with app.app_context():
        user = db.session.get(User, 'login_uid_123')
        db.session.delete(user)
        db.session.commit()

def test_login_invalid_credentials(app, client):
    """Test login failure with wrong password."""
    username = 'wrong_pass_user'
    
    with app.app_context():
        user = User(id='wrong_uid_456', username=username, email='wrong@test.com')
        user.set_password('correct_password')
        db.session.add(user)
        db.session.commit()
        
    payload = {'username': username, 'password': 'incorrect_password'}
    response = client.post('/auth/login', 
                          data=json.dumps(payload), 
                          headers={'Content-Type': 'application/json'})
    
    assert response.status_code == 401
    assert 'Invalid credentials' in response.json['message']
    
    # Cleanup
    with app.app_context():
        user = db.session.get(User, 'wrong_uid_456')
        db.session.delete(user)
        db.session.commit()

def test_token_validation_edge_cases(app, client, auth_headers):
    """Verify various token failure modes are handled correctly."""
    setup_test_routes(app)
    
    # 1. Malformed token (missing 'Bearer ' prefix)
    bad_headers = {'Authorization': 'JustTheTokenValue'}
    response = client.get('/test/auth', headers=bad_headers)
    assert response.status_code == 401
    
    # 2. Token with non-existent user_id in payload
    payload = {
        'user_id': 'missing_user_uuid',
        'exp': int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    ghost_token = jwt.encode(payload, 'dev-secret-key', algorithm='HS256')
    response = client.get('/test/auth', headers={'Authorization': f'Bearer {ghost_token}'})
    assert response.status_code == 401
    assert response.json['error'] == 'User not found'

def test_anonymous_token_refresh_flow(app, client):
    """Test getting a new token for an existing anonymous user."""
    setup_test_routes(app)
    client_id = 'persistent_device_id'
    payload = {'client_id': client_id}
    
    # 1. Get initial token
    resp1 = client.post('/auth/anonymous', 
                       data=json.dumps(payload), 
                       headers={'Content-Type': 'application/json'})
    token1 = resp1.json['token']
    
    # 2. Get "refreshed" token (same client_id)
    resp2 = client.post('/auth/anonymous', 
                       data=json.dumps(payload), 
                       headers={'Content-Type': 'application/json'})
    token2 = resp2.json['token']
    
    assert token1 != token2  # Tokens should be different because of 'iat' or 'jti'
    
    # 3. Verify both tokens are valid
    for token in [token1, token2]:
        headers = {'Authorization': f'Bearer {token}'}
        resp = client.get('/test/auth', headers=headers)
        assert resp.status_code == 200
        assert resp.json['user_id'] == client_id

def test_iam_manager_isolation():
    """Test the IdentityAccessManager in isolation (from security/iam.py)."""
    from security.iam import IdentityAccessManager
    iam = IdentityAccessManager()
    
    user_id = 'test_iam_user'
    role = 'user'
    
    # Test token generation
    tokens = iam.generate_tokens(user_id, role)
    assert 'access_token' in tokens
    assert 'refresh_token' in tokens
    
    # Test validation
    payload = iam.validate_token(tokens['access_token'])
    assert payload is not None
    assert payload['user_id'] == user_id
    assert payload['role'] == role
    
    # Test refresh flow
    import time
    time.sleep(1.1)
    new_tokens = iam.refresh_access_token(tokens['refresh_token'])
    assert new_tokens is not None
    assert new_tokens['access_token'] != tokens['access_token']
    
    # Test permission check
    assert iam.check_permission('admin', 'any:permission') is True
    assert iam.check_permission('user', 'create:story') is True
    assert iam.check_permission('user', 'admin:access') is False

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
