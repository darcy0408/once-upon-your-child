import jwt
import pytest
from datetime import datetime, timedelta
from types import SimpleNamespace

from backend.database import db
from backend.models.user import User


@pytest.fixture(autouse=True)
def mock_auth_secret(mocker):
    return mocker.patch('backend.middleware.auth._get_jwt_secret', return_value='test_secret')


def _create_user(user_id: str, tier: str = 'free') -> User:
    user = User(
        id=user_id,
        username=user_id,
        email=f'{user_id}@example.com',
        subscription_tier=tier,
    )
    user.set_password('test-password')
    db.session.add(user)
    db.session.commit()
    return user


def _auth_headers(user_id: str) -> dict[str, str]:
    token = jwt.encode(
        {'user_id': user_id, 'exp': datetime.utcnow() + timedelta(hours=1)},
        'test_secret',
        algorithm='HS256',
    )
    return {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json',
    }


class TestStripeRoutes:
    def test_create_checkout_session_success(self, client, app, mocker):
        with app.app_context():
            _create_user('stripe_user_1')

        mock_session = SimpleNamespace(
            id='cs_test_123',
            url='https://checkout.stripe.com/pay/cs_test_123',
        )
        create_mock = mocker.patch(
            'backend.routes.stripe_routes.stripe.checkout.Session.create',
            return_value=mock_session,
        )

        response = client.post(
            '/api/stripe/create-checkout-session',
            json={'tier': 'premium', 'user_id': 'stripe_user_1'},
        )

        assert response.status_code == 200
        body = response.get_json()
        assert body['id'] == 'cs_test_123'
        assert 'checkout.stripe.com' in body['checkout_url']
        create_mock.assert_called_once()

    def test_create_checkout_session_invalid_tier(self, client):
        response = client.post(
            '/api/stripe/create-checkout-session',
            json={'tier': 'invalid_tier'},
        )

        assert response.status_code == 400
        assert response.get_json()['error'] == 'Invalid subscription tier'

    def test_subscription_status_returns_active_for_owner(self, client, app, mocker):
        with app.app_context():
            user = _create_user('stripe_user_2', tier='premium')
            user.stripe_customer_id = 'cus_test_123'
            db.session.commit()

        mocker.patch(
            'backend.routes.stripe_routes.stripe.Subscription.list',
            return_value=SimpleNamespace(
                data=[
                    SimpleNamespace(
                        current_period_end=1735689600,
                        cancel_at_period_end=False,
                    ),
                ],
            ),
        )

        response = client.get(
            '/api/stripe/subscription-status/stripe_user_2',
            headers=_auth_headers('stripe_user_2'),
        )

        assert response.status_code == 200
        body = response.get_json()
        assert body['status'] == 'active'
        assert body['tier'] == 'premium'
        assert body['cancel_at_period_end'] is False

    def test_webhook_signature_validation_failure(self, client, monkeypatch, mocker):
        from backend.routes import webhook_handler

        monkeypatch.setenv('STRIPE_WEBHOOK_SECRET', 'whsec_test')
        mocker.patch(
            'backend.routes.webhook_handler.stripe.Webhook.construct_event',
            side_effect=webhook_handler.stripe.error.SignatureVerificationError('bad sig', 'sig_header'),
        )

        response = client.post(
            '/api/webhooks/stripe',
            data=b'{}',
            headers={'Stripe-Signature': 'invalid'},
        )

        assert response.status_code == 401
        assert response.get_json()['error'] == 'Invalid signature'

    def test_webhook_checkout_completed_updates_subscription(self, client, app, monkeypatch, mocker):
        monkeypatch.setenv('STRIPE_WEBHOOK_SECRET', 'whsec_test')

        with app.app_context():
            _create_user('stripe_user_3', tier='free')

        event = {
            'type': 'checkout.session.completed',
            'data': {
                'object': {
                    'client_reference_id': 'stripe_user_3',
                    'metadata': {'subscription_tier': 'premium'},
                    'subscription': {
                        'status': 'active',
                        'current_period_end': 1735689600,
                        'cancel_at_period_end': False,
                    },
                },
            },
        }

        mocker.patch(
            'backend.routes.webhook_handler.stripe.Webhook.construct_event',
            return_value=event,
        )

        response = client.post(
            '/api/webhooks/stripe',
            data=b'{"id":"evt_123"}',
            headers={'Stripe-Signature': 'valid'},
        )

        assert response.status_code == 200
        assert response.get_json()['status'] == 'success'

        with app.app_context():
            user = db.session.get(User, 'stripe_user_3')
            assert user is not None
            assert user.subscription_tier == 'premium'
            assert user.subscription_status == 'active'
            assert user.current_period_end is not None
