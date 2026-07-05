"""Regression tests for erasure completeness in ``purge_user_data``.

Covers the two gaps surfaced by the 2026-06-07 privacy audit:
  * PRIV-04 — ParentHiddenContext + ConsentVerificationCode were never deleted.
  * PRIV-05 — erasure was not propagated to Stripe.

Erasure is the single source of truth for COPPA right-to-erasure and the
retention job, so these are guarded against silent regression.
"""

import hashlib
from datetime import datetime, timedelta, timezone

from backend.database import db
from backend.models import (
    ConsentRecord,
    ConsentVerificationCode,
    ParentHiddenContext,
    User,
)
from backend.services.data_retention import purge_user_data


def _make_user(uid="erase_me", stripe_id="cus_test_erase"):
    user = User(
        id=uid,
        username=f"user_{uid}",
        email=f"{uid}@example.com",
        password_hash="hashed",
        subscription_tier="premium",
        role="user",
        stripe_customer_id=stripe_id,
    )
    db.session.add(user)
    return user


def test_purge_deletes_hidden_context_and_consent_codes(app, mocker):
    """PRIV-04: erasure removes ParentHiddenContext + ConsentVerificationCode."""
    with app.app_context():
        user = _make_user()
        consent = ConsentRecord(
            user_id=user.id, child_age=8, consent_method="email_verified"
        )
        db.session.add(consent)
        db.session.flush()
        code = ConsentVerificationCode(
            user_id=user.id,
            consent_record_id=consent.id,
            code_hash=hashlib.sha256(b"123456").hexdigest(),
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
        )
        phc = ParentHiddenContext(
            user_id=user.id,
            child_profile_id="profile-1",
            trigger="loud noises",
            coping_tool="deep breaths",
            repair_goal="feel safe again",
        )
        db.session.add_all([code, phc])
        db.session.commit()

        # Stripe is best-effort; stub it so the test never touches the network.
        mocker.patch("stripe.Customer.delete")

        purge_user_data(user, commit=True)

        assert ParentHiddenContext.query.filter_by(user_id=user.id).count() == 0
        assert ConsentVerificationCode.query.filter_by(user_id=user.id).count() == 0
        assert ConsentRecord.query.filter_by(user_id=user.id).count() == 0


def test_purge_propagates_erasure_to_stripe(app, mocker):
    """PRIV-05: erasure deletes the Stripe customer and nulls the local id."""
    with app.app_context():
        user = _make_user(uid="erase_stripe", stripe_id="cus_abc123")
        db.session.commit()

        mocker.patch("stripe.api_key", "sk_test_dummy")
        delete_mock = mocker.patch("stripe.Customer.delete")

        purge_user_data(user, commit=True)

        delete_mock.assert_called_once_with("cus_abc123")
        assert user.stripe_customer_id is None


def test_purge_survives_stripe_failure(app, mocker):
    """A Stripe outage must never block the legally-required local erasure."""
    with app.app_context():
        user = _make_user(uid="erase_stripe_fail", stripe_id="cus_fail")
        db.session.commit()

        mocker.patch("stripe.api_key", "sk_test_dummy")
        mocker.patch("stripe.Customer.delete", side_effect=Exception("stripe down"))

        # Must not raise.
        purge_user_data(user, commit=True)

        assert user.password_hash == "DELETED"
        assert user.stripe_customer_id is None


# --- Amended-COPPA fast-follows: G-5 (cache TTL) + G-7 (unconsented contact) ---


def test_purge_stale_illustration_cache_evicts_old_keeps_recent(app):
    """G-5 (R-6): cached illustrations aged past the window are evicted; a
    recently-served one is kept (a re-read within the window stays free)."""
    from backend.models.illustration_cache import IllustrationCache
    from backend.services.data_retention import purge_stale_illustration_cache

    with app.app_context():
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        old = IllustrationCache(
            cache_key="k_old",
            image_data="b64old",
            last_accessed_at=now - timedelta(days=400),
        )
        recent = IllustrationCache(
            cache_key="k_recent",
            image_data="b64recent",
            last_accessed_at=now - timedelta(days=10),
        )
        db.session.add_all([old, recent])
        db.session.commit()

        summary = purge_stale_illustration_cache(stale_days=365)

        assert summary["evicted"] == 1
        assert not summary.get("error")
        keys = {r.cache_key for r in IllustrationCache.query.all()}
        assert keys == {"k_recent"}


def test_purge_unconsented_parent_contact_scrubs_only_stale_pending(app):
    """G-7 (R-2): a stale unverified consent round-trip has its parent email
    deleted and its codes removed; verified and recent-pending rows are left
    untouched."""
    from backend.services.data_retention import purge_unconsented_parent_contact

    with app.app_context():
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        stale_pending = ConsentRecord(
            user_id="u_stale",
            child_age=8,
            consent_method="email_pending",
            parent_email="parent@example.com",
            verified=False,
            consent_given_at=now - timedelta(days=45),
        )
        db.session.add(stale_pending)
        db.session.flush()
        code = ConsentVerificationCode(
            user_id="u_stale",
            consent_record_id=stale_pending.id,
            code_hash=hashlib.sha256(b"999999").hexdigest(),
            expires_at=now - timedelta(days=44),
        )
        recent_pending = ConsentRecord(
            user_id="u_recent",
            child_age=7,
            consent_method="email_pending",
            parent_email="fresh@example.com",
            verified=False,
            consent_given_at=now - timedelta(days=1),
        )
        verified = ConsentRecord(
            user_id="u_ok",
            child_age=9,
            consent_method="email_verified",
            parent_email="kept@example.com",
            verified=True,
            consent_given_at=now - timedelta(days=200),
        )
        db.session.add_all([code, recent_pending, verified])
        db.session.commit()

        summary = purge_unconsented_parent_contact(max_pending_days=30)

        assert summary["scrubbed"] == 1
        assert not summary.get("error")
        assert (
            ConsentRecord.query.filter_by(user_id="u_stale").one().parent_email is None
        )
        assert ConsentVerificationCode.query.filter_by(user_id="u_stale").count() == 0
        # Untouched:
        assert (
            ConsentRecord.query.filter_by(user_id="u_recent").one().parent_email
            == "fresh@example.com"
        )
        assert (
            ConsentRecord.query.filter_by(user_id="u_ok").one().parent_email
            == "kept@example.com"
        )
