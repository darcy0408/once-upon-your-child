import os
import logging
from flask import Blueprint, request, jsonify
import stripe
from dotenv import load_dotenv

from ..models.user import User
from ..middleware.auth import require_auth

load_dotenv()

stripe_routes = Blueprint('stripe_routes', __name__)
logger = logging.getLogger("stripe_routes")

# Stripe API key will be set by init_stripe_api
# stripe.api_key = os.getenv('STRIPE_API_KEY') # REMOVED

def init_stripe_api(app):
    """Initializes Stripe API key using app config."""
    stripe.api_key = app.config.get('STRIPE_API_KEY')
    if not stripe.api_key:
        logger.warning("STRIPE_API_KEY not set in app config - Stripe routes may not function.")
    else:
        logger.info("✓ Stripe API configured via init_stripe_api")

def get_price_ids():
    """Get Stripe Price IDs from environment variables (loaded dynamically)"""
    return {
        'premium': os.getenv('STRIPE_PRICE_ID_PREMIUM', 'price_PLACEHOLDER_PREMIUM'),
        'family': os.getenv('STRIPE_PRICE_ID_FAMILY', 'price_PLACEHOLDER_FAMILY'),
    }

def get_trial_days():
    """Return trial period in days, or None to disable trial."""
    raw = os.getenv('STRIPE_TRIAL_DAYS', '14')
    try:
        days = int(raw)
        return days if days > 0 else None
    except ValueError:
        return None

@stripe_routes.route('/create-checkout-session', methods=['POST'])
@require_auth
def create_checkout_session():
    data = request.get_json(silent=True) or {}
    tier = data.get('tier')
    # Always use the authenticated user ID for checkout
    user_id = request.current_user.id

    PRICE_IDS = get_price_ids()
    logger.info(f"Creating checkout for tier '{tier}' with price_id: {PRICE_IDS.get(tier)}")

    if not tier or tier not in PRICE_IDS:
        return jsonify({'error': 'Invalid subscription tier'}), 400

    try:
        trial_days = get_trial_days()
        session_params = dict(
            payment_method_types=['card'],
            line_items=[{'price': PRICE_IDS[tier], 'quantity': 1}],
            mode='subscription',
            success_url='https://grand-light-production-68d9.up.railway.app/#/subscription-success',
            cancel_url='https://grand-light-production-68d9.up.railway.app/#/subscription-canceled',
        )
        if trial_days:
            session_params['subscription_data'] = {'trial_period_days': trial_days}
            logger.info(f"Trial enabled: {trial_days} days for tier '{tier}'")

        checkout_session = stripe.checkout.Session.create(**session_params)
        return jsonify({
            'id': checkout_session.id,
            'checkout_url': checkout_session.url
        })
    except Exception as e:
        logger.exception("Failed to create checkout session")
        return jsonify(error="Failed to create checkout session. Please try again."), 500

@stripe_routes.route('/create-portal-session', methods=['POST'])
@require_auth
def create_portal_session():
    """
    Create a Stripe Billing Portal session so the user can manage their
    subscription (update payment method, cancel, view invoices).
    """
    user = request.current_user

    if not user.stripe_customer_id:
        return jsonify({'error': 'No billing account found for this user'}), 404

    try:
        portal_session = stripe.billing_portal.Session.create(
            customer=user.stripe_customer_id,
            return_url='https://grand-light-production-68d9.up.railway.app/#/settings',
        )
        return jsonify({'portal_url': portal_session.url})
    except Exception as e:
        logger.exception("Failed to create portal session")
        return jsonify({'error': 'Failed to open billing portal. Please try again.'}), 500


@stripe_routes.route('/subscription-status/<user_id>', methods=['GET'])
@require_auth
def get_subscription_status(user_id):
    """
    Get the current subscription status for a user.
    Returns subscription tier, status, and renewal date.
    """
    try:
        # User already validated by @require_auth decorator
        user = request.current_user

        # Get subscription from Stripe if customer_id exists
        if user.stripe_customer_id:
            subscriptions = stripe.Subscription.list(
                customer=user.stripe_customer_id,
                status='active',
                limit=1
            )

            if subscriptions.data:
                sub = subscriptions.data[0]
                return jsonify({
                    'status': 'active',
                    'tier': user.subscription_tier or 'free',
                    'current_period_end': sub.current_period_end,
                    'cancel_at_period_end': sub.cancel_at_period_end
                })

        # No active subscription
        return jsonify({
            'status': 'inactive',
            'tier': 'free'
        })

    except Exception as e:
        logger.exception("Failed to get subscription status")
        return jsonify({'error': 'Failed to retrieve subscription status'}), 500
