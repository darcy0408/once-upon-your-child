# Task 4 — BUG-003 Stripe Anon Guard Call-Site Audit

**Model:** Sonnet
**Estimated effort:** 20–40 min

## Background

**BUG-003** (Stripe 403 console noise for anonymous users) was fixed on 2026-04-20b in commit `de5758f`:

- `lib/services/subscription_sync_service.dart` — in `syncSubscriptionStatus()`, if `resolvedUserId.startsWith('anon_')`, emit `SubscriptionStatus(tier: free, status: inactive)` and return without a network call.

The 2026-04-21 re-verification found the fix is **partially effective**:

- Fresh anon token (`anon_687d4b2762884e52` or similar): `GET /api/stripe/subscription-status/...` returned **200**.
- Stale anon token from a prior session: same endpoint returned **403**.

Since the guard is a simple string prefix check (`startsWith('anon_')`), it can't "fail" on stale tokens if it's reached. **The 403 must be coming from a different call site** that bypasses `SubscriptionSyncService.syncSubscriptionStatus()`.

## Your job

Find the second call site that hits `/api/stripe/subscription-status/` without the anon guard, and apply the same guard (or centralize the check so no caller can bypass it).

## Investigation steps

1. **Grep for the endpoint.** Find every Dart call site that hits the subscription-status URL:
   ```
   grep -rn 'subscription-status' lib/ backend/
   ```
   Expect hits in:
   - `lib/services/subscription_sync_service.dart` (already guarded)
   - Possibly another service, a hydration helper, or a direct call in a widget/provider

2. **Grep for the URL pattern broadly**, in case the path is built from a constant:
   ```
   grep -rn 'stripe' lib/services/ lib/providers/
   grep -rn 'SubscriptionStatus' lib/
   ```

3. **Check the backend side** too — `backend/routes/stripe_routes.py` or similar. Confirm the backend returns 403 unconditionally for anon IDs, or whether it's 403 only for expired/unknown tokens. That shapes whether the client-side guard is sufficient or whether the backend should also be lenient.

4. **Trace the stale-token scenario**: when a stored anon token is carried over from a previous session, which services fetch subscription status on app startup / resume? Grep for `WidgetsBindingObserver`, `didChangeAppLifecycleState`, and startup-hydration flows.

## Fix approach

Pick the cleanest option based on what you find:

### Option A — Add the guard to the second call site
If there's only one other caller, duplicate the guard. Quick, low-risk.

### Option B — Centralize the guard
If there are multiple callers, promote the check into a helper:
```dart
bool isAnonymousUser(String userId) => userId.startsWith('anon_');
```
Have every caller route through it (or through a single `SubscriptionApiClient` that applies the check). Prefer this if grep finds >1 unguarded caller — easier to keep in sync.

### Option C — Backend-side leniency
If the backend can return a `free/inactive` JSON body for anon IDs instead of 403, that removes the console noise without client-side coordination. This is cleanest but requires a backend change + deploy. **Consult `TEAM_COORDINATION.md` §2026-04-18 security sweep** — the 403 may be intentional security policy; don't loosen it without understanding why.

## Pass criteria

- ✅ `lib/services/` audit: every subscription-status call site routes through the anon guard.
- ✅ Stale anon token no longer produces a 403 in the network log (tested in browser or via a unit test that simulates a stale token).
- ✅ No new untested code paths for authenticated users — auth flow untouched.

## Deliverable

1. Code changes (Option A / B / C depending on findings).
2. Append to `TEAM_COORDINATION.md` under the 2026-04-21 entry:
   - `### BUG-003 call-site audit`
   - List of call sites found and which were unguarded
   - Chosen fix approach + rationale
   - Verification steps taken
3. Commit: `fix(stripe): guard <N> additional subscription-status call sites for anon users` (or `refactor` if Option B).

## Notes

- Do not loosen the backend 403 behavior without explicit sign-off from Darcy — there's a 2026-04-18 security-hardening sweep in this codebase and anonymous-auth flow has had dedicated fixes. Changes to the backend policy need to preserve the guarantees established there.
- If you find no second call site (grep turns up only `subscription_sync_service.dart`), dig into what the stale-token actually looks like on the wire — is it really prefixed with `anon_`, or does it get a different prefix after some rotation? Check `lib/services/auth_service.dart` or equivalent. The guard might be correct but the stale token's format might not match.
- Reference files:
  - `lib/services/subscription_sync_service.dart` — existing guard
  - `lib/services/auth_service.dart` — anon token format / lifecycle
  - `backend/routes/stripe_routes.py` — server-side behavior
  - `TEAM_COORDINATION.md` §2026-04-20b — original fix; §2026-04-21 — re-verification findings
