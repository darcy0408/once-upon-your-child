from functools import wraps

from flask import Blueprint, current_app, jsonify, request

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
    """Factory function to create subscription blueprint with rate limiting.

    The blueprint no longer registers any routes of its own — the client
    reads subscription state via `/api/stripe/subscription-status/<id>`
    (backend/routes/stripe_routes.py), and the `GET
    /api/user/<user_id>/subscription` duplicate was removed as orphaned
    (backend deadwood removal wave 1, 2026-07-07). The factory is kept
    because `require_premium` / `_user_is_premium` in this module are
    imported by story_routes.py, avatar_routes.py, and utility_routes.py.
    """
    subscription_routes = Blueprint("subscription_routes", __name__)
    return subscription_routes
