import uuid

from backend.database import db
from backend.models.character import Character
from backend.models.user import User


def _create_user(user_id: str) -> User:
    user = User(id=user_id, username=f"user_{user_id}", email=f"{user_id}@example.com")
    user.set_password("test-password")
    db.session.add(user)
    db.session.commit()
    return user


def test_create_character_requires_auth(client):
    response = client.post("/create-character", json={"name": "Luna", "age": 7})

    assert response.status_code == 401
    assert response.get_json()["error"] == "Authentication required"


def test_create_character_success_contract(client, auth_headers, test_user):
    payload = {
        "name": "Sparky",
        "age": 5,
        "traits": ["brave", "funny"],
        "personality_sliders": {"adventure": 110, "unknown": 22},
        "pets": [{"name": "Milo", "type": "cat", "age": 3}, "ignored"],
        "generatedAvatar": {"seed": "alpha"},
    }

    response = client.post("/create-character", json=payload, headers=auth_headers)

    assert response.status_code == 201
    data = response.get_json()
    assert data["name"] == "Sparky"
    assert data["age"] == 5
    assert data["personality_traits"] == ["brave", "funny"]
    assert data["personality_sliders"] == {"adventure": 100}
    assert data["pets"] == [{"name": "Milo", "type": "cat", "age": 3}]
    assert data["generated_avatar"] == {"seed": "alpha"}
    assert "id" in data

    with client.application.app_context():
        saved = db.session.get(Character, data["id"])
        assert saved is not None
        assert saved.user_id == test_user.id


def test_create_character_ignores_payload_user_id(client, auth_headers, test_user):
    response = client.post(
        "/create-character",
        json={"name": "Nora", "age": 6, "user_id": "malicious-user-id"},
        headers=auth_headers,
    )

    assert response.status_code == 201
    created = response.get_json()
    with client.application.app_context():
        saved = db.session.get(Character, created["id"])
        assert saved.user_id == test_user.id


def test_create_character_missing_name_returns_400(client, auth_headers, test_user):
    response = client.post("/create-character", json={"age": 7}, headers=auth_headers)

    assert response.status_code == 400
    assert "name" in response.get_json()["error"]


def test_create_character_missing_age_returns_400(client, auth_headers, test_user):
    response = client.post("/create-character", json={"name": "NoAge"}, headers=auth_headers)

    assert response.status_code == 400
    assert "age" in response.get_json()["error"]


def test_create_character_invalid_age_returns_400(client, auth_headers, test_user):
    response = client.post("/create-character", json={"name": "Luna", "age": 200}, headers=auth_headers)

    assert response.status_code == 400
    assert response.get_json()["error"] == "Age must be between 0 and 120."


def test_get_characters_returns_only_current_user_records(client, auth_headers, test_user, app):
    with app.app_context():
        other_user = _create_user("other-user")
        db.session.add_all(
            [
                Character(id=str(uuid.uuid4()), user_id=test_user.id, name="Mine 1", age=8),
                Character(id=str(uuid.uuid4()), user_id=test_user.id, name="Mine 2", age=9),
                Character(id=str(uuid.uuid4()), user_id=other_user.id, name="Not Mine", age=10),
            ]
        )
        db.session.commit()

    response = client.get("/get-characters", headers=auth_headers)

    assert response.status_code == 200
    names = {item["name"] for item in response.get_json()}
    assert "Mine 1" in names
    assert "Mine 2" in names
    assert "Not Mine" not in names


def test_get_characters_requires_auth(client):
    response = client.get("/get-characters")

    assert response.status_code == 401
    assert response.get_json()["error"] == "Authentication required"


def test_get_character_by_id_success(client, auth_headers, test_user, app):
    with app.app_context():
        character = Character(id="char-get-1", user_id=test_user.id, name="Scout", age=8)
        db.session.add(character)
        db.session.commit()

    response = client.get("/characters/char-get-1", headers=auth_headers)

    assert response.status_code == 200
    body = response.get_json()
    assert body["id"] == "char-get-1"
    assert body["name"] == "Scout"


def test_get_character_not_found_returns_404(client, auth_headers, test_user):
    response = client.get("/characters/missing-character-id", headers=auth_headers)

    assert response.status_code == 404
    assert response.get_json()["error"] == "Character not found"


def test_get_character_requires_auth(client):
    response = client.get("/characters/missing-character-id")

    assert response.status_code == 401
    assert response.get_json()["error"] == "Authentication required"


def test_get_character_other_user_forbidden(client, auth_headers, test_user, app):
    with app.app_context():
        other_user = _create_user("other-user-2")
        db.session.add(Character(id="char-locked", user_id=other_user.id, name="Secret", age=7))
        db.session.commit()

    response = client.get("/characters/char-locked", headers=auth_headers)

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_update_character_success(client, auth_headers, test_user, app):
    with app.app_context():
        db.session.add(Character(id="char-update-1", user_id=test_user.id, name="Old", age=5))
        db.session.commit()

    response = client.patch(
        "/characters/char-update-1",
        json={"name": "New", "traits": ["smart"], "generatedAvatar": {"seed": "updated"}},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["name"] == "New"
    assert body["personality_traits"] == ["smart"]
    assert body["generated_avatar"] == {"seed": "updated"}
    assert body["age"] == 5


def test_update_character_put_success(client, auth_headers, test_user, app):
    with app.app_context():
        db.session.add(Character(id="char-update-put", user_id=test_user.id, name="Old", age=7))
        db.session.commit()

    response = client.put(
        "/characters/char-update-put",
        json={"name": "New Name"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["id"] == "char-update-put"
    assert body["name"] == "New Name"


def test_update_character_requires_auth(client, auth_headers, test_user, app):
    with app.app_context():
        db.session.add(Character(id="char-update-auth", user_id=test_user.id, name="Kid", age=5))
        db.session.commit()

    response = client.patch("/characters/char-update-auth", json={"name": "NoAuth"})

    assert response.status_code == 401
    assert response.get_json()["error"] == "Authentication required"


def test_update_character_invalid_age_returns_400(client, auth_headers, test_user, app):
    with app.app_context():
        db.session.add(Character(id="char-update-2", user_id=test_user.id, name="Kid", age=5))
        db.session.commit()

    response = client.patch("/characters/char-update-2", json={"age": -1}, headers=auth_headers)

    assert response.status_code == 400
    assert response.get_json()["error"] == "Age must be between 0 and 120."


def test_update_character_other_user_forbidden(client, auth_headers, test_user, app):
    with app.app_context():
        other_user = _create_user("other-user-3")
        db.session.add(Character(id="char-update-forbidden", user_id=other_user.id, name="Lock", age=8))
        db.session.commit()

    response = client.patch(
        "/characters/char-update-forbidden",
        json={"name": "Hack"},
        headers=auth_headers,
    )

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_update_character_not_found_returns_404(client, auth_headers, test_user):
    response = client.patch(
        "/characters/missing-update-id",
        json={"name": "Ignored"},
        headers=auth_headers,
    )

    assert response.status_code == 404
    assert response.get_json()["error"] == "Character not found"


def test_delete_character_success(client, auth_headers, test_user, app):
    with app.app_context():
        db.session.add(Character(id="char-delete-1", user_id=test_user.id, name="Gone", age=9))
        db.session.commit()

    response = client.delete("/characters/char-delete-1", headers=auth_headers)

    assert response.status_code == 200
    assert response.get_json() == {"status": "deleted", "id": "char-delete-1"}

    with app.app_context():
        assert db.session.get(Character, "char-delete-1") is None


def test_delete_character_requires_auth(client, auth_headers, test_user, app):
    with app.app_context():
        db.session.add(Character(id="char-delete-auth", user_id=test_user.id, name="Kid", age=7))
        db.session.commit()

    response = client.delete("/characters/char-delete-auth")

    assert response.status_code == 401
    assert response.get_json()["error"] == "Authentication required"


def test_delete_character_other_user_forbidden(client, auth_headers, test_user, app):
    with app.app_context():
        other_user = _create_user("other-user-4")
        db.session.add(Character(id="char-delete-forbidden", user_id=other_user.id, name="Safe", age=6))
        db.session.commit()

    response = client.delete("/characters/char-delete-forbidden", headers=auth_headers)

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_delete_character_not_found_returns_404(client, auth_headers, test_user):
    response = client.delete("/characters/missing-delete-id", headers=auth_headers)

    assert response.status_code == 404
    assert response.get_json()["error"] == "Character not found"
