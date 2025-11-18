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


def test_get_subscription_success(client, setup_users):
    with client.application.app_context():
        user_id = _create_user()

    response = client.get(f'/api/user/{user_id}/subscription')
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

    response = client.get(f'/api/user/{user_id}/subscription')
    assert response.status_code == 200
    data = response.get_json()
    assert data['tier'] == 'free'
    assert data['status'] == 'active'
    assert data['current_period_end'] is None


def test_get_subscription_user_not_found(client, setup_users):
    response = client.get('/api/user/does-not-exist/subscription')
    assert response.status_code == 404
    data = response.get_json()
    assert data['error'] == 'User not found'


def test_get_subscription_server_error(client, monkeypatch, setup_users):
    class _BrokenQuery:
        def get(self, _):
            raise RuntimeError('db offline')

    monkeypatch.setattr(User, 'query', _BrokenQuery())

    response = client.get('/api/user/any/subscription')
    assert response.status_code == 500
    data = response.get_json()
    assert 'error' in data
