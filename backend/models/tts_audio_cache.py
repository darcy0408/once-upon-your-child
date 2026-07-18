"""Persistent TTS narration audio cache (latency + quota reduction).

Narration audio is fully determined by its inputs (the cleaned story text,
voice, speed, and which provider chain serves the request). Re-reading a story
used to re-synthesize the identical MP3 from scratch — burning the user's
daily TTS quota and adding seconds of dead air before playback. This table
durably caches synthesized audio keyed by a salted HMAC-SHA256 of those
inputs. A cache hit returns the stored audio (and word timestamps) instantly,
skips the provider call AND skips the TTS quota — a re-read costs nothing.

Mirrors ``IllustrationCache`` (backend/models/illustration_cache.py): the
table is auto-created at boot by ``db.create_all()`` (the model is imported by
``backend/models/__init__.py``), so no manual migration is needed on deploy.

Growth is bounded two ways (see ``purge_stale_tts_audio_cache`` in
backend/services/data_retention.py): a last-accessed TTL
(``TTS_AUDIO_CACHE_RETENTION_DAYS``, default 90) and a hard row cap
(``TTS_AUDIO_CACHE_MAX_ROWS``, default 20000) that evicts least-recently-
served rows first.
"""

from datetime import datetime, timezone

from ..database import db


class TtsAudioCache(db.Model):
    """One row per unique (synthesis inputs -> narration audio) pair."""

    __tablename__ = "tts_audio_cache"

    id = db.Column(db.Integer, primary_key=True)
    # HMAC-SHA256 (salted with the app SECRET_KEY) of the synthesis inputs —
    # the lookup key. Salting matters here even more than for illustrations:
    # narration text carries the child's first name, and an unsalted hash of
    # low-entropy input is dictionary-attackable (COPPA amended-rule F-4/G-5).
    # See tts_audio_cache_service.compute_cache_key().
    cache_key = db.Column(db.String(64), unique=True, nullable=False, index=True)
    # Account that created this row (F-4 / G-5: right-to-erasure). Nullable —
    # rows created by the shared 'anonymous' guest session have no
    # individually-deletable owner and age out via the TTL instead.
    # purge_user_data() deletes the rows an account created.
    user_id = db.Column(db.String(36), nullable=True, index=True)
    # Base64-encoded MP3 payload (matches how audio travels through the
    # /tts/synthesize response, i.e. the `audio_base64` field).
    audio_base64 = db.Column(db.Text, nullable=False)
    # Audio container format — 'mp3' for every current provider.
    audio_format = db.Column(db.String(16), nullable=True)
    # Which provider produced the cached audio (azure / elevenlabs / gemini /
    # edge) — echoed back in the response `provider` field on a hit.
    provider = db.Column(db.String(64), nullable=True)
    # JSON-encoded word-timestamp list ([{start_ms, end_ms}, ...]) so a cache
    # hit keeps read-along highlighting identical to a fresh synthesis.
    # '[]' when the serving provider had no alignment data.
    word_timestamps_json = db.Column(db.Text, nullable=True)
    # Length of the cleaned text that was synthesized — lets ops reason about
    # row size / provider spend saved without decoding the audio.
    text_chars = db.Column(db.Integer, nullable=True)
    created_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    last_accessed_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    # Number of times this cached audio has been served.
    hit_count = db.Column(db.Integer, nullable=False, default=0)

    def to_dict(self):
        return {
            "id": self.id,
            "cache_key": self.cache_key,
            "user_id": self.user_id,
            "audio_base64": self.audio_base64,
            "audio_format": self.audio_format,
            "provider": self.provider,
            "word_timestamps_json": self.word_timestamps_json,
            "text_chars": self.text_chars,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_accessed_at": (
                self.last_accessed_at.isoformat() if self.last_accessed_at else None
            ),
            "hit_count": self.hit_count,
        }
