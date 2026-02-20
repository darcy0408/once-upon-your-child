import json
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from backend.database import db
from backend.models.user import User


def _create_user(app, user_id="test-user-1"):
    with app.app_context():
        user = db.session.get(User, user_id)
        if user:
            return user_id
        user = User(id=user_id, username=f"user_{user_id}", email=f"{user_id}@example.com", password_hash="hashed")
        user.set_password("test-password")
        db.session.add(user)
        db.session.commit()
        return user_id


def _auth_headers(app, user_id):
    secret = app.config.get("JWT_SECRET_KEY") or "dev-secret-key"
    token = jwt.encode(
        {
            "user_id": user_id,
            "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
        },
        secret,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


@pytest.mark.api_contract
def test_health_endpoint_schema(client):
    response = client.get("/health")
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload, dict)
    assert "status" in payload
    assert "timestamp" in payload
    assert "version" in payload
    assert "database" in payload
    assert "has_api_key" in payload
    assert "model" in payload
    assert "stripe_configured" in payload
    assert "stripe_premium_price" in payload
    assert "stripe_family_price" in payload
    assert "environment" in payload


@pytest.mark.api_contract
def test_health_database_endpoint_schema(client):
    response = client.get("/health/database")
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload, dict)
    assert "status" in payload


@pytest.mark.api_contract
def test_version_endpoint_schema(client):
    response = client.get("/version")
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload, dict)
    assert "version" in payload
    assert "gemini_model" in payload


@pytest.mark.api_contract
def test_health_detailed_endpoint_schema(client):
    # This endpoint can return 200 (healthy) or 503 (unhealthy) depending on environment.
    response = client.get("/health/detailed")
    assert response.status_code in (200, 503)
    payload = response.get_json()
    assert isinstance(payload, dict)
    assert "status" in payload
    assert "timestamp" in payload
    assert "checks" in payload
    assert isinstance(payload["checks"], dict)


@pytest.mark.api_contract
def test_get_story_themes_contract(client):
    response = client.get("/get-story-themes")
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload, list)
    assert len(payload) > 0


@pytest.mark.api_contract
def test_generate_story_requires_character(client):
    response = client.post("/generate-story", json={})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_generate_story_mock_contract(client):
    response = client.post(
        "/generate-story-mock",
        json={"character": "Luna", "theme": "Adventure", "include_illustrations": False},
    )
    assert response.status_code == 200
    payload = response.get_json()
    # Check for result wrapper
    if "result" in payload:
        story = payload["result"].get("story", {})
    else:
        story = payload.get("story", {})
    assert story.get("title") or payload.get("title")
    assert story.get("story_text") or payload.get("story_text")


@pytest.mark.api_contract
def test_generate_illustrations_mock_contract(client):
    response = client.post(
        "/generate-illustrations-mock",
        json={"scene_description": "A magical forest", "character_name": "Luna", "num_images": 1},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("count") == 1
    illustrations = payload.get("illustrations", [])
    assert len(illustrations) == 1
    assert illustrations[0].get("image_data")


@pytest.mark.api_contract
def test_generate_coloring_pages_mock_requires_scene(client):
    response = client.post("/generate-coloring-pages-mock", json={})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_generate_coloring_pages_mock_contract(client):
    response = client.post(
        "/generate-coloring-pages-mock",
        json={"scenes": [{"description": "A castle on a hill", "title": "Castle"}], "character_name": "Luna"},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("count", 0) > 0
    pages = payload.get("coloring_pages", [])
    assert len(pages) > 0
    assert pages[0].get("image_data")


@pytest.mark.api_contract
def test_generate_interactive_story_missing_user_id(client):
    response = client.post("/generate-interactive-story", json={})
    assert response.status_code == 401
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_continue_interactive_story_missing_fields(client):
    response = client.post("/continue-interactive-story", json={})
    assert response.status_code == 401
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_get_characters_requires_auth(client):
    response = client.get("/get-characters")
    assert response.status_code == 401
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_get_characters_with_auth(client):
    user_id = _create_user(client.application, user_id="auth-user-1")
    headers = _auth_headers(client.application, user_id)
    response = client.get("/get-characters", headers=headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload, list)


@pytest.mark.api_contract
def test_create_character_with_auth(client):
    user_id = _create_user(client.application, user_id="auth-user-2")
    headers = _auth_headers(client.application, user_id)
    response = client.post(
        "/create-character",
        headers=headers,
        json={"name": "Luna", "age": 7},
    )
    assert response.status_code == 201
    payload = response.get_json()
    assert payload.get("id")
    assert payload.get("name") == "Luna"


@pytest.mark.api_contract
def test_usage_stats_requires_owner(client):
    user_id = _create_user(client.application, user_id="auth-user-3")
    headers = _auth_headers(client.application, user_id)
    response = client.get(f"/api/user/{user_id}/usage-stats", headers=headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert "stories_this_month" in payload
    assert "characters_count" in payload
    assert "period_start" in payload
    assert "period_end" in payload


@pytest.mark.api_contract
def test_stripe_webhook_unconfigured(client):
    response = client.post("/api/webhooks/stripe", data=json.dumps({}), content_type="application/json")
    assert response.status_code == 500
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_get_character_detail_with_auth(client):
    user_id = _create_user(client.application, user_id="auth-user-detail")
    headers = _auth_headers(client.application, user_id)

    # Create a character first
    create_resp = client.post(
        "/create-character",
        headers=headers,
        json={"name": "Sol", "age": 5},
    )
    char_id = create_resp.get_json()["id"]

    # Get details
    response = client.get(f"/characters/{char_id}", headers=headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("id") == char_id
    assert payload.get("name") == "Sol"


@pytest.mark.api_contract
def test_update_character_with_auth(client):
    user_id = _create_user(client.application, user_id="auth-user-update")
    headers = _auth_headers(client.application, user_id)

    # Create a character first
    create_resp = client.post(
        "/create-character",
        headers=headers,
        json={"name": "Mars", "age": 10},
    )
    char_id = create_resp.get_json()["id"]

    # Update character
    response = client.patch(
        f"/characters/{char_id}",
        headers=headers,
        json={"name": "Mars Updated", "age": 11},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("name") == "Mars Updated"
    assert payload.get("age") == 11


@pytest.mark.api_contract
def test_delete_character_with_auth(client):
    user_id = _create_user(client.application, user_id="auth-user-delete")
    headers = _auth_headers(client.application, user_id)

    # Create a character first
    create_resp = client.post(
        "/create-character",
        headers=headers,
        json={"name": "Pluto", "age": 4},
    )
    char_id = create_resp.get_json()["id"]

    # Delete character
    response = client.delete(f"/characters/{char_id}", headers=headers)
    assert response.status_code == 200

    # Verify it's gone
    get_resp = client.get(f"/characters/{char_id}", headers=headers)
    assert get_resp.status_code == 404


@pytest.mark.api_contract
def test_create_checkout_session_contract(client, mock_stripe):
    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium", "user_id": "test-user-stripe"},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert "id" in payload
    assert "checkout_url" in payload


@pytest.mark.api_contract
def test_get_subscription_status_contract(client, mock_stripe):
    user_id = _create_user(client.application, user_id="test-user-stripe-status")
    headers = _auth_headers(client.application, user_id)

    response = client.get(f"/api/stripe/subscription-status/{user_id}", headers=headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert "status" in payload
    assert "tier" in payload


@pytest.mark.api_contract
def test_auth_anonymous_contract(client):
    response = client.post("/auth/anonymous", json={})
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload, dict)
    assert isinstance(payload.get("token"), str)
    assert isinstance(payload.get("refresh_token"), str)
    assert isinstance(payload.get("user_id"), str)
    assert payload.get("is_anonymous") is True


@pytest.mark.api_contract
def test_auth_anonymous_reuses_client_id(client):
    resp1 = client.post("/auth/anonymous", json={"client_id": "anon_contract_1"})
    resp2 = client.post("/auth/anonymous", json={"client_id": "anon_contract_1"})

    assert resp1.status_code == 200
    assert resp2.status_code == 200
    assert resp1.get_json()["user_id"] == "anon_contract_1"
    assert resp2.get_json()["user_id"] == "anon_contract_1"


@pytest.mark.api_contract
def test_auth_login_invalid_credentials(client):
    response = client.post("/auth/login", json={"username": "nope", "password": "wrong"})
    assert response.status_code == 401
    payload = response.get_json()
    assert payload.get("message")


@pytest.mark.api_contract
def test_auth_login_success_returns_token(client):
    user_id = _create_user(client.application, user_id="login-user-1")
    response = client.post(
        "/auth/login",
        json={"username": f"user_{user_id}", "password": "test-password"},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload.get("token"), str)
    assert isinstance(payload.get("refresh_token"), str)


@pytest.mark.api_contract
def test_auth_refresh_contract(client):
    auth_resp = client.post("/auth/anonymous", json={})
    assert auth_resp.status_code == 200
    auth_payload = auth_resp.get_json()
    refresh_token = auth_payload.get("refresh_token")
    user_id = auth_payload.get("user_id")
    assert isinstance(refresh_token, str)

    refresh_resp = client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )
    assert refresh_resp.status_code == 200
    refresh_payload = refresh_resp.get_json()
    assert isinstance(refresh_payload.get("token"), str)
    assert refresh_payload.get("user_id") == user_id


@pytest.mark.api_contract
def test_security_headers_present_on_json_response(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"
    assert "Content-Security-Policy" in response.headers


@pytest.mark.api_contract
def test_get_internal_subscription_contract(client):
    user_id = _create_user(client.application, user_id="sub-user-1")
    response = client.get(f"/api/user/{user_id}/subscription")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("user_id") == user_id
    assert "tier" in payload
    assert "status" in payload
    assert "current_period_end" in payload
    assert "cancel_at_period_end" in payload


@pytest.mark.api_contract
def test_get_internal_subscription_404_for_unknown_user(client):
    response = client.get("/api/user/does-not-exist/subscription")
    assert response.status_code == 404
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_cancel_subscription_contract_requires_owner(client):
    user_id = _create_user(client.application, user_id="cancel-user-1")
    headers = _auth_headers(client.application, user_id)
    response = client.post(f"/api/user/{user_id}/cancel-subscription", headers=headers)
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("success") is True
    assert payload.get("cancel_at_period_end") is True


@pytest.mark.api_contract
def test_cancel_subscription_contract_forbidden_for_other_user(client):
    owner_id = _create_user(client.application, user_id="cancel-user-owner")
    _create_user(client.application, user_id="cancel-user-other")
    headers = _auth_headers(client.application, owner_id)
    response = client.post("/api/user/cancel-user-other/cancel-subscription", headers=headers)
    assert response.status_code == 403
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_report_story_contract(client):
    response = client.post(
        "/report-story",
        json={"story_id": "story_1", "reason": "test", "story_preview": "preview"},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("status") == "reported"
    assert payload.get("message")


@pytest.mark.api_contract
def test_generate_illustrations_requires_scene_description(client):
    response = client.post("/generate-illustrations", json={})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_generate_illustrations_contract_returns_list_and_count(client):
    response = client.post(
        "/generate-illustrations",
        json={"scene_description": "A sunny field", "character_name": "Luna", "num_images": 1},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert "illustrations" in payload
    assert "count" in payload
    assert isinstance(payload["illustrations"], list)
    assert isinstance(payload["count"], int)


@pytest.mark.api_contract
def test_generate_coloring_pages_requires_scene_or_scenes(client):
    response = client.post("/generate-coloring-pages", json={})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_generate_coloring_pages_contract_returns_list_and_count(client):
    response = client.post(
        "/generate-coloring-pages",
        json={"scene_description": "A castle on a hill", "character_name": "Luna"},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert "coloring_pages" in payload
    assert "count" in payload
    assert isinstance(payload["coloring_pages"], list)
    assert isinstance(payload["count"], int)


@pytest.mark.api_contract
def test_feature_unlocks_contract(client):
    user_id = _create_user(client.application, user_id="unlock-user-1")
    response = client.get(f"/users/{user_id}/feature-unlocks")
    assert response.status_code == 200
    payload = response.get_json()
    assert "stories_created_count" in payload
    assert "character_creation_unlocked" in payload
    assert "interactive_stories_unlocked" in payload
    assert "coloring_pages_unlocked" in payload
    assert "advanced_settings_unlocked" in payload


@pytest.mark.api_contract
def test_feature_unlocks_404_for_unknown_user(client):
    response = client.get("/users/unknown-user/feature-unlocks")
    assert response.status_code == 404
    payload = response.get_json()
    assert payload.get("error")


@pytest.mark.api_contract
def test_record_story_created_contract(client):
    user_id = _create_user(client.application, user_id="story-created-user-1")
    response = client.post(f"/users/{user_id}/story-created")
    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload.get("stories_created_count"), int)
    assert payload.get("message")


@pytest.mark.api_contract
def test_usage_summary_contract(client):
    response = client.get("/usage/summary")
    assert response.status_code == 200
    payload = response.get_json()
    assert "period" in payload
    assert "totals" in payload


@pytest.mark.api_contract
def test_usage_daily_contract(client):
    response = client.get("/usage/daily")
    assert response.status_code == 200
    payload = response.get_json()
    assert "period_days" in payload
    assert "daily" in payload


@pytest.mark.api_contract
def test_avatar_health_contract(client):
    response = client.get("/avatar/health")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("status") in ("healthy", "unhealthy")


@pytest.mark.api_contract
def test_avatar_fallback_avatars_contract(client):
    response = client.get("/avatar/fallback-avatars")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("status") == "success"
    assert isinstance(payload.get("fallback_avatars"), list)


@pytest.mark.api_contract
def test_avatar_gallery_list_contract(client):
    response = client.get("/avatar/gallery/list-avatars")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("status") == "success"
    assert isinstance(payload.get("avatars"), list)
    assert isinstance(payload.get("count"), int)
    assert payload["count"] == len(payload["avatars"])
    if payload["avatars"]:
        assert payload["avatars"][0].get("id")
        assert payload["avatars"][0].get("url")


@pytest.mark.api_contract
def test_avatar_gallery_select_contract(client):
    list_resp = client.get("/avatar/gallery/list-avatars")
    assert list_resp.status_code == 200
    avatars = (list_resp.get_json() or {}).get("avatars", [])
    assert avatars, "avatar gallery should have at least 1 avatar in test environment"
    avatar_id = avatars[0]["id"]

    response = client.post(f"/avatar/gallery/select-avatar/{avatar_id}")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("status") == "success"
    avatar = payload.get("avatar") or {}
    assert avatar.get("source") == "gallery"
    assert avatar.get("gallery_id") == avatar_id
    assert avatar.get("image_url")


@pytest.mark.api_contract
def test_avatar_generate_mock_contract(client):
    response = client.post(
        "/avatar/generate-avatar-mock",
        json={"character_name": "Luna", "age": 7, "style": "pixar"},
    )
    assert response.status_code == 200
    payload = response.get_json()
    assert payload.get("status") == "success"
    avatar = payload.get("avatar") or {}
    assert avatar.get("id")
    assert avatar.get("image_base64")
    assert avatar.get("style") == "pixar"
    assert avatar.get("is_mock") is True


@pytest.mark.api_contract
def test_avatar_generate_requires_body(client):
    # Send an empty JSON body (Content-Type: application/json) to avoid 415 parsing errors.
    response = client.post("/avatar/generate-avatar", json={})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("status") == "error"
    assert payload.get("error_code") == "INVALID_REQUEST"


@pytest.mark.api_contract
def test_avatar_generate_validation_errors(client):
    response = client.post("/avatar/generate-avatar", json={"age": 7})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("status") == "error"
    assert payload.get("error_code") == "MISSING_CHARACTER_NAME"

    response = client.post("/avatar/generate-avatar", json={"character_name": "Luna", "age": "7"})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("status") == "error"
    assert payload.get("error_code") == "INVALID_AGE"

    response = client.post("/avatar/generate-avatar", json={"character_name": "Luna", "age": 7, "style": "nope"})
    assert response.status_code == 400
    payload = response.get_json()
    assert payload.get("status") == "error"
    assert payload.get("error_code") == "INVALID_STYLE"
    assert payload.get("valid_styles")
