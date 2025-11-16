#!/usr/bin/env python3
"""
Authorization Middleware for Story Weaver
Request authorization layer with permission checking and security headers
"""

import os
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Callable
from functools import wraps
import redis
import json

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AuthorizationMiddleware:
    def __init__(self, iam_manager):
        self.iam = iam_manager
        self.redis_client = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))

        # Rate limiting configuration
        self.rate_limits = {
            'user': {'requests': 100, 'window': 60},      # 100 req/minute
            'premium': {'requests': 500, 'window': 60},   # 500 req/minute
            'therapist': {'requests': 1000, 'window': 60}, # 1000 req/minute
            'admin': {'requests': 5000, 'window': 60}     # 5000 req/minute
        }

        # Blocked IPs and users
        self.blocked_ips = set()
        self.blocked_users = set()

        # Security event tracking
        self.security_events = []

    def require_auth(self, required_permissions: List[str] = None, require_mfa: bool = False):
        """Decorator to require authentication and optional permissions"""
        def decorator(f):
            @wraps(f)
            def decorated_function(*args, **kwargs):
                # Extract request information (would be from Flask request object)
                auth_header = self._get_auth_header()
                client_ip = self._get_client_ip()
                user_agent = self._get_user_agent()

                # Check if IP is blocked
                if client_ip in self.blocked_ips:
                    self._log_security_event('blocked_ip_access', {
                        'ip': client_ip,
                        'endpoint': f.__name__,
                        'user_agent': user_agent
                    })
                    return self._unauthorized_response('IP address blocked')

                # Validate authorization header
                if not auth_header or not auth_header.startswith('Bearer '):
                    self._log_security_event('missing_auth_header', {
                        'ip': client_ip,
                        'endpoint': f.__name__,
                        'user_agent': user_agent
                    })
                    return self._unauthorized_response('Missing or invalid authorization header')

                token = auth_header.split(' ')[1]

                # Validate token
                payload = self.iam.validate_token(token)
                if not payload:
                    self._log_security_event('invalid_token', {
                        'ip': client_ip,
                        'endpoint': f.__name__,
                        'token_partial': token[:10] + '...',
                        'user_agent': user_agent
                    })
                    return self._unauthorized_response('Invalid or expired token')

                user_id = payload['user_id']
                user_role = payload.get('role', 'user')
                session_id = payload.get('session_id')

                # Check if user is blocked
                if user_id in self.blocked_users:
                    self._log_security_event('blocked_user_access', {
                        'user_id': user_id,
                        'ip': client_ip,
                        'endpoint': f.__name__,
                        'user_agent': user_agent
                    })
                    return self._unauthorized_response('Account suspended')

                # Check MFA requirement
                if require_mfa and not payload.get('mfa_verified', False):
                    self._log_security_event('mfa_required', {
                        'user_id': user_id,
                        'endpoint': f.__name__,
                        'user_agent': user_agent
                    })
                    return self._unauthorized_response('Multi-factor authentication required')

                # Check permissions
                if required_permissions:
                    has_permission = False
                    for permission in required_permissions:
                        if self.iam.check_permission(user_role, permission):
                            has_permission = True
                            break

                    if not has_permission:
                        self._log_security_event('insufficient_permissions', {
                            'user_id': user_id,
                            'role': user_role,
                            'required_permissions': required_permissions,
                            'endpoint': f.__name__,
                            'user_agent': user_agent
                        })
                        return self._forbidden_response('Insufficient permissions')

                # Rate limiting check
                rate_limit_ok = self._check_rate_limit(user_id, user_role, client_ip)
                if not rate_limit_ok:
                    self._log_security_event('rate_limit_exceeded', {
                        'user_id': user_id,
                        'ip': client_ip,
                        'endpoint': f.__name__,
                        'user_agent': user_agent
                    })
                    return self._rate_limit_response('Rate limit exceeded')

                # Log successful access
                self._log_access_event(user_id, f.__name__, client_ip, user_agent)

                # Add user context to request (would be Flask g object)
                self._set_request_context(user_id, user_role, session_id, payload)

                return f(*args, **kwargs)
            return decorated_function
        return decorator

    def _get_auth_header(self) -> Optional[str]:
        """Get authorization header from request"""
        # In Flask, this would be: request.headers.get('Authorization')
        # For now, return a placeholder
        return os.getenv('TEST_AUTH_HEADER')

    def _get_client_ip(self) -> str:
        """Get client IP address"""
        # In Flask, this would be: request.remote_addr or request.headers.get('X-Forwarded-For')
        return os.getenv('TEST_CLIENT_IP', '127.0.0.1')

    def _get_user_agent(self) -> str:
        """Get user agent string"""
        # In Flask, this would be: request.headers.get('User-Agent')
        return os.getenv('TEST_USER_AGENT', 'Unknown')

    def _check_rate_limit(self, user_id: str, user_role: str, client_ip: str) -> bool:
        """Check if request is within rate limits"""
        try:
            # Get rate limit for user role
            limits = self.rate_limits.get(user_role, self.rate_limits['user'])
            max_requests = limits['requests']
            window_seconds = limits['window']

            # Create rate limit key
            current_window = int(time.time() / window_seconds)
            rate_key = f"rate_limit:{user_id}:{current_window}"

            # Get current request count
            current_count = int(self.redis_client.get(rate_key) or 0)

            if current_count >= max_requests:
                return False

            # Increment counter
            self.redis_client.incr(rate_key)
            self.redis_client.expire(rate_key, window_seconds)

            return True

        except Exception as e:
            logger.error(f"Rate limit check failed: {e}")
            return True  # Allow request on error

    def _log_security_event(self, event_type: str, details: Dict[str, Any]):
        """Log security events"""
        event = {
            'timestamp': datetime.utcnow().isoformat(),
            'event_type': event_type,
            'details': details,
            'severity': self._get_event_severity(event_type)
        }

        self.security_events.append(event)

        # Keep only last 1000 events
        if len(self.security_events) > 1000:
            self.security_events = self.security_events[-500:]

        logger.warning(f"Security event: {event_type} - {details}")

    def _log_access_event(self, user_id: str, endpoint: str, ip: str, user_agent: str):
        """Log successful access events"""
        # In production, you might want to log this to a separate audit log
        # or use a more sophisticated logging system
        logger.info(f"Access granted: user={user_id}, endpoint={endpoint}, ip={ip}")

    def _get_event_severity(self, event_type: str) -> str:
        """Get severity level for security events"""
        severity_map = {
            'blocked_ip_access': 'high',
            'blocked_user_access': 'high',
            'missing_auth_header': 'medium',
            'invalid_token': 'medium',
            'mfa_required': 'low',
            'insufficient_permissions': 'medium',
            'rate_limit_exceeded': 'low',
        }
        return severity_map.get(event_type, 'low')

    def _set_request_context(self, user_id: str, user_role: str, session_id: str, payload: Dict[str, Any]):
        """Set user context in request"""
        # In Flask, this would set values in the g object
        # For now, we'll just log it
        logger.debug(f"Set request context: user={user_id}, role={user_role}, session={session_id}")

    def _unauthorized_response(self, message: str) -> tuple:
        """Return unauthorized response"""
        return {'error': message, 'code': 'UNAUTHORIZED'}, 401

    def _forbidden_response(self, message: str) -> tuple:
        """Return forbidden response"""
        return {'error': message, 'code': 'FORBIDDEN'}, 403

    def _rate_limit_response(self, message: str) -> tuple:
        """Return rate limit response"""
        return {'error': message, 'code': 'RATE_LIMIT_EXCEEDED'}, 429

    def add_security_headers(self, response):
        """Add comprehensive security headers to response"""
        headers = {
            # Prevent MIME type sniffing
            'X-Content-Type-Options': 'nosniff',

            # Prevent clickjacking
            'X-Frame-Options': 'DENY',

            # XSS protection
            'X-XSS-Protection': '1; mode=block',

            # Enforce HTTPS
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',

            # Content Security Policy
            'Content-Security-Policy': (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://code.jquery.com; "
                "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
                "font-src 'self' https://fonts.gstatic.com; "
                "img-src 'self' data: https:; "
                "connect-src 'self' https://api.story-weaver.com wss://api.story-weaver.com"
            ),

            # Referrer policy
            'Referrer-Policy': 'strict-origin-when-cross-origin',

            # Feature policy
            'Permissions-Policy': (
                "camera=(), microphone=(), geolocation=(), "
                "payment=(), usb=(), magnetometer=()"
            ),

            # Remove server information
            'Server': '',

            # Cache control for sensitive endpoints
            'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
            'Pragma': 'no-cache',
            'Expires': '0'
        }

        # Apply headers to response
        for header, value in headers.items():
            response.headers[header] = value

        return response

    def block_ip(self, ip_address: str, reason: str = "Security violation"):
        """Block an IP address"""
        self.blocked_ips.add(ip_address)
        self._log_security_event('ip_blocked', {
            'ip': ip_address,
            'reason': reason,
            'action': 'blocked'
        })
        logger.warning(f"Blocked IP address: {ip_address} - {reason}")

    def block_user(self, user_id: str, reason: str = "Security violation"):
        """Block a user account"""
        self.blocked_users.add(user_id)
        self._log_security_event('user_blocked', {
            'user_id': user_id,
            'reason': reason,
            'action': 'blocked'
        })
        logger.warning(f"Blocked user account: {user_id} - {reason}")

    def unblock_ip(self, ip_address: str):
        """Unblock an IP address"""
        if ip_address in self.blocked_ips:
            self.blocked_ips.remove(ip_address)
            self._log_security_event('ip_unblocked', {
                'ip': ip_address,
                'action': 'unblocked'
            })
            logger.info(f"Unblocked IP address: {ip_address}")

    def unblock_user(self, user_id: str):
        """Unblock a user account"""
        if user_id in self.blocked_users:
            self.blocked_users.remove(user_id)
            self._log_security_event('user_unblocked', {
                'user_id': user_id,
                'action': 'unblocked'
            })
            logger.info(f"Unblocked user account: {user_id}")

    def get_security_report(self) -> Dict[str, Any]:
        """Generate security report"""
        recent_events = self.security_events[-100:] if self.security_events else []

        # Analyze events by type and severity
        event_summary = {}
        severity_counts = {'low': 0, 'medium': 0, 'high': 0}

        for event in recent_events:
            event_type = event['event_type']
            severity = event['severity']

            if event_type not in event_summary:
                event_summary[event_type] = 0
            event_summary[event_type] += 1

            severity_counts[severity] += 1

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'blocked_ips_count': len(self.blocked_ips),
            'blocked_users_count': len(self.blocked_users),
            'recent_security_events': len(recent_events),
            'event_summary': event_summary,
            'severity_distribution': severity_counts,
            'blocked_ips': list(self.blocked_ips),
            'blocked_users': list(self.blocked_users)
        }

    def cleanup_expired_data(self):
        """Clean up expired security data"""
        # Clean up old security events (keep last 30 days)
        cutoff_date = datetime.utcnow() - timedelta(days=30)
        self.security_events = [
            event for event in self.security_events
            if datetime.fromisoformat(event['timestamp']) > cutoff_date
        ]

        logger.info(f"Cleaned up expired security data, {len(self.security_events)} events remaining")

def create_security_middleware(iam_manager):
    """Factory function to create security middleware"""
    return AuthorizationMiddleware(iam_manager)

# Flask integration decorator
def require_auth(permissions: List[str] = None, require_mfa: bool = False):
    """Flask route decorator for authentication and authorization"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # This would integrate with Flask request context
            # For now, return a placeholder
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# Export key components
__all__ = ['AuthorizationMiddleware', 'create_security_middleware', 'require_auth']