import pytest
import json
from unittest.mock import MagicMock
from backend.database import db
from backend.models.user import User

def test_get_subscription_success(client, test_user):
    """Test retrieving subscription data for a user."""
    response = client.get(f'/api/user/{test_user.id}/subscription')
    assert response.status_code == 200
    data = response.get_json()
    assert data['user_id'] == test_user.id
    assert data['tier'] == 'free'
    assert data['status'] == 'active'

def test_get_subscription_not_found(client):
    """Test 404 for nonexistent user."""
    response = client.get('/api/user/nonexistent/subscription')
    assert response.status_code == 404
    data = response.get_json()
    assert 'error' in data

def test_create_checkout_session(client, mock_stripe):
    """Test creating a Stripe checkout session."""
    payload = {
        "tier": "premium",
        "user_id": "test_user_123"
    }
    response = client.post('/api/stripe/create-checkout-session',
                           json=payload,
                           content_type='application/json')

    assert response.status_code == 200
    data = response.get_json()
    assert 'id' in data
    assert 'checkout_url' in data
    assert data['id'] == 'cs_test_123'

def test_create_checkout_session_invalid_tier(client):
    """Test creating a checkout session with invalid tier."""
    payload = {
        "tier": "invalid_tier",
        "user_id": "test_user_123"
    }
    response = client.post('/api/stripe/create-checkout-session',
                           json=payload,
                           content_type='application/json')

    assert response.status_code == 400

def test_get_subscription_status(client, mock_stripe):

    """Test retrieving subscription status from Stripe."""

    user_id = 'stripe_user_fresh'

    with client.application.app_context():

        user = User(id=user_id, username='stripe_test', email='stripe@test.com')

        user.stripe_customer_id = 'cus_test_123'

        user.set_password('password')

        db.session.add(user)

        db.session.commit()



    # Generate token for this specific user

    from datetime import datetime, timedelta

    import jwt

    payload = {

        'user_id': user_id,

        'exp': datetime.utcnow() + timedelta(hours=1)

    }

    token = jwt.encode(payload, 'dev-secret-key', algorithm='HS256')

    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}



    # Mock stripe.Subscription.list response

    mock_sub = MagicMock()

    mock_sub.current_period_end = 1234567890

    mock_sub.cancel_at_period_end = False

    

    mock_stripe.Subscription.list.return_value.data = [mock_sub]



    response = client.get(f'/api/stripe/subscription-status/{user_id}',

                          headers=headers)

    

    assert response.status_code == 200

    data = response.get_json()

    assert data['status'] == 'active'

    assert data['current_period_end'] == 1234567890


