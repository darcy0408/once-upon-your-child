# Story Weaver App - Project Status

**Last Updated:** 2026-05-30

> Customer-facing brand is **"Once Upon YOUR Child, powered by Story Weaver"** — "Story Weaver" is the technical/platform name.

## Current Status: Post-Launch / Monetization, Reliability & Hardening

The five launch-track development phases are complete. The app is deployed on Railway (backend + `grand-light` frontend; Netlify mirror is orphaned and slated for decommission). Phase 6 is in flight — Stripe monetization wiring, reliability hardening (FMEA fixes, prompt-template versioning, streaming backend), Play Store size optimization (WebP), a WCAG 2.2 AA accessibility audit, recurring security audits, and a story-quality eval/judge harness.

Backlog: **53 open / 93 done** manual tasks (`docs/MANUAL_TASKS.md`) — most open items are browser/device verification, not code.

## Architecture

| Layer | Stack |
|-------|-------|
| Frontend | Flutter (Dart) — web, Android (AAB ~82MB), iOS, desktop |
| Backend | Python / Flask on Railway + Celery worker (Redis broker) |
| AI | Google Gemini (server + BYOK server-side); OpenRouter / Flux Schnell fallback |
| Images | Gemini + Flux image generation; served via Cloudflare |
| Storage | Postgres on Railway (since 2026-05-14; shared by Flask + Celery); Isar offline cache (`SharedPreferences` stub on web) |
| Backups | External `pg_dump` → Cloudflare R2 (Railway native backups are Pro-only) |
| TTS | ElevenLabs → Gemini Flash TTS → Edge TTS → on-device flutter_tts (tiered fallback) |
| Monitoring | Sentry crash reporting |
| Payments | Stripe (Free / Adventurer / Family / BYOK tiers) |

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
- Cover-image height bumped 55 % → 68 %; BoxFit.cover; BYOK users bypass illustration paywall
- Pick-a-Path AppBar progress bar hidden during session-break screen
- TTS warm-up queue reordered to cache Sprout avatar prompts and colour names first (was failing to robotic flutter_tts fallback when child outran the prewarm)
- Wizard back-nav: tapping prior progress dots from MagicReviewStep now animates back to HeroCreatorStep at the correct sub-step

### Monetization & Tiers (Phase 6)
- Stripe checkout + webhooks wired (Phase 1 monetization); customer-portal redirect (Stripe-hosted until frontend has portal routes)
- Tiers: Free / Adventurer / **Family** (6 slots, adult relatives, rotating hero) / BYOK
- Free-tier illustration cap with upsell UI; BYOK users bypass the illustration paywall
- Image-gen cost routing: Flux Schnell for non-BYOK; OpenRouter Gemini Image priced per-image (~$0.0375/img)
- AI quota circuit breaker + fail-closed illustration-quota cost breaker on Redis outage

### Reader & Reading Experience (Phase 6)
- **MT-099 "Open Book" reader** — leaf grounded inside a leather hardback frame (per-band leather palettes, warm body, stacked-leaves footer), two-page spread on wide screens, gold-filigree chrome dropped when framed; high-contrast passthrough; reduce-motion gates the 3D flip + sparkle burst
- Page-flip SFX (`page_turn.mp3`), egg-crack avatar generation animation, illustration persistence, resume/continue affordance per hero
- Superhero Mode (hero powers with per-power visual overrides) extended to Explorer band

### Story Generation & Quality (Phase 6)
- **Prompt-template versioning** (MT-187 F-01) — prompts are versioned and tracked
- **Streaming story backend** (PERF-01) + cancel foundation (PERF-04)
- Story-quality **eval/judge harness** (MT-186) — GitHub Models gpt-4.1 judge, scheduled daily, story text truncated to 5k chars to avoid 413
- Themes feature (story themes recall, wired end-to-end)

### Therapeutic / Safety (Phase 6 additions)
- **MT-158 parent sensitivity interstitial** — per-quest sensitivity metadata + a parent-facing interstitial before sensitive Life Quests (F-08/F-16)

### Infrastructure
- BYOK (Bring Your Own Key) setup wizard with secure storage, "free" copy lead-in
  - Validation no longer crashes on empty-candidate Gemini responses (`models.list()` health check instead of `generate_content`)
  - Text field readability fix (dark text on cream card)
  - StoryResultScreen converted to ConsumerStatefulWidget so `useOwnApiKey` is reactive (was frozen at construction)
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

## Known Issues

1. **Manual-tasks backlog: 53 open items** (`docs/MANUAL_TASKS.md`) — overwhelmingly browser/device verification of shipped fixes rather than unstarted code. Notable open code-ish items: MT-129 (illustration↔avatar fidelity — text-fix shipped, awaiting paid-tier verify), MT-120 (per-power visual override paid-tier verify), MT-105 (Flutter integration-tests agent in worktree), MT-199 (Sprout pop-up reader, backlog), MT-200 (MT-099 global warm-bg polish).
2. **Reliability hardening not fully closed** — Phase 2+3 FMEA fixes done; prod migration done; some Railway verify + alerting still pending (see memory `reliability_hardening_2026_05`).
3. **Railway native backups are Pro-only** — mitigated by external `pg_dump` → R2 workflow; verify the cron is healthy.
4. **Dependabot deferred majors** — stripe → v15 (note: v15 has breaking changes — `stripe.error.*` removed, `StripeObject` lost `.get()`), elevenlabs floor, cryptography, protobuf. Each blocked on a manual smoke-test of the payment / TTS / crypto paths.
5. **Netlify frontend is orphaned** — `reliable-sherbet-2352c4` still auto-deploys a stale build; real prod is Railway `grand-light`. Decommission pending.
6. **Local `backend_errors.log`** carries only test-suite noise (dev JWT, `agegate-*` users, Redis-down breaker firing by design) — not production errors.

## Planned (v1.1+)

- SMS / Stripe age verification
- Guided meditation mode (additional patterns beyond Adult Breathe)
- PDF story export
- Parent dashboard & analytics
- Push notifications
- Referral program
- Per-page illustration generation for Sprout Picture Book mode (B-BE4, deferred from child-UX audit)
- Stripe v15 + ElevenLabs v2 floor bump after smoke-tests
- 6 additional Creator/Adolescent Life Quests (authored, awaiting rollout)
- MT-199 Direction C "Pop-Up Picture Book" reader for Sprout (backlog, pending signal)
- MT-200 MT-099 polish: global warm "book-stage" background + title-page-leaf demotion
- Frontend migration to Cloudflare Pages (branch `chore/frontend-cloudflare-pages`) + Netlify decommission

## Resources

- [Master Launch Plan](MASTER_LAUNCH_PLAN.md)
- [Business Plan](BUSINESS_PLAN.md)
- [COPPA Audit](COPPA_AUDIT.md)
- [Team Coordination](../TEAM_COORDINATION.md)
- [Manual Tasks](MANUAL_TASKS.md)
- [QA Playwright Report 2026-04-24](QA_PLAYWRIGHT_REPORT_2026-04-24.md)
- [Quality Audit results](../backend/tests/quality/results/) (gitignored; latest: 2026-05-03)
