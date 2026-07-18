"""Tests for the persistent TTS narration audio cache service.

Covers:
  * cache_key composition — every synthesis-affecting param (text, voice,
    speed, provider chain, premium/dialogue opt-ins) changes the key;
    whitespace-only text differences still hit; case is key-significant
    (unlike the illustration cache — casing changes spoken audio).
  * the key is a salted HMAC (SECRET_KEY), not a plain sha256.
  * store + hit round-trip, hit_count bump, word-timestamp round-trip.
  * the cache layer degrades open — a DB error behaves as a miss / no-op.
  * the retention purge enforces both the TTL and the row cap.
"""

from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from backend.services.tts_audio_cache_service import (
    compute_cache_key,
    get_cached_tts_audio,
    normalize_tts_text,
    store_tts_audio,
)


class TestCacheKeyComposition:
    """compute_cache_key must be deterministic and sensitive to real inputs."""

    def _base_kwargs(self) -> dict:
        return dict(
            text="Once upon a time, Luna followed a shining map.",
            voice_id="XrExE9yKIg1WjnnlVkGX",
            speed=1.0,
            chain="azure",
            premium_voice=False,
            character_voice_id=None,
        )

    def test_identical_inputs_produce_identical_key(self):
        k1 = compute_cache_key(**self._base_kwargs())
        k2 = compute_cache_key(**self._base_kwargs())
        assert k1 == k2
        assert len(k1) == 64  # sha256 hex

    def test_whitespace_normalized_but_case_preserved(self):
        base = self._base_kwargs()
        ws_variant = dict(base)
        ws_variant["text"] = "  Once upon a time,   Luna followed a shining map.  "
        assert compute_cache_key(**base) == compute_cache_key(**ws_variant)

        case_variant = dict(base)
        case_variant["text"] = "once upon a time, luna followed a shining map."
        # Casing changes pronunciation/emphasis — it must fragment the key.
        assert compute_cache_key(**base) != compute_cache_key(**case_variant)

    def test_different_text_changes_key(self):
        other = dict(self._base_kwargs())
        other["text"] = "A completely different story."
        assert compute_cache_key(**self._base_kwargs()) != compute_cache_key(**other)

    def test_different_voice_changes_key(self):
        other = dict(self._base_kwargs())
        other["voice_id"] = "21m00Tcm4TlvDq8ikWAM"
        assert compute_cache_key(**self._base_kwargs()) != compute_cache_key(**other)

    def test_different_speed_changes_key(self):
        other = dict(self._base_kwargs())
        other["speed"] = 0.85
        assert compute_cache_key(**self._base_kwargs()) != compute_cache_key(**other)

    def test_equivalent_speed_representations_collide(self):
        a = dict(self._base_kwargs())
        a["speed"] = 1
        b = dict(self._base_kwargs())
        b["speed"] = 1.0
        assert compute_cache_key(**a) == compute_cache_key(**b)

    def test_different_chain_changes_key(self):
        """Audio cached under one provider chain must never serve another —
        the legacy chain's audience gates (adult/teen/u13) depend on it."""
        base = self._base_kwargs()
        for chain in ("legacy-adult", "legacy-teen", "legacy-u13"):
            other = dict(base)
            other["chain"] = chain
            assert compute_cache_key(**base) != compute_cache_key(**other)
        assert compute_cache_key(
            **{**base, "chain": "legacy-adult"}
        ) != compute_cache_key(**{**base, "chain": "legacy-teen"})

    def test_premium_and_dialogue_flags_change_key(self):
        base = self._base_kwargs()
        premium = dict(base)
        premium["premium_voice"] = True
        assert compute_cache_key(**base) != compute_cache_key(**premium)

        dialogue = dict(base)
        dialogue["character_voice_id"] = "D38z5RcWu1voky8WS1ja"
        assert compute_cache_key(**base) != compute_cache_key(**dialogue)

    def test_key_is_salted_not_plain_sha256(self, monkeypatch):
        """F-4 / G-5: narration text embeds the child's first name; the key
        must be an HMAC keyed with SECRET_KEY, not a plain sha256."""
        monkeypatch.setenv("SECRET_KEY", "test-salt-one")
        kwargs = self._base_kwargs()
        key = compute_cache_key(**kwargs)

        text_hash = hashlib.sha256(
            normalize_tts_text(kwargs["text"]).encode("utf-8")
        ).hexdigest()
        canonical = "\n".join(
            [
                f"text={text_hash}",
                f"voice={kwargs['voice_id']}",
                "speed=1.00",
                f"chain={kwargs['chain']}",
                "premium=0",
                "dialogue=",
            ]
        )
        plain_sha256 = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        assert key != plain_sha256

    def test_different_secret_key_produces_different_key(self, monkeypatch):
        kwargs = self._base_kwargs()
        monkeypatch.setenv("SECRET_KEY", "secret-a")
        key_a = compute_cache_key(**kwargs)
        monkeypatch.setenv("SECRET_KEY", "secret-b")
        key_b = compute_cache_key(**kwargs)
        assert key_a != key_b


class TestStoreAndHit:
    """Round-trip through the DB-backed cache."""

    def test_miss_returns_none(self, app):
        with app.app_context():
            assert get_cached_tts_audio("0" * 64) is None

    def test_store_then_hit_round_trips_audio_and_timestamps(self, app):
        with app.app_context():
            key = compute_cache_key(
                text="Hello world.", voice_id="v1", speed=1.0, chain="azure"
            )
            timestamps = [
                {"start_ms": 0, "end_ms": 120},
                {"start_ms": 130, "end_ms": 250},
            ]
            assert store_tts_audio(
                key,
                "bW9jay1hdWRpbw==",
                audio_format="mp3",
                provider="azure",
                word_timestamps=timestamps,
                user_id="user-1",
                text_chars=12,
            )

            cached = get_cached_tts_audio(key)
            assert cached is not None
            assert cached["audio_base64"] == "bW9jay1hdWRpbw=="
            assert cached["format"] == "mp3"
            assert cached["provider"] == "azure"
            assert cached["word_timestamps"] == timestamps

    def test_hit_bumps_hit_count_and_last_accessed(self, app):
        with app.app_context():
            from backend.models.tts_audio_cache import TtsAudioCache

            key = compute_cache_key(
                text="Bump me.", voice_id="v1", speed=1.0, chain="azure"
            )
            store_tts_audio(key, "YXVkaW8=", provider="azure")
            get_cached_tts_audio(key)
            get_cached_tts_audio(key)

            row = TtsAudioCache.query.filter_by(cache_key=key).one()
            assert row.hit_count == 2

    def test_duplicate_store_is_treated_as_success(self, app):
        with app.app_context():
            from backend.models.tts_audio_cache import TtsAudioCache

            key = compute_cache_key(
                text="Twice.", voice_id="v1", speed=1.0, chain="azure"
            )
            assert store_tts_audio(key, "b25l", provider="azure")
            assert store_tts_audio(key, "dHdv", provider="azure")
            rows = TtsAudioCache.query.filter_by(cache_key=key).all()
            assert len(rows) == 1
            assert rows[0].audio_base64 == "b25l"  # first write wins

    def test_empty_inputs_are_rejected(self, app):
        with app.app_context():
            assert store_tts_audio("", "YXVkaW8=") is False
            assert store_tts_audio("a" * 64, "") is False
            assert get_cached_tts_audio("") is None


class TestDegradeOpen:
    """A cache-layer DB fault must behave as a miss / no-op, never raise."""

    def test_lookup_error_degrades_to_miss(self, app):
        with app.app_context():
            with patch(
                "backend.database.db.session.query",
                side_effect=RuntimeError("db down"),
            ):
                assert get_cached_tts_audio("a" * 64) is None

    def test_store_error_degrades_to_false(self, app):
        with app.app_context():
            with patch(
                "backend.database.db.session.query",
                side_effect=RuntimeError("db down"),
            ):
                assert store_tts_audio("a" * 64, "YXVkaW8=") is False


class TestRetentionPurge:
    """purge_stale_tts_audio_cache enforces the TTL and the row cap."""

    def _seed(self, app, key_suffix: str, last_accessed: datetime) -> None:
        from backend.database import db
        from backend.models.tts_audio_cache import TtsAudioCache

        row = TtsAudioCache(
            cache_key=(key_suffix * 64)[:64],
            audio_base64="YXVkaW8=",
            provider="azure",
            created_at=last_accessed,
            last_accessed_at=last_accessed,
            hit_count=0,
        )
        db.session.add(row)
        db.session.commit()

    def test_ttl_evicts_stale_rows_only(self, app):
        from backend.models.tts_audio_cache import TtsAudioCache
        from backend.services.data_retention import purge_stale_tts_audio_cache

        with app.app_context():
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            self._seed(app, "a", now - timedelta(days=200))
            self._seed(app, "b", now - timedelta(days=1))

            summary = purge_stale_tts_audio_cache(stale_days=90)

            assert summary["evicted"] == 1
            remaining = TtsAudioCache.query.all()
            assert len(remaining) == 1
            assert remaining[0].cache_key.startswith("b")

    def test_row_cap_evicts_least_recently_served_first(self, app):
        from backend.models.tts_audio_cache import TtsAudioCache
        from backend.services.data_retention import purge_stale_tts_audio_cache

        with app.app_context():
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            self._seed(app, "c", now - timedelta(days=3))  # oldest
            self._seed(app, "d", now - timedelta(days=2))
            self._seed(app, "e", now - timedelta(days=1))  # newest

            summary = purge_stale_tts_audio_cache(stale_days=90, max_rows=2)

            assert summary["evicted"] == 0
            assert summary["evicted_over_cap"] == 1
            keys = {row.cache_key[:1] for row in TtsAudioCache.query.all()}
            assert keys == {"d", "e"}
