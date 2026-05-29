from datetime import datetime, timezone
from functools import wraps

from flask import Blueprint, current_app, jsonify, request

from backend.database import db
from backend.middleware.auth import require_auth, require_owner
from backend.models.user import User


def _format_timestamp(value):
    if not value:
        value = datetime.now(timezone.utc)
    if value.tzinfo:
        value = value.astimezone()
    return value.replace(microsecond=0).isoformat() + "Z"


# ---------------------------------------------------------------------------
# M-8 (server-side entitlement enforcement)
#
# The audit found premium-gated capabilities (coloring, interactive stories,
# multi-character, export) gated only by client-side flags in editable
# SharedPreferences. Client flags are cosmetic; the server must enforce the
# entitlement off the authoritative `User.subscription_tier`.
#
# `require_premium` is the single reusable gate. Apply it AFTER `@require_auth`
# on any endpoint that exposes a paid capability. It never trusts a tier value
# from the request body — only `request.current_user.subscription_tier`.
# ---------------------------------------------------------------------------

# Tiers that count as a paid/premium entitlement. BYOK users supply their own
# API key and are treated as entitled to paid features.
PREMIUM_TIERS = frozenset({"premium", "family", "byok"})


def _user_is_premium(user) -> bool:
    """True if *user* holds a paid entitlement, judged server-side only."""
    if user is None:
        return False
    tier = (getattr(user, "subscription_tier", "") or "").strip().lower()
    if tier in PREMIUM_TIERS:
        return True
    # BYOK can also be carried as a standalone flag rather than a tier label.
    if getattr(user, "has_byok", False):
        return True
    return False


def require_premium(f):
    """Decorator: require a paid subscription tier. Use AFTER @require_auth.

    Gates purely on the authoritative `User.subscription_tier` (and the
    server-side `has_byok` flag) — never on any client-supplied tier/premium
    value. Returns 403 with an `upgrade_required` code so the client can show
    the upgrade CTA.
    """

    @wraps(f)
    def decorated(*args, **kwargs):
        user = getattr(request, "current_user", None)
        if user is None:
            return jsonify({"error": "Authentication required"}), 401
        if not _user_is_premium(user):
            current_app.logger.info(
                "Premium-gated capability denied for user %s (tier=%s)",
                getattr(user, "id", "?"),
                getattr(user, "subscription_tier", None),
            )
            return (
                jsonify(
                    {
                        "error": "This feature requires a premium subscription",
                        "code": "upgrade_required",
                    }
                ),
                403,
            )
        return f(*args, **kwargs)

    return decorated


def create_subscription_blueprint(limiter=None):
    """Factory function to create subscription blueprint with rate limiting."""
    subscription_routes = Blueprint("subscription_routes", __name__)

    @subscription_routes.route("/api/user/<user_id>/subscription", methods=["GET"])
    @require_auth
    @require_owner("user_id")
    @limiter.limit("60 per minute")  # Read-heavy endpoint
    def get_subscription(user_id):
        try:
            user = db.session.get(User, user_id)
            if not user:
                return jsonify({"error": "User not found"}), 404

            subscription_data = {
                "user_id": user.id,
                "tier": user.subscription_tier or "free",
                "status": user.subscription_status or "active",
                "current_period_end": (
                    _format_timestamp(user.current_period_end)
                    if user.current_period_end
                    else None
                ),
                "cancel_at_period_end": bool(user.cancel_at_period_end),
            }
            return jsonify(subscription_data)
        except Exception:
            current_app.logger.exception("Failed to load subscription for %s", user_id)
            return jsonify({"error": "Internal server error"}), 500

    return subscription_routes
