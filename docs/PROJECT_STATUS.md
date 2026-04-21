# Story Weaver App - Project Status

**Last Updated:** 2026-04-21

## Current Status: Post-Launch / Polish & Hardening

All three development phases are complete. The app is deployed (Railway backend, Netlify frontend). Current work focuses on UX polish, age-band consistency, QA regression, and resolving production blockers.

## Architecture

| Layer | Stack |
|-------|-------|
| Frontend | Flutter (Dart) — web, Android, iOS, desktop |
| Backend | Python / Flask on Railway |
| AI | Google Gemini (server + BYOK client-side) |
| Storage | Isar (offline cache, `SharedPreferences` stub on web), SQLite (backend) |
| TTS | ElevenLabs (via backend) |
| Monitoring | Sentry crash reporting |
| Payments | Stripe (Free / Adventurer / Family / BYOK tiers) |

## Completed Features

### Core Experience
- 4-step story wizard: Hero Creator, Feeling Selection, Companion Selector, Magic Review
- AI story generation with sensory-rich adventure prompts
- Pick-a-Path interactive stories
- Rhyme Time and Learning to Read modes
- Typewriter reveal + page-flip storybook reader
- Illustration generation and coloring page export
- ElevenLabs TTS narration (global 0.85× rate, rate-limit aware backoff)

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
- **Life Quests** (formerly Big Feelings) — CYOA emotional problem-solving; 5 Explorer quests authored, 6 new Creator/Adolescent quests in flight
- Adult band Reflect screen: Breathe (3 patterns) / Reflect (journaled prompts) / Ground (5-4-3-2-1)
- COPPA-compliant age gate and parental consent (sticky footer, share-to-grown-up flow)
- Parent controls (screen time, bedtime, Life Quests settings, character creation link)

### Character System
- Full CRUD for characters with name/age/gender/archetype
- Gendered archetype images across all 6 bands (boy/girl variants), age-appropriate archetype names
- Pet management (species, personality, color)
- Human companion avatar pipeline: photo-to-Pixar prompt preserving face-likeness (distinct from pet cartoon transformation)
- Character library grid view
- Archetypes with special abilities and age-appropriate labels
- Companion selector with saved characters, pets, magical creatures

### Infrastructure
- BYOK (Bring Your Own Key) setup wizard with secure storage, "free" copy lead-in
- Offline caching via Isar (web: `SharedPreferences`-backed stub of the same query API)
- Railway backend deployment
- Netlify frontend deployment
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

## Development Phases (All Complete)

### Phase 1 (Dec 2025) — Foundation
Wizard UI, character system, story generation, backend deployment.

### Phase 2 (Jan-Feb 2026) — Content & Calibration
Adventure content upgrades, sensory immersion, archetype overhaul, mood-physics mapping, 7-band age calibration, tone calibration (CTA, coping strategies, bedtime prompts).

### Phase 3 (Mar 2026) — Visual Consistency & UX
Band-specific feeling images, visual consistency pass, step-nav tap-to-scroll for mature bands, avatar overflow fixes, stale scenario title fixes, age picker redesign (big circles 3-8, pill bands 9+), exhaustive AgeBand switches.

### Phase 4 (Apr 2026) — Polish, Compliance & Differentiation
ADULT-3 Reflect screen, Life Quests rebrand, security audit + remediation, Creator/Adolescent differentiation plan, gendered archetypes all bands, Playwright QA sweep, a11y semantic wiring (FeelingsBadgeGrid, GenderImageButton).

## Known Issues

1. **Content moderator failing open** — `gemini-2.0-flash-lite` is deprecated (404 NOT_FOUND). `content_moderator` fails open, meaning stories are not safety-classified pre-delivery. **P0 — silent safety regression.** Fix pending (see `docs/briefings/TASK2_MODERATOR_MODEL_BUMP.md`).
2. **BUG-001 re-verification pending** — Adult-band Create Story avatar-gate fix (commit `73ee489`) landed on `main` but has not been Playwright-verified against the live Railway build. See `docs/briefings/TASK1_PLAYWRIGHT_BAND6_REVERIFY.md`.
3. **BUG-002 / BUG-003 regression re-run pending** — TTS 429 backoff + Stripe anon guard fixed analytically on 2026-04-20b; full Playwright regression re-run deferred.
4. **CORS blocking production web** — Backend CORS config prevents frontend from reaching API in production web deployment. Mobile/desktop unaffected.

## Planned (v1.1+)

- SMS / Stripe age verification
- Guided meditation mode (additional patterns beyond Adult Breathe)
- PDF story export
- Parent dashboard & analytics
- Push notifications
- Referral program

## Resources

- [Master Launch Plan](MASTER_LAUNCH_PLAN.md)
- [Business Plan](BUSINESS_PLAN.md)
- [COPPA Audit](COPPA_AUDIT.md)
- [Team Coordination](../TEAM_COORDINATION.md)
- [QA Playwright Report 2026-04-20](QA_PLAYWRIGHT_REPORT_2026-04-20.md)
