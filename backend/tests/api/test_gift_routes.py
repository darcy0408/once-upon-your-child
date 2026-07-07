"""Route-level tests for gift-subscription redemption (POST /api/gift/redeem).

Covers the redemption-endpoint contract: happy path, unknown code, double
redeem, and the "don't leak which codes exist" error shape.
"""

import uuid
from datetime import UTC, datetime, timedelta

import jwt

from backend.database import db
from backend.models.gift_code import GiftCode, generate_code, hash_code, normalize_code
from backend.models.user import User


def _auth_headers(user_id):
    token = jwt.encode(
        {
            "user_id": user_id,
            "sub": user_id,
            "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
        },
        "dev-secret-key",
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def _create_user(app, **overrides):
    with app.app_context():
        user = User(
            id=overrides.pop("id", str(uuid.uuid4())),
            username=overrides.pop("username", f"user_{uuid.uuid4().hex[:8]}"),
            email=overrides.pop("email", f"{uuid.uuid4().hex[:8]}@example.com"),
            password_hash=overrides.pop("password_hash", "hashed"),
            subscription_tier=overrides.pop("subscription_tier", "free"),
            role=overrides.pop("role", "user"),
        )
        db.session.add(user)
        db.session.commit()
        return user.id


def _seed_gift_code(app, plaintext_code=None, **overrides):
    plaintext_code = plaintext_code or generate_code()
    with app.app_context():
        gift = GiftCode(
            code_hash=hash_code(normalize_code(plaintext_code)),
            tier=overrides.pop("tier", "premium"),
            duration_days=overrides.pop("duration_days", 365),
            purchaser_email=overrides.pop("purchaser_email", "buyer@example.com"),
            stripe_session_id=overrides.pop("stripe_session_id", None),
            status=overrides.pop("status", "created"),
        )
        db.session.add(gift)
        db.session.commit()
        return gift.id, plaintext_code


def test_redeem_requires_auth(client):
    resp = client.post("/api/gift/redeem", json={"code": "ABCD-1234-WXYZ"})
    assert resp.status_code == 401


def test_redeem_unknown_code_returns_404(client, app):
    uid = _create_user(app)
    resp = client.post(
        "/api/gift/redeem",
        json={"code": "0000-0000-0000"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 404
    body = resp.get_json()
    assert body["code"] == "gift_code_not_found"


def test_redeem_malformed_code_returns_404(client, app):
    """A code with characters outside the Crockford alphabet (e.g. 'U') must
    fail the same way an unknown-but-well-formed code does — no format hint
    leak."""
    uid = _create_user(app)
    resp = client.post(
        "/api/gift/redeem",
        json={"code": "UUUUUUUUUUUU"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 404
    assert resp.get_json()["code"] == "gift_code_not_found"


def test_redeem_missing_code_returns_404(client, app):
    uid = _create_user(app)
    resp = client.post("/api/gift/redeem", json={}, headers=_auth_headers(uid))
    assert resp.status_code == 404


def test_redeem_happy_path_applies_entitlement(client, app):
    uid = _create_user(app, subscription_tier="free")
    gift_id, plaintext = _seed_gift_code(app, tier="premium", duration_days=365)

    # Submit lowercase with dashes/spaces to exercise input normalization.
    submitted = plaintext.lower()
    submitted = "-".join([submitted[0:4], submitted[4:8], submitted[8:12]]) + "  "

    before = datetime.now(UTC)
    resp = client.post(
        "/api/gift/redeem",
        json={"code": submitted},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["success"] is True
    assert body["tier"] == "premium"
    assert body["subscription_status"] == "active"
    assert body["current_period_end"] is not None

    with app.app_context():
        user = db.session.get(User, uid)
        assert user.subscription_tier == "premium"
        assert user.subscription_status == "active"
        assert user.current_period_end is not None
        # current_period_end is stored as naive UTC (apply_entitlement's
        # convention) — compare against a naive expectation.
        expected_end = (before + timedelta(days=365)).replace(tzinfo=None)
        # Allow slack for test execution time.
        assert abs((user.current_period_end - expected_end).total_seconds()) < 60

        gift = db.session.get(GiftCode, gift_id)
        assert gift.status == "redeemed"
        assert gift.redeemed_by_user_id == uid
        assert gift.redeemed_at is not None


def test_redeem_double_redeem_returns_409(client, app):
    uid_1 = _create_user(app)
    uid_2 = _create_user(app)
    _gift_id, plaintext = _seed_gift_code(app)

    first = client.post(
        "/api/gift/redeem",
        json={"code": plaintext},
        headers=_auth_headers(uid_1),
    )
    assert first.status_code == 200

    second = client.post(
        "/api/gift/redeem",
        json={"code": plaintext},
        headers=_auth_headers(uid_2),
    )
    assert second.status_code == 409
    assert second.get_json()["code"] == "gift_code_redeemed"

    with app.app_context():
        # The second (rejected) redeemer must not have been granted anything.
        user_2 = db.session.get(User, uid_2)
        assert user_2.subscription_tier == "free"


def test_redeem_revoked_code_returns_404(client, app):
    uid = _create_user(app)
    _gift_id, plaintext = _seed_gift_code(app, status="revoked")

    resp = client.post(
        "/api/gift/redeem",
        json={"code": plaintext},
        headers=_auth_headers(uid),
    )
    # Revoked codes must not be redeemable, and must not leak that they exist
    # in a special (non-"unknown") state.
    assert resp.status_code == 404
    assert resp.get_json()["code"] == "gift_code_not_found"
