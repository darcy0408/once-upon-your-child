import pytest
import json
from backend.models.user import User
from backend.models.character import Character
from backend.database import db

# Note: We rely on 'app' fixture from conftest.py which provides active app_context.


@pytest.fixture
def admin_user(app):
    # No extra app_context logic needed if conftest provides it
    user = db.session.get(User, "admin_test")
    if not user:
        user = User(
            id="admin_test", username="admin_test", email="admin@test.com", role="admin"
        )
        user.set_password("password")
        db.session.add(user)
        db.session.commit()
    yield user
    # Cleanup
    # db.session.delete(user) # In session scope, cleanup might be handled by db.drop_all or careful deletes
    # For now explicit delete is safe usually
    db.session.delete(user)
    db.session.commit()


@pytest.fixture
def regular_user(app):
    user = db.session.get(User, "user_test")
    if not user:
        user = User(
            id="user_test", username="user_test", email="user@test.com", role="user"
        )
        user.set_password("password")
        db.session.add(user)
        db.session.commit()
    yield user
    db.session.delete(user)
    db.session.commit()


@pytest.fixture
def user_character(app, regular_user):
    char = Character(id="char_test", name="Test Char", age=10, user_id=regular_user.id)
    db.session.add(char)
    db.session.commit()
    yield char
    c = db.session.get(Character, "char_test")
    if c:
        db.session.delete(c)
        db.session.commit()


@pytest.fixture
def auth_headers(app, regular_user):
    from flask_jwt_extended import create_access_token

    token = create_access_token(identity=regular_user.id)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin_auth_headers(app, admin_user):
    from flask_jwt_extended import create_access_token

    token = create_access_token(identity=admin_user.id)
    return {"Authorization": f"Bearer {token}"}


def test_admin_route_access_denied_no_auth(client):
    """Test admin route without auth."""
    # Use the client directly
    response = client.get("/admin/analytics/overview")
    assert response.status_code == 401


def test_admin_route_access_denied_regular_user(client, auth_headers):
    """Test admin route with regular user auth."""
    response = client.get("/admin/analytics/overview", headers=auth_headers)
    assert response.status_code == 403


def test_admin_route_access_granted_admin(client, admin_auth_headers):
    """Test admin route with admin user auth."""
    response = client.get("/admin/analytics/overview", headers=admin_auth_headers)
    assert response.status_code == 200
    data = json.loads(response.data)
    # The analytics route returns various keys
    assert "total_users" in data or "today" in data or "users" in data


def test_input_validation_age(app, client):
    """Priority 2: Verify Age Input Validation."""
    with app.app_context():
        # Direct service call to verify logic
        from backend.services import character_service

        # Invalid Age
        payload = {"name": "Old Man", "age": 150, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 400
        assert "Age must be" in resp.get("error", "")


def test_input_validation_sanitization(app, client):
    """Priority 2: Verify Text Sanitization."""
    with app.app_context():
        from backend.services import character_service

        # HTML Name
        payload = {"name": "<b>Bold</b>", "age": 10, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 201
        assert resp.get("name") == "Bold"


def test_endor_protection_user_stats(client, regular_user, auth_headers):
    """Test user cannot access another user's stats."""
    other_id = "other_user_id"
    response = client.get(f"/api/user/{other_id}/usage-stats", headers=auth_headers)
    assert response.status_code == 403


def test_idor_protection_delete_other_character(client, app, user_character):
    """Test attacker cannot delete valid user's character."""
    # Create attacker
    attacker = db.session.get(User, "attacker")
    if not attacker:
        attacker = User(
            id="attacker", username="att", email="att@test.com", role="user"
        )
        attacker.set_password("password")
        db.session.add(attacker)
        db.session.commit()

    from flask_jwt_extended import create_access_token

    token = create_access_token(identity=attacker.id)
    attacker_headers = {"Authorization": f"Bearer {token}"}

    try:
        # Corrected URL path
        response = client.delete(
            f"/characters/{user_character.id}", headers=attacker_headers
        )
        assert response.status_code == 403

    finally:
        u = db.session.get(User, "attacker")
        if u:
            db.session.delete(u)
            db.session.commit()


# --- Validator Edge Case Tests ---


def test_validator_negative_age(app):
    """Test that negative age is rejected."""
    with app.app_context():
        from backend.services import character_service

        payload = {"name": "Test Child", "age": -5, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 400
        assert "Age must be between" in resp.get("error", "")


def test_validator_age_over_limit(app):
    """Test that age over 120 is rejected."""
    with app.app_context():
        from backend.services import character_service

        payload = {"name": "Ancient One", "age": 999, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 400
        assert "Age must be between" in resp.get("error", "")


def test_validator_non_integer_age(app):
    """Test that non-integer age is rejected."""
    with app.app_context():
        from backend.services import character_service

        payload = {"name": "Test Child", "age": "not a number", "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 400
        assert "Age must be" in resp.get("error", "")


def test_validator_null_required_field(app):
    """Test that null name is rejected."""
    with app.app_context():
        from backend.services import character_service

        payload = {"name": None, "age": 10, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 400
        assert "Missing required field" in resp.get("error", "")


def test_validator_missing_required_field(app):
    """Test that missing required fields are caught."""
    with app.app_context():
        from backend.services import character_service

        # Missing both name and age
        payload = {"user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 400
        assert "name" in resp.get("error", "").lower()


def test_validator_script_injection_sanitized(app):
    """Test that script tags are sanitized from text input."""
    with app.app_context():
        from backend.services import character_service

        payload = {
            "name": "<script>alert('xss')</script>Evil",
            "age": 10,
            "user_id": "test_user",
        }
        resp, status = character_service.create_character(payload)
        assert status == 201
        # Script tag should be removed, only 'Evil' remains
        assert "script" not in resp.get("name", "").lower()
        assert "Evil" in resp.get("name", "")


def test_validator_html_tags_stripped(app):
    """Test that HTML tags are stripped from text input."""
    with app.app_context():
        from backend.services import character_service

        payload = {
            "name": "<div><span>Clean Name</span></div>",
            "age": 10,
            "user_id": "test_user",
        }
        resp, status = character_service.create_character(payload)
        assert status == 201
        assert resp.get("name") == "Clean Name"


def test_validator_text_length_enforced(app):
    """Test that text exceeding max length is truncated."""
    with app.app_context():
        from backend.utils.validators import sanitize_text

        long_text = "A" * 200
        sanitized = sanitize_text(long_text, max_length=100)
        assert len(sanitized) == 100


def test_validator_age_boundary_values(app):
    """Test boundary values for age (0 and 120 should be valid)."""
    with app.app_context():
        from backend.services import character_service

        # Age 0 should be valid (newborns)
        payload = {"name": "Baby", "age": 0, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 201

        # Age 120 should be valid (maximum allowed)
        payload = {"name": "Elder", "age": 120, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        assert status == 201


def test_validator_age_zero_valid(app):
    """Test that age=0 is now valid (newborns are valid characters)."""
    with app.app_context():
        from backend.services import character_service

        payload = {"name": "Newborn", "age": 0, "user_id": "test_user"}
        resp, status = character_service.create_character(payload)
        # Fixed: age=0 is now accepted (not treated as falsy/missing)
        assert status == 201
        assert resp.get("age") == 0
