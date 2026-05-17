# Green Hat — Alternatives & Novel Mitigations

Story Weaver security audit, 2026-05-16. Alternative architectures, unconventional mitigations, and attack vectors not on the standard checklists.

## Architectural alternatives

### Make the privacy claim true instead of correcting it
C-1, M-7's photo component, and the undisclosed Cloudflare sub-processor all stem from server-side avatar generation. On-device avatar generation — extending the deterministic DiceBear-style rendering already used for preset avatars — would let "photos never leave the device" remain *accurate* and eliminate all three at once. If server-side generation must stay, a client-side face-abstraction/blur step before upload reduces biometric exposure of a real minor.

### One sanitization gateway, not a field allowlist
`sanitize_story_request` protects a named list of fields; H-3, H-4, and L-4 are all "a field nobody added to the list." Replace the allowlist with a single recursive pass that sanitizes *every* string in the request body and wraps it in `[USER_INPUT]`. New fields become safe by default — the vulnerability class is structurally removed, not patched instance by instance.

### Pseudonymize at the prompt boundary
Replace the child's real name with a per-request token (`HERO_1`) before any provider call; substitute it back locally in the returned story. Cheap, library-level, and it removes the highest-value PII from all four third parties — a clean fix for M-7 that does not depend on auditing each provider's retention policy.

### Fail-open by surface, not globally
"Fail open" is defensible for story *rendering* (a child should not see an error) but indefensible for the cost circuit breaker (M-2) and Sprout-band moderation (M-4). Split the quota subsystem: keep the availability path fail-open, back the *cost* breaker with a conservative DB counter so a Redis outage cannot uncap LLM spend, and serve a pre-vetted safe fallback story when the Sprout classifier errors.

### Server-side entitlement as the single source of truth
Treat every client premium flag as cosmetic. Gate each paid capability on `User.subscription_tier` at the endpoint. This collapses M-8 (editable local flags) and the H-2 / M-17 quota confusion into one trustworthy check, and makes client-side tampering irrelevant rather than merely inconvenient.

## Novel mitigations

### Verifiable consent via the payment rail you already have
H-8 needs a COPPA sliding-scale method. Stripe is already integrated — a $0.50 authorize-and-void on a parent's card is a recognized verifiable-consent method, stronger than an email round-trip, and reuses existing infrastructure with no new vendor. The card transaction itself is the proof an adult is present.

### Image-output classification
Flux providers (Cloudflare, Replicate) lack input moderation (M-5). Rather than trying to filter every input prompt, run a lightweight vision-safety classifier on the *generated image* before it reaches a child. Output moderation is provider-agnostic and catches drift the input filter structurally cannot.

### Per-user token-version claim
Add a `tv` claim to the JWT; bump a `token_version` column on logout or data deletion; reject any token whose `tv` is stale. This gives instant revocation without a per-request Redis lookup — fixing M-1 and the "deleted account keeps working for 24h" gap with one cheap claim, and it works even when Redis is down.

### Treat the LLM as untrusted output, always
Generated story text is re-fed into image-generation prompts (M-5). Conceptually the model's output is untrusted input to the next stage — apply the same sanitize-and-wrap discipline to model-generated scene descriptions that you apply to user input. This generalizes beyond the current pipeline.

## Unconventional attack vectors to keep in the threat model

- **Cross-field injection.** Per-field length caps can be evaded by splitting a payload across `worldBible` + `conflictHook` + `sensoryPalette` — the model reassembles the concatenated prompt. Defend at the assembled-prompt level, not per field.
- **The `validate-api-key` endpoint as a distributed oracle.** Unauthenticated and rate-limited only per identifier — an attacker with a corpus of leaked Gemini keys rotates identifiers/IPs to validate them all for free (L-1). The endpoint is a service *to the attacker*.
- **Voice-to-text as an injection channel.** `speech_to_text` feeds the superpower/quest fields. Any client-side text validation is bypassed because the text originates from the speech engine, not a text field — server-side sanitization is the only real defense.
- **Generated images never seen by a human or a filter before a child sees them.** The trust chain is entirely upstream; a single moderation miss is shown directly to a 4-year-old. Output classification (above) is the structural fix.
- **The singleton `anonymous` user as a shared-fate identity.** Anything keyed on it — rate limits, quotas, abuse counters — is shared across all anonymous users; one abuser degrades everyone (M-16).
- **Debug/QA builds as a COPPA bypass surface.** `?bypass_consent=1` is `kDebugMode`-gated, but every internally-distributed debug build is a build with no consent gate (M-15). The threat model should treat non-release builds as consent-gate-absent.
