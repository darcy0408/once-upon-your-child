"""Tests for the IAP S2S notification verification gate — S-06 (audit 03).

Covers `backend/utils/iap_notification_verify.py` and the verification gate
wired into the `/api/iap/apple/notifications` and `/api/iap/google/notifications`
endpoints in `backend/routes/iap_routes.py`.

The endpoints used to ACK 200 with no signature verification. After S-06:
  * invalid / missing Apple JWS              -> 403
  * invalid / missing Google OIDC token      -> 403
  * missing verification config (root CA /
    GOOGLE_PUBSUB_AUDIENCE)                  -> 503 (fail CLOSED, never 200)
  * a genuinely verifiable request           -> 200 stub ACK (handled: False)

Apple JWS signing in these tests uses a *self-signed* throwaway EC chain plus a
synthetic "root CA" so the full chain-validation code path is exercised without
Apple's real private keys. The Google path is exercised by monkeypatching
`google.oauth2.id_token.verify_oauth2_token`.
"""

import base64
import json
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from backend.utils import iap_notification_verify as verify_mod
from backend.utils.iap_notification_verify import (
    IapVerificationConfigError,
    IapVerificationError,
    verify_apple_jws,
)

APPLE_URL = "/api/iap/apple/notifications"
GOOGLE_URL = "/api/iap/google/notifications"


# ===========================================================================
# Self-signed Apple-style certificate chain helpers
# ===========================================================================


def _make_ec_key():
    return ec.generate_private_key(ec.SECP256R1())


def _make_cert(subject_cn, issuer_cn, subject_key, issuer_key, *, days=3650):
    """Build an X.509 cert: subject signed by issuer_key. Self-signed if equal."""
    now = datetime.now(timezone.utc)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, subject_cn)])
    issuer = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, issuer_cn)])
    builder = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(subject_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=1))
        .not_valid_after(now + timedelta(days=days))
    )
    return builder.sign(issuer_key, hashes.SHA256())


def _cert_der_b64(cert):
    return base64.b64encode(cert.public_bytes(serialization.Encoding.DER)).decode(
        "ascii"
    )


@pytest.fixture
def apple_chain(tmp_path, monkeypatch):
    """A throwaway root -> intermediate -> leaf EC chain.

    The synthetic root cert is written to disk and APPLE_ROOT_CA_PATH is
    pointed at it so `verify_apple_jws` trusts it. Returns the leaf private key
    and the x5c list (leaf, intermediate) Apple would place in the JWS header.
    """
    root_key = _make_ec_key()
    inter_key = _make_ec_key()
    leaf_key = _make_ec_key()

    root_cert = _make_cert("Test Apple Root", "Test Apple Root", root_key, root_key)
    inter_cert = _make_cert(
        "Test Apple Intermediate", "Test Apple Root", inter_key, root_key
    )
    leaf_cert = _make_cert(
        "Test Apple Leaf", "Test Apple Intermediate", leaf_key, inter_key
    )

    root_path = tmp_path / "TestAppleRoot.cer"
    root_path.write_bytes(root_cert.public_bytes(serialization.Encoding.DER))
    monkeypatch.setenv("APPLE_ROOT_CA_PATH", str(root_path))

    x5c = [_cert_der_b64(leaf_cert), _cert_der_b64(inter_cert)]
    return {"leaf_key": leaf_key, "x5c": x5c, "root_path": str(root_path)}


def _sign_apple_jws(payload, leaf_key, x5c):
    """Sign a payload as Apple would: ES256 JWS with an x5c header."""
    return jwt.encode(
        payload,
        leaf_key,
        algorithm="ES256",
        headers={"x5c": x5c},
    )


# ===========================================================================
# Apple — verify_apple_jws unit tests
# ===========================================================================


def test_apple_jws_valid_chain_returns_payload(apple_chain):
    payload = {"notificationType": "DID_RENEW", "notificationUUID": "abc-123"}
    token = _sign_apple_jws(payload, apple_chain["leaf_key"], apple_chain["x5c"])
    decoded = verify_apple_jws(token)
    assert decoded["notificationType"] == "DID_RENEW"
    assert decoded["notificationUUID"] == "abc-123"


def test_apple_jws_missing_payload_raises():
    with pytest.raises(IapVerificationError):
        verify_apple_jws("")
    with pytest.raises(IapVerificationError):
        verify_apple_jws(None)


def test_apple_jws_malformed_raises(apple_chain):
    with pytest.raises(IapVerificationError):
        verify_apple_jws("not.a.jws.token")
    with pytest.raises(IapVerificationError):
        verify_apple_jws("onlyonesegment")


def test_apple_jws_no_x5c_header_raises(apple_chain):
    """A JWS signed without an x5c chain must be rejected."""
    payload = {"notificationType": "DID_RENEW"}
    token = jwt.encode(payload, apple_chain["leaf_key"], algorithm="ES256")
    with pytest.raises(IapVerificationError):
        verify_apple_jws(token)


def test_apple_jws_untrusted_root_raises(tmp_path, monkeypatch):
    """A chain that does NOT terminate at the trusted root is rejected."""
    # Build a complete self-consistent chain but trust a DIFFERENT root.
    root_key = _make_ec_key()
    leaf_key = _make_ec_key()
    root_cert = _make_cert("Rogue Root", "Rogue Root", root_key, root_key)
    leaf_cert = _make_cert("Rogue Leaf", "Rogue Root", leaf_key, root_key)
    x5c = [_cert_der_b64(leaf_cert)]

    # Trust an unrelated root.
    other_root_key = _make_ec_key()
    other_root = _make_cert("Real Root", "Real Root", other_root_key, other_root_key)
    root_path = tmp_path / "RealRoot.cer"
    root_path.write_bytes(other_root.public_bytes(serialization.Encoding.DER))
    monkeypatch.setenv("APPLE_ROOT_CA_PATH", str(root_path))

    token = _sign_apple_jws({"x": 1}, leaf_key, x5c)
    with pytest.raises(IapVerificationError):
        verify_apple_jws(token)


def test_apple_jws_signature_mismatch_raises(apple_chain):
    """A JWS signed by a key OTHER than the leaf in the x5c header is rejected."""
    wrong_key = _make_ec_key()
    token = _sign_apple_jws({"x": 1}, wrong_key, apple_chain["x5c"])
    with pytest.raises(IapVerificationError):
        verify_apple_jws(token)


def test_apple_jws_missing_root_ca_raises_config_error(tmp_path, monkeypatch):
    """When the Apple root CA file is absent, fail CLOSED with a config error."""
    monkeypatch.setenv("APPLE_ROOT_CA_PATH", str(tmp_path / "does-not-exist.cer"))
    # A syntactically valid JWS still triggers the config error first because
    # the root CA load happens before signature verification.
    leaf_key = _make_ec_key()
    leaf_cert = _make_cert("Leaf", "Leaf", leaf_key, leaf_key)
    token = _sign_apple_jws({"x": 1}, leaf_key, [_cert_der_b64(leaf_cert)])
    with pytest.raises(IapVerificationConfigError):
        verify_apple_jws(token)


def test_bundled_apple_root_ca_is_present_and_parses():
    """The bundled AppleRootCA-G3.cer asset must exist and be a valid cert."""
    import os

    path = verify_mod._DEFAULT_APPLE_ROOT_CA
    assert os.path.exists(
        path
    ), "AppleRootCA-G3.cer must be bundled next to iap_notification_verify.py"
    cert = verify_mod._load_apple_root_ca()
    assert "Apple Root CA" in cert.subject.rfc4514_string()


# ===========================================================================
# Apple — endpoint gate tests
# ===========================================================================


def test_apple_endpoint_missing_jws_returns_403(client):
    resp = client.post(APPLE_URL, json={})
    assert resp.status_code == 403


def test_apple_endpoint_invalid_jws_returns_403(client, apple_chain):
    resp = client.post(APPLE_URL, json={"signedPayload": "garbage.jws.value"})
    assert resp.status_code == 403


def test_apple_endpoint_missing_root_ca_returns_503(client, tmp_path, monkeypatch):
    monkeypatch.setenv("APPLE_ROOT_CA_PATH", str(tmp_path / "missing.cer"))
    leaf_key = _make_ec_key()
    leaf_cert = _make_cert("Leaf", "Leaf", leaf_key, leaf_key)
    token = _sign_apple_jws({"x": 1}, leaf_key, [_cert_der_b64(leaf_cert)])
    resp = client.post(APPLE_URL, json={"signedPayload": token})
    assert resp.status_code == 503
    assert b"not configured" in resp.data


def test_apple_endpoint_valid_jws_acks_200(client, apple_chain):
    payload = {"notificationType": "DID_RENEW", "notificationUUID": "uuid-1"}
    token = _sign_apple_jws(payload, apple_chain["leaf_key"], apple_chain["x5c"])
    resp = client.post(APPLE_URL, json={"signedPayload": token})
    assert resp.status_code == 200
    # The phase-1 stub must still NOT claim to have handled entitlement.
    assert resp.get_json().get("handled") is False


# ===========================================================================
# Google — endpoint gate tests
# ===========================================================================


def _install_fake_google_verifier(monkeypatch, *, claims=None, raises=False):
    """Monkeypatch google.oauth2.id_token.verify_oauth2_token."""
    from google.oauth2 import id_token as google_id_token

    def _fake(token, request, audience=None, **kwargs):
        if raises:
            raise ValueError("invalid token")
        result = dict(claims or {})
        result.setdefault("iss", "https://accounts.google.com")
        result.setdefault("aud", audience)
        return result

    monkeypatch.setattr(google_id_token, "verify_oauth2_token", _fake)


def test_google_endpoint_missing_audience_config_returns_503(client, monkeypatch):
    monkeypatch.delenv("GOOGLE_PUBSUB_AUDIENCE", raising=False)
    resp = client.post(
        GOOGLE_URL,
        json={"message": {"data": "e30="}},
        headers={"Authorization": "Bearer some-token"},
    )
    assert resp.status_code == 503
    assert b"not configured" in resp.data


def test_google_endpoint_missing_bearer_token_returns_403(client, monkeypatch):
    monkeypatch.setenv("GOOGLE_PUBSUB_AUDIENCE", "https://sw.example/iap/google")
    resp = client.post(GOOGLE_URL, json={"message": {"data": "e30="}})
    assert resp.status_code == 403


def test_google_endpoint_invalid_token_returns_403(client, monkeypatch):
    monkeypatch.setenv("GOOGLE_PUBSUB_AUDIENCE", "https://sw.example/iap/google")
    _install_fake_google_verifier(monkeypatch, raises=True)
    resp = client.post(
        GOOGLE_URL,
        json={"message": {"data": "e30="}},
        headers={"Authorization": "Bearer bad-token"},
    )
    assert resp.status_code == 403


def test_google_endpoint_wrong_issuer_returns_403(client, monkeypatch):
    monkeypatch.setenv("GOOGLE_PUBSUB_AUDIENCE", "https://sw.example/iap/google")
    _install_fake_google_verifier(
        monkeypatch, claims={"iss": "https://evil.example", "email": "x@y.z"}
    )
    resp = client.post(
        GOOGLE_URL,
        json={"message": {"data": "e30="}},
        headers={"Authorization": "Bearer token"},
    )
    assert resp.status_code == 403


def test_google_endpoint_valid_token_acks_200(client, monkeypatch):
    monkeypatch.setenv("GOOGLE_PUBSUB_AUDIENCE", "https://sw.example/iap/google")
    _install_fake_google_verifier(
        monkeypatch,
        claims={"email": "pubsub@gserviceaccount.com", "email_verified": True},
    )
    resp = client.post(
        GOOGLE_URL,
        json={"message": {"data": "e30="}},
        headers={"Authorization": "Bearer good-token"},
    )
    assert resp.status_code == 200
    assert resp.get_json().get("handled") is False
