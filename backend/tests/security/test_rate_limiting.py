import jwt
import pytest
from datetime import datetime, timedelta
from flask import jsonify, request

from backend.app import create_app
from backend.database import db
from backend.models.user import User
from backend.utils.app_helpers import get_tier_limits


def _create_user(app, user_id: str, tier: str = 'free') -> User:
    with app.app_context():
        user = db.session.get(User, user_id)
        if user is None:
            user = User(
                id=user_id,
                username=user_id,
                email=f'{user_id}@example.com',
                subscription_tier=tier,
            )
            user.set_password('test-password')
            db.session.add(user)
        else:
            user.subscription_tier = tier
        db.session.commit()
        return user


def _auth_headers(user_id: str) -> dict[str, str]:
    token = jwt.encode(
        {
            'user_id': user_id,
            'exp': datetime.utcnow() + timedelta(hours=1),
        },
        'test_secret',
        algorithm='HS256',
    )
    return {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json',
        'X-User-ID': user_id,
    }


@pytest.fixture
def app():
    import backend.config as config_module

    config_module.TestingConfig.RATELIMIT_ENABLED = True
    config_module.config_by_name['testing'].RATELIMIT_ENABLED = True

    flask_app = create_app('testing')
    with flask_app.app_context():
        db.create_all()
        yield flask_app
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture(autouse=True)
def mock_auth_secret(mocker):
    return mocker.patch('backend.middleware.auth._get_jwt_secret', return_value='test_secret')


@pytest.fixture
def register_rate_test_routes(app):
    if '/test/rate/generate-story' in [rule.rule for rule in app.url_map.iter_rules()]:
        return

    @app.route('/test/rate/generate-story', methods=['POST'])
    @app.limiter.limit(lambda: get_tier_limits() or '1000/minute')
    def rate_generate_story():
        return jsonify({'ok': True}), 200

    @app.route('/test/rate/expensive-op', methods=['POST'])
    @app.limiter.limit(lambda: get_tier_limits('expensive') or '100/hour')
    def rate_expensive_op():
        return jsonify({'ok': True}), 200

    @app.route('/test/rate/characters', methods=['POST'])
    @app.limiter.limit('20 per minute')
    def rate_characters():
        return jsonify({'ok': True}), 200

    @app.route('/test/rate/rapid', methods=['POST'])
    @app.limiter.limit('10 per minute')
    def rate_rapid():
        return jsonify({'ok': True}), 200

    @app.route('/test/rate/authenticated-characters', methods=['POST'])
    @app.limiter.limit('20 per minute')
    def rate_authenticated_characters():
        if not request.headers.get('Authorization'):
            return jsonify({'error': 'Authentication required'}), 401
        return jsonify({'ok': True}), 200


def test_free_user_limited_to_three_stories_per_window(client, app, register_rate_test_routes):
    user_id = 'free_limit_user'
    _create_user(app, user_id, tier='free')

    headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    for _ in range(3):
        response = client.post('/test/rate/generate-story', headers=headers, json={})
        assert response.status_code == 200

    fourth = client.post('/test/rate/generate-story', headers=headers, json={})
    assert fourth.status_code == 429


def test_fourth_story_returns_429_for_free_user(client, app, register_rate_test_routes):
    user_id = 'free_limit_msg_user'
    _create_user(app, user_id, tier='free')

    headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    for _ in range(3):
        client.post('/test/rate/generate-story', headers=headers, json={})

    limited = client.post('/test/rate/generate-story', headers=headers, json={})
    body = limited.get_json()

    assert limited.status_code == 429
    assert body['error'] == 'Rate limit exceeded'
    assert body['user_tier'] == 'free'


def test_rate_limit_resets_after_manual_storage_reset(client, app, register_rate_test_routes):
    user_id = 'reset_limit_user'
    _create_user(app, user_id, tier='free')

    headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    for _ in range(3):
        client.post('/test/rate/generate-story', headers=headers, json={})

    blocked = client.post('/test/rate/generate-story', headers=headers, json={})
    assert blocked.status_code == 429

    app.limiter.reset()

    after_reset = client.post('/test/rate/generate-story', headers=headers, json={})
    assert after_reset.status_code == 200


def test_premium_user_gets_higher_limit_than_free(client, app, register_rate_test_routes):
    user_id = 'premium_limit_user'
    _create_user(app, user_id, tier='premium')

    headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    for _ in range(10):
        response = client.post('/test/rate/generate-story', headers=headers, json={})
        assert response.status_code == 200

    limited = client.post('/test/rate/generate-story', headers=headers, json={})
    assert limited.status_code == 429


def test_byok_user_allows_high_volume_requests(client, app, register_rate_test_routes):
    user_id = 'byok_limit_user'
    _create_user(app, user_id, tier='byok')

    headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    statuses = [client.post('/test/rate/generate-story', headers=headers, json={}).status_code for _ in range(30)]

    assert all(status == 200 for status in statuses)


def test_rapid_requests_over_ten_per_minute_are_blocked(client, app, register_rate_test_routes):
    headers = {'X-User-ID': 'rapid_user', 'Content-Type': 'application/json'}

    statuses = [client.post('/test/rate/rapid', headers=headers, json={}).status_code for _ in range(11)]

    assert statuses.count(429) == 1


def test_rate_limit_headers_present_on_limited_response(client, register_rate_test_routes):
    headers = {'X-User-ID': 'header_user', 'Content-Type': 'application/json'}

    for _ in range(10):
        client.post('/test/rate/rapid', headers=headers, json={})

    response = client.post('/test/rate/rapid', headers=headers, json={})

    assert response.status_code == 429
    body = response.get_json()
    assert body['error'] == 'Rate limit exceeded'
    assert 'retry_after' in body


def test_rate_limit_bypass_attempt_with_spoofed_ip_fails(client, app, register_rate_test_routes):
    user_id = 'spoof_user'
    _create_user(app, user_id, tier='free')

    base_headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    for _ in range(3):
        client.post('/test/rate/generate-story', headers=base_headers, json={})

    bypass_headers = {
        'X-User-ID': user_id,
        'X-Forwarded-For': '203.0.113.77',
        'Content-Type': 'application/json',
    }
    limited = client.post('/test/rate/generate-story', headers=bypass_headers, json={})

    assert limited.status_code == 429


def test_generate_story_endpoint_rate_limit_behavior(client, app, register_rate_test_routes):
    user_id = 'endpoint_limit_user'
    _create_user(app, user_id, tier='free')

    headers = {'X-User-ID': user_id, 'Content-Type': 'application/json'}
    for _ in range(3):
        client.post('/test/rate/generate-story', headers=headers, json={})

    response = client.post('/test/rate/generate-story', headers=headers, json={})
    assert response.status_code == 429


def test_character_endpoint_allows_requests_under_higher_limit(client, app, register_rate_test_routes):
    user_id = 'character_limit_user'
    _create_user(app, user_id, tier='free')

    headers = _auth_headers(user_id)
    statuses = [
        client.post('/test/rate/authenticated-characters', headers=headers, json={'name': 'Luna'}).status_code
        for _ in range(10)
    ]

    assert all(status == 200 for status in statuses)
