# Launch Embarrassment Synthesis — 2026-07-17

**What this is:** one honest, prioritized read across the full audit corpus — `LAUNCH_READINESS.md`,
`docs/PROJECT_STATUS.md`, the 07-05 ultracode launch audit, the legal-liability / COPPA / amended-Rule
docs, `SAFETY_AUDIT_REMEDIATION.md`, the competitive/UX/SEL/distribution docs, the image-cohesion and
fresh-eyes walkthrough reports, `docs/MANUAL_TASKS.md`, and the July session records — answering:
*what would actually embarrass us, or get us pulled, at launch?* Claims below were spot-verified
against current code and live tracker state (e.g. `gh issue view 449`, `story_routes.py`,
`avatar_generation_service.py`) rather than taken from any single doc, because the docs disagree
with each other in load-bearing places.

**Context:** pre-launch, launch pause LIFTED 2026-07-08. "No live users" is fraying at the edges —
invited testers have had links since ~07-14.

---

## The 5 things that would actually embarrass us at launch

### 1. COPPA enforcement is OFF in prod right now — and our own status doc says it's ON

- **Fact (verified today):** `ENFORCE_RESOLVED_AGE` and `COPPA_REQUIRE_VERIFIED_CONSENT` were set
  `false` on Railway the evening of **2026-07-15** at the owner's request (test-iteration friction).
  Issue **#449** ("launch blocker: re-enable COPPA enforcement flags before real users") is **OPEN**.
  Tester-phase behavior: no-age users pass all gates; under-13 passes with an *unverified* checkbox
  record — no email round-trip. The prod smoke test's 403 assertions fail by design while this stands.
- **The embarrassing part:** `docs/PROJECT_STATUS.md` — *last updated 2026-07-17, today* — still says
  "COPPA launch-gate flags FLIPPED ON (2026-07-14) … smoke-verified." Anyone (including a future
  session, or the owner on launch morning) reading the status doc believes the #1 legal gate is
  closed. It is not. This is exactly how the flags ship OFF on launch day: not by decision, but by a
  stale doc absorbing the decision.
- **Aggravator:** invited outside testers already have links (the 07-14 flip rationale was "testers
  should hit the real consent posture"). If any invited family's under-13 child is using the app
  today, we are collecting child data on an unverified checkbox — the precise thing three audits
  called the top launch blocker.
- **Who'd notice:** an FTC/state-AG reviewer or kidSAFE assessor in minutes (create account, no age,
  generate — it works); a diligent parent; a journalist doing the "I tested the kids' AI app" piece.
- **Smallest fix:** the returning-client landmines that forced the rollback are all closed now
  (#442 age back-fill, #448 media-src CSP, cache-buster #447, Pages cutover) — re-flip both flags,
  re-run `test_production_smoke.py` until the 403 assertions pass, close #449, and correct
  PROJECT_STATUS §Known-Issues-2 in the same commit. Until the owner wants the flags on, PROJECT_STATUS
  must say **OFF** — never report prod as COPPA-enforcing while #449 is open.

### 2. Prod has repeatedly not been what the docs said it was — and no audit owns "does prod match main"

Fourteen audits cover code, none covers the deploy/verification pipeline — which is where the
actual, user-visible failures have come from:

- The apex domain served a **frozen May 29 build off the "orphaned" Railway frontend for ~6 weeks**
  while every doc said "frontend on Cloudflare Pages" (the cutover step had never been executed;
  discovered + fixed 2026-07-15).
- **All narration audio was dead on prod web** (missing `media-src` CSP) — the third CSP incident —
  and was declared fixed twice on status-code evidence while every user got the robotic voice.
  Five stacked causes took two days to unwind (flags, quota, CSP, immutable disk cache, dead CI).
- **CI deploys silently skipped from ~07-11** (private-repo artifact quota): runs looked green,
  nothing shipped.
- The async story path **never completed for any adult/long story** (unauthenticated 401 polls,
  3 duplicate Celery generations per attempt) until the 07-15 walkthrough caught it — on live prod.
- **Who'd notice:** every first user; the owner's own demo already died this way ("lost them before
  the first story"). This is the most *probable* launch embarrassment, even if #1 is the most severe.
- **Smallest fix:** one post-deploy behavioral smoke, run on every deploy: (a) `curl -sI` the apex
  and assert `server: cloudflare` + non-immutable cache headers; (b) one story generated E2E through
  the 202 path; (c) an instrumented **audible-playback** probe (hook `HTMLMediaElement.play`), never
  a 200-check; (d) assert the deployed `main.dart.js` hash matches the build. Half of this already
  exists in scattered session recipes — it needs to be one script with a red light.

### 3. Ship-quality landmines in the bundle: adult-coded assets, an unlicensed watermark, and a Sprout first-story that contradicts the child

- `assets/feelings_faces/aroused.webp` (baked **"Aroused"** label, seductive smirk), `intimate.webp`
  (kissing faces), `violated.webp`, plus garbage-word files — no code path shows them, but
  `pubspec.yaml` bundles the folder, so **they ship in every build and are extractable from the APK**.
  "COPPA-focused kids' app ships an 'Aroused' emotion asset" is a ready-made headline and an easy
  Apple-reviewer rejection. (Image-cohesion audit P0-2, still open.)
- `assets/images/feelings/adolescent/surprised.webp` has a **tiled FREEPIK watermark** — visible on a
  live picker AND unlicensed stock in a paid app (P0-1; the earlier Freepik find, MT-263, was fixed —
  this one is a second instance found 07-15).
- **MT-371 (open):** Sprout per-page illustrations — hero doesn't match the picked avatar, identity
  changes page to page, garbled AI text baked into art, wrong scene art on cards. This is the
  flagship band's payoff moment, after a parent just spent 5–6 minutes and an email code getting there.
- Plus the funnel itself: 8 pre-wizard screens, ~110s generation, and voiceless pre-consent Sprout
  onboarding (TTS 403s by design for the one band that can't read; MT-373).
- **Who'd notice:** parents and reviewers (MT-371, funnel); journalists and Apple (the assets).
- **Smallest fix:** delete the unreachable `feelings_faces` files and replace one watermarked webp —
  an afternoon, zero code risk. MT-371's lead (prefetcher fires with `characterAppearance=null`) is
  the next biggest first-impression lever.

### 4. The paperwork half of amended-COPPA compliance isn't published — while the code half is genuinely done

The engineering posture is strong (see reconciliation below), which makes the unpublished paperwork
the weakest exposed flank:

- **Privacy Policy v3** (retention schedule per R-6's 3-part test, the two R-2 direct-notice
  statements, persistent-identifier enumeration, backup-tail/IllustrationCache disclosure) — drafted
  (`docs/PRIVACY_POLICY_V3_DRAFT.md`, 07-07), **unpublished** (MT-330: counsel review then publish).
  The amended Rule's compliance deadline (2026-04-22) is already past; on day one of launch this is
  a live gap, and it's *checkable from outside* by anyone who reads the policy.
- **OpenAI DPA + Zero Data Retention not executed** (MT-318 / G-3). This is load-bearing: without
  processor status, sending child prompts to OpenAI is arguably a third-party disclosure needing
  *separate* consent — the entire single-consent architecture leans on this signature. It's a
  console click-through, still not done.
- **No consent-withdrawal path** (MT-352): `ConsentRecord.withdrawn` has no write path; a parent can
  delete everything or nothing. COPPA/GDPR Art. 7(3) expects revocation.
- **Azure + Cloudflare written security assurances uncollected** (G-6); external legal review of the
  consent mechanics (P0 #9) not routed.
- Quietly related: **CF-IPCountry never reaches the backend** (app calls Railway directly), so EEA
  age-raising is off and everything fails to the US-13 threshold — fine for a US soft launch,
  indefensible the day a German parent signs up.
- **Who'd notice:** a regulator or kidSAFE assessor first; a competitor or journalist doing a policy
  read-through second.
- **Smallest fix:** the v3 publish + DPA/ZDR execution are both owner-hours, not code. MT-352 is a
  medium code task. Do the first two before any public URL circulates.

### 5. "Therapeutically grounded" marketing with no named clinician — our own audits call this pattern out in competitors

- The SEL alignment doc is honest and good — and its §5 clinical advisory is a **placeholder**; it
  explicitly forbids presenting the product as "clinically reviewed" until a named clinician has
  actually reviewed it. Sunkel declined 07-13; Padron/Jones outreach is open. Meanwhile the
  competitive audit's own positioning rule is: *"never ship Oscar's unverifiable 'reviewed by
  educators' pattern — name the clinician or don't claim it."* If launch copy says "therapeutic" /
  "clinically-reviewed antihero arc" with §5 empty, we become the thing our audit mocked.
- Adjacent: crisis resources are **US-hardcoded** (988/Crisis Text Line) with the clinical review
  that would bless or fix that still unrouted — awkward the moment a non-US teen hits the panel.
- The antihero band itself is correctly gated OFF (`ANTIHERO_CRUX_ENABLED` default off) — that part
  is handled; the exposure is marketing language, not content.
- **Who'd notice:** clinicians (the exact B2B2C channel the distribution strategy depends on),
  journalists, and the FTC's health-claims lens.
- **Smallest fix:** a launch-copy sweep that claims only what's checkable (constrained generation,
  per-story moderation, real consent flow, transparency notes — the safety page from the competitive
  audit's #1 recommendation) and keeps "clinically reviewed" out of every surface until §5 is real.

**Honorable mentions (real, but less likely to embarrass at a web soft launch):** trademark
clearance vs. Pratham Books' "StoryWeaver" still open (MT-172 — mitigated by the customer-facing
"Once Upon YOUR Child" brand, bites at store listing); no alert on AI-cost runaway + the
duplicate-generation/idempotency gap (MT-375) + solo-pool/Redis SPOF (MT-338) — a modest traffic
spike silently breaks or bills; the unbounded OpenAI avatar call → gunicorn 504s; Celery env-drift
silent-hang precedent (celery-beat still unfixed).

---

## Stale / contradictory docs (drift to fix)

| Doc | Problem |
|---|---|
| **`docs/PROJECT_STATUS.md`** (dated *today*) | Known-Issues §2 claims COPPA flags ON — **false since 07-15 evening** (issue #449). Also internally contradictory: line 9 says grand-light/Netlify deleted 07-17 vs line 128 "decommission pending"; "ElevenLabs TTS narration" listed as a current core feature (narration is Azure); "Story-generation Gemini key rotation `GOOGLE_API_KEY_2/3/4`" still under Infrastructure (text is OpenAI); Architecture row says moderation "being decoupled … tonight's PR" (merged #341 on 07-01). |
| **`LAUNCH_READINESS.md`** (the "single source of truth", last reconciled 07-03) | Most stale doc of all: P0 #6 says `ENCRYPTION_KEY` "not set in prod at all today" (set + verified 07-04 and 07-14); P0 #1–4 flags listed OPEN (flipped ON 07-14, OFF 07-15 — neither reflected); frames #6 around BYOK key-save (BYOK sunset 07-15, MT-358); "3 open PRs #363/364/365" all long merged; P0 #5 `DISABLE_GEMINI_IMAGE` "not confirmed" (MT-295 closed done). Needs a full re-reconcile pass before anyone uses it to make the launch call. |
| **`docs/TRIPLE_LENS_UX_THERAPEUTIC_AUDIT.md`** | December 2024 fossil: recommends Gemini BYOK onboarding (Gemini contractually forbidden on child paths; BYOK deleted), analyzes screens that no longer exist. Mark superseded or delete — it's the only corpus doc with no header warning. |
| **`docs/COPPA_AUDIT.md`** | Correctly marked superseded, but its headline "verifiable consent not yet implemented — planned v1.1" is now wrong in *both* directions: the Resend round-trip is fully built and live-proven (07-15 walkthrough) — it's just switched off (#449). |
| **`docs/AGE_BAND_UX_LAUNCH_AUDIT.md`** | Two findings were overruled by owner decisions and the doc never annotated: MT-264 "regenerate robin without the cross" (the cross necklace is an intentional memorial — never strip it) and MT-265 neutral gender option (owner wontfix 06-21, Boy/Girl only). A future session executing this doc verbatim would violate both decisions. |
| **`docs/LAUNCH_READINESS_AUDIT_2026-07-05.md`** | Its two Gemini launch blockers (chronicle→Gemini, avatar-tweak→Gemini) and the crisis-free-text HIGH are all fixed in code (verified today: `chronicle_routes.py` has zero Gemini references; avatar tweak re-routed per the MT-327 comment; `_crisis_guard` covers `custom_elements`/`hero_secret`/`therapeutic_prompt`). No closure annotations → risk of re-reporting closed blockers. |
| **`docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md`** | Findings #5 (crisis input detection) and #11 (reporting mechanism) are now fully shipped (MT-327; PR #417 report button, parent-gated) but the findings table and "Still open" list stop at 06-28. Stale in the safe direction. |
| **`docs/SAFETY_AUDIT_REMEDIATION.md`** | Launch-gate checklist boxes unchecked and unannotated with the 07-14 flip / 07-15 unflip saga. |
| **`docs/RECOVERY.md` §4** | Still says restore is "untested — prove it"; the drill is done and proven (RTO ~2s). Already flagged in LAUNCH_READINESS, still unfixed. |
| **Any pre-07-15 claim that "prod frontend = Cloudflare Pages"** | Was aspirational until the 07-15 DNS cutover; any pre-07-15 "verified in prod" frontend claim is suspect (it verified the frozen May build). |

**Meta-pattern:** the tracker discipline ("when a gate clears, update LAUNCH_READINESS **and**
MANUAL_TASKS") broke in both directions during July. MANUAL_TASKS is the most current of the three;
LAUNCH_READINESS the least. Recommendation: one reconcile pass that makes LAUNCH_READINESS point-in-time
correct *and* adds issue #449 as P0 row 0.

---

## Genuinely done vs. claimed done — the top launch gates

| Gate | Claimed (where) | Actual (verified) |
|---|---|---|
| COPPA env flags ON | PROJECT_STATUS: ON since 07-14 | **OFF since 07-15 evening** (owner request; issue #449 OPEN). The single biggest claim/reality gap in the corpus. |
| Verifiable consent mechanism (Resend round-trip) | COPPA_AUDIT: "not implemented, v1.1" | **Genuinely done and live-proven** (07-15 walkthrough: real email round-trip, code <30s). Just not enforced (see above). |
| Client age-sync + returning-client backfill | — | **Done** (PR #415 onboarding PATCH; PR #442 startup back-fill after the 07-14 regression). |
| Consent-forgery + age-redeclaration closures (07-05 blockers #4/#5) | 07-05 audit: open | **Done** ("Cluster B closed" per 07-06/07-07 sessions; the flip is no longer hollow). |
| Crisis detection on ALL child free-text | 07-05 audit: only interactive path | **Done** — `_crisis_guard` in `story_routes.py` (MT-327) covers custom_elements, hero_secret/tell/line, therapeutic_prompt, raw-text-before-sanitization. |
| Report-content mechanism | Legal audit #11: mailto-only, buried | **Done** — PR #417, reader "Report this content" → `POST /report-story`, parent-gated. |
| Gemini off child paths | Various, partially | **Code-complete** (chronicle ported; avatar/app Gemini paths require `ALLOW_DIRECT_GEMINI_IMAGE` opt-in + honor `DISABLE_GEMINI_IMAGE`; TTS fallback under-18-gated via #365; provider-typo coercion fixed). Residual is env hygiene only (MT-295 closed). |
| `ENCRYPTION_KEY` | LAUNCH_READINESS: "not set in prod" | **Set + verified twice** (07-04, 07-14). Tracker stale. |
| Backups restorable | RECOVERY.md §4: untested | **Proven** (drill verified, RTO ~2s, R2 daily). RECOVERY.md stale. |
| OpenAI DPA + ZDR | — | **NOT done** (MT-318/G-3; owner console task; load-bearing for consent architecture). |
| Privacy Policy v3 (retention schedule, R-2 notices) | Drafted 07-07 | **NOT published** (MT-330; needs counsel pass). |
| Consent withdrawal path | — | **NOT built** (MT-352). |
| Clinical sign-off / named advisor | SEL doc §5 | **NOT done** (Sunkel declined 07-13; antihero stays correctly gated OFF, so exposure is marketing copy, not content). |
| External legal review | — | **NOT done** (P0 #9, unrouted). |
| Mobile IAP | — | Stubbed, fail-closed, flag off — fine for web launch, blocks any store paid launch (MT-350). |
| Story-quality judge harness | PROJECT_STATUS | Correctly documented as on-demand only (scheduled workflow deleted in #168) — this one is honest. |

---

## Gaps no audit covers (the unknown-unknowns for a solo founder shipping a kids' app)

1. **Deploy/prod-parity verification** — the biggest real-failure source (see #2 above) and the only
   layer with zero audit coverage.
2. **International posture as a whole** — EEA consent-age (CF-IPCountry null), UK AADC applicability,
   US-only crisis numbers, non-US store metadata. Each appears as a footnote somewhere; nobody owns it.
3. **Operational support surface** — no support-inbox SLA, no status page, no incident-response
   runbook for a *content* incident (moderation failure reaching a real child: who's notified, what's
   preserved, what's said to the parent). The report button now exists; the process behind it doesn't.
4. **Consent-email deliverability at scale** — the round-trip is proven against one Gmail inbox;
   SPF/DKIM/DMARC posture for the Resend sending domain against Outlook/Yahoo/corporate filters is
   unaudited, and a consent email in spam = a locked-out paying parent.
5. **Commerce/legal boilerplate** — ToS/EULA, auto-renewal state disclosures, refund policy, sales-tax
   (Stripe Tax) registration all sit in the P2 pile with no owner or date; business insurance is a
   memory note, not a plan.
6. **Capacity under even mild success** — sync story-gen in the web process + solo Celery pool +
   Redis SPOF + no cost-runaway alert means one modest Reddit thread degrades or over-bills the
   service invisibly (MT-338/MT-375 exist but aren't sequenced against launch).

---

## Verdict — if forced to launch tomorrow

The single worst thing that happens tomorrow is not a crash — it's that the app launches **exactly as
it is**: COPPA enforcement flags still off (because issue #449 is open but PROJECT_STATUS says the
gates are on, so nobody re-checks), a retention-policy-less privacy notice, and no executed OpenAI
DPA — while real under-13 accounts sign up on an unverified checkbox. Every line of the hard
engineering (consent round-trip, crisis guard, moderation fail-closed, Gemini exit, pseudonymization,
deletion cascade) is genuinely built and would survive scrutiny; what fails scrutiny is that the
*switch is off and the paperwork is unpublished*, which to a regulator, a kidSAFE assessor, or a
journalist is indistinguishable from never having built it. The probable-embarrassment runner-up is a
first-run experience failure nobody caught because deploys aren't behaviorally verified — the pattern
that already ate six weeks once. Both are cheap to fix, neither is code, and both are invisible from
inside the repo — which is precisely why they're the dangerous ones.
