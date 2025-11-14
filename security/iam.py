#!/usr/bin/env python3
"""
Identity & Access Management (IAM) for Story Weaver
Zero-trust authentication and authorization system
"""

import os
import jwt
import bcrypt
import secrets
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from functools import wraps
import pyotp
import qrcode
import io
import base64

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class IdentityAccessManager:
    def __init__(self):
        self.jwt_secret = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
        self.jwt_algorithm = "HS256"
        self.access_token_expiry = 900  # 15 minutes
        self.refresh_token_expiry = 604800  # 7 days
        self.password_salt = os.getenv("PASSWORD_SALT", bcrypt.gensalt())

        # Role definitions with permissions
        self.roles = {
            'admin': {
                'permissions': ['*'],  # All permissions
                'description': 'Full system access'
            },
            'therapist': {
                'permissions': [
                    'read:user_profile',
                    'write:user_profile',
                    'read:therapeutic_sessions',
                    'write:therapeutic_sessions',
                    'read:analytics',
                    'export:data'
                ],
                'description': 'Therapist access to user data and sessions'
            },
            'user': {
                'permissions': [
                    'read:own_profile',
                    'write:own_profile',
                    'read:own_sessions',
                    'write:own_sessions',
                    'create:story',
                    'read:own_stories'
                ],
                'description': 'Standard user access'
            },
            'viewer': {
                'permissions': [
                    'read:own_profile',
                    'read:own_sessions',
                    'read:own_stories'
                ],
                'description': 'Read-only access'
            }
        }

        # Active sessions tracking
        self.active_sessions = {}

    def hash_password(self, password: str) -> str:
        """Hash a password using bcrypt"""
        return bcrypt.hashpw(password.encode('utf-8'), self.password_salt).decode('utf-8')

    def verify_password(self, password: str, hashed: str) -> bool:
        """Verify a password against its hash"""
        return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

    def generate_tokens(self, user_id: str, role: str, additional_claims: Dict[str, Any] = None) -> Dict[str, str]:
        """Generate access and refresh tokens"""
        now = datetime.utcnow()

        # Access token payload
        access_payload = {
            'user_id': user_id,
            'role': role,
            'type': 'access',
            'iat': now,
            'exp': now + timedelta(seconds=self.access_token_expiry),
            'iss': 'story-weaver-iam',
            'aud': 'story-weaver-api'
        }

        # Refresh token payload
        refresh_payload = {
            'user_id': user_id,
            'type': 'refresh',
            'iat': now,
            'exp': now + timedelta(seconds=self.refresh_token_expiry),
            'iss': 'story-weaver-iam'
        }

        # Add additional claims if provided
        if additional_claims:
            access_payload.update(additional_claims)

        # Generate tokens
        access_token = jwt.encode(access_payload, self.jwt_secret, algorithm=self.jwt_algorithm)
        refresh_token = jwt.encode(refresh_payload, self.jwt_secret, algorithm=self.jwt_algorithm)

        # Track session
        session_id = secrets.token_urlsafe(32)
        self.active_sessions[session_id] = {
            'user_id': user_id,
            'role': role,
            'created_at': now,
            'last_activity': now,
            'access_token_jti': access_payload.get('jti'),
            'refresh_token_jti': refresh_payload.get('jti')
        }

        return {
            'access_token': access_token,
            'refresh_token': refresh_token,
            'token_type': 'Bearer',
            'expires_in': self.access_token_expiry,
            'session_id': session_id
        }

    def validate_token(self, token: str, token_type: str = 'access') -> Optional[Dict[str, Any]]:
        """Validate a JWT token"""
        try:
            payload = jwt.decode(token, self.jwt_secret, algorithms=[self.jwt_algorithm])

            # Check token type
            if payload.get('type') != token_type:
                return None

            # Check if token is expired
            exp = datetime.fromtimestamp(payload['exp'])
            if exp < datetime.utcnow():
                return None

            # Check if session is still active
            session_id = payload.get('session_id')
            if session_id and session_id not in self.active_sessions:
                return None

            # Update session activity
            if session_id:
                self.active_sessions[session_id]['last_activity'] = datetime.utcnow()

            return payload

        except jwt.ExpiredSignatureError:
            logger.warning("Token expired")
            return None
        except jwt.InvalidTokenError:
            logger.warning("Invalid token")
            return None
        except Exception as e:
            logger.error(f"Token validation error: {e}")
            return None

    def refresh_access_token(self, refresh_token: str) -> Optional[Dict[str, str]]:
        """Generate new access token using refresh token"""
        payload = self.validate_token(refresh_token, 'refresh')
        if not payload:
            return None

        user_id = payload['user_id']

        # Find active session for this user
        user_sessions = [s for s in self.active_sessions.values() if s['user_id'] == user_id]
        if not user_sessions:
            return None

        # Use the most recent session
        session = max(user_sessions, key=lambda x: x['created_at'])

        # Generate new access token
        return self.generate_tokens(user_id, session['role'])

    def revoke_session(self, session_id: str, user_id: str = None):
        """Revoke a user session"""
        if session_id in self.active_sessions:
            session = self.active_sessions[session_id]
            if user_id and session['user_id'] != user_id:
                return False  # Session doesn't belong to user

            del self.active_sessions[session_id]
            logger.info(f"Session {session_id} revoked")
            return True

        return False

    def revoke_all_user_sessions(self, user_id: str):
        """Revoke all sessions for a user"""
        sessions_to_remove = [sid for sid, session in self.active_sessions.items()
                            if session['user_id'] == user_id]

        for session_id in sessions_to_remove:
            del self.active_sessions[session_id]

        logger.info(f"All sessions revoked for user {user_id}")
        return len(sessions_to_remove)

    def check_permission(self, user_role: str, required_permission: str) -> bool:
        """Check if a user role has a specific permission"""
        if user_role not in self.roles:
            return False

        role_permissions = self.roles[user_role]['permissions']

        # Admin has all permissions
        if '*' in role_permissions:
            return True

        return required_permission in role_permissions

    def get_user_permissions(self, user_role: str) -> List[str]:
        """Get all permissions for a user role"""
        if user_role not in self.roles:
            return []

        permissions = self.roles[user_role]['permissions']
        if '*' in permissions:
            return ['*']  # Admin has all permissions

        return permissions

    def setup_mfa(self, user_id: str) -> Dict[str, str]:
        """Set up Multi-Factor Authentication for a user"""
        # Generate TOTP secret
        totp_secret = pyotp.random_base32()

        # Create TOTP object
        totp = pyotp.TOTP(totp_secret)

        # Generate QR code
        provisioning_uri = totp.provisioning_uri(name=user_id, issuer_name="Story Weaver")

        # Create QR code image
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(provisioning_uri)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        qr_code_b64 = base64.b64encode(buffer.getvalue()).decode()

        return {
            'secret': totp_secret,
            'qr_code': qr_code_b64,
            'provisioning_uri': provisioning_uri
        }

    def verify_mfa(self, secret: str, code: str) -> bool:
        """Verify an MFA code"""
        try:
            totp = pyotp.TOTP(secret)
            return totp.verify(code)
        except Exception as e:
            logger.error(f"MFA verification error: {e}")
            return False

    def get_active_sessions(self, user_id: str = None) -> List[Dict[str, Any]]:
        """Get active sessions, optionally filtered by user"""
        sessions = []
        for session_id, session_data in self.active_sessions.items():
            if user_id is None or session_data['user_id'] == user_id:
                session_info = session_data.copy()
                session_info['session_id'] = session_id
                session_info['is_active'] = True
                sessions.append(session_info)

        return sessions

    def cleanup_expired_sessions(self):
        """Clean up expired sessions"""
        now = datetime.utcnow()
        expired_sessions = []

        for session_id, session_data in self.active_sessions.items():
            # Check if session has been inactive for too long
            last_activity = session_data['last_activity']
            if (now - last_activity).total_seconds() > 3600:  # 1 hour inactivity
                expired_sessions.append(session_id)

        for session_id in expired_sessions:
            del self.active_sessions[session_id]

        if expired_sessions:
            logger.info(f"Cleaned up {len(expired_sessions)} expired sessions")

        return len(expired_sessions)

class SecurityMiddleware:
    """Flask middleware for security enforcement"""

    def __init__(self, iam_manager: IdentityAccessManager):
        self.iam = iam_manager

    def require_auth(self, required_permissions: List[str] = None):
        """Decorator to require authentication and optional permissions"""
        def decorator(f):
            @wraps(f)
            def decorated_function(*args, **kwargs):
                auth_header = request.headers.get('Authorization')
                if not auth_header or not auth_header.startswith('Bearer '):
                    return jsonify({'error': 'Missing or invalid authorization header'}), 401

                token = auth_header.split(' ')[1]
                payload = self.iam.validate_token(token)

                if not payload:
                    return jsonify({'error': 'Invalid or expired token'}), 401

                # Check permissions if required
                if required_permissions:
                    user_role = payload.get('role', 'user')
                    for permission in required_permissions:
                        if not self.iam.check_permission(user_role, permission):
                            return jsonify({'error': 'Insufficient permissions'}), 403

                # Add user context to request
                request.user_id = payload['user_id']
                request.user_role = payload.get('role', 'user')
                request.session_id = payload.get('session_id')

                return f(*args, **kwargs)
            return decorated_function
        return decorator

    def add_security_headers(self, response):
        """Add security headers to response"""
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
        response.headers['Content-Security-Policy'] = "default-src 'self'"
        response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'

        return response

def init_security(app):
    """Initialize security for Flask application"""
    iam = IdentityAccessManager()
    middleware = SecurityMiddleware(iam)

    # Add security headers to all responses
    @app.after_request
    def add_security_headers(response):
        return middleware.add_security_headers(response)

    # Store in app context
    app.iam = iam
    app.security_middleware = middleware

    return iam, middleware

# Export key functions
__all__ = ['IdentityAccessManager', 'SecurityMiddleware', 'init_security']