# STORE-1 — In-App Purchase Migration Brief

Date: 2026-05-17
Source: `audit/LEGAL-COMPLIANCE.md` finding STORE-1 (Critical, launch-blocker for the
iOS/Android store builds). Phase-4 plan WP-1.
Status: ☐ not started — gated on decision **D-2** (timing).

---

## Goal

The app sells digital subscriptions (Premium $4.99/mo, Family $9.99/mo). Today it does this
via **Stripe Checkout opened in an external browser**. Apple App Store Guideline 3.1.1 and
Google Play's Payments policy **both require their own in-app billing** for digital goods
consumed in an app distributed through their store — a Stripe-web-checkout flow is an
automatic rejection on both.

**Goal:** sell subscriptions through StoreKit (iOS) and Google Play Billing (Android) in the
store builds, while keeping Stripe for the web build, behind **one server-side entitlement
source of truth**.

## Scope boundary (important)

- **Web build** — keep Stripe exactly as-is. The web app is not distributed through an app
  store; the IAP rule does not apply. Do **not** rip Stripe out.
- **iOS / Android builds** — must use StoreKit / Play Billing. The Stripe purchase path must
  be **unreachable** on these builds.
- One backend remains the authority on what tier a user has; it now accepts entitlement
  signals from three channels (Stripe webhooks, Apple, Google) and resolves them to a tier.

## Decision gate — D-2

Before starting, confirm the timing decision from the Phase-4 plan:
- **(a)** Full IAP migration before any launch.
- **(b)** Launch web first (Stripe), do IAP as a fast-follow, then submit the store builds.
- **(c)** Ship store builds with subscriptions disabled initially.
This brief is the same work regardless; D-2 only sets *when*.

## Prerequisites (owner / console)

- Apple Developer account + App Store Connect access; **paid-apps agreement** active.
- Google Play Console access; merchant account configured.
- Create the subscription products in **both** consoles with stable product IDs — suggest
  `premium_monthly`, `family_monthly`. Prices set per-store (Apple/Google manage currency).
- Decide trial handling — Apple/Google have their own intro-offer/free-trial mechanisms; the
  current `STRIPE_TRIAL_DAYS=14` does not carry over automatically.

## Implementation steps

1. **Plugin** — add `in_app_purchase` (official Flutter plugin; covers StoreKit + Play
   Billing). Add platform setup (iOS capability, Android billing permission).
2. **Build-flavor gating** — a single `PaymentChannel` abstraction. Web → Stripe (existing
   `stripe_service.dart`); iOS/Android → a new `iap_service.dart`. The paywall UI calls the
   abstraction; the Stripe path must be compiled out / unreachable on mobile.
3. **Purchase flow (mobile)** — query products, present them, run the purchase, listen on the
   purchase stream, and on success send the **receipt / purchase token** to the backend.
4. **Backend verification** — new endpoints:
   - `POST /api/iap/apple/verify` — validate the receipt with Apple (App Store Server API).
   - `POST /api/iap/google/verify` — validate the token with the Google Play Developer API.
   On valid receipt, set the user's tier — reuse the existing tier logic the Stripe webhook
   already drives (see `backend/routes/webhook_handler.py`). Entitlement must be **one
   function**, three callers.
5. **Server-to-server notifications** — wire Apple App Store Server Notifications V2 and
   Google Real-Time Developer Notifications so renewals, cancellations, refunds, and billing
   retries update the tier without the client. This is the mobile equivalent of Stripe
   webhooks.
6. **Restore purchases** — add a "Restore purchases" action (Apple requires it); re-validate
   and re-apply entitlement.
7. **Entitlement reconciliation** — one user must not be billed twice; if a user has both a
   Stripe sub (from web) and a store sub, define precedence and surface it. Keep the tier
   resolution deterministic.
8. **Account-deletion interaction** — the existing erasure flow must not orphan an active
   store subscription; document that store subs are cancelled by the user via the store.

## Testing matrix

| Flow | iOS (StoreKit sandbox) | Android (Play test track) | Web (Stripe test) |
|---|---|---|---|
| New subscription | ✅ | ✅ | ✅ |
| Renewal (S2S notification) | ✅ | ✅ | ✅ |
| Cancel / lapse | ✅ | ✅ | ✅ |
| Refund | ✅ | ✅ | ✅ |
| Restore purchases | ✅ | ✅ | n/a |
| Tier reflected server-side | ✅ | ✅ | ✅ |

## Risks / gotchas

- **No external steering.** Apple/Google forbid linking users to an outside payment method
  from inside the app. The mobile builds must not mention or link to web/Stripe checkout.
- **Receipt validation must be server-side.** Never trust the client's claim of a purchase.
- **Family Sharing / shared purchases** (Apple) can complicate the "Family" tier — decide
  whether the Family tier maps to an Apple Family-Sharing-eligible product.
- **Price parity** — store prices won't exactly match $4.99/$9.99 after Apple/Google tiering
  and currency conversion; align marketing copy.
- **Kids-Category note** — purchases in a kids-directed app sit behind the parental gate
  already added (STORE-7); the purchase UI should remain parent-facing.

## Effort

~2–4 weeks for one developer: plugin + flavor gating (~3 d), mobile purchase flow (~4 d),
backend verification + S2S notifications (~5 d), reconciliation + restore (~3 d), the full
sandbox/test-track testing matrix (~3–5 d), plus console setup.
