from datetime import UTC, datetime, timedelta

import pytest

from backend.database import db
from backend.models.user import User


@pytest.fixture(scope='function')
def setup_users(app):
    with app.app_context():
        # Clear users before each test
        db.session.query(User).delete()
        db.session.commit()

def _create_user(**overrides):
    payload = {
        'id': overrides.pop('id', None),
        'username': overrides.pop('username', 'sub-test-user'),
        'email': overrides.pop('email', 'test@example.com'),
        'password_hash': 'hashed',
        'subscription_tier': overrides.pop('subscription_tier', 'premium'),
        'subscription_status': overrides.pop('subscription_status', 'active'),
        'current_period_end': overrides.pop(
            'current_period_end',
            datetime.now(UTC) + timedelta(days=30),
        ),
        'cancel_at_period_end': overrides.pop(
            'cancel_at_period_end', False
        ),
    }
    payload.update(overrides)
    user = User(**payload)
    db.session.add(user)
    db.session.commit()
    return user.id


import jwt
from datetime import UTC, datetime, timedelta, timezone

import pytest

from backend.database import db
from backend.models.user import User


@pytest.fixture(scope='function')
def setup_users(app):
    with app.app_context():
        # Clear users before each test
        db.session.query(User).delete()
        db.session.commit()

def _create_user(**overrides):
    payload = {
        'id': overrides.pop('id', None),
        'username': overrides.pop('username', 'sub-test-user'),
        'email': overrides.pop('email', 'test@example.com'),
        'password_hash': 'hashed',
        'subscription_tier': overrides.pop('subscription_tier', 'premium'),
        'subscription_status': overrides.pop('subscription_status', 'active'),
        'current_period_end': overrides.pop(
            'current_period_end',
            datetime.now(UTC) + timedelta(days=30),
        ),
        'cancel_at_period_end': overrides.pop(
            'cancel_at_period_end', False
        ),
    }
    payload.update(overrides)
    user = User(**payload)
    db.session.add(user)
    db.session.commit()
    return user.id

def _get_auth_headers(user_id):
    payload = {
        'user_id': user_id,
        'sub': user_id,
        'exp': int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
    }
    token = jwt.encode(payload, 'dev-secret-key', algorithm='HS256')
    return {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}


def test_get_subscription_success(client, setup_users):
    with client.application.app_context():
        user_id = _create_user()

    response = client.get(f'/api/user/{user_id}/subscription', headers=_get_auth_headers(user_id))
    assert response.status_code == 200
    data = response.get_json()

    assert data['user_id'] == user_id
    assert data['tier'] == 'premium'
    assert data['status'] == 'active'
    assert data['cancel_at_period_end'] is False
    assert data['current_period_end'].endswith('Z')


def test_get_subscription_defaults_when_missing_data(client, setup_users):
    with client.application.app_context():
        user_id = _create_user(
            subscription_tier='',
            subscription_status='',
            current_period_end=None,
        )

    response = client.get(f'/api/user/{user_id}/subscription', headers=_get_auth_headers(user_id))
    assert response.status_code == 200
    data = response.get_json()
    assert data['tier'] == 'free'
    assert data['status'] == 'active'
    assert data['current_period_end'] is None


def test_get_subscription_user_not_found(client, setup_users):
    # We still need a valid token from some user
    with client.application.app_context():
        caller_id = _create_user(id='caller-1', username='caller', email='caller@test.com')
    
    # Attempting to access OTHER user ID results in 403 Forbidden due to @require_owner
    response = client.get('/api/user/does-not-exist/subscription', headers=_get_auth_headers(caller_id))
    assert response.status_code == 403


def test_get_subscription_server_error(client, monkeypatch, setup_users):
    from backend.database import db
    
    with client.application.app_context():
        user_id = _create_user()

    def mock_get(*args, **kwargs):
        raise RuntimeError('db offline')

    monkeypatch.setattr(db.session, 'get', mock_get)

    response = client.get(f'/api/user/{user_id}/subscription', headers=_get_auth_headers(user_id))
    assert response.status_code == 500
    data = response.get_json()
    assert 'error' in data
