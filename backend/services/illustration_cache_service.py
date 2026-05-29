"""Persistent illustration cache read/write helpers (cost reduction).

A per-page illustration is fully determined by its inputs (scene description,
character, style, age, therapeutic focus, companions, power, and the character
appearance — including any custom avatar). Re-reading a story therefore used
to re-bill the image provider for an identical picture. This module computes a
stable sha256 cache key from those inputs and reads/writes the
``IllustrationCache`` Postgres table around the provider call.

Design rules:
  * DEGRADE OPEN — every DB interaction is wrapped; any error is logged and
    swallowed so a cache-layer fault never breaks image generation. A failed
    lookup behaves exactly like a cache miss.
  * A cache HIT skips the provider call AND the illustration quota — a re-read
    must be free.
  * The key normalizes whitespace and case for the text inputs so trivial
    differences (extra spaces, capitalization) still hit; the character
    appearance / custom avatar is hashed verbatim so a custom-avatar user
    still gets correct images (just a lower hit rate).
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)


def _norm_text(value: Any) -> str:
    """Lowercase + collapse internal whitespace so trivial diffs still hit."""
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip().lower()


def _appearance_hash(character_appearance: Any) -> str:
    """Stable hash of the character appearance, INCLUDING any custom avatar.

    The appearance may be a dict (possibly containing a large
    ``custom_avatar_base64`` field) or a string. It is serialized
    deterministically and hashed verbatim — a custom-avatar user still gets a
    correct (per-avatar) cache key, just with a lower hit rate across users.
    """
    if not character_appearance:
        return "none"
    try:
        if isinstance(character_appearance, dict):
            serialized = json.dumps(character_appearance, sort_keys=True, default=str)
        else:
            serialized = str(character_appearance)
    except Exception:  # noqa: BLE001 — never let serialization break keying
        serialized = repr(character_appearance)
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def _norm_companions(companions: Any) -> str:
    """Order-independent normalized representation of the companions list."""
    if not companions:
        return ""
    try:
        items = [_norm_text(c) for c in companions]
    except TypeError:
        return _norm_text(companions)
    return "|".join(sorted(items))


def compute_cache_key(
    *,
    scene_description: Any,
    character_name: Any,
    style: Any,
    age: Any,
    therapeutic_focus: Any = None,
    companions: Any = None,
    power_id: Any = None,
    character_appearance: Any = None,
) -> str:
    """Return the sha256 hex cache key for a set of illustration inputs.

    The key is a sha256 over a normalized, field-tagged concatenation of every
    input that influences the generated image. Normalization (lowercase +
    whitespace collapse) means trivially different requests still collide on a
    hit; the appearance component is a sub-hash that includes any custom
    avatar base64.
    """
    parts = [
        f"scene={_norm_text(scene_description)}",
        f"char={_norm_text(character_name)}",
        f"style={_norm_text(style)}",
        f"age={_norm_text(age)}",
        f"focus={_norm_text(therapeutic_focus)}",
        f"companions={_norm_companions(companions)}",
        f"power={_norm_text(power_id)}",
        f"appearance={_appearance_hash(character_appearance)}",
    ]
    canonical = "\n".join(parts)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def get_cached_illustration(cache_key: str) -> dict | None:
    """Return a cached image dict for *cache_key*, or None on miss / any error.

    On a hit the row's ``hit_count`` is incremented and ``last_accessed_at`` is
    refreshed. All DB access is guarded — a fault degrades to a cache miss.
    """
    if not cache_key:
        return None
    try:
        from ..database import db
        from ..models.illustration_cache import IllustrationCache

        row = (
            db.session.query(IllustrationCache)
            .filter_by(cache_key=cache_key)
            .one_or_none()
        )
        if row is None:
            return None

        result = {
            "image_data": row.image_data,
            "format": row.image_format or "png",
            "provider": row.provider,
        }
        try:
            row.hit_count = (row.hit_count or 0) + 1
            row.last_accessed_at = datetime.now(timezone.utc)
            db.session.commit()
        except Exception as exc:  # noqa: BLE001
            logger.warning("illustration_cache: failed to bump hit stats (%s)", exc)
            try:
                db.session.rollback()
            except Exception:  # noqa: BLE001
                pass
        return result
    except Exception as exc:  # noqa: BLE001 — degrade open: treat as a miss
        logger.warning("illustration_cache: lookup failed, treating as miss (%s)", exc)
        try:
            from ..database import db

            db.session.rollback()
        except Exception:  # noqa: BLE001
            pass
        return None


def store_illustration(
    cache_key: str,
    image_data: str,
    *,
    image_format: str | None = None,
    provider: str | None = None,
) -> bool:
    """Store a freshly generated image under *cache_key*. Never raises.

    Returns True on a successful write, False otherwise. A pre-existing row for
    the same key (e.g. a concurrent write) is treated as success.
    """
    if not cache_key or not image_data:
        return False
    try:
        from ..database import db
        from ..models.illustration_cache import IllustrationCache

        existing = (
            db.session.query(IllustrationCache)
            .filter_by(cache_key=cache_key)
            .one_or_none()
        )
        if existing is not None:
            return True

        now = datetime.now(timezone.utc)
        row = IllustrationCache(
            cache_key=cache_key,
            image_data=image_data,
            image_format=image_format,
            provider=provider,
            created_at=now,
            last_accessed_at=now,
            hit_count=0,
        )
        db.session.add(row)
        db.session.commit()
        return True
    except Exception as exc:  # noqa: BLE001 — never break image generation
        logger.warning("illustration_cache: store failed (%s)", exc)
        try:
            from ..database import db

            db.session.rollback()
        except Exception:  # noqa: BLE001
            pass
        return False
