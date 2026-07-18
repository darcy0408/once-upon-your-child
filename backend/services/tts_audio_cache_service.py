"""Persistent TTS narration audio cache read/write helpers.

Narration start used to wait on a full synthesis of the requested text on
every single play — including re-reads of a story that was narrated minutes
earlier. This module computes a stable cache key from every input that
influences the produced audio and reads/writes the ``TtsAudioCache`` Postgres
table around the provider call in ``/tts/synthesize``.

Design rules (mirrors backend/services/illustration_cache_service.py):
  * DEGRADE OPEN — every DB interaction is wrapped; any error is logged and
    swallowed so a cache-layer fault never breaks narration. A failed lookup
    behaves exactly like a cache miss.
  * A cache HIT skips the provider call AND the daily TTS quota — a re-read
    must be free.
  * The key normalizes ONLY whitespace in the text (collapse runs, strip).
    Unlike the illustration cache it does NOT lowercase: TTS output genuinely
    differs with casing ("NASA" vs "nasa") and punctuation, so those must
    stay part of the key.
  * The key is HMAC-SHA256'd with the app SECRET_KEY (COPPA amended-rule
    F-4 / G-5). Narration text embeds the child's first name; a plain sha256
    of low-entropy input is dictionary-attackable, so the key is salted with
    a server secret exactly like the illustration cache key.
  * The key includes a ``chain`` discriminator describing which provider
    family would serve the request (``azure`` when Azure AI Speech is
    configured; otherwise ``legacy-<audience>``), plus the premium/dialogue
    opt-in flags. Two users whose requests would be served by different
    provider chains (e.g. an adult on the legacy Gemini chain vs a teen on
    Edge) therefore never share a row, and audio synthesized under one
    provider policy is never replayed to an audience that policy excludes.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import re
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

# Fallback pepper used only if SECRET_KEY is somehow unset (dev/test-only;
# SECRET_KEY is required in production). Mirrors the illustration cache.
_DEV_FALLBACK_SALT = "dev-secret-key-fallback-tts-audio-cache"


def _cache_key_salt() -> str:
    """Resolve the HMAC salt for cache-key hashing (env, not app config)."""
    return os.getenv("SECRET_KEY") or _DEV_FALLBACK_SALT


def normalize_tts_text(text: Any) -> str:
    """Collapse internal whitespace and strip. Case/punctuation preserved —
    they change the spoken audio, so they must stay key-significant."""
    if text is None:
        return ""
    return re.sub(r"\s+", " ", str(text)).strip()


def compute_cache_key(
    *,
    text: Any,
    voice_id: Any,
    speed: Any = 1.0,
    chain: Any = "azure",
    premium_voice: bool = False,
    character_voice_id: Any = None,
) -> str:
    """Return the salted HMAC-SHA256 hex cache key for a synthesis request.

    ``text`` is whitespace-normalized then sub-hashed (it can be many KB);
    ``speed`` is rendered with two decimals so 1.0 and 1.00 collide;
    ``chain`` names the provider family that would serve the request (the
    route passes 'azure' or 'legacy-<audience>'); the premium/dialogue flags
    fragment the key only when the caller says they can take effect.
    """
    text_hash = hashlib.sha256(normalize_tts_text(text).encode("utf-8")).hexdigest()
    try:
        speed_component = f"{float(speed):.2f}"
    except (TypeError, ValueError):
        speed_component = "1.00"
    parts = [
        f"text={text_hash}",
        f"voice={(str(voice_id) if voice_id is not None else '').strip()}",
        f"speed={speed_component}",
        f"chain={(str(chain) if chain is not None else '').strip()}",
        f"premium={'1' if premium_voice else '0'}",
        f"dialogue={(str(character_voice_id) if character_voice_id else '').strip()}",
    ]
    canonical = "\n".join(parts)
    return hmac.new(
        _cache_key_salt().encode("utf-8"), canonical.encode("utf-8"), hashlib.sha256
    ).hexdigest()


def get_cached_tts_audio(cache_key: str) -> dict | None:
    """Return cached audio for *cache_key*, or None on miss / any error.

    On a hit the row's ``hit_count`` is incremented and ``last_accessed_at``
    is refreshed. All DB access is guarded — a fault degrades to a miss.
    """
    if not cache_key:
        return None
    try:
        from ..database import db
        from ..models.tts_audio_cache import TtsAudioCache

        row = (
            db.session.query(TtsAudioCache).filter_by(cache_key=cache_key).one_or_none()
        )
        if row is None:
            return None

        try:
            word_timestamps = json.loads(row.word_timestamps_json or "[]")
            if not isinstance(word_timestamps, list):
                word_timestamps = []
        except (ValueError, TypeError):
            word_timestamps = []

        result = {
            "audio_base64": row.audio_base64,
            "format": row.audio_format or "mp3",
            "provider": row.provider,
            "word_timestamps": word_timestamps,
        }
        try:
            row.hit_count = (row.hit_count or 0) + 1
            row.last_accessed_at = datetime.now(timezone.utc)
            db.session.commit()
        except Exception as exc:  # noqa: BLE001
            logger.warning("tts_audio_cache: failed to bump hit stats (%s)", exc)
            try:
                db.session.rollback()
            except Exception:  # noqa: BLE001
                pass
        return result
    except Exception as exc:  # noqa: BLE001 — degrade open: treat as a miss
        logger.warning("tts_audio_cache: lookup failed, treating as miss (%s)", exc)
        try:
            from ..database import db

            db.session.rollback()
        except Exception:  # noqa: BLE001
            pass
        return None


def store_tts_audio(
    cache_key: str,
    audio_base64: str,
    *,
    audio_format: str | None = None,
    provider: str | None = None,
    word_timestamps: list | None = None,
    user_id: str | None = None,
    text_chars: int | None = None,
) -> bool:
    """Store freshly synthesized audio under *cache_key*. Never raises.

    ``user_id`` records the account that created this row so
    ``purge_user_data`` can evict it on that account's right-to-erasure
    request (F-4 / G-5 — the audio speaks the child's name aloud).

    Returns True on a successful write, False otherwise. A pre-existing row
    for the same key (e.g. a concurrent write) is treated as success.
    """
    if not cache_key or not audio_base64:
        return False
    try:
        from ..database import db
        from ..models.tts_audio_cache import TtsAudioCache

        existing = (
            db.session.query(TtsAudioCache).filter_by(cache_key=cache_key).one_or_none()
        )
        if existing is not None:
            return True

        try:
            timestamps_json = json.dumps(word_timestamps or [])
        except (ValueError, TypeError):
            timestamps_json = "[]"

        now = datetime.now(timezone.utc)
        row = TtsAudioCache(
            cache_key=cache_key,
            user_id=user_id,
            audio_base64=audio_base64,
            audio_format=audio_format,
            provider=provider,
            word_timestamps_json=timestamps_json,
            text_chars=text_chars,
            created_at=now,
            last_accessed_at=now,
            hit_count=0,
        )
        db.session.add(row)
        db.session.commit()
        return True
    except Exception as exc:  # noqa: BLE001 — never break narration
        logger.warning("tts_audio_cache: store failed (%s)", exc)
        try:
            from ..database import db

            db.session.rollback()
        except Exception:  # noqa: BLE001
            pass
        return False
