# Story Weaver App - Project Status

**Last Updated:** 2026-04-12

## Current Status: Post-Launch / Polish & Hardening

All three development phases are complete. The app is deployed (Railway backend, Netlify frontend). Current work focuses on UX polish, age-band consistency, and resolving production blockers.

## Architecture

| Layer | Stack |
|-------|-------|
| Frontend | Flutter (Dart) — web, Android, iOS, desktop |
| Backend | Python / Flask on Railway |
| AI | Google Gemini (server + BYOK client-side) |
| Storage | Isar (offline cache), SQLite (backend) |
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
- ElevenLabs TTS narration

### Age Bands (6 bands, fully themed)
| Band | Ages | Theme |
|------|------|-------|
| Sprout | 2-5 | Warm, bubbly, illustration-heavy |
| Explorer | 6-8 | Magical purple, sparkles |
| Adventurer | 9-11 | Cosmic, book-like typography |
| Creator | 12-14 | Clean editorial, dark mode default |
| Adolescent | 15-17 | Cinematic dark, teal accent |
| Adult | 18+ | Refined minimal, warm amber |

Each band has dedicated visual assets, typography, color palettes, and age-appropriate copy. All `AgeBand` switches are exhaustive.

### Therapeutic / Safety
- Mood Magic + 3-level Feelings Wheel
- Big Feelings therapeutic flow with hidden parent guidance
- COPPA-compliant age gate and parental consent
- Parent controls (screen time, bedtime, Big Feelings settings)

### Character System
- Full CRUD for characters with name/age/gender/archetype
- Pet management (species, personality, color)
- Character library grid view
- Archetypes with special abilities and age-appropriate labels
- Companion selector with saved characters, pets, magical creatures

### Infrastructure
- BYOK (Bring Your Own Key) setup wizard with secure storage
- Offline caching via Isar
- Railway backend deployment
- Netlify frontend deployment
- Zero-warning codebase

## Development Phases (All Complete)

### Phase 1 (Dec 2025) — Foundation
Wizard UI, character system, story generation, backend deployment.

### Phase 2 (Jan-Feb 2026) — Content & Calibration
Adventure content upgrades, sensory immersion, archetype overhaul, mood-physics mapping, 7-band age calibration, tone calibration (CTA, coping strategies, bedtime prompts).

### Phase 3 (Mar 2026) — Visual Consistency & UX
Band-specific feeling images, visual consistency pass, step-nav tap-to-scroll for mature bands, avatar overflow fixes, stale scenario title fixes, age picker redesign (big circles 3-8, pill bands 9+), exhaustive AgeBand switches.

## Known Issues

1. **CORS blocking production web** — Backend CORS config prevents frontend from reaching API in production web deployment. Mobile/desktop unaffected.

## Planned (v1.1+)

- SMS / Stripe age verification
- Guided meditation mode
- PDF story export
- Parent dashboard & analytics
- Push notifications
- Referral program
- Therapist portal

## Resources

- [Master Launch Plan](MASTER_LAUNCH_PLAN.md)
- [Business Plan](BUSINESS_PLAN.md)
- [COPPA Audit](COPPA_AUDIT.md)
- [Team Coordination](TEAM_COORDINATION.md)
