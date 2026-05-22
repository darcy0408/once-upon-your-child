# Runbook: Rotating the Stripe Webhook Signing Secret

This runbook describes how to rotate the Stripe webhook signing secret used by
the `story-weaver-app` backend with zero downtime.

The webhook handler (`backend/routes/webhook_handler.py`, `handle_webhook`)
verifies every inbound Stripe event against two candidate secrets:

- `STRIPE_WEBHOOK_SECRET` — the primary (current) secret.
- `STRIPE_WEBHOOK_SECRET_OLD` — an optional secondary secret, used only during
  a rotation.

Because the handler accepts a signature that matches *either* secret, you can
roll the secret without any verification outage.

## When to Rotate

Rotate the webhook signing secret when:

- You suspect the secret has been exposed (committed to git, leaked in logs,
  shared insecurely, present in a compromised environment, etc.).
- As periodic security hygiene (for example, once or twice per year).

## Why Zero-Downtime Matters

Stripe retries failed webhook deliveries for roughly three days, so a brief
verification outage does not lose events permanently. However, a longer outage
is still harmful:

- Subscription state in our database (tier, status, period end) drifts out of
  sync with Stripe until the retries eventually succeed.
- During that window users can be shown the wrong entitlement — for example, a
  paid customer treated as free, or a delinquent account still treated as
  active.

Verifying against both the old and new secret during the rotation avoids any
window where in-flight webhooks return HTTP 401.

## Rotation Procedure

Perform these steps in order. Do not skip the redeploys — environment variable
changes in Railway only take effect on a new deployment.

### 1. Roll the secret in the Stripe Dashboard

In the Stripe Dashboard, go to **Developers -> Webhooks**, select the endpoint
for `story-weaver-app`, and roll its signing secret.

Stripe keeps the **previous** secret valid for **24 hours** after the roll, so
events signed just before the roll continue to verify during that grace window.
Copy the **new** signing secret (it starts with `whsec_`).

### 2. Preserve the current secret as the secondary

In Railway, open the `story-weaver-app` service variables.

Set `STRIPE_WEBHOOK_SECRET_OLD` to the **current** value of
`STRIPE_WEBHOOK_SECRET` (the value that is live right now, before this
rotation).

### 3. Set the primary secret to the new value

Still in Railway, set `STRIPE_WEBHOOK_SECRET` to the **new** secret you copied
from Stripe in step 1.

### 4. Redeploy the backend

Trigger a redeploy of the `story-weaver-app` service so both variables take
effect.

After this deploy the handler verifies against both the old and new secret, so
no event is rejected regardless of which secret Stripe used to sign it.

### 5. Remove the secondary secret after 24 hours

Once **at least 24 hours** have elapsed since the roll in step 1 (Stripe's
old-secret grace window has fully closed), no further events will be signed
with the old secret.

In Railway, **delete** the `STRIPE_WEBHOOK_SECRET_OLD` variable from the
`story-weaver-app` service and redeploy. The handler is now back to
single-secret verification using only the new secret.

## Verification

After the redeploy in step 4 (and again after step 5):

1. In the Stripe Dashboard, go to **Developers -> Webhooks** and open the
   `story-weaver-app` endpoint.
2. Review the **recent deliveries / event attempts** list.
3. Confirm recent deliveries show **2xx** response codes. No `401` responses
   should appear after the deploy completes.

If you want a deterministic signal, you can resend a recent event from the
Stripe Dashboard and confirm it returns 2xx.

## Rollback

If webhook deliveries start failing after a step:

1. In Railway, restore `STRIPE_WEBHOOK_SECRET` to its **previous** value (the
   value you saved into `STRIPE_WEBHOOK_SECRET_OLD` in step 2).
2. Redeploy the `story-weaver-app` service.
3. Re-check the Stripe Dashboard deliveries list to confirm 2xx responses have
   resumed.

Once recovered, investigate the cause before attempting the rotation again.
