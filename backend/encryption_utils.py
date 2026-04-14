"""
Encryption utilities for securely storing user API keys.
Uses AES-256-CBC encryption with PKCS7 padding.
"""
import os
import base64
import re
import logging
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding

logger = logging.getLogger(__name__)


def _get_encryption_key() -> bytes:
    """
    Get the encryption key from environment variable.
    The key should be a 32-byte (256-bit) random string.
    """
    key_str = os.getenv('ENCRYPTION_KEY')
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


def encrypt_api_key(plain_key: str) -> str:
    """
    Encrypt a plaintext API key using AES-256-CBC.
    
    Args:
        plain_key: The plaintext API key to encrypt
        
    Returns:
        Base64-encoded string containing IV + encrypted data
        Format: base64(IV + encrypted_data)
    """
    if not plain_key:
        raise ValueError("Cannot encrypt empty API key")
    
    # Get encryption key
    key = _get_encryption_key()
    
    # Generate random IV (16 bytes for AES)
    iv = os.urandom(16)
    
    # Create cipher
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    
    # Pad the plaintext to AES block size (16 bytes)
    padder = padding.PKCS7(128).padder()
    padded_data = padder.update(plain_key.encode('utf-8')) + padder.finalize()
    
    # Encrypt
    encrypted_data = encryptor.update(padded_data) + encryptor.finalize()
    
    # Combine IV + encrypted data and encode as base64
    result = base64.b64encode(iv + encrypted_data).decode('utf-8')
    
    logger.info("API key encrypted successfully")
    return result


def decrypt_api_key(encrypted_key: str) -> str:
    """
    Decrypt an encrypted API key.
    
    Args:
        encrypted_key: Base64-encoded string containing IV + encrypted data
        
    Returns:
        Decrypted plaintext API key
    """
    if not encrypted_key:
        raise ValueError("Cannot decrypt empty string")
    
    try:
        # Get encryption key
        key = _get_encryption_key()
        
        # Decode from base64
        encrypted_blob = base64.b64decode(encrypted_key)
        
        # Extract IV (first 16 bytes) and encrypted data (rest)
        iv = encrypted_blob[:16]
        encrypted_data = encrypted_blob[16:]
        
        # Create cipher
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()
        
        # Decrypt
        padded_data = decryptor.update(encrypted_data) + decryptor.finalize()
        
        # Unpad
        unpadder = padding.PKCS7(128).unpadder()
        plain_data = unpadder.update(padded_data) + unpadder.finalize()
        
        return plain_data.decode('utf-8')
        
    except Exception as e:
        logger.error(f"Failed to decrypt API key: {e}")
        raise ValueError(f"Decryption failed: {e}")


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
    pattern = r'^AIza[A-Za-z0-9_-]{35}$'
    
    if re.match(pattern, key):
        return True
    
    logger.warning(f"API key format validation failed. Length: {len(key)}, Starts with AIza: {key.startswith('AIza') if key else False}")
    return False


def test_gemini_api_key(api_key: str) -> tuple[bool, str]:
    """
    Test an API key by making a minimal request to the Gemini API.

    Args:
        api_key: The API key to test

    Returns:
        Tuple of (is_valid, error_message)
        If valid: (True, "")
        If invalid: (False, "error description")
    """
    from google import genai
    from google.genai import types

    try:
        # Create client with the test key
        client = genai.Client(api_key=api_key)

        # Make a minimal API call to verify the key works
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents="Respond with just the word 'OK' if you can read this.",
            config=types.GenerateContentConfig(
                max_output_tokens=10,
                temperature=0.0,
            )
        )

        # If we got here, the key is valid
        text = getattr(response, 'text', '')
        logger.info(f"API key test successful. Response: {text[:50]}")
        return (True, "")

    except Exception as e:
        error_msg = str(e)
        logger.warning(f"API key test failed: {error_msg}")

        # Provide user-friendly error messages
        if "API_KEY_INVALID" in error_msg or "invalid" in error_msg.lower():
            return (False, "Invalid API key. Please check your key and try again.")
        elif "quota" in error_msg.lower() or "429" in error_msg:
            return (False, "API key is valid but quota exceeded. Please check your Google Cloud quota.")
        elif "permission" in error_msg.lower() or "403" in error_msg:
            return (False, "API key doesn't have permission to use Gemini API.")
        else:
            return (False, f"API key test failed: {error_msg}")
