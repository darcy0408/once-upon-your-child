"""
API Key Management Routes for BYOK (Bring Your Own API Key) feature.
Allows users to securely save, validate, and remove their Gemini API keys.
"""
from flask import Blueprint, request, jsonify
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import logging
from datetime import datetime, timedelta, timezone

from ..database import db
from ..models.user import User
from ..encryption_utils import (
    encrypt_api_key,
    decrypt_api_key,
    validate_gemini_api_key_format,
    test_gemini_api_key
)

logger = logging.getLogger(__name__)

# Create blueprint
api_key_routes = Blueprint('api_key_routes', __name__)


def get_user_from_request():
    """
    Extract user ID from request and fetch user from database.
    For now, we'll use X-User-ID header (same as existing pattern in app.py).
    In production, this should be replaced with proper JWT authentication.
    """
    user_id = request.headers.get('X-User-ID')
    if not user_id:
        return None, ("User authentication required. Please provide X-User-ID header.", 401)
    
    user = User.query.filter_by(id=user_id).first()
    if not user:
        return None, ("User not found.", 404)
    
    return user, None


@api_key_routes.route('/api/user/settings/api-key', methods=['POST'])
def save_api_key():
    """
    Save or update a user's BYOK Gemini API key.
    
    Request body:
        {
            "api_key": "AIzaSy..."
        }
    
    Response:
        {
            "success": true,
            "byok_enabled": true,
            "message": "API key saved successfully"
        }
    """
    try:
        # Get authenticated user
        user, error_response = get_user_from_request()
        if error_response:
            return jsonify({"error": error_response[0]}), error_response[1]
        
        # Parse request
        data = request.get_json(silent=True) or {}
        api_key = data.get('api_key', '').strip()
        
        if not api_key:
            return jsonify({"error": "API key is required"}), 400
        
        # Validate format
        if not validate_gemini_api_key_format(api_key):
            return jsonify({
                "error": "Invalid API key format. Gemini API keys should start with 'AIza' and be 39 characters long."
            }), 400
        
        # Test the API key with Gemini
        is_valid, error_message = test_gemini_api_key(api_key)
        if not is_valid:
            return jsonify({
                "error": "API key validation failed",
                "details": error_message,
                "valid": False
            }), 400
        
        # Encrypt and save
        encrypted_key = encrypt_api_key(api_key)
        user.gemini_api_key_encrypted = encrypted_key
        user.has_byok = True
        
        # Initialize usage tracking if not already set
        if not user.usage_reset_date:
            # Reset on the 1st of next month
            today = datetime.now(timezone.utc)
            if today.day >= 28:
                # If near end of month, reset next month
                next_month = today.replace(day=1) + timedelta(days=32)
                user.usage_reset_date = next_month.replace(day=1)
            else:
                # Reset on 1st of next month
                next_month = today.replace(day=1) + timedelta(days=32)
                user.usage_reset_date = next_month.replace(day=1)
        
        db.session.commit()
        
        logger.info(f"User {user.id} successfully configured BYOK")
        
        return jsonify({
            "success": True,
            "byok_enabled": True,
            "message": "API key saved successfully. You now have unlimited story and illustration generation!",
            "valid": True
        }), 200
        
    except Exception as e:
        logger.exception(f"Failed to save API key: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to save API key", "details": str(e)}), 500


@api_key_routes.route('/api/user/settings/api-key', methods=['DELETE'])
def remove_api_key():
    """
    Remove a user's BYOK API key.
    
    Response:
        {
            "success": true,
            "byok_enabled": false,
            "message": "API key removed successfully"
        }
    """
    try:
        # Get authenticated user
        user, error_response = get_user_from_request()
        if error_response:
            return jsonify({"error": error_response[0]}), error_response[1]
        
        # Remove API key
        user.gemini_api_key_encrypted = None
        user.has_byok = False
        
        db.session.commit()
        
        logger.info(f"User {user.id} removed BYOK API key")
        
        return jsonify({
            "success": True,
            "byok_enabled": False,
            "message": "API key removed successfully. Free tier limits now apply."
        }), 200
        
    except Exception as e:
        logger.exception(f"Failed to remove API key: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to remove API key", "details": str(e)}), 500


@api_key_routes.route('/api/user/settings/validate-api-key', methods=['POST'])
def validate_api_key():
    """
    Test an API key without saving it.
    
    Request body:
        {
            "api_key": "AIzaSy..."
        }
    
    Response:
        {
            "valid": true/false,
            "message": "..."
        }
    """
    try:
        # This endpoint doesn't require authentication - allows testing before signup
        data = request.get_json(silent=True) or {}
        api_key = data.get('api_key', '').strip()
        
        if not api_key:
            return jsonify({"valid": False, "message": "API key is required"}), 400
        
        # Validate format
        if not validate_gemini_api_key_format(api_key):
            return jsonify({
                "valid": False,
                "message": "Invalid API key format. Gemini API keys should start with 'AIza' and be 39 characters long."
            }), 200  # Return 200 but valid=false
        
        # Test with Gemini API
        is_valid, error_message = test_gemini_api_key(api_key)
        
        if is_valid:
            return jsonify({
                "valid": True,
                "message": "API key is valid and working!"
            }), 200
        else:
            return jsonify({
                "valid": False,
                "message": error_message
            }), 200  # Return 200 but valid=false
            
    except Exception as e:
        logger.exception(f"API key validation error: {e}")
        return jsonify({
            "valid": False,
            "message": f"Validation failed: {str(e)}"
        }), 500


@api_key_routes.route('/api/user/usage', methods=['GET'])
def get_usage():
    """
    Get user's usage statistics and limits.
    
    Response:
        {
            "tier": "free" | "premium" | "family" | "byok",
            "stories": {
                "used": 3,
                "limit": 5,
                "unlimited": false
            },
            "illustrations": {
                "used": 1,
                "limit": 3,
                "unlimited": false
            },
            "reset_date": "2024-01-01T00:00:00Z"
        }
    """
    try:
        # Get authenticated user
        user, error_response = get_user_from_request()
        if error_response:
            return jsonify({"error": error_response[0]}), error_response[1]
        
        # Determine tier
        if user.has_byok:
            tier = "byok"
            story_limit = None  # Unlimited
            illustration_limit = None  # Unlimited
        elif user.subscription_tier == "family":
            tier = "family"
            story_limit = 500  # Very high limit for family
            illustration_limit = 200
        elif user.subscription_tier == "premium":
            tier = "premium"
            story_limit = 100
            illustration_limit = 50
        else:
            tier = "free"
            story_limit = 5
            illustration_limit = 3
        
        # Check if we need to reset monthly counters
        now = datetime.now(timezone.utc)
        if user.usage_reset_date and now >= user.usage_reset_date:
            # Reset counters
            user.stories_generated_this_month = 0
            user.illustrations_generated_this_month = 0
            # Set next reset date (1st of next month)
            next_month = now.replace(day=1) + timedelta(days=32)
            user.usage_reset_date = next_month.replace(day=1)
            db.session.commit()
            logger.info(f"Reset monthly usage for user {user.id}")
        
        return jsonify({
            "tier": tier,
            "stories": {
                "used": user.stories_generated_this_month,
                "limit": story_limit,
                "unlimited": story_limit is None
            },
            "illustrations": {
                "used": user.illustrations_generated_this_month,
                "limit": illustration_limit,
                "unlimited": illustration_limit is None
            },
            "reset_date": user.usage_reset_date.isoformat() if user.usage_reset_date else None
        }), 200
        
    except Exception as e:
        logger.exception(f"Failed to get usage: {e}")
        return jsonify({"error": "Failed to retrieve usage data", "details": str(e)}), 500
