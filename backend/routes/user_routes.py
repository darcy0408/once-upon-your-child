from datetime import datetime, timedelta, timezone
from flask import Blueprint, jsonify, current_app
from backend.models.user import User
from backend.models.character import Character
from backend.models.story import Story
from backend.database import db

user_routes = Blueprint('user_routes', __name__)

# Subscription limits
SUBSCRIPTION_LIMITS = {
    'free': {'stories': 10, 'characters': 2},
    'premium': {'stories': 100, 'characters': 5},
    'family': {'stories': 500, 'characters': 10},
}

def _get_period_start_end():
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    period_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if now.month == 12:
        period_end = period_start.replace(year=now.year + 1, month=1)
    else:
        period_end = period_start.replace(month=now.month + 1)
    return period_start, period_end

def _normalize_timestamp(value):
    if not value:
        return None
    if value.tzinfo:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value

def _get_period_bounds_for_user(user):
    default_start, default_end = _get_period_start_end()
    if not user.current_period_end:
        return default_start, default_end
    period_end = _normalize_timestamp(user.current_period_end)
    current_month_start = period_end.replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    if current_month_start.month == 1:
        period_start = current_month_start.replace(year=current_month_start.year - 1, month=12)
    else:
        period_start = current_month_start.replace(month=current_month_start.month - 1)
    return period_start, period_end

def _format_timestamp(value):
    if not value:
        return None
    return value.replace(microsecond=0).isoformat() + 'Z'

@user_routes.route('/api/user/<user_id>/usage-stats', methods=['GET'])
def get_usage_stats(user_id):
    try:
        user = db.session.get(User, user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        period_start, period_end = _get_period_bounds_for_user(user)

        # Count stories this month
        stories_this_month = Story.query.filter(
            Story.user_id == user_id,
            Story.created_at >= period_start,
            Story.created_at < period_end
        ).count()

        # Count characters
        characters_count = Character.query.filter(Character.user_id == user_id).count()

        # Get limits
        tier = user.subscription_tier or 'free'
        limits = SUBSCRIPTION_LIMITS.get(tier, SUBSCRIPTION_LIMITS['free'])

        response = {
            'stories_this_month': stories_this_month,
            'stories_limit': limits['stories'],
            'characters_count': characters_count,
            'characters_limit': limits['characters'],
            'period_start': _format_timestamp(period_start),
            'period_end': _format_timestamp(period_end),
        }
        return jsonify(response)
    except Exception as e:
        current_app.logger.exception('Failed to get usage stats for %s', user_id)
        return jsonify({'error': 'Internal server error'}), 500

@user_routes.route('/api/user/<user_id>/cancel-subscription', methods=['POST'])
def cancel_subscription(user_id):
    try:
        user = db.session.get(User, user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        user.cancel_at_period_end = True
        db.session.commit()

        response = {
            'success': True,
            'message': 'Subscription will be canceled at period end',
            'cancel_at_period_end': True,
        }
        return jsonify(response)
    except Exception as e:
        current_app.logger.exception('Failed to cancel subscription for %s', user_id)
        return jsonify({'error': 'Internal server error'}), 500
