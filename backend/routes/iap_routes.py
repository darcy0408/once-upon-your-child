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

PHASE 1 IS A SCAFFOLD. The Apple/Google API calls are stubbed with explicit
TODOs and a feature flag — the real calls need owner-provided credentials
(Apple App Store Server API key, Google service-account JSON) that are out of
this task's scope. Without them, `IAP_VERIFICATION_ENABLED` defaults off and
the endpoints return 503 rather than silently granting entitlement.
"""
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

from flask import Blueprint, current_app, jsonify, request
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

try:
    from ..database import db
    from ..models.user import User
    # Importing the IAP models at module level registers them with SQLAlchemy
    # before db.create_all() runs, so the tables auto-create on a fresh DB.
    from ..models.iap_event import (
        IapNotificationEvent,
        IapPurchase,
        STORE_APPLE,
        STORE_GOOGLE,
    )
    from ..middleware.auth import require_auth
    from ..services.entitlement_service import apply_entitlement, FREE_TIER
    from ..utils.iap_notification_verify import (
        IapVerificationConfigError,
        IapVerificationError,
        verify_apple_jws,
        verify_google_pubsub_oidc,
    )
except ImportError:  # pragma: no cover - flat-module layout
    from database import db
    from models.user import User
    from models.iap_event import (
        IapNotificationEvent,
        IapPurchase,
        STORE_APPLE,
        STORE_GOOGLE,
    )
    from middleware.auth import require_auth
    from services.entitlement_service import apply_entitlement, FREE_TIER
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
    "family_monthly": "family",
}


def _verification_enabled() -> bool:
    """Whether real receipt verification is wired up.

    Defaults OFF: until the owner provisions Apple/Google credentials the
    verify endpoints must NOT grant entitlement off an unverified receipt.
    """
    return os.getenv("IAP_VERIFICATION_ENABLED", "false").strip().lower() in (
        "1", "true", "yes", "on",
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
            "authenticated identity", body_user_id, user.id,
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
            "store credentials not yet provisioned (store=%s)", store,
        )
        return jsonify({
            "error": "In-app purchases are not yet available",
            "code": "iap_not_configured",
        }), 503

    # --- Verify the receipt with the store --------------------------------
    try:
        if store == STORE_APPLE:
            verified = _verify_with_apple(verification_data)
        else:
            verified = _verify_with_google(verification_data, product_id)
    except SQLAlchemyError:
        raise
    except Exception:  # noqa: BLE001 - store/network errors -> 502
        logger.exception("IAP %s receipt verification raised", store)
        return jsonify({"error": "Could not reach the store for verification"}), 502

    if not verified.get("valid"):
        logger.warning(
            "IAP %s receipt rejected for user %s: %s",
            store, user.id, verified.get("reason"),
        )
        return jsonify({
            "error": "Receipt could not be verified",
            "code": "receipt_invalid",
        }), 400

    expires_at = verified.get("expires_at")
    status = verified.get("status", "active")
    store_txn_id = verified.get("store_transaction_id") or product_id

    # --- Record the store purchase + apply entitlement --------------------
    try:
        _upsert_iap_purchase(
            user_id=user.id,
            store=store,
            product_id=product_id,
            tier=tier,
            store_transaction_id=store_txn_id,
            status=status,
            expires_at=expires_at,
            event_time=datetime.now(timezone.utc),
        )
        apply_entitlement(
            user,
            tier=tier if status in ("active", "trialing", "grace_period") else FREE_TIER,
            status=status,
            period_end=expires_at,
            source=store,
            commit=True,
        )
    except SQLAlchemyError:
        db.session.rollback()
        logger.exception("IAP verify: DB error applying entitlement")
        return jsonify({"error": "Could not record purchase"}), 500

    return jsonify({
        "status": "verified",
        "tier": user.subscription_tier,
        "subscription_status": user.subscription_status,
        "current_period_end":
            expires_at.isoformat() if isinstance(expires_at, datetime) else None,
    }), 200


# ===========================================================================
# Server-to-server notification endpoints (renewals / cancels / refunds)
# ===========================================================================

@iap_routes.route("/iap/apple/notifications", methods=["POST"])
def apple_server_notifications():
    """Apple App Store Server Notifications V2 — renewals, cancels, refunds.

    The mobile equivalent of the Stripe webhook. Apple POSTs a single
    `signedPayload` JWS; the payload's `notificationUUID` is the dedup key.

    SECURITY GATE (S-06): the `signedPayload` JWS is verified against Apple's
    root CA BEFORE anything else. An unverifiable payload is rejected with 403;
    a missing-config situation (Apple root CA not bundled) fails CLOSED with
    503 — never a blind ACK.

    TODO(STORE-1 phase 2 / owner): implement entitlement application.
      1. Parse the `signedPayload` JWS.  [DONE — verified below]
      2. Verify the x5c certificate chain against Apple's root CA.  [DONE]
      3. Decode `notificationType` / `subtype` and the `data.signedTransactionInfo`
         + `data.signedRenewalInfo` to get product, expiry and state.
      4. Map originalTransactionId -> IapPurchase, apply ordering guard against
         `last_event_time`, update status/expiry, and call apply_entitlement().
    Requires the App Store Server API config (issuer ID, key ID, .p8 key).
    """
    body = request.get_json(silent=True) or {}
    signed_payload = body.get("signedPayload")
    try:
        # Verified payload is intentionally NOT consumed yet — entitlement
        # mutation is the phase-2 TODO above. This gate only proves the
        # request is genuinely from Apple before the stub ACKs it.
        verify_apple_jws(signed_payload)
    except IapVerificationConfigError:
        logger.error("Apple S2S notification: verification not configured")
        return jsonify({
            "error": "notification verification not configured",
        }), 503
    except IapVerificationError as exc:
        logger.warning("Apple S2S notification rejected: %s", exc)
        return jsonify({"error": "notification verification failed"}), 403

    return _handle_notification_stub(store=STORE_APPLE)


@iap_routes.route("/iap/google/notifications", methods=["POST"])
def google_server_notifications():
    """Google Real-Time Developer Notifications — renewals, cancels, refunds.

    Delivered via Google Cloud Pub/Sub: the request body is a Pub/Sub envelope
    whose `message.data` is base64 JSON carrying `subscriptionNotification`
    (with `purchaseToken` and `notificationType`).

    SECURITY GATE (S-06): the Pub/Sub push OIDC bearer token is verified
    against Google's public keys (audience = GOOGLE_PUBSUB_AUDIENCE) BEFORE
    anything else. A missing/invalid token is rejected with 403; an unset
    GOOGLE_PUBSUB_AUDIENCE fails CLOSED with 503 — never a blind ACK.

    TODO(STORE-1 phase 2 / owner): implement entitlement application.
      1. (Recommended) verify the Pub/Sub push OIDC token.  [DONE — below]
      2. Base64-decode `message.data`; read `purchaseToken` + `notificationType`.
      3. Re-query the Google Play Developer API for the authoritative
         subscription state (never trust the notification body alone).
      4. Map purchaseToken -> IapPurchase, apply the ordering guard, update
         status/expiry, and call apply_entitlement().
    Requires the Google service-account JSON with Play Developer API access.
    """
    try:
        # Verified claims intentionally not consumed yet — entitlement
        # mutation is the phase-2 TODO above. This gate only proves the
        # request is a genuine Google Pub/Sub push before the stub ACKs it.
        verify_google_pubsub_oidc(request)
    except IapVerificationConfigError:
        logger.error("Google S2S notification: verification not configured")
        return jsonify({
            "error": "notification verification not configured",
        }), 503
    except IapVerificationError as exc:
        logger.warning("Google S2S notification rejected: %s", exc)
        return jsonify({"error": "notification verification failed"}), 403

    return _handle_notification_stub(store=STORE_GOOGLE)


def _handle_notification_stub(*, store: str):
    """Phase-1 placeholder for the S2S notification handlers.

    Records the notification for observability (and dedup, once the IDs are
    parsed) and ACKs with 200 so the store does not enter an endless retry
    loop while the full handler is still being built. It deliberately does NOT
    mutate any entitlement — that is gated on the phase-2 implementation above.
    """
    logger.warning(
        "IAP %s S2S notification received but handler is a Phase-1 stub — "
        "acknowledged without applying entitlement (STORE-1 phase 2 TODO).",
        store,
    )
    # 200 so Apple/Google stop retrying; once the real handler lands it will
    # parse the payload, dedup on the notification ID, and apply entitlement.
    return jsonify({"status": "acknowledged", "handled": False}), 200


# ===========================================================================
# Store verification helpers — Phase 1 stubs
# ===========================================================================

def _verify_with_apple(receipt_data: str) -> Dict[str, Any]:
    """Validate a StoreKit receipt with Apple.

    Returns a dict: { valid: bool, status, expires_at, store_transaction_id,
    reason }.

    TODO(STORE-1 phase 2 / owner): implement against the App Store Server API
    (https://developer.apple.com/documentation/appstoreserverapi). Prefer the
    Server API over the legacy /verifyReceipt endpoint. Steps:
      1. Build a JWT signed with the App Store Connect API .p8 key.
      2. Call `GET /inApps/v1/subscriptions/{originalTransactionId}` (or decode
         the StoreKit2 signed transaction the client sent).
      3. Read the renewal info: product ID, expiresDate, auto-renew status.
      4. Map to { valid, status, expires_at, store_transaction_id }.
    Needs: APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (.p8),
    APPLE_BUNDLE_ID.
    """
    raise NotImplementedError(
        "Apple receipt verification not implemented — STORE-1 phase 2. "
        "Provision App Store Server API credentials and implement "
        "_verify_with_apple()."
    )


def _verify_with_google(purchase_token: str, product_id: str) -> Dict[str, Any]:
    """Validate a Google Play purchase token with the Play Developer API.

    Returns a dict: { valid: bool, status, expires_at, store_transaction_id,
    reason }.

    TODO(STORE-1 phase 2 / owner): implement against the Google Play Developer
    API `purchases.subscriptionsv2.get` (or `purchases.subscriptions.get`).
    Steps:
      1. Authenticate with the service-account JSON (scope
         androidpublisher).
      2. Call subscriptionsv2.get(packageName, token=purchase_token).
      3. Read lineItems -> productId + expiryTime, and subscriptionState.
      4. Map to { valid, status, expires_at, store_transaction_id }.
    Needs: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, ANDROID_PACKAGE_NAME.
    """
    raise NotImplementedError(
        "Google receipt verification not implemented — STORE-1 phase 2. "
        "Provision a Play Developer API service account and implement "
        "_verify_with_google()."
    )


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
                "(event predates last applied state)", store_transaction_id,
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
