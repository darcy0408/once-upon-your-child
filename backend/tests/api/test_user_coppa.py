"""COPPA endpoint tests for user_routes.py — CQ-04.

user_routes.py was at 23% coverage; the existing test_user_routes.py only
exercised usage-stats and cancel-subscription. Every COPPA endpoint was
untested. These tests pin the compliance- and security-critical behaviour:

  * right-to-erasure delete (data purged + user anonymised);
  * ownership enforcement on the destructive delete (non-owner -> 403);
  * consent recording, including the fail-safe photo-avatar default (CMP-8) and
    the server forcing verified=False for client-asserted email methods (COPPA);
  * the email round-trip failing CLOSED when email is unconfigured;
  * the verification-code brute-force guards (no code -> 410, wrong -> 400,
    expired -> 410, attempt cap -> 429) and the success promotion path.
"""

import hashlib
import uuid
from datetime import UTC, datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models.character import Character
from backend.models.consent_record import ConsentRecord, ConsentVerificationCode
from backend.models.story import Story
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


def _create_user(app):
    with app.app_context():
        user = User(
            id=str(uuid.uuid4()),
            username=f"user_{uuid.uuid4().hex[:8]}",
            email=f"{uuid.uuid4().hex[:8]}@example.com",
            password_hash="hashed",
            subscription_tier="free",
            role="user",
        )
        db.session.add(user)
        db.session.commit()
        return user.id


def _seed_code(
    app, user_id, code, *, attempts=0, expires_in_minutes=15, consent_record_id=None
):
    with app.app_context():
        row = ConsentVerificationCode(
            user_id=user_id,
            consent_record_id=consent_record_id,
            code_hash=hashlib.sha256(code.encode("utf-8")).hexdigest(),
            expires_at=(
                datetime.now(timezone.utc) + timedelta(minutes=expires_in_minutes)
            ).replace(tzinfo=None),
            attempts=attempts,
        )
        db.session.add(row)
        db.session.commit()
        return row.id


# ---------------------------------------------------------------------------
# PATCH /age
# ---------------------------------------------------------------------------


def test_set_age_under_13_sets_flag(client, app):
    uid = _create_user(app)
    resp = client.patch(
        f"/api/user/{uid}/age", json={"age": 8}, headers=_auth_headers(uid)
    )
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["is_under_13"] is True
    assert body["declared_age"] == 8


def test_set_age_13_or_over_clears_flag(client, app):
    uid = _create_user(app)
    resp = client.patch(
        f"/api/user/{uid}/age", json={"age": 15}, headers=_auth_headers(uid)
    )
    assert resp.status_code == 200
    assert resp.get_json()["is_under_13"] is False


def test_set_age_invalid_returns_400(client, app):
    uid = _create_user(app)
    for bad in ({"age": 0}, {"age": 200}, {"age": "ten"}, {}):
        resp = client.patch(
            f"/api/user/{uid}/age", json=bad, headers=_auth_headers(uid)
        )
        assert resp.status_code == 400, bad


# ---------------------------------------------------------------------------
# POST /consent
# ---------------------------------------------------------------------------


def test_record_consent_success(client, app):
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent",
        json={"child_age": 7, "consent_method": "parent"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["success"] is True
    assert body["consent"]["consent_method"] == "parent"


def test_record_consent_missing_age_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent",
        json={"consent_method": "parent"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400


def test_record_consent_invalid_method_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent",
        json={"child_age": 7, "consent_method": "totally_made_up"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400


def test_record_consent_photo_avatar_defaults_false(client, app):
    # CMP-8: an omitted allow_photo_avatar must NOT record the child as opted
    # in to photo-based (biometric) avatars.
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent",
        json={"child_age": 6, "consent_method": "parent"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 201
    assert resp.get_json()["consent"]["allow_photo_avatar"] is False


def test_record_consent_email_method_forces_unverified(client, app):
    # COPPA: a client cannot self-assert email_verified. The server forces
    # verified=False; only the /consent/verify round trip can set it true.
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent",
        json={
            "child_age": 9,
            "consent_method": "email_verified",
            "verified": True,
        },
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 201
    assert resp.get_json()["consent"]["verified"] is False


# ---------------------------------------------------------------------------
# DELETE /data  (right to erasure) — the critical path
# ---------------------------------------------------------------------------


def test_delete_user_data_purges_and_anonymizes(client, app):
    uid = _create_user(app)
    with app.app_context():
        db.session.add(
            Character(
                id=str(uuid.uuid4()),
                user_id=uid,
                name="Hero",
                age=7,
                gender="male",
                role="hero",
            )
        )
        db.session.add(
            Story(
                user_id=uid,
                title="My Story",
                created_at=datetime.now(UTC).replace(tzinfo=None),
            )
        )
        db.session.add(ConsentRecord(user_id=uid, child_age=7, consent_method="parent"))
        db.session.commit()

    resp = client.delete(f"/api/user/{uid}/data", headers=_auth_headers(uid))
    assert resp.status_code == 200
    assert resp.get_json()["success"] is True

    with app.app_context():
        assert Character.query.filter_by(user_id=uid).count() == 0
        assert Story.query.filter_by(user_id=uid).count() == 0
        assert ConsentRecord.query.filter_by(user_id=uid).count() == 0
        user = db.session.get(User, uid)
        assert user is not None  # row retained but anonymised
        assert user.email.endswith("@deleted.local")
        assert user.password_hash == "DELETED"
        assert user.declared_age is None


def test_delete_user_data_rejects_non_owner(client, app):
    owner = _create_user(app)
    attacker = _create_user(app)
    # Attacker authenticates as themselves but targets the owner's data.
    resp = client.delete(f"/api/user/{owner}/data", headers=_auth_headers(attacker))
    assert resp.status_code == 403
    with app.app_context():
        # Owner's account untouched (not anonymised).
        owner_row = db.session.get(User, owner)
        assert owner_row is not None
        assert not owner_row.email.endswith("@deleted.local")


# ---------------------------------------------------------------------------
# GET /export  (right to access)
# ---------------------------------------------------------------------------


def test_export_user_data_returns_bundle(client, app):
    uid = _create_user(app)
    with app.app_context():
        db.session.add(
            Character(
                id=str(uuid.uuid4()),
                user_id=uid,
                name="Hero",
                age=7,
                gender="male",
                role="hero",
            )
        )
        db.session.commit()
    resp = client.get(f"/api/user/{uid}/export", headers=_auth_headers(uid))
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["user_id"] == uid
    assert "profile" in body
    assert "characters" in body
    assert "consent_records" in body
    assert "attachment" in resp.headers.get("Content-Disposition", "")


# ---------------------------------------------------------------------------
# POST /consent/request-verification  (email round trip — fail closed)
# ---------------------------------------------------------------------------


def test_request_verification_invalid_email_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent/request-verification",
        json={"child_age": 8, "parent_email": "not-an-email"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400


def test_request_verification_email_unconfigured_fails_closed_503(
    client, app, monkeypatch
):
    monkeypatch.setattr("backend.routes.user_routes.is_email_configured", lambda: False)
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent/request-verification",
        json={"child_age": 8, "parent_email": "parent@example.com"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 503
    assert resp.get_json()["code"] == "EMAIL_SERVICE_UNAVAILABLE"


# ---------------------------------------------------------------------------
# POST /consent/verify  (brute-force guards + success promotion)
# ---------------------------------------------------------------------------


def test_verify_consent_no_active_code_returns_410(client, app):
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent/verify",
        json={"code": "123456"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 410
    assert resp.get_json()["verified"] is False


def test_verify_consent_missing_code_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        f"/api/user/{uid}/consent/verify",
        json={},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400


def test_verify_consent_wrong_code_returns_400(client, app):
    uid = _create_user(app)
    _seed_code(app, uid, "111111")
    resp = client.post(
        f"/api/user/{uid}/consent/verify",
        json={"code": "999999"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400
    assert resp.get_json()["verified"] is False


def test_verify_consent_expired_code_returns_410(client, app):
    uid = _create_user(app)
    _seed_code(app, uid, "222222", expires_in_minutes=-1)
    resp = client.post(
        f"/api/user/{uid}/consent/verify",
        json={"code": "222222"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 410


def test_verify_consent_attempt_cap_returns_429(client, app):
    uid = _create_user(app)
    _seed_code(app, uid, "333333", attempts=5)  # CONSENT_CODE_MAX_ATTEMPTS
    resp = client.post(
        f"/api/user/{uid}/consent/verify",
        json={"code": "333333"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 429


def test_verify_consent_success_promotes_record(client, app):
    uid = _create_user(app)
    with app.app_context():
        pending = ConsentRecord(
            user_id=uid,
            child_age=9,
            consent_method="email_pending",
            verified=False,
        )
        db.session.add(pending)
        db.session.commit()
        pending_id = pending.id
    _seed_code(app, uid, "654321", consent_record_id=pending_id)

    resp = client.post(
        f"/api/user/{uid}/consent/verify",
        json={"code": "654321"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 200
    assert resp.get_json()["verified"] is True
    with app.app_context():
        rec = db.session.get(ConsentRecord, pending_id)
        assert rec.consent_method == "email_verified"
        assert rec.verified is True
