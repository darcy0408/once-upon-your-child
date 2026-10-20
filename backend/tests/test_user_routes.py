import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from backend.database import db
from backend.models.character import Character
from backend.models.story import Story
from backend.models.user import User


@pytest.fixture(scope="function")
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
            "type": "access",
            "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
        },
        secret,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def _create_user(**overrides):
    payload = {
        "id": overrides.pop("id", str(uuid.uuid4())),
        "username": overrides.pop("username", f"user_{uuid.uuid4().hex[:8]}"),
        "email": overrides.pop("email", f"{uuid.uuid4().hex[:8]}@example.com"),
        "password_hash": "hashed",
        "subscription_tier": overrides.pop("subscription_tier", "premium"),
        "subscription_status": overrides.pop("subscription_status", "active"),
        "current_period_end": overrides.pop(
            "current_period_end",
            datetime.now(UTC) + timedelta(days=30),
        ),
        "cancel_at_period_end": overrides.pop("cancel_at_period_end", False),
    }
    payload.update(overrides)
    user = User(**payload)
    db.session.add(user)
    db.session.commit()
    return user.id


def _create_story(user_id, created_at=None):
    if created_at is None:
        created_at = datetime.now(UTC)
    story = Story(user_id=user_id, title="Test Story", created_at=created_at)
    db.session.add(story)
    db.session.commit()
    return story.id


def _create_character(user_id):
    character = Character(
        id=str(uuid.uuid4()),
        user_id=user_id,
        name="Test Character",
        age=7,
        gender="male",
        role="hero",
    )
    db.session.add(character)
    db.session.commit()
    return character.id


def _next_month_start():
    now = datetime.now(UTC)
    return (now.replace(day=1) + timedelta(days=32)).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0, tzinfo=None
    )


def test_get_usage_stats_success(client, setup_data):
    with client.application.app_context():
        # 45 generations this month, per the counter ai_quota enforces.
        user_id = _create_user(
            subscription_tier="premium",
            stories_generated_this_month=45,
            usage_reset_date=_next_month_start(),
        )
        # Create 3 characters
        for _ in range(3):
            _create_character(user_id)

    headers = _auth_headers(client.application, user_id)
    response = client.get(f"/api/user/{user_id}/usage-stats", headers=headers)
    assert response.status_code == 200
    data = response.get_json()

    assert data["stories_this_month"] == 45
    assert data["stories_limit"] == 150
    assert data["characters_count"] == 3
    assert data["characters_limit"] == 6
    assert "period_start" in data
    assert "period_end" in data


def test_usage_stats_counts_generations_not_saved_rows(client, setup_data):
    """MT-474: the read-out is the enforced counter, not a count of Story rows.

    A story that was generated but never saved still spent quota; a saved
    row that was imported or restored did not. Only the counter is truthful.
    """
    with client.application.app_context():
        user_id = _create_user(
            subscription_tier="free",
            stories_generated_this_month=2,
            usage_reset_date=_next_month_start(),
        )
        for _ in range(4):
            _create_story(user_id)

    headers = _auth_headers(client.application, user_id)
    response = client.get(f"/api/user/{user_id}/usage-stats", headers=headers)
    assert response.status_code == 200
    assert response.get_json()["stories_this_month"] == 2


def test_usage_stats_period_is_the_calendar_month(client, setup_data):
    """The window shown is the one the counter rolls over on, not the Stripe period."""
    with client.application.app_context():
        user_id = _create_user(
            subscription_tier="premium",
            current_period_end=datetime.now(UTC) + timedelta(days=17),
        )

    headers = _auth_headers(client.application, user_id)
    data = client.get(f"/api/user/{user_id}/usage-stats", headers=headers).get_json()
    now = datetime.now(UTC)
    assert data["period_start"] == now.strftime("%Y-%m-01T00:00:00Z")
    assert data["period_end"] == _next_month_start().strftime("%Y-%m-%dT00:00:00Z")


@pytest.mark.parametrize(
    "tier,expected_limit",
    [("free", 1), ("premium", 6), ("family", 20)],
)
def test_usage_stats_character_limit_matches_enforced_cap(
    client, setup_data, tier, expected_limit
):
    """MT-474: one table for the cap — the read-out and /create-character agree."""
    with client.application.app_context():
        user_id = _create_user(subscription_tier=tier)

    headers = _auth_headers(client.application, user_id)
    response = client.get(f"/api/user/{user_id}/usage-stats", headers=headers)
    assert response.status_code == 200
    assert response.get_json()["characters_limit"] == expected_limit


@pytest.mark.parametrize(
    "tier,expected_limit",
    [("free", 5), ("premium", 150), ("family", 0)],
)
def test_usage_stats_story_limit_matches_enforced_quota(
    client, setup_data, tier, expected_limit
):
    """The reported cap is the one ai_quota enforces; 0 means unlimited."""
    with client.application.app_context():
        user_id = _create_user(subscription_tier=tier)

    headers = _auth_headers(client.application, user_id)
    response = client.get(f"/api/user/{user_id}/usage-stats", headers=headers)
    assert response.status_code == 200
    assert response.get_json()["stories_limit"] == expected_limit


def test_get_usage_stats_user_not_found(client, setup_data):
    user_id = "some-random-id"
    headers = _auth_headers(client.application, user_id)
    response = client.get(f"/api/user/{user_id}/usage-stats", headers=headers)
    assert response.status_code == 401
    data = response.get_json()
    assert data["error"] == "User not found"
