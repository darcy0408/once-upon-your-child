# Once Upon YOUR Child

*powered by Story Weaver*

**AI-powered social-emotional storytelling for kids and families.** Once Upon YOUR Child (technical platform name: Story Weaver) is a Flutter-based mobile and web application that generates personalized, age-appropriate stories. The app focuses on emotional awareness and feelings vocabulary to help children recognize and talk about their emotions, build confidence, and practice social-emotional skills through engaging narratives.

> An independent project making social-emotional learning tools accessible to every family. See [`BUSINESS_PLAN.md`](./BUSINESS_PLAN.md) for the full monetization strategy.

> **Note:** This app supports social-emotional learning. It is not therapy, counseling, or medical treatment, and makes no clinical claims.

**Live app:** `https://onceuponyourchild.app` · **Production backend:** `https://story-weaver-app-production.up.railway.app`

## What This App Does

Once Upon YOUR Child creates magical, personalized stories that help children ages 2 through adult understand and process their emotions. Parents and children work together to create custom heroes, select feelings, and generate therapeutic narratives that are both entertaining and emotionally supportive.

### Core Concept

The app combines:
- **Emotional intelligence** — Mood Magic picker and optional 3-level feelings wheel help children identify and express emotions
- **AI-powered storytelling** — OpenAI GPT-5 mini generates age-calibrated narratives with rich therapeutic themes (provider is configurable; Gemini was retired from the served kids' app for terms-of-service reasons)
- **Deep personalization** — Custom characters with avatars, archetypes, companions, goals, and personality sliders that persist across sessions
- **Age-specific visuals** — Dedicated character and UI asset sets for all 6 age bands (Sprout through Adult)
- **Visual engagement** — AI-generated illustrations and printable coloring pages
- **Flexible modes** — Wizard-guided creation, interactive choose-your-own-path, rhyme time, learn-to-read, multi-character adventures, Life Quests (formerly Big Feelings) therapeutic theme, and conflict scenarios

## Complete User Journey

### 1. App Launch & Age Gate
First-time users declare their age. Users under 13 are routed through a **Parental Consent** screen with a full Notice to Parents disclosure before accessing the app.

### 2. Wizard Entry
Users land on the **Wizard Story Screen** with a moon phase progress indicator. Saved characters load automatically from the backend. Younger bands use the page-based 4-step flow described below; the mature bands (Creator / Adolescent / Adult) use a streamlined **2-step** flow (Hero Creator → Magic Review) built on the CreativeBrief accordion.

### 3. Step 1: Hero Creator (`lib/screens/wizard_steps/hero_creator_step.dart`)
- **Basic info**: Name, archetype (Brave Explorer, Clever Thinker, Kind Helper, Spark of Mischief, etc.)
- **Appearance**: Hair, skin tone, eye color, outfit — feeds AI avatar generation
- **Personality**: Traits, goals, challenges, comfort items, sliders (Extrovert↔Introvert, Thinker↔Feeler, Planner↔Spontaneous)
- **My Buddies**: 7 magical companions (Dragon, Wise Owl, Shadow Cat, Star Dog, Unicorn, Clever Fox, Rockin' Robin) + custom pet photo upload with fallback chain
- **Avatar**: Age-band-specific character carousel with diverse representation across 6 ethnicities; ✨ "Create a custom avatar that looks like me!" upsell leads to BYOK wizard for AI-generated custom portraits
- **World Bible**: Optional setting description that locks the story world for consistent world-building

### 4. Step 2: Feeling Selection (`lib/screens/wizard_steps/feeling_selection_step.dart`)
Two modes:

**Mood Magic Picker** (default, lightweight):
- Core mood selection (Happy, Sad, Angry, Scared, Worried, Calm) with animated faces
- "Choose-a-Fix" coping strategy suggestions
- Age-gated vocabulary

**3-Level Feelings Wheel** (advanced):
- Level 1: 6 core emotions (Happy/Sad/Angry/Scared/Confused/Calm)
- Level 2: ~3–4 secondary feelings per core
- Level 3: Most granular tertiary feelings
- Intensity slider (1–10)

**Life Quests Mode** (formerly Big Feelings, therapeutic theme):
- Age-specific feeling vocabulary across Sprout / Explorer / Adventurer / Creator / Adolescent bands
- Routes to therapeutic interactive stories with social-emotional repair arcs

Feeling data influences story theme, hero challenge, coping strategy modeled, and the closing "Wisdom Gem."

### 5. Step 3: Companion Selection
Companions from Step 1 are confirmed; multi-character friends/siblings can be added.

### 6. Step 4: Magic Review & Launch (`lib/screens/wizard_steps/magic_review_step.dart`)
Summary card → tap **"Create My Story"** to start generation.

### 7. Story Generation Pipeline

**Frontend** (`lib/services/api_service_manager.dart`) sends payload to `POST /generate-story`.

**Backend** (`backend/services/story_service.py`) runs `AdvancedStoryEngine`:

1. **Age Calibration** — 6 age bands with hard-coded word/node constraints (never change without approval):

   | Age Band | Regular Story | Pick-a-Path Nodes |
   |----------|--------------|-------------------|
   | Sprout (2–5) | 200–650 words | 7–13 nodes |
   | Explorer (6–8) | 450–1200 words | 9–18 nodes |
   | Adventurer (9–11) | 900–2400 words | 12–24 nodes |
   | Creator (13–14) | 1300–3400 words | 14–26 nodes |
   | Adolescent (15–17) | 1600–4500 words | 16–32 nodes |
   | Adult (18+) | 2000–6000 words | 18–38 nodes |

2. **Rich tone directives** — Each age band has a 6-part directive covering POV, sentence length, vocabulary level, emotional depth, structural expectations, and an explicit AVOID list.

3. **Therapeutic integration** — Feeling + intensity → plot arc, coping model, Wisdom Gem

4. **Life Quests system** (formerly Big Feelings) — Per-age-band therapeutic prompt variants with believable social pressure, repair arcs, and hidden parent guidance layer

5. **Safety guardrails** — No violence, weapons, bullying; age-appropriate language enforced

6. **Conflict Hook** — Optional scenario card conflict is wired through the full generation pipeline including interactive stories

7. **OpenAI GPT-5 mini** call (story-text provider; `STORY_GEN_PROVIDER` selects the engine) → parsed into title, pages, wisdom gem

### 8. Story Result Screen (`lib/story_result_screen.dart`)

**Display:**
- **Storybook Mode** — page-by-page with magic typewriter reveal effect + page flip animations
- Inline illustrations (if generated) shown above each page
- Breathing companion avatar in header

**Post-story action bar (sticky bottom):**
- 🎨 **Illustration teaser** (free users only) — locked shimmer card: "See this scene illustrated!" → opens upgrade bottom sheet
- 🪄 "Tell Me Another!" primary CTA
- Secondary: Re-read · Remix · Save · Share · Color

### 9. Illustration Generation
Sent to `POST /generate-illustration` → **Cloudflare Workers AI (Flux Schnell, `@cf/black-forest-labs/flux-1-schnell`)** as the default $0 provider, with Replicate Flux Schnell as fallback → base64 returned, displayed inline.

### 10. Coloring Page Generation
Scene extraction → bold line-art → printable PDF → saved to Coloring Book library.

### 11. Subscription & BYOK System

| Tier | Price | Stories | Key Features |
|------|-------|---------|-------------|
| **Free** (Starter) | $0 | 10/month | Pre-made avatars, basic themes, no illustrations |
| **Adventurer** *(recommended)* | $4.99/mo · $39.99/yr | 10/day | All themes, illustrations, interactive stories |
| **Family** | $9.99/mo · $79.99/yr | Unlimited | Custom AI avatars, 4 child profiles, PDF export, priority queue |
| **BYOK** | Free | Unlimited | All Family features; user pays their own Gemini API costs (~$0.10–0.50/month) |

**BYOK flow:**
1. User taps any unlock prompt (upgrade dialog, avatar gallery footer, illustration teaser, Settings)
2. 3-step BYOK wizard: Benefits → Get Key → Enter Key
3. Key stored in `flutter_secure_storage` — never sent to our servers
4. Flutter calls Gemini directly, bypassing backend (zero API cost to us)

**Grace period:** New users get 3 days of unlimited stories before free limits apply.

## Technical Architecture

### Frontend (Flutter)
```
lib/
├── main_story.dart                          # App entry, navigation, subscription load
├── screens/
│   ├── wizard_story_screen.dart             # 4-step wizard (primary entry)
│   ├── wizard_steps/
│   │   ├── hero_creator_step.dart           # Character + companions + avatar carousel
│   │   ├── feeling_selection_step.dart      # Mood Magic + Feelings Wheel + Big Feelings
│   │   ├── companion_selector_step.dart
│   │   └── magic_review_step.dart           # Review + generate
│   ├── parental_consent_screen.dart         # COPPA Notice to Parents + consent
│   ├── parent_controls_screen.dart          # Screen time, Big Feelings guidance, data deletion
│   ├── character_library_screen.dart
│   └── subscription_management_screen.dart
├── services/
│   ├── api_service_manager.dart             # All backend API routing
│   ├── parental_consent_service.dart        # COPPA consent (local + backend sync)
│   ├── child_profile_service.dart           # Profiles + backend deletion
│   ├── grace_period_service.dart            # 3-day grace + monthly limit
│   ├── audio_ambience_service.dart          # Ambient sound during reading
│   └── app_tts_service.dart                 # ElevenLabs TTS narration
├── widgets/
│   ├── avatar_gallery_selector.dart         # Age-band character carousel + custom upsell
│   ├── storybook_page.dart                  # Page-turning animation
│   ├── moon_phase_progress.dart             # Wizard progress indicator
│   ├── magical_typewriter_text.dart         # Story reveal animation
│   └── magic_orb.dart                       # Breathing/loading animation
├── data/
│   ├── scenario_data.dart                   # 12 story scenarios with conflict hooks
│   └── feelings_wheel_data.dart             # Age-band feeling vocabulary
├── models/
│   ├── wizard_data.dart                     # Full wizard state model
│   └── subscription_models.dart             # Tier definitions + TierPricing
└── config/
    └── environment.dart                     # dev/staging/production URL switching
```

**Key Technologies:**
- Flutter 3.24+ / Dart 3.5+
- **Riverpod** (`flutter_riverpod`) for all state management
- **Isar** for local story/character cache (web stub + native implementations)
- **flutter_secure_storage** for auth tokens
- **ElevenLabs TTS** (via backend) for narration
- **page_flip_builder** for storybook animations

### Backend (Python/Flask)
```
backend/
├── app.py                                   # Flask factory, blueprints, middleware, error handlers
├── routes/
│   ├── story_routes.py                      # /generate-story, /generate-interactive, /task-status
│   ├── character_routes.py                  # Character CRUD + parent hidden context
│   ├── illustration_routes.py
│   ├── coloring_routes.py
│   ├── tts_routes.py                        # ElevenLabs TTS proxy
│   ├── avatar_routes.py                     # Custom + pet avatar generation
│   ├── api_key_routes.py                    # BYOK key validation + tier detection
│   ├── stripe_routes.py                     # Payment webhooks
│   └── utility_routes.py                    # Auth (anonymous + JWT), health checks
├── services/
│   ├── story_service.py                     # AdvancedStoryEngine (AGE_CONSTRAINTS table)
│   ├── interactive_adventure_service.py     # Pick-a-Path orchestration
│   ├── interactive_adventure_prompt_builder.py  # Big Feelings per-age-band variants
│   ├── avatar_generation_service.py         # Custom + pet avatar with fallback chain
│   └── usage_tracking_service.py
├── middleware/
│   └── auth.py                              # @require_auth, @require_owner, @require_admin
├── models/
│   ├── user.py
│   ├── character.py
│   ├── story.py
│   ├── consent_record.py                    # COPPA consent records
│   └── parent_hidden_context.py             # Per-profile Big Feelings guidance
└── config/__init__.py                       # Config classes (Development/Production/Testing)
```

**Key Technologies:**
- Flask + Gunicorn (prod: `gunicorn -w 4 -b 0.0.0.0:$PORT wsgi:app`)
- SQLAlchemy ORM (SQLite dev / PostgreSQL prod on Railway)
- Flask-JWT-Extended for auth
- Flask-Limiter + Redis for distributed rate limiting
- OpenAI Python SDK (GPT-5 mini — production story-text provider); Cloudflare Workers AI (Flux Schnell) for illustrations; OpenAI gpt-image-2 for avatars
- Sentry for crash reporting (with PII scrubbing before_send hook)
- Railway for deployment

### Import Dual-Path Pattern
All backend modules support running from repo root or inside `backend/`:
```python
try:
    from backend.services.story_service import ...
except ImportError:
    from services.story_service import ...
```
Always maintain both paths when adding new modules.

## Core Features

### 1. Age-Aware Therapeutic Prompts
Six age bands with hard-coded developmental constraints. Each band has a 6-part tone directive covering POV guidance, sentence length, vocabulary complexity, emotional depth, structural expectations, and explicit AVOID lists. **Do not change the word count constraints without explicit approval.**

### 2. Feelings-First Storytelling
Mood Magic + optional 3-level feelings wheel (based on Plutchik / Geneva Emotion Wheel research). Feeling data shapes the entire story arc — challenge type, coping model, Wisdom Gem at the end.

### 3. Life Quests Therapeutic Theme (formerly Big Feelings)
Dedicated therapeutic story mode with age-specific prompt variants across Sprout / Explorer / Adventurer / Creator / Adolescent bands. Stories model believable social pressure, emotional regulation, and repair without moralizing. Parents can privately configure hidden guidance (feeling, trigger, body signal, coping tool, repair goal) in Parent Controls — this shapes stories without the child ever seeing the parent's notes.

### 4. Age-Band Visual Assets
Each of the 6 age bands has a dedicated set of character and UI assets:
- Sprout (2-5): Warm, bubbly, illustration-heavy — soft Pixar 3D
- Explorer (6-8): Magical purple, sparkles — playful Pixar 3D
- Adventurer (9-11): Cosmic, book-like typography — high-energy Cosmic Chronicle
- Creator (13-14): Clean editorial, dark mode default — confident Pixar 3D
- Adolescent (15-17): Cinematic dark, teal accent — high-fidelity 3D
- Adult (18+): Refined fine-art cinematic

All character sets include diverse representation across Caucasian, Asian, Black, Hispanic, and South Asian ethnicities.

### 5. Interactive Stories (Pick-a-Path)
Per-segment word counts are calculated by dividing total story word count by estimated path depth (4–14 segments depending on age), preventing novel-length individual segments. `conflictHook` and `sensoryPalette` from scenario cards are fully wired through the route → service → prompt builder pipeline.

### 6. Custom AI Avatars
For BYOK/Premium users, OpenAI gpt-image-2 generates a custom portrait from character appearance data. Reference photo support: upload a photo and the AI generates a story-style portrait that looks like you. For free users, a "Create a custom avatar that looks like me!" ✨ button in the avatar gallery surfaces this as the key upgrade hook.

### 7. Pet Magical Companions
Upload a photo of your pet → the image model transforms it into a magical story companion. Robust fallback chain: primary image generation → text-based portrait generation → original photo fallback. Responses with original photo return HTTP 206 (partial content) so the UI can show an appropriate message.

### 8. Parent Controls & COPPA Compliance
- **Parental consent screen** with full Notice to Parents disclosure (lists Google Gemini, OpenRouter, ElevenLabs, Cloudflare Workers AI, Replicate, Stripe, Firebase, Railway)
- **Screen time controls**: daily limit, bedtime lockout
- **Life Quests Guidance** (formerly Big Feelings): hidden per-profile story shaping visible only to parents
- **Delete All My Data**: prominent button calling `DELETE /api/user/<id>/data` with confirmation
- Consent records synced to backend (`POST /api/user/<id>/consent`)
- Privacy Policy explicitly names all third-party services
- COPPA audit: `docs/COPPA_AUDIT.md`

### 9. Offline Support
Stories cached in Isar (NoSQL, platform-conditional: `_io.dart` for native, `_stub.dart` for web). Read previously generated stories without internet.

### 10. Achievement System
XP, levels, story streaks, therapeutic milestones tracked via `ProgressionService` + `AchievementService`.

## Environment Configuration

| Flavor | Command | Backend URL |
|--------|---------|-------------|
| Development | `flutter run --dart-define=FLAVOR=development` | `http://127.0.0.1:5000` |
| Staging | `flutter run --dart-define=FLAVOR=staging` | `https://story-weaver-staging.up.railway.app` |
| Production | `flutter build web --release --dart-define=FLAVOR=production` | `https://story-weaver-app-production.up.railway.app` |

Required backend env vars (in `backend/.env`):
```
GEMINI_API_KEY=...
SECRET_KEY=...
JWT_SECRET_KEY=...
```
Optional: `STRIPE_API_KEY`, `SENTRY_DSN`, `REDIS_URL`, `ELEVENLABS_API_KEY`

## Quick Start

### Prerequisites
- Flutter SDK 3.24+
- Python 3.11+
- Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)

### Installation

```bash
# 1. Clone
git clone https://github.com/darcy0408/story-weaver-app.git
cd story-weaver-app

# 2. Flutter deps
flutter pub get

# 3. Backend
cd backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 4. Configure
echo "GEMINI_API_KEY=your_key_here" > .env
echo "SECRET_KEY=dev-secret" >> .env
echo "JWT_SECRET_KEY=dev-jwt-secret" >> .env

# 5. Run backend (creates SQLite on first run)
python app.py   # http://127.0.0.1:5000

# 6. Run Flutter (new terminal)
cd ..
flutter run -d chrome
```

## Testing

> Always set `MOCK_TESTING_MODE=true` before running tests — real API calls cost money.

```bash
# Backend (from repo root)
MOCK_TESTING_MODE=true python3 -m pytest tests/ -q

# Flutter
flutter test
flutter analyze   # core lints (rules in analysis_options.yaml)

# Accessibility (WCAG 2.2 AA) custom lint gate — tools/a11y_lint/
# Runs the no_unlabelled_icon_button / no_unlabelled_form_field /
# no_unguarded_repeat rules. Exits non-zero when findings exist.
dart run custom_lint
```

> **a11y gate / analyzer pin (CQ-02):** the custom_lint a11y plugin only starts
> because `pubspec.yaml` pins `analyzer: 6.3.0` AND overrides
> `analyzer_plugin: 0.11.3`. The default-resolved `analyzer_plugin 0.11.2` calls
> `Element.enclosingElement3` / `NamedType.name`, symbols absent from analyzer
> 6.3.0, so the plugin fails to start ("Failed to start the plugins"). 0.11.3
> compiles against the 6.3.0 API. The analyzer is held at 6.3.0 because
> `isar_generator 3.1.0` caps `analyzer <6.0` (overridden) and `custom_lint 0.6.x`
> needs a compatible analyzer. The long-term fix that lifts the pin is an
> Isar 3→4 migration (out of scope here); until then, keep both overrides in sync.

After changing Riverpod providers or Isar models:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Deployment

**Backend → Railway:**
```bash
cd backend && railway up
# Gunicorn: gunicorn -w 4 -b 0.0.0.0:$PORT wsgi:app
```

**Frontend → Cloudflare Pages (`once-upon-your-child` project):**
Auto-deployed on every push to `main` by the `deploy-production` job in `.github/workflows/cicd.yml` (`wrangler pages deploy build/web`) — live at `https://onceuponyourchild.app`. The `web/_headers` (CSP) and `web/_redirects` (SPA fallback) files are bundled by `flutter build web`, so routing and security headers carry over automatically.
```bash
flutter build web --release --dart-define=FLAVOR=production
```
Merging to `main` *is* the deploy — no manual step. (Railway `grand-light` and Netlify are retired for the frontend.)

CI/CD: `.github/workflows/cicd.yml` (main pipeline — frontend tests/build + Cloudflare Pages deploy), `backend-tests.yml`, `backend-lint.yml`. Backend redeploys natively on Railway on push to `main`.

## Usage Limits & Costs

| Tier | Stories | Characters | Illustrations | Custom Avatars |
|------|---------|------------|---------------|----------------|
| Free | 10/month | 1 | ❌ | ❌ |
| Adventurer ($4.99/mo) | 10/day | 3 | ✅ (1/story) | ❌ |
| Family ($9.99/mo) | Unlimited | Unlimited | ✅ (3/story) | ✅ |
| BYOK (free) | Unlimited | Unlimited | ✅ | ✅ |

**Per-request API costs (server-side):**
- Story generation: ~$0.002
- Illustration: ~$0.005–0.01
- Custom avatar: ~$0.01
- Interactive story choice: ~$0.001

**BYOK users cost $0 to serve** (they pay Google directly).

## Roadmap

**Completed ✅:**
- Core story generation (OpenAI GPT-5 mini in production)
- 6-band age calibration with therapeutic tone directives
- Mood Magic + 3-level feelings wheel
- Wizard UI with moon phase progress
- Hero Creator with archetype cards
- My Buddies companion grid with pet photo upload + fallback chain
- Age-band specific character carousels with diverse representation (all 6 bands, 100% complete)
- Avatar gallery with custom AI portrait generation (reference photo support)
- World Bible setting field
- Storybook reader with page-flip, typewriter, ambient audio
- ElevenLabs TTS narration + voice picker
- Illustration generation + coloring pages
- Interactive Pick-a-Path (per-segment word sizing)
- Life Quests therapeutic theme (formerly Big Feelings; per-band variants across Sprout / Explorer / Adventurer / Creator / Adolescent)
- Hidden Parent Layer (private per-profile story guidance)
- Stripe payment integration (Free / Premium / Family tiers + 14-day trial; checkout + webhooks live)
- COPPA compliance: Notice to Parents, consent backend sync, Delete All My Data
- Parental Controls: screen time, bedtime lockout, photo avatar toggle
- Offline caching (Isar)
- Achievement + progression system
- BYOK wizard with benefits copy
- Illustration teaser for free users (locked shimmer + upgrade sheet)
- Grace period system (3 days unlimited → 10/month free)
- Rate limiting (Flask-Limiter + Redis, per-route limits)
- Authorization ownership checks (IDOR prevention)
- Sentry crash reporting with PII scrubbing
- CI/CD pipeline (GitHub Actions → Cloudflare Pages frontend + Railway backend)
- Production backend live and verified

**In Progress 🔄:**
- Mobile app (iOS/Android) store deployment — IAP migration in progress (web Stripe live)
- TTS overflow tier (Gemini Flash TTS between ElevenLabs and Edge, shipped 2026-05-21)

**Planned 📋:**
1. **v1.1 — Verifiable parental consent**: SMS OTP (Twilio) or $0.50 Stripe micro-charge — parent picks one at setup, never asked again
2. Guided Meditation feature — personalized age-band meditations via quick path or scenario carousel (full spec: `docs/GUIDED_MEDITATION_V2_SPEC.md`)
3. Story export to PDF storybook (with illustrations)
4. Parent dashboard (emotion trends, reading stats, session exports)
5. Push notifications ("Time for tonight's bedtime story! 🌙")
6. Referral system ("give a friend 1 week free")
7. Shareable story links / social sharing
8. Therapist collaboration portal
9. Seasonal theme packs

## Additional Documentation

| File | Purpose |
|------|---------|
| [`BUSINESS_PLAN.md`](./BUSINESS_PLAN.md) | Monetization strategy, pricing, marketing, revenue projections |
| [`TEAM_COORDINATION.md`](./TEAM_COORDINATION.md) | Session logs, development history |
| [`PRIVACY_POLICY.md`](./PRIVACY_POLICY.md) | Privacy policy with third-party disclosures |
| [`docs/COPPA_AUDIT.md`](./docs/COPPA_AUDIT.md) | COPPA compliance audit and v1.1 verification plan |
| [`docs/GUIDED_MEDITATION_V2_SPEC.md`](./docs/GUIDED_MEDITATION_V2_SPEC.md) | Full spec for v2 meditation feature |
| [`DEPLOYMENT_INSTRUCTIONS.md`](./DEPLOYMENT_INSTRUCTIONS.md) | Netlify deployment guide |
| [`DEPLOYMENT_CHECKLIST.md`](./DEPLOYMENT_CHECKLIST.md) | Pre-launch checklist |
| [`TESTING_AND_DEPLOYMENT.md`](./TESTING_AND_DEPLOYMENT.md) | QA procedures |

## License

MIT License — see LICENSE file for details.

## Acknowledgments

- **OpenAI** for story-text and avatar generation
- **Cloudflare Workers AI** (Flux Schnell) for story illustrations
- **ElevenLabs** for text-to-speech narration
- **Flutter** team for the amazing cross-platform framework
- **Plutchik** and the **Geneva Emotion Wheel** for feelings wheel design
- **Child development and therapeutic research** informing age-appropriate content guidelines

---

**Ready to create magical stories that help children understand their emotions?** 🌟

*Start the backend, launch the app, and watch as AI transforms feelings into adventures.*
