# Story Weaver

Therapeutic AI storytelling for kids and families. Story Weaver pairs a Flutter front end with a Python/Flask backend and Google Gemini to generate age-appropriate, feelings-aware stories, illustrations, and coloring pages.

## ✨ Core Features

- **Feelings-first storytelling** – 3-level feelings wheel + intensity slider tailor every prompt to a child’s current emotion.
- **Dual story modes** – therapeutic narratives when a feeling is selected, adventure mode when it’s skipped.
- **Age-aware prompts** – automatic length/vocabulary guidelines for ages 3–17+ (Learning-to-Read rhyming mode for ages 4–7).
- **Rich character creation** – goals, challenges, traits, comfort items, personality sliders, and companions.
- **Interactive & multi-character stories** – choose-your-own adventures plus sibling/friend scenarios.
- **Illustrations & coloring pages** – AI-generated art and printable coloring sheets from any story segment.
- **Subscriptions & BYOK** – run on the hosted backend or let premium users bring their own Gemini API key.

## 🏗️ Architecture

```
flutter/                    # Cross-platform app (web, mobile, desktop)
└── lib/
    ├── main_story.dart     # Story creator UI & navigation
    ├── services/           # API, progression, subscription, TTS, etc.
    ├── feelings_wheel_*    # Hierarchical emotion picker & data
    └── ...
backend/
└── app.py                  # Flask API + Gemini orchestration
```

- **Frontend:** Flutter 3.22+, Dart 3.8+.
- **Backend:** Python 3.11 (Flask + SQLAlchemy + google-generativeai).
- **AI:** Google Gemini for stories, illustrations, coloring pages, and TTS.

## ✅ Prerequisites

| Tool            | Version/Notes                |
|-----------------|-----------------------------|
| Flutter SDK     | 3.22 or newer (`flutter --version`) |
| Dart SDK        | ships with Flutter          |
| Python          | 3.11 (for backend)          |
| pip / venv      | recommended for backend     |
| Node/NPM        | optional (Railway CLI, etc.)|

## 🚀 Quick Start

1. **Clone & install Flutter deps**
   ```bash
   git clone https://github.com/<you>/story-weaver-app.git
   cd story-weaver-app
   flutter pub get
   ```
2. **Set up backend**
   ```bash
   cd backend
   python -m venv .venv && source .venv/bin/activate  # or .venv\Scripts\activate on Windows
   pip install -r requirements.txt
   cp .env.example .env  # create your .env
   # edit .env with GEMINI_API_KEY=your_key_here
   python app.py
   ```
   The Flask server listens on `http://127.0.0.1:5000` (configurable).
3. **Run Flutter app**
   ```bash
   cd ..
   flutter run -d chrome          # or any Flutter-supported device
   ```
4. **Generate a story**
   - Create/select a character.
   - (Optional) walk through the feelings wheel.
   - Tap **Create My Story**; the story result view includes achievements, illustrations, and sharing.

## ⚙️ Environment Configuration

The app now uses build flavors defined in `lib/config/flavor_config.dart`. Pick the backend + branding at build time with `--dart-define=FLAVOR=...`:

| Flavor | Command | Backend | Banner |
|--------|---------|---------|--------|
| Development | `flutter run --dart-define=FLAVOR=development` | `http://127.0.0.1:5000` | `DEV` |
| Staging | `flutter run --dart-define=FLAVOR=staging` | `https://story-weaver-staging.up.railway.app` | `STAGING` |
| Production | `flutter build web --release --dart-define=FLAVOR=production` | `https://story-weaver-app-production.up.railway.app` | none |

Additional defines:
- `--dart-define=CUSTOM_BACKEND_URL=https://...` overrides any flavor backend (handy for feature branches).
- `--dart-define=DEV_GEMINI_API_KEY=...` / `STAGING_GEMINI_API_KEY` / `PROD_GEMINI_API_KEY` inject managed Gemini keys if desired.

`Environment.backendUrl` and the rest of the helpers automatically read the active flavor—avoid hardcoding URLs outside that helper.

## 🌐 Building & Deployment

### Flutter Web Release
```bash
flutter build web --release
```
Outputs land in `build/web/` and can be hosted on Netlify, Vercel, Firebase Hosting, etc. See `DEPLOYMENT_INSTRUCTIONS.md` for Netlify steps.

### Backend (Railway example)
1. `cd backend`
2. `railway login` and `railway init`
3. `railway variables set GEMINI_API_KEY=...`
4. `railway up`

More production notes live in:
- `GEMINI_DEPLOYMENT_TASK.md`
- `DEPLOYMENT_CHECKLIST.md`
- `TESTING_AND_DEPLOYMENT.md`

## 🧠 Key Workflows

| Workflow | Files |
|----------|-------|
| Feelings wheel | `lib/feelings_wheel_screen.dart`, `lib/pre_story_feelings_dialog.dart`, `lib/feelings_wheel_data.dart` |
| Story prompts  | `lib/services/api_service_manager.dart`, `lib/services/story_complexity_service.dart`, `backend/app.py` |
| Subscriptions & usage limits | `lib/subscription_service.dart`, `lib/services/progression_service.dart`, `lib/services/achievement_service.dart` |
| Offline caching | `lib/storage_service.dart`, `lib/offline_stories_screen.dart` |
| Illustrations & coloring | `lib/story_result_screen.dart`, `lib/story_illustration_service.dart`, backend endpoints |

## 🧪 Testing

- Frontend: `flutter test`
- Backend: `pytest backend/tests` *(create this folder to add unit/integration coverage)*
- Manual QA checklist: `TESTING_AND_DEPLOYMENT.md`

## 🧭 Roadmap

High-impact next steps (see `codex_improvements.md` for details):
1. Secure storage for BYOK/subscription data
2. Crash/error reporting (Sentry/Crashlytics)
3. Integration tests for story creation + paywall flows
4. Backend task queue + Postgres migration
5. Parent dashboard & enhanced monetization

## 📚 Additional Docs

- `GEMINI_CODEX_TASKS.md` – parallel task board for AI agents.
- `TASK_PLANS.md` – multi-week milestone planning.
- `SESSION_HANDOFF.md` – stateful notes between contributors.

---
Happy storytelling! ✨
