# Launch Critical Path — 2026-07-06

**Author:** Fable 5 synthesis pass. **Sources adjudicated:** `LAUNCH_READINESS.md` (07-03),
`docs/LAUNCH_READINESS_AUDIT_2026-07-05.md` (ultracode audit), `docs/COPPA_AMENDED_RULE_GAP_ANALYSIS.md`,
`docs/SAFETY_AUDIT_REMEDIATION.md`, `docs/DISTRIBUTION_STRATEGY.md`, `docs/SOFT_LAUNCH_CHECKLIST.md`,
plus live PR/code verification on 2026-07-06.

**What this doc is:** the single decision-sequenced path from today to (1) kids'-band
soft launch, (2) monetized public launch, (3) the therapist-wedge business — with each
step tagged **[owner]** (only Darcy can do it), **[Sonnet]** (any cheap session can
execute it), or **[external]** (a human outside the project). Where trackers disagreed,
this doc states the adjudicated truth and why.

---

## 0. Adjudications — where the trackers were stale (verified against code/PRs today)

1. **The 2026-07-05 audit's 5 launch blockers are now 4/5 CLOSED in merged code.**
   - Cluster A (#1 Chronicle→Gemini, #2 avatar-tweak bypass) + the `gemini-tts-13-17`
     and provider-typo HIGHs: **closed by PR #385** (merged 07-06).
   - Cluster B #4 (verified-consent forgery): **closed** — `user_routes.py` now forces
     `verified = False` on all `record_consent` paths; only the email round-trip
     (`/consent/verify`) can promote it. #5 (age-redeclaration bypass): **closed** —
     upward re-declaration is refused + audit-logged for any account with actual
     knowledge of under-13.
   - Blocker #3 (gates default OFF) is not a code defect — it **is** the ops flip below.
2. **`LAUNCH_READINESS.md` "3 open PRs" section is stale:** #363/#364/#365 are all
   MERGED. So are #384/#385/#386. G-1 (real name to image vendors) is resolved.
3. **Still genuinely open in code (verified today):** crisis detection covers ONLY the
   interactive "Something Else" box (`story_routes.py:1849` is the sole `detect_crisis`
   call site). The audit's other HIGHs (photo-opt-in enforcement, PII-in-logs, BYOK promo
   copy, retention-policy v3) are unconfirmed-open — treat as open until a session
   verifies otherwise.
4. **Deadline pressure that is real:** Azure AI Speech free trial lapses **~2026-07-14**
   (MT-259). Everything else is self-paced; this one degrades narration in 8 days.

---

## 1. The decision that orders everything else

**The kids'-band soft launch (free, invited, web-only) is ~1 code-day + ~30 owner-minutes
away.** Nothing on the critical path to it requires external humans. The paused-launch
decision is the owner's to keep or lift — but the correct engineering posture is to make
the path *ready to walk*, so the pause is purely a business choice, not a masked backlog.

Sequence of launches this doc plans for:
- **L1 — Soft launch:** kids' bands (3-12), free, invited, no store listing. Gate: §2.
- **L2 — Public web launch + Stripe:** adds monetization + policy v3 + legal sign-off. Gate: §3.
- **L3 — Teen band on:** adds clinical sign-off. Gate: §4.
- **L4 — Mobile stores:** adds keystore, IAP, trademark, store forms. Gate: §5.
- **Business track (parallel):** distribution Phase 0 → pilot. Gate: §6.

---

## 2. L1 — Kids' soft launch (target: whenever owner says go; ready in ~1 week)

### 2a. Code, before the flips — [Sonnet], ~1 session
1. **Crisis detection on all free-text paths** — call `detect_crisis()` on
   `custom_elements`, `hero_secret`, `therapeutic_prompt` (and any parent free-text)
   before generation in every endpoint; return `crisis_response()` exactly as the
   continue-endpoint does. Add regression tests. *(Audit HIGH; highest-conscience item
   in a therapeutic kids' app. Small, isolated.)*
2. **Photo-avatar opt-in enforcement** — verify, then fix if still open:
   `avatar_routes.py:246` must load the latest non-withdrawn `ConsentRecord` and 403
   when `allow_photo_avatar=False` for under-13. *(Audit HIGH; contradicts the consent
   screen's promise.)*
3. **Child-PII log redaction** — `story_tasks.py:1547` logs child names/ages/full
   prompts at INFO in prod; demote to DEBUG or redact. *(Audit HIGH; 15-minute fix.)*
4. **Prod-verify #385** — hit prod chronicle/TTS/avatar-tweak endpoints and confirm the
   Gemini paths 4xx/fallback correctly; confirm `GEMINI_API_KEY` posture on Railway.

### 2b. Owner-ops flips, in this order — [owner], ~30 min total (SOFT_LAUNCH_CHECKLIST §A/§B is the click-by-click)
1. `ENFORCE_RESOLVED_AGE=true` (prerequisite PR #361 merged — unblocked).
2. Flip `_kSkipEmailConsent=false` (1-line client change — [Sonnet] can PR it) + one live
   Resend round-trip test with a real email.
3. `COPPA_REQUIRE_VERIFIED_CONSENT=true`.
4. `DISABLE_GEMINI_IMAGE=1` (belt-and-suspenders even after #385).
5. `ENCRYPTION_KEY` — generate, set, **and back up to the IAM-covered Google Doc in the
   same sitting** (not re-issuable).
6. `COPPA_REQUIRE_CURRENT_POLICY_VERSION=true` — **only after** the pre-flight prod
   Postgres count of consent records with version `NULL`/`<2` ([Sonnet] can run the
   query via `railway run`), so the re-prompt wave is known.
7. **Azure Speech: convert free→Pay-As-You-Go before 2026-07-14** (MT-259).

### 2c. Verify — [Sonnet], same day as flips
Deploy green · `/health` · kids'-band story end-to-end on prod · under-13 blocked
pre-consent (the `/auth/anonymous` probe from the gap analysis, now expected to 403) ·
consent email round-trip works.

**Exit criteria for L1:** 2a–2c all green. Then the launch decision is purely: send
invites or don't.

---

## 3. L2 — Public web launch + monetization (adds ~2-4 weeks of paperwork, little code)

- **Policy v3 batch** — [owner, then Sonnet for the code half]: retention schedule table
  (G-4), the two R-2 direct-notice sentences + unconsented-contact deletion job (G-7),
  identifiers-and-why paragraph (G-8). Bump `CURRENT_POLICY_VERSION` to 3 **after** the
  §2b.6 flip settled, to avoid two re-prompt waves.
- **OpenAI DPA + ZDR** — [owner]: execute per `docs/OPENAI_DPA_ZDR_COMPLIANCE.md`
  (merged, #363). This is consent-architecture (G-3), not hygiene — it keeps the
  single-consent model valid.
- **Azure + Cloudflare DPAs** — [owner]: collect self-serve data-protection terms, file
  with the OpenAI record (G-6).
- **External legal review** — [external]: COPPA consent mechanics + retention/deletion
  completeness. Package = gap analysis + LEGAL_LIABILITY_AUDIT + this doc.
- **Stripe go-live checks** — [Sonnet]: webhook idempotency medium from the audit, plus
  a live test purchase.
- **Audit mediums cleanup PR** — [Sonnet]: rate-limit decorator order, share gating
  under-13, moderation-fallback re-moderation, audit-log/illustration-cache retention.
- **kidSAFE LISTED** — [owner]: get the quote now (free to ask); buy when L2 is real —
  it's a badge purchase, the compliance bar is already exceeded.

---

## 4. L3 — Teen band (independent of L1/L2 timing)

- **Recruit the ONE named clinical advisor** — [owner, outreach already staged in
  MT-320/ac54 session]. This same person: (a) signs off the antihero packet
  (`docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`, evidence batch ready), (b) reviews the
  crisis flow incl. US-hardcoding, (c) becomes the named clinician for the SEL
  credibility kit (§6). **One person, three gates — highest-leverage single hire in the
  entire plan.**
- Until signed: teen band stays off. Nothing else blocks on it.

---

## 5. L4 — Mobile stores (defer until L2 has signal; ~45h+ of work)

Keystore (MT-144, runbook ready) → Play console + $25 fee (paused deliberately) → IAP
receipt verification (MT-143, stubbed, fail-closed — fine) → trademark clearance vs.
Pratham's StoryWeaver (MT-172, [external]) → Data-Safety/privacy-nutrition forms
(MT-145). **Do none of this before L2 shows demand** — it's the most expensive lane and
the only one with real third-party friction.

---

## 6. Business track — runs parallel to all of the above (from DISTRIBUTION_STRATEGY.md)

Phase 0 is executable *while paused*, costs ~$0-500, creates no public commitment:
1. **Credibility kit** — [Sonnet drafts, owner + clinician polish]: CASEL-5 checkmark
   matrix + ASCA mapping. `docs/SEL_FRAMEWORK_ALIGNMENT.md` (merged, #363) is 90% of it;
   remaining = the `[TO BE NAMED]` clinician (§4) + one-page PDF layout.
2. **Clinical advisor recruit** — same person as §4. Do this first; it unblocks three lanes.
3. **kidSAFE quote** — email, free.

Phase 1 (10-therapist pilot + nightly founder outreach) starts only at owner green-light,
after L1 exists to demo. Honest constraint from the strategy doc stands: **the binding
resource is founder hours, not dollars** — design the pilot async.

---

## 7. What to deliberately NOT do (kill list)

- No new audits. Fourteen exist; the marginal finding rate has collapsed. Next audit
  only after L2 is live with real users.
- No ASCA spend, no paid acquisition, no CASEL registry ($1,750 + RCT mismatch), no
  PRIVO/ESRB — per the distribution research.
- No Isar at-rest encryption work (P2#17 — impossible in Isar 3.1.0, OS FBE covers it;
  revisit at storage migration).
- No mobile-store work before L2 signal (§5).
- No re-verification of the "SOLID" list from the 07-05 audit or the "already true"
  list in LAUNCH_READINESS — they were adversarially verified; re-checking is waste.

---

## 8. Suggested calendar (relative to owner go/no-go)

| When | What | Who |
|---|---|---|
| **This week** | §2a code PR(s) + #385 prod-verify + Azure PAYG conversion (hard date ~07-14) | Sonnet + owner |
| **This week** | §2b flips 1-5 + §2c verify | owner + Sonnet |
| **Week 2** | §2b.6 policy-version flip (after pre-flight) · clinician outreach ships (§4) | owner |
| **Weeks 2-4** | L1 invites (if green-lit) · policy v3 drafting · DPA paperwork | owner |
| **Months 2-3** | Legal review round-trip · Stripe checks · mediums PR · kidSAFE purchase | mixed |
| **Month 3+** | L2 public launch decision · Phase 1 pilot · teen band when signed | owner |
| **Months 6-12** | L4 stores, only on L2 signal | mixed |

---

## 9. Maintenance rule

When any step here completes, update **this doc's** step, `LAUNCH_READINESS.md`, and the
matching MT — the 07-05 audit and 07-03 tracker both rotted within 48 hours because
parallel sessions ship faster than trackers update. The §0 adjudications are dated
2026-07-06; trust code over any tracker (including this one) after that date.
