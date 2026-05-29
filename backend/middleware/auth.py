"""
Authentication middleware for Story Weaver API.
Provides JWT-based authentication and authorization decorators.

Security features:
- require_auth: Validates JWT token and attaches user to request; sets g.minor_age_cap
- require_parental_consent: COPPA gate — blocks under-13 users without a ConsentRecord
- require_admin: Validates user has admin role
- require_owner: Validates user owns the requested resource (IDOR protection)
- get_current_user_id: Safely extracts user ID from JWT without requiring auth
- optional_auth: Attempts auth but doesn't require it
"""

import logging
import os
from functools import wraps

import jwt
from flask import current_app, g, jsonify, request

from backend.database import db
from backend.models.consent_record import CURRENT_POLICY_VERSION, ConsentRecord
from backend.models.user import User

logger = logging.getLogger(__name__)


def _get_jwt_secret():
    """Get JWT secret key, raising error if not configured."""
    # First check app config (useful for testing)
    try:
        if current_app and "JWT_SECRET_KEY" in current_app.config:
            return current_app.config["JWT_SECRET_KEY"]
    except RuntimeError:
        # Outside of request context
        pass

    secret = os.getenv("JWT_SECRET_KEY")
    if not secret or secret == "dev-secret-key":
        # In production, this should never happen
        if os.getenv("FLASK_ENV", "production") in ("prod", "production"):
            logger.error("JWT_SECRET_KEY not properly configured in production!")
            raise ValueError("JWT_SECRET_KEY must be set in production")
        # In dev, allow but warn
        logger.warning("Using default JWT secret - NOT SAFE FOR PRODUCTION")
        return "dev-secret-key"
    return secret


def require_auth(f):
    """
    Decorator that requires a valid JWT token.
    Attaches the current user to request.current_user.
    """

    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("Authorization")

        if not token:
            return jsonify({"error": "Authentication required"}), 401

        try:
            if token.startswith("Bearer "):
                token = token[7:]

            secret = _get_jwt_secret()
            data = jwt.decode(token, secret, algorithms=["HS256"])

            # Identity is standardized on the JWT `sub` claim. The legacy
            # `user_id` claim is no longer accepted as a fallback.
            user_id = data.get("sub")
            if not user_id:
                logger.warning(
                    f"Auth failed: No 'sub' claim in token. Payload keys: {list(data.keys())}"
                )
                return jsonify({"error": "Invalid token payload"}), 401

            current_user = db.session.get(User, user_id)
            if not current_user:
                logger.warning(f"Auth failed: User {user_id} not found in DB")
                return jsonify({"error": "User not found"}), 401

            # Token-version revocation check: the `tv` claim minted at token
            # issue time must still match the user's stored token_version.
            # Bumping User.token_version (e.g. on logout or data-deletion)
            # invalidates every outstanding access token for that user.
            stored_tv = getattr(current_user, "token_version", 0) or 0
            token_tv = data.get("tv", 0) or 0
            if token_tv != stored_tv:
                logger.warning(
                    "Auth failed: token_version mismatch for user %s "
                    "(token tv=%s, stored tv=%s)",
                    user_id,
                    token_tv,
                    stored_tv,
                )
                return jsonify({"error": "Token revoked"}), 401

            # Attach user to request context
            request.current_user = current_user
            g.current_user_id = current_user.id

            # COPPA age cap: if the authenticated user is under 13, store their
            # declared age so story routes can cap content calibration accordingly.
            # An under-13 user cannot request adult-calibrated content by sending
            # a higher age value in the request body.
            if (
                hasattr(current_user, "is_under_13")
                and current_user.is_under_13
                and current_user.declared_age
            ):
                g.minor_age_cap = current_user.declared_age
            else:
                g.minor_age_cap = None

        except jwt.ExpiredSignatureError:
            logger.warning("Auth failed: Token expired")
            return jsonify({"error": "Token expired"}), 401
        except jwt.InvalidTokenError as e:
            logger.warning(
                f"Auth failed: Invalid JWT token: {type(e).__name__} - {str(e)}"
            )
            return jsonify({"error": "Invalid token"}), 401
        except ValueError as e:
            logger.error(f"JWT configuration error: {e}")
            return jsonify({"error": "Authentication service unavailable"}), 503

        return f(*args, **kwargs)

    return decorated


def require_parental_consent(f):
    """
    Decorator that enforces COPPA parental consent for under-13 users.
    Must be used after @require_auth.

    Checks that a non-withdrawn ConsentRecord exists for the user before
    allowing access to content-generation endpoints. Users aged 13+ pass
    through unconditionally.

    When COPPA_REQUIRE_VERIFIED_CONSENT is enabled, the record must also
    have verified=True (the email round-trip completed). It defaults OFF so
    the tester-phase build (self_attested consent, verified=False) is not
    blocked — set it true for launch. See audit/LEGAL-COMPLIANCE.md (CMP-2).

    CMP-10 — policy-version staleness: when COPPA_REQUIRE_CURRENT_POLICY_VERSION
    is enabled, a consent record whose policy_version is older than
    CURRENT_POLICY_VERSION (or NULL, i.e. a legacy pre-column row) is treated
    as stale and fails the gate exactly like a missing record — so a privacy-
    policy update forces fresh parental consent. This flag defaults OFF so the
    tester phase is not broken; enable it (together with bumping
    CURRENT_POLICY_VERSION) when a policy change must invalidate prior consent.
    See audit/LEGAL-COMPLIANCE.md (CMP-10).

    Usage:
        @story_bp.route("/generate-story", methods=["POST"])
        @require_auth
        @require_parental_consent
        def generate_story():
            ...
    """

    @wraps(f)
    def decorated(*args, **kwargs):
        if not hasattr(request, "current_user") or not request.current_user:
            return jsonify({"error": "Authentication required"}), 401

        user = request.current_user
        if not getattr(user, "is_under_13", False):
            # User is 13 or older — no consent check needed.
            return f(*args, **kwargs)

        # Under-13: require a valid, non-withdrawn consent record.
        consent = (
            ConsentRecord.query.filter_by(user_id=user.id, withdrawn=False)
            .order_by(ConsentRecord.consent_given_at.desc())
            .first()
        )
        if not consent:
            logger.warning(
                "COPPA: under-13 user %s attempted content generation without parental consent",
                user.id,
            )
            return (
                jsonify(
                    {
                        "error": "Parental consent required",
                        "code": "PARENTAL_CONSENT_REQUIRED",
                    }
                ),
                403,
            )

        # COPPA: when verified-consent enforcement is enabled (production),
        # the record must be verified=True. A self_attested or email_pending
        # record (verified=False) does NOT satisfy the gate. Defaults off for
        # the tester phase — see the decorator docstring / CMP-2.
        require_verified = os.getenv(
            "COPPA_REQUIRE_VERIFIED_CONSENT", "false"
        ).strip().lower() in ("1", "true", "yes", "on")
        if require_verified and not consent.verified:
            logger.warning(
                "COPPA: under-13 user %s has consent record %s with verified=False; "
                "blocked under COPPA_REQUIRE_VERIFIED_CONSENT",
                user.id,
                consent.id,
            )
            return (
                jsonify(
                    {
                        "error": "Verified parental consent required",
                        "code": "PARENTAL_CONSENT_UNVERIFIED",
                    }
                ),
                403,
            )

        # CMP-10: when policy-version enforcement is enabled, a consent record
        # stamped with an older policy_version (or NULL — a legacy row created
        # before the column existed) is stale: the privacy policy has changed
        # since the parent consented, so fresh consent is required. Defaults
        # off for the tester phase — see the decorator docstring / CMP-10.
        require_current_policy = os.getenv(
            "COPPA_REQUIRE_CURRENT_POLICY_VERSION", "false"
        ).strip().lower() in ("1", "true", "yes", "on")
        if require_current_policy:
            record_version = consent.policy_version
            if record_version is None or record_version < CURRENT_POLICY_VERSION:
                logger.warning(
                    "COPPA: under-13 user %s has consent record %s with stale "
                    "policy_version=%s (current=%s); blocked under "
                    "COPPA_REQUIRE_CURRENT_POLICY_VERSION",
                    user.id,
                    consent.id,
                    record_version,
                    CURRENT_POLICY_VERSION,
                )
                return (
                    jsonify(
                        {
                            "error": "Parental consent required for updated privacy policy",
                            "code": "PARENTAL_CONSENT_STALE_POLICY",
                        }
                    ),
                    403,
                )

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
        if not hasattr(request, "current_user") or not request.current_user:
            return jsonify({"error": "Authentication required"}), 401

        # Check admin role
        user = request.current_user
        if (
            not getattr(user, "is_admin", False)
            and not getattr(user, "role", "") == "admin"
        ):
            logger.warning(f"Non-admin user {user.id} attempted admin action")
            return jsonify({"error": "Admin access required"}), 403

        return f(*args, **kwargs)

    return decorated


def require_owner(resource_user_id_param="user_id"):
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
            if not hasattr(request, "current_user") or not request.current_user:
                return jsonify({"error": "Authentication required"}), 401

            # Get resource owner ID from URL params or kwargs
            resource_owner_id = kwargs.get(resource_user_id_param)

            # Also check request.view_args for Flask URL parameters
            if not resource_owner_id and hasattr(request, "view_args"):
                resource_owner_id = request.view_args.get(resource_user_id_param)

            if not resource_owner_id:
                # If no user_id in URL, this decorator shouldn't be used
                logger.error(
                    f"require_owner used but {resource_user_id_param} not found in request"
                )
                return jsonify({"error": "Invalid request"}), 400

            # Verify ownership
            if str(request.current_user.id) != str(resource_owner_id):
                logger.warning(
                    f"IDOR attempt: User {request.current_user.id} tried to access "
                    f"resource belonging to {resource_owner_id}"
                )
                return jsonify({"error": "Access denied"}), 403

            return f(*args, **kwargs)

        return decorated

    return decorator


def get_current_user_id():
    """
    Safely get the current user ID from JWT token without requiring authentication.
    Returns None if no valid token is present.
    Useful for optional user identification (e.g., analytics, rate limiting).
    """
    token = request.headers.get("Authorization")
    if not token:
        # No fallback to the client-supplied X-User-ID header: it is
        # unauthenticated and spoofable. Identity comes only from a verified JWT.
        return None

    try:
        if token.startswith("Bearer "):
            token = token[7:]

        secret = _get_jwt_secret()
        data = jwt.decode(token, secret, algorithms=["HS256"])
        # Identity is standardized on the `sub` claim.
        return data.get("sub")
    except (jwt.InvalidTokenError, ValueError):
        # Token invalid but that's okay for optional auth
        return None


def optional_auth(f):
    """
    Decorator that attempts to authenticate but doesn't require it.
    If valid token present, attaches user to request.current_user.
    If no token or invalid token, continues without user.
    """

    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("Authorization")
        request.current_user = None
        g.current_user_id = None

        if token:
            try:
                if token.startswith("Bearer "):
                    token = token[7:]

                secret = _get_jwt_secret()
                data = jwt.decode(token, secret, algorithms=["HS256"])
                # Identity is standardized on the `sub` claim.
                user_id = data.get("sub")

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
