import os
from flask import Blueprint, request, jsonify
import stripe
from dotenv import load_dotenv

load_dotenv()

stripe_routes = Blueprint('stripe_routes', __name__)

stripe.api_key = os.getenv('STRIPE_API_KEY')

# TODO: Replace with your actual Stripe Price IDs
PRICE_IDS = {
    'premium': 'price_1234567890',
    'family': 'price_0987654321',
}

@stripe_routes.route('/create-checkout-session', methods=['POST'])
def create_checkout_session():
    data = request.get_json()
    tier = data.get('tier')
    user_id = data.get('user_id')  # Optional user ID for tracking

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
