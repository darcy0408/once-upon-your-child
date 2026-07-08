from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import jwt

from backend.database import db
from backend.models.user import User


def _create_user(user_id: str, tier: str = "free") -> User:
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@example.com",
        subscription_tier=tier,
    )
    user.set_password("test-password")
    db.session.add(user)
    db.session.commit()
    return user


def _auth_headers(user_id: str) -> dict[str, str]:
    token = jwt.encode(
        {
            "user_id": user_id,
            "sub": user_id,
            "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
        },
        "dev-secret-key",
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def test_create_checkout_session_success(client, app, mocker):
    with app.app_context():
        _create_user("u-1")

    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123", "family": "price_family_456"},
    )
    create_mock = mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
        return_value=SimpleNamespace(
            id="cs_test_123", url="https://checkout.stripe.com/pay/cs_test_123"
        ),
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium", "user_id": "u-1"},
        headers=_auth_headers("u-1"),
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["id"] == "cs_test_123"
    assert "checkout.stripe.com" in body["checkout_url"]
    create_mock.assert_called_once()
    kwargs = create_mock.call_args.kwargs
    assert kwargs["line_items"][0]["price"] == "price_premium_123"
    assert kwargs["mode"] == "subscription"


def test_create_checkout_session_annual_premium_uses_annual_price_id(
    client, app, mocker
):
    with app.app_context():
        _create_user("u-1b")

    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={
            "premium": "price_premium_123",
            "family": "price_family_456",
            "premium_annual": "price_premium_annual_789",
        },
    )
    create_mock = mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
        return_value=SimpleNamespace(
            id="cs_test_annual", url="https://checkout.stripe.com/pay/cs_test_annual"
        ),
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium", "user_id": "u-1b", "billing_period": "annual"},
        headers=_auth_headers("u-1b"),
    )

    assert response.status_code == 200
    kwargs = create_mock.call_args.kwargs
    assert kwargs["line_items"][0]["price"] == "price_premium_annual_789"
    assert kwargs["metadata"]["billing_period"] == "annual"
    assert kwargs["metadata"]["subscription_tier"] == "premium"
    assert kwargs["subscription_data"]["metadata"]["billing_period"] == "annual"


def test_create_checkout_session_annual_premium_missing_price_id_returns_503(
    client, app, mocker
):
    with app.app_context():
        _create_user("u-1c")

    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={
            "premium": "price_premium_123",
            "family": "price_family_456",
            "premium_annual": None,
        },
    )
    create_mock = mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium", "user_id": "u-1c", "billing_period": "annual"},
        headers=_auth_headers("u-1c"),
    )

    assert response.status_code == 503
    assert response.get_json()["error"] == "Subscription tier temporarily unavailable"
    create_mock.assert_not_called()


def test_create_checkout_session_invalid_billing_period_returns_400(
    client, app, mocker
):
    with app.app_context():
        _create_user("u-1d")

    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123", "family": "price_family_456"},
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium", "user_id": "u-1d", "billing_period": "biannual"},
        headers=_auth_headers("u-1d"),
    )

    assert response.status_code == 400
    assert response.get_json()["error"] == "Invalid billing period"


def test_create_checkout_session_annual_family_returns_400(client, app, mocker):
    with app.app_context():
        _create_user("u-1e")

    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123", "family": "price_family_456"},
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "family", "user_id": "u-1e", "billing_period": "annual"},
        headers=_auth_headers("u-1e"),
    )

    assert response.status_code == 400
    assert (
        response.get_json()["error"] == "Annual billing is only available for premium"
    )


def test_create_checkout_session_invalid_tier_returns_400(client, app):
    with app.app_context():
        _create_user("u-2")

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "starter"},
        headers=_auth_headers("u-2"),
    )

    assert response.status_code == 400
    assert response.get_json()["error"] == "Invalid subscription tier"


def test_create_checkout_session_missing_tier_returns_400(client, app):
    with app.app_context():
        _create_user("u-3")

    response = client.post(
        "/api/stripe/create-checkout-session", json={}, headers=_auth_headers("u-3")
    )

    assert response.status_code == 400
    assert response.get_json()["error"] == "Invalid subscription tier"


def test_create_checkout_session_missing_json_body_returns_400(client, app):
    with app.app_context():
        _create_user("u-4")

    response = client.post(
        "/api/stripe/create-checkout-session",
        data="",
        headers={"Content-Type": "application/json", **_auth_headers("u-4")},
    )

    assert response.status_code == 400
    assert response.get_json()["error"] == "Invalid subscription tier"


def test_create_checkout_session_defaults_to_14_day_trial(
    client, app, mocker, monkeypatch
):
    """Paywall copy promises '14 days free' (single-tier pricing, PR #395).

    get_trial_days() defaults STRIPE_TRIAL_DAYS to "14" when the env var is
    unset, so this must be true out of the box with no Railway config.
    """
    with app.app_context():
        _create_user("u-trial-default")

    monkeypatch.delenv("STRIPE_TRIAL_DAYS", raising=False)
    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123"},
    )
    create_mock = mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
        return_value=SimpleNamespace(
            id="cs_test_trial", url="https://checkout.stripe.com/pay/cs_test_trial"
        ),
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium"},
        headers=_auth_headers("u-trial-default"),
    )

    assert response.status_code == 200
    kwargs = create_mock.call_args.kwargs
    assert kwargs["subscription_data"]["trial_period_days"] == 14


def test_create_checkout_session_trial_disabled_via_env_zero(
    client, app, mocker, monkeypatch
):
    """STRIPE_TRIAL_DAYS=0 (or any non-positive value) disables the trial."""
    with app.app_context():
        _create_user("u-trial-off")

    monkeypatch.setenv("STRIPE_TRIAL_DAYS", "0")
    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123"},
    )
    create_mock = mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
        return_value=SimpleNamespace(
            id="cs_test_no_trial",
            url="https://checkout.stripe.com/pay/cs_test_no_trial",
        ),
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium"},
        headers=_auth_headers("u-trial-off"),
    )

    assert response.status_code == 200
    kwargs = create_mock.call_args.kwargs
    assert "trial_period_days" not in kwargs["subscription_data"]


def test_create_checkout_session_trial_days_env_override(
    client, app, mocker, monkeypatch
):
    """STRIPE_TRIAL_DAYS tunes the trial length without a code deploy."""
    with app.app_context():
        _create_user("u-trial-30")

    monkeypatch.setenv("STRIPE_TRIAL_DAYS", "30")
    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123"},
    )
    create_mock = mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
        return_value=SimpleNamespace(
            id="cs_test_30", url="https://checkout.stripe.com/pay/cs_test_30"
        ),
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium"},
        headers=_auth_headers("u-trial-30"),
    )

    assert response.status_code == 200
    kwargs = create_mock.call_args.kwargs
    assert kwargs["subscription_data"]["trial_period_days"] == 30


def test_create_checkout_session_stripe_failure_returns_500(client, app, mocker):
    with app.app_context():
        _create_user("u-5")

    mocker.patch(
        "backend.routes.stripe_routes.get_price_ids",
        return_value={"premium": "price_premium_123"},
    )
    mocker.patch(
        "backend.routes.stripe_routes.stripe.checkout.Session.create",
        side_effect=Exception("stripe outage"),
    )

    response = client.post(
        "/api/stripe/create-checkout-session",
        json={"tier": "premium"},
        headers=_auth_headers("u-5"),
    )

    assert response.status_code == 500
    assert (
        response.get_json()["error"]
        == "Failed to create checkout session. Please try again."
    )


def test_get_subscription_status_returns_active_for_owner(client, app, mocker):
    with app.app_context():
        user = _create_user("stripe-user-2", tier="premium")
        user.stripe_customer_id = "cus_test_123"
        db.session.commit()

    mocker.patch(
        "backend.routes.stripe_routes.stripe.Subscription.list",
        return_value=SimpleNamespace(
            data=[
                SimpleNamespace(
                    current_period_end=1735689600, cancel_at_period_end=False
                )
            ]
        ),
    )

    response = client.get(
        "/api/stripe/subscription-status/stripe-user-2",
        headers=_auth_headers("stripe-user-2"),
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "active"
    assert body["tier"] == "premium"
    assert body["current_period_end"] == 1735689600
    assert body["cancel_at_period_end"] is False


def test_get_subscription_status_returns_own_data_regardless_of_url_user_id(
    client, app
):
    # @require_owner was removed: the endpoint always returns request.current_user's
    # subscription (URL user_id is ignored).  An authenticated user calling another
    # user's URL gets their OWN data — no data leaks, no false 403s.
    with app.app_context():
        _create_user("owner-user")
        _create_user("attacker-user")

    response = client.get(
        "/api/stripe/subscription-status/owner-user",
        headers=_auth_headers("attacker-user"),
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "inactive"  # attacker-user has no Stripe customer


def test_get_subscription_status_requires_auth(client, app):
    with app.app_context():
        _create_user("owner-user-2")

    response = client.get("/api/stripe/subscription-status/owner-user-2")

    assert response.status_code == 401
    assert response.get_json()["error"] == "Authentication required"


def test_get_subscription_status_returns_inactive_without_customer(client, app):
    with app.app_context():
        _create_user("stripe-user-no-customer", tier="premium")

    response = client.get(
        "/api/stripe/subscription-status/stripe-user-no-customer",
        headers=_auth_headers("stripe-user-no-customer"),
    )

    assert response.status_code == 200
    assert response.get_json() == {"status": "inactive", "tier": "free"}


def test_get_subscription_status_stripe_error_returns_500(client, app, mocker):
    with app.app_context():
        user = _create_user("stripe-user-error", tier="premium")
        user.stripe_customer_id = "cus_err_123"
        db.session.commit()

    mocker.patch(
        "backend.routes.stripe_routes.stripe.Subscription.list",
        side_effect=Exception("stripe unavailable"),
    )

    response = client.get(
        "/api/stripe/subscription-status/stripe-user-error",
        headers=_auth_headers("stripe-user-error"),
    )

    assert response.status_code == 500
    assert response.get_json()["error"] == "Failed to retrieve subscription status"


def test_get_subscription_status_rejects_malformed_token(client, app):
    with app.app_context():
        _create_user("stripe-user-malformed-token")

    response = client.get(
        "/api/stripe/subscription-status/stripe-user-malformed-token",
        headers={"Authorization": "Bearer definitely-not-a-jwt"},
    )

    assert response.status_code == 401
    assert response.get_json()["error"] == "Invalid token"


def test_get_subscription_status_rejects_expired_token(client, app):
    with app.app_context():
        _create_user("stripe-user-expired-token")

    expired_token = jwt.encode(
        {
            "user_id": "stripe-user-expired-token",
            "exp": int((datetime.now(timezone.utc) - timedelta(hours=1)).timestamp()),
        },
        "dev-secret-key",
        algorithm="HS256",
    )

    response = client.get(
        "/api/stripe/subscription-status/stripe-user-expired-token",
        headers={"Authorization": f"Bearer {expired_token}"},
    )

    assert response.status_code == 401
    assert response.get_json()["error"] == "Token expired"
