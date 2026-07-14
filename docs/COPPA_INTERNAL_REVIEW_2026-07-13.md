# Internal COPPA review — findings memo (2026-07-13)

**Scope:** `PRIVACY_POLICY.md` (live v2), `PRIVACY_POLICY_V3_DRAFT.md`, `COPPA_AMENDED_RULE_GAP_ANALYSIS.md` (G-1…G-12), and the code's actual data practices as of `main` @ `aa057bcc` (post D1/D2 merge), reviewed against the amended COPPA rule (effective 2025-06-23; compliance mandatory since 2026-04-22).

**What this is / is not:** an internal compliance review by the planning model, done ahead of outside counsel review. It is rigorous but it is **not legal advice, creates no privilege, and does not satisfy any requirement for review by counsel.** Cheapest future substitutes, in order: kidSAFE Seal certification review (already tracked as MT-320 — doubles as an external check), then a one-hour flat-fee privacy-attorney consult on THIS memo once revenue exists.

**Overall verdict:** the architecture is genuinely strong — most of what COPPA requires is already built (photo handling, pseudonymization, consent records, deletion cascade, analytics posture). The exposure is concentrated in two places: **enforcement that exists but is switched off**, and **a live policy statement the code contradicts.** Because the app is pre-launch with no child users, these are launch gates, not accrued violations. Do not open the kids' soft launch (L1) until F-1 through F-4 are closed.

---

## Launch gates (must close before any child uses the app)

**F-1 · CRITICAL — Server-side consent enforcement is OFF (G-2).**
The three enforcement toggles — `ENFORCE_RESOLVED_AGE`, `COPPA_REQUIRE_VERIFIED_CONSENT`, `COPPA_REQUIRE_CURRENT_POLICY_VERSION` — default to `"false"` and appear nowhere in `railway.toml`. Result: an anonymous session with no declared age and no consent record reaches every child-data endpoint. Collecting a child's personal information without verifiable parental consent is the core COPPA violation; the client-side flow is good, but the server is the operator.
**Fix (owner, ~15 min + a test pass):** set all three to `true` in Railway variables; then verify in staging that (a) an anonymous/no-age session is refused at gated endpoints and funneled to age declaration, and (b) the under-13 email round-trip is required in a release build. Add the three vars to `railway.toml` so they can't silently vanish. This closes G-2.

**F-2 · CRITICAL — The live policy calls emotional data "transient"; the code retains it.**
v2 (and v3, unchanged) describe "big feelings" input as "transient story-personalization input… not… a retained emotional profile." In reality `parent_hidden_context` persistently stores structured `feeling`, `trigger`, `body_signal`, `coping_tool`, `repair_goal` per child until account deletion or the 2-year purge. A privacy-policy statement contradicted by practice is an FTC Act §5 deception issue independent of COPPA, and it's the exact pattern FTC orders cite.
**Fix — requires one product decision (Darcy):**
- *(a) Make the code match the words:* use the context for generation, then delete (or ≤30-day TTL with its own purge). Loses story continuity.
- *(b) Make the words match the code* **(recommended)**: v3 discloses a retained "story personalization profile" with its retention period, and the parent dashboard gets a view/edit/delete control for it (parental review rights, §312.6, are required anyway).
Either way, v3's wording must change **before publication** — as drafted, v3 carries the contradiction forward. This closes STORE_PRIVACY_FORMS Gap 2.

**F-3 · HIGH — v3 promises "no training on your data" before the OpenAI DPA/ZDR exists (G-3).**
v3 states providers are "prohibited from using it for their own purposes, including training their AI models." That is only true once the OpenAI DPA + Zero Data Retention are executed. v3's own header correctly says don't publish before G-3 — hold that line.
**Fix (owner):** execute the DPA and ZDR request per PR #363's checklist (self-serve in the OpenAI org console), archive the executed copies in the business Drive, then G-3 closes and v3's claim becomes true.

**F-4 · HIGH — IllustrationCache survives account deletion and is keyed by the child's real name (G-5).**
Parents have a deletion right (§312.6); a cache entry containing child-derived content, keyed by real name, that persists 365 days after the account is purged, breaches it — and the real-name key is itself unnecessary retention.
**Fix (agent-sized ticket):** hash the cache key (name → SHA-256, matching the pseudonymization posture) and add a deletion hook: `purge_user_data()` evicts the account's cache entries (add `user_id` or a key-registry per account). Backups already roll off in 30 days and v3 discloses that — acceptable.

## Fix before v3 publishes (paper, not danger)

**F-5 · HIGH — Publish the retention policy.** The amended rule requires a written, published retention policy; v3's table is good and v2 has none. Sequence: close F-2's wording + F-3, add the two lines below (F-7), bump `CURRENT_POLICY_VERSION` to 3 (`consent_record.py`), publish, and re-consent on next login where practices materially changed (the separate-disclosure-consent language is new — treat it as material). Closes G-4, G-7, G-8.
**F-6 · MEDIUM — Write the security program (G-9, amended-rule requirement).** A short WISP is enough at this scale: named coordinator (Darcy), data inventory (the v2 vendor table is 90% of it), vendor-assurance appendix (closes G-6 — collect the SOC2/DPA links for Azure, Cloudflare, Railway, etc.), backup-restore re-purge procedure (so a restore can't resurrect purged children's data), and incident response steps. I can draft this next — it's a document, not code.
**F-7 · LOW — notice gap (updated after implementation):** v3's identifier section omitted the IP address stored on `ConsentRecord` — now added on branch `session/coppa-f4-f7`, with a flagged nuance for the final copy pass (the section's surrounding prose calls the listed identifiers "random" and pre-consent, which doesn't describe an IP captured at consent). The ElevenLabs under-18 gate this review originally listed was ALREADY fixed on `main` by PR #424 (2026-07-09) with test coverage — the extraction source (`STORE_PRIVACY_FORMS_DRAFT.md` Gap 1) is stale on this point and should be marked resolved there. F-4 implementation also upgraded the finding: cache keys were hashed but **unsalted** (dictionary-attackable over common first names); they're now HMAC-salted with the server secret, plus the deletion hook via a `user_id` column.

## Noted, not urgent
**F-8 · LOW —** `_kSkipEmailConsent = !kReleaseMode` is fine (TestFlight/App Store builds are release mode; the bypass can't ship) — just never flip it to a runtime flag. **F-9 · LOW —** legacy `child_profile_service.deleteProfile` swallows backend failures (G-12) — fix opportunistically; the server-side cascade is the one that matters and it's solid.

## What's already right (keep it that way)
Photo bytes are consent-gated before the request is even read and never stored — only the cartoon avatar persists. Real-name pseudonymization to vendors is live (G-1 closed). Consent records are provable: timestamp, IP, method, verified flag, policy version. The deletion cascade covers everything but the cache (F-4). Retention crons run daily with a Redis heartbeat; unconsented parent emails purge at 30 days; consent codes expire in 15 minutes. Analytics/crash reporting: off by default, separate opt-in, adults only, no `setUserId`, emotional events first-party only (post-`aa057bcc`). No ad SDKs. This is a better baseline than most shipped kids' apps.

## Suggested order
1. F-1 env flip + staging verification (owner, today-sized)
2. F-2 decision (owner: option a or b) → v3 wording + parent-dashboard control (agent)
3. F-3 DPA/ZDR execution (owner, self-serve)
4. F-4 cache ticket + F-7 one-liners (agent, one branch)
5. F-6 WISP draft (planning model) → F-5 publish v3 + version bump + re-consent (agent)
6. kidSAFE application when trust budget allows — doubles as external review.
