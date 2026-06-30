"""Security tests for the Pass-2 authz / generator hardening (audit PR 6).

Covers:
  * IAP upsert refuses to reassign a store_transaction_id to a different user
    (P2#16 — cross-user subscription takeover).
  * /select-avatar rejects a non-numeric id before building a filesystem path
    (P2#15 — path-traversal on the URL param).
  * The OpenRouter generator sends a child-safety system prompt (P2#23).
"""

import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from backend.database import db
from backend.models.iap_event import IapPurchase
from backend.models.user import User
from backend.routes.iap_routes import _upsert_iap_purchase


def _make_user(tier="free"):
    user = User(
        id=str(uuid.uuid4()),
        username=f"user_{uuid.uuid4().hex[:8]}",
        email=f"{uuid.uuid4().hex[:8]}@example.com",
        password_hash="hashed",
        subscription_tier=tier,
        role="user",
    )
    db.session.add(user)
    db.session.commit()
    return user.id


def test_iap_upsert_refuses_cross_user_reassignment(app):
    """A second user presenting the same receipt must not steal the row."""
    txn = f"txn_{uuid.uuid4().hex}"
    t0 = datetime.now(UTC)
    with app.app_context():
        owner = _make_user()
        attacker = _make_user()

        _upsert_iap_purchase(
            user_id=owner,
            store="apple",
            product_id="premium_monthly",
            tier="premium",
            store_transaction_id=txn,
            status="active",
            expires_at=t0 + timedelta(days=30),
            event_time=t0,
        )
        db.session.commit()

        # Same txn, different user, later event_time (so the ordering guard
        # does NOT short-circuit — we want to reach the user_id assignment).
        _upsert_iap_purchase(
            user_id=attacker,
            store="apple",
            product_id="premium_monthly",
            tier="premium",
            store_transaction_id=txn,
            status="active",
            expires_at=t0 + timedelta(days=30),
            event_time=t0 + timedelta(minutes=5),
        )
        db.session.commit()

        rows = IapPurchase.query.filter_by(store_transaction_id=txn).all()
        assert len(rows) == 1
        assert str(rows[0].user_id) == str(owner), "txn was reassigned to attacker"


def test_select_avatar_rejects_non_numeric_id(client, auth_headers):
    """A crafted (non-numeric) avatar id is rejected with 400, not used to
    build a filesystem path."""
    resp = client.post("/avatar/gallery/select-avatar/abc", headers=auth_headers)
    assert resp.status_code == 400

    resp2 = client.post("/avatar/gallery/select-avatar/1.1.1", headers=auth_headers)
    assert resp2.status_code == 400


def test_openrouter_generator_sends_system_prompt(monkeypatch):
    """The OpenRouter chat request must include a child-safety system message."""
    import backend.services.openrouter_story_generator as orsg

    captured = {}

    def _fake_post(url, **kwargs):
        captured["json"] = kwargs.get("json")
        resp = MagicMock()
        resp.status_code = 200
        resp.raise_for_status.return_value = None
        resp.json.return_value = {
            "choices": [
                {"finish_reason": "stop", "message": {"content": "Once upon a time."}}
            ]
        }
        return resp

    monkeypatch.setattr(orsg.requests, "post", _fake_post)

    gen = orsg.OpenRouterStoryGenerator(api_key="test-key")
    out = gen.generate_story("Write a story about a brave fox.")

    assert out == "Once upon a time."
    messages = captured["json"]["messages"]
    assert messages[0]["role"] == "system"
    assert "children" in messages[0]["content"].lower()
    assert messages[1]["role"] == "user"
