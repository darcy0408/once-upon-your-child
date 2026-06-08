# Launch Readiness Tracker

Single source of truth for what stands between Story Weaver / "Once Upon YOUR
Child" and a safe public launch. Consolidates and **deduplicates** the open
findings from all 14 audit reports (`audit-reports/NN-*.md`) and the manual-task
backlog (`docs/MANUAL_TASKS.md`).

- **Reconciled:** 2026-06-07. The app is **pre-launch / pre-revenue** (no real
  traffic yet — verified in MT-223). That reframes priority: a finding that
  "blocks public launch" gates a *future* event, while a bus-factor finding can
  kill the project *today*. Both are P0 here.
- **How to read a row:** the same underlying issue often appears in several
  audits under different IDs — those are merged into one row with all aliases.
  Status reflects current reality (commits/PRs/MT state), **not** the audit's
  point-in-time text. Effort: S < 2h · M ~half-day · L multi-day.
- **Status keys:** OPEN · IN-FLIGHT (PR up) · FIXED (on main or in PR #242) ·
  PARTIAL · VERIFY (code looks done, needs a live/prod or vendor check).
- This file is the index; each row points to the audit report holding the full
  finding, exploit/repro detail, and remediation steps.

---

## P0 — Must clear before public launch, or fix now (existential)

Two clusters: **launch gates** (legal/COPPA/store/safety) and **bus-factor**
(project dies if the founder is unavailable). Bus-factor items are cheap and
**unowned** — nobody is working them — so they lead the execution order below.

### P0-A · Bus-factor / continuity (fix this week — hours, not days)

| ID(s) | Issue | Status | Effort | Owner action |
|---|---|---|---|---|
| CONT-keystore = 04 STORE-10 = MT-144 | Android release keystore **never created**; gitignored `key.properties` with debug-signing fallback. Unrecoverable + a Play-Store gate. | OPEN | S | Generate the keystore, back it up to the vault below, follow the MT-144 runbook. |
| CONT (ENCRYPTION_KEY) | `ENCRYPTION_KEY` encrypts every stored BYOK key (`backend/encryption_utils.py:34`); it lives **only** in Railway env, in no vault. Lose it → all BYOK keys undecryptable. | OPEN | S | Copy to an encrypted vault; document recovery. |
| CONT-03 | **Zero authorized second party**; no emergency credential vault for any account (GitHub/Railway/Cloudflare/Stripe/domain). | OPEN | S | Stand up a vault (e.g. 1Password emergency kit) + name one trusted person. **Highest leverage single fix.** |
| 08 P2 = CONT = OBS-07 | Postgres backup runs to R2 (outage fixed in #207/MT-220) but **restore is never tested** and there is **no DR runbook**. | OPEN | M | Do one restore drill; write `RECOVERY.md` ("prod down, founder unreachable"). |
| CONT (Cloudflare) | One Cloudflare account holds frontend **+** the only off-Railway backup (R2) **+** Workers AI. Single-account compromise = triple loss. | OPEN | M | Document; consider isolating R2 backups in a separate account. |

**Action kit: [`RECOVERY.md`](RECOVERY.md)** — vault structure, secret inventory,
restore drill, and the minimum-viable-bus-factor checklist for this whole
cluster. Full detail: `audit-reports/13-continuity-20260607.md` (+ `spof-map.csv`,
`succession-plan-template.md`), `audit-reports/08-reliability-20260522.md`.

### P0-B · Legal / COPPA / store launch gates

| ID(s) | Issue | Status | Effort | Owner action |
|---|---|---|---|---|
| PRIV-01 = 09 A-01 = 04 CMP-1 = MT-213/135 | Under-13 **verifiable parental consent disabled** in release (`_kSkipEmailConsent`). | **IN-FLIGHT — PR #241** | S | Merge #241; do the live `RESEND_API_KEY` round-trip verify. |
| 04 CMP-2 = MT-166 | Server flag `COPPA_REQUIRE_VERIFIED_CONSENT=false` on Railway. | OPEN | S (env) | Set `true` once #241's round-trip is verified in prod. |
| 09 A-02 = MT-214 (+ MT-226 pill) | "12–14" age control routes honest 13/14-yos into the under-13 path; masked only while VPC is skipped. | PARTIAL | S | Finish splitting the pill at the age-13 line (pairs with #241). |
| 04 L-AI-01 | **Gemini API terms reportedly prohibit child-directed apps.** Mitigation is already staged: `STORY_GEN_PROVIDER=openrouter` + `OPENROUTER_API_KEY` switches story-text generation off Gemini (`backend/.env.example:37-45`; brief in `audit/MT-171-OPENROUTER-MIGRATION-BRIEF.md`, MT-171). Image-gen still has a Gemini path. | OPEN (VERIFY) | S (flag flip) / M (full off-Gemini) | Decide the provider stance; flip the flag if you must avoid Gemini for child-directed content. Resolve early — it shapes cost + the stack. |
| 04 L-TM-01 | "Story Weaver" trademark collision (Pratham Books namesake). | OPEN | M | Counsel: clearance or finalize platform-name change. Customer brand is already "Once Upon YOUR Child". |
| 04 L-TM-02 = L-ALIGN-07 | In-product "Once Upon a Time" strings → trademark exposure + brand drift. | OPEN (PARTIAL) | S | Finish the rendered-string brand sweep. |
| 04 STORE-10 → see P0-A (keystore) | — | OPEN | S | (same item as CONT-keystore) |
| 04 L-DOC-07 | Operator is an individual, not a legal entity. | OPEN | M | Form an LLC before taking payments at scale. |
| 04 L-GOOGLE-01 / L-APPLE-02 | Play Data Safety form + App Store age-rating/listing not done. | OPEN | S each | Console paperwork — only gates the **mobile** store launch. |
| 04 L-PAY-01 (STORE-1) | IAP receipt verification not implemented. | OPEN | L | **Mobile-store only**; web Stripe is already live. Defer if launching web-first. |
| 02 F-07 | Child photos sent to 3rd-party image APIs with no retention guarantee. | OPEN | L | Confirm no-retention / DPAs (ties to PRIV-13, L-AI-03/MT-137). |
| PRIV-04/05 = MT-236/230 | "Delete All My Data" left `ParentHiddenContext`/codes behind; no Stripe propagation. | **FIXED — PR #242** | — | Merge #242. Client local-store sweep (PRIV-03) stays open under MT-236. |

Full detail: `audit-reports/04-legal-20260519.md`,
`audit-reports/01-privacy-20260607.md`, `audit-reports/09-ux-product-20260531.md`,
`audit-reports/02-content-safety-20260519.md`.

---

## P1 — Strongly recommended before launch (reliability, trust, cost)

Not strict legal gates, but the difference between a launch that survives contact
with users and one that fails silently.

| ID(s) | Issue | Status | Effort |
|---|---|---|---|
| OBS-01/02 | Sentry skips init if DSN unset; worker/beat have no `CeleryIntegration` → reliability alerts can no-op. | OPEN | S |
| OBS-03/16 = PRIV-08 | Worker logs the full **pre-scrub prompt** (child's real name) at INFO. | OPEN | S |
| OBS-04 | Founder dashboard reports **fabricated** error/latency/failure numbers. | OPEN | S |
| OBS-05/06/07/08 = 08 G1/G2/B2/SE1 | No alert on Stripe-webhook failure, backup failure, AI-cost runaway, or full outage (health cron disabled). | OPEN | S–M |
| 08 R2 | Finished story **content expires after 1h** (only metadata persisted) — a paid user can lose their story. | OPEN | M |
| 08 A3/X2 = 07 PERF-02 | Sync-timeout orphan thread → **double generation** (double AI spend). Perf side fixed; reliability side open. | OPEN | M |
| 08 A1/A5/R1/W1 | Sync gen exhausts the 2-worker pool; shallow `/health`; Redis eviction may drop tasks; worker restart loses in-flight task. | OPEN | S–M |
| A11Y-001/002 | CTA contrast fails AA (Adult/Sprout); CanvasKit web semantics partial. WCAG 2.2 AA gates. | OPEN | S / L |
| 09 P-02/P-03 = OBS-12 = MT-215 | Conversion funnel uninstrumented (checkout/paywall events never fire); analytics no-op on web. Can't measure launch. | OPEN | M |
| 09 P-06 | Orphaned "example" SubscriptionScreen reachable in the live path. | OPEN (VERIFY) | S |
| 10 F-01/F-02 | ElevenLabs default paid TTS + Claude-Sonnet OpenRouter fallback dwarf margin. | **FIXED — #205** | — |
| 10 F-03 = MT-223 | Image cost depends on Cloudflare free Neuron pool. | OPEN (dormant until traffic) | S |
| 05 AI age-fit | Seussian/rhyme/superhero modes fail age-fit at extreme ages (40–77%). | OPEN | M |
| CQ-03 | Frozen analyzer/build toolchain pinned by Isar 3 (blocks dependency hygiene). | OPEN | L |
| CQ-05/CQ-07 | `story_routes.py` god-file (2297 LOC, 30% cov); 365 `print()` instead of logging. | OPEN | M–L |
| 02 F-09 | Peer-mental-health quest ships no crisis resources. | OPEN | M |

Already cleared (do not re-open): **CQ-01** pyjwt CVEs (now `2.13.0`), **CQ-02**
a11y custom_lint gate (#213/#215), **CQ-04** payment/COPPA route tests (#214),
**09 P-01/P-05/D-12** pricing + manage-sub + debug toggle (#186), **07** perf
(streaming/double-gen/cold-start/WebP), **02** content-safety P0 moderation
(`3db0756e`), **03** security (all 9 actionable findings), **14** story-craft
CR-01..05.

Full detail: `audit-reports/12-observability-20260603.md`, `08-reliability`,
`06-accessibility`, `10-finops`, `11-code-quality`, `05-ai-quality`.

---

## P2 — Post-launch / iterative (summarized; not a strict gate)

Catalogued in the source reports; pulled up here as theme + count so the tail
isn't mistaken for "covered." Work these after P0/P1.

| Theme | Where | Open count (approx) | Note |
|---|---|---|---|
| Onboarding/wizard/reader UX polish | 09 (A-03..A-12, W-01..W-16, D-01..D-15) | ~45 | Mostly Medium/Low UX; W-04/W-05 (choice overload), D-03 (raw errors shown to kids), D-09 (dead-end empty state) are the High ones worth pulling into P1. |
| Accessibility (beyond the 2 AA blockers) | 06 (A11Y-003..018, LTR-01..04) | ~20 | Icon labels, alt text, dyslexia font, focus order, live regions. |
| Legal paperwork / brand polish | 04 (L-ALIGN, L-DOC-03..06, L-APPLE/-GOOGLE secondary, L-PAY-02/04) | ~25 | EULA, CCPA notice, DMCA agent, auto-renewal disclosures, Data-Safety SDK list. Counsel/console work. |
| Content-safety residue | 02 (F-08, F-10..F-20) | ~10 | Content warnings, image moderation, family-structure assumptions, age-band moderation divergence. |
| Reliability mediums | 08 (S2/S3, A2/A4, O2, W2, P5) | ~10 | Webhook idempotency, pool sizing, secret rotation docs. |
| Story-craft polish | 14 (FR-01..06, CR-06/07, R3/R5) | ~8 | Companion agency in pick-a-path, age-voice tuning. CR-06/R5 in-flight on `adventurer-craft-fixes`. |
| Code-quality refactors | 11 (CQ-06/08/09/10) | ~4 | mypy debt, Dart god-files, lib/ structure, doc staleness. |
| Performance residue | 07 (PERF-08/09/11/14, R0) | ~5 | Story-list query, gunicorn config verify, baseline capture. |

---

## Cross-audit dedupe map (the same issue under many names)

| Underlying issue | Aliases | Where it lives now |
|---|---|---|
| Under-13 verifiable consent off | PRIV-01, 09 A-01, 04 CMP-1, MT-213, MT-135 | PR #241 |
| Server consent-enforcement flag | 04 CMP-2, MT-166 | OPEN (env toggle, after #241) |
| 12–14 age bucket crosses COPPA line | 09 A-02, MT-214, MT-226 | OPEN (pill split) |
| Android keystore missing | 04 STORE-10, 13 CONT, MT-144 | OPEN |
| Backup restore untested / no DR | 08 P1/P2, 13 CONT, OBS-07 | OPEN (backup outage itself fixed #207) |
| Silent failure / blind alerting | 08 SE1/G1/G2/B2, 12 OBS-02/05/06/08, PRIV-12 | OPEN |
| Pre-scrub prompt PII in logs | 12 OBS-03/16, 01 PRIV-08 | OPEN |
| Double story generation | 08 A3/X2, 07 PERF-02 (perf side) | Perf fixed; reliability open; also a cost risk |
| Funnel/analytics blindness | 09 P-02/P-03, 12 OBS-12, MT-215 | OPEN |
| Child photos to 3rd parties | 02 F-07, 01 PRIV-13, 04 L-AI-03/MT-137 | OPEN |
| Erasure completeness | PRIV-04/05, MT-236/230 | FIXED (#242); client sweep open |

---

## Recommended execution order

1. **Bus-factor week (P0-A).** Vault + one second party (CONT-03), create + back
   up the keystore (MT-144) and `ENCRYPTION_KEY`, one backup-restore drill +
   `RECOVERY.md`. ~1–2 days total; converts most "unrecoverable" risk to "days".
2. **Merge what's already done.** PR #242 (erasure fix + these audits) and PR
   #241 (VPC), then the prod verifies they unblock (RESEND round-trip,
   `COPPA_REQUIRE_VERIFIED_CONSENT=true`, `STRIPE_API_KEY` set).
3. **Resolve the provider-terms unknown (L-AI-01) early** — it can change the
   architecture, so don't discover it last.
4. **Close the remaining legal gates** (entity, trademark, store paperwork) on
   the track that matches your launch surface (web-first defers the IAP/store
   items entirely).
5. **P1 reliability + observability** so launch failures are visible, then
   **A11Y AA blockers** and **funnel instrumentation**.
6. **P2** iteratively after launch.

> Maintenance: when an item ships, mark it FIXED here and in `docs/MANUAL_TASKS.md`
> (the per-task backlog remains the place for full working notes; this file is the
> prioritized launch view).
