from datetime import datetime, timedelta, timezone
from flask import Blueprint, jsonify, current_app, request
from backend.models.user import User
from backend.models.character import Character
from backend.models.story import Story
from backend.models.consent_record import ConsentRecord
from backend.database import db
from backend.middleware.auth import require_auth, require_owner

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


def create_user_routes_blueprint(limiter=None):
    """Factory function to create user routes blueprint with rate limiting."""
    user_routes = Blueprint('user_routes', __name__)

    @user_routes.route('/api/user/<user_id>/usage-stats', methods=['GET'])
    @require_auth
    @require_owner('user_id')
    @limiter.limit("60 per minute")  # Read-heavy endpoint
    def get_usage_stats(user_id):
        try:
            # User already validated by @require_owner decorator
            user = request.current_user

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
    @require_auth
    @require_owner('user_id')
    @limiter.limit("5 per hour")  # Strict limit on subscription changes
    def cancel_subscription(user_id):
        try:
            # User already validated by @require_owner decorator
            user = request.current_user

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

    # ================================================================
    # COPPA COMPLIANCE ENDPOINTS
    # ================================================================

    @user_routes.route('/api/user/<user_id>/age', methods=['PATCH'])
    @require_auth
    @require_owner('user_id')
    @limiter.limit("10 per hour")
    def set_declared_age(user_id):
        """Set the declared age for a user. Updates COPPA flag automatically."""
        try:
            data = request.get_json(silent=True) or {}
            age = data.get('age')

            if age is None or not isinstance(age, int) or age < 1 or age > 120:
                return jsonify({'error': 'Valid age (1-120) is required'}), 400

            user = request.current_user
            user.declared_age = age
            user.is_under_13 = age < 13
            db.session.commit()

            return jsonify({
                'success': True,
                'declared_age': age,
                'is_under_13': user.is_under_13,
            })
        except Exception as e:
            current_app.logger.exception('Failed to set age for %s', user_id)
            return jsonify({'error': 'Internal server error'}), 500

    @user_routes.route('/api/user/<user_id>/consent', methods=['POST'])
    @require_auth
    @require_owner('user_id')
    @limiter.limit("10 per hour")
    def record_consent(user_id):
        """
        Record parental consent server-side (COPPA compliance).
        Required fields: child_age, consent_method
        Optional fields: parent_email, allow_photo_avatar
        """
        try:
            data = request.get_json(silent=True) or {}
            child_age = data.get('child_age')
            consent_method = data.get('consent_method')

            if child_age is None or not isinstance(child_age, int) or child_age < 1:
                return jsonify({'error': 'Valid child_age is required'}), 400
            if not consent_method or consent_method not in ('parent', 'self_attested', 'email_verified'):
                return jsonify({'error': 'consent_method must be one of: parent, self_attested, email_verified'}), 400

            parent_email = (data.get('parent_email') or '').strip()[:120] or None
            allow_photo_avatar = data.get('allow_photo_avatar', True)

            # Also update the user's age fields
            user = request.current_user
            user.declared_age = child_age
            user.is_under_13 = child_age < 13

            record = ConsentRecord(
                user_id=user_id,
                child_age=child_age,
                parent_email=parent_email,
                consent_method=consent_method,
                ip_address=request.remote_addr,
                allow_photo_avatar=bool(allow_photo_avatar),
            )
            db.session.add(record)
            db.session.commit()

            current_app.logger.info(
                'Consent recorded for user %s: age=%d, method=%s',
                user_id, child_age, consent_method
            )

            return jsonify({
                'success': True,
                'consent_id': record.id,
                'consent': record.to_dict(),
            }), 201
        except Exception as e:
            current_app.logger.exception('Failed to record consent for %s', user_id)
            return jsonify({'error': 'Internal server error'}), 500

    @user_routes.route('/api/user/<user_id>/data', methods=['DELETE'])
    @require_auth
    @require_owner('user_id')
    @limiter.limit("3 per hour")  # Very strict — destructive operation
    def delete_user_data(user_id):
        """
        Delete all user data (COPPA right to erasure).
        Deletes: characters, stories, interactive stories, achievements, consent records.
        Anonymizes the user record.
        """
        try:
            from backend.models import (
                InteractiveStory, StorySegment, StoryChoice,
                InventoryItem, StoryState, UserAchievement, AchievementStats,
            )

            user = request.current_user

            # --- Delete interactive story data (cascade-aware) ---
            interactive_stories = InteractiveStory.query.filter_by(user_id=user_id).all()
            for story in interactive_stories:
                StoryChoice.query.filter(
                    StoryChoice.segment_id.in_(
                        db.session.query(StorySegment.id).filter_by(story_id=story.id)
                    )
                ).delete(synchronize_session=False)
                StorySegment.query.filter_by(story_id=story.id).delete()
                InventoryItem.query.filter_by(story_id=story.id).delete()
                StoryState.query.filter_by(story_id=story.id).delete()
                db.session.delete(story)

            # --- Delete linear stories ---
            Story.query.filter_by(user_id=user_id).delete()

            # --- Delete characters ---
            Character.query.filter_by(user_id=user_id).delete()

            # --- Delete achievements ---
            UserAchievement.query.filter_by(user_id=user_id).delete()
            AchievementStats.query.filter_by(user_id=user_id).delete()

            # --- Delete consent records ---
            ConsentRecord.query.filter_by(user_id=user_id).delete()

            # --- Anonymize user record ---
            import uuid
            anon_id = str(uuid.uuid4())[:8]
            user.username = f'deleted_{anon_id}'
            user.email = f'deleted_{anon_id}@deleted.local'
            user.password_hash = 'DELETED'
            user.declared_age = None
            user.is_under_13 = False
            user.stripe_customer_id = None
            user.gemini_api_key_encrypted = None
            user.has_byok = False
            user.stories_created_count = 0
            user.stories_generated_this_month = 0
            user.illustrations_generated_this_month = 0

            db.session.commit()

            current_app.logger.info('All data deleted for user %s (anonymized)', user_id)

            return jsonify({
                'success': True,
                'message': 'All user data has been deleted and account anonymized.',
            })
        except Exception as e:
            db.session.rollback()
            current_app.logger.exception('Failed to delete data for user %s', user_id)
            return jsonify({'error': 'Data deletion failed. Please try again or contact support.'}), 500

    return user_routes

