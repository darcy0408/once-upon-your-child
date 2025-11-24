import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import os
import stripe
from flask import Blueprint, current_app, jsonify, request
from sqlalchemy.exc import SQLAlchemyError

from backend.database import db
from backend.models.user import User

webhook_routes = Blueprint("webhook_routes", __name__)

_UNSET = object()


@webhook_routes.route("/stripe", methods=["POST"])
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
    except stripe.error.SignatureVerificationError:
        current_app.logger.warning("Stripe webhook signature verification failed")
        return jsonify({"error": "Invalid signature"}), 401

    try:
        _dispatch_event(event)
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception("Database error while handling Stripe webhook")
        return jsonify({"error": "Database error"}), 500

    return jsonify({"status": "success"}), 200


def _dispatch_event(event: Dict[str, Any]) -> None:
    event_type = event.get("type")
    data_object = (event.get("data") or {}).get("object") or {}

    if event_type == "checkout.session.completed":
        _handle_checkout_completed(data_object)
    elif event_type == "customer.subscription.updated":
        _handle_subscription_updated(data_object)
    elif event_type == "customer.subscription.deleted":
        _handle_subscription_deleted(data_object)
    elif event_type == "invoice.payment_failed":
        _handle_payment_failed(data_object)
    else:
        current_app.logger.info("Unhandled Stripe event type: %s", event_type)


def _handle_checkout_completed(session: Dict[str, Any]) -> None:
    user = _find_user(session.get("client_reference_id"))
    if not user:
        current_app.logger.warning("Checkout completed for unknown user")
        return

    subscription_info = session.get("subscription")
    if isinstance(subscription_info, dict):
        status = subscription_info.get("status", "active")
        period_end = _parse_timestamp(subscription_info.get("current_period_end"))
        cancel_at_period_end = bool(subscription_info.get("cancel_at_period_end"))
    else:
        status = "active"
        period_end = None
        cancel_at_period_end = False

    _apply_subscription_updates(
        user,
        tier=_extract_tier(session),
        status=status,
        period_end=period_end,
        cancel_at_period_end=cancel_at_period_end,
    )


def _handle_subscription_updated(subscription: Dict[str, Any]) -> None:
    user = _find_user(_extract_user_id(subscription))
    if not user:
        current_app.logger.warning("Subscription update for unknown user")
        return

    _apply_subscription_updates(
        user,
        tier=_extract_tier(subscription),
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
    return User.query.get(user_id)


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
