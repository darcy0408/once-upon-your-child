# Six Hats Review + Simplification Plan — 2026-07-03

Full-app strategic review (Six Hats + Pareto + pre-mortem + subtraction audit),
built from three parallel code/doc surveys (launch docs, backend health,
Flutter health). Product context: feature-complete, pre-launch, no live users;
launch deliberately paused by owner.

---

## ⚪ White Hat — Facts

- **94 open tasks** (91 open / 2 in-progress / 1 blocked) vs 149 resolved — but
  ~30 are April–May device-verification debt likely superseded by later PRs,
  ~18 owner config/account ops, ~10 art, ~5 external sign-off. **Genuinely
  unstarted code work ≈ 20 items, mostly P1/P2.**
- **True launch gates ≈ 9 items, almost none code:** Railway env flips
  (`COPPA_REQUIRE_VERIFIED_CONSENT`, `DISABLE_GEMINI_IMAGE`, `ENCRYPTION_KEY`
  MT-238, policy-version flag w/ pre-flight row count), `_kSkipEmailConsent`
  flip + Resend round-trip (MT-135), OpenAI DPA/ZDR (MT-318 — checklist in PR
  #363), clinical read of antihero packet (MT-266c), legal review of consent
  mechanics.
- **Dead weight quantified:** ~16k lines dead Dart (3.4k dead wizard steps +
  12.5k across 39 orphaned files), ~1.3–1.5k lines retirable backend
  Gemini/legacy-TTS code, 358MB local `assets/.png-backup/`, ~8.5MB orphaned
  tracked assets, 3 stale launch docs + 1 month-stale tracker.
- **Hard deadline: Azure Speech trial lapses ~2026-07-14** (MT-259).

## ⚫ Black Hat — Risks (ranked)

1. **Legacy TTS chain has no age gate** — `backend/routes/tts_routes.py:458-473`.
   If Azure fails to init in prod, under-13 narration silently falls to
   Gemini/Edge TTS (both barred, MT-248). ElevenLabs is `is_under_13`-gated;
   this path is not. ~1hr fix.
2. **`test/utils/distress_detector_test.dart` never runs in CI** — neither
   workflow runs `test/utils/`, `test/services/` (4 files), or
   `test/providers/`. Crisis-detection logic effectively untested in CI.
3. **Deployed build does self-attested consent, not verifiable** (MT-135,
   `_kSkipEmailConsent = true` in release). The launch-gate keystone.
4. **Doc rot actively misleads:** root `LAUNCH_READINESS.md` reconciled
   2026-06-07 (contradicts reality: restore drill done, LLC formed, Gemini
   migration complete); `docs/LAUNCH_READINESS_PLAN.md` +
   `docs/LAUNCH_BLOCKERS.md` describe the Netlify/Gemini/SQLite era; MT-295
   open in MANUAL_TASKS but closed in SAFETY_AUDIT_REMEDIATION; MT-166
   double-tracked vs SOFT_LAUNCH_CHECKLIST.
5. **Stranded-work pattern:** avatar-decode fix + MT-311#16 flagged across 3
   sessions before landing (landed in PR #364, 2026-07-03); MT-305/310/311/312
   ID collisions from parallel sessions.
6. **Distribution is the unsolved existential risk** (per 2026-07-03 88cb money
   assessment) — none of the 94 open tasks addresses it.

## 🟡 Yellow Hat — Strengths

- Hard engineering done: Gemini migration executed in a month; 8/8 safety-audit
  PRs merged; backups restore-drilled (RTO ~2s); 600+ backend tests green.
- Remaining critical path owned by us ≈ 2 days of env flips + one flag flip +
  one DPA email.
- Safety posture is the premium market position vs Slumberkins et al; the
  SEL/CASEL credentialing page is a cheap high-leverage asset (PR #363 starts
  this).
- Remaining code problems are subtraction problems — fast, safe, satisfying.

## 🔴 Red Hat — Gut

The app is done and the launch is being circled. Every remaining blocker is a
5-minute owner action or an external wait. The real question isn't "what to
improve" but "what needs to be true to flip the flags." Session sprawl
(3-session stranded fixes, ID collisions) is costing more than it parallelizes.

## 🟢 Green Hat — Creative Moves

- **Subtraction Sprint** — one session that only deletes (see Chunk 3).
- **Collapse 4 launch docs into one `LAUNCH_GATES.md`** (~9 rows, owner +
  status each); archive the rest with tombstone headers.
- **Bulk-staleness amnesty:** close the ~30 April–May verification MTs in one
  pass ("superseded — re-file if seen post-launch").
- **`BandConfig` centralization** — collapse the 22-file `switch(AgeBand)`
  duplication into `age_band_theme.dart` (post-launch).
- File the kidSAFE Safe Harbor quote as its own MT.

## 🔵 Blue Hat — Process

- One tracker (MANUAL_TASKS.md); everything else points at it or dies.
- Session WIP rule: branch not PR'd by session close → explicitly parked with
  an owner note, or reverted.
- Retire or explicitly bless `.github/workflows/cicd.yml` (legacy 7-test gate)
  vs `main_tests.yml` — two overlapping CI workflows with different coverage.

---

## Pareto — the 20% that is 80% of launch value

1. ~~Finish MT-311#16~~ → **PR #364** (2026-07-03)
2. Azure PAYG conversion (deadline 7/14, MT-259)
3. TTS legacy-chain age gate
4. MT-135 consent flip + Resend verify
5. The 4 Railway env flips in order
6. OpenAI DPA/ZDR request (MT-318, checklist in PR #363)

## Pre-mortem (Jan 2027, it failed — why?)

- *Most likely:* never launched — polish loop until energy ran out.
  **Mitigation: a dated soft-launch decision point, even if "not yet."**
- *Second:* launched, nobody came — distribution never got a wedge.
- *Third:* compliance incident via the ungated-fallback class of bug.
- *Unlikely:* cost blowout / technical collapse (breakers, backups, monitoring
  cover these).

---

## The Plan

### Chunk 0 — This week (deadline-bound + in-flight) ~1 day
- [x] Finish & PR `fix/image-name-pseudonymize` (MT-311#16) → **PR #364**
      (also landed the 3-session-stranded avatar-decode fix)
- [ ] **Azure Speech → Pay-As-You-Go** (lapses ~7/14; MT-259)
- [ ] Age-gate or delete the Gemini/Edge legacy TTS chain
      (`tts_routes.py:458-473`)
- [ ] Add `test/utils`, `test/services`, `test/providers` to `main_tests.yml`
- [ ] Merge PR #363 (DPA/ZDR checklist + SEL alignment)

### Chunk 1 — Truth reconciliation ~half day
- [ ] Collapse 4 launch docs → one current `LAUNCH_GATES.md`; archive
      `LAUNCH_READINESS.md` (stale 6/07), `docs/LAUNCH_READINESS_PLAN.md`,
      `docs/LAUNCH_BLOCKERS.md`, `docs/MASTER_LAUNCH_PLAN*.md`
- [ ] Reconcile MT-295 (likely closed via #319) + MT-166 double-tracking
- [ ] Bulk-close ~30 stale verification MTs
- [ ] File kidSAFE-quote MT

### Chunk 2 — Owner gate ops (~2 hrs, Darcy's hands)
- [ ] `ENCRYPTION_KEY` generate + set + vault (MT-238)
- [ ] `DISABLE_GEMINI_IMAGE=1`; confirm `ALLOW_DIRECT_GEMINI_IMAGE` unset
      (MT-295/309)
- [ ] Consent flags in order (MT-310) — pre-flight: count under-13 consent
      rows below current policy version before flipping
      `COPPA_REQUIRE_CURRENT_POLICY_VERSION`
- [ ] MT-135: `_kSkipEmailConsent=false` + live Resend round-trip verify
- [ ] Send DPA/ZDR request to OpenAI (MT-318)
- [ ] Route clinical packet (MT-266c,
      `docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`)

### Chunk 3 — Subtraction Sprint ~1 day
Backend:
- [ ] Extract shared prompt helpers (`gemini_image_generator.py:119-266`) →
      new module; delete `GeminiImageGenerator` class (~1,040 lines) + dead
      env flags (`DISABLE_GEMINI_IMAGE` etc. once retired) + call sites
- [ ] Note: `openrouter_image_generator.py` IS Gemini (routes
      `google/gemini-2.5-flash-image`) — retire with the Gemini scope
- [ ] Collapse the 6×-repeated import-fallback boilerplate into one
      `_load_generator()` helper
- [ ] Test-tree hygiene: delete `comprehensive_audit.py` (superseded by v2) +
      stale `tests/manual/*.pyc`; move 10 loose root-level scripts to
      `tests/manual/`
- [ ] Env cleanup: `STRIPE_WEBHOOK_SECRET_OLD`, consolidate
      `GOOGLE_API_KEY_2/3/4`

Flutter:
- [ ] Delete 3 dead wizard steps + their tests (`feeling_selection_step.dart`
      1,759 / `companion_selector_step.dart` 1,173 /
      `custom_pet_avatar_screen.dart` 452)
- [ ] Delete ~39 fully-orphaned files (~12.5k lines) — confirm the 3
      test-only-referenced ones first (`character_creation_screen.dart`,
      `feelings_garden_screen.dart`, `quality_badge.dart`)
- [ ] Delete `'Nonbinary'` dead branch (`wizard_data_mapper.dart:47-55`)
- [ ] Fix 6 "Story Weaver" brand-string drift sites (L-ALIGN-07):
      `subscription_screen.dart:63`, `subscription_models.dart:354`,
      `story_result_screen.dart:2137`, `welcome_screen.dart:987`,
      `parental_consent_screen.dart:318`, `achievement.dart:255`
- [ ] Delete local `assets/.png-backup/` (358MB, gitignored); confirm-then-
      delete orphaned `assets/brand/` (2.4M) + `assets/app Icon images/`
      (6.1M) + `assets/images/New folder/`; retire `netlify.toml`

### Chunk 4 — Post-launch structural (park until traffic)
- BandConfig centralization (22 files of `switch(AgeBand)`)
- Split `story_routes.py` (3,081) / `story_result_screen.dart` (5,833) /
  `hero_creator_step.dart` (3,980) / `magic_review_step.dart` (3,425) /
  `api_service_manager.dart` (2,869)
- Extract TTS fallback cascade from `tts_routes.py` into a service
- Startup env-var validation manifest (73 vars currently read ad hoc)
- Rename `tts_api_service.dart` → `elevenlabs_tts_client.dart`

### Chunk 5 — Distribution (after gates clear)
Replaces coding time. Product risk LOW, distribution risk HIGH and unsolved —
niche + B2B2C wedge experiments per the 88cb money assessment.

---

*Sources: 3 parallel survey agents (launch docs, backend, Flutter),
2026-07-03. Scout reports live in the session transcript; key file:line refs
inlined above.*
