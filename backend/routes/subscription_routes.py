from datetime import datetime, timedelta, timezone

from flask import Blueprint, jsonify, current_app

from backend.database import db
from backend.models.user import User

subscription_routes = Blueprint('subscription_routes', __name__)

@subscription_routes.route('/api/user/<user_id>/subscription', methods=['GET'])
def get_subscription(user_id):
    try:
        user = db.session.get(User, user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404

        subscription_data = {
            'user_id': user.id,
            'tier': user.subscription_tier or 'free',
            'status': user.subscription_status or 'active',
            'current_period_end': _format_timestamp(user.current_period_end) if user.current_period_end else None,
            'cancel_at_period_end': bool(user.cancel_at_period_end),
        }
        return jsonify(subscription_data)
    except Exception:
        current_app.logger.exception('Failed to load subscription for %s', user_id)
        return jsonify({'error': 'Internal server error'}), 500


def _format_timestamp(value):
    if not value:
        value = datetime.now(timezone.utc)
    if value.tzinfo:
        value = value.astimezone()
    return value.replace(microsecond=0).isoformat() + 'Z'
