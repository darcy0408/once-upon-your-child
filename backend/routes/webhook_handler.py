import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import os
import stripe
from flask import Blueprint, current_app, jsonify, request
from sqlalchemy.exc import SQLAlchemyError

from backend.database import db
from backend.models.user import User
from backend.routes.stripe_routes import get_price_ids

webhook_routes = Blueprint("webhook_routes", __name__)

_UNSET = object()

# Lowest / unpaid tier. Used as the fail-closed fallback when a subscription's
# price ID cannot be mapped to a known paid tier.
_FREE_TIER = "free"


def _price_id_to_tier_map() -> Dict[str, str]:
    """Server-side authoritative {price_id: tier} map.

    Built by inverting the {tier: price_id} table that `stripe_routes` derives
    from STRIPE_PRICE_ID_PREMIUM / STRIPE_PRICE_ID_FAMILY. Reusing
    `get_price_ids()` keeps a single source of truth for the price config and
    automatically skips unset / placeholder price IDs (they come back as None).
    """
    return {
        price_id: tier
        for tier, price_id in get_price_ids().items()
        if price_id
    }


def _resolve_subscription_object(subscription: Any) -> Optional[Dict[str, Any]]:
    """Return an expanded subscription dict.

    Stripe events may carry `subscription` either as a fully expanded object or
    as a bare ID string. When it is a bare ID (or otherwise lacks line items),
    retrieve the authoritative object from the Stripe API so we can read the
    price the customer is actually being charged for.
    """
    if isinstance(subscription, dict):
        items = (subscription.get("items") or {}).get("data")
        if items:
            return subscription
        sub_id = subscription.get("id")
    elif isinstance(subscription, str):
        sub_id = subscription
    else:
        return None

    if not sub_id:
        return None
    try:
        retrieved = stripe.Subscription.retrieve(sub_id)
        if hasattr(retrieved, "to_dict"):
            return retrieved.to_dict()
        return retrieved
    except stripe.StripeError:
        current_app.logger.exception(
            "Failed to retrieve Stripe subscription %s for tier resolution", sub_id
        )
        return None


def _tier_from_subscription(
    subscription: Any, *, metadata_source: Optional[Dict[str, Any]] = None
) -> str:
    """Resolve the subscription tier from the ACTUAL charged price ID.

    Authoritative source is `subscription['items']['data'][0]['price']['id']`
    mapped through the server-side {price_id: tier} table. The client-supplied
    `metadata.subscription_tier` is treated as a fallback hint ONLY when the
    price ID is genuinely unresolvable. If a resolved price ID is unknown, we
    fail closed to the free tier rather than trusting the client label.
    """
    sub_obj = _resolve_subscription_object(subscription)

    price_id: Optional[str] = None
    if sub_obj:
        try:
            items = (sub_obj.get("items") or {}).get("data") or []
            if items:
                price = items[0].get("price") or {}
                price_id = price.get("id")
        except (AttributeError, IndexError, TypeError):
            price_id = None

    if price_id:
        price_map = _price_id_to_tier_map()
        tier = price_map.get(price_id)
        if tier:
            return tier
        current_app.logger.error(
            "Stripe subscription price ID %s is not in the authoritative "
            "price->tier map; failing closed to '%s'",
            price_id,
            _FREE_TIER,
        )
        return _FREE_TIER

    # Price ID genuinely unresolvable — fall back to the metadata hint, but warn.
    hint = _extract_tier(metadata_source) if metadata_source is not None else None
    if hint:
        current_app.logger.warning(
            "Could not resolve Stripe price ID for subscription; falling back "
            "to client-supplied metadata tier hint '%s'",
            hint,
        )
        return hint

    current_app.logger.error(
        "Could not resolve Stripe price ID and no metadata tier hint available; "
        "failing closed to '%s'",
        _FREE_TIER,
    )
    return _FREE_TIER


@webhook_routes.route("/webhooks/stripe", methods=["POST"])
@webhook_routes.route("/stripe/webhook", methods=["POST"])
def handle_webhook():
    payload = request.data
    sig_header = request.headers.get("Stripe-Signature", "")
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET", "")
    if not webhook_secret:
        current_app.logger.error("STRIPE_WEBHOOK_SECRET not configured")
        return jsonify({'error': 'Webhook not configured'}), 500

    try:
        event = stripe.Webhook.construct_event(
            payload=payload,
            sig_header=sig_header,
            secret=webhook_secret,
        )
    except ValueError:
        current_app.logger.warning("Stripe webhook payload could not be parsed")
        return jsonify({"error": "Invalid payload"}), 400
    except stripe.SignatureVerificationError:
        current_app.logger.warning("Stripe webhook signature verification failed")
        return jsonify({"error": "Invalid signature"}), 401

    try:
        _dispatch_event(event)
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception("Database error while handling Stripe webhook")
        return jsonify({"error": "Database error"}), 500

    return jsonify({"status": "success"}), 200


def _dispatch_event(event: Any) -> None:
    if hasattr(event, "to_dict"):
        event = event.to_dict()
    event_type = event.get("type")
    data_object = (event.get("data") or {}).get("object") or {}

    if event_type == "checkout.session.completed":
        _handle_checkout_completed(data_object)
    elif event_type == "customer.subscription.created":
        # Non-checkout creation paths (Stripe-side recovery, manual creation in
        # dashboard, etc.). Same downstream sync as `subscription.updated`.
        _handle_subscription_updated(data_object)
    elif event_type == "customer.subscription.updated":
        _handle_subscription_updated(data_object)
    elif event_type == "customer.subscription.deleted":
        _handle_subscription_deleted(data_object)
    elif event_type == "invoice.payment_succeeded":
        # Renewal confirmation — recurring charge cleared. Refresh tier so a
        # previously past_due account is restored to active.
        _handle_payment_succeeded(data_object)
    elif event_type == "invoice.payment_failed":
        _handle_payment_failed(data_object)
    else:
        current_app.logger.info("Unhandled Stripe event type: %s", event_type)


def _handle_checkout_completed(session: Dict[str, Any]) -> None:
    user = _find_user(_extract_user_id(session))
    if not user:
        current_app.logger.warning("Checkout completed for unknown user")
        return

    customer_id = session.get("customer")
    if customer_id and not user.stripe_customer_id:
        user.stripe_customer_id = customer_id

    subscription_info = session.get("subscription")
    if isinstance(subscription_info, dict):
        status = subscription_info.get("status", "active")
        period_end = _parse_timestamp(subscription_info.get("current_period_end"))
        cancel_at_period_end = bool(subscription_info.get("cancel_at_period_end"))
    else:
        status = "active"
        period_end = None
        cancel_at_period_end = False

    # Resolve tier from the actual charged price ID, not the client metadata.
    # `subscription_info` may be a bare ID string or an expanded object; the
    # checkout session itself carries the metadata used only as a last-resort
    # fallback hint.
    tier = _tier_from_subscription(subscription_info, metadata_source=session)

    _apply_subscription_updates(
        user,
        tier=tier,
        status=status,
        period_end=period_end,
        cancel_at_period_end=cancel_at_period_end,
    )


def _handle_subscription_updated(subscription: Dict[str, Any]) -> None:
    user = _find_user(_extract_user_id(subscription))
    if not user:
        current_app.logger.warning("Subscription update for unknown user")
        return

    # The event's data.object IS the subscription. Resolve tier from its actual
    # price ID (re-fetched if line items aren't present) rather than trusting
    # the client-supplied metadata label.
    tier = _tier_from_subscription(subscription, metadata_source=subscription)

    _apply_subscription_updates(
        user,
        tier=tier,
        status=subscription.get("status"),
        period_end=_parse_timestamp(subscription.get("current_period_end")),
        cancel_at_period_end=bool(subscription.get("cancel_at_period_end")),
    )


def _handle_subscription_deleted(subscription: Dict[str, Any]) -> None:
    user = _find_user(_extract_user_id(subscription))
    if not user:
        current_app.logger.warning("Subscription deleted for unknown user")
        return

    _apply_subscription_updates(
        user,
        status="canceled",
        period_end=_parse_timestamp(subscription.get("current_period_end")),
        cancel_at_period_end=True,
    )


def _handle_payment_failed(invoice: Dict[str, Any]) -> None:
    user = _find_user(_extract_user_id(invoice))
    if not user:
        current_app.logger.warning("Payment failed for unknown user")
        return

    _apply_subscription_updates(
        user,
        status="past_due",
    )


def _handle_payment_succeeded(invoice: Dict[str, Any]) -> None:
    user = _find_user(_extract_user_id(invoice))
    if not user:
        current_app.logger.warning("Payment succeeded for unknown user")
        return

    _apply_subscription_updates(
        user,
        status="active",
        period_end=_parse_timestamp(invoice.get("period_end")),
    )


def _apply_subscription_updates(
    user: User,
    *,
    tier: Any = _UNSET,
    status: Any = _UNSET,
    period_end: Any = _UNSET,
    cancel_at_period_end: Any = _UNSET,
) -> None:
    if tier is not _UNSET and tier:
        user.subscription_tier = tier
    if status is not _UNSET and status:
        user.subscription_status = status
    if period_end is not _UNSET:
        user.current_period_end = period_end
    if cancel_at_period_end is not _UNSET:
        user.cancel_at_period_end = bool(cancel_at_period_end)

    db.session.add(user)
    db.session.commit()


def _find_user(user_id: Optional[str]) -> Optional[User]:
    if not user_id:
        return None
    return db.session.get(User, user_id)


def _extract_user_id(source: Dict[str, Any]) -> Optional[str]:
    metadata = source.get("metadata")
    if isinstance(metadata, dict):
        user_id = metadata.get("user_id")
        if user_id:
            return user_id
    if "client_reference_id" in source:
        return source.get("client_reference_id")
    return source.get("user_id")


def _extract_tier(source: Dict[str, Any]) -> Optional[str]:
    metadata = source.get("metadata")
    if isinstance(metadata, dict):
        tier = metadata.get("subscription_tier") or metadata.get("tier")
        if tier:
            return tier
    return source.get("subscription_tier")


def _parse_timestamp(value: Any) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc)
    except (TypeError, ValueError):
        current_app.logger.warning("Invalid timestamp value for Stripe webhook: %s", value)
        return None
