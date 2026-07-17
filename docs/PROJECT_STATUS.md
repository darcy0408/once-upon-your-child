# Story Weaver App - Project Status

**Last Updated:** 2026-07-17

> Customer-facing brand is **"Once Upon YOUR Child, powered by Story Weaver"** — "Story Weaver" is the technical/platform name. The business now operates through an **LLC** (formed 2026-06-21).

## Current Status: Pre-Launch Compliance & Safety Hardening

The core product is feature-complete across all 6 age bands; the work through June 2026 has been a **launch-gate compliance and safety sweep**, not new features. The app is deployed (backend on Railway; frontend on **Cloudflare Pages** at onceuponyourchild.app, both apex and www — the old Netlify site and Railway `grand-light` frontend service were both deleted 2026-07-17). **No live users yet** — every safety/compliance item is gated on *launch*, not on production traffic.

The single largest change this month: **all AI provider paths moved off Google Gemini** for child-directed content, because Gemini's API ToS (and Vertex's) prohibit apps directed at under-18s ("MT-137"). Story **text** now runs on **OpenAI GPT-5 mini** for all tiers; **avatars** on OpenAI gpt-image; **narration** on **Azure AI Speech**; **illustrations** stay on Cloudflare Flux (clean). Gemini is down to residual image-fallback paths being retired.

Backlog: ~**80 open / 180+ done** manual tasks (`docs/MANUAL_TASKS.md`) — the large majority of open items are **browser/device verification or owner ops** (Railway config flips, dashboard checks, clinical/legal sign-off), not unstarted code.

**June 2026 arc (~25 sessions):** OpenAI story-text migration + `EMOTIONAL HEART` prompt upgrade (#266/#272); Azure AI Speech narration go-live + ElevenLabs `/tts/transcribe` deletion (#277/#278); the Adolescent (15–17) antihero "double-life" saga end-to-end (#263–#267) + the Crux Choice backend (#273) + saga-continuity loop extended to Adventurer/Explorer (#274); Hero Saga Phase 2 (#257); the "Story Notes" age-gated transparency layer over the hidden parent-context (#279); the ux6b + mature-bands UX audits (MT-262…302, ~20 PRs); the **Boy/Girl-only** gender decision (#291); and the **pre-launch Safety/Legal/COPPA audit batch** — legal-liability + Phase 1 COPPA consent gating (#320), purchase-gating P0 cluster (#321), generation-output egress + teen fail-closed (#332), authz/generator hardening (#335), story-quality/reliability + the P0 Pick-a-Path→Gemini ToS fix (#336), plus BYOK Gemini-image guard + privacy-defaults (#319/#333/#334).

## Architecture

| Layer | Stack |
|-------|-------|
| Frontend | Flutter (Dart) — web (Cloudflare Pages, onceuponyourchild.app), Android (AAB ~82MB), iOS, desktop |
| Backend | Python / Flask on Railway + Celery worker (Redis broker); story-gen runs sync in the web process |
| Story text | **OpenAI GPT-5 mini** (all tiers, `STORY_GEN_PROVIDER=openai`); `claude`/`tiered` providers built but dormant. Gemini forbidden for kids (MT-137) |
| Content moderation | 2-layer: deterministic keyword filter + LLM pass (**being decoupled Gemini→OpenAI**, tonight's PR) |
| Images | Avatars → **OpenAI gpt-image**; story illustrations → **Cloudflare Flux** → Replicate → (Gemini last-resort, being retired) |
| Storage | Postgres on Railway (since 2026-05-14); Isar offline cache (`SharedPreferences` stub on web) |
| Backups | External `pg_dump` → Cloudflare R2 (verified restorable, RTO ~2s) + `restore-drill.yml` |
| TTS | **Azure AI Speech** (primary, real-time/no-retention) → Edge → on-device flutter_tts; ElevenLabs 13+ only; child-voice STT deleted |
| Monitoring | Sentry crash reporting (Developer plan; `beforeSend` PII scrub) |
| Payments | Stripe — single Premium $9.99/mo / $59.99/yr (pricing decision 2026-07-07, PRs #395/#398); free = 5 stories/mo + 1 illustrated; Family tier dormant/hidden; BYOK sunset 2026-07-15 (MT-358 decision (a)) |

## Completed Features

### Core Experience
- 4-step story wizard: Hero Creator, Feeling Selection, Companion Selector, Magic Review
- AI story generation with sensory-rich adventure prompts
- Pick-a-Path interactive stories
- Rhyme Time and Learning to Read modes (Read Along now uses phrase-per-line layout for early readers)
- Typewriter reveal + page-flip storybook reader, golden sparkle burst + haptic feedback on every flip
- Illustration generation and coloring page export
- ElevenLabs TTS narration (global 0.85× rate, rate-limit aware backoff with retry cap)
- Sparkle-catcher tap-target mini-game during story generation, available on all bands (sprout cadence softer: 2.8 s spawn, 4–5 s lifetime, 60 px golden stars)
- Synchronous welcome-back: saved characters preloaded on app start so the wizard opens directly to the character grid (no blank flash)
- Offline story-scaffold fallback wraps both AI generation paths; serves a personalized scaffold story when AI is unreachable

### Age Bands (6 bands, fully themed)
| Band | Ages | Theme |
|------|------|-------|
| Sprout | 2-5 | Warm, bubbly, illustration-heavy |
| Explorer | 6-8 | Magical purple, sparkles |
| Adventurer | 9-11 | Cosmic, book-like typography |
| Creator | 12-14 | Clean editorial, dark mode default |
| Adolescent | 15-17 | Cinematic dark, teal accent |
| Adult | 18+ | Refined minimal, warm amber |

Each band has dedicated visual assets, typography, color palettes, age-appropriate copy, and gendered archetype images. All `AgeBand` switches are exhaustive. All 6 bands now share the same 4-tab shell (Stories / Reflect or Feelings / Library / Settings).

### Therapeutic / Safety
- Mood Magic + 3-level Feelings Wheel
- **Life Quests** (formerly Big Feelings) — CYOA emotional problem-solving; 5 Explorer quests authored, Sprout quests live (Big Bear Hug, Big Loud, My Turn Your Turn), Creator/Adolescent in flight
- Sprout Big Feelings flow rebrand: 4-cloud entry grid (Sunny/Rain/Storm/Wobbly), squircle emotion cards, auto-advance on feeling pick, coping-tool sub-step skipped for ages ≤ 5, grown-up tip callout on quest endings
- Adult band Reflect screen: Breathe (3 patterns) / Reflect (journaled prompts) / Ground (5-4-3-2-1)
- COPPA-compliant age gate and parental consent (sticky footer, share-to-grown-up flow)
- 13–17 attestation gate: "Just so you know" parent-awareness dialog before `recordConsent(method: 'self_attested')`; teens always proceed
- Parent controls (screen time, bedtime, Life Quests settings, character creation link)

### Character System
- Full CRUD for characters with name/age/gender/archetype
- Gendered archetype images across all 6 bands (boy/girl variants), age-appropriate archetype names
- Pet management (species, personality, color)
- Human companion avatar pipeline: photo-to-Pixar prompt preserving face-likeness (distinct from pet cartoon transformation)
- "Generate my look" gallery-avatar tweak (hair length / eye colour customise → AI compare view)
- Character library grid view
- Archetypes with special abilities and age-appropriate labels
- Companion selector with saved characters, pets, magical creatures
- Sprout avatar wizard simplified to 4 steps (welcome → gender → favouriteColor → photo); 9-colour 3×3 grid; AI infers hair/eye colour from photo
- Sprout Animal Friend (boy + girl) and Brave Hero archetype scenes refreshed

### Sprout Experience (Phase 5 redesign)
- Story prompts: mandatory third-person POV, 3–4 band forbidden-word list (15 entries), 8-word sentence ceiling, animism guard
- "Young-band delight rules" (age ≤ 7): ≥2 ALL-CAPS onomatopoeia per page, rule-of-three story structure, companion arc with doubt → courage, page-ending hooks
- Full-width stacked story-type cards (Fredoka 22 px) with Rhyme Time as third option
- Free-form text+mic "Make One Up" panel replaces 4-tile picker
- Sprout scene-tile taps auto-advance the wizard (was leaving kids stuck on the picker)
- Auto-save on story-result landing for ages ≤ 5 (no manual heart tap)
- Chronicles "Your Stories" section at top for Sprout characters; age-aware empty-state copy
- Cover-image height bumped 55 % → 68 %; BoxFit.cover
- Pick-a-Path AppBar progress bar hidden during session-break screen
- TTS warm-up queue reordered to cache Sprout avatar prompts and colour names first (was failing to robotic flutter_tts fallback when child outran the prewarm)
- Wizard back-nav: tapping prior progress dots from MagicReviewStep now animates back to HeroCreatorStep at the correct sub-step

### Monetization & Tiers (Phase 6)
- Stripe checkout + webhooks wired (Phase 1 monetization); customer-portal redirect (Stripe-hosted until frontend has portal routes)
- Tiers: Free / Premium (Family — 6 slots, adult relatives, rotating hero — dormant; BYOK sunset 2026-07-15, MT-358)
- Free-tier illustration cap with upsell UI
- Image-gen cost routing: Flux Schnell primary; OpenRouter Gemini Image fallback priced per-image (~$0.0375/img)
- AI quota circuit breaker + fail-closed illustration-quota cost breaker on Redis outage

### Reader & Reading Experience (Phase 6)
- **MT-099 "Open Book" reader** — leaf grounded inside a leather hardback frame (per-band leather palettes, warm body, stacked-leaves footer), two-page spread on wide screens, gold-filigree chrome dropped when framed; high-contrast passthrough; reduce-motion gates the 3D flip + sparkle burst
- Page-flip SFX (`page_turn.mp3`), egg-crack avatar generation animation, illustration persistence, resume/continue affordance per hero
- Superhero Mode (hero powers with per-power visual overrides) extended to Explorer band

### Story Generation & Quality (Phase 6)
- **Prompt-template versioning** (MT-187 F-01) — prompts are versioned and tracked
- **Streaming story backend** (PERF-01) + cancel foundation (PERF-04)
- Story-quality **eval/judge harness** (MT-186) — GitHub Models gpt-4.1 judge, story text truncated to 5k chars to avoid 413; the scheduled-daily workflow (`eval-judge-resume.yml`) was later deleted in #168, so the harness now runs on-demand only, not on a schedule
- Themes feature (story themes recall, wired end-to-end)

### Therapeutic / Safety (Phase 6 additions)
- **MT-158 parent sensitivity interstitial** — per-quest sensitivity metadata + a parent-facing interstitial before sensitive Life Quests (F-08/F-16)

### Infrastructure
- ~~BYOK (Bring Your Own Key) setup wizard~~ — **removed 2026-07-15** (MT-358 sunset: no OpenAI free tier to ride, competed with the single Premium tier, and was the last user-facing Gemini child-data path)
- Offline caching via Isar (web: `SharedPreferences`-backed stub of the same query API)
- Story-generation Gemini key rotation: `GOOGLE_API_KEY_2/3/4` rotate on `ResourceExhausted`
- Image-generation key rotation in `GeminiImageGenerator` (pet avatars + future paths)
- `TTS_DISABLED` env-var toggle short-circuits `/tts/synthesize` to clean 503 (used during ElevenLabs quota outages)
- Backend `_fallback_story()` now returns valid JSON (was bracket-tagged plain text rendering raw in UI)
- `_safe_extract_title_and_gem` uses `JSONDecoder.raw_decode` so trailing Gemini content is silently ignored (no more 7,707-word "Extra data" raw-text fallback)
- Adult band word-ceiling note ("HARD LIMIT: do not exceed N words total") + per-page word scaling by age
- Quality-audit script (`backend/tests/quality/run_story_quality.py`) — 7–9 checks across all 6 bands; 49/49 green on 2026-05-03 production verification
- Test suite: 294/294 green (+ new life-quest sensitivity flow/widget/unit tests from MT-158)
- Postgres on Railway (since 2026-05-14), shared by Flask + Celery worker
- External `pg_dump` → Cloudflare R2 backup workflow (Railway native backups are Pro-only)
- WebP illustration asset conversion + Play Store size optimization (AAB ~82MB); Android keystore runbook delivered
- Custom domain live (CSP + CORS hardened after a custom-domain outage; gstatic in both script-src and connect-src)
- Railway backend + `grand-light` frontend deployment (Netlify mirror orphaned, decommission pending)
- Zero-warning codebase

### Security Hardening (April 2026)
- Gemini API key removed from Flutter client (backend-proxied)
- Gemini output safety filter
- Startup assertions + Sentry noise filter
- AI quota circuit breaker
- Anonymous auth flow fix
- Refresh token rotation + JWT blocklist
- TTS quota + audit log
- Therapist portal removed (security bar exceeded responsible-implementation threshold)

## Development Phases

### Phase 1 (Dec 2025) — Foundation
Wizard UI, character system, story generation, backend deployment.

### Phase 2 (Jan-Feb 2026) — Content & Calibration
Adventure content upgrades, sensory immersion, archetype overhaul, mood-physics mapping, 7-band age calibration, tone calibration (CTA, coping strategies, bedtime prompts).

### Phase 3 (Mar 2026) — Visual Consistency & UX
Band-specific feeling images, visual consistency pass, step-nav tap-to-scroll for mature bands, avatar overflow fixes, stale scenario title fixes, age picker redesign (big circles 3-8, pill bands 9+), exhaustive AgeBand switches.

### Phase 4 (Apr 2026) — Polish, Compliance & Differentiation
ADULT-3 Reflect screen, Life Quests rebrand, security audit + remediation, Creator/Adolescent differentiation plan, gendered archetypes all bands, Playwright QA sweep (BUG-001/002/003 fixes), a11y semantic wiring (FeelingsBadgeGrid, GenderImageButton), 13–17 attestation gate, error-display fix (`interactive_story_service._parseError` priority `message ?? error ?? hint`).

### Phase 5 (early May 2026) — Sprout Polish & UX Sweep
Sprout-first redesign (avatar simplification, scene auto-advance, full-width story-type cards, Make One Up mic panel, auto-save, Chronicles "Your Stories" section, Big Feelings cloud grid + squircle cards), child-UX audit fixes (POV, vocabulary, illustration size, paywall gap), young-band story delight rules, voice/TTS hardening (warm-up reorder, dual-voice fix, `TTS_DISABLED` toggle, retry cap), BYOK reliability sweep (validation crash, text readability, persistence), wizard back-nav from review step, page-flip sparkles + haptics, character preloading, sparkle-catcher mini-game extended to Sprout, avatar tweak URL fix, age-band visual audit (5 fixes), test suite 294/294 green, quality-audit framework + 49/49 prod pass.

### Phase 6 (mid–late May 2026) — Monetization, Reliability & Hardening
Stripe monetization wiring (checkout + webhooks, Family tier, free-tier illustration cap upsell), Postgres provisioning + prod migration, themes feature, prompt-template versioning (MT-187 F-01), streaming story backend (PERF-01) + cancel foundation (PERF-04), story-quality eval/judge harness (MT-186), reliability hardening (FMEA fixes), R2 backup workflow, WebP asset conversion + Play Store size optimization (~82MB AAB) + keystore runbook, custom-domain launch + CSP/CORS P0 fixes, WCAG 2.2 AA accessibility audit + remediation (A11Y tooltip sweep), recurring Six Hats security/content/legal audits + remediation, cost-reduction sweep (Edge TTS free fallback, Gemini Flash TTS overflow tier), Superhero Mode → Explorer band, MT-099 "Open Book" reader refactor, MT-158 parent sensitivity interstitial, "Once Upon YOUR Child" brand sweep.

### Phase 7 (June 2026) — Provider Migration, Superhero Saga & Pre-Launch Compliance
The launch-gate month. **Provider migration off Gemini** (MT-137 ToS): story text → OpenAI GPT-5 mini for all tiers (#266/#272, `EMOTIONAL HEART` prompt), avatars → OpenAI gpt-image (#301), narration → Azure AI Speech (#277/#278), child-voice STT deleted. **Superhero saga:** Adolescent (15–17) antihero double-life band end-to-end (#263–#267), Crux Choice two-phase backend (#273), saga-continuity loop down to Adventurer/Explorer (#274), Hero Saga Phase 2 continuity (#257). **Transparency:** "Story Notes" age-gated disclosure over the hidden parent-context (#279/#286). **UX audits:** the ux6b age-band launch audit + mature-bands audit (MT-262…302, ~20 PRs); Boy/Girl-only gender decision (#291). **Pre-launch Safety/Legal/COPPA audit batch:** legal-liability + Phase 1 COPPA consent gating (#320), purchase-gating P0 cluster (#321), generation-output link-scrub + teen fail-closed (#332), authz/generator hardening (#335), story-quality/reliability + P0 Pick-a-Path→OpenAI ToS fix (#336), BYOK Gemini-image guard + privacy defaults (#319/#333/#334). Business incorporated as an **LLC** (2026-06-21).

## Known Issues / Launch Gates

1. **Gemini fully off child paths, but owner ops flips remain** — story text (OpenAI), avatars (OpenAI), narration (Azure) are migrated. Residual: set `DISABLE_GEMINI_IMAGE=1` on Railway + enable Zero Data Retention (MT-295); confirm `ALLOW_DIRECT_GEMINI_IMAGE` stays unset (MT-309); the LLM-moderator decouple is in a pending PR (tonight).
2. **COPPA launch-gate flags FLIPPED ON (2026-07-14)** — `ENFORCE_RESOLVED_AGE`, `COPPA_REQUIRE_VERIFIED_CONSENT`, `COPPA_REQUIRE_CURRENT_POLICY_VERSION` all set `true` on Railway ahead of invited-tester sharing (MT-310 steps 3–5 done). Smoke-verified: no-age anonymous account → `403 AGE_REQUIRED` on `/generate-story`; age-declared adult → `200` story; under-13 profiles now require the real Resend consent round-trip. Remaining on MT-310: the human sign-off read of `crisis_detection.py`/`input_sanitizer.dart`. (`ENCRYPTION_KEY` is set in prod — verified 2026-07-04 and again 2026-07-14; the old "unset → BYOK 500s" claim was stale.)
3. **Clinical/legal external sign-off outstanding** — Adolescent antihero band is gated OFF pending clinical review (MT-266c; packet ready at `docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`); COPPA verifiable-consent mechanics + crisis-flow US-hardcoding route to counsel/clinician (`docs/SAFETY_AUDIT_REMEDIATION.md`).
4. **Backlog is verification-heavy** — most open MTs are device/browser verification of already-shipped fixes or owner ops, not unstarted code. Art recommissions (MT-268/270/271/272/281/282/287) need Imagen + owner taste.
5. **Local `backend_errors.log`** carries only dev/test noise (unset keys, dev JWT, Redis-down breaker by design) — not production errors.

> Resolved 2026-07-12: Azure AI Speech subscription converted free→Pay-As-You-Go, owner-verified in the portal (MT-259 closed) — the ~2026-07-14 trial-lapse risk is gone.

## Planned (v1.1+)

- SMS / Stripe age verification
- Guided meditation mode (additional patterns beyond Adult Breathe)
- Parent dashboard & analytics (server-side half; basic on-device dashboard shipped)
- Push notifications
- Referral program (parked — owner: zero value pre-launch)
- Per-page illustration generation for Sprout Picture Book mode (B-BE4, deferred from child-UX audit)
- Stripe v15 + ElevenLabs v2 floor bump after smoke-tests
- MT-199 Direction C "Pop-Up Picture Book" reader for Sprout (backlog, pending signal)
- MT-200 MT-099 polish: global warm "book-stage" background + title-page-leaf demotion
- Netlify decommission (frontend already live on Cloudflare Pages; MT-205 sub-item)

> Removed 2026-07-07 as shipped/stale: PDF story export (PR #399); "6 additional Creator/Adolescent
> Life Quests awaiting rollout" (content verified present in `lib/data/life_quest_data.dart`).
> Full unfinished-features sweep: `docs/UNFINISHED_FEATURES_AUDIT.md`.

## Resources

- **[Launch Readiness Tracker](../LAUNCH_READINESS.md)** — deduplicated P0/P1/P2 view across all 14 audits + the backlog; start here for "what's left before launch"
- **[Recovery & Vault Runbook](../RECOVERY.md)** — emergency "prod down / founder unavailable" runbook + credential-vault structure (bus-factor P0)
- [Master Launch Plan](MASTER_LAUNCH_PLAN.md)
- [Business Plan](BUSINESS_PLAN.md)
- [COPPA Audit](COPPA_AUDIT.md)
- [Team Coordination](../TEAM_COORDINATION.md)
- [Manual Tasks](MANUAL_TASKS.md)
- [QA Playwright Report 2026-04-24](QA_PLAYWRIGHT_REPORT_2026-04-24.md)
- [Quality Audit results](../backend/tests/quality/results/) (gitignored; latest: 2026-05-03)
