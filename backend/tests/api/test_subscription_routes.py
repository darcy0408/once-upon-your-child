from datetime import datetime, timedelta

import pytest
import jwt

from backend.database import db
from backend.models.story import Story
from backend.models.user import User


@pytest.fixture(autouse=True)
def mock_auth_secret(mocker):
    """Ensure JWT validation uses the same secret as test token fixtures."""
    return mocker.patch('backend.middleware.auth._get_jwt_secret', return_value='test_secret')


@pytest.fixture
def test_user(app):
    """Create a local test user compatible with current User model."""
    with app.app_context():
        user = User(
            id='test_user_123',
            username='test_user_123',
            email='test@example.com',
            subscription_tier='free',
        )
        user.set_password('test-password')
        db.session.add(user)
        db.session.commit()
        yield user
        Story.query.filter_by(user_id=user.id).delete()
        db.session.delete(user)
        db.session.commit()


def _get_user(user_id: str) -> User:
    user = db.session.get(User, user_id)
    assert user is not None
    return user


def _create_user(user_id: str, tier: str) -> User:
    user = User(
        id=user_id,
        username=user_id,
        email=f'{user_id}@example.com',
        subscription_tier=tier,
    )
    user.set_password('test-password')
    db.session.add(user)
    db.session.commit()
    return user


def _auth_headers(user_id: str) -> dict[str, str]:
    token = jwt.encode(
        {'user_id': user_id, 'email': f'{user_id}@example.com', 'exp': datetime.utcnow() + timedelta(hours=1)},
        'test_secret',
        algorithm='HS256',
    )
    return {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json',
    }


class TestSubscriptionRoutes:
    def test_get_subscription_returns_free_tier(self, client, app, test_user):
        with app.app_context():
            user = _get_user(test_user.id)
            user.subscription_tier = 'free'
            user.subscription_status = 'active'
            user.cancel_at_period_end = False
            user.current_period_end = None
            db.session.commit()

        response = client.get(f'/api/user/{test_user.id}/subscription')

        assert response.status_code == 200
        body = response.get_json()
        assert body['user_id'] == test_user.id
        assert body['tier'] == 'free'
        assert body['status'] == 'active'
        assert body['cancel_at_period_end'] is False

    def test_get_subscription_returns_premium_tier_with_period_end(self, client, app, test_user):
        period_end = datetime.utcnow() + timedelta(days=30)
        with app.app_context():
            user = _create_user('premium_user_123', 'premium')
            user.subscription_status = 'active'
            user.cancel_at_period_end = True
            user.current_period_end = period_end
            db.session.commit()
            db.session.remove()

        response = client.get('/api/user/premium_user_123/subscription')

        assert response.status_code == 200
        body = response.get_json()
        assert body['tier'] == 'premium'
        assert body['status'] == 'active'
        assert body['cancel_at_period_end'] is True
        assert body['current_period_end'] is not None

    def test_get_subscription_returns_404_for_unknown_user(self, client):
        response = client.get('/api/user/missing_user/subscription')

        assert response.status_code == 404
        body = response.get_json()
        assert body['error'] == 'User not found'

    def test_usage_stats_story_count_increments(self, client, app, test_user, auth_headers):
        with app.app_context():
            db.session.add(Story(user_id=test_user.id, title='Story One'))
            db.session.add(Story(user_id=test_user.id, title='Story Two'))
            db.session.commit()

        response = client.get(f'/api/user/{test_user.id}/usage-stats', headers=auth_headers)

        assert response.status_code == 200
        body = response.get_json()
        assert body['stories_this_month'] == 2

    def test_usage_stats_returns_tier_limits(self, client, app, test_user, auth_headers):
        free_response = client.get(f'/api/user/{test_user.id}/usage-stats', headers=auth_headers)
        assert free_response.status_code == 200
        assert free_response.get_json()['stories_limit'] == 10

        with app.app_context():
            _create_user('premium_usage_user', 'premium')
            db.session.remove()

        premium_response = client.get(
            '/api/user/premium_usage_user/usage-stats',
            headers=_auth_headers('premium_usage_user'),
        )
        assert premium_response.status_code == 200
        assert premium_response.get_json()['stories_limit'] == 100
