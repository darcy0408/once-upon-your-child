import pytest
import json
import os
import time
import flask
from backend.models.user import User
from backend.database import db
from backend.app import create_app
from backend.config import TestingConfig
from unittest.mock import patch, MagicMock

@pytest.fixture
def ratelimit_app():
    """
    App fixture with rate limiting explicitly enabled.
    """
    from backend.config import config_by_name
    import backend.tasks.story_tasks as story_tasks
    import backend.utils.app_helpers as app_helpers
    
    class RateLimitTestingConfig(TestingConfig):
        RATELIMIT_ENABLED = True
        RATELIMIT_STORAGE_URI = "memory://"
        RATELIMIT_HEADERS_ENABLED = True
        CELERY_TASK_ALWAYS_EAGER = True

    new_configs = {k: RateLimitTestingConfig for k in config_by_name.keys()}

    with patch('backend.app.config_by_name', new_configs):
        app = create_app('testing')
        app.limiter.enabled = True
        story_tasks._flask_app = app
        
        @app.route("/verify-limiter")
        @app.limiter.limit("2 per minute")
        def verify_limiter():
            # Standard helper to get ID for debugging
            from backend.utils.app_helpers import get_user_identifier
            return flask.jsonify({
                "status": "ok", 
                "identifier": get_user_identifier()
            }), 200
            
        with app.app_context():
            db.create_all()
            if not db.session.get(User, 'anonymous'):
                anon = User(id='anonymous', username='anonymous', email='anon@test.com', password_hash='hash')
                db.session.add(anon)
                db.session.commit()
            
            yield app
            db.session.remove()
            db.drop_all()
            story_tasks._flask_app = None

@pytest.fixture
def ratelimit_client(ratelimit_app):
    return ratelimit_app.test_client()

@pytest.fixture
def free_user_id(ratelimit_app):
    with ratelimit_app.app_context():
        user = User(
            id='free_user_limit_test',
            username='freeuser_limit',
            email='free_limit@example.com',
            password_hash='hashed_password',
            subscription_tier='free'
        )
        db.session.add(user)
        db.session.commit()
        return 'free_user_limit_test'

def test_limiter_identifier_and_sharing(ratelimit_client, free_user_id):
    """
    Test that the limiter correctly uses X-User-ID and shares state across routes.
    """
    headers = {'X-User-ID': free_user_id}
    
    # Request 1
    resp = ratelimit_client.get('/verify-limiter', headers=headers)
    assert resp.status_code == 200
    assert json.loads(resp.data)['identifier'] == f"user:{free_user_id}"
    
    # Request 2
    resp = ratelimit_client.get('/verify-limiter', headers=headers)
    assert resp.status_code == 200
    
    # Request 3 - Should be 429
    resp = ratelimit_client.get('/verify-limiter', headers=headers)
    assert resp.status_code == 429

def test_rate_limit_isolated_per_user_identifier(ratelimit_client, ratelimit_app):
    """
    Test that limits are scoped per user identifier, not globally shared.
    """
    with ratelimit_app.app_context():
        user_a = User(
            id='rate_user_a',
            username='rate_user_a',
            email='a@example.com',
            password_hash='hashed_password',
            subscription_tier='free'
        )
        user_b = User(
            id='rate_user_b',
            username='rate_user_b',
            email='b@example.com',
            password_hash='hashed_password',
            subscription_tier='free'
        )
        db.session.add_all([user_a, user_b])
        db.session.commit()

    headers_a = {'X-User-ID': 'rate_user_a'}
    headers_b = {'X-User-ID': 'rate_user_b'}

    # User A consumes limit.
    assert ratelimit_client.get('/verify-limiter', headers=headers_a).status_code == 200
    assert ratelimit_client.get('/verify-limiter', headers=headers_a).status_code == 200
    assert ratelimit_client.get('/verify-limiter', headers=headers_a).status_code == 429

    # User B should still have full limit independently.
    assert ratelimit_client.get('/verify-limiter', headers=headers_b).status_code == 200
    assert ratelimit_client.get('/verify-limiter', headers=headers_b).status_code == 200
    assert ratelimit_client.get('/verify-limiter', headers=headers_b).status_code == 429

def test_free_tier_real_limits(ratelimit_client, free_user_id):
    """
    Test that free tier users are rate limited using real app limits (3/min).
    """
    headers = {'X-User-ID': free_user_id, 'Content-Type': 'application/json'}
    payload = {'character': 'Test Hero', 'age': 5}

    # App default for free is 3/minute.
    for i in range(3):
        # Story generation can fail in CI if external model credentials are absent.
        # Rate-limit behavior should still allow the first 3 requests through.
        assert ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers).status_code != 429
    
    # 4th request should be 429
    response = ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers)
    assert response.status_code == 429

def test_rate_limit_headers(ratelimit_client):
    """
    Test that rate limit headers are present.
    """
    response = ratelimit_client.get('/verify-limiter')
    assert response.status_code == 200
    assert 'X-RateLimit-Limit' in response.headers
    assert 'X-RateLimit-Remaining' in response.headers

def test_premium_tier_limits(ratelimit_client, ratelimit_app):
    """
    Test that premium tier users have higher limits (10/min).
    """
    with ratelimit_app.app_context():
        user = User(
            id='premium_user_test',
            username='premiumuser',
            email='premium@example.com',
            password_hash='hash',
            subscription_tier='premium'
        )
        db.session.add(user)
        db.session.commit()

    headers = {'X-User-ID': 'premium_user_test', 'Content-Type': 'application/json'}
    payload = {'character': 'Test Hero', 'age': 5}

    # Should allow 10 requests
    for i in range(10):
        resp = ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers)
        assert resp.status_code == 200, f"Request {i+1} failed"
    
    # 11th request should be 429
    assert ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers).status_code == 429

def test_family_tier_limits(ratelimit_client, ratelimit_app):
    """
    Test that family tier users have even higher limits (15/min).
    """
    with ratelimit_app.app_context():
        user = User(
            id='family_user_test',
            username='familyuser',
            email='family@example.com',
            password_hash='hash',
            subscription_tier='family'
        )
        db.session.add(user)
        db.session.commit()

    headers = {'X-User-ID': 'family_user_test', 'Content-Type': 'application/json'}
    payload = {'character': 'Test Hero', 'age': 5}

    # Should allow 15 requests
    for i in range(15):
        resp = ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers)
        assert resp.status_code == 200, f"Request {i+1} failed"
    
    # 16th request should be 429
    assert ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers).status_code == 429

def test_rate_limit_reset_behavior(ratelimit_client, ratelimit_app):
    """
    Test that rate limits eventually reset.
    """
    # Use a very low limit for quick testing
    @ratelimit_app.route("/quick-reset")
    @ratelimit_app.limiter.limit("1 per 2 seconds")
    def quick_reset():
        return flask.jsonify({"status": "ok"}), 200

    headers = {'X-User-ID': 'reset_user_test'}
    
    # 1st request ok
    assert ratelimit_client.get('/quick-reset', headers=headers).status_code == 200
    # 2nd request 429
    assert ratelimit_client.get('/quick-reset', headers=headers).status_code == 429
    
    # Wait for reset
    time.sleep(2.1)
    
    # 3rd request ok again
    assert ratelimit_client.get('/quick-reset', headers=headers).status_code == 200

def test_byok_tier_limits(ratelimit_client, ratelimit_app):
    """
    Test that BYOK users have extremely high limits (effectively unlimited for tests).
    """
    with ratelimit_app.app_context():
        user = User(
            id='byok_user_test',
            username='byokuser',
            email='byok@example.com',
            password_hash='hash',
            subscription_tier='byok'
        )
        db.session.add(user)
        db.session.commit()

    headers = {'X-User-ID': 'byok_user_test', 'Content-Type': 'application/json'}
    payload = {'character': 'Test Hero', 'age': 5}

    # Should allow 20 requests without any issue (higher than family limit)
    for i in range(20):
        resp = ratelimit_client.post('/generate-story', data=json.dumps(payload), headers=headers)
        assert resp.status_code == 200, f"Request {i+1} failed"

def test_ip_fallback_identifier_when_no_user_header(ratelimit_client):
    """
    Test limiter falls back to IP identifier when X-User-ID is missing.
    """
    response = ratelimit_client.get('/verify-limiter')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['identifier'].startswith('ip:')
