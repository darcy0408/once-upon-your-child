"""
Tests for backend/encryption_utils.py — S-03 migration to authenticated
AES-256-GCM encryption for BYOK API keys.

Covers:
  * GCM round-trip (encrypt -> decrypt).
  * Legacy AES-256-CBC blobs still decrypt (backward compatibility).
  * A tampered GCM blob raises ValueError (tamper detection).
  * is_legacy_encrypted() format detection.
  * Lazy re-wrap: decrypt_user_api_key converts a legacy key to gcm: format.
"""

import base64
import os

import pytest
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

from backend.encryption_utils import (
    decrypt_api_key,
    decrypt_user_api_key,
    encrypt_api_key,
    is_legacy_encrypted,
)

# A deterministic 32-byte key (64 hex chars) for tests.
_TEST_KEY_HEX = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"

SAMPLE_KEY = "AIza" + ("a" * 35)


@pytest.fixture(autouse=True)
def _encryption_key_env(monkeypatch):
    """Provide a deterministic ENCRYPTION_KEY for every test in this module."""
    monkeypatch.setenv("ENCRYPTION_KEY", _TEST_KEY_HEX)


def _make_legacy_cbc_blob(plain_key: str) -> str:
    """Produce a blob in the pre-S-03 legacy AES-256-CBC format:
    base64(IV[16] + ciphertext). Mirrors the old encrypt_api_key().
    """
    key = bytes.fromhex(_TEST_KEY_HEX)
    iv = os.urandom(16)
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    padder = padding.PKCS7(128).padder()
    padded = padder.update(plain_key.encode("utf-8")) + padder.finalize()
    ciphertext = encryptor.update(padded) + encryptor.finalize()
    return base64.b64encode(iv + ciphertext).decode("utf-8")


# ---------------------------------------------------------------------------
# GCM round-trip
# ---------------------------------------------------------------------------


def test_gcm_round_trip():
    encrypted = encrypt_api_key(SAMPLE_KEY)
    assert encrypted.startswith("gcm:")
    assert decrypt_api_key(encrypted) == SAMPLE_KEY


def test_gcm_uses_fresh_nonce_each_time():
    """Two encryptions of the same plaintext must differ (random nonce)."""
    a = encrypt_api_key(SAMPLE_KEY)
    b = encrypt_api_key(SAMPLE_KEY)
    assert a != b
    assert decrypt_api_key(a) == decrypt_api_key(b) == SAMPLE_KEY


# ---------------------------------------------------------------------------
# Legacy CBC backward compatibility
# ---------------------------------------------------------------------------


def test_legacy_cbc_blob_still_decrypts():
    legacy = _make_legacy_cbc_blob(SAMPLE_KEY)
    assert not legacy.startswith("gcm:")
    assert decrypt_api_key(legacy) == SAMPLE_KEY


# ---------------------------------------------------------------------------
# Tamper detection
# ---------------------------------------------------------------------------


def test_tampered_gcm_blob_raises_value_error():
    encrypted = encrypt_api_key(SAMPLE_KEY)
    raw = base64.b64decode(encrypted[len("gcm:") :])
    # Flip a bit in the ciphertext/tag region (past the 12-byte nonce).
    tampered_raw = bytearray(raw)
    tampered_raw[-1] ^= 0x01
    tampered = "gcm:" + base64.b64encode(bytes(tampered_raw)).decode("utf-8")

    with pytest.raises(ValueError):
        decrypt_api_key(tampered)


def test_tampered_gcm_nonce_raises_value_error():
    encrypted = encrypt_api_key(SAMPLE_KEY)
    raw = bytearray(base64.b64decode(encrypted[len("gcm:") :]))
    raw[0] ^= 0x01  # corrupt the nonce
    tampered = "gcm:" + base64.b64encode(bytes(raw)).decode("utf-8")

    with pytest.raises(ValueError):
        decrypt_api_key(tampered)


# ---------------------------------------------------------------------------
# is_legacy_encrypted
# ---------------------------------------------------------------------------


def test_is_legacy_encrypted_for_gcm_blob():
    encrypted = encrypt_api_key(SAMPLE_KEY)
    assert is_legacy_encrypted(encrypted) is False


def test_is_legacy_encrypted_for_legacy_blob():
    legacy = _make_legacy_cbc_blob(SAMPLE_KEY)
    assert is_legacy_encrypted(legacy) is True


def test_is_legacy_encrypted_for_empty_string():
    assert is_legacy_encrypted("") is False
    assert is_legacy_encrypted(None) is False


# ---------------------------------------------------------------------------
# Lazy re-wrap via decrypt_user_api_key
# ---------------------------------------------------------------------------


def test_lazy_rewrap_converts_legacy_key_on_access(app):
    """Decrypting a User whose stored key is legacy-CBC must re-persist it
    in gcm: format while still returning the correct plaintext."""
    from backend.database import db
    from backend.models import User

    with app.app_context():
        user = User(
            id="byok_rewrap_user",
            username="byokrewrap",
            email="byokrewrap@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
            has_byok=True,
            gemini_api_key_encrypted=_make_legacy_cbc_blob(SAMPLE_KEY),
        )
        db.session.add(user)
        db.session.commit()

        assert is_legacy_encrypted(user.gemini_api_key_encrypted) is True

        plain = decrypt_user_api_key(user)
        assert plain == SAMPLE_KEY

        # Stored blob is now upgraded and persisted.
        refreshed = db.session.get(User, "byok_rewrap_user")
        assert refreshed.gemini_api_key_encrypted.startswith("gcm:")
        assert is_legacy_encrypted(refreshed.gemini_api_key_encrypted) is False
        assert decrypt_api_key(refreshed.gemini_api_key_encrypted) == SAMPLE_KEY


def test_lazy_rewrap_noop_for_gcm_key(app):
    """A key already in gcm: format must not be needlessly rewritten."""
    from backend.database import db
    from backend.models import User

    with app.app_context():
        gcm_blob = encrypt_api_key(SAMPLE_KEY)
        user = User(
            id="byok_gcm_user",
            username="byokgcm",
            email="byokgcm@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
            has_byok=True,
            gemini_api_key_encrypted=gcm_blob,
        )
        db.session.add(user)
        db.session.commit()

        plain = decrypt_user_api_key(user)
        assert plain == SAMPLE_KEY
        # Blob unchanged (no re-encrypt — same nonce/ciphertext).
        assert user.gemini_api_key_encrypted == gcm_blob


def test_lazy_rewrap_failure_is_non_fatal(app, monkeypatch):
    """A re-wrap failure must not break the caller — plaintext still returned."""
    import backend.encryption_utils as eu
    from backend.database import db
    from backend.models import User

    with app.app_context():
        user = User(
            id="byok_rewrap_fail_user",
            username="byokrewrapfail",
            email="byokrewrapfail@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
            has_byok=True,
            gemini_api_key_encrypted=_make_legacy_cbc_blob(SAMPLE_KEY),
        )
        db.session.add(user)
        db.session.commit()

        # Force the re-encrypt step to blow up.
        def _boom(_):
            raise RuntimeError("simulated re-wrap failure")

        monkeypatch.setattr(eu, "encrypt_api_key", _boom)

        # Caller still gets the correct plaintext despite the failed re-wrap.
        plain = decrypt_user_api_key(user)
        assert plain == SAMPLE_KEY


def test_decrypt_user_api_key_raises_when_no_stored_key(app):
    from backend.database import db
    from backend.models import User

    with app.app_context():
        user = User(
            id="byok_nokey_user",
            username="byoknokey",
            email="byoknokey@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
        )
        db.session.add(user)
        db.session.commit()

        with pytest.raises(ValueError):
            decrypt_user_api_key(user)
