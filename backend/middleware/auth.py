"""
Authentication middleware for Story Weaver API.
Provides JWT-based authentication and authorization decorators.

Security features:
- require_auth: Validates JWT token and attaches user to request; sets g.minor_age_cap
- require_parental_consent: COPPA gate — blocks under-13 users without a ConsentRecord
- require_photo_avatar_consent: COPPA gate — blocks photo-based avatar generation
  without the parental `allow_photo_avatar` opt-in (MT-363)
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

from backend.config import env_is_production
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
        if env_is_production():
            logger.error("JWT_SECRET_KEY not properly configured in production!")
            raise ValueError("JWT_SECRET_KEY must be set in production")
        # In dev, allow but warn
        logger.warning("Using default JWT secret - NOT SAFE FOR PRODUCTION")
        return "dev-secret-key"
    return secret


_blocklist_redis = None
_blocklist_redis_url = None


def is_jti_blocklisted(jti):
    """Return True if this JWT ID was written to the Redis revocation blocklist.

    Shared by require_auth/optional_auth and by flask-jwt-extended's
    token_in_blocklist_loader (app.py) so both auth paths agree.

    Degrades gracefully: with no Redis configured, or Redis unreachable, the
    check is skipped so a Redis outage never locks users out of the app.
    """
    global _blocklist_redis, _blocklist_redis_url

    if not jti:
        return False
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return False
    try:
        if _blocklist_redis is None or _blocklist_redis_url != redis_url:
            import redis as _redis_lib

            # One pooled client per process — this runs on every
            # authenticated request, so don't reconnect each time.
            _blocklist_redis = _redis_lib.from_url(
                redis_url, socket_connect_timeout=1, socket_timeout=1
            )
            _blocklist_redis_url = redis_url
        return bool(_blocklist_redis.exists(f"jwt:blocklist:{jti}"))
    except Exception as exc:
        logger.warning(
            "JWT blocklist: Redis unavailable (%s) — skipping revocation check", exc
        )
        return False


def _decode_access_token(token):
    """Decode a bearer token and confirm it is a live *access* token.

    Raises jwt.InvalidTokenError (bad signature, expired, wrong type,
    blocklisted) or ValueError (JWT secret not configured).

    The `type` check matters: refresh tokens are signed with the same secret
    and live 30 days, so without it a refresh token works as a bearer token
    on every protected route (MT-454). A token with no `type` claim is
    rejected too — every token this app issues carries one.
    """
    if token.startswith("Bearer "):
        token = token[7:]

    data = jwt.decode(token, _get_jwt_secret(), algorithms=["HS256"])

    if data.get("type") != "access":
        raise jwt.InvalidTokenError("not an access token")
    if is_jti_blocklisted(data.get("jti")):
        raise jwt.InvalidTokenError("token has been revoked")
    return data


def token_version_matches(user, claims):
    """Token-version revocation check.

    The `tv` claim minted at token issue time must still match the user's
    stored token_version. Bumping User.token_version (e.g. on logout or
    data-deletion) invalidates every outstanding token for that user.
    """
    stored_tv = getattr(user, "token_version", 0) or 0
    token_tv = claims.get("tv", 0) or 0
    return token_tv == stored_tv


def _user_from_optional_token(token):
    """Resolve the user for an optional-auth request, or None.

    Applies the same checks as require_auth (access type, blocklist,
    token_version) — a token require_auth would refuse must not identify
    a user here either (MT-456).
    """
    try:
        data = _decode_access_token(token)
    except (jwt.InvalidTokenError, ValueError):
        # Invalid token is fine for optional auth
        return None

    # Identity is standardized on the `sub` claim.
    user_id = data.get("sub")
    if not user_id:
        return None
    user = db.session.get(User, user_id)
    if not user or not token_version_matches(user, data):
        return None
    return user


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
            data = _decode_access_token(token)

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

            if not token_version_matches(current_user, data):
                logger.warning(
                    "Auth failed: token_version mismatch for user %s "
                    "(token tv=%s, stored tv=%s)",
                    user_id,
                    data.get("tv", 0) or 0,
                    getattr(current_user, "token_version", 0) or 0,
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

        # Audit #1/#2 — unresolved-age hole: is_under_13 defaults False and is
        # only ever set when the client honestly declares an age, so an
        # anonymous/never-onboarded account reaches generation as a de-facto
        # "13+" user with no consent. When ENFORCE_RESOLVED_AGE is enabled the
        # server refuses to serve a user whose age it has never established
        # (declared_age is None) — closing the bypass instead of failing open.
        #
        # Defaults OFF: today the client does not sync an age server-side for
        # 13+/adult users, so enabling this without the companion client change
        # would block legitimate adults. Flip it on at launch once every
        # onboarding path POSTs declared_age. See the launch checklist in
        # docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md.
        enforce_resolved_age = os.getenv(
            "ENFORCE_RESOLVED_AGE", "false"
        ).strip().lower() in ("1", "true", "yes", "on")
        if enforce_resolved_age and getattr(user, "declared_age", None) is None:
            logger.warning(
                "COPPA: user %s reached a gated endpoint with no resolved age; "
                "blocked under ENFORCE_RESOLVED_AGE",
                user.id,
            )
            return (
                jsonify(
                    {
                        "error": "Age verification required",
                        "code": "AGE_REQUIRED",
                    }
                ),
                403,
            )

        if not getattr(user, "is_under_13", False):
            # User is 13 or older (with a resolved age) — no consent check needed.
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


def require_photo_avatar_consent(f):
    """
    Decorator that enforces the parental ``allow_photo_avatar`` opt-in before a
    route may read/process an uploaded photo of a child's face (MT-363).
    Must be used after @require_auth.

    This is a SEPARATE, narrower gate than ``require_parental_consent``:
    - ``require_parental_consent`` only fires for under-13 accounts and checks
      that *some* consent record exists.
    - ``require_photo_avatar_consent`` applies to EVERY account regardless of
      declared age (every account on this app belongs to a child-directed
      product) and specifically checks the ``allow_photo_avatar`` opt-in,
      because photo-based avatar generation sends a real photo of a child's
      face to a third-party image-generation provider — a distinct,
      affirmative consent from the general COPPA gate.

    FAIL CLOSED (CMP-8): if no non-withdrawn ConsentRecord exists for the
    user, or the most recent one has ``allow_photo_avatar`` != True, the
    request is rejected. Any ambiguity — no record at all, a withdrawn
    record, a record that predates the opt-in — denies rather than allows.
    Callers must apply this BEFORE reading the uploaded photo bytes or
    invoking the image-generation service.

    Usage:
        @avatar_bp.route("/generate-custom-avatar", methods=["POST"])
        @require_auth
        @require_parental_consent
        @require_photo_avatar_consent
        def generate_custom_avatar():
            ...
    """

    @wraps(f)
    def decorated(*args, **kwargs):
        if not hasattr(request, "current_user") or not request.current_user:
            return jsonify({"error": "Authentication required"}), 401

        user = request.current_user

        consent = (
            ConsentRecord.query.filter_by(user_id=user.id, withdrawn=False)
            .order_by(ConsentRecord.consent_given_at.desc())
            .first()
        )
        if not consent or not consent.allow_photo_avatar:
            logger.warning(
                "MT-363: user %s attempted photo-based avatar generation "
                "without allow_photo_avatar consent (consent_record=%s)",
                user.id,
                getattr(consent, "id", None),
            )
            return (
                jsonify(
                    {
                        "error": "Parental consent for photo-based avatars is required",
                        "code": "PHOTO_AVATAR_CONSENT_REQUIRED",
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

    user = _user_from_optional_token(token)
    return user.id if user else None


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
            current_user = _user_from_optional_token(token)
            if current_user:
                request.current_user = current_user
                g.current_user_id = current_user.id

        return f(*args, **kwargs)

    return decorated
