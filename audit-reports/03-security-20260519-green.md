# 03 Security Audit — Green Hat (Alternative Architectures & Novel Mitigations)

Proposals beyond the checklist — architectural changes and unconventional
defenses that would harden the app against attack classes not currently
modelled. These are recommendations, not findings; none is required to close
a Black Hat item, though several would prevent whole categories of S-NN.

## 1. Make the rate-limit key un-spoofable by construction

S-01 exists because the limiter key function trusts a request header. A
structural fix that prevents the entire class: derive the unauthenticated key
exclusively from network-layer signal (`get_remote_address()` behind a trusted
proxy-header allowlist), and for authenticated traffic from the verified `sub`
claim only. Then make `get_user_identifier` *unable* to read a request body or
arbitrary header — pass it only `(authenticated_user_id, remote_addr)`. The
key function should not have access to a spoofable surface in the first place.

## 2. Authenticated-encryption envelope for all secrets at rest

Generalize the S-03 fix into a single `seal()` / `unseal()` helper built on
`AESGCM` (or libsodium secretbox) with a versioned key id prefix
(`v1:<keyid>:<nonce>:<ct+tag>`). Every secret-at-rest — BYOK keys today,
future OAuth refresh tokens, the consent verification codes — goes through it.
The version prefix makes key rotation a non-event: new writes use the new key,
old blobs decrypt under the old key id until naturally re-written.

## 3. Treat dead security code as a supply-chain risk, not just clutter

Beyond deleting `security/` (S-02): add a CI check that fails if any module
under a `experimental/` or `archive/` path is imported by shipping code, and a
check that flags any *new* top-level directory named like a security control.
Dead controls that look live are a recurring failure mode; a lint rule turns
it into a build error.

## 4. Defense-in-depth login protection independent of the rate limiter

S-01 shows that a single rate-limit layer is a single point of failure. Add a
per-account failed-login counter (`User.failed_login_count` +
`locked_until`), incremented on a bad password and reset on success,
independent of flask-limiter. Even with the limiter fully bypassed, an
attacker hits an exponential per-account backoff. Pair with a generic
"invalid credentials" response time floor to remove the user-enumeration
timing side channel.

## 5. Sign the IAP S2S notification trust boundary before phase 2 lands

For S-06: rather than relying on a future developer to remember the JWS / OIDC
verification, build the verification *first* as a standalone, tested function
that the stub already calls — the stub verifies the signature and *then*
returns "handled: false". When phase-2 wires in the entitlement logic, the
verification is already on the path and cannot be skipped. Verification-first,
business-logic-second.

## 6. Egress allowlist for the backend container

The backend makes outbound calls to a known, small set of hosts
(`generativelanguage.googleapis.com`, `openrouter.ai`, `api.replicate.com`,
Cloudflare, Stripe, Sentry, Resend). A container-level egress allowlist (or a
Railway network policy if available) turns any future SSRF or compromised-
dependency beacon into a blocked connection. Unconventional for a small app
but cheap insurance for one handling children's data and API keys.

## 7. Canary / honeytoken in the BYOK key store

Seed one `User` row with a deliberately-invalid "honeypot" encrypted BYOK key
whose plaintext is a unique unused string. A monitor that ever sees that
string leave the system (in a log, an outbound request, an error report)
signals a key-store exfiltration in progress. Cheap tripwire for the exact
asset S-03 is about.

## 8. Structured audit events to an append-only sink

`audit_log` exists for login/refresh/anonymous-session. Extend it to every
security-relevant event (admin action, tier change, consent grant/withdraw,
data deletion, IAP entitlement) and ship those events to an append-only
destination separate from the app DB. Today a DB compromise also rewrites the
evidence; a separate sink preserves the forensic record and supports the COPPA
§312.6 / GDPR accountability obligations.

## 9. Per-tier outbound cost ceiling enforced at the provider-call boundary

The cost circuit breaker is good, but it is a pre-flight quota check. A
complementary control: a hard monthly spend ceiling enforced *at the point of
the provider HTTP call* (a shared counter incremented on every Gemini/Replicate
request, checked before the call fires). S-05 shows a single rate-limit layer
can be miscounted; a spend ceiling at the actual money-spending line is the
true backstop and is provider-agnostic.

## 10. Replace the `X-User-ID` legacy header path entirely

Rather than gating the `X-User-ID` fallback, audit whether any client still
sends it (the Flutter app does not). If nothing uses it, delete the fallback
from both `get_user_identifier` and `get_current_user_id`. An unused, spoofable
identity header is pure attack surface — removal is the strongest fix.
