"""Data-retention purge logic (CMP-5 / PP-13).

The privacy policy promises that inactive-account data is deleted after a
retention window (2 years of inactivity by default). This module centralises
the deletion / anonymisation logic so it can be invoked from two places:

  * the user-initiated erasure endpoint (``DELETE /api/user/<id>/data``), and
  * the scheduled Celery-beat retention job (``purge_inactive_accounts``).

``purge_user_data`` performs exactly the same cascade + anonymisation as the
erasure endpoint — child content is deleted and the user row is anonymised —
so the two paths can never drift apart.

Configuration
-------------
``DATA_RETENTION_INACTIVE_DAYS`` — integer, default 730 (2 years). Accounts
with no activity for at least this many days are purged by the scheduled job.
``ILLUSTRATION_CACHE_RETENTION_DAYS`` — integer, default 365. Cached
illustrations not served for at least this many days are evicted (bounds the
shared illustration cache so no image — including any custom-avatar likeness —
is retained indefinitely; amended-COPPA R-6).
``UNCONSENTED_CONTACT_MAX_DAYS`` — integer, default 30. A parental-consent
round-trip that captured a parent email but was never verified within this
window has that contact info deleted (amended-COPPA R-2).
``TTS_AUDIO_CACHE_RETENTION_DAYS`` / ``TTS_AUDIO_CACHE_MAX_ROWS`` — integers,
default 90 / 20000. Cached narration audio not served within the window is
evicted, and the table is additionally capped at the row limit (least-
recently-served evicted first) so it can never grow unbounded.
"""

import logging
import uuid
from datetime import datetime, timedelta, timezone

from backend.database import db
from backend.models.user import User

logger = logging.getLogger(__name__)

# Default retention window: 2 years of inactivity, matching PRIVACY_POLICY.md.
DEFAULT_RETENTION_INACTIVE_DAYS = 730

# Default illustration-cache eviction window (days). The illustration cache is a
# shared, content-addressed cost optimisation with no user_id; a stale-eviction
# TTL keeps it from retaining any image indefinitely without breaking the
# cross-user hit rate that makes the cache worthwhile.
DEFAULT_ILLUSTRATION_CACHE_RETENTION_DAYS = 365

# Default window (days) after which an unverified consent round-trip's captured
# parent email is deleted. Comfortably beyond the 15-minute code expiry and any
# realistic retry, so an in-progress flow is never disturbed.
DEFAULT_UNCONSENTED_CONTACT_MAX_DAYS = 30

# Default TTS-audio-cache eviction window (days) and hard row cap. Narration
# audio rows are large (a base64 MP3 chunk is ~0.5-2 MB) and speak the child's
# name aloud, so this cache is bounded much more aggressively than the
# illustration cache: a shorter TTL plus an absolute row cap that evicts
# least-recently-served rows first.
DEFAULT_TTS_AUDIO_CACHE_RETENTION_DAYS = 90
DEFAULT_TTS_AUDIO_CACHE_MAX_ROWS = 20_000

# Accounts that must never be auto-purged regardless of inactivity. The shared
# 'anonymous' user backs anonymous story generation; deleting it would break
# the app for every guest.
PROTECTED_USER_IDS = frozenset({"anonymous"})


def get_retention_inactive_days() -> int:
    """Resolve the inactivity retention window (days) from the environment.

    Falls back to ``DEFAULT_RETENTION_INACTIVE_DAYS`` (730) when the env var is
    unset, empty, non-numeric, or non-positive.
    """
    import os

    raw = os.getenv("DATA_RETENTION_INACTIVE_DAYS")
    if raw is None or not str(raw).strip():
        return DEFAULT_RETENTION_INACTIVE_DAYS
    try:
        value = int(str(raw).strip())
    except (TypeError, ValueError):
        logger.warning(
            "DATA_RETENTION_INACTIVE_DAYS=%r is not an integer; "
            "falling back to %d days",
            raw,
            DEFAULT_RETENTION_INACTIVE_DAYS,
        )
        return DEFAULT_RETENTION_INACTIVE_DAYS
    if value <= 0:
        logger.warning(
            "DATA_RETENTION_INACTIVE_DAYS=%d is not positive; "
            "falling back to %d days",
            value,
            DEFAULT_RETENTION_INACTIVE_DAYS,
        )
        return DEFAULT_RETENTION_INACTIVE_DAYS
    return value


def _last_activity(user: User) -> datetime | None:
    """Best-available activity timestamp for an account.

    Uses ``last_active_at`` (set on login / anonymous-session / token refresh)
    when present, otherwise falls back to ``created_at``. Returns a naive UTC
    datetime (the DB stores naive UTC) or ``None`` if neither is available.
    """
    ts = getattr(user, "last_active_at", None) or getattr(user, "created_at", None)
    if ts is None:
        return None
    if ts.tzinfo is not None:
        ts = ts.astimezone(timezone.utc).replace(tzinfo=None)
    return ts


def _is_already_anonymized(user: User) -> bool:
    """True when the account has already been anonymised by a prior erasure."""
    email = user.email or ""
    return user.password_hash == "DELETED" or email.endswith("@deleted.local")


def _delete_stripe_customer(customer_id: str | None) -> None:
    """Best-effort deletion of the Stripe customer for an erased account.

    Erasure of local data is the legally-required action and must never be
    blocked by a Stripe outage or misconfiguration, so every failure here is
    logged and swallowed rather than raised (GDPR Art.17(2) / CCPA
    §1798.105(c): controllers must propagate erasure to processors).
    """
    if not customer_id:
        return
    try:
        import os

        import stripe

        if not getattr(stripe, "api_key", None):
            # The web process sets this via init_stripe_api at boot, but the
            # Celery worker (which runs the retention purge) does not, so resolve
            # it here the same way config does. Env var is STRIPE_SECRET_KEY
            # (STRIPE_API_KEY is an accepted alias) — see config/__init__.py.
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY") or os.getenv(
                "STRIPE_API_KEY"
            )
        if not stripe.api_key:
            logger.warning(
                "Erasure: STRIPE_API_KEY not configured; could not delete "
                "Stripe customer %s. Record it for manual deletion.",
                customer_id,
            )
            return
        stripe.Customer.delete(customer_id)
        logger.info("Erasure: deleted Stripe customer %s", customer_id)
    except Exception:
        logger.exception(
            "Erasure: failed to delete Stripe customer %s; local data was "
            "still erased. Manual deletion at Stripe may be required.",
            customer_id,
        )


def purge_user_data(user: User, *, commit: bool = True) -> None:
    """Delete all child content for ``user`` and anonymise the user row.

    This is the single source of truth for COPPA right-to-erasure and the
    data-retention purge job. It deletes characters, linear stories,
    interactive stories (and their cascade), achievements, consent records and
    their transient verification codes, and the parent-authored hidden Big
    Feelings guidance, then anonymises the user record, bumps ``token_version``
    so any outstanding access tokens are revoked, and propagates the erasure to
    Stripe (best-effort).

    The caller owns the transaction unless ``commit=True`` (the default), in
    which case this function commits. On any error the caller should roll back.
    """
    # Imported lazily to avoid import-time cycles with the models package.
    from backend.models import (
        AchievementStats,
        InteractiveStory,
        InventoryItem,
        StoryChoice,
        StorySegment,
        StoryState,
        UserAchievement,
    )
    from backend.models.character import Character
    from backend.models.consent_record import ConsentRecord, ConsentVerificationCode
    from backend.models.iap_event import IapPurchase
    from backend.models.illustration_cache import IllustrationCache
    from backend.models.parent_hidden_context import ParentHiddenContext
    from backend.models.story import Story

    user_id = user.id

    # --- Delete interactive story data (cascade-aware) ---
    interactive_stories = InteractiveStory.query.filter_by(user_id=user_id).all()
    for story in interactive_stories:
        StoryChoice.query.filter(
            StoryChoice.segment_id.in_(
                db.session.query(StorySegment.id).filter_by(story_id=story.id)
            )
        ).delete(synchronize_session=False)
        StorySegment.query.filter_by(story_id=story.id).delete()
        InventoryItem.query.filter_by(story_id=story.id).delete()
        StoryState.query.filter_by(story_id=story.id).delete()
        db.session.delete(story)

    # --- Delete linear stories ---
    Story.query.filter_by(user_id=user_id).delete()

    # --- Delete characters ---
    Character.query.filter_by(user_id=user_id).delete()

    # --- Delete achievements ---
    UserAchievement.query.filter_by(user_id=user_id).delete()
    AchievementStats.query.filter_by(user_id=user_id).delete()

    # --- Delete IAP purchase records ---
    # IapPurchase is the per-user store-subscription record and carries a
    # user_id, so it must be erased. IapNotificationEvent is intentionally
    # left alone: it is a dedup table keyed by the store notification id (not
    # a user_id) and holds no user-scoped PII — see backend/models/iap_event.py.
    IapPurchase.query.filter_by(user_id=user_id).delete()

    # --- Delete consent records + transient verification codes ---
    # Codes carry an FK to consent_record.id, so they must go first.
    ConsentVerificationCode.query.filter_by(user_id=user_id).delete()
    ConsentRecord.query.filter_by(user_id=user_id).delete()

    # --- Delete parent-authored hidden Big Feelings guidance ---
    # Child-sensitive emotional data (trigger / coping tool / repair goal);
    # right-to-erasure must remove it (COPPA §312.7 / GDPR Art.17).
    ParentHiddenContext.query.filter_by(user_id=user_id).delete()

    # --- Delete this account's cached illustrations (F-4 / G-5) ---
    # The illustration cache is otherwise a shared, content-addressed cost
    # optimisation (see illustration_cache_service) that would only ever
    # expire via the 365-day TTL (purge_stale_illustration_cache); an account
    # deletion right must not wait a year for content it caused to be
    # generated to disappear. Rows written before the user_id column existed
    # have no attributable owner and are left for the TTL to age out.
    IllustrationCache.query.filter_by(user_id=user_id).delete()

    # --- Delete this account's cached narration audio (F-4 / G-5) ---
    # Same rationale as the illustration cache above: the TTS audio cache is a
    # shared, content-addressed cost/latency optimisation, but its rows speak
    # the child's name aloud — an account deletion must not wait on the TTL
    # for audio that account caused to be synthesized to disappear.
    from backend.models.tts_audio_cache import TtsAudioCache

    TtsAudioCache.query.filter_by(user_id=user_id).delete()

    # --- Anonymize user record ---
    # Capture the Stripe customer id before nulling it so erasure can be
    # propagated to Stripe after the local transaction commits.
    stripe_customer_id = user.stripe_customer_id
    anon_id = str(uuid.uuid4())[:8]
    user.username = f"deleted_{anon_id}"
    user.email = f"deleted_{anon_id}@deleted.local"
    user.password_hash = "DELETED"
    user.declared_age = None
    user.is_under_13 = False
    user.stripe_customer_id = None
    user.gemini_api_key_encrypted = None
    user.has_byok = False
    user.stories_created_count = 0
    user.stories_generated_this_month = 0
    user.illustrations_generated_this_month = 0
    # Invalidate every outstanding access token for this account so the
    # erasure cannot be undone by a still-valid pre-deletion token (M-1).
    user.token_version = (getattr(user, "token_version", 0) or 0) + 1

    if commit:
        db.session.commit()

    # Propagate erasure to Stripe (best-effort; never blocks local erasure).
    _delete_stripe_customer(stripe_customer_id)


def purge_inactive_accounts(inactive_days: int | None = None) -> dict:
    """Anonymise every account inactive beyond the retention window.

    Safe by construction: only accounts whose best-available activity
    timestamp is strictly older than ``cutoff`` are purged; recently-active
    accounts, protected accounts (the shared anonymous user) and accounts
    already anonymised by a prior erasure are skipped. Each account is purged
    in its own transaction so one failure cannot abort the whole run.

    Returns a summary dict with counts.
    """
    if inactive_days is None:
        inactive_days = get_retention_inactive_days()

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    cutoff = now - timedelta(days=inactive_days)

    logger.info(
        "Data-retention purge starting: window=%d days, cutoff=%s (UTC)",
        inactive_days,
        cutoff.isoformat(),
    )

    purged = 0
    skipped_recent = 0
    skipped_protected = 0
    skipped_already = 0
    errors = 0

    users = User.query.all()
    for user in users:
        if user.id in PROTECTED_USER_IDS:
            skipped_protected += 1
            continue
        if _is_already_anonymized(user):
            skipped_already += 1
            continue

        last_active = _last_activity(user)
        # No usable timestamp at all — fail SAFE and keep the account rather
        # than risk deleting a recently-created row with a null timestamp.
        if last_active is None:
            skipped_recent += 1
            logger.warning(
                "Retention: user %s has no activity timestamp; skipping (fail-safe)",
                user.id,
            )
            continue
        if last_active >= cutoff:
            skipped_recent += 1
            continue

        # This account is inactive beyond the window — purge it.
        try:
            purge_user_data(user, commit=True)
            purged += 1
            logger.info(
                "Retention: purged inactive account %s "
                "(last activity %s, %d+ days inactive)",
                user.id,
                last_active.isoformat(),
                inactive_days,
            )
            try:
                from backend.utils.audit import audit_log

                audit_log(
                    "data_retention_purge",
                    user_id=user.id,
                    data={
                        "inactive_days": inactive_days,
                        "last_active": last_active.isoformat(),
                    },
                )
            except Exception:
                pass
        except Exception:
            errors += 1
            db.session.rollback()
            logger.exception(
                "Retention: failed to purge account %s; rolled back", user.id
            )

    summary = {
        "window_days": inactive_days,
        "cutoff": cutoff.isoformat(),
        "scanned": len(users),
        "purged": purged,
        "skipped_recent": skipped_recent,
        "skipped_protected": skipped_protected,
        "skipped_already_anonymized": skipped_already,
        "errors": errors,
    }
    logger.info("Data-retention purge complete: %s", summary)
    return summary


def _resolve_positive_int_env(var_name: str, default: int) -> int:
    """Resolve a positive-int env var, falling back to ``default`` on any
    unset/empty/non-numeric/non-positive value (same policy as
    ``get_retention_inactive_days``)."""
    import os

    raw = os.getenv(var_name)
    if raw is None or not str(raw).strip():
        return default
    try:
        value = int(str(raw).strip())
    except (TypeError, ValueError):
        logger.warning(
            "%s=%r is not an integer; falling back to %d", var_name, raw, default
        )
        return default
    if value <= 0:
        logger.warning(
            "%s=%d is not positive; falling back to %d", var_name, value, default
        )
        return default
    return value


def purge_stale_illustration_cache(stale_days: int | None = None) -> dict:
    """Evict cached illustrations not served within the retention window.

    The ``illustration_cache`` table is a shared, content-addressed cost
    optimisation: the ``cache_key`` is a salted HMAC-SHA256 of the inputs (no
    recoverable child name in the row — F-4 / G-5). What the row *does* hold
    is the generated ``image_data``, which for a custom-avatar story can embed
    the child's likeness — so under the amended COPPA Rule's retention-limit
    requirement (R-6) it must not be retained indefinitely. Rows also carry an
    optional ``user_id`` recording the account that created them, so
    ``purge_user_data`` evicts a deleted account's entries immediately rather
    than waiting on this TTL; this eviction is the backstop for everything
    else (cross-account shared hits, and legacy rows with no ``user_id``).

    This evicts every row whose ``last_accessed_at`` is older than the window,
    so a story re-read within the window stays free (cache hit) while abandoned
    images age out and are re-generated on demand if ever needed again.

    Window: ``ILLUSTRATION_CACHE_RETENTION_DAYS`` (default 365). Degrades
    safely — any DB error is logged and reported, never raised.
    """
    if stale_days is None:
        stale_days = _resolve_positive_int_env(
            "ILLUSTRATION_CACHE_RETENTION_DAYS",
            DEFAULT_ILLUSTRATION_CACHE_RETENTION_DAYS,
        )

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    cutoff = now - timedelta(days=stale_days)

    try:
        from backend.models.illustration_cache import IllustrationCache

        deleted = (
            db.session.query(IllustrationCache)
            .filter(IllustrationCache.last_accessed_at < cutoff)
            .delete(synchronize_session=False)
        )
        db.session.commit()
        summary = {
            "window_days": stale_days,
            "cutoff": cutoff.isoformat(),
            "evicted": deleted,
        }
        logger.info("Illustration-cache eviction complete: %s", summary)
        return summary
    except Exception:
        db.session.rollback()
        logger.exception("Illustration-cache eviction failed; rolled back")
        return {
            "window_days": stale_days,
            "cutoff": cutoff.isoformat(),
            "evicted": 0,
            "error": True,
        }


def purge_stale_tts_audio_cache(
    stale_days: int | None = None, max_rows: int | None = None
) -> dict:
    """Bound the shared TTS narration-audio cache (size + retention guard).

    The ``tts_audio_cache`` table caches synthesized narration MP3s so a
    re-read starts instantly and costs no quota. Rows are large (a base64 MP3
    is ~0.5-2 MB) and the audio speaks the child's name aloud, so under the
    amended COPPA Rule's retention-limit requirement (R-6) it must not be
    retained indefinitely — and the table must not grow unbounded either.

    Two guards, both configurable:
      * TTL — every row whose ``last_accessed_at`` is older than
        ``TTS_AUDIO_CACHE_RETENTION_DAYS`` (default 90) is evicted, so a
        story re-read within the window stays instant while abandoned audio
        ages out.
      * Row cap — if more than ``TTS_AUDIO_CACHE_MAX_ROWS`` (default 20000)
        rows remain, the least-recently-served overflow is evicted.

    ``purge_user_data`` separately evicts a deleted account's rows
    immediately; this eviction is the backstop for everything else. Degrades
    safely — any DB error is logged and reported, never raised.
    """
    if stale_days is None:
        stale_days = _resolve_positive_int_env(
            "TTS_AUDIO_CACHE_RETENTION_DAYS",
            DEFAULT_TTS_AUDIO_CACHE_RETENTION_DAYS,
        )
    if max_rows is None:
        max_rows = _resolve_positive_int_env(
            "TTS_AUDIO_CACHE_MAX_ROWS",
            DEFAULT_TTS_AUDIO_CACHE_MAX_ROWS,
        )

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    cutoff = now - timedelta(days=stale_days)

    try:
        from backend.models.tts_audio_cache import TtsAudioCache

        deleted = (
            db.session.query(TtsAudioCache)
            .filter(TtsAudioCache.last_accessed_at < cutoff)
            .delete(synchronize_session=False)
        )

        # Row-cap guard: evict least-recently-served rows beyond the cap.
        evicted_over_cap = 0
        remaining = db.session.query(TtsAudioCache).count()
        overflow = remaining - max_rows
        if overflow > 0:
            overflow_ids = [
                row_id
                for (row_id,) in db.session.query(TtsAudioCache.id)
                .order_by(TtsAudioCache.last_accessed_at.asc())
                .limit(overflow)
                .all()
            ]
            if overflow_ids:
                evicted_over_cap = (
                    db.session.query(TtsAudioCache)
                    .filter(TtsAudioCache.id.in_(overflow_ids))
                    .delete(synchronize_session=False)
                )

        db.session.commit()
        summary = {
            "window_days": stale_days,
            "cutoff": cutoff.isoformat(),
            "max_rows": max_rows,
            "evicted": deleted,
            "evicted_over_cap": evicted_over_cap,
        }
        logger.info("TTS-audio-cache eviction complete: %s", summary)
        return summary
    except Exception:
        db.session.rollback()
        logger.exception("TTS-audio-cache eviction failed; rolled back")
        return {
            "window_days": stale_days,
            "cutoff": cutoff.isoformat(),
            "max_rows": max_rows,
            "evicted": 0,
            "evicted_over_cap": 0,
            "error": True,
        }


def purge_unconsented_parent_contact(max_pending_days: int | None = None) -> dict:
    """Delete parent contact info from consent flows that never completed.

    Amended COPPA Rule R-2: if a parent does not consent within a reasonable
    time, the operator must delete the parent's contact information. A consent
    round-trip that captured a parent email on an unverified (``verified=False``,
    not withdrawn) ``ConsentRecord`` but was never completed within
    ``max_pending_days`` has its ``parent_email`` nulled and its transient
    verification codes deleted. The (now email-less) record is left in place so
    the fail-safe COPPA gate still sees "no verified consent" for that user.

    Verified records, withdrawn records, records with no captured email, and
    still-recent pending records are all left untouched.

    Window: ``UNCONSENTED_CONTACT_MAX_DAYS`` (default 30). Degrades safely.
    """
    if max_pending_days is None:
        max_pending_days = _resolve_positive_int_env(
            "UNCONSENTED_CONTACT_MAX_DAYS", DEFAULT_UNCONSENTED_CONTACT_MAX_DAYS
        )

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    cutoff = now - timedelta(days=max_pending_days)

    try:
        from backend.models.consent_record import (
            ConsentRecord,
            ConsentVerificationCode,
        )

        stale = ConsentRecord.query.filter(
            ConsentRecord.verified.is_(False),
            ConsentRecord.withdrawn.is_(False),
            ConsentRecord.parent_email.isnot(None),
            ConsentRecord.consent_given_at < cutoff,
        ).all()
        scrubbed = 0
        for record in stale:
            # Drop the transient verification codes for this pending record,
            # then remove the captured contact info.
            ConsentVerificationCode.query.filter_by(consent_record_id=record.id).delete(
                synchronize_session=False
            )
            record.parent_email = None
            scrubbed += 1
        db.session.commit()
        summary = {
            "window_days": max_pending_days,
            "cutoff": cutoff.isoformat(),
            "scrubbed": scrubbed,
        }
        logger.info("Unconsented parent-contact purge complete: %s", summary)
        return summary
    except Exception:
        db.session.rollback()
        logger.exception("Unconsented parent-contact purge failed; rolled back")
        return {
            "window_days": max_pending_days,
            "cutoff": cutoff.isoformat(),
            "scrubbed": 0,
            "error": True,
        }
