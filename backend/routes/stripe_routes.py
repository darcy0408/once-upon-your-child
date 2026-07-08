import logging
import os
import time

import stripe
from dotenv import load_dotenv
from flask import Blueprint, jsonify, request

from ..middleware.auth import require_auth

load_dotenv()

stripe_routes = Blueprint("stripe_routes", __name__)
logger = logging.getLogger("stripe_routes")

# Canonical production frontend (Cloudflare Pages via the custom domain) used as
# the Stripe checkout / billing-portal redirect target. Env-overridable so a
# domain change needs no code edit. Previously hard-coded to the now-decommissioned
# grand-light Railway frontend.
FRONTEND_URL = os.getenv("FRONTEND_URL", "https://onceuponyourchild.app").rstrip("/")

# Stripe API key will be set by init_stripe_api
# stripe.api_key = os.getenv('STRIPE_API_KEY') # REMOVED


def init_stripe_api(app):
    """Initializes Stripe API key using app config."""
    stripe.api_key = app.config.get("STRIPE_API_KEY")
    if not stripe.api_key:
        logger.warning(
            "STRIPE_API_KEY not set in app config - Stripe routes may not function."
        )
    else:
        logger.info("✓ Stripe API configured via init_stripe_api")


_PLACEHOLDER_PRICE_IDS = {
    "price_PLACEHOLDER_PREMIUM",
    "price_PLACEHOLDER_FAMILY",
    "price_PLACEHOLDER_PREMIUM_ANNUAL",
}


def get_price_ids():
    """Get Stripe Price IDs from environment variables (loaded dynamically).

    If a real price ID isn't set in the environment, return None for that tier
    so the checkout route returns a clean 400 instead of silently asking Stripe
    to charge for a non-existent product.

    "premium_annual" is not a subscription tier — it's the annual-billing
    variant of the premium tier's price, keyed separately here so
    `/create-checkout-session` can resolve it without a second price map.
    """
    raw = {
        "premium": os.getenv("STRIPE_PRICE_ID_PREMIUM", ""),
        "family": os.getenv("STRIPE_PRICE_ID_FAMILY", ""),
        "premium_annual": os.getenv("STRIPE_PRICE_ID_PREMIUM_ANNUAL", ""),
    }
    return {
        tier: pid if pid and pid not in _PLACEHOLDER_PRICE_IDS else None
        for tier, pid in raw.items()
    }


def get_trial_days():
    """Return trial period in days, or None to disable trial."""
    raw = os.getenv("STRIPE_TRIAL_DAYS", "14")
    try:
        days = int(raw)
        return days if days > 0 else None
    except ValueError:
        return None


@stripe_routes.route("/create-checkout-session", methods=["POST"])
@require_auth
def create_checkout_session():
    data = request.get_json(silent=True) or {}
    tier = data.get("tier")
    billing_period = data.get("billing_period", "monthly")
    # Always use the authenticated user ID for checkout
    user_id = request.current_user.id

    PRICE_IDS = get_price_ids()

    if not tier or tier not in PRICE_IDS:
        return jsonify({"error": "Invalid subscription tier"}), 400
    if billing_period not in ("monthly", "annual"):
        return jsonify({"error": "Invalid billing period"}), 400
    if billing_period == "annual" and tier != "premium":
        return (
            jsonify({"error": "Annual billing is only available for premium"}),
            400,
        )

    # Annual is a price-ID variant of premium, not its own tier — resolve to
    # the "premium_annual" key so the tier the user is entitled to (still
    # "premium") stays separate from which Stripe Price gets billed.
    price_key = "premium_annual" if billing_period == "annual" else tier
    logger.info(
        f"Creating checkout for tier '{tier}' ({billing_period}) with price_id: "
        f"{PRICE_IDS.get(price_key)}"
    )
    if PRICE_IDS[price_key] is None:
        logger.error(
            f"STRIPE_PRICE_ID_{price_key.upper()} env var not configured — refusing checkout"
        )
        return jsonify({"error": "Subscription tier temporarily unavailable"}), 503

    try:
        trial_days = get_trial_days()
        user = request.current_user
        session_params = dict(
            payment_method_types=["card"],
            line_items=[{"price": PRICE_IDS[price_key], "quantity": 1}],
            mode="subscription",
            success_url=f"{FRONTEND_URL}/#/subscription-success",
            cancel_url=f"{FRONTEND_URL}/#/subscription-canceled",
            client_reference_id=user_id,
            customer_email=user.email,
            metadata={
                "user_id": user_id,
                "subscription_tier": tier,
                "billing_period": billing_period,
            },
            subscription_data={
                "metadata": {
                    "user_id": user_id,
                    "subscription_tier": tier,
                    "billing_period": billing_period,
                }
            },
        )
        if user.stripe_customer_id:
            session_params["customer"] = user.stripe_customer_id
        else:
            session_params["customer_creation"] = "always"
        if trial_days:
            session_params["subscription_data"]["trial_period_days"] = trial_days
            logger.info(f"Trial enabled: {trial_days} days for tier '{tier}'")

        # Idempotency key: a client retry within the same coarse 5-minute
        # bucket dedupes to the same Stripe checkout session, while a
        # genuinely new checkout later (next bucket) still creates one.
        # billing_period is included so switching Monthly<->Yearly within the
        # same bucket creates a new session instead of deduping to the other.
        idempotency_key = (
            f"checkout:{user_id}:{tier}:{billing_period}:{int(time.time() // 300)}"
        )
        checkout_session = stripe.checkout.Session.create(
            **session_params, idempotency_key=idempotency_key
        )
        return jsonify(
            {"id": checkout_session.id, "checkout_url": checkout_session.url}
        )
    except Exception:
        logger.exception("Failed to create checkout session")
        return (
            jsonify(error="Failed to create checkout session. Please try again."),
            500,
        )


@stripe_routes.route("/create-portal-session", methods=["POST"])
@require_auth
def create_portal_session():
    """
    Create a Stripe Billing Portal session so the user can manage their
    subscription (update payment method, cancel, view invoices).
    """
    user = request.current_user

    if not user.stripe_customer_id:
        return jsonify({"error": "No billing account found for this user"}), 404

    try:
        portal_session = stripe.billing_portal.Session.create(
            customer=user.stripe_customer_id,
            return_url=f"{FRONTEND_URL}/#/settings",
        )
        return jsonify({"portal_url": portal_session.url})
    except Exception:
        logger.exception("Failed to create portal session")
        return (
            jsonify({"error": "Failed to open billing portal. Please try again."}),
            500,
        )


@stripe_routes.route("/subscription-status/<user_id>", methods=["GET"])
@require_auth
def get_subscription_status(user_id):
    """
    Get the current subscription status for a user.
    Returns subscription tier, status, and renewal date.
    """
    try:
        # User already validated by @require_auth decorator
        user = request.current_user

        # Get subscription from Stripe if customer_id exists
        if user.stripe_customer_id:
            subscriptions = stripe.Subscription.list(
                customer=user.stripe_customer_id, status="active", limit=1
            )

            if subscriptions.data:
                sub = subscriptions.data[0]
                return jsonify(
                    {
                        "status": "active",
                        "tier": user.subscription_tier or "free",
                        "current_period_end": sub.current_period_end,
                        "cancel_at_period_end": sub.cancel_at_period_end,
                    }
                )

        # No active subscription
        return jsonify({"status": "inactive", "tier": "free"})

    except Exception:
        logger.exception("Failed to get subscription status")
        return jsonify({"error": "Failed to retrieve subscription status"}), 500


@stripe_routes.route("/cancel-subscription", methods=["POST"])
@require_auth
def cancel_subscription():
    """
    Cancel the authenticated user's active subscription at period end.
    The user keeps access until current_period_end, then is downgraded to free.
    """
    user = request.current_user

    if not user.stripe_customer_id:
        return jsonify({"error": "No active subscription found"}), 404

    try:
        subscriptions = stripe.Subscription.list(
            customer=user.stripe_customer_id,
            status="active",
            limit=1,
        )
        if not subscriptions.data:
            return jsonify({"error": "No active subscription found"}), 404

        sub = subscriptions.data[0]
        updated = stripe.Subscription.modify(sub.id, cancel_at_period_end=True)

        user.cancel_at_period_end = True
        from ..database import db

        db.session.add(user)
        db.session.commit()

        return jsonify(
            {
                "status": "canceled",
                "cancel_at_period_end": True,
                "current_period_end": updated.current_period_end,
            }
        )
    except Exception:
        logger.exception("Failed to cancel subscription")
        return (
            jsonify({"error": "Failed to cancel subscription. Please try again."}),
            500,
        )
