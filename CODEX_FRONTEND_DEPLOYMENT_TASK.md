# Codex Task: Frontend Deployment & End-to-End Testing

## Priority: HIGH
**Assigned to:** Codex
**Estimated time:** 30-45 minutes
**Status:** Backend fully operational, frontend code complete, needs deployment verification

---

## 🎯 Objective

Verify the Netlify frontend deployment is working correctly with the Railway backend, test the complete Stripe checkout flow end-to-end, and fix any frontend issues discovered.

---

## 📊 Current Status

✅ **Backend**: Fully operational on Railway
- Stripe checkout sessions creating successfully
- Both Premium and Family tiers tested
- Health endpoint responding

✅ **Frontend Code**: Stripe integration complete
- `StripeService` created
- `SubscribeButton` updated
- Subscription management screen enhanced

⚠️ **Not Yet Tested**: End-to-end flow from frontend UI to Stripe checkout

---

## Task 1: Verify Netlify Deployment Status

### 1.1: Check Netlify Build
Go to: https://reliable-sherbet-2352c4.netlify.app

**Expected:**
- Site loads without errors
- App appears with Story Weaver branding

**If broken:**
- Check Netlify deploy logs for errors
- Verify Flutter web build completed
- Check for any missing environment variables

### 1.2: Test Basic Navigation
Navigate through the app:
- [ ] Home screen loads
- [ ] Character creation works
- [ ] Story generation works (basic test)
- [ ] Settings screen accessible

**If any navigation fails, note the specific error for fixing**

---

## Task 2: Test Stripe Checkout Flow (End-to-End)

### 2.1: Locate Subscribe Button

**Where to find it:**
- Premium upgrade screen
- Subscription management screen
- Paywall dialog (if triggered by story limit)

**What to check:**
- [ ] Subscribe button is visible
- [ ] Button has correct styling
- [ ] Button shows loading state when clicked

### 2.2: Test Premium Checkout

1. **Click "Subscribe - Premium" button**

**Expected Behavior:**
- Loading spinner appears briefly
- Browser redirects to Stripe Checkout page
- URL starts with `https://checkout.stripe.com/`
- Premium pricing shows: **$9.99/month**

**If it fails:**
- Check browser console for errors
- Verify API call to `/api/stripe/create-checkout-session`
- Check network tab for response

2. **Complete Test Checkout**

Use Stripe test card:
```
Card: 4242 4242 4242 4242
Expiry: 12/34 (any future date)
CVC: 123
ZIP: 12345
```

**Expected:**
- Payment processes successfully
- Redirects to success page on Netlify
- Success page displays confirmation

### 2.3: Test Family Checkout

Repeat the same flow for Family tier:
- [ ] Click "Subscribe - Family" button
- [ ] Redirects to Stripe Checkout
- [ ] Family pricing shows: **$14.99/month**
- [ ] Complete with test card
- [ ] Success page displays

---

## Task 3: Test Subscription Management Screen

### 3.1: Access Subscription Management

Navigate to the subscription management screen.

**Check:**
- [ ] Screen loads without errors
- [ ] Shows current subscription status (likely "free" for test user)
- [ ] Displays upgrade options if free
- [ ] Shows subscription details if active (after test checkout)

### 3.2: Test Status API Call

**In browser console, check:**
```javascript
// Should see API call to:
// /api/stripe/subscription-status/<user_id>
```

**Expected Response:**
```json
{
  "status": "inactive",
  "tier": "free"
}
```

### 3.3: Test Cancellation UI (If Subscribed)

If you completed a test checkout:
- [ ] "Cancel Subscription" button appears
- [ ] Click shows confirmation dialog
- [ ] Cancellation flow works correctly

---

## Task 4: Fix Any Issues Found

### Common Frontend Issues to Check:

#### Issue 1: API Base URL Incorrect
**Symptom:** API calls fail with CORS or 404
**Fix:** Check `FlavorConfig.instance.backendUrl`
**Expected:** `https://story-weaver-app-production.up.railway.app`

**File to check:** `lib/config/flavor_config.dart`

#### Issue 2: Subscribe Button Not Responding
**Symptom:** Button click does nothing
**Fix:** Check for JavaScript errors in console
**Likely causes:**
- `url_launcher` package not working
- API call failing silently
- Error handling swallowing errors

**File to check:** `lib/widgets/subscribe_button.dart`

#### Issue 3: Success Page Not Found
**Symptom:** After Stripe checkout, gets 404
**Fix:** Verify route is registered in main.dart

**Expected route:**
```dart
'/subscription-success': (context) => const SubscriptionSuccessScreen(),
```

**File to check:** `lib/main.dart` or main story app file

#### Issue 4: CORS Errors
**Symptom:** Browser console shows CORS policy errors
**Fix:** This is a backend issue - alert user that backend needs CORS configuration
**Note:** Backend should already have CORS enabled via Flask-CORS

---

## Task 5: Test Mobile Responsiveness

### 5.1: Test on Different Screen Sizes

**Using browser dev tools:**
- [ ] Mobile (375px width)
- [ ] Tablet (768px width)
- [ ] Desktop (1920px width)

**Check:**
- [ ] Subscribe buttons visible and usable
- [ ] Subscription management screen layouts correctly
- [ ] Stripe checkout redirects work on mobile

---

## Task 6: Performance Check

### 6.1: Test Load Times

**Use browser dev tools (Network tab):**
- Initial page load: Should be < 3 seconds
- API calls: Should be < 1 second

### 6.2: Check for Errors

**Browser Console:**
- Should have no red errors
- Yellow warnings are okay if not critical

**Network Tab:**
- All API calls should return 200 OK
- No 404s or 500s

---

## Task 7: Documentation Update

### 7.1: Document Test Results

Create a summary in TEAM_COORDINATION.md:

```markdown
- 2025-11-24 · Codex → Team: FRONTEND DEPLOYMENT VERIFIED ✅
  - Netlify deployment: [✅ Working / ⚠️ Issues found]
  - Stripe checkout flow: [✅ Tested successfully / ⚠️ Issues]
  - Premium tier: [✅ Working]
  - Family tier: [✅ Working]
  - Subscription management: [✅ Working]
  - Issues found: [List any issues]
  - Fixes applied: [List any fixes made]
```

### 7.2: If Issues Found

For each issue discovered:
1. Document the issue clearly
2. Note the fix applied
3. Re-test to verify fix
4. Update TEAM_COORDINATION.md with results

---

## Verification Checklist

Before marking task complete:

- [ ] Netlify site loads without errors
- [ ] Basic app navigation works
- [ ] Premium subscribe button redirects to Stripe
- [ ] Family subscribe button redirects to Stripe
- [ ] Test checkout completes successfully
- [ ] Success page displays after checkout
- [ ] Subscription management screen works
- [ ] No critical console errors
- [ ] API calls use correct backend URL
- [ ] Mobile layout is usable
- [ ] TEAM_COORDINATION.md updated with results

---

## 🧪 Testing Commands

### Check Netlify Deployment Status
```bash
curl -I https://reliable-sherbet-2352c4.netlify.app
```
**Expected:** `HTTP/2 200`

### Test Backend API from Frontend Domain
```javascript
// Run in browser console on Netlify site
fetch('https://story-weaver-app-production.up.railway.app/health')
  .then(r => r.json())
  .then(console.log)
```
**Expected:** `{status: "ok", database: "ok", ...}`

---

## 🚨 When to Stop and Alert

Stop immediately and alert user if:
- ❌ Netlify site won't load at all
- ❌ Cannot access backend API (CORS issues)
- ❌ Stripe checkout creates but redirects to wrong URL
- ❌ Critical frontend compilation errors

---

## 📝 Git Commit Template

If you fix issues:

```bash
git commit -m "[AGENT SYNC | YYYY-MM-DD HH:MM:SS] Fix: Frontend deployment issues

Fixed issues found during end-to-end testing:
- [Issue 1 and fix]
- [Issue 2 and fix]

Verified:
- Stripe checkout flow working
- Both subscription tiers tested
- Mobile responsiveness confirmed

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Expected Outcome

✅ **Success Criteria:**
- User can click subscribe button on Netlify frontend
- User is redirected to Stripe Checkout with correct pricing
- User can complete test purchase with test card
- User is redirected back to success page
- No critical errors in browser console
- Mobile experience is functional

**This confirms the full integration is working end-to-end!** 🎉

---

## Notes for Codex

- Focus on **testing first**, fixing second
- Document **everything** you find
- If the frontend needs code changes, make them minimal
- Priority is verifying the Stripe integration works
- The backend is already tested and working

**Reference:** See `TEAM_COORDINATION.md` section "STRIPE INTEGRATION COMPLETED" for backend test results
