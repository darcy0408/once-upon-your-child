"""Gift-entitlement expiry sweep.

Gift codes grant a time-boxed entitlement (models/gift_code.py) by calling
the same `apply_entitlement()` single-writer path Stripe/IAP use, but unlike
Stripe/IAP a gift has no recurring store object to push a "this lapsed"
webhook/notification at the real expiry date. `require_premium`
(routes/subscription_routes.py) gates purely on `User.subscription_tier` —
nothing in the codebase actively re-checks `current_period_end` — so without
an active sweep a redeemed gift would grant premium FOREVER.

This task runs once daily (see celery_config.py beat_schedule) and downgrades
back to free ONLY users reachable through a `redeemed` GiftCode row whose
grantee's `current_period_end` (the SAME column every channel writes via
apply_entitlement) has passed. Scoping the query through GiftCode — rather
than "any paid user past current_period_end" — means a user who later buys or
upgrades to a real Stripe/IAP subscription is safe: apply_entitlement
overwrites current_period_end with the new (future) date, so this sweep's
`< now` filter stops matching them. It can never touch a real Stripe/IAP
subscriber's entitlement, including one lagging on a webhook, because that
user is not reachable through a GiftCode join at all.
"""

import os
from datetime import datetime, timezone

from celery.utils.log import get_task_logger

# Prevent default app initialization during import so we control app context.
os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")

from backend.celery_config import celery

logger = get_task_logger(__name__)

# Lazy Flask app initialization to avoid circular imports (mirrors story_tasks
# / retention_tasks).
_flask_app = None


def get_flask_app():
    """Lazy initialization of the Flask app to avoid circular imports."""
    global _flask_app
    if _flask_app is None:
        from backend.app import create_app  # lazy import breaks circular dep

        _config_name = os.getenv("FLASK_CONFIG") or "dev"
        if _config_name not in {"dev", "prod", "production", "testing"}:
            _config_name = "dev"
        _flask_app = create_app(_config_name)
    return _flask_app


@celery.task(name="backend.tasks.subscription_tasks.expire_gift_entitlements_task")
def expire_gift_entitlements_task():
    """Celery entry point for the daily gift-entitlement expiry sweep.

    Safe to run repeatedly: a user already downgraded to free simply doesn't
    match the `subscription_tier.in_(PAID_TIERS)` filter on the next run.
    Returns a summary dict (also visible in the Celery result backend).
    """
    from backend.database import db
    from backend.models.gift_code import STATUS_REDEEMED, GiftCode
    from backend.models.user import User
    from backend.services.entitlement_service import (
        FREE_TIER,
        PAID_TIERS,
        apply_entitlement,
    )

    app = get_flask_app()
    with app.app_context():
        logger.info("Gift entitlement expiry sweep triggered by Celery beat")
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        expired = (
            db.session.query(GiftCode, User)
            .join(User, GiftCode.redeemed_by_user_id == User.id)
            .filter(
                GiftCode.status == STATUS_REDEEMED,
                User.subscription_tier.in_(PAID_TIERS),
                User.current_period_end.isnot(None),
                User.current_period_end < now,
            )
            .all()
        )

        downgraded = 0
        for _gift, user in expired:
            apply_entitlement(
                user,
                tier=FREE_TIER,
                status="expired",
                source="gift_expiry",
                commit=False,
            )
            downgraded += 1

        if downgraded:
            db.session.commit()

        logger.info("Gift entitlement expiry sweep finished: downgraded=%d", downgraded)
        return {"downgraded": downgraded}
