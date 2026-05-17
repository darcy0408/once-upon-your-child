import hashlib
import re
import secrets
from datetime import datetime, timedelta, timezone
from flask import Blueprint, jsonify, current_app, request
from backend.models.user import User
from backend.models.character import Character
from backend.models.story import Story
from backend.models.consent_record import ConsentRecord, ConsentVerificationCode
from backend.database import db
from backend.middleware.auth import require_auth, require_owner
from backend.utils.audit import audit_log
from backend.utils.email_service import (
    send_consent_verification_email,
    is_email_configured,
)

# --- COPPA email-verification tuning -------------------------------------
# 6-digit numeric code: 1,000,000 possibilities. Combined with the strict
# 5-attempt cap below and a 15-minute expiry, brute-force success probability
# is 5/1,000,000 before the code self-invalidates — secure, and far easier for
# a non-technical parent to type from an email than a long alphanumeric token.
CONSENT_CODE_EXPIRY_MINUTES = 15
CONSENT_CODE_MAX_ATTEMPTS = 5

# Allowed consent_method values accepted by record_consent. 'email_pending' and
# 'debug_bypass' are recorded by the client during the COPPA round trip / dev
# bypass; 'email_verified' is only ever set server-side by the verify endpoint.
ALLOWED_CONSENT_METHODS = (
    'parent', 'self_attested', 'email_verified', 'email_pending', 'debug_bypass',
)

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _is_valid_email(email):
    """Syntactic parent-email validation, mirroring the Flutter client."""
    if not email or not isinstance(email, str):
        return False
    trimmed = email.strip()
    if not trimmed or len(trimmed) > 254:
        return False
    return bool(_EMAIL_RE.match(trimmed))


def _hash_consent_code(code):
    """SHA-256 hex digest of a verification code (codes never stored plaintext)."""
    return hashlib.sha256(code.encode('utf-8')).hexdigest()

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
            if not consent_method or consent_method not in ALLOWED_CONSENT_METHODS:
                return jsonify({
                    'error': 'consent_method must be one of: '
                             + ', '.join(ALLOWED_CONSENT_METHODS)
                }), 400

            parent_email = (data.get('parent_email') or '').strip()[:120] or None
            allow_photo_avatar = data.get('allow_photo_avatar', True)

            # COPPA: 'verified' may only be truthy when the method is a real
            # verified method. The email round trip is verified server-side by
            # the /consent/verify endpoint, never by a client-asserted flag, so
            # an 'email_verified'/'email_pending' record created via this
            # endpoint is forced verified=False here.
            verified = bool(data.get('verified', False))
            if consent_method in ('email_pending', 'email_verified'):
                verified = False

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
                verified=verified,
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
            audit_log('data_deleted', user_id=user_id)

            return jsonify({
                'success': True,
                'message': 'All user data has been deleted and account anonymized.',
            })
        except Exception as e:
            db.session.rollback()
            current_app.logger.exception('Failed to delete data for user %s', user_id)
            return jsonify({'error': 'Data deletion failed. Please try again or contact support.'}), 500

    @user_routes.route('/api/user/<user_id>/export', methods=['GET'])
    @require_auth
    @require_owner('user_id')
    @limiter.limit("5 per hour")
    def export_user_data(user_id):
        """
        Export all user data (COPPA right to access).
        Returns a JSON object containing the user's profile, characters,
        stories, interactive stories, achievements, and consent records.
        """
        try:
            from backend.models import (
                InteractiveStory, StorySegment, StoryChoice,
                InventoryItem, StoryState, UserAchievement, AchievementStats,
            )

            user = request.current_user

            # Characters
            characters = Character.query.filter_by(user_id=user_id).all()
            characters_data = [c.to_dict() for c in characters]

            # Stories
            stories = Story.query.filter_by(user_id=user_id).all()
            stories_data = [{
                'id': s.id,
                'title': s.title,
                'theme': s.theme,
                'created_at': s.created_at.isoformat() if s.created_at else None,
            } for s in stories]

            # Interactive Stories
            interactive_stories = InteractiveStory.query.filter_by(user_id=user_id).all()
            interactive_data = []
            for ist in interactive_stories:
                segments = StorySegment.query.filter_by(story_id=ist.id).all()
                interactive_data.append({
                    'id': ist.id,
                    'title': getattr(ist, 'title', None),
                    'created_at': ist.created_at.isoformat() if ist.created_at else None,
                    'segments_count': len(segments),
                })

            # Consent records
            consent_records = ConsentRecord.query.filter_by(user_id=user_id).all()
            consent_data = [cr.to_dict() for cr in consent_records]

            # Achievements
            achievements = UserAchievement.query.filter_by(user_id=user_id).all()
            achievements_data = [{
                'id': a.id,
                'achievement_type': getattr(a, 'achievement_type', None),
                'earned_at': a.earned_at.isoformat() if getattr(a, 'earned_at', None) else None,
            } for a in achievements]

            export = {
                'exported_at': datetime.now(timezone.utc).isoformat(),
                'user_id': user_id,
                'profile': user.to_dict(),
                'characters': characters_data,
                'stories': stories_data,
                'interactive_stories': interactive_data,
                'consent_records': consent_data,
                'achievements': achievements_data,
            }

            audit_log('data_exported', user_id=user_id)
            response = jsonify(export)
            response.headers['Content-Disposition'] = f'attachment; filename="storyweaver_export_{user_id[:8]}.json"'
            return response
        except Exception as e:
            current_app.logger.exception('Failed to export data for %s', user_id)
            return jsonify({'error': 'Data export failed'}), 500

    # ================================================================
    # COPPA EMAIL-VERIFIED PARENTAL CONSENT — round trip endpoints
    # ================================================================

    @user_routes.route(
        '/api/user/<user_id>/consent/request-verification', methods=['POST']
    )
    @require_auth
    @require_owner('user_id')
    @limiter.limit("5 per hour")  # Aggressive — email send is abuse-prone
    def request_consent_verification(user_id):
        """
        Start the COPPA email round trip for an under-13 user.

        Body: child_age (int), parent_email (str), allow_photo_avatar (bool).
        Generates a single-use, hashed, expiring verification code, emails it
        to the parent, and records consent as PENDING (consent_method=
        'email_pending', verified=False).

        Returns {'success': true} on success (the shape the client checks).
        Fails CLOSED: if email cannot be sent, no code is left active and the
        endpoint returns a 503-style error — consent stays unverified.
        """
        try:
            data = request.get_json(silent=True) or {}
            child_age = data.get('child_age')
            parent_email = (data.get('parent_email') or '').strip()
            allow_photo_avatar = bool(data.get('allow_photo_avatar', False))

            if child_age is None or not isinstance(child_age, int) or child_age < 1:
                return jsonify({'error': 'Valid child_age is required'}), 400
            if not _is_valid_email(parent_email):
                return jsonify({'error': 'A valid parent_email is required'}), 400

            # Email must be configured BEFORE we create state — fail closed.
            if not is_email_configured():
                current_app.logger.error(
                    'Consent verification requested for user %s but email '
                    'service is not configured (RESEND_API_KEY unset).',
                    user_id,
                )
                return jsonify({
                    'error': 'Email verification is temporarily unavailable. '
                             'Please try again later.',
                    'code': 'EMAIL_SERVICE_UNAVAILABLE',
                }), 503

            user = request.current_user
            user.declared_age = child_age
            user.is_under_13 = child_age < 13

            stored_email = parent_email[:120]

            # Record (or refresh) the PENDING consent record. Reuse the most
            # recent non-withdrawn pending record if one exists so repeated
            # "send code" presses don't pile up duplicate records.
            pending = (
                ConsentRecord.query
                .filter_by(
                    user_id=user_id,
                    consent_method='email_pending',
                    withdrawn=False,
                    verified=False,
                )
                .order_by(ConsentRecord.consent_given_at.desc())
                .first()
            )
            if pending is None:
                pending = ConsentRecord(
                    user_id=user_id,
                    child_age=child_age,
                    parent_email=stored_email,
                    consent_method='email_pending',
                    ip_address=request.remote_addr,
                    allow_photo_avatar=allow_photo_avatar,
                    verified=False,
                )
                db.session.add(pending)
            else:
                pending.child_age = child_age
                pending.parent_email = stored_email
                pending.allow_photo_avatar = allow_photo_avatar
                pending.ip_address = request.remote_addr
            db.session.flush()  # ensure pending.id is populated

            # Invalidate any still-active codes for this user — only the newest
            # code should be usable.
            ConsentVerificationCode.query.filter_by(
                user_id=user_id, consumed=False
            ).update({'consumed': True, 'consumed_at': datetime.now(timezone.utc)},
                     synchronize_session=False)

            # Cryptographically random 6-digit numeric code.
            code = f'{secrets.randbelow(1_000_000):06d}'
            expires_at = datetime.now(timezone.utc) + timedelta(
                minutes=CONSENT_CODE_EXPIRY_MINUTES
            )
            code_row = ConsentVerificationCode(
                user_id=user_id,
                consent_record_id=pending.id,
                code_hash=_hash_consent_code(code),
                expires_at=expires_at.replace(tzinfo=None),
            )
            db.session.add(code_row)

            # Send the email BEFORE committing the code, so a send failure
            # leaves no usable code behind (fail closed).
            sent = send_consent_verification_email(
                parent_email, code, CONSENT_CODE_EXPIRY_MINUTES
            )
            if not sent:
                db.session.rollback()
                current_app.logger.error(
                    'Consent verification email failed to send for user %s.',
                    user_id,
                )
                return jsonify({
                    'error': 'Could not send the verification email. Please '
                             'check the address and try again.',
                    'code': 'EMAIL_SEND_FAILED',
                }), 503

            db.session.commit()

            # SECURITY: never log the code or the parent email.
            current_app.logger.info(
                'Consent verification email sent for user %s (code expires '
                'in %d min)', user_id, CONSENT_CODE_EXPIRY_MINUTES
            )
            audit_log('consent_verification_requested', user_id=user_id)

            return jsonify({
                'success': True,
                'message': 'Verification email sent to the parent address.',
                'expires_in_minutes': CONSENT_CODE_EXPIRY_MINUTES,
            })
        except Exception as e:
            db.session.rollback()
            current_app.logger.exception(
                'Failed to request consent verification for %s', user_id
            )
            return jsonify({'error': 'Internal server error'}), 500

    @user_routes.route('/api/user/<user_id>/consent/verify', methods=['POST'])
    @require_auth
    @require_owner('user_id')
    @limiter.limit("10 per hour")  # Plus per-code attempt cap below
    def verify_consent(user_id):
        """
        Complete the COPPA email round trip: submit the code the parent
        received. Body: code (str).

        On success: promotes the pending ConsentRecord to verified
        (consent_method='email_verified', verified=True), consumes the code,
        and returns {'verified': true, 'success': true}.

        On failure: increments the per-code attempt counter, invalidates the
        code once the attempt cap is hit, and returns a non-distinguishing
        {'verified': false} with a 400/410 — never revealing which check
        failed in a way that aids brute force.
        """
        try:
            data = request.get_json(silent=True) or {}
            code = (data.get('code') or '').strip()

            if not code:
                return jsonify({'verified': False, 'success': False,
                                'error': 'A code is required'}), 400

            # Find the newest unconsumed code for this user.
            code_row = (
                ConsentVerificationCode.query
                .filter_by(user_id=user_id, consumed=False)
                .order_by(ConsentVerificationCode.created_at.desc())
                .first()
            )

            # Non-distinguishing failure shape used for every failure path.
            def _fail(status=400):
                return jsonify({'verified': False, 'success': False,
                                'error': 'Invalid or expired code'}), status

            if code_row is None:
                current_app.logger.info(
                    'Consent verify failed for user %s: no active code', user_id
                )
                return _fail(410)

            # Expired — consume so it can't be retried, then fail.
            if code_row.is_expired():
                code_row.consumed = True
                code_row.consumed_at = datetime.now(timezone.utc)
                db.session.commit()
                current_app.logger.info(
                    'Consent verify failed for user %s: code expired', user_id
                )
                return _fail(410)

            # Attempt cap already reached — code is dead.
            if code_row.attempts >= CONSENT_CODE_MAX_ATTEMPTS:
                code_row.consumed = True
                code_row.consumed_at = datetime.now(timezone.utc)
                db.session.commit()
                current_app.logger.warning(
                    'Consent verify blocked for user %s: attempt cap reached',
                    user_id
                )
                return _fail(429)

            # Compare hashes in constant time.
            submitted_hash = _hash_consent_code(code)
            if not secrets.compare_digest(submitted_hash, code_row.code_hash):
                code_row.attempts += 1
                # Invalidate the code if this failure hit the cap.
                if code_row.attempts >= CONSENT_CODE_MAX_ATTEMPTS:
                    code_row.consumed = True
                    code_row.consumed_at = datetime.now(timezone.utc)
                    current_app.logger.warning(
                        'Consent verify: code invalidated for user %s after '
                        '%d failed attempts', user_id, code_row.attempts
                    )
                db.session.commit()
                current_app.logger.info(
                    'Consent verify failed for user %s: code mismatch '
                    '(attempt %d/%d)',
                    user_id, code_row.attempts, CONSENT_CODE_MAX_ATTEMPTS
                )
                return _fail(400)

            # --- Success: consume the code and promote the consent record ---
            code_row.consumed = True
            code_row.consumed_at = datetime.now(timezone.utc)

            record = None
            if code_row.consent_record_id:
                record = db.session.get(
                    ConsentRecord, code_row.consent_record_id
                )
            if record is None:
                # Fall back to the newest pending record for this user.
                record = (
                    ConsentRecord.query
                    .filter_by(
                        user_id=user_id,
                        consent_method='email_pending',
                        withdrawn=False,
                    )
                    .order_by(ConsentRecord.consent_given_at.desc())
                    .first()
                )
            if record is None:
                # No pending record — create a verified one so consent is
                # truthfully recorded rather than lost.
                user = request.current_user
                record = ConsentRecord(
                    user_id=user_id,
                    child_age=user.declared_age or 0,
                    consent_method='email_verified',
                    ip_address=request.remote_addr,
                    verified=True,
                )
                db.session.add(record)
            else:
                record.consent_method = 'email_verified'
                record.verified = True

            db.session.commit()

            current_app.logger.info(
                'Consent verified for user %s (email round trip complete)',
                user_id
            )
            audit_log('consent_verified', user_id=user_id)

            return jsonify({
                'verified': True,
                'success': True,
                'message': 'Parental consent verified.',
            })
        except Exception as e:
            db.session.rollback()
            current_app.logger.exception(
                'Failed to verify consent for %s', user_id
            )
            return jsonify({'error': 'Internal server error'}), 500

    return user_routes

