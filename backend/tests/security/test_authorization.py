from datetime import datetime, timedelta

import jwt

from backend.database import db
from backend.models.character import Character
from backend.models.story import Story
from backend.models.user import User


def _auth_headers(user_id: str) -> dict[str, str]:
    token = jwt.encode(
        {
            "user_id": user_id,
            "exp": datetime.utcnow() + timedelta(hours=1),
        },
        "test_secret",
        algorithm="HS256",
    )
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def _create_user(user_id: str, username: str, email: str, tier: str = "free") -> User:
    user = User(
        id=user_id,
        username=username,
        email=email,
        password_hash="test_hash",
        subscription_tier=tier,
    )
    db.session.add(user)
    db.session.commit()
    return user


def _create_character(char_id: str, user_id: str, name: str = "Hero") -> Character:
    character = Character(
        id=char_id,
        user_id=user_id,
        name=name,
        age=8,
    )
    db.session.add(character)
    db.session.commit()
    return character


def _create_story(story_id: str, user_id: str, title: str = "Story") -> Story:
    story = Story(
        id=story_id,
        user_id=user_id,
        title=title,
    )
    db.session.add(story)
    db.session.commit()
    return story


def test_user_can_access_own_characters(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        owner = _create_user("owner_1", "owner1", "owner1@example.com")
        _create_character("owner_char_1", owner.id, "Owner Hero")
        _create_character("owner_char_2", owner.id, "Owner Hero 2")
        _create_user("other_1", "other1", "other1@example.com")
        _create_character("other_char_1", "other_1", "Other Hero")

    response = client.get("/get-characters", headers=_auth_headers("owner_1"))

    assert response.status_code == 200
    names = [item["name"] for item in response.get_json()]
    assert "Owner Hero" in names
    assert "Owner Hero 2" in names
    assert "Other Hero" not in names


def test_user_cannot_access_other_users_characters(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_2", "owner2", "owner2@example.com")
        _create_user("other_2", "other2", "other2@example.com")
        _create_character("other_char_2", "other_2", "Other Secret Hero")

    response = client.get("/characters/other_char_2", headers=_auth_headers("owner_2"))

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_user_can_access_own_stories(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        owner = _create_user("owner_3", "owner3", "owner3@example.com")
        _create_story("owner_story_1", owner.id, "Owner Story 1")
        _create_story("owner_story_2", owner.id, "Owner Story 2")
        _create_user("other_3", "other3", "other3@example.com")
        _create_story("other_story_1", "other_3", "Other Story 1")

    response = client.get(
        "/api/user/owner_3/usage-stats",
        headers=_auth_headers("owner_3"),
    )

    assert response.status_code == 200
    payload = response.get_json()
    assert payload["stories_this_month"] == 2


def test_user_cannot_access_other_users_stories(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_4", "owner4", "owner4@example.com")
        _create_user("other_4", "other4", "other4@example.com")
        _create_story("other_story_4", "other_4", "Other Story")

    response = client.get(
        "/api/user/other_4/usage-stats",
        headers=_auth_headers("owner_4"),
    )

    assert response.status_code == 403
    assert response.get_json()["error"] == "Access denied"


def test_character_update_by_wrong_user_returns_403(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_5", "owner5", "owner5@example.com")
        _create_user("other_5", "other5", "other5@example.com")
        _create_character("other_char_5", "other_5", "Other Hero")

    response = client.patch(
        "/characters/other_char_5",
        headers=_auth_headers("owner_5"),
        json={"name": "Hacked Name"},
    )

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_character_delete_by_wrong_user_returns_403(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_6", "owner6", "owner6@example.com")
        _create_user("other_6", "other6", "other6@example.com")
        _create_character("other_char_6", "other_6", "Other Hero")

    response = client.delete(
        "/characters/other_char_6",
        headers=_auth_headers("owner_6"),
    )

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_get_characters_id_requires_ownership(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_7", "owner7", "owner7@example.com")
        _create_user("other_7", "other7", "other7@example.com")
        _create_character("other_char_7", "other_7", "Other Hero")

    response = client.get("/characters/other_char_7", headers=_auth_headers("owner_7"))

    assert response.status_code == 403


def test_patch_characters_id_requires_ownership(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_8", "owner8", "owner8@example.com")
        _create_user("other_8", "other8", "other8@example.com")
        _create_character("other_char_8", "other_8", "Other Hero")

    response = client.patch(
        "/characters/other_char_8",
        headers=_auth_headers("owner_8"),
        json={"role": "Wizard"},
    )

    assert response.status_code == 403


def test_delete_characters_id_requires_ownership(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_9", "owner9", "owner9@example.com")
        _create_user("other_9", "other9", "other9@example.com")
        _create_character("other_char_9", "other_9", "Other Hero")

    response = client.delete(
        "/characters/other_char_9",
        headers=_auth_headers("owner_9"),
    )

    assert response.status_code == 403


def test_owner_can_update_and_delete_own_character(client, app, monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test_secret")
    with app.app_context():
        _create_user("owner_10", "owner10", "owner10@example.com")
        _create_character("owner_char_10", "owner_10", "Original Name")

    update_response = client.patch(
        "/characters/owner_char_10",
        headers=_auth_headers("owner_10"),
        json={"name": "Updated Name"},
    )
    delete_response = client.delete(
        "/characters/owner_char_10",
        headers=_auth_headers("owner_10"),
    )

    assert update_response.status_code == 200
    assert update_response.get_json()["name"] == "Updated Name"
    assert delete_response.status_code == 200
