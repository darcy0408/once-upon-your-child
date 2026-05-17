import uuid
from datetime import datetime, timedelta, UTC
import pytest
from backend.database import db
from backend.models.user import User
from backend.models.character import Character
from backend.models.story import Story

import jwt

@pytest.fixture(scope='function')
def setup_data(app):
    with app.app_context():
        # Clear data before each test
        db.session.query(Story).delete()
        db.session.query(Character).delete()
        db.session.query(User).delete()
        db.session.commit()

def _auth_headers(app, user_id):
    secret = app.config.get("JWT_SECRET_KEY") or "dev-secret-key"
    token = jwt.encode(
        {
            "user_id": user_id,
            "sub": user_id,
            "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
        },
        secret,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

def _create_user(**overrides):
    payload = {
        'id': overrides.pop('id', str(uuid.uuid4())),
        'username': overrides.pop('username', f"user_{uuid.uuid4().hex[:8]}"),
        'email': overrides.pop('email', f"{uuid.uuid4().hex[:8]}@example.com"),
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

def _create_story(user_id, created_at=None):
    if created_at is None:
        created_at = datetime.now(UTC)
    story = Story(user_id=user_id, title='Test Story', created_at=created_at)
    db.session.add(story)
    db.session.commit()
    return story.id

def _create_character(user_id):
    character = Character(
        id=str(uuid.uuid4()),
        user_id=user_id,
        name='Test Character',
        age=7,
        gender='male',
        role='hero'
    )
    db.session.add(character)
    db.session.commit()
    return character.id

def test_get_usage_stats_success(client, setup_data):
    with client.application.app_context():
        user_id = _create_user(subscription_tier='premium')
        # Create 45 stories this month (all within current month)
        now = datetime.now(UTC)
        period_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        for i in range(45):
            # Create stories with timezone-aware datetime matching route expectations
            story_time = period_start + timedelta(hours=i)
            _create_story(user_id, created_at=story_time.replace(tzinfo=None))
        # Create 3 characters
        for _ in range(3):
            _create_character(user_id)

    headers = _auth_headers(client.application, user_id)
    response = client.get(f'/api/user/{user_id}/usage-stats', headers=headers)
    assert response.status_code == 200
    data = response.get_json()

    assert data['stories_this_month'] == 45
    assert data['stories_limit'] == 100
    assert data['characters_count'] == 3
    assert data['characters_limit'] == 5
    assert 'period_start' in data
    assert 'period_end' in data

def test_get_usage_stats_user_not_found(client, setup_data):
    user_id = "some-random-id"
    headers = _auth_headers(client.application, user_id)
    response = client.get(f'/api/user/{user_id}/usage-stats', headers=headers)
    assert response.status_code == 401
    data = response.get_json()
    assert data['error'] == 'User not found'

def test_cancel_subscription_success(client, setup_data):
    with client.application.app_context():
        user_id = _create_user()

    headers = _auth_headers(client.application, user_id)
    response = client.post(f'/api/user/{user_id}/cancel-subscription', headers=headers)
    assert response.status_code == 200
    data = response.get_json()

    assert data['success'] is True
    assert 'Subscription will be canceled' in data['message']
    assert data['cancel_at_period_end'] is True

    # Verify in DB
    with client.application.app_context():
        user = db.session.get(User, user_id)
        assert user.cancel_at_period_end is True
