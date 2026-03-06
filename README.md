# Story Weaver

**Therapeutic AI storytelling for kids and families.** Story Weaver is a Flutter-based mobile and web application that generates personalized, age-appropriate stories using Google Gemini AI. The app focuses on emotional awareness and therapeutic storytelling to help children process feelings, build confidence, and develop social-emotional skills through engaging narratives.

> Built by a solo developer on a mission to make therapeutic tools accessible to every family. See [`BUSINESS_PLAN.md`](./BUSINESS_PLAN.md) for the full monetization strategy.

## 🎯 What This App Does

Story Weaver creates magical, personalized stories that help children ages 3–17+ understand and process their emotions. Parents and children work together to create custom heroes, select feelings, and generate therapeutic narratives that are both entertaining and emotionally supportive.

### Core Concept

The app combines:
- **Emotional intelligence** – Mood Magic picker and optional 3-level feelings wheel help children identify and express emotions
- **AI-powered storytelling** – Google Gemini 2.0 Flash generates age-calibrated narratives with rich therapeutic themes
- **Deep personalization** – Custom characters with avatars, archetypes, companions, goals, and personality sliders that persist across sessions
- **Visual engagement** – AI-generated illustrations (via OpenRouter/Gemini) and printable coloring pages
- **Flexible modes** – Wizard-guided creation, interactive choose-your-own-path, rhyme time, learn-to-read, multi-character adventures, and conflict scenarios

## 🌟 Complete User Journey

### 1. App Launch & Wizard Entry
Users land on the **4-step Wizard Story Screen** with a moon phase progress indicator. Saved characters load automatically from the backend.

### 2. Step 1: Hero Creator (`lib/screens/wizard_steps/hero_creator_step.dart`)
- **Basic info**: Name, archetype (Brave Explorer, Clever Thinker, Kind Helper, Spark of Mischief, etc.)
- **Appearance**: Hair, skin tone, eye color, outfit — feeds AI avatar generation
- **Personality**: Traits, goals, challenges, comfort items, sliders (Extrovert↔Introvert, Thinker↔Feeler, Planner↔Spontaneous)
- **My Buddies**: 7 magical companions (Dragon, Wise Owl, Shadow Cat, Star Dog, Unicorn, Clever Fox, Rockin' Robin) + custom pet photo upload — all shown as circular avatar buttons with precached images
- **Avatar**: Choose from 55+ pre-made curated avatars with shuffle; ✨ "Create a custom avatar that looks like me!" upsell leads to BYOK wizard for AI-generated custom portraits
- **World Bible**: Optional setting description that locks the story world for consistent world-building

### 3. Step 2: Feeling Selection (`lib/screens/wizard_steps/feeling_selection_step.dart`)
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

Feeling data influences story theme, hero challenge, coping strategy modeled, and the closing "Wisdom Gem."

### 4. Step 3: Companion Selection
Companions from Step 1 are confirmed; multi-character friends/siblings can be added.

### 5. Step 4: Magic Review & Launch (`lib/screens/wizard_steps/magic_review_step.dart`)
Summary card → tap **"Create My Story"** to start generation.

### 6. Story Generation Pipeline

**Frontend** (`lib/services/api_service_manager.dart`) sends payload to `POST /generate-story`.

**Backend** (`backend/services/story_service.py`) runs `AdvancedStoryEngine`:

1. **Age Calibration** – 7 age bands with hard-coded word/node constraints (never change without approval):

   | Age Band | Regular Story | Pick-a-Path Nodes |
   |----------|--------------|-------------------|
   | 3–4      | 200–650 words | 7–13 nodes |
   | 5–7      | 450–1200 words | 9–18 nodes |
   | 8–10     | 900–2400 words | 12–24 nodes |
   | 11–13    | 1300–3400 words | 14–26 nodes |
   | 13–15    | 1600–4500 words | 16–32 nodes |
   | 15–18    | 2000–6000 words | 18–38 nodes |
   | Adult    | 2000–7800 words | 18–44 nodes |

2. **Rich tone directives** – Each age band has a 6-part directive covering POV, sentence length, vocabulary level, emotional depth, structural expectations, and an explicit AVOID list.

3. **Therapeutic integration** – Feeling + intensity → plot arc, coping model, Wisdom Gem

4. **Safety guardrails** – No violence, weapons, bullying; age-appropriate language enforced

5. **Conflict Hook** – Optional scenario card conflict is wired through the full generation pipeline including interactive stories

6. **Gemini 2.0 Flash** call via `google-generativeai` Python SDK → parsed into title, pages, wisdom gem

### 7. Story Result Screen (`lib/story_result_screen.dart`)

**Display:**
- **Storybook Mode** — page-by-page with magic typewriter reveal effect + page flip animations
- Inline illustrations (if generated) shown above each page
- Breathing companion avatar in header

**Post-story action bar (sticky bottom):**
- 🎨 **Illustration teaser** (free users only) — locked shimmer card: "See this scene illustrated!" → opens upgrade bottom sheet
- 🪄 "Tell Me Another!" primary CTA
- Secondary: Re-read · Remix · Save · Share · Color

**Upgrade bottom sheet** (triggered by teaser):
- Full feature list: illustrations, custom avatars, unlimited stories, coloring pages
- Direct "Set Up Free Premium →" button → BYOK wizard

### 8. Illustration Generation
Sent to `POST /generate-illustration` → OpenRouter/Gemini `gemini-2.5-flash-image` → base64 returned, displayed inline.

### 9. Coloring Page Generation
Scene extraction → bold line-art → printable PDF → saved to Coloring Book library.

### 10. Subscription & BYOK System

| Tier | Price | Stories | Key Features |
|------|-------|---------|-------------|
| **Free** (Starter) | $0 | 10/month | Pre-made avatars, basic themes, no illustrations |
| **Adventurer** *(recommended)* | $4.99/mo · $39.99/yr | 10/day | All themes, illustrations, interactive stories |
| **Family** | $9.99/mo · $79.99/yr | Unlimited | Custom AI avatars, 4 child profiles, PDF export, priority queue |
| **BYOK** | Free | Unlimited | All Family features; user pays their own Gemini API costs (~$0.10–0.50/month) |

**BYOK flow:**
1. User taps any unlock prompt (upgrade dialog, avatar gallery footer, illustration teaser, Settings)
2. 3-step BYOK wizard: Benefits (custom avatars, illustrations, unlimited stories) → Get Key (AI Studio link) → Enter Key
3. Key stored in `flutter_secure_storage` — never sent to our servers
4. Flutter calls Gemini directly, bypassing backend (zero API cost to us)

**Grace period:** New users get 3 days of unlimited stories before free limits apply.

## 🏗️ Technical Architecture

### Frontend (Flutter)
```
lib/
├── main_story.dart                      # App entry, navigation, subscription load
├── screens/
│   ├── wizard_story_screen.dart         # 4-step wizard (primary entry)
│   ├── wizard_steps/
│   │   ├── hero_creator_step.dart       # Character + companions + avatar
│   │   ├── feeling_selection_step.dart  # Mood Magic + Feelings Wheel
│   │   ├── companion_selector_step.dart
│   │   └── magic_review_step.dart       # Review + generate
│   ├── byok_setup_wizard.dart           # 3-step BYOK setup (Benefits→Key→Enter)
│   ├── character_library_screen.dart
│   └── subscription_management_screen.dart
├── services/
│   ├── api_service_manager.dart         # Backend vs. direct Gemini routing
│   ├── grace_period_service.dart        # 3-day grace + monthly limit (10/month free)
│   ├── avatar_generation_service.dart
│   ├── progression_service.dart         # XP, levels, achievements
│   ├── isar_service.dart                # Local NoSQL cache (platform stubs: _io/_stub)
│   ├── audio_ambience_service.dart      # Ambient sound during reading
│   └── offline_story_service.dart
├── widgets/
│   ├── avatar_gallery_selector.dart     # 55+ curated avatars + custom avatar upsell
│   ├── storybook_page.dart              # Page-turning animation
│   ├── moon_phase_progress.dart         # Wizard progress indicator
│   ├── magical_typewriter_text.dart     # Story reveal animation
│   └── breathing_avatar.dart
├── dialogs/
│   └── upgrade_prompt_dialog.dart       # Limit reached → BYOK button + plans
├── models/
│   ├── subscription_models.dart         # Tier definitions + TierPricing
│   └── story_generation_result.dart
├── story_result_screen.dart             # Post-generation reader + teaser
└── config/
    └── flavor_config.dart               # dev/staging/production URL switching
```

**Key Technologies:**
- Flutter 3.22+ / Dart 3.8+
- **Riverpod** (`flutter_riverpod`) for all state management
- **Isar** for local story/character cache (web stub + native implementations)
- **flutter_secure_storage** for BYOK API keys
- **google_generative_ai** for direct Gemini calls (BYOK mode)
- **ElevenLabs TTS** (via backend) for narration
- **page_flip_builder** for storybook animations

### Backend (Python/Flask)
```
backend/
├── app.py                               # Flask factory, blueprints, middleware
├── routes/
│   ├── story_routes.py                  # /generate-story, /generate-interactive
│   ├── character_routes.py              # /save-character, /get-characters
│   ├── illustration_routes.py
│   ├── coloring_routes.py
│   ├── api_key_routes.py                # BYOK key validation + tier detection
│   ├── stripe_routes.py                 # Payment webhooks
│   └── admin_routes.py
├── services/
│   ├── story_service.py                 # AdvancedStoryEngine (AGE_CONSTRAINTS table)
│   ├── interactive_adventure_service.py # Pick-a-Path orchestration
│   ├── interactive_adventure_prompt_builder.py  # Per-segment word sizing
│   ├── avatar_generation_service.py
│   └── usage_tracking_service.py
├── utils/
│   └── app_helpers.py                   # Auth, tier resolution, rate limiting
├── config/__init__.py                   # Config classes (Development/Production/Testing)
├── models/
│   ├── user.py
│   ├── character.py
│   └── story.py
└── cost_tracking.py                     # Per-operation cost estimates
```

**Key Technologies:**
- Flask + Gunicorn (prod: `gunicorn -w 4 -b 0.0.0.0:$PORT wsgi:app`)
- SQLAlchemy ORM (SQLite dev / PostgreSQL prod)
- Flask-JWT-Extended for auth
- Flask-Limiter for rate limiting (free: 200/day; premium: higher)
- google-generativeai Python SDK (Gemini 2.0 Flash)
- OpenRouter for image generation (~$0.002–0.01/image)
- Sentry for crash reporting
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

## ✨ Core Features

### 1. Age-Aware Therapeutic Prompts
Seven age bands with hard-coded developmental constraints. Each band has a 6-part tone directive covering POV guidance, sentence length, vocabulary complexity, emotional depth, structural expectations, and explicit AVOID lists. **Do not change the word count constraints without explicit approval.**

### 2. Feelings-First Storytelling
Mood Magic + optional 3-level feelings wheel (based on Plutchik / Geneva Emotion Wheel research). Feeling data shapes the entire story arc — challenge type, coping model, Wisdom Gem at the end.

### 3. Interactive Stories (Pick-a-Path)
Per-segment word counts are calculated by dividing total story word count by estimated path depth (4–14 segments depending on age), preventing novel-length individual segments. `conflictHook` and `sensoryPalette` from scenario cards are fully wired through the route → service → prompt builder pipeline.

### 4. Custom AI Avatars
For BYOK/Premium users, Gemini generates a custom portrait from character appearance data. For free users, a "Create a custom avatar that looks like me!" ✨ button in the avatar gallery surfaces this as the key upgrade hook.

### 5. Illustration Teaser (Conversion Funnel)
Free users see a locked shimmer card after every story — "See this scene illustrated!" — leading to a full-feature unlock sheet with direct BYOK setup.

### 6. Offline Support
Stories cached in Isar (NoSQL, platform-conditional: `_io.dart` for native, `_stub.dart` for web). Read previously generated stories without internet.

### 7. Achievement System
XP, levels, story streaks, therapeutic milestones tracked via `ProgressionService` + `AchievementService`.

## ⚙️ Environment Configuration

| Flavor | Command | Backend URL |
|--------|---------|-------------|
| Development | `flutter run --dart-define=FLAVOR=development` | `http://127.0.0.1:5000` |
| Staging | `flutter run --dart-define=FLAVOR=staging` | `https://story-weaver-staging.up.railway.app` |
| Production | `flutter build web --release --dart-define=FLAVOR=production` | Railway prod URL |

Required backend env vars (in `backend/.env`):
```
GEMINI_API_KEY=...
SECRET_KEY=...
JWT_SECRET_KEY=...
```
Optional: `STRIPE_API_KEY`, `SENTRY_DSN`, `REDIS_URL`, `OPENROUTER_API_KEY`

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.22+
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

## 🧪 Testing

> ⚠️ **Always set `MOCK_TESTING_MODE=true` before running tests** — real API calls cost money.

```bash
# Backend (from repo root)
MOCK_TESTING_MODE=true python3 -m pytest tests/ -q   # 94 passing, 8 skipped

# Flutter
flutter test
flutter analyze   # rules in analysis_options.yaml
```

After changing Riverpod providers or Isar models:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## 🌐 Deployment

**Backend → Railway:**
```bash
cd backend && railway up
# Gunicorn: gunicorn -w 4 -b 0.0.0.0:$PORT wsgi:app
```

**Frontend → Netlify:**
```bash
flutter build web --release --dart-define=FLAVOR=production
# Deploy build/web/ to Netlify
```

CI/CD: `.github/workflows/cicd.yml` (main pipeline), `backend-tests.yml`, `backend-lint.yml`

## 📊 Usage Limits & Costs

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

## 🧭 Roadmap

**Completed ✅:**
- Core story generation (Gemini 2.0 Flash)
- 7-band age calibration with therapeutic tone directives
- Mood Magic + 3-level feelings wheel
- Wizard UI with moon phase progress
- Hero Creator with archetype cards (framed landscape images)
- My Buddies companion grid (circular avatar buttons, precached)
- Avatar gallery (55+ curated, shuffle, custom AI avatar upsell)
- World Bible setting field
- Storybook reader with page-flip, typewriter, ambient audio
- Illustration generation + coloring pages
- Interactive Pick-a-Path (per-segment word sizing fixed)
- Offline caching (Isar)
- Achievement + progression system
- ElevenLabs TTS narration + voice picker
- BYOK wizard with improved benefits copy (custom avatars lead)
- Illustration teaser for free users (locked shimmer + upgrade sheet)
- Grace period system (3 days unlimited → 10/month free)
- CI/CD pipeline (GitHub Actions → Railway + Netlify)

**In Progress 🔄:**
- Stripe payment integration (routes + webhooks exist, checkout flow needs end-to-end testing)
- Mobile app (iOS/Android) — currently web only

**Planned 📋:**
1. Story export to PDF storybook (with illustrations)
2. Referral system ("give a friend 1 week free")
3. Push notifications ("Time for tonight's bedtime story! 🌙")
4. Parent dashboard (emotion trends, reading stats, session exports)
5. Shareable story links / social sharing
6. Therapist collaboration portal
7. Seasonal theme packs

## 📚 Additional Documentation

| File | Purpose |
|------|---------|
| [`BUSINESS_PLAN.md`](./BUSINESS_PLAN.md) | Monetization strategy, pricing, marketing, revenue projections |
| [`TEAM_COORDINATION.md`](./TEAM_COORDINATION.md) | Session logs, development history |
| [`DEPLOYMENT_INSTRUCTIONS.md`](./DEPLOYMENT_INSTRUCTIONS.md) | Netlify deployment guide |
| [`DEPLOYMENT_CHECKLIST.md`](./DEPLOYMENT_CHECKLIST.md) | Pre-launch checklist |
| [`TESTING_AND_DEPLOYMENT.md`](./TESTING_AND_DEPLOYMENT.md) | QA procedures |

## 📄 License

MIT License — see LICENSE file for details.

## 🙏 Acknowledgments

- **Google Gemini** for powering story and image generation
- **Flutter** team for the amazing cross-platform framework
- **Plutchik** and the **Geneva Emotion Wheel** for feelings wheel design
- **Child development and therapeutic research** informing age-appropriate content guidelines

---

**Ready to create magical stories that help children understand their emotions?** 🌟

*Start the backend, launch the app, and watch as AI transforms feelings into adventures.*

