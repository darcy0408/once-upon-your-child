"""In-app-purchase receipt verification + S2S notifications — STORE-1 (MT-143).

Scope (Phase 1):
  - `POST /api/iap/apple/verify`   — verify a StoreKit receipt with Apple.
  - `POST /api/iap/google/verify`  — verify a Play purchase token with Google.
  - `POST /api/iap/apple/notifications`  — Apple App Store Server Notifications V2.
  - `POST /api/iap/google/notifications` — Google Real-Time Developer Notifications.

The `/verify` endpoints are reached by the mobile app right after a StoreKit /
Play Billing purchase (see lib/services/payment/iap_verification_service.dart).
The `/notifications` endpoints are the mobile equivalent of the Stripe webhook
— renewals, cancellations, refunds and billing retries arrive there.

Trust model: the client's claim of a purchase is NEVER trusted. The verify
endpoints validate the receipt with Apple/Google server-side, then resolve the
tier and call the SHARED `apply_entitlement()` so all three channels (Stripe,
Apple, Google) write entitlement through one function.

Credentials are owner-provisioned (APP_STORE_SHARED_SECRET, Google
service-account JSON, GOOGLE_PUBSUB_AUDIENCE, Apple root CA). Without them the
verify endpoints fail CLOSED behind `IAP_VERIFICATION_ENABLED` (503, never a
blind grant) and the notification endpoints fail CLOSED at the signature gate
(503, never a blind ACK).
"""

import base64
import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

from flask import Blueprint, jsonify, request
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

try:
    from ..database import db
    from ..middleware.auth import require_auth

    # Importing the IAP models at module level registers them with SQLAlchemy
    # before db.create_all() runs, so the tables auto-create on a fresh DB.
    from ..models.iap_event import (
        STORE_APPLE,
        STORE_GOOGLE,
        IapNotificationEvent,
        IapPurchase,
    )
    from ..models.user import User
    from ..services.entitlement_service import FREE_TIER, apply_entitlement
    from ..utils.iap_notification_verify import (
        IapVerificationConfigError,
        IapVerificationError,
        verify_apple_jws,
        verify_google_pubsub_oidc,
    )
except ImportError:  # pragma: no cover - flat-module layout
    from database import db
    from middleware.auth import require_auth
    from models.iap_event import (
        STORE_APPLE,
        STORE_GOOGLE,
        IapNotificationEvent,
        IapPurchase,
    )
    from models.user import User
    from services.entitlement_service import FREE_TIER, apply_entitlement
    from utils.iap_notification_verify import (
        IapVerificationConfigError,
        IapVerificationError,
        verify_apple_jws,
        verify_google_pubsub_oidc,
    )

logger = logging.getLogger("iap_routes")

iap_routes = Blueprint("iap_routes", __name__)


# ---------------------------------------------------------------------------
# Product -> tier map. MUST match the store product IDs created in App Store
# Connect and the Google Play Console, and the Dart side
# (lib/services/payment/payment_models.dart: kIapProduct*).
# ---------------------------------------------------------------------------
_PRODUCT_TIER_MAP: Dict[str, str] = {
    "premium_monthly": "premium",
    "premium_annual": "premium",
    "family_monthly": "family",
}

# Store statuses that grant the paid tier. Anything else (expired / on_hold /
# refunded / inactive / ...) drops the user to FREE. Must stay a subset of
# entitlement_service._ACCESS_STATUSES.
_GRANTING_STATUSES = ("active", "trialing", "grace_period")


def _verification_enabled() -> bool:
    """Whether real receipt verification is wired up.

    Defaults OFF: until the owner provisions Apple/Google credentials the
    verify endpoints must NOT grant entitlement off an unverified receipt.
    """
    return os.getenv("IAP_VERIFICATION_ENABLED", "false").strip().lower() in (
        "1",
        "true",
        "yes",
        "on",
    )


def _tier_for_product(product_id: Optional[str]) -> Optional[str]:
    if not product_id:
        return None
    return _PRODUCT_TIER_MAP.get(product_id.strip())


# ===========================================================================
# Receipt verification endpoints
# ===========================================================================


@iap_routes.route("/iap/apple/verify", methods=["POST"])
@require_auth
def verify_apple_receipt():
    """Verify a StoreKit receipt with Apple and apply entitlement.

    Request JSON (from iap_verification_service.dart):
        { user_id, product_id, verification_data, source, purchase_id,
          transaction_date }

    `verification_data` is the StoreKit receipt (base64). The authenticated
    user is the authority on identity — the body `user_id` is cross-checked
    against it, never trusted alone.
    """
    return _handle_verify(store=STORE_APPLE)


@iap_routes.route("/iap/google/verify", methods=["POST"])
@require_auth
def verify_google_receipt():
    """Verify a Google Play purchase token with Google and apply entitlement.

    `verification_data` is the Play Billing purchase token. The Google Play
    Developer API resolves it to a subscription with an expiry and state.
    """
    return _handle_verify(store=STORE_GOOGLE)


def _handle_verify(*, store: str):
    """Shared verify handler for both stores."""
    data = request.get_json(silent=True) or {}
    product_id = data.get("product_id")
    verification_data = data.get("verification_data")

    # Identity: trust the authenticated user, not the body.
    user = request.current_user
    body_user_id = data.get("user_id")
    if body_user_id and body_user_id != user.id:
        logger.warning(
            "IAP verify: body user_id %s != authenticated user %s — using "
            "authenticated identity",
            body_user_id,
            user.id,
        )

    if not verification_data:
        return jsonify({"error": "Missing receipt verification_data"}), 400

    tier = _tier_for_product(product_id)
    if tier is None:
        logger.error("IAP verify: unknown product_id '%s'", product_id)
        return jsonify({"error": "Unknown subscription product"}), 400

    if not _verification_enabled():
        # TODO(STORE-1 / owner): set IAP_VERIFICATION_ENABLED=true once the
        # Apple App Store Server API key and Google service-account credentials
        # are provisioned. Until then we fail CLOSED — never grant a tier off
        # an unverified receipt.
        logger.error(
            "IAP verify called but IAP_VERIFICATION_ENABLED is off — "
            "store credentials not yet provisioned (store=%s)",
            store,
        )
        return (
            jsonify(
                {
                    "error": "In-app purchases are not yet available",
                    "code": "iap_not_configured",
                }
            ),
            503,
        )

    # --- Verify the receipt with the store --------------------------------
    try:
        if store == STORE_APPLE:
            verified = _verify_with_apple(verification_data, product_id)
        else:
            verified = _verify_with_google(verification_data, product_id)
    except IapVerificationConfigError:
        # Flag flipped on but store credentials aren't provisioned yet — fail
        # CLOSED with the same 503 as the disabled path, never a blind grant.
        logger.error(
            "IAP %s verify: verification enabled but store credentials are "
            "not configured",
            store,
        )
        return (
            jsonify(
                {
                    "error": "In-app purchases are not yet available",
                    "code": "iap_not_configured",
                }
            ),
            503,
        )
    except SQLAlchemyError:
        raise
    except Exception:  # noqa: BLE001 - store/network errors -> 502
        logger.exception("IAP %s receipt verification raised", store)
        return jsonify({"error": "Could not reach the store for verification"}), 502

    if not verified.get("valid"):
        logger.warning(
            "IAP %s receipt rejected for user %s: %s",
            store,
            user.id,
            verified.get("reason"),
        )
        return (
            jsonify(
                {
                    "error": "Receipt could not be verified",
                    "code": "receipt_invalid",
                }
            ),
            400,
        )

    expires_at = verified.get("expires_at")
    status = verified.get("status", "active")
    store_txn_id = verified.get("store_transaction_id") or product_id

    # --- Record the store purchase + apply entitlement --------------------
    try:
        record = _upsert_iap_purchase(
            user_id=user.id,
            store=store,
            product_id=product_id,
            tier=tier,
            store_transaction_id=store_txn_id,
            status=status,
            expires_at=expires_at,
            event_time=datetime.now(timezone.utc),
        )
        if record is None or str(record.user_id) != str(user.id):
            # Ownership guard (audit P2#16): the receipt is already registered
            # to a DIFFERENT account. _upsert_iap_purchase refused to reassign
            # the row — and entitlement must follow the same verdict, or one
            # shared receipt would unlock premium on any number of accounts.
            db.session.rollback()
            logger.warning(
                "IAP %s verify: receipt txn already registered to another "
                "account — refusing to grant user %s",
                store,
                user.id,
            )
            return (
                jsonify(
                    {
                        "error": "This purchase is already linked to another "
                        "account",
                        "code": "receipt_owned_elsewhere",
                    }
                ),
                409,
            )
        apply_entitlement(
            user,
            tier=(tier if status in _GRANTING_STATUSES else FREE_TIER),
            status=status,
            period_end=expires_at,
            source=store,
            commit=True,
        )
    except SQLAlchemyError:
        db.session.rollback()
        logger.exception("IAP verify: DB error applying entitlement")
        return jsonify({"error": "Could not record purchase"}), 500

    return (
        jsonify(
            {
                "status": "verified",
                "tier": user.subscription_tier,
                "subscription_status": user.subscription_status,
                "current_period_end": (
                    expires_at.isoformat() if isinstance(expires_at, datetime) else None
                ),
            }
        ),
        200,
    )


# ===========================================================================
# Server-to-server notification endpoints (renewals / cancels / refunds)
# ===========================================================================


@iap_routes.route("/iap/apple/notifications", methods=["POST"])
def apple_server_notifications():
    """Apple App Store Server Notifications V2 — renewals, cancels, refunds.

    The mobile equivalent of the Stripe webhook. Apple POSTs a single
    `signedPayload` JWS; the payload's `notificationUUID` is the dedup key.

    SECURITY GATE (S-06): the `signedPayload` JWS is verified against Apple's
    root CA BEFORE anything else (as is the inner `signedTransactionInfo` JWS
    before it is trusted). An unverifiable payload is rejected with 403; a
    missing-config situation (Apple root CA not bundled) fails CLOSED with
    503 — never a blind ACK.

    Response contract (Apple retries any non-200 up to 5 times over 72h):
      200 — processed, duplicate, stale, or nothing to apply.
      403 — signature verification failed.
      404 — transaction unknown here (the /verify call that creates the
            IapPurchase row may not have landed yet — retry converges).
      500 — transient DB failure (retry).
      503 — verification not configured (fail closed).
    """
    body = request.get_json(silent=True) or {}
    try:
        payload = verify_apple_jws(body.get("signedPayload"))
        return _handle_apple_notification(payload)
    except IapVerificationConfigError:
        logger.error("Apple S2S notification: verification not configured")
        return (
            jsonify(
                {
                    "error": "notification verification not configured",
                }
            ),
            503,
        )
    except IapVerificationError as exc:
        logger.warning("Apple S2S notification rejected: %s", exc)
        return jsonify({"error": "notification verification failed"}), 403
    except SQLAlchemyError:
        db.session.rollback()
        logger.exception("Apple S2S notification: DB error")
        return jsonify({"error": "could not record notification"}), 500


@iap_routes.route("/iap/google/notifications", methods=["POST"])
def google_server_notifications():
    """Google Real-Time Developer Notifications — renewals, cancels, refunds.

    Delivered via Google Cloud Pub/Sub: the request body is a Pub/Sub envelope
    whose `message.data` is base64 JSON carrying `subscriptionNotification`
    (with `purchaseToken` and `notificationType`) or
    `voidedPurchaseNotification` (refunds). The envelope `messageId` is the
    dedup key. The notification body is never trusted for state — the
    authoritative subscription state is re-queried from the Play Developer API
    via the same `_verify_with_google` path the verify endpoint uses.

    SECURITY GATE (S-06): the Pub/Sub push OIDC bearer token is verified
    against Google's public keys (audience = GOOGLE_PUBSUB_AUDIENCE) BEFORE
    anything else. A missing/invalid token is rejected with 403; an unset
    GOOGLE_PUBSUB_AUDIENCE fails CLOSED with 503 — never a blind ACK.

    Response contract (Pub/Sub redelivers any non-2xx with backoff):
      200 — processed, duplicate, or nothing to apply.
      400 — undecodable message data (genuine-but-malformed; will retry).
      403 — OIDC verification failed.
      404 — purchase token unknown here (the /verify call that creates the
            IapPurchase row may not have landed yet — redelivery converges).
      500 — transient DB failure (retry).
      502 — Play Developer API unreachable (retry).
      503 — verification / Play API credentials not configured (fail closed).
    """
    try:
        verify_google_pubsub_oidc(request)
        return _handle_google_notification(request.get_json(silent=True) or {})
    except IapVerificationConfigError:
        logger.error("Google S2S notification: verification not configured")
        return (
            jsonify(
                {
                    "error": "notification verification not configured",
                }
            ),
            503,
        )
    except IapVerificationError as exc:
        logger.warning("Google S2S notification rejected: %s", exc)
        return jsonify({"error": "notification verification failed"}), 403
    except SQLAlchemyError:
        db.session.rollback()
        logger.exception("Google S2S notification: DB error")
        return jsonify({"error": "could not record notification"}), 500
    except Exception:  # noqa: BLE001 - Play API network errors -> 502
        db.session.rollback()
        logger.exception("Google S2S notification: Play API re-query raised")
        return jsonify({"error": "could not reach the store"}), 502


def _ack(handled: bool, reason: Optional[str] = None, status_code: int = 200):
    """Uniform notification response."""
    body: Dict[str, Any] = {
        "status": "processed" if handled else "acknowledged",
        "handled": handled,
    }
    if reason:
        body["reason"] = reason
    return jsonify(body), status_code


def _naive_utc(value: Optional[datetime]) -> Optional[datetime]:
    """Normalize an aware datetime to the naive-UTC convention the DB uses."""
    if value is not None and value.tzinfo is not None:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


def _record_notification_event(
    *,
    store: str,
    notification_id: str,
    notification_type: Optional[str],
    notification_time: Optional[datetime],
) -> bool:
    """Insert the dedup row for a store notification ID.

    Returns True if this is the first delivery (row flushed, NOT yet
    committed — the caller commits atomically with the entitlement write, so a
    failure later re-opens the dedup window for the store's retry). Returns
    False on a duplicate delivery.
    """
    event = IapNotificationEvent(
        store=store,
        notification_id=notification_id,
        notification_type=notification_type,
        notification_time=_naive_utc(notification_time),
    )
    db.session.add(event)
    try:
        db.session.flush()
    except IntegrityError:
        db.session.rollback()
        return False
    return True


def _apply_notification_state(
    *,
    store: str,
    purchase: IapPurchase,
    product_id: Optional[str],
    status: str,
    expires_at: Optional[datetime],
    event_time: Optional[datetime],
    cancel_at_period_end: Optional[bool] = None,
) -> bool:
    """Write a store-notified subscription state through the shared helpers.

    Resolves the tier, updates the IapPurchase row (via `_upsert_iap_purchase`,
    which owns the ordering + ownership guards) and applies entitlement to the
    row's user. Flushes but does NOT commit — the caller commits atomically
    with the dedup row. Returns False when the user row no longer exists.
    """
    tier = _tier_for_product(product_id) or purchase.tier
    _upsert_iap_purchase(
        user_id=purchase.user_id,
        store=store,
        product_id=product_id or purchase.product_id,
        tier=tier,
        store_transaction_id=purchase.store_transaction_id,
        status=status,
        expires_at=expires_at,
        event_time=event_time,
    )

    user = db.session.get(User, purchase.user_id)
    if user is None:
        logger.error(
            "IAP %s notification: purchase %s references missing user %s — "
            "recorded store state without entitlement",
            store,
            purchase.store_transaction_id,
            purchase.user_id,
        )
        return False

    apply_entitlement(
        user,
        tier=(tier if status in _GRANTING_STATUSES else FREE_TIER),
        status=status,
        period_end=expires_at,
        cancel_at_period_end=cancel_at_period_end,
        source=store,
        commit=False,
    )
    return True


# ---------------------------------------------------------------------------
# Apple notification handling
# ---------------------------------------------------------------------------


def _apple_notification_state(
    notification_type: str,
    subtype: Optional[str],
    txn: Dict[str, Any],
) -> Tuple[str, Optional[datetime], Optional[bool]]:
    """Map a V2 notification + decoded transaction to (status, expires_at,
    cancel_at_period_end).

    State is derived from the transaction fields wherever possible (Apple's
    recommended state-over-event approach); the notification type only breaks
    the ties the transaction can't (grace period vs. billing retry). A
    subscription with no expiry fails CLOSED to inactive — we only sell
    auto-renewable subscriptions, which always carry `expiresDate`.
    """
    expires_at = _apple_ms_to_datetime(txn.get("expiresDate"))

    cancel_at_period_end: Optional[bool] = None
    if notification_type == "DID_CHANGE_RENEWAL_STATUS":
        if subtype == "AUTO_RENEW_DISABLED":
            cancel_at_period_end = True
        elif subtype == "AUTO_RENEW_ENABLED":
            cancel_at_period_end = False

    # A revoked/refunded transaction never grants, whatever the expiry says.
    if txn.get("revocationDate") is not None or notification_type in (
        "REFUND",
        "REVOKE",
    ):
        return "refunded", expires_at, cancel_at_period_end

    if notification_type == "DID_FAIL_TO_RENEW":
        # Billing retry: access continues only inside Apple's grace period.
        if subtype == "GRACE_PERIOD":
            return "grace_period", expires_at, cancel_at_period_end
        return "on_hold", expires_at, cancel_at_period_end

    if notification_type in ("EXPIRED", "GRACE_PERIOD_EXPIRED"):
        return "expired", expires_at, cancel_at_period_end

    # SUBSCRIBED / DID_RENEW / DID_CHANGE_RENEWAL_* / OFFER_REDEEMED / ... —
    # trust the transaction's own expiry window.
    if expires_at is None or expires_at <= datetime.now(timezone.utc):
        return "inactive", expires_at, cancel_at_period_end
    return "active", expires_at, cancel_at_period_end


def _handle_apple_notification(payload: Dict[str, Any]):
    """Apply a verified App Store Server Notifications V2 payload.

    `payload` is the decoded (signature-verified) outer JWS. The inner
    `data.signedTransactionInfo` JWS is verified with the same Apple root CA
    chain before any field of it is trusted.
    """
    notification_type = payload.get("notificationType") or ""
    subtype = payload.get("subtype")
    notification_uuid = payload.get("notificationUUID")
    signed_txn = (payload.get("data") or {}).get("signedTransactionInfo")

    if not signed_txn or not notification_uuid:
        # TEST notifications and summary/external-purchase payloads carry no
        # per-transaction state — nothing to apply. ACK so Apple stops.
        logger.info(
            "Apple S2S notification %s (%s): no transaction payload — "
            "acknowledged without entitlement change",
            notification_type or "<untyped>",
            notification_uuid or "no-uuid",
        )
        return _ack(False, reason="no transaction payload")

    # The inner transaction JWS is signed the same way as the envelope; verify
    # it before trusting any field (raises -> 403/503 in the route).
    txn = verify_apple_jws(signed_txn)

    # Defense in depth: Apple's root CA signs notifications for EVERY app, so
    # a genuine payload may belong to someone else's app. The txn-id -> row
    # lookup below is the primary gate (unknown -> 404); when IOS_BUNDLE_ID is
    # set, reject foreign-app payloads explicitly as well.
    expected_bundle = (os.getenv("IOS_BUNDLE_ID") or "").strip()
    txn_bundle = txn.get("bundleId")
    if expected_bundle and txn_bundle and txn_bundle != expected_bundle:
        logger.warning(
            "Apple S2S notification %s is for bundle %s, not ours — "
            "acknowledged without entitlement change",
            notification_uuid,
            txn_bundle,
        )
        return _ack(False, reason="bundle mismatch")

    original_txn_id = txn.get("originalTransactionId")
    if not original_txn_id:
        logger.error(
            "Apple S2S notification %s has no originalTransactionId — "
            "acknowledged without entitlement change",
            notification_uuid,
        )
        return _ack(False, reason="no originalTransactionId")

    purchase = (
        db.session.query(IapPurchase)
        .filter_by(store_transaction_id=original_txn_id)
        .first()
    )
    if purchase is None:
        # The purchase's /verify call may not have landed yet (the SUBSCRIBED
        # notification often races it by seconds). Non-200 -> Apple retries in
        # 1h, by which time the row exists. Nothing is committed on this path,
        # so the retry reprocesses from scratch.
        logger.warning(
            "Apple S2S notification %s: unknown originalTransactionId — "
            "requesting retry",
            notification_uuid,
        )
        return _ack(False, reason="transaction unknown", status_code=404)

    event_time = _apple_ms_to_datetime(
        payload.get("signedDate") or txn.get("signedDate")
    )

    if not _record_notification_event(
        store=STORE_APPLE,
        notification_id=notification_uuid,
        notification_type=notification_type,
        notification_time=event_time,
    ):
        logger.info(
            "Apple S2S notification %s already processed — duplicate delivery",
            notification_uuid,
        )
        return _ack(False, reason="duplicate")

    # Ordering guard: Apple state is derived from THIS payload, so a stale
    # out-of-order delivery must not regress entitlement (e.g. an old EXPIRED
    # arriving after a newer DID_RENEW). The duplicate row above still commits,
    # so the same stale notification won't be reconsidered on a redelivery.
    stale = (
        event_time is not None
        and purchase.last_event_time is not None
        and _naive_utc(event_time) < purchase.last_event_time
    )
    if stale:
        logger.warning(
            "Apple S2S notification %s (%s) predates last applied state — "
            "dropped as stale",
            notification_uuid,
            notification_type,
        )
        db.session.commit()
        return _ack(False, reason="stale")

    status, expires_at, cancel_at_period_end = _apple_notification_state(
        notification_type, subtype, txn
    )
    applied = _apply_notification_state(
        store=STORE_APPLE,
        purchase=purchase,
        product_id=txn.get("productId"),
        status=status,
        expires_at=expires_at,
        event_time=event_time,
        cancel_at_period_end=cancel_at_period_end,
    )
    db.session.commit()

    logger.info(
        "Apple S2S notification %s applied: type=%s subtype=%s status=%s",
        notification_uuid,
        notification_type,
        subtype,
        status,
    )
    return _ack(applied, reason=None if applied else "user missing")


# ---------------------------------------------------------------------------
# Google notification handling
# ---------------------------------------------------------------------------


def _decode_pubsub_data(message: Dict[str, Any]) -> Dict[str, Any]:
    """Decode the base64 JSON `message.data` of a Pub/Sub envelope."""
    raw = message.get("data")
    if not raw or not isinstance(raw, str):
        raise ValueError("Pub/Sub message has no data")
    decoded = json.loads(base64.b64decode(raw))
    if not isinstance(decoded, dict):
        raise ValueError("Pub/Sub message data is not a JSON object")
    return decoded


def _handle_google_notification(envelope: Dict[str, Any]):
    """Apply a verified Google Real-Time Developer Notification.

    The RTDN body is only used to locate the subscription (purchase token) —
    the authoritative state is re-queried from the Play Developer API, so an
    out-of-order delivery still applies the CURRENT state and needs no
    payload-level ordering guard (`event_time` is the query time, matching the
    verify endpoint's convention). The exception is `voidedPurchaseNotification`
    (refund), which is applied directly: revocation must not depend on how the
    re-queried state presents it.
    """
    message = envelope.get("message") or {}
    message_id = message.get("messageId")

    if not message_id or not message.get("data"):
        logger.info(
            "Google S2S notification without message data — acknowledged "
            "without entitlement change"
        )
        return _ack(False, reason="no message data")

    try:
        notification = _decode_pubsub_data(message)
    except (ValueError, json.JSONDecodeError) as exc:
        logger.error("Google S2S notification %s undecodable: %s", message_id, exc)
        return jsonify({"error": "undecodable Pub/Sub message data"}), 400

    sub_notification = notification.get("subscriptionNotification") or {}
    voided_notification = notification.get("voidedPurchaseNotification") or {}
    purchase_token = sub_notification.get("purchaseToken") or voided_notification.get(
        "purchaseToken"
    )
    notification_type = (
        "voided"
        if voided_notification
        else str(sub_notification.get("notificationType") or "")
    )

    if not purchase_token:
        # testNotification (or an unhandled kind, e.g. one-time products,
        # which we do not sell) — nothing to apply.
        logger.info(
            "Google S2S notification %s carries no purchase token "
            "(kinds: %s) — acknowledged without entitlement change",
            message_id,
            sorted(k for k in notification if k != "version"),
        )
        return _ack(False, reason="no purchase token")

    purchase = (
        db.session.query(IapPurchase)
        .filter_by(store_transaction_id=purchase_token)
        .first()
    )
    if purchase is None:
        # The /verify call that creates the row may not have landed yet —
        # non-2xx makes Pub/Sub redeliver with backoff until it converges.
        # Nothing is committed on this path.
        logger.warning(
            "Google S2S notification %s: unknown purchase token (…%s) — "
            "requesting redelivery",
            message_id,
            purchase_token[-8:],
        )
        return _ack(False, reason="purchase unknown", status_code=404)

    notification_time = _apple_ms_to_datetime(notification.get("eventTimeMillis"))

    if voided_notification:
        # Refund/void: revoke directly off the store's explicit signal.
        if not _record_notification_event(
            store=STORE_GOOGLE,
            notification_id=message_id,
            notification_type=notification_type,
            notification_time=notification_time,
        ):
            return _ack(False, reason="duplicate")
        applied = _apply_notification_state(
            store=STORE_GOOGLE,
            purchase=purchase,
            product_id=purchase.product_id,
            status="refunded",
            expires_at=purchase.expires_at,
            event_time=datetime.now(timezone.utc),
        )
        db.session.commit()
        logger.info(
            "Google S2S notification %s applied: voided purchase — refunded",
            message_id,
        )
        return _ack(applied, reason=None if applied else "user missing")

    # Re-query the authoritative subscription state (never trust the RTDN
    # body for state). Raises IapVerificationConfigError -> 503 / network
    # errors -> 502 in the route; both make Pub/Sub redeliver.
    product_id = sub_notification.get("subscriptionId") or purchase.product_id
    verified = _verify_with_google(purchase_token, product_id)
    if not verified.get("valid"):
        # A token Google no longer recognizes, or a product mismatch. Do NOT
        # revoke off a failed lookup — log loudly and ACK so this doesn't
        # retry forever; the daily reconciliation/verify path stays authoritative.
        logger.error(
            "Google S2S notification %s: re-query did not validate (%s) — "
            "no entitlement change",
            message_id,
            verified.get("reason"),
        )
        return _ack(False, reason="re-query did not validate")

    if not _record_notification_event(
        store=STORE_GOOGLE,
        notification_id=message_id,
        notification_type=notification_type,
        notification_time=notification_time,
    ):
        return _ack(False, reason="duplicate")

    applied = _apply_notification_state(
        store=STORE_GOOGLE,
        purchase=purchase,
        product_id=product_id,
        status=verified.get("status", "inactive"),
        expires_at=verified.get("expires_at"),
        event_time=datetime.now(timezone.utc),
    )
    db.session.commit()

    logger.info(
        "Google S2S notification %s applied: rtdn_type=%s status=%s",
        message_id,
        notification_type,
        verified.get("status"),
    )
    return _ack(applied, reason=None if applied else "user missing")


# ===========================================================================
# Store verification helpers
# ===========================================================================

# Apple App Store receipt verification (verifyReceipt). The client sends a
# base64 StoreKit receipt; we validate it with Apple's shared-secret endpoint.
# Per Apple's guidance always POST production first and retry sandbox on a 21007
# status, so TestFlight/sandbox receipts verify through the same code path.
_APPLE_VERIFY_URL_PROD = "https://buy.itunes.apple.com/verifyReceipt"
_APPLE_VERIFY_URL_SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt"


def _apple_ms_to_datetime(value: Any) -> Optional[datetime]:
    """Convert Apple's millisecond-epoch (expires_date_ms) to an aware datetime."""
    if value is None:
        return None
    try:
        return datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)
    except (ValueError, TypeError):
        return None


def _latest_apple_entry(entries: list) -> Optional[Dict[str, Any]]:
    """Return the receipt transaction with the latest expires_date_ms."""
    best: Optional[Dict[str, Any]] = None
    best_ms = -1
    for entry in entries or []:
        try:
            ms_int = int(entry.get("expires_date_ms"))
        except (ValueError, TypeError):
            continue
        if ms_int > best_ms:
            best_ms = ms_int
            best = entry
    return best


def _map_apple_receipt(data: Dict[str, Any], product_id: str) -> Dict[str, Any]:
    """Map an Apple verifyReceipt response to the shared verify shape.

    status 0 = valid; 21006 = valid receipt whose subscription has expired (it
    still carries the transaction info). Any other status is a rejected receipt
    -> { valid: False } -> HTTP 400.
    """
    status = data.get("status")
    if status not in (0, 21006):
        return {"valid": False, "reason": "apple verifyReceipt status %s" % status}

    # Subscriptions surface in latest_receipt_info; fall back to receipt.in_app.
    entries = data.get("latest_receipt_info") or []
    if not entries:
        entries = (data.get("receipt") or {}).get("in_app") or []

    matching = [e for e in entries if e.get("product_id") == product_id]
    if product_id and entries and not matching:
        return {
            "valid": False,
            "reason": "receipt has no transaction for %s" % product_id,
        }

    latest = _latest_apple_entry(matching or entries)
    expires_at = None
    store_txn_id = None
    if latest:
        expires_at = _apple_ms_to_datetime(latest.get("expires_date_ms"))
        store_txn_id = latest.get("original_transaction_id") or latest.get(
            "transaction_id"
        )

    now = datetime.now(timezone.utc)
    if status == 21006 or (expires_at is not None and expires_at <= now):
        entitlement_status = "inactive"
    else:
        entitlement_status = "active"

    return {
        "valid": True,
        "status": entitlement_status,
        "expires_at": expires_at,
        "store_transaction_id": store_txn_id,
    }


def _post_apple_verify(url: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """POST a verifyReceipt payload to Apple and return the parsed JSON."""
    import requests

    response = requests.post(url, json=payload, timeout=15)
    response.raise_for_status()
    return response.json()


def _fetch_apple_verify_receipt(receipt_data: str) -> Dict[str, Any]:
    """Verify a StoreKit receipt with Apple's verifyReceipt endpoint.

    Isolated (and patched in tests) so _map_apple_receipt can be exercised
    without network or credentials. A missing APP_STORE_SHARED_SECRET or a 21004
    (shared-secret mismatch) fails CLOSED via IapVerificationConfigError (-> 503);
    a 21005 (Apple server unavailable) surfaces as a transient error (-> 502).
    """
    shared_secret = os.getenv("APP_STORE_SHARED_SECRET")
    if not shared_secret:
        raise IapVerificationConfigError(
            "Apple verification is enabled but APP_STORE_SHARED_SECRET is unset."
        )

    payload = {
        "receipt-data": receipt_data,
        "password": shared_secret,
        "exclude-old-transactions": True,
    }
    data = _post_apple_verify(_APPLE_VERIFY_URL_PROD, payload)
    # 21007: a sandbox receipt reached the prod endpoint -> retry sandbox.
    if data.get("status") == 21007:
        data = _post_apple_verify(_APPLE_VERIFY_URL_SANDBOX, payload)
    if data.get("status") == 21004:
        raise IapVerificationConfigError(
            "APP_STORE_SHARED_SECRET does not match the app's shared secret."
        )
    if data.get("status") == 21005:
        # Apple's receipt server is temporarily unavailable -> 502, retryable.
        raise RuntimeError("Apple receipt server temporarily unavailable (21005)")
    return data


def _verify_with_apple(receipt_data: str, product_id: str) -> Dict[str, Any]:
    """Validate a StoreKit receipt with Apple (verifyReceipt) and map the result.

    The client sends a base64 StoreKit receipt (serverVerificationData). We POST
    it to Apple's shared-secret endpoint and map the authoritative expiry/state
    to { valid, status, expires_at, store_transaction_id }; the client's claim is
    never trusted.

    Needs (owner-provisioned, STORE-1): APP_STORE_SHARED_SECRET (the App Store
    Connect app-specific shared secret). A missing secret / 21004 -> 503; a bad
    receipt -> 400; a transient Apple outage -> 502.

    NOTE: verifyReceipt is Apple's legacy (still functional) endpoint. Migrating
    to the App Store Server API (StoreKit2 signed transactions) is a post-launch
    hardening step.
    """
    data = _fetch_apple_verify_receipt(receipt_data)
    return _map_apple_receipt(data, product_id)


# ---------------------------------------------------------------------------
# Google Play Developer API — purchases.subscriptionsv2.get
# ---------------------------------------------------------------------------
_GOOGLE_PLAY_API_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3"
_GOOGLE_ANDROIDPUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Google subscriptionState -> our entitlement status vocabulary. States absent
# from this map (EXPIRED / ON_HOLD / PAUSED / PENDING / UNSPECIFIED) do NOT
# grant access. CANCELED still grants until expiryTime (auto-renew is off but
# access continues), so it maps to "active".
_GOOGLE_STATE_TO_STATUS = {
    "SUBSCRIPTION_STATE_ACTIVE": "active",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "grace_period",
    "SUBSCRIPTION_STATE_CANCELED": "active",
}


def _parse_rfc3339(value: Optional[str]) -> Optional[datetime]:
    """Parse an RFC3339 timestamp (e.g. Google's expiryTime) to an aware UTC
    datetime.

    Tolerates a trailing 'Z' and sub-microsecond precision (Google may send
    nanoseconds, which datetime.fromisoformat rejects). Returns None when the
    value is missing or unparseable.
    """
    if not value or not isinstance(value, str):
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    if "." in text:
        head, _, tail = text.partition(".")
        frac = ""
        rest = ""
        for idx, char in enumerate(tail):
            if char.isdigit():
                frac += char
            else:
                rest = tail[idx:]
                break
        text = head + ("." + frac[:6] if frac else "") + rest
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def _latest_google_expiry(line_items: list) -> Optional[datetime]:
    """Return the latest expiryTime across a subscription's line items."""
    latest: Optional[datetime] = None
    for item in line_items or []:
        parsed = _parse_rfc3339(item.get("expiryTime"))
        if parsed and (latest is None or parsed > latest):
            latest = parsed
    return latest


def _map_google_subscription(data: Dict[str, Any], product_id: str) -> Dict[str, Any]:
    """Map a purchases.subscriptionsv2 response to the shared verify shape.

    Returns { valid, status, expires_at, reason }; _verify_with_google adds the
    stable store_transaction_id (the purchase token). `valid` means the token
    resolved to a genuine subscription for the claimed product; `status`
    (derived from subscriptionState) is what _handle_verify uses to decide
    between granting the tier and dropping to FREE.
    """
    line_items = data.get("lineItems") or []
    product_ids = {li.get("productId") for li in line_items if li.get("productId")}

    # The token must resolve to the product the client claimed.
    if product_id and product_ids and product_id not in product_ids:
        return {
            "valid": False,
            "reason": "purchase token resolves to %s, not claimed %s"
            % (sorted(product_ids), product_id),
        }

    expires_at = _latest_google_expiry(line_items)
    state = data.get("subscriptionState", "")
    status = _GOOGLE_STATE_TO_STATUS.get(state)

    if status is None:
        # A real subscription, but in a non-granting state (expired/on-hold/...).
        return {
            "valid": True,
            "status": "inactive",
            "expires_at": expires_at,
            "reason": "subscription state %s does not grant access"
            % (state or "unknown"),
        }

    return {
        "valid": True,
        "status": status,
        "expires_at": expires_at,
    }


def _fetch_google_subscriptionv2(
    package_name: str, purchase_token: str
) -> Dict[str, Any]:
    """Call the Play Developer API purchases.subscriptionsv2.get.

    Isolated (and patched in tests) so the pure mapping in
    _map_google_subscription can be exercised without network or credentials.
    Reads the service-account JSON + package name from the environment; a
    missing credential fails CLOSED via IapVerificationConfigError (-> 503).
    A 404 (unknown/expired token) raises IapVerificationError (-> 400).
    """
    raw_creds = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    if not raw_creds or not package_name:
        raise IapVerificationConfigError(
            "Google Play verification is enabled but not configured "
            "(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON / ANDROID_PACKAGE_NAME unset)."
        )

    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    credentials = service_account.Credentials.from_service_account_info(
        json.loads(raw_creds), scopes=[_GOOGLE_ANDROIDPUBLISHER_SCOPE]
    )
    session = AuthorizedSession(credentials)
    url = "%s/applications/%s/purchases/subscriptionsv2/tokens/%s" % (
        _GOOGLE_PLAY_API_BASE,
        package_name,
        purchase_token,
    )
    response = session.get(url, timeout=15)
    if response.status_code == 404:
        raise IapVerificationError("Google purchase token not found")
    response.raise_for_status()
    return response.json()


def _verify_with_google(purchase_token: str, product_id: str) -> Dict[str, Any]:
    """Validate a Google Play purchase token with the Play Developer API.

    Authenticates with the service-account JSON (scope androidpublisher), calls
    purchases.subscriptionsv2.get, and maps the authoritative subscription
    state to { valid, status, expires_at, store_transaction_id }. The store
    response is the authority — the client's claim is never trusted.

    Needs (owner-provisioned, STORE-1): GOOGLE_PLAY_SERVICE_ACCOUNT_JSON,
    ANDROID_PACKAGE_NAME. A not-found token -> { valid: False } -> HTTP 400;
    a missing credential -> IapVerificationConfigError -> HTTP 503.

    TODO(STORE-1): free-trial detection (offerDetails) currently maps to
    "active" — this grants correctly but is not surfaced as "trialing".
    """
    package_name = (os.getenv("ANDROID_PACKAGE_NAME") or "").strip()
    try:
        data = _fetch_google_subscriptionv2(package_name, purchase_token)
    except IapVerificationError as exc:
        return {"valid": False, "reason": str(exc)}
    result = _map_google_subscription(data, product_id)
    if result.get("valid"):
        # The purchase token is the stable per-subscription key: it matches the
        # IapPurchase.store_transaction_id contract and is what a Real-Time
        # Developer Notification carries, so renewals/cancels/refunds can be
        # linked back to this row. (latestOrderId increments every renewal, so
        # it is not a stable key.)
        result["store_transaction_id"] = purchase_token
    return result


# ===========================================================================
# Persistence helpers
# ===========================================================================


def _upsert_iap_purchase(
    *,
    user_id: str,
    store: str,
    product_id: str,
    tier: str,
    store_transaction_id: str,
    status: str,
    expires_at: Optional[datetime],
    event_time: Optional[datetime],
) -> IapPurchase:
    """Insert or update the IapPurchase row for this store subscription.

    Keyed by `store_transaction_id` (unique). Applies an ordering guard: an
    update whose `event_time` predates the stored `last_event_time` is treated
    as a stale/out-of-order delivery and skipped — the IAP analogue of the
    Stripe webhook's per-user cursor.
    """
    if expires_at is not None and expires_at.tzinfo is not None:
        expires_at = expires_at.astimezone(timezone.utc).replace(tzinfo=None)
    if event_time is not None and event_time.tzinfo is not None:
        event_time = event_time.astimezone(timezone.utc).replace(tzinfo=None)

    record = (
        db.session.query(IapPurchase)
        .filter_by(store_transaction_id=store_transaction_id)
        .first()
    )

    if record is None:
        record = IapPurchase(
            user_id=user_id,
            store=store,
            product_id=product_id,
            tier=tier,
            store_transaction_id=store_transaction_id,
            status=status,
            expires_at=expires_at,
            last_event_time=event_time,
        )
        db.session.add(record)
        try:
            db.session.flush()
        except IntegrityError:
            # Concurrent insert raced us — fall through to the update path.
            db.session.rollback()
            record = (
                db.session.query(IapPurchase)
                .filter_by(store_transaction_id=store_transaction_id)
                .first()
            )

    if record is not None and record.id is not None:
        # Ordering guard against stale notifications.
        if (
            event_time is not None
            and record.last_event_time is not None
            and event_time < record.last_event_time
        ):
            logger.warning(
                "IAP upsert: dropping stale event for txn %s "
                "(event predates last applied state)",
                store_transaction_id,
            )
            return record
        # Ownership guard (audit P2#16): a store_transaction_id belongs to the
        # account that first registered it. Refuse to reassign it to a different
        # user — otherwise a second verified caller presenting the same receipt
        # would steal the subscription row.
        if record.user_id and str(record.user_id) != str(user_id):
            logger.warning(
                "IAP upsert: txn %s already owned by user %s; refusing to "
                "reassign to user %s",
                store_transaction_id,
                record.user_id,
                user_id,
            )
            return record
        record.user_id = user_id
        record.product_id = product_id
        record.tier = tier
        record.status = status
        record.expires_at = expires_at
        if event_time is not None:
            record.last_event_time = event_time
        db.session.add(record)

    return record
