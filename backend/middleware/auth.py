"""
Authentication middleware for Story Weaver API.
Provides JWT-based authentication and authorization decorators.

Security features:
- require_auth: Validates JWT token and attaches user to request
- require_admin: Validates user has admin role
- require_owner: Validates user owns the requested resource (IDOR protection)
- get_current_user_id: Safely extracts user ID from JWT without requiring auth
"""
from functools import wraps
from flask import request, jsonify, g, current_app
from backend.database import db
from backend.models.user import User
import jwt
import os
import logging

logger = logging.getLogger(__name__)


def _get_jwt_secret():
    """Get JWT secret key, raising error if not configured."""
    # First check app config (useful for testing)
    try:
        if current_app and 'JWT_SECRET_KEY' in current_app.config:
            return current_app.config['JWT_SECRET_KEY']
    except RuntimeError:
        # Outside of request context
        pass

    secret = os.getenv('JWT_SECRET_KEY')
    if not secret or secret == 'dev-secret-key':
        # In production, this should never happen
        if os.getenv('FLASK_ENV', 'production') in ('prod', 'production'):
            logger.error("JWT_SECRET_KEY not properly configured in production!")
            raise ValueError("JWT_SECRET_KEY must be set in production")
        # In dev, allow but warn
        logger.warning("Using default JWT secret - NOT SAFE FOR PRODUCTION")
        return 'dev-secret-key'
    return secret


def require_auth(f):
    """
    Decorator that requires a valid JWT token.
    Attaches the current user to request.current_user.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')

        if not token:
            return jsonify({'error': 'Authentication required'}), 401

        try:
            if token.startswith('Bearer '):
                token = token[7:]

            secret = _get_jwt_secret()
            data = jwt.decode(
                token,
                secret,
                algorithms=['HS256']
            )

            user_id = data.get('user_id') or data.get('sub')
            if not user_id:
                logger.warning(f"Auth failed: No user_id in token. Payload keys: {list(data.keys())}")
                return jsonify({'error': 'Invalid token payload'}), 401

            current_user = db.session.get(User, user_id)
            if not current_user:
                logger.warning(f"Auth failed: User {user_id} not found in DB")
                return jsonify({'error': 'User not found'}), 401

            # Attach user to request context
            request.current_user = current_user
            g.current_user_id = current_user.id

        except jwt.ExpiredSignatureError:
            logger.warning("Auth failed: Token expired")
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError as e:
            logger.warning(f"Auth failed: Invalid JWT token: {type(e).__name__} - {str(e)}")
            return jsonify({'error': 'Invalid token'}), 401
        except ValueError as e:
            logger.error(f"JWT configuration error: {e}")
            return jsonify({'error': 'Authentication service unavailable'}), 503

        return f(*args, **kwargs)

    return decorated


def require_admin(f):
    """
    Decorator that requires the user to have admin role.
    Must be used after @require_auth.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        # First ensure user is authenticated
        if not hasattr(request, 'current_user') or not request.current_user:
            return jsonify({'error': 'Authentication required'}), 401

        # Check admin role
        user = request.current_user
        if not getattr(user, 'is_admin', False) and not getattr(user, 'role', '') == 'admin':
            logger.warning(f"Non-admin user {user.id} attempted admin action")
            return jsonify({'error': 'Admin access required'}), 403

        return f(*args, **kwargs)

    return decorated


def require_therapist(f):
    """
    Decorator that requires the user to have therapist role.
    Must be used after @require_auth.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        if not hasattr(request, 'current_user') or not request.current_user:
            return jsonify({'error': 'Authentication required'}), 401
        user = request.current_user
        if getattr(user, 'role', '') not in ('therapist', 'admin'):
            logger.warning(f"Non-therapist user {user.id} attempted therapist action")
            return jsonify({'error': 'Therapist access required'}), 403
        return f(*args, **kwargs)
    return decorated


def require_owner(resource_user_id_param='user_id'):
    """
    Decorator that validates the authenticated user owns the requested resource.
    Prevents IDOR (Insecure Direct Object Reference) attacks.

    Args:
        resource_user_id_param: Name of the URL parameter or kwarg containing the resource owner's user_id

    Usage:
        @require_auth
        @require_owner('user_id')
        def get_user_data(user_id):
            # user_id is guaranteed to match authenticated user
            ...
    """
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if not hasattr(request, 'current_user') or not request.current_user:
                return jsonify({'error': 'Authentication required'}), 401

            # Get resource owner ID from URL params or kwargs
            resource_owner_id = kwargs.get(resource_user_id_param)

            # Also check request.view_args for Flask URL parameters
            if not resource_owner_id and hasattr(request, 'view_args'):
                resource_owner_id = request.view_args.get(resource_user_id_param)

            if not resource_owner_id:
                # If no user_id in URL, this decorator shouldn't be used
                logger.error(f"require_owner used but {resource_user_id_param} not found in request")
                return jsonify({'error': 'Invalid request'}), 400

            # Verify ownership
            if str(request.current_user.id) != str(resource_owner_id):
                logger.warning(
                    f"IDOR attempt: User {request.current_user.id} tried to access "
                    f"resource belonging to {resource_owner_id}"
                )
                return jsonify({'error': 'Access denied'}), 403

            return f(*args, **kwargs)

        return decorated
    return decorator


def get_current_user_id():
    """
    Safely get the current user ID from JWT token without requiring authentication.
    Returns None if no valid token is present.
    Useful for optional user identification (e.g., analytics, rate limiting).
    """
    token = request.headers.get('Authorization')
    if not token:
        # Also check X-User-ID header as fallback for legacy clients
        return request.headers.get('X-User-ID')

    try:
        if token.startswith('Bearer '):
            token = token[7:]

        secret = _get_jwt_secret()
        data = jwt.decode(token, secret, algorithms=['HS256'])
        return data.get('user_id') or data.get('sub')
    except (jwt.InvalidTokenError, ValueError):
        # Token invalid but that's okay for optional auth
        return request.headers.get('X-User-ID')


def optional_auth(f):
    """
    Decorator that attempts to authenticate but doesn't require it.
    If valid token present, attaches user to request.current_user.
    If no token or invalid token, continues without user.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        request.current_user = None
        g.current_user_id = None

        if token:
            try:
                if token.startswith('Bearer '):
                    token = token[7:]

                secret = _get_jwt_secret()
                data = jwt.decode(token, secret, algorithms=['HS256'])
                user_id = data.get('user_id') or data.get('sub')

                if user_id:
                    current_user = db.session.get(User, user_id)
                    if current_user:
                        request.current_user = current_user
                        g.current_user_id = current_user.id
            except (jwt.InvalidTokenError, ValueError):
                # Invalid token is fine for optional auth
                pass

        return f(*args, **kwargs)

    return decorated
