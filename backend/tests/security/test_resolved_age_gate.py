"""Tests for the ENFORCE_RESOLVED_AGE gate in require_parental_consent.

Audit findings #1/#2 (docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md): is_under_13
defaults False and is only set when the client declares an age, so an account
that never established an age reached gated endpoints as a de-facto 13+ user.
When ENFORCE_RESOLVED_AGE is enabled, the consent gate refuses any user whose
age the server has never resolved (declared_age is None).

The flag defaults OFF (no behavior change) until the client always syncs an age
server-side; these tests pin both states.
"""

from datetime import datetime, timedelta, timezone

import jwt
import pytest

from backend.database import db
from backend.models import User


def _headers_for(user_id: str) -> dict:
    payload = {
        "sub": user_id,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


@pytest.fixture
def teen_user(app):
    """A user who HAS resolved an age server-side (declared_age=15, 13+)."""
    with app.app_context():
        user = User(
            id="teen_user_15",
            username="teenuser",
            email="teen@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
            declared_age=15,
            is_under_13=False,
        )
        db.session.add(user)
        db.session.commit()
        yield user
        db.session.delete(user)
        db.session.commit()


def test_unresolved_age_blocked_when_flag_on(
    client, free_user, free_user_headers, monkeypatch
):
    """A user with declared_age=None is refused with AGE_REQUIRED when the
    flag is on (free_user has no declared age)."""
    monkeypatch.setenv("ENFORCE_RESOLVED_AGE", "true")
    resp = client.post(
        "/create-character", json={"name": "Luna", "age": 7}, headers=free_user_headers
    )
    assert resp.status_code == 403
    assert resp.get_json().get("code") == "AGE_REQUIRED"


def test_unresolved_age_allowed_when_flag_off(
    client, free_user, free_user_headers, monkeypatch
):
    """Default behavior (flag off): an unresolved-age user is NOT blocked by the
    age gate — preserves today's flow so adults aren't locked out pre-launch."""
    monkeypatch.delenv("ENFORCE_RESOLVED_AGE", raising=False)
    resp = client.post(
        "/create-character", json={"name": "Luna", "age": 7}, headers=free_user_headers
    )
    # May 200/201/400 depending on payload validation, but never the age block.
    assert not (
        resp.status_code == 403 and resp.get_json().get("code") == "AGE_REQUIRED"
    )


def test_resolved_teen_passes_age_gate_when_flag_on(client, teen_user, monkeypatch):
    """A 13+ user with a resolved declared_age passes the age gate even with the
    flag on (only unresolved age is blocked, not a known adult/teen)."""
    monkeypatch.setenv("ENFORCE_RESOLVED_AGE", "true")
    resp = client.post(
        "/create-character",
        json={"name": "Nova", "age": 15},
        headers=_headers_for(teen_user.id),
    )
    assert not (
        resp.status_code == 403 and resp.get_json().get("code") == "AGE_REQUIRED"
    )
