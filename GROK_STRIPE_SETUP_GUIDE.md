# Grok Task: Stripe Account Setup & Configuration Guide

## Priority: HIGH
**Assigned to:** Grok
**Estimated time:** 20-30 minutes
**Dependencies:** User must complete Stripe account registration first

---

## Objective
Guide the user through Stripe account setup, product/price creation, and provide the exact configuration values needed for Railway deployment. Focus on production-ready setup with proper webhook configuration.

---

## Phase 1: Stripe Account Creation

### Step 1: Create Stripe Account

Guide the user to:
1. Go to https://dashboard.stripe.com/register
2. Create account with business email
3. Complete business information
4. Note: Can start in TEST mode, switch to LIVE later

### Step 2: Verify Account Access

Once logged in, user should see:
- Dashboard (https://dashboard.stripe.com/)
- Test/Live mode toggle in top left
- Ensure TEST mode is selected for initial setup

---

## Phase 2: Product & Price Creation

### Step 3: Create Premium Monthly Product

**Navigate to:** Products → Add Product

**Premium Tier Configuration:**
```
Product Name: Story Weaver Premium
Description: Unlimited personalized stories, advanced features, priority support
Pricing Model: Recurring
Price: $9.99 USD
Billing Period: Monthly
```

**After creating:**
1. Copy the Price ID (starts with `price_...`)
2. Save as: `STRIPE_PRICE_ID_PREMIUM=price_xxxxx`

### Step 4: Create Family Monthly Product

**Navigate to:** Products → Add Product

**Family Tier Configuration:**
```
Product Name: Story Weaver Family
Description: Unlimited stories for up to 5 children, all premium features, family dashboard
Pricing Model: Recurring
Price: $14.99 USD
Billing Period: Monthly
```

**After creating:**
1. Copy the Price ID (starts with `price_...`)
2. Save as: `STRIPE_PRICE_ID_FAMILY=price_xxxxx`

---

## Phase 3: API Keys Configuration

### Step 5: Get Test API Keys

**Navigate to:** Developers → API Keys

**Copy these keys:**
1. **Publishable key** (starts with `pk_test_...`)
   - Not needed for backend, but save for future frontend use
2. **Secret key** (starts with `sk_test_...`)
   - Click "Reveal test key"
   - Save as: `STRIPE_API_KEY=sk_test_xxxxx`

**CRITICAL:** Never commit secret keys to git or share publicly

---

## Phase 4: Webhook Configuration

### Step 6: Create Webhook Endpoint

**Navigate to:** Developers → Webhooks → Add endpoint

**Webhook Configuration:**
```
Endpoint URL: https://story-weaver-app-production.up.railway.app/api/webhooks/stripe

Description: Story Weaver subscription events

Events to send:
  ✓ customer.subscription.created
  ✓ customer.subscription.updated
  ✓ customer.subscription.deleted
  ✓ invoice.payment_succeeded
  ✓ invoice.payment_failed
  ✓ checkout.session.completed
```

**After creating:**
1. Click on the webhook you just created
2. Click "Reveal" under "Signing secret"
3. Copy the webhook secret (starts with `whsec_...`)
4. Save as: `STRIPE_WEBHOOK_SECRET=whsec_xxxxx`

---

## Phase 5: Railway Environment Configuration

### Step 7: Compile All Environment Variables

Create a secure note with these exact values (filled in with real values):

```bash
# Stripe Configuration - Add to Railway
STRIPE_API_KEY=sk_test_YOUR_ACTUAL_SECRET_KEY_HERE
STRIPE_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_WEBHOOK_SECRET_HERE
STRIPE_PRICE_ID_PREMIUM=price_YOUR_ACTUAL_PREMIUM_PRICE_ID
STRIPE_PRICE_ID_FAMILY=price_YOUR_ACTUAL_FAMILY_PRICE_ID
```

### Step 8: Add to Railway

**Method 1: Railway Dashboard**
1. Go to https://railway.app
2. Select "story-weaver-app" project
3. Click on backend service
4. Go to "Variables" tab
5. Click "New Variable"
6. Add each variable one by one:
   - Variable: `STRIPE_API_KEY`
   - Value: `sk_test_...` (paste actual value)
7. Repeat for all 4 Stripe variables

**Method 2: Railway CLI**
```bash
railway variables set STRIPE_API_KEY=sk_test_YOUR_KEY
railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
railway variables set STRIPE_PRICE_ID_PREMIUM=price_YOUR_PREMIUM_ID
railway variables set STRIPE_PRICE_ID_FAMILY=price_YOUR_FAMILY_ID
```

### Step 9: Verify Railway Configuration

After adding variables:
1. Go to Railway dashboard
2. Check that all 4 Stripe variables appear in "Variables" tab
3. Redeploy the service (Railway does this automatically when variables change)
4. Check deployment logs for: `✓ Stripe API configured`

---

## Phase 6: Testing the Integration

### Step 10: Test Checkout Session Creation

Use PowerShell to test the backend endpoint:

```powershell
$body = @{
    tier = "premium"
    user_id = "test_user_123"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://story-weaver-app-production.up.railway.app/api/stripe/create-checkout-session" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

**Expected Response:**
```json
{
  "id": "cs_test_...",
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_..."
}
```

**If successful:**
1. Copy the `checkout_url`
2. Open it in browser
3. You should see Stripe checkout page with your product

### Step 11: Test Checkout Flow (Use Stripe Test Cards)

On the Stripe checkout page, use test card:
```
Card Number: 4242 4242 4242 4242
Expiry: Any future date (e.g., 12/34)
CVC: Any 3 digits (e.g., 123)
ZIP: Any 5 digits (e.g., 12345)
```

Complete the checkout and verify:
1. Redirect to success page
2. Check Railway logs for webhook event
3. Check Stripe dashboard for successful payment

---

## Phase 7: Frontend Configuration (Future)

### Step 12: Document Frontend Setup (Not needed yet)

For future reference, the frontend will need:
- Publishable key in Flutter app (for direct Stripe SDK integration later)
- Success/cancel URLs already configured in `stripe_routes.py`

**No action needed now** - backend integration is priority

---

## Phase 8: Production Migration Plan

### Step 13: Plan for Going Live

When ready for production:

1. **Switch to Live Mode** in Stripe dashboard
2. **Create production products** (same as test, but in live mode)
3. **Get production API keys** (start with `sk_live_...`)
4. **Create production webhook** (same URL, but use live mode)
5. **Update Railway variables** with live keys
6. **Enable payment methods** in Stripe settings
7. **Complete Stripe account verification** (required for live mode)

---

## Troubleshooting Guide

### Issue: "Invalid API Key"
- Verify you copied the full key (starts with `sk_test_`)
- Check for extra spaces or missing characters
- Ensure TEST mode is selected in Stripe dashboard

### Issue: "Webhook signature verification failed"
- Verify webhook secret is correct (starts with `whsec_`)
- Check that webhook URL exactly matches Railway deployment URL
- Ensure webhook is configured for correct events

### Issue: "Price not found"
- Verify price IDs are correct (start with `price_`)
- Check that prices are in TEST mode
- Ensure products are active in Stripe dashboard

### Issue: Railway deployment failed after adding variables
- Check Railway logs for specific error
- Verify all 4 Stripe variables are present
- Ensure no typos in variable names (case sensitive)

---

## Verification Checklist

Before marking complete, verify:

- [ ] Stripe account created and verified
- [ ] Premium product created with monthly pricing
- [ ] Family product created with monthly pricing
- [ ] Test API secret key copied
- [ ] Test webhook created and secret copied
- [ ] All 4 Stripe variables added to Railway
- [ ] Railway deployment successful with Stripe configured
- [ ] Test checkout session creates successfully
- [ ] Test checkout flow completes with test card
- [ ] Webhook events appear in Railway logs

---

## Deliverables

Provide to the user in a secure format:

```
STRIPE CONFIGURATION - KEEP SECURE
====================================

Test Mode Keys:
- Secret Key: sk_test_...
- Webhook Secret: whsec_...
- Premium Price ID: price_...
- Family Price ID: price_...

Railway Configuration:
✓ All variables added
✓ Deployment successful
✓ Webhook endpoint: https://story-weaver-app-production.up.railway.app/api/webhooks/stripe

Next Steps:
1. Test frontend integration once Codex completes their task
2. Verify end-to-end subscription flow
3. Plan production migration when ready
```

---

## After Completion

Update TEAM_COORDINATION.md with:
```
- 2025-11-23 · Grok → Team: STRIPE ACCOUNT SETUP COMPLETED ✅
  - Created Stripe account and configured test mode
  - Created Premium and Family products with monthly pricing
  - Configured API keys and webhook endpoint
  - Added all Stripe environment variables to Railway
  - Verified backend integration with test checkout session
  - Completed test transaction with Stripe test card
  - System ready for end-to-end subscription testing
  - Production migration plan documented
```

---

## Notes for Grok

- Guide the user through this process step-by-step
- Take screenshots if helpful for verification
- Keep API keys secure - never paste them in chat logs
- Test thoroughly before marking complete
- Document any issues encountered and how they were resolved
- This is the foundation for monetization - attention to detail is critical
