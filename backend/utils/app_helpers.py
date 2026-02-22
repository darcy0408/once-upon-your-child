import json
import os
import time
import uuid
from datetime import datetime, timezone

from flask import g, jsonify, request
from flask_limiter.util import get_remote_address

from ..models.user import User

# Keyword list for story safety checks
INAPPROPRIATE_KEYWORDS = [
    'violence', 'weapon', 'death', 'kill', 'hurt', 'blood',
    'scary', 'monster', 'nightmare', 'attack', 'fight', 'gun',
    'knife', 'suicide', 'self-harm'
]


def is_production() -> bool:
    return os.getenv('RAILWAY_ENVIRONMENT') == 'production'


def get_user_identifier() -> str:
    """Get user ID from request or fall back to IP address"""
    # 1. Check for user attached by auth middleware
    if hasattr(request, 'current_user') and request.current_user:
        return f"user:{request.current_user.id}"
    
    if hasattr(g, 'current_user_id') and g.current_user_id:
        return f"user:{g.current_user_id}"

    # 2. Check for legacy/manual header
    user_id = request.headers.get('X-User-ID')

    # 3. Check for flask-jwt-extended identity
    if not user_id:
        try:
            from flask_jwt_extended import get_jwt_identity
            user_id = get_jwt_identity()
        except Exception:
            pass

    return f"user:{user_id}" if user_id else f"ip:{get_remote_address()}"


def get_user_tier() -> str:
    """Get user subscription tier for rate limiting"""
    # 1. Check for user attached by auth middleware
    if hasattr(request, 'current_user') and request.current_user:
        return request.current_user.subscription_tier or 'free'

    # 2. Try to load user from ID in request context or headers
    user_id = request.headers.get('X-User-ID') or getattr(g, 'current_user_id', None) or getattr(g, 'user_id', None)

    if user_id:
        try:
            user = User.query.filter_by(id=user_id).first()
            if user:
                return user.subscription_tier or 'free'
        except Exception:
            pass

    return 'free'


def get_tier_limits(operation: str = 'default') -> str | None:
    """Get rate limits based on user tier"""
    tier = get_user_tier()

    limits = {
        'default': {
            'free': "3/minute; 10/hour; 50/day",
            'premium': "10/minute; 100/hour",
            'family': "15/minute; 200/hour",
            'byok': None
        },
        'expensive': {
            'free': "1/minute; 5/hour; 10/day",
            'premium': "3/minute; 20/hour",
            'family': "5/minute; 30/hour",
            'byok': None
        }
    }

    return limits.get(operation, limits['default']).get(tier, limits['default']['free'])


def make_filter_story_content(logger):
    def filter_story_content(story_text: str) -> tuple[str, bool]:
        """Detect potentially inappropriate keywords in story content."""
        if not story_text:
            return story_text, False

        lower_text = story_text.lower()
        had_issues = False
        for keyword in INAPPROPRIATE_KEYWORDS:
            if keyword in lower_text:
                had_issues = True
                logger.warning(f"Content filter triggered: {keyword} in story text")
        if had_issues:
            logger.warning(f"Flagged story content (first 200 chars): {story_text[:200]!r}")
        return story_text, had_issues

    return filter_story_content


def make_log_error(logger):
    def log_error(error_type, message, details=None):
        log_entry = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'type': error_type,
            'message': message,
            'details': details or {}
        }
        logger.error(json.dumps(log_entry))

    return log_error


def make_add_request_id(logger):
    def add_request_id():
        g.request_id = str(uuid.uuid4())[:8]
        g.start_time = time.time()
        logger.info(f"[{g.request_id}] {request.method} {request.path}")

    return add_request_id


def make_log_response(logger, log_error):
    def log_response(response):
        request_id = getattr(g, 'request_id', 'unknown')
        duration = 0
        if hasattr(g, 'start_time'):
            duration = time.time() - g.start_time
            if duration > 5.0:
                log_error(
                    error_type='slow_request',
                    message=f'Request took {duration:.2f}s',
                    details={
                        'method': request.method,
                        'path': request.path,
                        'duration': duration,
                        'status_code': response.status_code
                    }
                )
        log_entry = {
            'method': request.method,
            'path': request.path,
            'status': response.status_code,
            'duration_ms': round(duration * 1000, 2) if hasattr(g, 'start_time') else 0,
            'ip': request.remote_addr,
            'request_id': request_id
        }
        logger.info(json.dumps(log_entry))
        return response

    return log_response


def make_handle_error(logger, is_production_fn, log_error):
    def handle_error(error):
        request_id = getattr(g, 'request_id', 'unknown')
        log_error(
            error_type='unhandled_error',
            message=str(error),
            details={
                'request_id': request_id,
                'method': request.method,
                'path': request.path,
                'error_class': error.__class__.__name__
            }
        )
        logger.exception(f"[{request_id}] Unhandled error: {error}")

        if is_production_fn():
            return jsonify({
                'error': 'Internal server error',
                'request_id': request_id
            }), 500
        return jsonify({
            'error': str(error),
            'request_id': request_id
        }), 500

    return handle_error
