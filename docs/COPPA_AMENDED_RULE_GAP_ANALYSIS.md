# Amended COPPA Rule (2025) — Gap Analysis for Once Upon YOUR Child

**Date:** 2026-07-03 (audit) · **Updated:** 2026-07-04 · **Author:** Fable 5 deep-compliance pass (session/fable-docs)
**Status:** Complete. **Correction (2026-07-04):** the codebase audit below was run
against `fix/image-name-pseudonymize` (PR #364) *before* it merged. **PR #364 has
since merged to `main`** — G-1 is therefore **RESOLVED**, not open. Left the
original wording below for the paper trail; treat G-1's status line as the
current truth, not the narrative text above it.

> **Why now:** The FTC's amended COPPA Rule was published 2025-04-22, became effective
> 2025-06-23, and its compliance deadline was **2026-04-22 — already in the past**.
> We are pre-launch with no live users, so there is no live violation, but the app
> must conform to the *amended* Rule (not the old one) on day one of launch. The FTC
> has said COPPA enforcement is a priority. This memo maps each amended-Rule
> requirement to our actual implementation and lists concrete gaps.
>
> **This is an engineering analysis, not legal advice.** Items marked `[legal]`
> route to counsel per docs/SAFETY_AUDIT_REMEDIATION.md § External review.

## Part 1 — What the amended Rule requires

Numbered R-1…R-10 for cross-referencing from Parts 2–3.

### R-1. Expanded "personal information" definition
Now explicitly includes **biometric identifiers** (voiceprints, facial templates/
faceprints, fingerprints, genetic data…), **government-issued identifiers**, and
mobile phone numbers. Practical impact for us: **child photos used for avatar
generation and any voice audio are squarely PI**; face-derived data is biometric PI.

### R-2. Direct notice to parents — expanded content
The consent-request notice must disclose: how the info will be used; the
**identities and categories of third-party recipients**, the purposes of disclosure,
and whether data becomes public; that the parent may **consent to collection/use
WITHOUT consenting to third-party disclosure** (unless integral to the service); and
that if the parent does not consent within a reasonable time the operator **will
delete the parent's contact info**.

### R-3. Online privacy notice — expanded content
The privacy policy must state: third-party recipient identities/categories +
purposes; the **data retention policy** (see R-6); the **specific internal
operations** for which persistent identifiers are collected and the safeguards
preventing their use for behavioral targeting/profiling; and audio-file
collection/use/immediate-deletion practices if audio is collected under the
consent exception.

### R-4. Separate verifiable consent for third-party disclosure
Consent to collect/use must be offered **separately** from consent to disclose to
third parties. Exception: disclosures **integral to the service**. Disclosure to a
vendor acting as a **service provider/processor bound not to use the data for its
own purposes (e.g., model training)** is the load-bearing distinction: a pure
processor is not a "third party disclosure" needing separate consent; a vendor
that trains on the data is. Hence the OpenAI **DPA + Zero Data Retention** work
(MT-318) is a *consent-architecture* requirement, not just hygiene.

### R-5. New consent methods (options, not obligations)
Knowledge-based authentication; government-ID + facial-comparison (both promptly
deleted); text-plus. Also: audio files collected solely to respond to a child's
request and **deleted immediately** are exempt from consent/notice.

### R-6. Written data-retention policy + retention limits
Operators **must maintain a written retention policy** stating (a) the purposes for
which children's PI is collected, (b) the business need for retaining it, and
(c) a **deletion timeline**. Children's PI may not be retained longer than
reasonably necessary for the documented purpose, then must be **securely deleted**.
The policy must be **published in the online privacy notice** (R-3). Indefinite
retention is expressly prohibited.

### R-7. Written information-security program
Designate personnel to coordinate it; **annual risk assessment**; safeguards
tailored to data sensitivity; regular testing/monitoring; **annual review**; and
**written confirmation from third parties** receiving children's PI that they use
reasonable security measures (vendor diligence — DPAs again).

### R-8. Mixed-audience definition + child-directedness factors
Two-step test; age screening required for mixed-audience services; the
child-directedness multifactor test now includes marketing materials,
representations to third parties, reviews, and comparable-service user ages.
We are **child-directed, children as primary audience** — not merely mixed —
so under-13 users get full COPPA treatment regardless of age gate answers.

### R-9. Safe harbor programs
Approved programs (e.g., kidSAFE) face stricter annual reporting/transparency.
Relevant to us only as a *buyer*: safe-harbor membership survives the amendment
and remains a credible certification signal (see distribution strategy doc).

### R-10. Persistent identifiers / support for internal operations
Persistent identifiers (our `anon_*` IDs, device IDs, crash-report IDs) collected
without consent are lawful **only** under the support-for-internal-operations
exception, which now must be **specifically enumerated in the notice** (R-3) and
must not be used for profiling/behavioral targeting.

## Part 2 — Current posture (codebase audit, 2026-07-03)

Audited on `fix/image-name-pseudonymize` (= main + PR #364); divergences from
`main` noted. Full lifecycle trace with file:line cites lives in the audit run;
the load-bearing facts:

**Collection.** Child PI collected: name, age, gender, feelings/mood + hidden
parent-context (allowlisted vocabulary with a PII-rejection filter on that one
endpoint — `character_routes.py:76-84`), free-text story inputs, photos for
avatar generation (transient; not stored server-side; resulting cartoon persisted
as `Character.avatar_data`). `allow_photo_avatar` defaults **False** (fail-safe).
No raw child voice is collected (child-voice STT was deleted; ElevenLabs is
hard-gated 13+ even as fallback).

**Vendor egress.** Story text goes to OpenAI **pseudonymized** (`HERO_1` token).
Image/avatar prompts: pseudonymized **only on PR #364 — on `main` today the
child's real name still goes to Cloudflare/Replicate/OpenRouter/OpenAI image
prompts**, while `PRIVACY_POLICY.md:148` and the consent screen already claim
otherwise. Consent-screen vendor list and privacy-policy vendor list currently
**match** (12 sub-processors). Gemini image fallback is guarded
(`DISABLE_GEMINI_IMAGE` / `ALLOW_DIRECT_GEMINI_IMAGE`). Sentry: frontend drops
all events pre-consent and strips breadcrumbs; backend `before_send` scrubs
bodies/headers/locals (no backend `before_breadcrumb`, exception-frames only).

**Consent.** Full email-verification round trip exists (Resend, hashed codes,
15-min expiry, attempt cap, fail-closed if unconfigured). `ConsentRecord` stamps
`policy_version` (current = 2); 13–17 use `self_attested`. But the three
server-side enforcement gates — `ENFORCE_RESOLVED_AGE`,
`COPPA_REQUIRE_VERIFIED_CONSENT`, `COPPA_REQUIRE_CURRENT_POLICY_VERSION` —
**all default OFF and are not set in `railway.toml`**.

**Pre-consent reachability (closes the SAFETY_AUDIT_REMEDIATION verification
item):** `POST /auth/anonymous` mints a `User` with `declared_age=NULL`,
`is_under_13=False` → `@require_parental_consent` early-returns for "not
under 13" → **every gated child-data endpoint (`/create-character`,
`/generate-story`, `/generate-custom-avatar`, `/tts/synthesize`…) is callable
with zero consent record** under default config. The Flutter client is
well-behaved (blocks on consent for <13, MT-311 made the 13–17 attestation
durable server-side), but the server does not independently require that the
flow ran. Flipping `ENFORCE_RESOLVED_AGE` closes this; MT-311's "durable
server age-sync on all onboarding paths" was the prerequisite and has merged.

**Retention/deletion.** `DELETE /api/user/<id>/data` → `purge_user_data`
cascades correctly (stories, characters, consent, hidden context; anonymizes
User; bumps `token_version`; best-effort Stripe customer delete) and the
client-side `LocalDataEraser` runs only after server 2xx. Scheduled inactive
purge at 730 days matches the policy. **Not covered:** `IllustrationCache`
(global, no `user_id`, cache key derived from the real character name on
`main`) survives deletion indefinitely; daily `pg_dump` → R2 backups retain
deleted users until the backup prunes — neither is disclosed in the policy.
Legacy `child_profile_service.deleteProfile` swallows backend-delete failures.

**Persistent identifiers.** Server `anon_*` IDs and a client `user_<uuid>`
device ID are created **before** any age/consent exists. JWTs carry only
`sub` + `token_version`. Analytics is off-by-default at class init and stays
off for all minors regardless of consent (#333 confirmed live).

**AI-training posture.** OpenAI: API no-training-by-default is asserted in code
comments, but the **DPA + Zero Data Retention are not executed** (MT-318, open,
contractual). Azure Speech and Cloudflare Workers AI have **no documented
retention/training posture** in the repo at all. BYOK-Gemini is explicitly
disclaimed as user-directed.

**Docs state.** `docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md` is current and
accurate; `docs/COPPA_AUDIT.md` is **stale** (claims gaps that are since fixed —
misleads in the *safe* direction but shouldn't be cited); `PRIVACY_POLICY.md` is
accurate except the two omissions/overclaims above.

## Part 3 — Gap register

Severity: **P0** = must close before launch day; **P1** = close before/with
launch announcement; **P2** = fast-follow. Owner: `code` / `ops` (Railway/GitHub
config) / `owner` (contractual, writing) / `[legal]`.

| # | Rule | Gap | Sev | Owner | Fix |
|---|------|-----|-----|-------|-----|
| G-1 | R-4, R-2 | ~~Real child name in image-vendor prompts on `main`~~ | **RESOLVED 2026-07-04** | code | PR #364 merged to `main` — image/avatar prompts now use `"the hero"`/`"the character"`, matching the policy/consent-screen disclosure. No further action |
| G-2 | R-2, R-4, R-10 | Server-side consent enforcement OFF: anonymous JWT reaches all child-data endpoints with no consent record | **P0** | ops | Flip `ENFORCE_RESOLVED_AGE` → then `COPPA_REQUIRE_VERIFIED_CONSENT` → then `COPPA_REQUIRE_CURRENT_POLICY_VERSION` (in that order; pre-flight the version-2 re-prompt wave). Already MT-310; this memo adds: prerequisite MT-311 is merged, so nothing blocks the first flip |
| G-3 | R-4, R-7 | OpenAI DPA + ZDR not executed; without processor status, sending child PI to OpenAI is arguably a third-party disclosure needing **separate** consent | **P0** | owner | Execute MT-318 (DPA + ZDR confirmation, keep written record). This converts OpenAI to a service provider and keeps the single-consent architecture valid |
| G-4 | R-6 | No written retention policy meeting the amended Rule's 3-part test (purpose / business need / deletion timeline) published in the notice; backup tail + `IllustrationCache` retention undisclosed | **P1** | owner+code | Add a "Data Retention Schedule" section to `PRIVACY_POLICY.md` (table: data class → purpose → need → timeline incl. R2 backup prune window). Bump `CURRENT_POLICY_VERSION` when published |
| G-5 | R-6 | `IllustrationCache` survives account deletion; on `main` its key derives from real name | **P1** | code | Small pass: purge rows on `purge_user_data` (add `user_id` or delete-by-character-key), or accept + document if keys become pseudonymous after #364 — decide, then record |
| G-6 | R-7 | Azure Speech + Cloudflare Workers AI retention/security posture undocumented; amended Rule requires **written** third-party security assurances | **P1** | owner | Collect the standard DPAs (Microsoft + Cloudflare both have self-serve data-protection terms); file alongside MT-318's OpenAI record |
| G-7 | R-2 | Direct notice lacks two new required statements: parent may consent to collection **without** third-party disclosure (or state disclosure is integral), and parent contact info **will be deleted** if consent isn't granted in reasonable time — and the deletion behavior itself doesn't exist | **P1** | code | Consent screen + `PRIVACY_POLICY.md` copy; add a cleanup job (or extend the existing retention task) deleting parent email from unconsented `ConsentVerificationCode`/pending records after N days |
| G-8 | R-10 | Persistent identifiers (`anon_*`, device `user_<uuid>`) created pre-consent are lawful only under the support-for-internal-operations exception, which must now be **specifically enumerated** in the online notice | **P1** | owner | Add an "identifiers we create and why" paragraph to the policy (auth continuity, subscription sync, crash reporting; no profiling/behavioral targeting — which is true, analytics is off for minors) |
| G-9 | R-7 | No written information-security program / annual risk-assessment artifact | **P2** | owner | One-page ISP doc: coordinator = owner; safeguards inventory (JWT hardening, token_version revocation, Sentry scrub, fail-closed moderation, R2 backup encryption); annual review date. The existing audits are 90% of the content |
| G-10 | R-1 | Child photo → avatar path touches biometric-adjacent data (face imagery to OpenAI/Replicate) | **P2** | owner | Already opt-in (`allow_photo_avatar` default False) and transient; add explicit biometric-category language to the direct notice `[legal]` sanity-check |
| G-11 | — | `docs/COPPA_AUDIT.md` stale in the safe direction; risk of citing wrong doc | **P2** | code | Mark it superseded, point at this memo + LEGAL_LIABILITY_AUDIT |
| G-12 | R-6 | Legacy `child_profile_service.deleteProfile` swallows backend-delete failure (silent under-deletion) | **P2** | code | Surface the failure or route the legacy path through the Parent Controls cascade |

**What is NOT a gap (verified):** consent-screen/policy vendor lists match;
analytics off for all minors; email-verification consent flow is sound
(hashed codes, fail-closed); deletion cascade + local eraser ordering correct;
JWT payload minimal; ElevenLabs under-13 hard gate; Sentry client gate;
mixed-audience question moot (we treat the app as child-directed with children
as primary audience — the strictest reading).

**Sequenced launch checklist (supersedes nothing; consolidates):**
1. ~~Merge #364 (G-1)~~ **DONE 2026-07-04** → 2. Execute OpenAI DPA/ZDR (G-3) → 3. Flip the three env
gates in order (G-2) → 4. Publish retention schedule + notice updates, bump
policy v3 (G-4, G-7, G-8) → 5. Collect Azure/Cloudflare DPAs (G-6) →
6. Code fast-follows (G-5, G-12) and ISP doc (G-9). Route G-7/G-10 language
past counsel with the existing external-review batch.
