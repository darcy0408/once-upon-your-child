import os
import logging
from flask import Blueprint, request, jsonify
import stripe
from dotenv import load_dotenv

from ..models.user import User

load_dotenv()

stripe_routes = Blueprint('stripe_routes', __name__)
logger = logging.getLogger("stripe_routes")

stripe.api_key = os.getenv('STRIPE_API_KEY')

def get_price_ids():
    """Get Stripe Price IDs from environment variables (loaded dynamically)"""
    return {
        'premium': os.getenv('STRIPE_PRICE_ID_PREMIUM', 'price_PLACEHOLDER_PREMIUM'),
        'family': os.getenv('STRIPE_PRICE_ID_FAMILY', 'price_PLACEHOLDER_FAMILY'),
    }

@stripe_routes.route('/create-checkout-session', methods=['POST'])
def create_checkout_session():
    data = request.get_json()
    tier = data.get('tier')
    user_id = data.get('user_id')  # Optional user ID for tracking

    PRICE_IDS = get_price_ids()
    logger.info(f"Creating checkout for tier '{tier}' with price_id: {PRICE_IDS.get(tier)}")

    if not tier or tier not in PRICE_IDS:
        return jsonify({'error': 'Invalid subscription tier'}), 400

    try:
        checkout_session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[
                {
                    'price': PRICE_IDS[tier],
                    'quantity': 1,
                },
            ],
            mode='subscription',
            success_url='https://reliable-sherbet-2352c4.netlify.app/#/subscription-success', # Production success URL
            cancel_url='https://reliable-sherbet-2352c4.netlify.app/#/subscription-canceled', # Production cancel URL
        )
        return jsonify({
            'id': checkout_session.id,
            'checkout_url': checkout_session.url
        })
    except Exception as e:
        return jsonify(error=str(e)), 403

@stripe_routes.route('/subscription-status/<user_id>', methods=['GET'])
def get_subscription_status(user_id):
    """
    Get the current subscription status for a user.
    Returns subscription tier, status, and renewal date.
    """
    try:
        # Query the database for user's subscription
        # This connects to the existing User model
        from ..models.user import User

        user = User.query.filter_by(id=user_id).first()

        if not user:
            return jsonify({'error': 'User not found'}), 404

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
        return jsonify({'error': str(e)}), 500
