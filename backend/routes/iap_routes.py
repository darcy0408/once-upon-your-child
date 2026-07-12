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

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

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
        IapPurchase,
    )
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
        IapPurchase,
    )
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
            tier=(
                tier if status in ("active", "trialing", "grace_period") else FREE_TIER
            ),
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
