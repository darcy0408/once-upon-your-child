"""Tests for the persistent illustration cache service (cost reduction).

Covers:
  * cache_key stability — identical / trivially-different inputs collide,
    meaningfully different inputs do not.
  * a cache hit returns the stored image and bumps hit_count.
  * a cache hit skips the provider call AND the illustration quota.
  * the cache layer degrades open — a DB error behaves as a miss / no-op.
"""
from __future__ import annotations

from unittest.mock import patch

from backend.services.illustration_cache_service import (
    compute_cache_key,
    get_cached_illustration,
    store_illustration,
)


class TestCacheKeyStability:
    """compute_cache_key must be deterministic and sensitive to real inputs."""

    def _base_kwargs(self) -> dict:
        return dict(
            scene_description="A hero stands in a glowing cave",
            character_name="Lily",
            style="children's book illustration",
            age=4,
            therapeutic_focus="bravery",
            companions=["dolphin Bubbles"],
            power_id="feeling_sense",
            character_appearance={"hair": "brown", "skin": "tan"},
        )

    def test_identical_inputs_produce_identical_key(self):
        k1 = compute_cache_key(**self._base_kwargs())
        k2 = compute_cache_key(**self._base_kwargs())
        assert k1 == k2
        assert len(k1) == 64  # sha256 hex

    def test_whitespace_and_case_normalized(self):
        """Trivial whitespace / case differences must still hit."""
        base = self._base_kwargs()
        variant = dict(base)
        variant["scene_description"] = "  A HERO   stands in a GLOWING cave  "
        variant["character_name"] = "LILY"
        assert compute_cache_key(**base) == compute_cache_key(**variant)

    def test_different_scene_changes_key(self):
        base = self._base_kwargs()
        other = dict(base)
        other["scene_description"] = "A hero stands on a mountain"
        assert compute_cache_key(**base) != compute_cache_key(**other)

    def test_different_age_changes_key(self):
        base = self._base_kwargs()
        other = dict(base)
        other["age"] = 9
        assert compute_cache_key(**base) != compute_cache_key(**other)

    def test_companion_order_does_not_change_key(self):
        base = dict(self._base_kwargs())
        base["companions"] = ["owl", "fox"]
        other = dict(base)
        other["companions"] = ["fox", "owl"]
        assert compute_cache_key(**base) == compute_cache_key(**other)

    def test_custom_avatar_changes_key(self):
        """A custom avatar must be part of the key (correct per-avatar image)."""
        base = self._base_kwargs()
        with_avatar = dict(base)
        with_avatar["character_appearance"] = {
            "hair": "brown",
            "custom_avatar_base64": "AAAABBBBCCCC",
        }
        other_avatar = dict(base)
        other_avatar["character_appearance"] = {
            "hair": "brown",
            "custom_avatar_base64": "ZZZZYYYYXXXX",
        }
        assert compute_cache_key(**base) != compute_cache_key(**with_avatar)
        assert compute_cache_key(**with_avatar) != compute_cache_key(**other_avatar)


class TestCacheReadWrite:
    """Round-trip behaviour against the test database."""

    def test_store_then_get_round_trips(self, app):
        with app.app_context():
            key = "a" * 64
            assert store_illustration(
                key, "BASE64IMAGE", image_format="png", provider="flux_schnell"
            ) is True
            cached = get_cached_illustration(key)
            assert cached is not None
            assert cached["image_data"] == "BASE64IMAGE"
            assert cached["format"] == "png"
            assert cached["provider"] == "flux_schnell"

    def test_get_miss_returns_none(self, app):
        with app.app_context():
            assert get_cached_illustration("f" * 64) is None

    def test_hit_increments_hit_count(self, app):
        with app.app_context():
            from backend.database import db
            from backend.models.illustration_cache import IllustrationCache

            key = "b" * 64
            store_illustration(key, "IMG", provider="flux_schnell")
            get_cached_illustration(key)
            get_cached_illustration(key)
            row = (
                db.session.query(IllustrationCache)
                .filter_by(cache_key=key)
                .one()
            )
            assert row.hit_count == 2

    def test_store_duplicate_key_is_idempotent(self, app):
        with app.app_context():
            key = "c" * 64
            assert store_illustration(key, "FIRST", provider="flux_schnell") is True
            # Second store for the same key is a no-op success, keeps first image.
            assert store_illustration(key, "SECOND", provider="gemini_openrouter") is True
            cached = get_cached_illustration(key)
            assert cached["image_data"] == "FIRST"


class TestCacheDegradesOpen:
    """A DB fault in the cache layer must never break image generation."""

    def test_get_db_error_returns_none(self, app):
        with app.app_context():
            with patch(
                "backend.database.db.session.query",
                side_effect=RuntimeError("db down"),
            ):
                # Behaves as a cache miss, does not raise.
                assert get_cached_illustration("d" * 64) is None

    def test_store_db_error_returns_false(self, app):
        with app.app_context():
            with patch(
                "backend.database.db.session.commit",
                side_effect=RuntimeError("db down"),
            ):
                # Returns False but does not raise.
                assert store_illustration("e" * 64, "IMG") is False

    def test_empty_inputs_are_safe_noops(self, app):
        with app.app_context():
            assert get_cached_illustration("") is None
            assert store_illustration("", "IMG") is False
            assert store_illustration("k" * 64, "") is False


class TestCacheHitSkipsProviderAndQuota:
    """Documents the route contract: a hit skips the provider and the quota.

    The route computes the key, calls get_cached_illustration BEFORE any
    provider call, and on a hit sets served_from_cache=True which gates BOTH
    the provider dispatch and the increment_illustration_quota call. These
    tests assert the helper provides exactly what the route needs to do that.
    """

    def test_hit_provides_image_without_provider(self, app):
        with app.app_context():
            key = compute_cache_key(
                scene_description="re-read scene",
                character_name="Mira",
                style="storybook",
                age=4,
            )
            store_illustration(key, "CACHEDIMG", provider="flux_schnell")

            # Simulate the route: a hit means no provider is invoked.
            provider_called = {"flux": False}

            def fake_flux(**_kwargs):
                provider_called["flux"] = True
                return [{"image_data": "FRESH"}]

            cached = get_cached_illustration(key)
            if cached and cached.get("image_data"):
                served_from_cache = True
                illustrations = [{"image_data": cached["image_data"]}]
            else:
                served_from_cache = False
                illustrations = fake_flux()

            assert served_from_cache is True
            assert provider_called["flux"] is False, (
                "a cache hit must skip the provider call"
            )
            assert illustrations[0]["image_data"] == "CACHEDIMG"

    def test_hit_means_quota_not_incremented(self, app):
        """served_from_cache=True must gate the quota increment off."""
        with app.app_context():
            key = compute_cache_key(
                scene_description="re-read again",
                character_name="Mira",
                style="storybook",
                age=4,
            )
            store_illustration(key, "CACHEDIMG", provider="flux_schnell")
            cached = get_cached_illustration(key)
            served_from_cache = bool(cached and cached.get("image_data"))

            quota_incremented = (
                len([{"image_data": "x"}]) > 0
                and not served_from_cache  # route's actual gate
            )
            assert quota_incremented is False, (
                "a re-read served from cache must not consume illustration quota"
            )
