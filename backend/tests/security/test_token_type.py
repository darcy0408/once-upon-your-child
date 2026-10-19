"""MT-454 / MT-456: every auth path applies the same token checks.

A bearer token must be an *access* token, must not be on the revocation
blocklist, and its `tv` claim must match the user's stored token_version.
That holds for require_auth, optional_auth, get_current_user_id, the
achievement routes and /auth/refresh alike.
"""

from datetime import datetime, timedelta, timezone

import jwt
import pytest
from flask import jsonify, request
from flask_jwt_extended import create_access_token, create_refresh_token

from backend.database import db
from backend.middleware import auth as auth_module
from backend.middleware.auth import get_current_user_id, optional_auth

PROTECTED_ROUTE = "/users/test_user_123/feature-unlocks"


@pytest.fixture(autouse=True)
def no_redis(monkeypatch):
    """Keep the blocklist lookup off the network unless a test opts in."""
    monkeypatch.delenv("REDIS_URL", raising=False)
    monkeypatch.delenv("REDIS_PRIVATE_URL", raising=False)
    monkeypatch.setattr(auth_module, "_blocklist_redis", None)
    monkeypatch.setattr(auth_module, "_blocklist_redis_url", None)


def _bearer(token):
    return {"Authorization": f"Bearer {token}"}


def _access(user, tv=0):
    return create_access_token(identity=user.id, additional_claims={"tv": tv})


def _refresh(user, tv=0):
    return create_refresh_token(identity=user.id, additional_claims={"tv": tv})


def _bump_token_version(user):
    user.token_version = (user.token_version or 0) + 1
    db.session.commit()


def _add_optional_route(app):
    @app.route("/test/optional-token-type")
    @optional_auth
    def optional_token_type():
        user = request.current_user
        return jsonify({"user_id": user.id if user else None})


# --- require_auth ---------------------------------------------------------


def test_require_auth_accepts_access_token(client, test_user):
    response = client.get(PROTECTED_ROUTE, headers=_bearer(_access(test_user)))
    assert response.status_code == 200


def test_require_auth_rejects_refresh_token(client, test_user):
    response = client.get(PROTECTED_ROUTE, headers=_bearer(_refresh(test_user)))
    assert response.status_code == 401
    assert response.json["error"] == "Invalid token"


def test_require_auth_rejects_token_without_type(client, test_user):
    payload = {
        "sub": test_user.id,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")

    response = client.get(PROTECTED_ROUTE, headers=_bearer(token))
    assert response.status_code == 401
    assert response.json["error"] == "Invalid token"


def test_require_auth_rejects_blocklisted_access_token(client, test_user, mocker):
    token = _access(test_user)
    jti = jwt.decode(token, "dev-secret-key", algorithms=["HS256"])["jti"]
    mocker.patch.object(
        auth_module, "is_jti_blocklisted", side_effect=lambda value: value == jti
    )

    response = client.get(PROTECTED_ROUTE, headers=_bearer(token))
    assert response.status_code == 401
    assert response.json["error"] == "Invalid token"

    # A different token for the same user is unaffected.
    response = client.get(PROTECTED_ROUTE, headers=_bearer(_access(test_user)))
    assert response.status_code == 200


def test_require_auth_rejects_bumped_token_version(client, test_user):
    token = _access(test_user)
    _bump_token_version(test_user)

    response = client.get(PROTECTED_ROUTE, headers=_bearer(token))
    assert response.status_code == 401
    assert response.json["error"] == "Token revoked"


# --- blocklist lookup -----------------------------------------------------


class _FakeRedis:
    def __init__(self, keys):
        self._keys = keys

    def exists(self, key):
        return 1 if key in self._keys else 0


def test_is_jti_blocklisted_reads_redis(monkeypatch, mocker):
    monkeypatch.setenv("REDIS_URL", "redis://blocklist.test:6379/0")
    from_url = mocker.patch(
        "redis.from_url", return_value=_FakeRedis({"jwt:blocklist:spent"})
    )

    assert auth_module.is_jti_blocklisted("spent") is True
    assert auth_module.is_jti_blocklisted("live") is False
    assert auth_module.is_jti_blocklisted(None) is False
    # One client for the process, not one per request.
    assert from_url.call_count == 1


def test_is_jti_blocklisted_fails_open_when_redis_down(monkeypatch, mocker):
    monkeypatch.setenv("REDIS_URL", "redis://blocklist.test:6379/0")
    mocker.patch("redis.from_url", side_effect=ConnectionError("down"))

    assert auth_module.is_jti_blocklisted("anything") is False


def test_is_jti_blocklisted_without_redis_configured():
    assert auth_module.is_jti_blocklisted("anything") is False


# --- optional_auth / get_current_user_id ----------------------------------


def test_optional_auth_identifies_access_token(app, client, test_user):
    _add_optional_route(app)
    response = client.get(
        "/test/optional-token-type", headers=_bearer(_access(test_user))
    )
    assert response.json["user_id"] == test_user.id


def test_optional_auth_ignores_refresh_token(app, client, test_user):
    _add_optional_route(app)
    response = client.get(
        "/test/optional-token-type", headers=_bearer(_refresh(test_user))
    )
    assert response.status_code == 200
    assert response.json["user_id"] is None


def test_optional_auth_ignores_bumped_token_version(app, client, test_user):
    _add_optional_route(app)
    token = _access(test_user)
    _bump_token_version(test_user)

    response = client.get("/test/optional-token-type", headers=_bearer(token))
    assert response.status_code == 200
    assert response.json["user_id"] is None


def test_get_current_user_id_applies_same_checks(app, test_user):
    access = _access(test_user)
    refresh = _refresh(test_user)

    with app.test_request_context(headers=_bearer(access)):
        assert get_current_user_id() == test_user.id
    with app.test_request_context(headers=_bearer(refresh)):
        assert get_current_user_id() is None

    _bump_token_version(test_user)
    with app.test_request_context(headers=_bearer(access)):
        assert get_current_user_id() is None


# --- achievement routes ---------------------------------------------------


def test_achievement_routes_accept_access_token(client, test_user):
    response = client.get("/achievement/data", headers=_bearer(_access(test_user)))
    assert response.status_code == 200


def test_achievement_routes_reject_refresh_token(client, test_user):
    response = client.get("/achievement/data", headers=_bearer(_refresh(test_user)))
    assert response.status_code == 401


def test_achievement_routes_reject_bumped_token_version(client, test_user):
    token = _access(test_user)
    _bump_token_version(test_user)

    for method, path in (("get", "/achievement/data"), ("post", "/achievement/sync")):
        response = getattr(client, method)(path, headers=_bearer(token), json={})
        assert response.status_code == 401, path
        assert response.json["error"] == "Token revoked"


# --- refresh tokens -------------------------------------------------------


def test_issued_refresh_tokens_carry_token_version(client):
    issued = client.post("/auth/anonymous", json={}).json
    claims = jwt.decode(issued["refresh_token"], "dev-secret-key", algorithms=["HS256"])
    assert claims["type"] == "refresh"
    assert claims["tv"] == 0

    rotated = client.post("/auth/refresh", headers=_bearer(issued["refresh_token"]))
    assert rotated.status_code == 200
    rotated_claims = jwt.decode(
        rotated.json["refresh_token"], "dev-secret-key", algorithms=["HS256"]
    )
    assert rotated_claims["tv"] == 0


def test_refresh_rejects_bumped_token_version(client, test_user):
    token = _refresh(test_user)
    _bump_token_version(test_user)

    response = client.post("/auth/refresh", headers=_bearer(token))
    assert response.status_code == 401
    assert response.json["error"] == "Token revoked"


def test_refresh_rejects_access_token(client, test_user):
    response = client.post("/auth/refresh", headers=_bearer(_access(test_user)))
    assert response.status_code in (401, 422)
