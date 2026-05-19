"""Server-to-server IAP notification verification — S-06 (audit 03).

The Apple App Store Server Notifications V2 and Google Real-Time Developer
Notification endpoints in `routes/iap_routes.py` accept unauthenticated POSTs.
Before any phase-2 entitlement logic is added, the incoming request MUST be
proven to actually come from Apple / Google. This module provides the two
verification primitives:

  * `verify_apple_jws()`           — verify the App Store V2 `signedPayload`
                                     JWS (x5c chain -> Apple root CA -> leaf
                                     signature).
  * `verify_google_pubsub_oidc()`  — verify the OIDC bearer token on a Google
                                     Cloud Pub/Sub push request.

Both raise `IapVerificationError` on any failure. The route layer turns that
into an HTTP 403. A *configuration* problem (missing root CA, missing audience
env var) raises `IapVerificationConfigError` — the route layer turns that into
an HTTP 503 so the endpoint fails CLOSED rather than blind-ACKing 200.

Dependencies: `cryptography` and `PyJWT` (already pinned in
backend/requirements.txt); `google-auth` for the Google OIDC path (also already
pinned). No new dependency is introduced by this module.
"""
from __future__ import annotations

import base64
import json
import logging
import os
from typing import Any, Dict, List, Optional

import jwt
from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

logger = logging.getLogger("iap_notification_verify")


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------

class IapVerificationError(Exception):
    """The notification could not be proven authentic -> caller returns 403."""


class IapVerificationConfigError(Exception):
    """Verification is not configured (missing root CA / env) -> caller 503.

    Distinct from `IapVerificationError` so the route layer can fail CLOSED
    with a 503 instead of a 403 — a 403 would tell Apple/Google the request
    was rejected; a 503 tells them to retry once the operator fixes config.
    """


# ===========================================================================
# Apple — App Store Server Notifications V2 (signedPayload JWS)
# ===========================================================================

# Apple's public root CA. The .cer is bundled next to this module; it is a
# public certificate (https://www.apple.com/certificateauthority/AppleRootCA-G3.cer).
# An operator may override the location with APPLE_ROOT_CA_PATH.
_DEFAULT_APPLE_ROOT_CA = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "AppleRootCA-G3.cer"
)


def _load_apple_root_ca() -> x509.Certificate:
    """Load Apple's root CA certificate.

    Raises `IapVerificationConfigError` (-> HTTP 503) if the cert file is
    missing or unreadable. If the bundled `AppleRootCA-G3.cer` is absent the
    operator must add it from
    https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
    or point APPLE_ROOT_CA_PATH at it.
    """
    path = os.getenv("APPLE_ROOT_CA_PATH", _DEFAULT_APPLE_ROOT_CA)
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
    except OSError as exc:
        raise IapVerificationConfigError(
            "Apple root CA certificate not available at %r — add "
            "AppleRootCA-G3.cer (from "
            "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer) "
            "or set APPLE_ROOT_CA_PATH." % path
        ) from exc

    # The asset may be DER (.cer) or PEM depending on how the operator saved it.
    try:
        return x509.load_der_x509_certificate(raw)
    except ValueError:
        try:
            return x509.load_pem_x509_certificate(raw)
        except ValueError as exc:
            raise IapVerificationConfigError(
                "Apple root CA at %r is not a valid DER/PEM certificate." % path
            ) from exc


def _b64url_decode(segment: str) -> bytes:
    """Decode a base64url segment, tolerating missing padding."""
    pad = "=" * (-len(segment) % 4)
    return base64.urlsafe_b64decode(segment + pad)


def _certs_from_x5c(x5c: List[str]) -> List[x509.Certificate]:
    """Parse the x5c header (list of base64 DER certs) into certificates.

    Per RFC 7515 the x5c entries are base64 (NOT base64url) DER. The first
    entry is the leaf, the last is the (intermediate or) closest-to-root cert.
    """
    certs: List[x509.Certificate] = []
    for entry in x5c:
        try:
            der = base64.b64decode(entry)
            certs.append(x509.load_der_x509_certificate(der))
        except (ValueError, Exception) as exc:  # noqa: BLE001
            raise IapVerificationError(
                "x5c entry is not a valid DER certificate"
            ) from exc
    return certs


def _public_key_matches(child_issuer_key, signed_cert: x509.Certificate) -> bool:
    """Verify `signed_cert` was signed by the private key of `child_issuer_key`.

    Supports the EC and RSA key types Apple uses for this chain.
    """
    try:
        if isinstance(child_issuer_key, ec.EllipticCurvePublicKey):
            child_issuer_key.verify(
                signed_cert.signature,
                signed_cert.tbs_certificate_bytes,
                ec.ECDSA(signed_cert.signature_hash_algorithm),
            )
        elif isinstance(child_issuer_key, rsa.RSAPublicKey):
            child_issuer_key.verify(
                signed_cert.signature,
                signed_cert.tbs_certificate_bytes,
                padding.PKCS1v15(),
                signed_cert.signature_hash_algorithm,
            )
        else:
            raise IapVerificationError(
                "Unsupported certificate key type in x5c chain: %s"
                % type(child_issuer_key).__name__
            )
        return True
    except InvalidSignature:
        return False


def _validate_apple_chain(
    x5c_certs: List[x509.Certificate], root_ca: x509.Certificate
) -> x509.Certificate:
    """Validate the x5c chain and return the verified leaf certificate.

    The chain is [leaf, intermediate(s)..., closest-to-root]. We verify each
    cert is signed by the next one up, then verify the top of the supplied
    chain is signed by the trusted Apple root CA. Expiry windows are checked.
    Returns the leaf certificate on success; raises `IapVerificationError`.
    """
    if not x5c_certs:
        raise IapVerificationError("JWS x5c certificate chain is empty")

    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    for cert in x5c_certs:
        # cryptography >= 42 exposes the tz-aware *_utc accessors.
        not_before = getattr(cert, "not_valid_before_utc", None) or \
            cert.not_valid_before.replace(tzinfo=timezone.utc)
        not_after = getattr(cert, "not_valid_after_utc", None) or \
            cert.not_valid_after.replace(tzinfo=timezone.utc)
        if now < not_before or now > not_after:
            raise IapVerificationError(
                "A certificate in the x5c chain is expired or not yet valid"
            )

    # Walk the chain: each cert must be signed by the next one up.
    for i in range(len(x5c_certs) - 1):
        child = x5c_certs[i]
        issuer = x5c_certs[i + 1]
        if child.issuer != issuer.subject:
            raise IapVerificationError(
                "x5c chain is not contiguous (issuer/subject mismatch)"
            )
        if not _public_key_matches(issuer.public_key(), child):
            raise IapVerificationError(
                "x5c chain link failed signature verification"
            )

    # The top of the supplied chain must chain to the trusted Apple root.
    top = x5c_certs[-1]
    if top.issuer != root_ca.subject:
        raise IapVerificationError(
            "x5c chain does not terminate at the Apple root CA"
        )
    if not _public_key_matches(root_ca.public_key(), top):
        raise IapVerificationError(
            "x5c chain top is not signed by the Apple root CA"
        )

    return x5c_certs[0]


def verify_apple_jws(signed_payload: str) -> Dict[str, Any]:
    """Verify an App Store Server Notifications V2 `signedPayload` JWS.

    Steps:
      1. Split the JWS, read the protected header, extract the `x5c` chain.
      2. Validate the x5c chain up to the bundled Apple root CA (AppleRootCA-G3).
      3. Verify the JWS signature with the leaf certificate's public key, using
         the header `alg` (Apple signs these with ES256).
      4. Return the decoded payload dict.

    Raises:
      IapVerificationConfigError — Apple root CA not available (-> HTTP 503).
      IapVerificationError       — any authenticity failure (-> HTTP 403).
    """
    if not signed_payload or not isinstance(signed_payload, str):
        raise IapVerificationError("Missing Apple signedPayload JWS")

    parts = signed_payload.split(".")
    if len(parts) != 3:
        raise IapVerificationError("signedPayload is not a well-formed JWS")

    # --- Read the protected header ----------------------------------------
    try:
        header = json.loads(_b64url_decode(parts[0]))
    except (ValueError, json.JSONDecodeError) as exc:
        raise IapVerificationError("signedPayload header is not valid JSON") from exc

    alg = header.get("alg")
    if alg in (None, "none"):
        raise IapVerificationError("signedPayload header has no usable alg")

    x5c = header.get("x5c")
    if not x5c or not isinstance(x5c, list):
        raise IapVerificationError("signedPayload header is missing the x5c chain")

    # --- Validate the certificate chain -----------------------------------
    # _load_apple_root_ca raises IapVerificationConfigError (-> 503) on its own.
    root_ca = _load_apple_root_ca()
    x5c_certs = _certs_from_x5c(x5c)
    leaf = _validate_apple_chain(x5c_certs, root_ca)

    # --- Verify the JWS signature with the (now trusted) leaf key ---------
    leaf_pubkey = leaf.public_key()
    leaf_pem = leaf_pubkey.public_bytes(
        Encoding.PEM, PublicFormat.SubjectPublicKeyInfo
    )
    try:
        payload = jwt.decode(
            signed_payload,
            key=leaf_pem,
            algorithms=[alg],
            # The payload carries no aud/exp/iss registered claims; Apple's
            # authenticity guarantee is the cert chain + signature.
            options={"verify_aud": False, "verify_exp": False, "verify_iss": False},
        )
    except jwt.InvalidAlgorithmError as exc:
        raise IapVerificationError("signedPayload uses an unsupported alg") from exc
    except jwt.PyJWTError as exc:
        raise IapVerificationError(
            "signedPayload JWS signature verification failed"
        ) from exc

    return payload


# ===========================================================================
# Google — Real-Time Developer Notifications (Pub/Sub push OIDC token)
# ===========================================================================

def _expected_google_audience() -> str:
    """Return the configured expected OIDC audience for the Pub/Sub push.

    Raises `IapVerificationConfigError` (-> HTTP 503) when unset, so a
    Google notification endpoint without configured verification fails CLOSED.
    """
    aud = (os.getenv("GOOGLE_PUBSUB_AUDIENCE") or "").strip()
    if not aud:
        raise IapVerificationConfigError(
            "GOOGLE_PUBSUB_AUDIENCE is not set — Google Pub/Sub push "
            "verification is not configured."
        )
    return aud


def _bearer_token_from_request(request) -> str:
    """Extract the bearer token from the request's Authorization header."""
    auth = request.headers.get("Authorization", "") or ""
    parts = auth.split(None, 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        raise IapVerificationError(
            "Google Pub/Sub push request has no bearer OIDC token"
        )
    return parts[1].strip()


def verify_google_pubsub_oidc(request) -> Dict[str, Any]:
    """Verify the OIDC bearer token on a Google Cloud Pub/Sub push request.

    Google Real-Time Developer Notifications are delivered as a Pub/Sub push
    whose HTTP request carries `Authorization: Bearer <OIDC JWT>`. The token is
    a Google-signed OIDC JWT; we verify its signature against Google's public
    certs and check the audience matches `GOOGLE_PUBSUB_AUDIENCE`.

    Returns the verified token claims.

    Raises:
      IapVerificationConfigError — GOOGLE_PUBSUB_AUDIENCE unset (-> HTTP 503).
      IapVerificationError       — token missing/invalid (-> HTTP 403).
    """
    expected_audience = _expected_google_audience()  # may raise 503
    token = _bearer_token_from_request(request)

    # Imported here so the Apple path has no hard dependency on google-auth.
    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ImportError as exc:  # pragma: no cover - dependency is pinned
        raise IapVerificationConfigError(
            "google-auth is not installed — cannot verify Google OIDC tokens."
        ) from exc

    try:
        claims = google_id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            audience=expected_audience,
        )
    except ValueError as exc:
        # verify_oauth2_token raises ValueError for bad signature, wrong
        # audience, expired token, etc.
        raise IapVerificationError(
            "Google Pub/Sub OIDC token verification failed: %s" % exc
        ) from exc

    # Defence in depth: verify_oauth2_token already checks the issuer, but be
    # explicit so a future google-auth change can't silently relax it.
    issuer = claims.get("iss")
    if issuer not in ("https://accounts.google.com", "accounts.google.com"):
        raise IapVerificationError(
            "Google Pub/Sub OIDC token has an unexpected issuer"
        )

    return claims
