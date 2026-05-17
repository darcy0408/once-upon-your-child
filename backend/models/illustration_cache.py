"""Persistent illustration cache (cost reduction — re-reads must be free).

Every per-page illustration call used to re-bill the image provider, so a
parent re-reading a story to a child paid for the same picture again and
again. This table durably caches a generated image keyed by a sha256 of the
inputs that actually determine the picture (scene, character, style, age,
therapeutic focus, companions, power, and a hash of the character appearance
including any custom avatar). A cache hit returns the stored image, skips the
provider call AND skips the illustration quota — a re-read costs nothing.

Auto-created at boot by `db.create_all()` (the model is imported by
`backend/models/__init__.py`). The matching migration script
(`backend/migrations/add_illustration_cache.py`) is the canonical record and
exists for explicit/managed runs; a fresh Railway deploy does not need it run
manually.
"""
from datetime import datetime, timezone

from ..database import db


class IllustrationCache(db.Model):
    """One row per unique (inputs -> generated image) pair."""

    __tablename__ = 'illustration_cache'

    id = db.Column(db.Integer, primary_key=True)
    # sha256 hex of the normalized illustration inputs — the lookup key.
    cache_key = db.Column(db.String(64), unique=True, nullable=False, index=True)
    # Base64-encoded image payload (matches how images travel through the
    # /generate-illustrations response, i.e. the `image_data` field).
    image_data = db.Column(db.Text, nullable=False)
    # Image container format, e.g. 'png' / 'jpeg'.
    image_format = db.Column(db.String(16), nullable=True)
    # Which provider produced the cached image (flux_schnell / gemini_*).
    provider = db.Column(db.String(64), nullable=True)
    created_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    last_accessed_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    # Number of times this cached image has been served (incl. the first read).
    hit_count = db.Column(db.Integer, nullable=False, default=0)

    def to_dict(self):
        return {
            'id': self.id,
            'cache_key': self.cache_key,
            'image_data': self.image_data,
            'image_format': self.image_format,
            'provider': self.provider,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_accessed_at': (
                self.last_accessed_at.isoformat() if self.last_accessed_at else None
            ),
            'hit_count': self.hit_count,
        }
