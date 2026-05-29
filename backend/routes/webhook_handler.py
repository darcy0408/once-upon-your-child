import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import os
import stripe
from flask import Blueprint, current_app, jsonify, request
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from backend.database import db
from backend.models.user import User

# Importing the dedup models at module level registers them with SQLAlchemy
# before app.py runs db.create_all(), so the tables are auto-created on a
# fresh database with no manual migration step (M-3).
from backend.models.stripe_event import StripeWebhookEvent, StripeSubscriptionCursor
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
    return {price_id: tier for tier, price_id in get_price_ids().items() if price_id}


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


def _event_id(event: Any) -> Optional[str]:
    if hasattr(event, "to_dict"):
        event = event.to_dict()
    if isinstance(event, dict):
        return event.get("id")
    return getattr(event, "id", None)


def _event_created(event: Any) -> Optional[datetime]:
    if hasattr(event, "to_dict"):
        event = event.to_dict()
    created = (
        event.get("created")
        if isinstance(event, dict)
        else getattr(event, "created", None)
    )
    return _parse_timestamp(created)


def _already_processed(event_id: str) -> bool:
    """Return True if this Stripe event.id has already been recorded (M-3).

    On any DB error here we fail OPEN (treat as not-yet-seen and continue):
    a dedup-store outage must not drop a legitimate payment event. The unique
    constraint in `_record_event` is the hard guarantee against double-apply.
    """
    try:
        return (
            db.session.query(StripeWebhookEvent.id).filter_by(event_id=event_id).first()
            is not None
        )
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception(
            "Stripe webhook dedup lookup failed for %s — proceeding", event_id
        )
        return False


def _record_event(
    event_id: str, event_type: Optional[str], event_created: Optional[datetime]
) -> bool:
    """Persist the event.id. Returns False if it was already present (M-3).

    The unique constraint on `event_id` is the authoritative replay guard: if
    two retries race past `_already_processed`, the second INSERT raises an
    IntegrityError and we treat the event as a duplicate.
    """
    try:
        db.session.add(
            StripeWebhookEvent(
                event_id=event_id,
                event_type=event_type,
                event_created=event_created,
            )
        )
        db.session.commit()
        return True
    except IntegrityError:
        db.session.rollback()
        current_app.logger.info(
            "Stripe webhook event %s already recorded (race) — skipping", event_id
        )
        return False


def _is_stale_event(user_id: Optional[str], event_created: Optional[datetime]) -> bool:
    """Return True if *event_created* is older than the last applied state change.

    Guards against out-of-order / replayed delivery: a stale
    `invoice.payment_succeeded` arriving after a real `invoice.payment_failed`
    must not flip a delinquent account back to active. Events with no
    timestamp, or for users with no cursor yet, are treated as fresh.
    """
    if not user_id or event_created is None:
        return False
    try:
        cursor = db.session.get(StripeSubscriptionCursor, user_id)
    except SQLAlchemyError:
        db.session.rollback()
        return False
    if cursor is None or cursor.last_event_created is None:
        return False
    last = cursor.last_event_created
    incoming = event_created
    # Compare naive-UTC to naive-UTC (cursor stores naive UTC).
    if last.tzinfo is not None:
        last = last.astimezone(timezone.utc).replace(tzinfo=None)
    if incoming.tzinfo is not None:
        incoming = incoming.astimezone(timezone.utc).replace(tzinfo=None)
    return incoming < last


def _advance_cursor(
    user_id: Optional[str], event_created: Optional[datetime], event_id: Optional[str]
) -> None:
    """Move the per-user high-water mark forward after a state change (M-3)."""
    if not user_id or event_created is None:
        return
    incoming = event_created
    if incoming.tzinfo is not None:
        incoming = incoming.astimezone(timezone.utc).replace(tzinfo=None)
    cursor = db.session.get(StripeSubscriptionCursor, user_id)
    if cursor is None:
        cursor = StripeSubscriptionCursor(user_id=user_id)
        db.session.add(cursor)
    if cursor.last_event_created is None or incoming >= (
        cursor.last_event_created.replace(tzinfo=None)
        if cursor.last_event_created.tzinfo is not None
        else cursor.last_event_created
    ):
        cursor.last_event_created = incoming
        cursor.last_event_id = event_id


@webhook_routes.route("/webhooks/stripe", methods=["POST"])
@webhook_routes.route("/stripe/webhook", methods=["POST"])
def handle_webhook():
    payload = request.data
    sig_header = request.headers.get("Stripe-Signature", "")

    # --- Signature verification with dual-secret rotation support (S2) -------
    # We verify the payload against TWO candidate signing secrets:
    #   * STRIPE_WEBHOOK_SECRET      — the primary (current) secret.
    #   * STRIPE_WEBHOOK_SECRET_OLD  — an optional secondary secret.
    # The secondary secret exists purely to make secret rotation zero-downtime:
    # while a rotation is in progress, in-flight webhooks may have been signed
    # with either the old or the new secret. Accepting both means no event is
    # rejected with a 401 during the rotation window. When no rotation is
    # underway, STRIPE_WEBHOOK_SECRET_OLD is simply unset and this behaves
    # exactly like single-secret verification.
    # See docs/RUNBOOK_STRIPE_WEBHOOK_SECRET_ROTATION.md for the procedure.
    candidate_secrets = [
        secret
        for secret in (
            os.getenv("STRIPE_WEBHOOK_SECRET", ""),
            os.getenv("STRIPE_WEBHOOK_SECRET_OLD", ""),
        )
        if secret
    ]
    if not candidate_secrets:
        current_app.logger.error("STRIPE_WEBHOOK_SECRET not configured")
        return jsonify({"error": "Webhook not configured"}), 500

    event = None
    for secret in candidate_secrets:
        try:
            event = stripe.Webhook.construct_event(
                payload=payload,
                sig_header=sig_header,
                secret=secret,
            )
            break
        except ValueError:
            # A malformed payload is bad regardless of which secret we try, so
            # short-circuit immediately rather than falling through.
            current_app.logger.warning("Stripe webhook payload could not be parsed")
            return jsonify({"error": "Invalid payload"}), 400
        except stripe.SignatureVerificationError:
            # This secret didn't verify the signature — fall through and try the
            # next candidate (supports the old/new overlap during a rotation).
            continue

    if event is None:
        # Every candidate secret raised SignatureVerificationError.
        current_app.logger.warning("Stripe webhook signature verification failed")
        return jsonify({"error": "Invalid signature"}), 401

    # --- Idempotency / replay-dedup (M-3) -----------------------------------
    # Stripe delivers at-least-once; within the 5-min signature window a
    # captured payload can also be replayed. Short-circuit (200, no-op) on a
    # duplicate event.id so handlers run exactly once per event.
    event_id = _event_id(event)
    if event_id and _already_processed(event_id):
        current_app.logger.info(
            "Stripe webhook %s already processed — skipping (idempotent)", event_id
        )
        return jsonify({"status": "duplicate"}), 200

    try:
        _dispatch_event(event)
    except SQLAlchemyError:
        db.session.rollback()
        current_app.logger.exception("Database error while handling Stripe webhook")
        # Do NOT record the event — Stripe will retry and we want it reprocessed.
        return jsonify({"error": "Database error"}), 500

    # Record the event AFTER successful processing so a mid-handler failure
    # leaves it eligible for Stripe's retry.
    if event_id:
        _record_event(event_id, _event_type(event), _event_created(event))

    return jsonify({"status": "success"}), 200


def _event_type(event: Any) -> Optional[str]:
    if hasattr(event, "to_dict"):
        event = event.to_dict()
    if isinstance(event, dict):
        return event.get("type")
    return getattr(event, "type", None)


def _dispatch_event(event: Any) -> None:
    if hasattr(event, "to_dict"):
        event = event.to_dict()
    event_type = event.get("type")
    data_object = (event.get("data") or {}).get("object") or {}
    # Stripe event.created — used by state-changing handlers to reject
    # out-of-order / replayed deliveries (M-3).
    event_ts = _parse_timestamp(event.get("created"))
    event_id = event.get("id")

    if event_type == "checkout.session.completed":
        _handle_checkout_completed(data_object, event_ts, event_id)
    elif event_type == "customer.subscription.created":
        # Non-checkout creation paths (Stripe-side recovery, manual creation in
        # dashboard, etc.). Same downstream sync as `subscription.updated`.
        _handle_subscription_updated(data_object, event_ts, event_id)
    elif event_type == "customer.subscription.updated":
        _handle_subscription_updated(data_object, event_ts, event_id)
    elif event_type == "customer.subscription.deleted":
        _handle_subscription_deleted(data_object, event_ts, event_id)
    elif event_type == "invoice.payment_succeeded":
        # Renewal confirmation — recurring charge cleared. Refresh tier so a
        # previously past_due account is restored to active.
        _handle_payment_succeeded(data_object, event_ts, event_id)
    elif event_type == "invoice.payment_failed":
        _handle_payment_failed(data_object, event_ts, event_id)
    else:
        current_app.logger.info("Unhandled Stripe event type: %s", event_type)


def _handle_checkout_completed(
    session: Dict[str, Any],
    event_ts: Optional[datetime] = None,
    event_id: Optional[str] = None,
) -> None:
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
        event_ts=event_ts,
        event_id=event_id,
    )


def _handle_subscription_updated(
    subscription: Dict[str, Any],
    event_ts: Optional[datetime] = None,
    event_id: Optional[str] = None,
) -> None:
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
        event_ts=event_ts,
        event_id=event_id,
    )


def _handle_subscription_deleted(
    subscription: Dict[str, Any],
    event_ts: Optional[datetime] = None,
    event_id: Optional[str] = None,
) -> None:
    user = _find_user(_extract_user_id(subscription))
    if not user:
        current_app.logger.warning("Subscription deleted for unknown user")
        return

    _apply_subscription_updates(
        user,
        status="canceled",
        period_end=_parse_timestamp(subscription.get("current_period_end")),
        cancel_at_period_end=True,
        event_ts=event_ts,
        event_id=event_id,
    )


def _handle_payment_failed(
    invoice: Dict[str, Any],
    event_ts: Optional[datetime] = None,
    event_id: Optional[str] = None,
) -> None:
    user = _find_user(_extract_user_id(invoice))
    if not user:
        current_app.logger.warning("Payment failed for unknown user")
        return

    _apply_subscription_updates(
        user,
        status="past_due",
        event_ts=event_ts,
        event_id=event_id,
    )


def _handle_payment_succeeded(
    invoice: Dict[str, Any],
    event_ts: Optional[datetime] = None,
    event_id: Optional[str] = None,
) -> None:
    user = _find_user(_extract_user_id(invoice))
    if not user:
        current_app.logger.warning("Payment succeeded for unknown user")
        return

    _apply_subscription_updates(
        user,
        status="active",
        period_end=_parse_timestamp(invoice.get("period_end")),
        event_ts=event_ts,
        event_id=event_id,
    )


def _apply_subscription_updates(
    user: User,
    *,
    tier: Any = _UNSET,
    status: Any = _UNSET,
    period_end: Any = _UNSET,
    cancel_at_period_end: Any = _UNSET,
    event_ts: Optional[datetime] = None,
    event_id: Optional[str] = None,
) -> None:
    # Out-of-order / replay guard (M-3): if this event predates the last
    # state-changing event already applied to the user, drop it so a stale
    # `payment_succeeded` cannot un-do a newer `payment_failed`.
    if _is_stale_event(user.id, event_ts):
        current_app.logger.warning(
            "Dropping stale/out-of-order Stripe event %s for user %s "
            "(event_created predates last applied state change)",
            event_id,
            user.id,
        )
        return

    if tier is not _UNSET and tier:
        user.subscription_tier = tier
    if status is not _UNSET and status:
        user.subscription_status = status
    if period_end is not _UNSET:
        user.current_period_end = period_end
    if cancel_at_period_end is not _UNSET:
        user.cancel_at_period_end = bool(cancel_at_period_end)

    db.session.add(user)
    # Advance the per-user high-water mark so a later replay of an older event
    # is recognised as stale.
    _advance_cursor(user.id, event_ts, event_id)
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
        current_app.logger.warning(
            "Invalid timestamp value for Stripe webhook: %s", value
        )
        return None
