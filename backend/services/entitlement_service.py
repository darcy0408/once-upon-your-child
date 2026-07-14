"""Single entitlement source of truth — STORE-1 (MT-143).

The STORE-1 brief (step 4) requires entitlement to be "one function, three
callers": Stripe webhooks, Apple notifications, and Google notifications all
resolve to a tier through the SAME code path so the three channels can never
drift apart.

`apply_entitlement()` is that one function. Given a user and a resolved
{tier, status, period_end} it writes `User.subscription_tier` /
`subscription_status` / `current_period_end` — the authoritative columns the
server-side `require_premium` gate reads.

Channel-specific code (verifying a Stripe price ID, an Apple receipt, a Google
token) lives in each channel's route module; this module only owns the final,
channel-agnostic write.

All three channels are live on this path (STORE-1 phase 2 complete):
  - The IAP routes (`routes/iap_routes.py`) — Apple/Google verify + S2S
    notification handlers.
  - The Stripe webhook (`routes/webhook_handler.py`) —
    `_apply_subscription_updates()` keeps the Stripe-specific stale-event
    guard and per-user cursor, then delegates the column writes here.
  - Gift redemption (`routes/gift_routes.py`) and the gift expiry sweep
    (`tasks/subscription_tasks.py`).
"""

import logging
from datetime import datetime, timezone
from typing import Optional

try:
    from ..database import db
    from ..models.user import User
except ImportError:  # pragma: no cover - flat-module layout
    from database import db
    from models.user import User

logger = logging.getLogger("entitlement_service")

# Lowest / unpaid tier — the fail-closed fallback.
FREE_TIER = "free"

# Tiers that grant a paid entitlement. Mirrors PREMIUM_TIERS in
# routes/subscription_routes.py (kept in sync intentionally; 'byok' is a
# server-side flag, not a purchasable tier, so it is not listed here).
PAID_TIERS = frozenset({"premium", "family"})

# Store statuses that should still grant access, mapped onto the Story Weaver
# `subscription_status` vocabulary the client already understands.
#   active / trialing / past_due  -> access granted (see SubscriptionSyncService)
#   canceled / expired            -> access revoked
_ACCESS_STATUSES = frozenset({"active", "trialing", "past_due", "grace_period"})


def status_grants_access(tier: Optional[str], status: Optional[str]) -> bool:
    """True if (tier, status) should currently unlock paid features."""
    norm_tier = (tier or "").strip().lower()
    norm_status = (status or "").strip().lower()
    if norm_tier not in PAID_TIERS:
        return False
    return norm_status in _ACCESS_STATUSES


def apply_entitlement(
    user: User,
    *,
    tier: Optional[str],
    status: Optional[str],
    period_end: Optional[datetime] = None,
    cancel_at_period_end: Optional[bool] = None,
    source: str = "unknown",
    commit: bool = True,
) -> None:
    """Write a resolved entitlement onto *user*.

    This is the single channel-agnostic entitlement write. Callers (Stripe /
    Apple / Google) are responsible for VERIFYING the purchase and resolving
    the tier before calling this; this function trusts its arguments and only
    persists them.

    Args:
        user: the User row to update.
        tier: resolved tier ('free' | 'premium' | 'family'). Unknown values
            fail closed to 'free'. None leaves the current tier untouched —
            for status-only channel events (e.g. Stripe
            invoice.payment_failed) that carry no tier information; this also
            keeps non-store tiers (a legacy 'byok' row) from being clobbered
            by such events.
        status: subscription status ('active' | 'trialing' | 'past_due' |
            'canceled' | 'expired' | ...). None/empty leaves it untouched.
        period_end: paid-through / renewal datetime (UTC), if known. None
            leaves it untouched.
        cancel_at_period_end: whether the sub is set to lapse at period end.
            None leaves it untouched.
        source: free-text channel label for logging ('stripe' | 'apple' |
            'google') — diagnostic only.
        commit: commit the session here. Pass False to batch with other writes.
    """
    if tier is not None:
        norm_tier = tier.strip().lower()
        if norm_tier not in PAID_TIERS and norm_tier != FREE_TIER:
            logger.error(
                "apply_entitlement: unknown tier '%s' from source '%s' for user "
                "%s — failing closed to '%s'",
                tier,
                source,
                getattr(user, "id", "?"),
                FREE_TIER,
            )
            norm_tier = FREE_TIER
        user.subscription_tier = norm_tier
    if status:
        user.subscription_status = status.strip().lower()
    if period_end is not None:
        # Store naive-UTC to match the existing Stripe webhook convention.
        if period_end.tzinfo is not None:
            period_end = period_end.astimezone(timezone.utc).replace(tzinfo=None)
        user.current_period_end = period_end
    if cancel_at_period_end is not None:
        user.cancel_at_period_end = bool(cancel_at_period_end)

    db.session.add(user)
    if commit:
        db.session.commit()

    logger.info(
        "Entitlement applied for user %s via %s: tier=%s status=%s",
        getattr(user, "id", "?"),
        source,
        user.subscription_tier,
        user.subscription_status,
    )
