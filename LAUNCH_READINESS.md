# Launch Readiness Tracker

Single source of truth for what stands between Story Weaver / "Once Upon YOUR
Child" and a safe public launch. Points at — rather than duplicates — the full
detail in `audit-reports/NN-*.md`, `docs/MANUAL_TASKS.md`, and
`docs/SAFETY_AUDIT_REMEDIATION.md`. For the actual next step to take, see
`docs/SOFT_LAUNCH_CHECKLIST.md` — that's the shorter, currently-actionable
plan for opening the kids' bands to a small invited group; this file is the
broader launch-readiness map (including the fuller public/monetized launch).

> **2026-07-06:** For the decision-sequenced path (what to do, in what order, tagged
> owner/Sonnet/external), see **`docs/LAUNCH_CRITICAL_PATH_2026-07-06.md`** — it also
> adjudicates the staleness in this file (the "3 open PRs" below are all MERGED; 4 of
> the 07-05 audit's 5 blockers are closed in code as of 07-06).

- **Reconciled:** 2026-07-03 (previous pass was 2026-06-07 and had rotted —
  it predated the LLC, the restore drill, and the OpenAI/Azure provider
  migration; all three are corrected below). The app is still
  **pre-launch / pre-revenue** (no real users). A finding that "blocks public
  launch" gates a *future* event; a bus-factor finding could have killed the
  project at any time — both were historically tracked as P0 here. As of this
  pass, bus-factor is mostly closed (see P1); what's left is almost entirely
  **owner-ops config flips and external sign-offs**, not code.
- **Status keys:** OPEN · IN-FLIGHT (PR up, not yet merged) · DONE (verified
  merged/live) · VERIFY (code looks done, needs a live/prod check).
- **Maintenance:** when a gate clears, update its row here **and** close the
  matching ID in `docs/MANUAL_TASKS.md` — don't let the two drift again.

---

## What shipped today (2026-07-03) — 3 open PRs, not yet merged

Found while reconciling this file — none of these are landed yet, despite
being drafted today. Don't treat them as done until merged:

| PR | Branch | What it does | State |
|---|---|---|---|
| **#364** | `fix/image-name-pseudonymize` | Pseudonymizes the child's real name before it reaches any image-generation vendor (OpenAI/Cloudflare/Replicate/OpenRouter never receive it — cache keys + seeds keep the real name locally so a child's own re-reads still hit their cache); also lands an avatar-decode hardening fix in `gemini_image_generator.py` that had sat uncommitted for 3+ sessions. Closes MT-311#16. | **OPEN**, unmerged |
| **#365** | `session/tts-gate` | Age-gates the legacy Gemini→Edge TTS fallback chain so it can never reach an under-13 user if Azure fails to init (previously only ElevenLabs had this gate — a real gap, since Gemini is contractually barred for under-18 use, MT-248/MT-137). Also fixes a CI gap: `test/services`, `test/providers`, `test/utils` were never run by `main_tests.yml`, so `distress_detector_test.dart` (crisis-detection logic) had **zero** CI coverage. | **OPEN**, unmerged |
| **#363** | `session/compliance-docs` | Docs-only. Adds `docs/OPENAI_DPA_ZDR_COMPLIANCE.md` (owner checklist for MT-318) and `docs/SEL_FRAMEWORK_ALIGNMENT.md` (CASEL-5/ASCA-36 mapping, closes most of the SEL-credentialing competitive gap — clinician section still `[TO BE NAMED]`). | **OPEN**, unmerged |

---

## P0 — True launch gates (≈9 items, almost none of them code)

Everything here is either a Railway config flip, a credential-generation step,
or an external human sign-off. The code these gates depend on is already
merged to `main` (all 8 safety-audit PRs — see
`docs/SAFETY_AUDIT_REMEDIATION.md`).

> **Owner decision (2026-07-17): COPPA enforcement is intentionally OFF during testing.** In prod today `COPPA_REQUIRE_VERIFIED_CONSENT` = `false` and `ENFORCE_RESOLVED_AGE` = `false` **on purpose** — the under-13 Resend consent round-trip is too much friction to repeat on every test. Rows 1 and 3 below stay OPEN *by choice*, not because they're blocked. **Do NOT flip them until launch / before any untrusted tester gets an invite link** — the flip is verified-safe when the time comes. (`COPPA_REQUIRE_CURRENT_POLICY_VERSION` is currently `true`.)

| # | Gate | Type | Status | Action |
|---|---|---|---|---|
| 1 | `COPPA_REQUIRE_VERIFIED_CONSENT=true` on Railway | env flip | OPEN | Flip after #2 below is verified live. Tracked as MT-166 + `docs/SOFT_LAUNCH_CHECKLIST.md` §A row 1. |
| 2 | Flip `_kSkipEmailConsent` to `false` (`lib/screens/parental_consent_screen.dart`) + live Resend round-trip verify | code flip (1 line) + live verify | OPEN | This is the actual under-13 verifiable-consent mechanism; #1 just enforces it server-side. MT-135. |
| 3 | `ENFORCE_RESOLVED_AGE=true` on Railway | env flip | OPEN | Client-side age-sync prerequisite **shipped** (`ParentalConsentService.recordConsent` durably POSTs `declared_age`, PR #361) — this flip is now unblocked. MT-310 step 3. |
| 4 | `COPPA_REQUIRE_CURRENT_POLICY_VERSION=true` on Railway | env flip, **needs a pre-flight query first** | OPEN | `CURRENT_POLICY_VERSION=2`; flipping re-prompts every under-13 whose consent record is `NULL`/`<2`. **Before flipping:** count affected rows in prod Postgres (`docs/SAFETY_AUDIT_REMEDIATION.md` PR 5) so the re-prompt wave size is known, not a surprise. MT-174 item 4. |
| 5 | `DISABLE_GEMINI_IMAGE=1` on Railway | env flip | OPEN | Belt-and-suspenders: without it, avatars/illustrations *could* fall back to Gemini (contractually barred for under-18, MT-137) if Cloudflare/Replicate/OpenAI all fail. Code-side exposure already closed (PR #319 — direct Gemini now requires an explicit dev-only opt-in, confirmed unset in prod). `docs/SOFT_LAUNCH_CHECKLIST.md` §A row 2, MT-295. |
| 6 | `ENCRYPTION_KEY` — generate, set on Railway, back up to a vault | credential generation | OPEN | Not set in prod at all today; server-side BYOK key-save 500s until it's set, and it is **not re-issuable** once keys are stored with it — back it up the instant it's created. MT-238, `docs/SOFT_LAUNCH_CHECKLIST.md` §B. |
| 7 | Execute OpenAI DPA + confirm Zero Data Retention for the child-prompt path | contractual (owner) | OPEN | Gap is contractual, not code — OpenAI's API already doesn't train on API data by default. Checklist drafted in open PR #363 (`docs/OPENAI_DPA_ZDR_COMPLIANCE.md`, not yet merged). MT-318. |
| 8 | Clinical sign-off on the adolescent-antihero content review | external review | OPEN | Only gates the 15-17 band (kids' soft launch doesn't touch it). Self-contained packet ready: `docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`, backed by a 7/7-clean evidence batch. MT-266(c). |
| 9 | External legal review — COPPA verifiable-consent mechanics + data retention/deletion completeness | external review | OPEN | Route out per `docs/SAFETY_AUDIT_REMEDIATION.md` "External review" section; nothing here is Claude-doable. |

Full detail: `audit-reports/04-legal-20260519.md`, `audit-reports/01-privacy-20260607.md`,
`docs/SAFETY_AUDIT_REMEDIATION.md`, `docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md`.

### What's already true (don't re-litigate these)

- **All 8 safety-audit PRs merged to `main`** as of 2026-07-01 — purchase
  gating, generation-output egress + fail-closed for all minors, authz/generator
  hardening, COPPA consent/collection posture, analytics off-by-default,
  crisis-resources panel, BYOK Gemini-image guard, and the LLM-moderator
  Gemini→OpenAI decouple. Only **P2#17 (Isar at-rest encryption for offline
  child PII)** remains as open code work, and it's deliberately deferred (data-
  loss/migration risk; needs its own careful pass) — not a launch blocker.
- **Provider migration off Gemini is done for text, avatars, and narration** —
  story text runs on OpenAI GPT-5 mini for all tiers, avatars on OpenAI
  gpt-image (PR #301), narration on Azure AI Speech, and layer-2 content
  moderation now runs on OpenAI too (PR #341, 2026-07-01). **Only the
  image-generation last-resort fallback remains Gemini-reachable** (Cloudflare
  Flux → Replicate → Gemini), and only via an explicit dev-only opt-in that's
  confirmed unset in prod — gate #5 above (`DISABLE_GEMINI_IMAGE`) is the
  belt-and-suspenders close on that, and it has **not** been confirmed flipped
  in prod. Do not claim this fully done until it has.
- **LLC formed 2026-06-21.** The old "operator is an individual, not a legal
  entity" finding (L-DOC-07) is closed.
- **Backup restore has been drilled and proven — this reverses the prior
  tracker.** `docs/RECOVERY.md` §4 still reads "untested — prove it" (that
  section itself is stale), but `docs/PROJECT_STATUS.md` and
  `docs/SOFT_LAUNCH_CHECKLIST.md` both confirm the drill happened: daily
  `pg_dump` → Cloudflare R2, restore-drill verified, **measured RTO ~2s**
  (`restore-drill.yml`), plus failure alerts. Bus-factor's worst single risk
  (an unrecoverable DB) is closed.
- **Security review: no critical issues** (auth/IDOR, Stripe webhooks, prompt
  injection, child-PII scrubbing, CSP/CORS) per `docs/SOFT_LAUNCH_CHECKLIST.md`.

---

## P1 — Strongly recommended, not blocking (bus-factor, store launch, reliability, brand)

### Bus-factor / continuity — partially done
The restore drill (above) closed the worst risk. Still open, all cheap and
owner-only, no code: build the credential vault + name a second party
(Google Inactive Account Manager + password-manager Emergency Access, pointed
at the three sons per `docs/RECOVERY.md` §2); back up `ENCRYPTION_KEY` /
`JWT_SECRET_KEY` / `SECRET_KEY` / `backend/.env` into it the moment they exist;
create the Android release keystore (MT-144 — prereqs verified, runbook at
`docs/ANDROID_KEYSTORE_RUNBOOK.md`, not yet executed). None of this blocks the
free/invited kids'-band soft launch; all of it should happen "this week"
regardless, per `docs/RECOVERY.md` §5.

### Mobile store launch (deferred — soft launch is web-first, free, invited)
Android keystore (MT-144), IAP receipt verification (MT-143, ~45h of agent-
codeable work still stubbed, blocked on console provisioning — MT-317),
trademark clearance for "Once Upon YOUR Child" / "Story Weaver" vs. Pratham
Books' StoryWeaver namesake (MT-172), Play Data Safety + App Store privacy-
nutrition forms (MT-145). None of this is needed while there's no store
listing — see `docs/SOFT_LAUNCH_CHECKLIST.md` §D.

### Reliability & observability
Sentry worker/beat `CeleryIntegration` gap, pre-scrub prompt PII in worker
logs, fabricated founder-dashboard numbers, no alert on Stripe-webhook/backup/
AI-cost-runaway failure, finished-story content expiring after 1h, sync-gen
double-generation cost risk, shallow `/health`. Detail:
`audit-reports/12-observability-20260603.md`, `audit-reports/08-reliability-20260522.md`.

### Accessibility
CTA contrast fails AA on Adult/Sprout bands; CanvasKit web semantics only
partially wired for screen readers (WCAG 2.2 AA gate). Detail:
`audit-reports/06-accessibility-20260521.md`.

### Brand / marketing-compliance
SEL/CASEL credentialing gap vs. Slumberkins — CASEL-5/ASCA-36 mapping mostly
done in open PR #363 (`docs/SEL_FRAMEWORK_ALIGNMENT.md`); naming an advisory
clinician + a kidSAFE Safe Harbor quote remain (MT-320). "Once Upon a Time"
in-product string drift vs. the "Once Upon YOUR Child" brand (L-ALIGN-07,
partial).

Already cleared, do not re-open: pyjwt CVEs, a11y custom_lint gate,
payment/COPPA route tests, pricing/manage-sub/debug-toggle fixes, streaming/
double-gen/cold-start/WebP perf work, P0 content-safety moderation, all 9
actionable security findings, story-craft CR-01..05.

---

## P2 — Post-launch / iterative

Catalogued in the source audit reports; not a strict gate. Themes: onboarding/
wizard/reader UX polish (~45 items, mostly Medium/Low), accessibility beyond
the 2 AA blockers (~20), legal paperwork/brand polish (~25, EULA/CCPA/DMCA-
agent/auto-renewal disclosures), content-safety residue (~10), reliability
mediums (~10, webhook idempotency, pool sizing, secret rotation docs),
story-craft polish (~8), code-quality refactors (~4), performance residue (~5).
Work these after P0/P1. Full detail in the numbered `audit-reports/`.

---

## Recommended execution order

1. **This week — the P0 owner-ops flips (#1-6 above).** All cheap (minutes to
   an hour each), all Railway console or a one-line code flip + redeploy.
   `docs/SOFT_LAUNCH_CHECKLIST.md` is the literal click-by-click version of
   this for the kids'-band soft launch specifically.
2. **In parallel — the 2 external sign-offs (#8, #9) and the OpenAI DPA/ZDR
   contractual step (#7).** These have no code dependency and can run
   alongside step 1; they gate the adolescent band and the fuller public
   launch, not the kids'-band soft launch.
3. **Merge the 3 open PRs (#363/#364/#365)** once reviewed — none are
   launch-blocking by themselves, but #365's CI-coverage fix (crisis-detection
   test was running with zero CI coverage) is worth prioritizing.
4. **Bus-factor cleanup** (vault, keystore) — no dependency on the above,
   do whenever convenient this week.
5. **P1 reliability/observability + A11Y AA blockers**, then **P2**
   iteratively after launch.

> Maintenance: when an item ships, mark it here **and** in
> `docs/MANUAL_TASKS.md` — the per-task backlog is where the full working
> notes live; this file is the prioritized launch view.
