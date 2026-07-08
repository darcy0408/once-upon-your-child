"""Tests for the free-tier one-fully-illustrated-story gate (2026-07-07
pricing decision).

The free tier gets exactly ONE fully-illustrated story (the "wow" story);
every illustration request for a DIFFERENT story after that is blocked with
an upgrade upsell. `User.free_illustrated_story_id` records which story
claimed the slot. See backend/routes/story_routes.py
`generate_illustrations_endpoint` (the gate) and `_resolve_story_identity`
(the story-id resolution, preferring an explicit `story_id`/`id` request
field and falling back to a hash of character-identity fields when absent).

Follows the `_create_user` + JWT pattern from test_analytics_events.py.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models import User
from backend.routes import story_routes


def _create_user(user_id: str, tier: str = "free", has_byok: bool = False) -> str:
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@example.com",
        password_hash="hash",
        subscription_tier=tier,
        role="user",
        has_byok=has_byok,
    )
    db.session.add(user)
    db.session.commit()

    payload = {
        "user_id": user_id,
        "sub": user_id,
        "email": f"{user_id}@example.com",
        "subscription_tier": tier,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")
    return token


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


_FAKE_IMAGE = [
    {
        "id": "test-img",
        "prompt": "a sunny meadow",
        "image_data": "ZmFrZWltYWdlZGF0YQ==",
        "format": "png",
        "generated_at": "2026-07-07T00:00:00",
    }
]


def _patch_flux(monkeypatch, mocker=None):
    """Deterministic, network-free illustration provider for these tests."""
    monkeypatch.setattr(
        story_routes, "_generate_flux_illustration", lambda **kwargs: list(_FAKE_IMAGE)
    )


def _illustration_payload(story_id: str, scene: str = "A sunny field") -> dict:
    return {
        "scene_description": scene,
        "character_name": "Luna",
        "age": 7,
        "num_images": 1,
        "story_id": story_id,
    }


class TestFreeIllustratedStoryGate:
    def test_first_story_claims_slot_and_allows(self, app, client, monkeypatch):
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("free-gate-1", tier="free")

        resp = client.post(
            "/generate-illustrations",
            json=_illustration_payload("story-A", "Page 1 scene"),
            headers=_headers(token),
        )
        assert resp.status_code == 200
        payload = resp.get_json()
        assert payload.get("code") != "FREE_ILLUSTRATED_STORY_USED"
        assert len(payload.get("illustrations", [])) == 1

        with app.app_context():
            user = db.session.get(User, "free-gate-1")
            assert user.free_illustrated_story_id is not None

    def test_same_story_continues_allowed(self, app, client, monkeypatch):
        """Multiple pages of the SAME story (same story_id) all illustrate."""
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("free-gate-2", tier="free")

        for page_scene in ("Page 1 scene", "Page 2 scene", "Page 3 scene"):
            resp = client.post(
                "/generate-illustrations",
                json=_illustration_payload("story-B", page_scene),
                headers=_headers(token),
            )
            assert resp.status_code == 200
            payload = resp.get_json()
            assert payload.get("code") != "FREE_ILLUSTRATED_STORY_USED"

        with app.app_context():
            user = db.session.get(User, "free-gate-2")
            claimed = user.free_illustrated_story_id
        # Still the same story's identity throughout — never re-claimed.
        assert claimed is not None

    def test_second_story_blocked(self, app, client, monkeypatch):
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("free-gate-3", tier="free")

        first = client.post(
            "/generate-illustrations",
            # Distinct scene text per "story" so this doesn't hit the
            # illustration cache (its key excludes story_id — a cache hit
            # would short-circuit before the gate, same as quota).
            json=_illustration_payload("story-C", "A sunny meadow scene"),
            headers=_headers(token),
        )
        assert first.status_code == 200
        assert first.get_json().get("code") != "FREE_ILLUSTRATED_STORY_USED"

        second = client.post(
            "/generate-illustrations",
            json=_illustration_payload("story-D", "A stormy mountain scene"),
            headers=_headers(token),
        )
        assert second.status_code == 200
        payload = second.get_json()
        assert payload["code"] == "FREE_ILLUSTRATED_STORY_USED"
        assert payload["illustrations"] == []
        assert payload["count"] == 0
        assert "Upgrade to Premium" in payload["message"]

    def test_premium_unaffected_by_gate(self, app, client, monkeypatch):
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("premium-gate-1", tier="premium")

        for story_id in ("story-E", "story-F", "story-G"):
            resp = client.post(
                "/generate-illustrations",
                json=_illustration_payload(story_id),
                headers=_headers(token),
            )
            assert resp.status_code == 200
            assert resp.get_json().get("code") != "FREE_ILLUSTRATED_STORY_USED"

        with app.app_context():
            user = db.session.get(User, "premium-gate-1")
            # The gate never writes the flag for a premium user.
            assert user.free_illustrated_story_id is None

    def test_byok_flag_on_free_tier_unaffected_by_gate(self, app, client, monkeypatch):
        """A `free`-tier row with the standalone has_byok flag set (distinct
        from actually sending user_api_key on this request) must still skip
        the gate, per the brief's BYOK-exempt requirement."""
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("byok-gate-1", tier="free", has_byok=True)

        for story_id in ("story-H", "story-I"):
            resp = client.post(
                "/generate-illustrations",
                json=_illustration_payload(story_id),
                headers=_headers(token),
            )
            assert resp.status_code == 200
            assert resp.get_json().get("code") != "FREE_ILLUSTRATED_STORY_USED"

        with app.app_context():
            user = db.session.get(User, "byok-gate-1")
            assert user.free_illustrated_story_id is None

    def test_proxy_fallback_same_character_treated_as_continuing(
        self, app, client, monkeypatch
    ):
        """When the client omits story_id (current production behavior — the
        Flutter client hasn't been wired up yet), the same character/
        companions/power across requests is treated as the same story."""
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("free-gate-proxy-1", tier="free")

        payload_no_story_id = {
            "scene_description": "A sunny field",
            "character_name": "Luna",
            "age": 7,
            "num_images": 1,
        }
        first = client.post(
            "/generate-illustrations",
            json=payload_no_story_id,
            headers=_headers(token),
        )
        assert first.status_code == 200
        assert first.get_json().get("code") != "FREE_ILLUSTRATED_STORY_USED"

        # Same character, different scene (a later page of the same story).
        payload_no_story_id_page2 = dict(payload_no_story_id)
        payload_no_story_id_page2["scene_description"] = "A dark forest"
        second = client.post(
            "/generate-illustrations",
            json=payload_no_story_id_page2,
            headers=_headers(token),
        )
        assert second.status_code == 200
        assert second.get_json().get("code") != "FREE_ILLUSTRATED_STORY_USED"

    def test_proxy_fallback_different_character_blocked(self, app, client, monkeypatch):
        _patch_flux(monkeypatch)
        with app.app_context():
            token = _create_user("free-gate-proxy-2", tier="free")

        first = client.post(
            "/generate-illustrations",
            json={
                "scene_description": "A sunny field",
                "character_name": "Luna",
                "age": 7,
                "num_images": 1,
            },
            headers=_headers(token),
        )
        assert first.status_code == 200
        assert first.get_json().get("code") != "FREE_ILLUSTRATED_STORY_USED"

        second = client.post(
            "/generate-illustrations",
            json={
                "scene_description": "A sunny field",
                "character_name": "Max",  # different hero → different story
                "age": 7,
                "num_images": 1,
            },
            headers=_headers(token),
        )
        assert second.status_code == 200
        assert second.get_json()["code"] == "FREE_ILLUSTRATED_STORY_USED"
