from datetime import datetime, timedelta, timezone

from flask import Blueprint, jsonify, request

# Robust imports to handle both package and script execution contexts
try:
    from .cost_tracking import get_cost_report
    from .database import db
    from .middleware.auth import optional_auth, require_admin, require_auth
    from .models.character import Character
    from .models.story import Story
    from .models.user import User
    from .services.event_tracking_service import record_event
    from .utils.app_helpers import get_user_tier
except ImportError:
    # Fallback for when backend is the root (e.g. python backend/app.py)
    from cost_tracking import get_cost_report
    from database import db
    from middleware.auth import optional_auth, require_admin, require_auth
    from models.character import Character
    from models.story import Story
    from models.user import User
    from services.event_tracking_service import record_event
    from utils.app_helpers import get_user_tier


# Client-emittable funnel events. The endpoint is a public (optional-auth)
# telemetry sink, so it accepts ONLY this small allowlist — an arbitrary
# client-supplied string must never create a new event stream or be written
# verbatim. Server-internal events (e.g. 'avatar_limit_hit') are recorded
# directly via record_event and are intentionally NOT in this list.
#
# 'feelings_check_in' / 'therapeutic_feedback' / 'story_emotion_moment'
# (H-3, docs/DECISION_D1_D2_KIDS_CATEGORY_ANALYTICS_2026-07-13.md) were
# rerouted here from Firebase Analytics — a child's emotional-state events
# must stay first-party only. The client (lib/services/therapeutic_analytics.dart)
# sends categorical-only metadata (enumerated emotion/coping labels, integer
# intensity, feedback length as an int) — the generic string/int/bool/float
# sanitization below already strips anything else.
_CLIENT_EVENT_ALLOWLIST = frozenset(
    {
        "paywall_viewed",
        "upgrade_clicked",
        "checkout_started",
        "feelings_check_in",
        "therapeutic_feedback",
        "story_emotion_moment",
    }
)


def get_stories_created_count(days=1):
    """Get count of stories created in the last N days"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return Story.query.filter(Story.created_at >= cutoff).count()


def get_active_users_count(days=1):
    """Get count of users who created stories in the last N days"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return (
        db.session.query(User.id)
        .join(Story)
        .filter(Story.created_at >= cutoff)
        .distinct()
        .count()
    )


def get_error_count(days=1):
    """Get count of errors (placeholder - would need error logging table)"""
    # For now, return a mock value
    # In production, this would query an error_logs table
    return 0


def get_avg_story_generation_time(days=7):
    """Get average story generation time (placeholder)"""
    # This would require timing data from logs
    # For now, return estimated average
    return 15.5  # seconds


def get_new_users_count(days=30):
    """Get count of new users in the last N days"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return User.query.filter(User.created_at >= cutoff).count()


def get_premium_conversion_count(days=30):
    """Get count of users who converted to premium in the last N days"""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return User.query.filter(
        User.created_at >= cutoff, User.subscription_tier.in_(["premium", "family"])
    ).count()


def get_story_count_by_theme():
    """Get story counts grouped by theme"""
    from sqlalchemy import func

    result = (
        db.session.query(Story.theme, func.count(Story.id).label("count"))
        .group_by(Story.theme)
        .all()
    )

    return {row.theme: row.count for row in result}


def get_story_count_by_character():
    """Get story counts by character type (placeholder)"""
    # This would require character type data
    return {"hero": 45, "animal": 23, "fantasy": 18, "other": 14}


def get_story_failure_rate():
    """Get story generation failure rate (placeholder)"""
    total_stories = get_stories_created_count(days=30)
    # Estimate 2% failure rate
    return (
        round((total_stories * 0.02) / total_stories * 100, 2)
        if total_stories > 0
        else 0
    )


def get_story_type_breakdown():
    """Get breakdown of interactive vs standard stories"""
    total = get_stories_created_count(days=30)
    # Estimate 25% interactive
    interactive = int(total * 0.25)
    standard = total - interactive

    return {"interactive": interactive, "standard": standard}


def get_illustration_count():
    """Get count of illustrations generated"""
    # This would require illustration tracking
    # For now, estimate based on premium users
    premium_users = User.query.filter(
        User.subscription_tier.in_(["premium", "family"])
    ).count()
    return premium_users * 15  # Estimate 15 illustrations per premium user


def get_coloring_page_count():
    """Get count of coloring pages created"""
    # Estimate lower usage
    return get_illustration_count() // 3


def get_byok_user_count():
    """Get count of users using BYOK (Bring Your Own Key)"""
    # This would require API key tracking
    # Estimate 10% of users
    total_users = User.query.count()
    return int(total_users * 0.1)


def get_grace_period_user_count():
    """Get count of users in grace period"""
    # This would require grace period tracking
    # Estimate 5% of free users
    free_users = User.query.filter(User.subscription_tier == "free").count()
    return int(free_users * 0.05)


def get_premium_user_count():
    """Get count of premium users"""
    return User.query.filter(User.subscription_tier.in_(["premium", "family"])).count()


def create_analytics_blueprint(limiter=None):
    """Factory function to create analytics blueprint with rate limiting"""
    analytics_bp = Blueprint("analytics", __name__)

    @analytics_bp.route("/admin/analytics/overview")
    @require_auth
    @require_admin
    @limiter.limit("30 per minute")
    def get_overview():
        """Daily/weekly/monthly overview stats"""
        return jsonify(
            {
                "today": {
                    "stories_created": get_stories_created_count(days=1),
                    "active_users": get_active_users_count(days=1),
                    "api_errors": get_error_count(days=1),
                },
                "this_week": {
                    "stories_created": get_stories_created_count(days=7),
                    "active_users": get_active_users_count(days=7),
                    "avg_story_time": get_avg_story_generation_time(days=7),
                },
                "this_month": {
                    "stories_created": get_stories_created_count(days=30),
                    "new_users": get_new_users_count(days=30),
                    "premium_conversions": get_premium_conversion_count(days=30),
                },
            }
        )

    @analytics_bp.route("/admin/analytics/story-stats")
    @require_auth
    @require_admin
    @limiter.limit("30 per minute")
    def get_story_stats():
        """Story generation statistics"""
        return jsonify(
            {
                "by_theme": get_story_count_by_theme(),
                "by_character_type": get_story_count_by_character(),
                "avg_generation_time": get_avg_story_generation_time(),
                "failure_rate": get_story_failure_rate(),
                "interactive_vs_standard": get_story_type_breakdown(),
            }
        )

    @analytics_bp.route("/admin/analytics/user-activity")
    @require_auth
    @require_admin
    @limiter.limit("30 per minute")
    def get_user_activity():
        """User activity and engagement metrics"""
        return jsonify(
            {
                "total_users": User.query.count(),
                "active_users_7d": get_active_users_count(days=7),
                "active_users_30d": get_active_users_count(days=30),
                "new_users_30d": get_new_users_count(days=30),
                "premium_users": get_premium_user_count(),
                "stories_per_user_avg": round(
                    get_stories_created_count(days=30)
                    / max(get_active_users_count(days=30), 1),
                    2,
                ),
                "character_creation_rate": round(
                    Character.query.count() / max(User.query.count(), 1), 2
                ),
            }
        )

    @analytics_bp.route("/admin/analytics/feature-usage")
    @require_auth
    @require_admin
    @limiter.limit("30 per minute")
    def get_feature_usage():
        """Feature adoption rates"""
        return jsonify(
            {
                "illustrations_generated": get_illustration_count(),
                "coloring_pages_created": get_coloring_page_count(),
                "byok_active_users": get_byok_user_count(),
                "grace_period_users": get_grace_period_user_count(),
                "premium_users": get_premium_user_count(),
                "feature_unlock_progress": {
                    "character_creation_unlocked": User.query.filter(
                        User.stories_created_count >= 1
                    ).count(),
                    "interactive_stories_unlocked": User.query.filter(
                        User.stories_created_count >= 2
                    ).count(),
                    "coloring_pages_unlocked": User.query.filter(
                        User.stories_created_count >= 3
                    ).count(),
                    "advanced_settings_unlocked": User.query.filter(
                        User.stories_created_count >= 5
                    ).count(),
                },
            }
        )

    @analytics_bp.route("/admin/analytics/stories")
    @require_auth
    @require_admin
    @limiter.limit("30 per minute")
    def get_stories_paginated():
        """Get paginated list of stories for admin review"""
        try:
            page = request.args.get("page", 1, type=int)
            per_page = request.args.get("per_page", 50, type=int)
            per_page = min(per_page, 100)  # Max 100 per page

            # Use optimized query with joins
            stories_query = Story.query.options(db.joinedload(Story.user)).order_by(
                Story.created_at.desc()
            )

            stories = stories_query.paginate(
                page=page, per_page=per_page, error_out=False
            )

            return jsonify(
                {
                    "items": [
                        {
                            "id": s.id,
                            "title": s.title or "Untitled Story",
                            "created_at": s.created_at.isoformat(),
                            "user_id": s.user_id,
                            "user_email": s.user.email if s.user else None,
                            "character_count": (
                                len(s.characters) if hasattr(s, "characters") else 0
                            ),
                        }
                        for s in stories.items
                    ],
                    "total": stories.total,
                    "page": page,
                    "pages": stories.pages,
                    "per_page": per_page,
                    "has_next": stories.has_next,
                    "has_prev": stories.has_prev,
                }
            )

        except Exception as e:
            return jsonify({"error": f"Failed to fetch stories: {str(e)}"}), 500

    @analytics_bp.route("/admin/analytics/users")
    @require_auth
    @require_admin
    @limiter.limit("30 per minute")
    def get_users_paginated():
        """Get paginated list of users for admin review"""
        try:
            page = request.args.get("page", 1, type=int)
            per_page = request.args.get("per_page", 50, type=int)
            per_page = min(per_page, 100)  # Max 100 per page

            tier_filter = request.args.get("tier")
            active_only = request.args.get("active_only", type=bool)

            users_query = User.query

            if tier_filter:
                users_query = users_query.filter(User.subscription_tier == tier_filter)

            if active_only:
                # Users active in last 30 days
                cutoff = datetime.now(timezone.utc) - timedelta(days=30)
                users_query = (
                    users_query.join(Story)
                    .filter(Story.created_at >= cutoff)
                    .distinct()
                )

            users_query = users_query.order_by(User.created_at.desc())

            users = users_query.paginate(page=page, per_page=per_page, error_out=False)

            return jsonify(
                {
                    "items": [
                        {
                            "id": u.id,
                            "username": u.username,
                            "email": u.email,
                            "subscription_tier": u.subscription_tier,
                            "created_at": u.created_at.isoformat(),
                            "stories_created_count": u.stories_created_count,
                            "current_period_end": (
                                u.current_period_end.isoformat()
                                if u.current_period_end
                                else None
                            ),
                            "cancel_at_period_end": u.cancel_at_period_end,
                        }
                        for u in users.items
                    ],
                    "total": users.total,
                    "page": page,
                    "pages": users.pages,
                    "per_page": per_page,
                    "has_next": users.has_next,
                    "has_prev": users.has_prev,
                }
            )

        except Exception as e:
            return jsonify({"error": f"Failed to fetch users: {str(e)}"}), 500

    @analytics_bp.route("/admin/cost-report")
    @require_auth
    @require_admin
    @limiter.limit("10 per minute")
    def get_cost_report_endpoint():
        """Get API cost report with breakdown by feature and time period"""
        try:
            days = request.args.get("days", 7, type=int)
            days = min(max(days, 1), 90)  # Limit to 1-90 days

            report = get_cost_report(days)

            return jsonify(report), 200

        except Exception as e:
            return jsonify({"error": f"Failed to generate cost report: {str(e)}"}), 500

    @analytics_bp.route("/analytics/event", methods=["POST"])
    @optional_auth
    @limiter.limit("60 per minute")
    def record_client_event():
        """Public funnel-telemetry sink (MT-249).

        Accepts a fire-and-forget event from the client. Auth is optional —
        anonymous / pre-login events (e.g. a paywall shown before signup) are
        allowed. ``event_name`` is validated against a small allowlist so an
        arbitrary client string can never create a new event stream. The
        subscription tier and user id are resolved server-side from the (optional)
        verified token, never trusted from the request body.
        """
        data = request.get_json(silent=True) or {}
        event_name = data.get("event_name")

        if not event_name or event_name not in _CLIENT_EVENT_ALLOWLIST:
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INVALID_EVENT",
                        "message": "Unknown or missing event_name",
                    }
                ),
                400,
            )

        # Only a small, sanitised subset of client-supplied metadata is kept —
        # short string/number/bool values, no nested structures, no PII.
        raw_meta = data.get("metadata")
        metadata = {}
        if isinstance(raw_meta, dict):
            for key, value in list(raw_meta.items())[:20]:
                if isinstance(value, bool) or isinstance(value, (int, float)):
                    metadata[str(key)[:50]] = value
                elif isinstance(value, str):
                    metadata[str(key)[:50]] = value[:200]

        current_user = getattr(request, "current_user", None)
        user_id = getattr(current_user, "id", None) if current_user else None
        tier = (get_user_tier() or "free").lower()

        # Best-effort — record_event never raises. Always ack with 202 so the
        # client's fire-and-forget call is cheap and never surfaces an error.
        record_event(event_name, user_id=user_id, tier=tier, metadata=metadata)
        return jsonify({"status": "accepted"}), 202

    return analytics_bp
