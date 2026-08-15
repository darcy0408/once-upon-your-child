# Team Coordination

## Recent Sessions

New sessions are written as individual files in `docs/sessions/` (one file per close).
This table indexes the last ~30. **Append new rows at the top of the table body.**
Older session blocks below this table are kept for history but no longer added to.

For the global manual-task backlog, see `docs/MANUAL_TASKS.md`.

| Date  | Time  | ID   | Branch | Topic | File |
|-------|-------|------|--------|-------|------|
| 2026-08-15 | 16:13 | 23e1 | main + `fix/mt-397-consent-verify-errors` (PR #38 OPEN) | **MT-144 CLOSED + MT-397 shipped**: Android release keystore generated (owner-side; credential boundary held), alias `upload`, valid to 2053 — build-side proof is the AAB signer cert matching the keystore cert byte-for-byte, which is what rules out the debug-signing fallback; the first keytool attempt silently defaulted to 90-day validity because the runbook's bash `\` continuations split under PowerShell (caught and redone); off-machine backup made and proven restorable (hash match + opens with the stored password). MT-397: the consent-verify endpoint returns one identical body for every rejection and differs only by HTTP status, and `ApiError` discarded the status — so wrong-code / expired / attempt-cap were indistinguishable **in principle** and the "code did not match" branch was dead code; status now plumbed through, three distinct messages, expiry window read from the server instead of mirrored as a client constant, Resend clears the stale code (13 new tests, 5/5 CI green). Also scrubbed a private filesystem path that had been sitting in `docs/MANUAL_TASKS.md` since July (history unchanged). Six merged branches deleted. **Unfinished: CLAUDE.md rule 2 (render at phone width) NOT satisfied for the UI change — see record** | private |
| 2026-08-14 | 22:35 | f271 | main (PR #37 MERGED) | Open-session briefing; PR #37 Flutter CI pin confirmed merged (by e4b2) + main CI re-verified green; local branch cleanup | private |
| 2026-08-14 | 22:30 | e4b2 | main (PRs #18–#23, #37 ALL MERGED) | **Dependency triage + main CI unbroken**: 6 Dependabot merges; all 4 security alerts resolved (they were stale — dependency graph hadn't re-ingested the Aug-4 aiohttp/cryptography fix; the merges forced it); #37 pins Flutter 3.41.9 at all 5 flutter-action sites (unpinned `stable` drifted to 3.47.0 on 08-14 and broke every main push's frontend jobs; last green was 08-05) + drops cicd.yml's dead `FLUTTER_VERSION` env; PR-triggered metered macOS run cancelled at 16s (ios-build.yml's paths include itself — recurs on any PR editing it); post-merge main runs BOTH GREEN. MT-144 pre-verified fully staged (Gradle wiring + example + gitignore + keytool on PATH) — only owner keystore steps remain, queued as next session's first task | private |
| 2026-08-13 | 22:01 | 36ef | main (PRs #35, #36 MERGED) | Android manifest ad-ID permission strip (#36); #35 merged; worktree cleanup | private |
| 2026-08-05 | 17:56 | 9c41 | session/secure-demo (PR #35 OPEN) | **Recovered the crashed Android sideload + demo-readiness assessment; shipped `web/.well-known/security.txt`** (`0bc4581e`): the crashed build was intact on disk (142MB fat release APK, debug-signed — no `key.properties` exists) and got onto the phone over **MTP via PowerShell `Shell.Application`**, sidestepping an `adb` that stayed `unauthorized` all session. RFC 9116 file verified to actually deploy (flutter_tools copies `web/` with no hidden-file filter; a real `flutter build web --release` put it at `build/web/.well-known/`); `security@` mailbox now proven by live email, closing the 545c carry-forward. Two findings filed: **MT-402** — `cost_tracking.py` has **zero `track_cost()` call sites**, so the $10/day + $50/week budget limits have never fired and the admin cost report reads $0 regardless of actual spend; **MT-403** — `firebase_analytics` merges `AD_ID` + two `ACCESS_ADSERVICES_*` permissions into the APK of a children's app. Note PR #35 draws **no CI by design** (every workflow is path-filtered to `lib/**`/`test/**`/`backend/**`, so `web/**` + `docs/**` matches none) | private |
| 2026-08-05 | 17:26 | 486a | main (PRs #31, #32, #33, #34 ALL MERGED) | **Crash recovery — rescued an uncommitted consent-screen fix, merged the two open voice PRs.** A prior session testing the app as an iPhone home-screen PWA ended in a machine crash; it had left `lib/screens/parental_consent_screen.dart` (+420/-327) uncommitted in the shared checkout, on no branch and in no stash — recovered to a patch file, then to an isolated worktree, merged as **#33** (`7e68aef5`): the consent read-gate's only "why is this button dead" hint was an up-arrow pointing away from the scroll the parent needs, so a `_readEnough` getter + a bottom-edge "Keep scrolling" cue replace it. Merged **#31** (`03b2ec75`, voice-input privacy disclosure — the third-party lists had covered narration only, never speech *recognition*) and **#32** (`dfc78a1f`, `/api/transcribe`, inert behind `TRANSCRIPTION_ENABLED`). #31 collided with #33 in the same widget tree; resolved by taking #33's file and re-applying #31's block, then proving nothing was dropped via a whitespace-stripped set-difference rather than a diff read — re-verified on `main` after the squash. Main checkout cleaned and fast-forwarded to `7aa632fb`; both session worktrees removed | private |
| 2026-08-04 | 15:37 | bb1f | main (PRs #25, #26 MERGED) | **MT-392 CLOSED — prompt-drift detector re-anchored by AST symbol** (`890144ce`): all 13 registry entries were mis-anchored, not the 3 filed, so `snapshot --verify` had been reporting 12 PASS on code containing no prompt; spans now match `inspect.getsource` byte-for-byte so eval hashes equal the `revision_hash` persisted on Story rows; Creator + Adolescent builders registered for the first time; 76 new tests are the CI gate. Plus **four published CVEs cleared** (`15e82e88`, aiohttp 3.14.3 / cryptography 50.0.0) — `pip-audit` had gone red on main and all 7 open PRs, time-triggered, not a code regression | private |
| 2026-07-16 | 17:55 | ffb4 | main (PR #453 MERGED) | **Actions billing UNBLOCKED — MT-376 CLOSED + #453 merged** (`e0283375`): owner set account Actions budget $0→$5 (stop-usage + alerts; one-budget-per-product gotcha — edit, don't create); CI verifiably running (macOS green on #453, full Linux suite on #454); #454's red `test` = live-prod `/generate-story` 30s-timeout flake (re-run); 4 red Netlify checks/PR = orphaned `reliable-sherbet-2352c4` site (MT-205 sub-item 4, deletion steps given to owner). Causality caveat: jobs resumed BEFORE the budget edit — trigger unconfirmed | [link](docs/sessions/2026-07-16-1755-ffb4.md) |
| 2026-07-16 | 16:05 | c1c0 | session/ci-cost (PR #453 OPEN) + session/prompts (PR #454 OPEN) | **MT-376 root-caused + rubric-transcription prompt fix, all 6 bands**: Actions outage = allowance exhaustion, NOT failed payment ($79.87 gross vs $79.91 included, $0 owed) — `ios-build.yml` on `macos-latest` (10×, meters on public repos) triggered on `lib/**` = $75.39/94% of the month; #453 drops `lib/**` from its paths. Six-band baseline showed every band writing its prompt rubric into prose ("Attempt one: ... It failed." on live prod; "the first escalation"; "his flaw—"); #454 rewords all band rules + renames copyable vocabulary + SILENT SKELETON CHECK + `_strip_attempt_labels()` net; re-gen ×2: 5 bands clean, Adolescent 17→2; backend 1853/1853. OWNER DECISION: wait Jul 31 vs ~$5 spending limit | [link](docs/sessions/2026-07-16-1605-c1c0.md) |
| 2026-07-15 | 15:34 | 6573 | session/uxfix (PR #448 OPEN) | **Fresh-eyes UX walkthrough + 2 prod P0s fixed**: live-prod funnel walk (parent+4yo full COPPA email round-trip, teen, adult) → report `audit-reports/ux-walkthrough-20260715.md`; **P0-1** all web audio dead (CSP `media-src` unset — Read-to-me silent for the picture-book band) fixed in `web/_headers`+`nginx.conf`; **P0-2** async 202 story path NEVER completed (`/task-status` polled with no auth header → perpetual 401 + duplicate Celery re-submits) fixed + regression test; consent-gate copy + voice-badge fixes; MT-370…375 filed (SMS text-plus consent, Sprout art cohesion, punctuation verify, voiceless pre-consent onboarding, first-run simplification decisions, dup-generation guard). **BLOCKER FOUND AT CLOSE: GitHub Actions billing failing account-wide — no CI can run (MT-376)** | [link](docs/sessions/2026-07-15-1534-6573.md) |
| 2026-07-15 | 09:53 | 0b46 | main (PRs #443, #441 merged) | **CI unbroken + A-1 duplicate-build reconciled**: MT-369 CLOSED via #443 (`0492e124`) — prod smoke tests now declare adult age via `PATCH /api/user/<id>/age`, new positive assert pins 403 AGE_REQUIRED for no-age sessions (the standing red `test` job on every PR is green again); PR #441 judged **superset** of the parallel-landed global palette rotation `6f5db470` → rebased keeping per-band `_SENSORY_PALETTE_ROTATION` (+ teen band fixed ≤17, main's TITLE wording kept, black fix), merged `ae71a33a`, 1840/1840 + full CI green; repo back to main-only (4 worktrees/branches removed, all merged remotes confirmed deleted). Parallel session's in-flight audio-ambience work left untouched in the shared checkout | [link](docs/sessions/2026-07-15-0953-0b46.md) |
| 2026-07-14 | 16:12 | 9fa5 | main (PR #437 merged, #438 open) | "Once upon a time" openers shipped + competitive product audit + Family Voice Narration spec | [link](docs/sessions/2026-07-14-1612-9fa5.md) |
<!-- New session-close entries go here. Most recent at top. -->
| 2026-08-14 | 20:49 | 8da9 | main | Apple track: ASC Phase-1 walkthrough start + iOS re-verify | private |
| 2026-08-04 | 15:37 | c62d | fix/responsive-typography-phone-widths | Six-band phone-width layout pass; wizard/reader/button text fixes | private |
| 2026-07-30 | 22:36 | 545c | main | Session-record privacy rework; a11y merges; security alias | private |
| 2026-07-14 | 12:36 | f803 | main (PR #436 merged) | **Outreach day + COPPA flags LIVE**: #436 merged + branch cleanup; MT-320 pivot after Sunkel decline — CMU sweep → **Padron (LCSW) emailed/delivered**, Jones bounce solved (**jacjones@**, cfemail-decode trick documented, v4 resend pending), ITS325 dry, career-services ask staged; beta-tester template + **Bitton invite sent** (prose-critique ask); **MT-310 steps 3–5 DONE — all three COPPA launch-gate flags flipped ON in prod + smoke-verified** (403 AGE_REQUIRED no-age / 200 adult); MT-368 filed (www subdomain dead); post-send health check all green (story 28.5s, Flux 3s, Sentry clean) | [link](docs/sessions/2026-07-14-1236-f803.md) |
| 2026-07-13 | 19:58 | 8823 | main (PR #436 open from session/entitle) | **Housekeeping + STORE-1 phase 2**: deleted 2 merged local branches (rest already gone; remote `chore/ci-artifact-retention` deletion still classifier-blocked); built **PR #436** — Stripe webhook entitlement writes now route through the shared `apply_entitlement()` single-writer (tier/status None = leave-unchanged added; unknown tier hints fail closed; explicit period_end clear preserved). 81 tests + lint green locally, **PR CI fully green** — awaiting merge word. Next code item: MT-338 (own session) | [link](docs/sessions/2026-07-13-1958-8823.md) |
| 2026-07-13 | 18:01 | 4d53 | main (PRs #431, #430 merged; #435 owner-merged) | **Merge-queue cleared to zero** + post-merge cleanup (`feac4bbd`): #435 handoff section closed out (App Store Connect owner reminders preserved), D1/D2 memo duplicate removed, **stale MT-259 Azure launch-gate line fixed in PROJECT_STATUS** (was already owner-resolved 2026-07-12 — briefing false alarm). A personal document was moved out of the public repo to Darcy's Google Drive before push (private memory has the pointer). Remote branch deletion classifier-blocked → 4 merged remote branches + `sw-d1d2` worktree left for housekeeping | [link](docs/sessions/2026-07-13-1801-4d53.md) |
| 2026-07-13 | 16:54 | 7fe1 | main (PRs #432, #434 merged; #433 closed dup) | **MT-350 chunk D shipped** — Apple V2 + Google RTDN S2S notification handlers (renewals/cancels/refunds now update entitlement; dedup + stale-drop + unknown→404-retry; 54 tests). Adversarial review caught **H1**: #429's verify path granted shared receipts to any account → now 409 `receipt_owned_elsewhere`; optional `IOS_BUNDLE_ID` gate added. Also **pillow 12.2.0→12.3.0** (#434, unreds the CVE-audit job on all PRs; parallel-dup #433 closed). **IAP backend CODE-COMPLETE** — remaining = owner store setup + sandbox verify + flag flip | [link](docs/sessions/2026-07-13-1654-7fe1.md) |
| 2026-07-12 | 19:09 | 5f31 | main (PRs #428, #429 merged) | **Land-it session** — rescued 2 unmerged/at-risk threads: (#428) the **local-only, unpushed** egress-scrub safety fix (external-link scrub of `saga_state` + `emotional_arc` on the single-shot story path — rebased off stale base, 22/22 tests) + (#429) the MT-350 **IAP receipt-verification track** from `session/iap` (Apple+Google+annual+erasure, 37 tests, flag stays OFF). Full cleanup → **main-only, no worktrees/branches**. MT-350 chunk D (S2S notifications) + owner store-setup still remain | [link](docs/sessions/2026-07-12-1909-5f31.md) |
| 2026-07-12 | 13:26 | 7f2c | session/iap (pushed, unmerged) + docs on main | MT-259 Azure CLOSED (owner-verified PAYG + Speech S0); MT-350 IAP **receipt-verification path built** — C annual + B Google + A Apple + E erasure + purchase-token keying fix (5 commits, 37 backend tests green, flag still off). **D (S2S notifications) + owner store creds still remain**; PR not yet opened | [link](docs/sessions/2026-07-12-1326-7f2c.md) |
| 2026-07-11 | 18:31 | f804 | main (PR #427 merged) | Post-briefing housekeeping: MANUAL_TASKS reconcile (12-PR queue) + adopted Azure eval harness + **found & fixed MT-363/364 partial gaps**; MT-367 Google→done, MT-259 Azure prod-smoke=azure + F0→S0 launch-risk flagged | [link](docs/sessions/2026-07-11-1831-f804.md) |
| 2026-07-11 | 08:09 | 6334 | main | Cleared the 12-PR queue (#413–#422/#425/#426); 2 conflict resolutions (#422 tests, #425 MANUAL_TASKS); full worktree/branch cleanup → main-only | [link](docs/sessions/2026-07-11-0809-6334.md) |
| 2026-07-10 | 16:56 | 3f61 | session/ops-check (PR #426) | Azure (MT-259) + Play (MT-367) owner-ops status check: Azure still unconverted (~4d to lapse), Play $25 fee PAID → awaiting Google verification | [link](docs/sessions/2026-07-10-1656-3f61.md) |
| 2026-07-10 | 14:30 | 3b29 | main | Google Play Organization account setup walkthrough (console-only) + MT-367 filed | [link](docs/sessions/2026-07-10-1430-3b29.md) |
| 2026-07-10 | 09:44 | 9f2b | main (PR #425 open) | GitHub Actions billing risk analysis for the public→private repo decision; shipped CI trigger trimming (PR #425, unmerged); filed MT-366 | [link](docs/sessions/2026-07-10-0944-9f2b.md) |
| 2026-07-09 | 17:50 | b4b1 | main (PRs #423, #424) | iOS App Store readiness assessment + `IOS_APP_STORE_CRITICAL_PATH.md` (#423) + store privacy-forms draft (MT-145) + MT-365 ElevenLabs under-18 gate fix (#424) | [link](docs/sessions/2026-07-09-1750-b4b1.md) |
| 2026-07-09 | 15:47 | 3a1e | main | MT-359 wave 2 (avatar deadwood) shipped as PR #422 | [link](docs/sessions/2026-07-09-1547-3a1e.md) |
| 2026-07-08 | 17:50 | 0823 | main | PR-queue clear (#412 merged) + MT-362 branch cleanup executed by owner | [link](docs/sessions/2026-07-08-1750-0823.md) |
| 2026-07-08 | 14:03 | 2c74 | main (PR #398) | Rescued stranded PR #398 (annual billing/quota); owner lifted launch pause; full launch-readiness reconciliation → `LAUNCH_CRITICAL_PATH_2026-07-08.md`, MT-363/364 filed | [link](docs/sessions/2026-07-08-1403-2c74.md) |
| 2026-07-08 | 13:26 | d4f7 | main (PRs #404-#408) | Cleared 5-PR queue: #404-#408 merged, #408 MANUAL_TASKS conflict resolved, 3 worktrees removed; MT-362 | [link](docs/sessions/2026-07-08-1326-d4f7.md) |
| 2026-07-08 | 09:14 | 8087 | main (PR #404) | PR-queue clear: #404 merged + MT-348 ID-collision reconciled (→MT-360) | [link](docs/sessions/2026-07-08-0914-8087.md) |
| 2026-07-07 | 21:48 | a91f | main (PR #412, open) | MT-347 red-team re-verify (grooming/abuse/warning-signs) — 4/4 clean; navigated a live parallel-session git collision without touching it | [link](docs/sessions/2026-07-07-2148-a91f.md) |
| 2026-07-07 | 21:13 | bce3 | main (PRs #408/#410/#411) | Unfinished-features audit → MT-350..359; deadwood wave 1; Cluster C salvage quests | [link](docs/sessions/2026-07-07-2113-bce3.md) |
| 2026-07-07 | 21:12 | 0207 | main (PR #409) | Screen-free bedtime real: wakelock+dim, interactive path contract fix, bedtime offline scaffolds (MT-361) | [link](docs/sessions/2026-07-07-2112-0207.md) |
| 2026-07-07 | 20:07 | 0bdc | main (PR #403) | Explorer SEL REAL-LIFE ECHO approved + shipped (MT-331→MT-360) | [link](docs/sessions/2026-07-07-2007-0bdc.md) |
| 2026-07-07 | 19:22 | 1529 | main (PRs #404-#407) | Meditation survey → 4 PRs: ledger flip, teen Reset kit, bedtime breath, dead-code sweep | [link](docs/sessions/2026-07-07-1922-1529.md) |
| 2026-07-07 | 18:22 | 63c2 | main (PR #402) | Red-team fixes: MT-336 P0s + MT-337 decided+shipped (#402) | [link](docs/sessions/2026-07-07-1822-63c2.md) |
| 2026-07-07 | 17:29 | be06 | main (PR #401) | Wave 2: weekly parent recap built inline + merged #401 | [link](docs/sessions/2026-07-07-1729-be06.md) |
| 2026-07-07 | 17:28 | fbfc | main | Repo cleanup: merged branches, prune, gitignore audit shots | [link](docs/sessions/2026-07-07-1728-fbfc.md) |
| 2026-07-07 | 14:41 | 5fe5 | main | Monetization wave 1: funnel + PDF export + gift subs (3 PRs merged) | [link](docs/sessions/2026-07-07-1441-5fe5.md) |
| 2026-07-07 | 14:39 | 6bb4 | main | Briefing + PR-queue no-op (parallel session already merged #390/#394/#396) | [link](docs/sessions/2026-07-07-1439-6bb4.md) |
| 2026-07-07 | 14:02 | bd5b | main | PR-queue clear: #390/#394 merged + post-hoc reviews + MT renumber | [link](docs/sessions/2026-07-07-1402-bd5b.md) |
| 2026-07-07 | 13:36 | eeb5 | main | All-band story audit + no-screen verify → 4 PRs merged (#392/#393/#394/#396) | [link](docs/sessions/2026-07-07-1336-eeb5.md) |
| 2026-07-07 | 12:23 | 7231 | main (PRs #395/#398) | Pricing decided + monetization shipped; #398 stranded-commit PR open | [link](docs/sessions/2026-07-07-1223-7231.md) |
| 2026-07-07 | 11:18 | c071 | main | Bedtime screen-free overhaul — PR #391 merged | [link](docs/sessions/2026-07-07-1118-c071.md) |
| 2026-07-07 | 11:16 | a493 | main | Per-age-band illustration styles + companion visuals (PR #389) | [link](docs/sessions/2026-07-07-1116-a493.md) |
| 2026-07-07 | 11:07 | 342a | main | Explorer SEL prompt-spine design (Fable) — MT-331 review gate | [link](docs/sessions/2026-07-07-1107-342a.md) |
| 2026-07-07 | 10:36 | 7907 | session/safety-redteam | Adversarial red-team story-gen: 4 HIGH (gate/grooming/abuse/egress) — MT-336/337 | [link](docs/sessions/2026-07-07-1036-7907.md) |
| 2026-07-07 | 08:28 | e937 | main | Clinician packet completed + Privacy Policy v3 drafted | [link](docs/sessions/2026-07-07-0828-e937.md) |
| 2026-07-07 | 08:14 | 511e | main | Triaged + cleaned C:/dev scratch folders (none were app work) | [link](docs/sessions/2026-07-07-0814-511e.md) |
| 2026-07-07 | 06:39 | d0ec | main | Briefing-only no-op; noted PR #388 (crisis-detection) merged by parallel session | [link](docs/sessions/2026-07-07-0639-d0ec.md) |
| 2026-07-07 | 06:39 | 4190 | main | MT-327 crisis-detection HIGH closed (PR #388) + stranded-branch triage | [link](docs/sessions/2026-07-07-0639-4190.md) |
| 2026-07-06 | 10:00 | d519 | main | Prompt ceiling pass #2 merged (#386) + launch critical-path brief | [link](docs/sessions/2026-07-06-1000-d519.md) |
| 2026-07-06 | 09:48 | e964 | main | MT-327 fully closed: 3 PRs merged + Cluster B consent hardening (PR #387) | [link](docs/sessions/2026-07-06-0948-e964.md) |
| 2026-07-05 | 23:28 | cd8f | main | MT-327 remediation: no-Gemini-for-minors sweep (PR #385) | [link](docs/sessions/2026-07-05-2328-cd8f.md) |
| 2026-07-05 | 22:43 | 2f64 | main | ultracode launch-readiness audit (5 blockers) | [link](docs/sessions/2026-07-05-2243-2f64.md) |
| 2026-07-05 | 12:43 | 4113 | main | Six Hats UX audit — all 5 age bands live on prod + fix plan | [link](docs/sessions/2026-07-05-1243-4113.md) |
| 2026-07-05 | 07:34 | d9a5 | main (PR #384) | Robotic voice on consent-CTA Pick-Hero screen fixed; boy/girl images ruled non-bug | [link](docs/sessions/2026-07-05-0734-d9a5.md) |
| 2026-07-04 | 21:30 | 0f66 | main | Warm welcome-greeting fix: prewarm greeting strings (PR #383) | [link](docs/sessions/2026-07-04-2130-0f66.md) |
| 2026-07-04 | 19:50 | 8beb | main | PR merge-queue clear + Sprout modes rescue + Chunk-2 COPPA ops/code | [link](docs/sessions/2026-07-04-1950-8beb.md) |
| 2026-07-04 | 18:09 | ac54 | main | MT-320 clinician outreach built end-to-end; Sunkel email staged | [link](docs/sessions/2026-07-04-1809-ac54.md) |
| 2026-07-04 | 12:01 | 0ddf | main | Six-hats review + subtraction sprint + CI red fix | [link](docs/sessions/2026-07-04-1201-0ddf.md) |
| 2026-07-04 | 11:57 | 405f | main | COPPA amended-Rule gap analysis + distribution strategy + prompt ceiling pass (PRs #372/#373) | [link](docs/sessions/2026-07-04-1157-405f.md) |
| 2026-07-04 | 09:49 | 03bb | main | Marketing plan + landing-page copy (first marketing session) | [link](docs/sessions/2026-07-04-0949-03bb.md) |
| 2026-07-03 | 19:14 | 0278 | fix/image-name-pseudonymize | MT-311#16 shipped (name pseudonymization) + PR #364 merged + CI fixes | [link](docs/sessions/2026-07-03-1914-0278.md) |
| 2026-07-03 | 15:48 | 63cd | session/compliance-docs | MT-318 OpenAI DPA/ZDR checklist + SEL framework alignment | [link](docs/sessions/2026-07-03-1548-63cd.md) |
| 2026-07-03 | 13:58 | 88cb | fix/image-name-pseudonymize | Google Play org-account setup (paused at $25 fee) + honest 6-hats money assessment; no code | [link](docs/sessions/2026-07-03-1358-88cb.md) |
| 2026-07-02 | 20:58 | de9f | main | Diagnosed Max token crunch + token-discipline in /start-session | [link](docs/sessions/2026-07-02-2058-de9f.md) |
| 2026-07-02 | 16:51 | d108 | main | Dependabot sweep (9 PRs) + competitive/SEL/COPPA deep-research; AI-training consent settled; MT-318 | [link](docs/sessions/2026-07-02-1651-d108.md) |
| 2026-07-02 | 10:14 | 904f | main | Advisory: Google Play dev-account verification guidance (identity gate, org-vs-personal, proof-of-address) | [link](docs/sessions/2026-07-02-1014-904f.md) |
| 2026-07-01 | 18:40 | 1909 | main | Launch triage: 18 PRs merged, MT-311 COPPA age-sync + IAP item 1 shipped, app-store critical path mapped | [link](docs/sessions/2026-07-01-1840-1909.md) |
| 2026-07-01 | 12:54 | ebd5 | session/crux-client | Crux Choice client (MT-258) shipped behind OFF flag; PR #359 | [link](docs/sessions/2026-07-01-1254-ebd5.md) |
| 2026-07-01 | 11:24 | a2eb | main | Merged 6 stranded PRs (#339-344) + prod-verify sweep (CF-IPCountry gap) + #358 interactive fail-closed | [link](docs/sessions/2026-07-01-1124-a2eb.md) |
| 2026-07-01 | 10:03 | d119 | main | Overnight 5-agent sweep: 6 PRs built+merged (#339-#344) — moderator→OpenAI, crisis surfaces, erasure, analytics, antihero substance rule | [link](docs/sessions/2026-07-01-1003-d119.md) |
| 2026-06-30 | 21:42 | f1f9 | main | Merged all 5 stranded safety-audit worktrees (#320/#321/#332/#335/#336) + fixed main lint & 2 hidden regressions | [link](docs/sessions/2026-06-30-2142-f1f9.md) |
| 2026-06-29 | 18:05 | 1c86 | session/audit-fixes | Scenario/quality audit + fixes; P0 Pick-a-Path Gemini ToS | [link](docs/sessions/2026-06-29-1805-1c86.md) |
| 2026-06-29 | 18:01 | 8d69 | fix/gemini-byok-consent-guard | Shipped MT-306/307 leftovers; merged #319+#337 (MT-306 ID-collision fix) | [link](docs/sessions/2026-06-29-1801-8d69.md) |
| 2026-06-29 | 17:15 | 31a0 | fix/gemini-byok-consent-guard | CAADCA/GDPR privacy defaults + crisis-input distress scan | [link](docs/sessions/2026-06-29-1715-31a0.md) |
| 2026-06-29 | 17:11 | 32b8 | session/legal-fixes | Legal-liability audit + Phase 1 COPPA + Phase 2.1 self-harm detection | [link](docs/sessions/2026-06-29-1711-32b8.md) |
| 2026-06-29 | 07:11 | 22b5 | main | Backlog blitz: 6-band audit + 13 PRs merged | [link](docs/sessions/2026-06-29-0711-22b5.md) |
| 2026-06-28 | 11:26 | 6567 | fix/gemini-byok-consent-guard | No silent direct-Gemini for kids; gate+disclose BYOK | [link](docs/sessions/2026-06-28-1126-6567.md) |
| 2026-06-27 | 11:37 | 7527 | main | Git maintenance: 24 fossil branches cleared, repo main-only | [link](docs/sessions/2026-06-27-1137-7527.md) |
| 2026-06-26 | 16:57 | 2e87 | main | Teen Be-a-Hero tone branch shipped + worktree cleanup | [link](docs/sessions/2026-06-26-1657-2e87.md) |
| 2026-06-24 | 20:11 | 275a | main | MT-296..302 audit backlog cleared (5 PRs) + 266c packet | [link](docs/sessions/2026-06-24-2011-275a.md) |
| 2026-06-22 | 17:18 | 054d | main | OpenAI avatar migration + Gemini retirement, Dependabot HIGH, MT-290 | [link](docs/sessions/2026-06-22-1718-054d.md) |
| 2026-06-21 | 07:50 | 2a7d | main | Reconciled #292 w/ MT-266a mandate; merged #292+#296 | [link](docs/sessions/2026-06-21-0750-2a7d.md) |
| 2026-06-21 | 07:48 | 3058 | main | MT-263 art replaced + MT-266a secret-care mandate; MT-266b dup-discarded vs #292 | [link](docs/sessions/2026-06-21-0748-3058.md) |
| 2026-06-21 | 07:48 | ccee | main | UX-audit sweep: 5 fixes merged + gender picker Boy/Girl-only | [link](docs/sessions/2026-06-21-0748-ccee.md) |
| 2026-06-19 | 08:29 | a784 | main | MT-266(a+b) #292 + MT-269 #296 shipped; MT-268 art-blocked | [link](docs/sessions/2026-06-19-0829-a784.md) |
| 2026-06-16 | 15:19 | 41fd | main | Robin cross = intentional memorial; MT-264 reclassified wontfix | [link](docs/sessions/2026-06-16-1519-41fd.md) |
| 2026-06-15 | 22:10 | 3799 | main | MT-254 dup-build (#282) closed redundant; verified shipped #279/#286 | [link](docs/sessions/2026-06-15-2210-3799.md) |
| 2026-06-15 | 17:37 | b3be | main | Resolved MT-254 dup-build, drove #279 to merge, +MT-260 harness | [link](docs/sessions/2026-06-15-1737-b3be.md) |
| 2026-06-15 | 15:01 | 0447 | session/u13gate | Under-13 ElevenLabs gate + Azure-accurate disclosure salvaged → #281 merged; closed #275 (MT-261) | [link](docs/sessions/2026-06-15-1501-0447.md) |
| 2026-06-15 | 06:40 | 9128 | worktree-story-notes-mt254 | Built entire MT-254 Story Notes transparency layer (PR #279, 8 commits) | [link](docs/sessions/2026-06-15-0640-9128.md) |
| 2026-06-14 | 18:45 | a3af | main | MT-248 launch-gate FULLY cleared — Azure AI Speech narration LIVE, /tts/transcribe deleted | [link](docs/sessions/2026-06-14-1845-a3af.md) |
| 2026-06-14 | 18:14 | b816 | main (worktree) | Greened #273 lint gate (Black + flake8) + merged #273 (Crux backend) & #274 (Adventurer/Explorer saga) | [link](docs/sessions/2026-06-14-1814-b816.md) |
| 2026-06-14 | 12:08 | 7092 | saga-loop-adventurer | Adolescent antihero overhaul (#269-271) + Crux Choice backend (#273) + saga loop→Adventurer/Explorer (#274) | [link](docs/sessions/2026-06-14-1208-7092.md) |
| 2026-06-14 | 12:08 | f312 | main | Story-gen LIVE off Gemini → OpenAI GPT-5 mini + EMOTIONAL HEART prompt | [link](docs/sessions/2026-06-14-1208-f312.md) |
| 2026-06-14 | 12:08 | 4022 | saga-loop-adventurer | Designed Story Notes age-gated transparency layer (MT-254) from ethics-class thread | [link](docs/sessions/2026-06-14-1208-4022.md) |
| 2026-06-12 | 14:07 | 6563 | main (PR #266) | Reconciled+shipped direct-Anthropic claude story-gen provider (#266); lockfile pinned; openai-provider analyzed | [link](docs/sessions/2026-06-12-1407-6563.md) |
| 2026-06-10 | 19:57 | 1ed9 | main | Adolescent antihero saga shipped end-to-end (#263/#264/#265/#267) + UX audit fixes | [link](docs/sessions/2026-06-10-1957-1ed9.md) |
| 2026-06-09 | 23:00 | b559 | main | Git reconcile + 7-branch cleanup; MT-248 launch-gate research + Chunk-A validation | [link](docs/sessions/2026-06-09-2300-b559.md) |
| 2026-06-09 | 07:22 | 9ba3 | main | Solo blitz: 5 PRs merged (a11y/brand/chips/rubric/spotlight) + 9 decisions + MT-137 Gemini/ElevenLabs launch-gate finding | [link](docs/sessions/2026-06-09-0722-9ba3.md) |
| 2026-06-08 | 18:47 | caba | main | Solo-backlog sweep: MT-239 iOS fix (#254) + docs-rescue/A/B (#256) + MT-235 Phase 2 saga (#257) + retired adv-craft branch | [link](docs/sessions/2026-06-08-1847-caba.md) |
| 2026-06-08 | 02:09 | 6a13 | adventurer-craft-fixes | GIT_MAINTENANCE (27 fossils deleted, MT-229) + cleared 4-PR queue #243/#249/#252/#242 | [link](docs/sessions/2026-06-08-0209-6a13.md) |
| 2026-06-08 | 01:36 | 93f8 | adventurer-craft-fixes | Age-band scene art (#243) + Creator polish (#249) + Hero Saga superhero (#252) | [link](docs/sessions/2026-06-08-0136-93f8.md) |
| 2026-06-08 | 01:35 | bca2 | session/audits | Audits 01+13 + erasure fix + launch tracker + continuity kit | [link](docs/sessions/2026-06-08-0135-bca2.md) |
| 2026-06-07 | 15:36 | 67e7 | adventurer-craft-fixes | Boundary-skills feature: prompt→plan→2 approved examples→Phase 1 (#253 merged) | [link](docs/sessions/2026-06-07-1536-67e7.md) |
| 2026-06-07 | 15:00 | eb2e | adventurer-craft-fixes | Companion overhaul: kill My Pet/Human + unify Add-a-Person + grown-up photos + premium signal (PR #246) | [link](docs/sessions/2026-06-07-1500-eb2e.md) |
| 2026-06-07 | 13:38 | 2af4 | main (PR #250) | Continuation of a316: Slack alerting deferred → GitHub failure emails | [link](docs/sessions/2026-06-07-1338-2af4.md) |
| 2026-06-07 | 13:12 | 69f9 | adventurer-craft-fixes | Adventurer companions grid polish (#244, merged): robin→bottom, Nyx restyle, atlas/kodiak retighten | [link](docs/sessions/2026-06-07-1312-69f9.md) |
| 2026-06-07 | 13:10 | a316 | main (PR #241,#245) | COPPA gate MT-213 verified live + MT-214/226 confirmed + MT-225 Slack v3 | [link](docs/sessions/2026-06-07-1310-a316.md) |
| 2026-06-07 | 13:10 | c9ad | adventurer-craft-fixes | Git maint + main branch-protection + fossil-branch audit (#247) | [link](docs/sessions/2026-06-07-1310-c9ad.md) |
| 2026-06-07 | 00:23 | 6a94 | adventurer-craft-fixes | Cleared 99a5 backlog: integration #237 + hono #239 + age-pill #235 | [link](docs/sessions/2026-06-07-0023-6a94.md) |
| 2026-06-06 | 23:30 | d5b0 | adventurer-craft-fixes | Recover villains #234 + MT-228 gate #238 + superhero custom-idea #240 | [link](docs/sessions/2026-06-06-2330-d5b0.md) |
| 2026-06-06 | 14:00 | 99a5 | adventurer-craft-fixes | Adventurer loot-card loading + real-gen E2E + consent fix | [link](docs/sessions/2026-06-06-1400-99a5.md) |
| 2026-06-06 | 12:10 | 62a2 | adventurer-craft-fixes | no-story RCA: superhero fixes #229 + gen-crash fix #233 merged | [link](docs/sessions/2026-06-06-1210-62a2.md) |
| 2026-06-06 | 10:19 | 6441 | adventurer-craft-fixes | Setting-tile + companion-framing fixes + app-wide invisible-input sweep | [link](docs/sessions/2026-06-06-1019-6441.md) |
| 2026-06-06 | 06:55 | a5f7 | adventurer-craft-fixes | Adventurer hero-name fixes shipped; villain overhaul designed+started, hit parallel write-race | [link](docs/sessions/2026-06-06-0655-a5f7.md) |
| 2026-06-05 | 16:12 | 1e9e | main (PRs) | Audit 14 + MT-221 + Companion Powers + MT-216 perf+nits | [link](docs/sessions/2026-06-05-1612-1e9e.md) |
| 2026-06-05 | 07:59 | 980d | main | Backup outage fix + pyjwt/aiohttp CVEs + Cloudflare cutover prep | [link](docs/sessions/2026-06-05-0759-980d.md) |
| 2026-06-03 | 23:35 | 5807 | session/triage-docs | PR triage: merged #206/#209/#205/#188 (+2 review-nit fixes), closed #182 | [link](docs/sessions/2026-06-03-2335-5807.md) |
| 2026-06-03 | 12:27 | 5623 | main | Audit #11 + CQ-01/02/04 fixes + 61 a11y labels merged | [link](docs/sessions/2026-06-03-1227-5623.md) |
| 2026-06-03 | 09:55 | 9794 | session/finops | FinOps audit: F-01/02/04/05 fixed, F-03 verified (PR #205) | [link](docs/sessions/2026-06-03-0955-9794.md) |
| 2026-06-03 | 06:26 | 3211 | main | Overnight sweep: fixed 5-day backup outage (#207) + 3 backlog code PRs (#206/#209/#210) + corrected stale MT-219/207 | [link](docs/sessions/2026-06-03-0626-3211.md) |
| 2026-06-02 | 13:27 | a7e6 | main | GIT_MAINTENANCE: branch cleanup 13→6, rescued 4cd2 record, discarded pubspec.lock churn | [link](docs/sessions/2026-06-02-1327-a7e6.md) |
| 2026-06-01 | 22:03 | 6b74 | main | Fixed broken main (Flutter compile #189) + CI analyze gate (#204) | [link](docs/sessions/2026-06-01-2203-6b74.md) |
| 2026-06-01 | 22:03 | 4825 | main | Merged git-guard hook (#183) + closed redundant deploy PR (#180) + removed csp-fix worktree | [link](docs/sessions/2026-06-01-2203-4825.md) |
| 2026-06-01 | 21:35 | 0d6c | main | Worktree-per-session tooling + start-session (PR #191) | [link](docs/sessions/2026-06-01-2135-0d6c.md) |
| 2026-06-01 | 18:18 | 87b2 | main | Audit 09 Criticals: pricing + MT-204 Pages flavor fix + COPPA gates; merged #186 | [link](docs/sessions/2026-06-01-1818-87b2.md) |
| 2026-06-01 | 18:17 | b34b | main | MT-208: clean-extracted #171 uniques → PR #185 merged, #171 closed | [link](docs/sessions/2026-06-01-1817-b34b.md) |
| 2026-06-01 | 18:12 | 3830 | feat/superhero-chunk-c | C4 Adventurer nemesis backend fix (PR #188) + UX Audit 09 | [link](docs/sessions/2026-06-01-1812-3830.md) |
| 2026-06-01 | 18:02 | 4c8f | main (PR #181) | Finished Superhero Chunk C (C2/C4) + merged PR #181 + worktree cleanup | [link](docs/sessions/2026-06-01-1802-4c8f.md) |
| 2026-05-31 | 22:40 | f3f4 | main | Cleared Adventurer queue (5 PRs) + #179 CSP prod fix + multi-agent worktree setup | [link](docs/sessions/2026-05-31-2240-f3f4.md) |
| 2026-05-31 | 22:37 | bc9b | chore/git-guard-hook | CI triage → delete redundant deploy workflow + git-guard hook | [link](docs/sessions/2026-05-31-2237-bc9b.md) |
| 2026-05-31 | 22:33 | 1eea | feat/superhero-mode-improvements | Superhero Mode overhaul + avatar→hero portrait → PR #181 | [link](docs/sessions/2026-05-31-2233-1eea.md) |
| 2026-05-31 | 14:39 | e178 | main | Cloudflare architecture orientation + memory fix | [link](docs/sessions/2026-05-31-1439-e178.md) |
| 2026-05-31 | 14:18 | 4cd2 | main | Greened main CI (#177) + removed redundant deploy workflow (#178) + Railway prod triage | [link](docs/sessions/2026-05-31-1418-4cd2.md) |
| 2026-05-31 | 09:35 | dfa7 | main | 24 PRs merged, 4 prod bugs fixed, Adventurer audit sweep 5 PRs in flight | [link](docs/sessions/2026-05-31-0935-dfa7.md) |
| 2026-05-31 | 07:39 | 1262 | main | Frontend host Netlify→Cloudflare Pages + CYOA TTS fix | [link](docs/sessions/2026-05-31-0739-1262.md) |
| 2026-05-31 | 07:38 | 27aa | feat-adventurer-9-12 | Adventurer 9-12: Superhero Mode + feelings curriculum | [link](docs/sessions/2026-05-31-0738-27aa.md) |
| 2026-05-30 | 11:07 | 433d | mt-099-bookfeel | MT-099 Open Book reader refactor (Direction B) → PR #164 | [link](docs/sessions/2026-05-30-1107-433d.md) |
| 2026-05-28 | 13:52 | 875f | reliability-hardening | MT-187 F-01 prompt-template versioning shipped + prod Postgres migrated | [link](docs/sessions/2026-05-28-1352-875f.md) |
| 2026-05-28 | 13:52 | 7c1c | reliability-hardening | Perf: PERF-01 streaming backend + PERF-04 cancel foundation | [link](docs/sessions/2026-05-28-1352-7c1c.md) |
| 2026-05-28 | 13:52 | 83c8 | reliability-hardening | Backup workflow hardened + R2 walkthrough; P1/P2 path corrected | [link](docs/sessions/2026-05-28-1352-83c8.md) |
| 2026-05-27 | 22:44 | 275f | mt-187-prompt-versioning | MT-144 keystore runbook delivered; MT-175 AAB re-verified at 82MB | [link](docs/sessions/2026-05-27-2244-275f.md) |
| 2026-05-27 | 07:22 | 28f5 | reliability-hardening | LinkedIn Company Page kit for Once Upon YOUR Child (no code) | [link](docs/sessions/2026-05-27-0722-28f5.md) |
| 2026-05-27 | 07:22 | 9c35 | reliability-hardening | Briefing + A11Y-LTR-03 inspect — work absorbed by parallel | [link](docs/sessions/2026-05-27-0722-9c35.md) |
| 2026-05-27 | 07:18 | a339 | main | Triage stranded parallel-session work + rescue commit | [link](docs/sessions/2026-05-27-0718-a339.md) |
| 2026-05-27 | 07:14 | d003 | reliability-hardening | Audit 05 end-to-end: harness, run, RCAs, fixes, rubric finding | [link](docs/sessions/2026-05-27-0714-d003.md) |
| 2026-05-24 | 21:30 | 0db7 | reliability-hardening | Audit 05 Superhero prompt fixes + Python 3.13 TTS verify | [link](docs/sessions/2026-05-24-2130-0db7.md) |
| 2026-05-22 | 15:18 | 1738 | main | WCAG 2.2 AA a11y audit + remediation Phases 0-1 | [link](docs/sessions/2026-05-22-1518-1738.md) |
| 2026-05-22 | 15:18 | 2102 | reliability-hardening | Verify Gemini TTS fallback locally (MT-178) | [link](docs/sessions/2026-05-22-1518-2102.md) |
| 2026-05-22 | 12:49 | 6360 | main | MT-174 brand verify surfaced + fixed P0 custom-domain outage (CSP fonts + CORS) | [link](docs/sessions/2026-05-22-1249-6360.md) |
| 2026-05-22 | 12:41 | 653a | main | Strip BOM from WebP-rewrite dart files; delegate MT-173/178 | [link](docs/sessions/2026-05-22-1241-653a.md) |
| 2026-05-22 | 11:59 | 85c1 | main | WebP Illustration Asset Conversion and Play Store Size Optimization | [link](docs/sessions/2026-05-22-1159-85c1.md) |
| 2026-05-22 | 11:58 | a60f | main | App summary + launch-blocker rundown + README staleness fixes | [link](docs/sessions/2026-05-22-1158-a60f.md) |
| 2026-05-22 | 01:26 | dacf | main | Helped answer Chrome Built-in AI EPP Pulse Check survey | [link](docs/sessions/2026-05-22-0126-dacf.md) |
| 2026-05-22 | 01:21 | 35d1 | main | P0 fix: nginx CSP missing gstatic blanked prod 2 days | [link](docs/sessions/2026-05-22-0121-35d1.md) |
| 2026-05-22 | 01:20 | b817 | main | Gemini Flash TTS overflow tier + MT-170/179/180 follow-ups | [link](docs/sessions/2026-05-22-0120-b817.md) |
| 2026-05-21 | 10:39 | 3de3 | main | Shared close-session + start-session skill text for Antigravity port | [link](docs/sessions/2026-05-21-1039-3de3.md) |
| 2026-05-21 | 09:24 | 4efd | main | Antigravity hand-off: test fixes + stt migration + idna CVE bump | [link](docs/sessions/2026-05-21-0924-4efd.md) |
| 2026-05-19 | 23:15 | e02c | main | MT-169 fix absorbed by parallel race; MT-113 routine 3× uncommitted | [link](docs/sessions/2026-05-19-2315-e02c.md) |
| 2026-05-19 | 23:15 | 1b55 | main | Briefing only; AI quality audit halted at clarifying-questions step | [link](docs/sessions/2026-05-19-2315-1b55.md) |
| 2026-05-19 | 23:05 | d4b8 | main | wire chrome-devtools-mcp + smoke test surfaces prod outage | [link](docs/sessions/2026-05-19-2305-d4b8.md) |
| 2026-05-19 | 23:05 | 45c8 | main | Domain + email + Google Cloud Program $350k AI-tier application submitted | [link](docs/sessions/2026-05-19-2305-45c8.md) |
| 2026-05-19 | 23:03 | 5de1 | main | Legal & distribution readiness audit 04 + "Once Upon YOUR Child" brand sweep | [link](docs/sessions/2026-05-19-2303-5de1.md) |
| 2026-05-19 | 23:02 | c7b7 | main | R8 dry-run: 384 MB asset bloat; built WebP toolchain | [link](docs/sessions/2026-05-19-2302-c7b7.md) |
| 2026-05-19 | 17:07 | 5e43 | main | MT-169 fail-CLOSED illustration-quota cost breaker on Redis outage | [link](docs/sessions/2026-05-19-1707-5e43.md) |
| 2026-05-19 | 17:07 | b617 | main | MT-168 Playwright partial-verify; blocked on Railway outage | [link](docs/sessions/2026-05-19-1707-b617.md) |
| 2026-05-19 | 16:23 | 22c7 | main | MT-113 reopen — raise hour/day rate-limit above monthly quota | [link](docs/sessions/2026-05-19-1623-22c7.md) |
| 2026-05-19 | 16:19 | 4449 | main | Six Hats security audit 03 + full Critical/High/Medium/Low remediation | [link](docs/sessions/2026-05-19-1619-4449.md) |
| 2026-05-19 | 15:02 | 4c3e | main | Fix backend crash restart + story-gen List cast TypeError | [link](docs/sessions/2026-05-19-1502-4c3e.md) |
| 2026-05-19 | 15:01 | 8781 | main | Triage stranded uncommitted backend work (1 commit + cleanup) | [link](docs/sessions/2026-05-19-1501-8781.md) |
| 2026-05-19 | 14:35 | 74a8 | main | MT-139 per-band prod verification sweep (14 closed) | [link](docs/sessions/2026-05-19-1435-74a8.md) |
| 2026-05-19 | 14:31 | 1083 | main | Reword hero-creator greeting; diagnose robotic TTS voice | [link](docs/sessions/2026-05-19-1431-1083.md) |
| 2026-05-19 | 14:31 | 2020 | main | MT-129 fix — story illustrations now match the created avatar | [link](docs/sessions/2026-05-19-1431-2020.md) |
| 2026-05-19 | 13:58 | 9a8d | main | MT-156 resolved — mt150_smoke.py tracked under backend/tests/smoke/ | [link](docs/sessions/2026-05-19-1358-9a8d.md) |
| 2026-05-19 | 13:53 | 8086 | main | Content-safety audit (Six Hats) + Critical/High mod fixes | [link](docs/sessions/2026-05-19-1353-8086.md) |
| 2026-05-19 | 08:16 | 8e76 | main | MT-154/155 interactive-story + avatar fixes; MT-150 monetization verified | [link](docs/sessions/2026-05-19-0816-8e76.md) |
| 2026-05-18 | 16:38 | 7ce6 | main | Closed MT-153 — SECRET_KEY verified on story-weaver-app backend | [link](docs/sessions/2026-05-18-1638-7ce6.md) |
| 2026-05-18 | 16:37 | 3dfa | main | MT-149 cost-reduction deploy smoke test (passed) | [link](docs/sessions/2026-05-18-1637-3dfa.md) |
| 2026-05-18 | 14:48 | c859 | main | Investigated uncommitted coloring-chip (already committed by parallel session) | [link](docs/sessions/2026-05-18-1448-c859.md) |
| 2026-05-18 | 13:54 | 61aa | main | Restored orphaned coloring-page UI entry point (end-page chip) | [link](docs/sessions/2026-05-18-1354-61aa.md) |
| 2026-05-18 | 12:28 | 6774 | main | P0 production unblank + MT-141/147/151 + celery-beat live | [link](docs/sessions/2026-05-18-1228-6774.md) |
| 2026-05-17 | 22:33 | ed03 | main | Security Medium+Low batch, M-8 re-scope, one-free-avatar feat | [link](docs/sessions/2026-05-17-2233-ed03.md) |
| 2026-05-17 | 22:07 | ddd2 | main | Cost-reduction wins shipped to production | [link](docs/sessions/2026-05-17-2207-ddd2.md) |
| 2026-05-17 | 21:49 | 9cc7 | main | Railway deploy of Phase 4 + Celery -B revert | [link](docs/sessions/2026-05-17-2149-9cc7.md) |
| 2026-05-17 | 21:42 | 149a | feat/cost-reduction | Free Edge TTS narration fallback + prod deploy crash fix | [link](docs/sessions/2026-05-17-2142-149a.md) |
| 2026-05-17 | 20:31 | ebfe | main | Legal & Compliance audit — Phases 1-4 remediation | [link](docs/sessions/2026-05-17-2031-ebfe.md) |
| 2026-05-17 | 09:52 | 0fe7 | main | Backlog code-task batch + MANUAL_TASKS.md cleanup | [link](docs/sessions/2026-05-17-0952-0fe7.md) |
| 2026-05-17 | 09:12 | ed41 | main | Git maintenance: branch cleanup + stale-PR triage | [link](docs/sessions/2026-05-17-0912-ed41.md) |
| 2026-05-17 | 08:55 | 3315 | main | Six Hats security audit + P0/P1 remediation shipped | [link](docs/sessions/2026-05-17-0855-3315.md) |
| 2026-05-17 | 07:51 | bc1a | main | 6-8 story-type wizard UX rework + COPPA debug-skip | [link](docs/sessions/2026-05-17-0751-bc1a.md) |
| 2026-05-16 | 16:17 | a4e1 | main | Reviewed P0/P1 security remediation; reverted H-5 BYOK regression | [link](docs/sessions/2026-05-16-1617-a4e1.md) |
| 2026-05-16 | 16:17 | 41cd | main | MT-129 fix + credential audit + a11y Playwright harness | [link](docs/sessions/2026-05-16-1617-41cd.md) |
| 2026-05-16 | 14:21 | 4237 | main | Railway DB endpoint Q&A (no code changes) | [link](docs/sessions/2026-05-16-1421-4237.md) |
| 2026-05-16 | 14:20 | 2d29 | main | No-op re-close after b95a (no new work) | [link](docs/sessions/2026-05-16-1420-2d29.md) |
| 2026-05-16 | 13:53 | b95a | main | MT-131 Cloudflare image migration shipped + MT-132 orphaned fix landed | [link](docs/sessions/2026-05-16-1353-b95a.md) |
| 2026-05-16 | 13:11 | 369d | main | MT-128 verify, reader-exit fix, per-hero Continue affordance | [link](docs/sessions/2026-05-16-1311-369d.md) |
| 2026-05-16 | 13:11 | d03f | main | Commit parallel-session per-hero Continue affordance | [link](docs/sessions/2026-05-16-1311-d03f.md) |
| 2026-05-16 | 12:38 | ec15 | main | Explorer-band Robin companion placeholder (404 asset) fix | [link](docs/sessions/2026-05-16-1238-ec15.md) |
| 2026-05-16 | 12:37 | bac9 | main | Triaged + committed parallel-session Sprout-reliability sweep | [link](docs/sessions/2026-05-16-1237-bac9.md) |
| 2026-05-15 | 20:57 | 295d | main | Stripe key warning triage + subscription overflow fix | [link](docs/sessions/2026-05-15-2057-295d.md) |
| 2026-05-15 | 20:20 | 0e2f | main | MT-126 re-verify + MT-127 fix + MT-122 R2 backup shipped + MT-123/124 closed | [link](docs/sessions/2026-05-15-2020-0e2f.md) |
| 2026-05-15 | 17:21 | b667 | main | Kids-reader UX: egg cracks, illustration persistence, resume/continue | [link](docs/sessions/2026-05-15-1721-b667.md) |
| 2026-05-15 | 08:24 | 32c7 | main | No-op close (no work since 5f6d) | [link](docs/sessions/2026-05-15-0824-32c7.md) |
| 2026-05-14 | 23:46 | 5f6d | main | No-op re-close after da24 (no new work) | [link](docs/sessions/2026-05-14-2346-5f6d.md) |
| 2026-05-14 | 23:33 | da24 | main | MT-125 + MT-126 (themes-recall actually wired) + MT-127 filed | [link](docs/sessions/2026-05-14-2333-da24.md) |
| 2026-05-14 | 22:59 | 358e | main | Multi-agent follow-through: MT-118/119/121/104 all closed + verified | [link](docs/sessions/2026-05-14-2259-358e.md) |
| 2026-05-14 | 21:41 | a1bf | main | Close MT-115 + MT-116; delegated themes-recall + prod migration | [link](docs/sessions/2026-05-14-2141-a1bf.md) |
| 2026-05-14 | 21:36 | 282e | main | Multi-agent Phase 1 sweep: 7 MTs shipped + MT-104 plan + MT-107 verify | [link](docs/sessions/2026-05-14-2136-282e.md) |
| 2026-05-14 | 14:30 | eed1 | main | Themes feature ship + Postgres provisioning | [link](docs/sessions/2026-05-14-1430-eed1.md) |
| 2026-05-14 | 14:11 | 302f | main | GitHub PAT placement + production schema verify for themes migration | [link](docs/sessions/2026-05-14-1411-302f.md) |
| 2026-05-13 | 18:30 | d1e9 | main | Delegate triage backlog, MT-087 live verify surfaces rate-limit shadowing | [link](docs/sessions/2026-05-13-1830-d1e9.md) |
| 2026-05-13 | 18:30 | 614f | main | MT-111/112 independent re-verify + filed MT-114 | [link](docs/sessions/2026-05-13-1830-614f.md) |
| 2026-05-13 | 17:27 | fd9e | main | MT-111 ship + Playwright-verify Explorer Superhero render | [link](docs/sessions/2026-05-13-1727-fd9e.md) |
| 2026-05-12 | 16:16 | cb6a | main | Triage-backlog unblock + Sentry wiring (4 closed, 1 wontfix, 1 new) | [link](docs/sessions/2026-05-12-1616-cb6a.md) |
| 2026-05-12 | 09:30 | 6298 | main | Superhero Mode extended to Explorer band (ages 6-8) | [link](docs/sessions/2026-05-12-0930-6298.md) |
| 2026-05-11 | 23:41 | 6e04 | main | In-flight triage + Sentry triage reports (both blocked by MT-095) | [link](docs/sessions/2026-05-11-2341-6e04.md) |
| 2026-05-11 | 23:38 | b5ad | main | No-op re-close after 0a90 | [link](docs/sessions/2026-05-11-2338-b5ad.md) |
| 2026-05-11 | 23:23 | 66ef | main | Stripe race + price-id fixes via Playwright; multi-agent farm-out | [link](docs/sessions/2026-05-11-2323-66ef.md) |
| 2026-05-11 | 23:23 | 953a | main | Close-session push policy + MT-087 cap UI widget tests | [link](docs/sessions/2026-05-11-2323-953a.md) |
| 2026-05-11 | 23:22 | e33d | main | BYOK validation diagnosis (backend off) + post-hoc verify | [link](docs/sessions/2026-05-11-2322-e33d.md) |
| 2026-05-11 | 23:22 | cbe9 | main | Wizard create-new: age picker, name gate, companion-orb dedupe | [link](docs/sessions/2026-05-11-2322-cbe9.md) |
| 2026-05-11 | 23:21 | f8c1 | main | Phase 1 monetization: Stripe wiring + Flux Schnell routing + matrix ratifications | [link](docs/sessions/2026-05-11-2321-f8c1.md) |
| 2026-05-11 | 22:53 | 0a90 | main | Sprout reader: page cap 8-12, JSON salvage, image text scrub | [link](docs/sessions/2026-05-11-2253-0a90.md) |
| 2026-05-11 | 22:52 | b36c | main | Egg jokes + crack counter for Sprout avatar generation | [link](docs/sessions/2026-05-11-2252-b36c.md) |
| 2026-05-11 | 15:57 | 08f3 | main | Sentry triage — 1 dev-noise issue, Seer over budget | [link](docs/sessions/2026-05-11-1557-08f3.md) |
| 2026-05-11 | 12:28 | d6a5 | main | BYOK mid-flow photo-avatar advance fix (MT-090) | [link](docs/sessions/2026-05-11-1228-d6a5.md) |
| 2026-05-11 | 11:00 | 4698 | main | No-op re-close after 6ce1 (no new work) | [link](docs/sessions/2026-05-11-1100-4698.md) |
| 2026-05-11 | 10:53 | 5b5b | main | Prefetcher circuit-breaker + page-flip SFX polish | [link](docs/sessions/2026-05-11-1053-5b5b.md) |
| 2026-05-11 | 10:53 | 3514 | main | No-op close (post-/clear, in-flight files left to parallel session) | [link](docs/sessions/2026-05-11-1053-3514.md) |
| 2026-05-11 | 10:19 | 3614 | main | Free-tier illustration cap upsell UI (MT-087) | [link](docs/sessions/2026-05-11-1019-3614.md) |
| 2026-05-11 | 10:19 | 6ce1 | main | Custom-avatar hair-length fix + MIME-detect on reference photo | [link](docs/sessions/2026-05-11-1019-6ce1.md) |
| 2026-05-11 | 08:17 | abb3 | main | Image-gen A/B: production routing audit + verified OpenRouter $0.0375/img | [link](docs/sessions/2026-05-11-0817-abb3.md) |
| 2026-05-11 | 08:16 | fa4d | main | Premium = family tier (6 slots, adult relatives, rotating hero) | [link](docs/sessions/2026-05-11-0816-fa4d.md) |
| 2026-05-10 | 09:39 | cd7d | main | Stripe v15 + wiring + premium matrix coordination | [link](docs/sessions/2026-05-10-0939-cd7d.md) |
| 2026-05-10 | 09:39 | ba9c | main | PREMIUM_BYOK_MATRIX coordination doc — multi-agent buildout | [link](docs/sessions/2026-05-10-0939-ba9c.md) |
| 2026-05-10 | 09:39 | c8f0 | main | MT-077 Sentry sweep verified + closed (cursor auto-close confirmed) | [link](docs/sessions/2026-05-10-0939-c8f0.md) |
| 2026-05-10 | 08:20 | df18 | main | Sentry weekly-digest triage: cursor rewrite + dev-event silence | [link](docs/sessions/2026-05-10-0820-df18.md) |
| 2026-05-09 | 20:15 | d235 | main | Sprout portrait swap to bundled path + 'Learning to Read' rename | [link](docs/sessions/2026-05-09-2015-d235.md) |
| 2026-05-09 | 20:15 | e054 | main | No-op close (no work since d84a) | [link](docs/sessions/2026-05-09-2015-e054.md) |
| 2026-05-09 | 18:15 | 3240 | main | Hero creator featured photo-avatar card + BYOK loop fix | [link](docs/sessions/2026-05-09-1815-3240.md) |
| 2026-05-09 | 15:10 | d84a | main | BYOK CTA in avatar tweak panel + hero_creator premium-state refresh | [link](docs/sessions/2026-05-09-1510-d84a.md) |
| 2026-05-08 | 21:37 | 46a8 | main | 3yo walkthrough triage: Sprout caps + UI contrast + avatar crash fix | [link](docs/sessions/2026-05-08-2137-46a8.md) |
| 2026-05-08 | 21:37 | 8c13 | main | Sprout sparkle-catcher firework + idle-star redesign | [link](docs/sessions/2026-05-08-2137-8c13.md) |
| 2026-05-08 | 19:34 | 0441 | main | Sprout image swap + character local-save resilience | [link](docs/sessions/2026-05-08-1934-0441.md) |
| 2026-05-08 | 19:34 | 7a95 | main | MT-064 cleanup: imagine_it screenshots + gitignore | [link](docs/sessions/2026-05-08-1934-7a95.md) |
| 2026-05-08 | 18:34 | 8015 | main | Imagine It card UX rework: full-screen route + visual press effect | [link](docs/sessions/2026-05-08-1834-8015.md) |
| 2026-05-06 | 12:22 | 39bf | main | 4th Sprout quest draft: gratitude (Sunny Pup / Hot Cocoa Breath) | [link](docs/sessions/2026-05-06-1222-39bf.md) |
| 2026-05-06 | 10:10 | c910 | main | Drafted 3 Sprout quests (mad/sad/scared) — parked for integration | [link](docs/sessions/2026-05-06-1010-c910.md) |
| 2026-05-06 | 10:09 | 536f | main | Fix static breathing-orb in CopingPracticeSheet | [link](docs/sessions/2026-05-06-1009-536f.md) |
| 2026-05-06 | 10:07 | 0d37 | main | Sprout cloud→animal-friends rebrand + breathing buddy | [link](docs/sessions/2026-05-06-1007-0d37.md) |
| 2026-05-06 | 08:02 | 81f6 | main | Sprout polish: per-page art + backend caps + welcome-back | [link](docs/sessions/2026-05-06-0802-81f6.md) |
| 2026-05-05 | 20:35 | d046 | main | Push 7-commit backlog: coping toolbox + Big Feelings wizard routing | [link](docs/sessions/2026-05-05-2035-d046.md) |
| 2026-05-05 | 00:17 | 78ab | main | A6 raced + per-page BYOK illustration prefetcher spike | [link](docs/sessions/2026-05-05-0017-78ab.md) |
| 2026-05-05 | 00:06 | b535 | main | A3 fix: page-turn no longer keeps prior page's scroll offset | [link](docs/sessions/2026-05-05-0006-b535.md) |
| 2026-05-05 | 00:05 | 4af1 | main | Multi-agent Sprout sweep: TTS storm, A7 vocab, A8 audit | [link](docs/sessions/2026-05-05-0005-4af1.md) |
| 2026-05-05 | 00:04 | 861c | main | A8 Sprout UX pass: responsive page + bigger kid taps | [link](docs/sessions/2026-05-05-0004-861c.md) |
| 2026-05-05 | 00:03 | af96 | main | Sprout vocab rule (A7) — absorbed by parallel commit 6bccd443 | [link](docs/sessions/2026-05-05-0003-af96.md) |
| 2026-05-05 | 00:02 | ebc0 | main | Fix misleading Pick a Path badge on linear stories | [link](docs/sessions/2026-05-05-0002-ebc0.md) |
| 2026-05-03 | 23:50 | 2f3d | main | GIT_MAINTENANCE: 6 dep patches + dependabot auto-cleanup observed | [link](docs/sessions/2026-05-03-2350-2f3d.md) |
| 2026-05-03 | 23:33 | 8580 | main | MT-035 root-cause investigation (anon UI verification blocked) | [link](docs/sessions/2026-05-03-2333-8580.md) |
| 2026-05-03 | 23:14 | e61a | main | Sprout loading-screen mini-game extension + early-reader UX consult | [link](docs/sessions/2026-05-03-2314-e61a.md) |
| 2026-05-03 | 23:05 | 65b8 | main | Fix avatar tweak URL path (/avatars/ → /avatar/) | [link](docs/sessions/2026-05-03-2305-65b8.md) |
| 2026-05-03 | 22:54 | 944e | main | Commit pre-existing: character preloading + page-flip sparkles | [link](docs/sessions/2026-05-03-2254-944e.md) |
| 2026-05-03 | 22:23 | 7e08 | main | Wizard progress-indicator back-nav fix from review step | [link](docs/sessions/2026-05-03-2223-7e08.md) |
| 2026-05-03 | 22:19 | d110 | main | Deploy+verify sweep — 5 MTs closed (Phase 0–3) | [link](docs/sessions/2026-05-03-2219-d110.md) |
| 2026-05-03 | 15:48 | b950 | main | Duplicate close; no new work | [link](docs/sessions/2026-05-03-1548-b950.md) |
| 2026-05-03 | 11:46 | f5e9 | main | TTS_DISABLED toggle + ElevenLabs quota fix | [link](docs/sessions/2026-05-03-1146-f5e9.md) |
| 2026-05-02 | 20:57 | 35ec | main | GIT_MAINTENANCE: dep updates + repo audit (stripe/elevenlabs deferred) | [link](docs/sessions/2026-05-02-2057-35ec.md) |
| 2026-05-02 | 20:23 | 0b11 | main | Test suite final push: 294/294 green (stripe, scenario, journey) | [link](docs/sessions/2026-05-02-2023-0b11.md) |
| 2026-05-02 | 20:12 | c1ff | main | MT-027 root-cause: opaque assets + GenderImageButton hardened | [link](docs/sessions/2026-05-02-2012-c1ff.md) |
| 2026-05-02 | 20:12 | 647b | main | Session start + Railway deploy attempt | [link](docs/sessions/2026-05-02-2012-647b.md) |
| 2026-05-02 | 20:11 | 3b79 | main | Young-band delight rules + test suite cleanup | [link](docs/sessions/2026-05-02-2011-3b79.md) |
| 2026-05-02 | 16:46 | d917 | main | Child-UX audit + Sprout fixes (POV, vocab, save, illus) | [link](docs/sessions/2026-05-02-1646-d917.md) |
| 2026-05-02 | 15:57 | 5653 | main | TTS quota 503 + Sprout scene tap auto-advance | [link](docs/sessions/2026-05-02-1557-5653.md) |
| 2026-05-02 | 15:28 | 9471 | main | Quality audit script + adult band story-gen fixes | [link](docs/sessions/2026-05-02-1528-9471.md) |
| 2026-05-02 | 14:05 | 9a69 | main | Sprout ocean tile code fix + girl archetype images | [link](docs/sessions/2026-05-02-1405-9a69.md) |
| 2026-05-02 | 14:01 | ca0d | main | Adventurer mic support + MT-017 TTS audit + close-session push | [link](docs/sessions/2026-05-02-1401-ca0d.md) |
| 2026-05-02 | 14:01 | c75e | main | Big Feelings rebrand + visual redesign + offline story fallback | [link](docs/sessions/2026-05-02-1401-c75e.md) |
| 2026-05-02 | 14:01 | 487e | main | Sprout robotic-voice fix on photo step + Animal Friend boy image | [link](docs/sessions/2026-05-02-1401-487e.md) |
| 2026-05-02 | 14:00 | 7e8d | main | MT-022 verified, MT-027 checkerboard fix, MT-023 diagnosed | [link](docs/sessions/2026-05-02-1400-7e8d.md) |
| 2026-05-02 | 10:53 | 8ca2 | main | Big Feelings Scrollbar/ScrollController crash fix | [link](docs/sessions/2026-05-02-1053-8ca2.md) |
| 2026-05-02 | 10:32 | dfad | main | Sprout archetype images + Gemini pet avatar key fix | [link](docs/sessions/2026-05-02-1032-dfad.md) |
| 2026-05-02 | 10:19 | 9b2b | main | Sprout avatar simplification, ocean tile, story fallback fix | [link](docs/sessions/2026-05-02-1019-9b2b.md) |
| 2026-05-02 | 10:18 | 599b | main | Age-band visual audit: fix 5 UI bugs | [link](docs/sessions/2026-05-02-1018-599b.md) |
| 2026-05-02 | 09:45 | 19bb | main | No-op close (work already committed as 263f) | [link](docs/sessions/2026-05-02-0945-19bb.md) |
| 2026-05-02 | 09:45 | 3297 | main | Configured Claude Code statusline on new computer | [link](docs/sessions/2026-05-02-0945-3297.md) |
| 2026-05-01 | 23:30 | 263f | main | BYOK validation crash fix + white-on-cream text field | [link](docs/sessions/2026-05-01-2330-263f.md) |
| 2026-05-01 | 23:21 | 8b6a | main | Six age-band visual audit + screenshot contention notes | [link](docs/sessions/2026-05-01-2321-8b6a.md) |
| 2026-05-01 | 23:11 | e32c | main | Sprout UX redesign + TTS dual-voice fix | [link](docs/sessions/2026-05-01-2311-e32c.md) |
| 2026-05-01 | 23:11 | 0151 | main | Welcome voice/UX fixes + wizard back-nav + Sprout review TTS | [link](docs/sessions/2026-05-01-2311-0151.md) |
| 2026-04-24 | 21:20 | 7dba | main | MT-013 BUG-002 retry cap — _maxPrewarmRetries const + skip wasted delay | [link](docs/sessions/2026-04-24-2120-7dba.md) |
| 2026-04-24 | 19:22 | 9620 | main | MT-005 BUG-001 re-verify: 18+ wizard advance PASS + DDC blocker documented | [link](docs/sessions/2026-04-24-1922-9620.md) |
| 2026-04-24 | 18:47 | b00e | main | Consolidated Playwright re-verify — 6 MTs closed (BUG-001✅ BUG-003✅ grids✅ gender✅) | [link](docs/sessions/2026-04-24-1847-b00e.md) |
| 2026-04-22 | 12:16 | d1c2 | main | BYOK visible key + SnackBar fix; Sprout quests | [link](docs/sessions/2026-04-22-1216-d1c2.md) |
| 2026-04-22 | 12:16 | 9b80 | main | TASK5 BYOK wizard re-check (no-op; already shipped) | [link](docs/sessions/2026-04-22-1216-9b80.md) |
| 2026-04-22 | 12:16 | cd57 | main | Six Hats UX audit (general app) — context-continuation close | [link](docs/sessions/2026-04-22-1216-cd57.md) |
| 2026-04-22 | 12:16 | 8a9d | main | Archetype image grid for mature bands (creator/adolescent/adult) | [link](docs/sessions/2026-04-22-1216-8a9d.md) |
| 2026-04-22 | 12:16 | 269f | main | Six Hats audit closeout — consent AppBar + Go Solo | [link](docs/sessions/2026-04-22-1216-269f.md) |
| 2026-04-22 | 12:16 | 8972 | main | Session tooling: /close-session + /start-session overhaul | [link](docs/sessions/2026-04-22-1216-8972.md) |
| 2026-04-22 | 12:16 | 7df8 | main | Six Hats creator review triage + BUG-010 auth guard | [link](docs/sessions/2026-04-22-1216-7df8.md) |
| 2026-04-22 | 12:15 | c29c | main | BUG-001/002/003 status audit + CORS stale-entry cleanup | [link](docs/sessions/2026-04-22-1215-c29c.md) |
| 2026-04-22 | 12:15 | c4ea | main | BUG-003 Stripe anon guard + BUG-002 TTS backoff verification | [link](docs/sessions/2026-04-22-1215-c4ea.md) |
| 2026-04-22 | 12:15 | 2571 | main | BUG-002 TTS backoff root-cause fix + Playwright MCP isolation | [link](docs/sessions/2026-04-22-1215-2571.md) |
| 2026-04-22 | 12:15 | 247a | main | Gender picker placeholder images wired in — all 6 bands | [link](docs/sessions/2026-04-22-1215-247a.md) |
| 2026-04-22 | 12:14 | 76e3 | main | Six Hats adult audit + BUG-012 error copy + BUG-010 guard | [link](docs/sessions/2026-04-22-1214-76e3.md) |
| 2026-04-22 | 12:14 | a488 | main | Session-handoff follow-ups (read-count bump + rename) | [link](docs/sessions/2026-04-22-1214-a488.md) |
| 2026-04-22 | 10:17 | 5a52 | main | Session-handoff overhaul (per-session files + global manual tasks) | [link](docs/sessions/2026-04-22-1017-5a52.md) |
| 2026-04-25 |  —    | 3a99 | main | MT-012 13-17 attestation gate + golden test cleanup | (no session file) |
| 2026-04-25 | 08:28 | 5c15 | main | MT-003/MT-004: BUG-012 smoke-test + Flutter error display fix | [link](docs/sessions/2026-04-25-0828-5c15.md) |
| 2026-04-25 | 08:36 | a38f | main | MT-012 audit (read-only) — premise stale; parallel session shipped fix | [link](docs/sessions/2026-04-25-0836-a38f.md) |

---

> Pre-2026-04-22 session blocks archived to [docs/archive/TEAM_COORDINATION_pre-2026-04-22.md](docs/archive/TEAM_COORDINATION_pre-2026-04-22.md).
