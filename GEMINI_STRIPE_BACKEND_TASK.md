# Gemini Backend Task: Stripe Integration Setup

## Priority: HIGH
**Assigned to:** Gemini CLI
**Estimated time:** 30-45 minutes
**Dependencies:** None - can start immediately

---

## Objective
Complete the backend Stripe integration for subscription management. The routes exist but are not registered, and configuration needs to be completed.

---

## Task 1: Register Stripe Routes in app.py

### Current State
- File `backend/routes/stripe_routes.py` exists with Stripe checkout logic
- File `backend/routes/webhook_handler.py` exists for Stripe webhooks
- These routes are NOT registered in `backend/app.py`

### What You Need To Do

1. **Import Stripe routes** at the top of `backend/app.py`:
```python
from .routes.stripe_routes import stripe_routes
from .routes.webhook_handler import webhook_routes
```

2. **Register blueprints** after other route registrations (look for where `character_routes` and `user_routes` are registered):
```python
app.register_blueprint(stripe_routes, url_prefix='/api/stripe')
app.register_blueprint(webhook_routes, url_prefix='/api/webhooks')
```

3. **Verify the import** at the top includes `stripe` in requirements check.

---

## Task 2: Update Environment Configuration

### Update `backend/.env.example`
Add these lines to document required Stripe variables:
```bash
# Stripe Configuration (Required for subscriptions)
STRIPE_API_KEY=sk_test_your_stripe_secret_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
STRIPE_PRICE_ID_PREMIUM=price_your_premium_price_id
STRIPE_PRICE_ID_FAMILY=price_your_family_price_id
```

### Update `backend/routes/stripe_routes.py`
Replace the hardcoded PRICE_IDS dictionary:

**OLD CODE (lines 12-16):**
```python
# TODO: Replace with your actual Stripe Price IDs
PRICE_IDS = {
    'premium': 'price_1234567890',
    'family': 'price_0987654321',
}
```

**NEW CODE:**
```python
# Load Stripe Price IDs from environment
PRICE_IDS = {
    'premium': os.getenv('STRIPE_PRICE_ID_PREMIUM', 'price_PLACEHOLDER_PREMIUM'),
    'family': os.getenv('STRIPE_PRICE_ID_FAMILY', 'price_PLACEHOLDER_FAMILY'),
}
```

---

## Task 3: Add Stripe API Key Check

In `backend/app.py`, add Stripe API key initialization after the Gemini API key setup:

**Find this section (around line 70-80):**
```python
api_key = os.getenv("GEMINI_API_KEY")
if api_key:
    # ... Gemini setup
```

**Add immediately after:**
```python
# Initialize Stripe
stripe_api_key = os.getenv("STRIPE_API_KEY")
if stripe_api_key:
    import stripe
    stripe.api_key = stripe_api_key
    logger.info("✓ Stripe API configured")
else:
    logger.warning("⚠ STRIPE_API_KEY not set - subscriptions disabled")
```

---

## Task 4: Update Webhook Handler for Production

### File: `backend/routes/webhook_handler.py`

1. **Ensure webhook secret is loaded from environment:**
```python
STRIPE_WEBHOOK_SECRET = os.getenv('STRIPE_WEBHOOK_SECRET')
```

2. **Add proper error handling** if webhook secret is missing:
```python
@webhook_routes.route('/stripe', methods=['POST'])
def stripe_webhook():
    if not STRIPE_WEBHOOK_SECRET:
        logger.error("STRIPE_WEBHOOK_SECRET not configured")
        return jsonify({'error': 'Webhook not configured'}), 500

    # ... rest of webhook logic
```

3. **Verify webhook signature verification** is present in the handler.

---

## Task 5: Add Subscription Status Endpoint

Create a new endpoint in `backend/routes/stripe_routes.py` to check subscription status:

```python
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
```

---

## Task 6: Test Endpoints

After completing the above, test these endpoints:

### Test 1: Create Checkout Session
```bash
curl -X POST http://localhost:5000/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{"tier": "premium", "user_id": "test_user_123"}'
```

**Expected Response:**
```json
{
  "id": "cs_test_...",
  "checkout_url": "https://checkout.stripe.com/..."
}
```

### Test 2: Get Subscription Status
```bash
curl http://localhost:5000/api/stripe/subscription-status/test_user_123
```

**Expected Response:**
```json
{
  "status": "inactive",
  "tier": "free"
}
```

---

## Task 7: Update requirements.txt

Verify `stripe` is in `backend/requirements.txt`. If not, add:
```
stripe>=5.0.0
```

---

## Verification Checklist

Before marking complete, verify:

- [ ] Stripe routes registered in app.py
- [ ] Webhook routes registered in app.py
- [ ] Environment variables documented in .env.example
- [ ] PRICE_IDS loads from environment
- [ ] Stripe API key initialization in app.py
- [ ] Webhook secret validation in webhook handler
- [ ] New subscription-status endpoint created
- [ ] All endpoints tested locally
- [ ] No breaking changes to existing code
- [ ] Code follows existing patterns in the project

---

## Git Commit Message Template

```
Feat: Complete Stripe integration for subscriptions

Integrated Stripe payment processing with proper environment configuration
and subscription management endpoints.

Changes:
- Registered stripe_routes and webhook_routes blueprints in app.py
- Updated stripe_routes.py to load price IDs from environment
- Added Stripe API key initialization with logging
- Added /subscription-status endpoint for checking user subscriptions
- Updated .env.example with Stripe configuration variables
- Enhanced webhook handler with proper secret validation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Notes for Gemini

- **DO NOT** create Stripe products or get API keys - the user will do this separately
- **DO** focus on code integration and configuration structure
- Follow the existing code style in the project (logging, error handling, etc.)
- Test locally if possible, but it's OK if Stripe API calls fail due to missing keys
- The goal is to have the code ready so the user just needs to add API keys

---

## After Completion

Update TEAM_COORDINATION.md with:
```
- 2025-11-23 · Gemini → Team: STRIPE BACKEND INTEGRATION COMPLETED ✅
  - Registered Stripe and webhook routes in app.py
  - Configured environment variable loading for Stripe API keys and price IDs
  - Added subscription status endpoint
  - Updated webhook handler with proper secret validation
  - Backend ready for Stripe API key configuration
  - Repository synced to main
```
