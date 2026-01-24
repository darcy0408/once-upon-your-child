# backend/utils/error_codes.py
"""Standardized error codes for structured API responses."""


class ErrorCodes:
    """Error code constants for the Story Weaver API."""

    # Mode validation errors
    MODE_INVALID = "ERR_MODE_INVALID"

    # Authentication/Authorization errors
    UNAUTHORIZED = "ERR_UNAUTHORIZED"
    AUTH_REQUIRED = "ERR_AUTH_REQUIRED"

    # Rate limiting errors
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"
    QUOTA_EXCEEDED = "QUOTA_EXCEEDED"

    # Input validation errors
    INVALID_INPUT = "ERR_INVALID_INPUT"
    MISSING_FIELD = "ERR_MISSING_FIELD"

    # Resource errors
    NOT_FOUND = "ERR_NOT_FOUND"
    CHARACTER_NOT_FOUND = "ERR_CHARACTER_NOT_FOUND"
    STORY_NOT_FOUND = "ERR_STORY_NOT_FOUND"

    # Server errors
    INTERNAL_ERROR = "ERR_INTERNAL"
    SERVICE_UNAVAILABLE = "ERR_SERVICE_UNAVAILABLE"
    GENERATION_FAILED = "ERR_GENERATION_FAILED"


def make_error_response(error_code: str, message: str, hint: str = None) -> dict:
    """Create a structured error response dictionary.

    Args:
        error_code: One of the ErrorCodes constants
        message: User-friendly error message
        hint: Optional hint for how to fix the issue

    Returns:
        Dict with error_code, message, and optionally hint
    """
    response = {
        "error_code": error_code,
        "message": message,
    }
    if hint:
        response["hint"] = hint
    return response
