"""
Encryption utilities for securely storing user API keys.

New API keys are encrypted with authenticated AES-256-GCM, which provides
tamper detection (S-03). Legacy keys encrypted with the older unauthenticated
AES-256-CBC scheme are still decryptable for backward compatibility, and are
lazily re-wrapped into GCM format on first access.
"""

import base64
import logging
import os
import re

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger(__name__)

# GCM blob format: the literal string prefix below, followed by
# base64(nonce[12] + ciphertext_with_tag). A legacy CBC blob is pure base64
# and can never contain a ':', so this prefix is collision-free.
_GCM_PREFIX = "gcm:"
_GCM_NONCE_BYTES = 12


def _get_encryption_key() -> bytes:
    """
    Get the encryption key from environment variable.
    The key should be a 32-byte (256-bit) random string.
    """
    key_str = os.getenv("ENCRYPTION_KEY")
    if not key_str:
        raise ValueError(
            "ENCRYPTION_KEY environment variable not set. "
            "Generate one with: python -c 'import secrets; print(secrets.token_hex(32))'"
        )

    # Convert hex string to bytes (should be 64 hex chars = 32 bytes)
    try:
        key_bytes = bytes.fromhex(key_str)
        if len(key_bytes) != 32:
            raise ValueError(f"Encryption key must be 32 bytes, got {len(key_bytes)}")
        return key_bytes
    except ValueError as e:
        raise ValueError(f"Invalid ENCRYPTION_KEY format: {e}")


def is_legacy_encrypted(encrypted_key: str) -> bool:
    """
    Return True if the stored blob uses the legacy (unauthenticated
    AES-256-CBC) format rather than the current AES-256-GCM format.

    A legacy blob is plain base64 and never starts with the "gcm:" prefix.
    """
    if not encrypted_key:
        return False
    return not encrypted_key.startswith(_GCM_PREFIX)


def encrypt_api_key(plain_key: str) -> str:
    """
    Encrypt a plaintext API key using authenticated AES-256-GCM.

    Args:
        plain_key: The plaintext API key to encrypt

    Returns:
        A string of the form "gcm:" + base64(nonce[12] + ciphertext_with_tag).
        The GCM tag (appended to the ciphertext by AESGCM) gives tamper
        detection: any modification makes decryption raise ValueError.
    """
    if not plain_key:
        raise ValueError("Cannot encrypt empty API key")

    # Get encryption key (32 bytes from ENCRYPTION_KEY env var)
    key = _get_encryption_key()

    # Generate a random 96-bit nonce (recommended size for GCM)
    nonce = os.urandom(_GCM_NONCE_BYTES)

    # AESGCM.encrypt returns ciphertext with the 16-byte auth tag appended
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plain_key.encode("utf-8"), None)

    result = _GCM_PREFIX + base64.b64encode(nonce + ciphertext).decode("utf-8")

    logger.info("API key encrypted successfully (AES-256-GCM)")
    return result


def _decrypt_gcm(encrypted_key: str) -> str:
    """Decrypt a "gcm:"-prefixed AES-256-GCM blob."""
    key = _get_encryption_key()

    blob = base64.b64decode(encrypted_key[len(_GCM_PREFIX) :])
    nonce = blob[:_GCM_NONCE_BYTES]
    ciphertext = blob[_GCM_NONCE_BYTES:]

    aesgcm = AESGCM(key)
    # Raises cryptography.exceptions.InvalidTag if the blob was tampered with.
    plain = aesgcm.decrypt(nonce, ciphertext, None)
    return plain.decode("utf-8")


def _decrypt_cbc_legacy(encrypted_key: str) -> str:
    """Decrypt a legacy (pre-S-03) unauthenticated AES-256-CBC blob.

    Format: base64(IV[16] + ciphertext). Kept for backward compatibility with
    keys stored before the GCM migration.
    """
    key = _get_encryption_key()

    encrypted_blob = base64.b64decode(encrypted_key)

    # Extract IV (first 16 bytes) and encrypted data (rest)
    iv = encrypted_blob[:16]
    encrypted_data = encrypted_blob[16:]

    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    padded_data = decryptor.update(encrypted_data) + decryptor.finalize()

    unpadder = padding.PKCS7(128).unpadder()
    plain_data = unpadder.update(padded_data) + unpadder.finalize()

    return plain_data.decode("utf-8")


def decrypt_api_key(encrypted_key: str) -> str:
    """
    Decrypt an encrypted API key.

    Detects the format by prefix: a "gcm:" prefix selects the authenticated
    AES-256-GCM path; anything else is treated as a legacy AES-256-CBC blob.

    Args:
        encrypted_key: The stored encrypted key (GCM or legacy CBC format)

    Returns:
        Decrypted plaintext API key

    Raises:
        ValueError: on any decryption failure, including a GCM auth-tag
            mismatch (tamper detection) — there is NO silent fallback.
    """
    if not encrypted_key:
        raise ValueError("Cannot decrypt empty string")

    try:
        if encrypted_key.startswith(_GCM_PREFIX):
            return _decrypt_gcm(encrypted_key)
        return _decrypt_cbc_legacy(encrypted_key)
    except Exception as e:
        logger.error(f"Failed to decrypt API key: {e}")
        raise ValueError(f"Decryption failed: {e}")


def decrypt_user_api_key(user, db_session=None) -> str:
    """
    Decrypt a User's stored BYOK API key, lazily re-wrapping legacy blobs.

    This is the single entry point any route/task should use when loading a
    stored BYOK key from a ``User`` record. If the stored key is in the legacy
    AES-256-CBC format, it is transparently re-encrypted with AES-256-GCM and
    persisted back to the user row so the legacy blob is retired on first use
    (lazy migration, no downtime).

    A re-wrap failure (e.g. a transient DB error) NEVER breaks the caller: the
    decrypted plaintext is still returned and the re-wrap is simply retried on
    the next access.

    Args:
        user: A ``User`` model instance with ``gemini_api_key_encrypted``.
        db_session: SQLAlchemy session used to persist the re-wrap. Defaults
            to ``backend.database.db.session`` when omitted.

    Returns:
        The decrypted plaintext API key.

    Raises:
        ValueError: if there is no stored key, or decryption fails (including
            a GCM tamper-detection failure).
    """
    encrypted = getattr(user, "gemini_api_key_encrypted", None)
    if not encrypted:
        raise ValueError("User has no stored API key")

    plain_key = decrypt_api_key(encrypted)

    # Lazy re-wrap: a successful legacy decrypt means we can safely upgrade.
    if is_legacy_encrypted(encrypted):
        try:
            if db_session is None:
                try:
                    from backend.database import db as _db
                except ImportError:
                    from database import db as _db
                db_session = _db.session

            user.gemini_api_key_encrypted = encrypt_api_key(plain_key)
            db_session.commit()
            logger.info(
                "Lazily re-wrapped legacy CBC API key to AES-256-GCM "
                f"for user {getattr(user, 'id', '<unknown>')}"
            )
        except Exception as e:
            # Re-wrap is best-effort — never fail the caller's request.
            logger.warning(f"Lazy API-key re-wrap failed (non-fatal): {e}")
            try:
                if db_session is not None:
                    db_session.rollback()
            except Exception:
                pass

    return plain_key


def validate_gemini_api_key_format(key: str) -> bool:
    """
    Validate that an API key matches the expected Gemini API key format.

    Gemini API keys typically start with 'AIza' and are 39 characters long.
    Example: AIzaSyAbc123...

    Args:
        key: The API key to validate

    Returns:
        True if the format is valid, False otherwise
    """
    if not key or not isinstance(key, str):
        return False

    # Gemini API keys: AIza[A-Za-z0-9_-]{35}
    pattern = r"^AIza[A-Za-z0-9_-]{35}$"

    if re.match(pattern, key):
        return True

    logger.warning(
        f"API key format validation failed. Length: {len(key)}, Starts with AIza: {key.startswith('AIza') if key else False}"
    )
    return False


def test_gemini_api_key(api_key: str) -> tuple[bool, str]:
    """
    Test an API key by listing available models via the Gemini API.

    Args:
        api_key: The API key to test

    Returns:
        Tuple of (is_valid, error_message)
        If valid: (True, "")
        If invalid: (False, "error description")
    """
    from google import genai

    try:
        client = genai.Client(api_key=api_key)

        # Listing models is the lightest possible authenticated call —
        # no content generation, no response-parsing edge cases.
        models = list(client.models.list())
        logger.info(f"API key test successful. Found {len(models)} models.")
        return (True, "")

    except Exception as e:
        error_msg = str(e)
        logger.warning(f"API key test failed: {error_msg}")

        if "API_KEY_INVALID" in error_msg or "invalid" in error_msg.lower():
            return (False, "Invalid API key. Please check your key and try again.")
        elif "quota" in error_msg.lower() or "429" in error_msg:
            return (
                False,
                "API key is valid but quota exceeded. Please check your Google Cloud quota.",
            )
        elif "permission" in error_msg.lower() or "403" in error_msg:
            return (False, "API key doesn't have permission to use Gemini API.")
        else:
            return (False, f"API key test failed: {error_msg}")
