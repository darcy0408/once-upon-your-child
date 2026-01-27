# Story Weaver

**Therapeutic AI storytelling for kids and families.** Story Weaver is a Flutter-based mobile and web application that generates personalized, age-appropriate stories using Google Gemini AI. The app focuses on emotional awareness and therapeutic storytelling to help children process feelings, build confidence, and develop social-emotional skills through engaging narratives.

## 🎯 What This App Does

Story Weaver creates magical, personalized stories that help children ages 3-17+ understand and process their emotions. Parents and children work together to create custom heroes, select feelings, and generate therapeutic narratives that are both entertaining and emotionally supportive.

### Core Concept

The app combines:
- **Emotional intelligence** – "Mood Magic" picker and optional 3-level feelings wheel help children identify and express emotions
- **AI-powered storytelling** – Google Gemini generates age-calibrated narratives with therapeutic themes
- **Rich personalization** – Custom characters with avatars, traits, companions, and goals that persist across sessions
- **Visual engagement** – AI-generated illustrations (Gemini Imagen 3) and printable coloring pages
- **Flexible modes** – Wizard-guided creation, quick stories, multi-character adventures, interactive choose-your-own-path tales, and conflict resolution scenarios

## 🌟 Complete User Journey

### 1. **App Launch & Character Library**
When users open the app, they land on the **Wizard Story Screen** – a magical 4-step guided experience with a moon phase progress indicator. The wizard loads any saved characters from the backend automatically.

If this is their first time, they'll create a new character. Returning users can select from their character library or create new heroes.

### 2. **Step 1: Hero Creator** (`lib/screens/wizard_steps/hero_creator_step.dart`)
The first wizard step allows users to create a detailed character:
- **Basic Info**: Name, age (3-17+), gender, archetype (Brave Explorer, Clever Thinker, Kind Helper, etc.)
- **Appearance**: Hair style, skin tone, eye color, outfit style – used to generate AI avatars
- **Personality Traits**: Compassionate, curious, resilient, determined – affects story tone
- **Goals & Challenges**: What the character wants to achieve and what obstacles they face
- **Comfort Items**: Security blankets, favorite toys, or special objects that appear in stories
- **Personality Sliders**: Extrovert/Introvert, Thinker/Feeler, Planner/Spontaneous

All character data is saved to the backend via `POST /save-character` and stored in a SQLite database (production uses PostgreSQL).

**Avatar Generation**: When a character is created with appearance details, the system can optionally generate a custom AI avatar using Gemini Imagen 3. This happens asynchronously via `lib/services/avatar_generation_service.dart` and `backend/services/avatar_generation_service.py`.

### 3. **Step 2: Feeling Selection** (`lib/screens/wizard_steps/feeling_selection_step.dart`)
This is the heart of the therapeutic experience. Children can choose between two emotion selection modes:

**Mood Magic Picker** (Default - Lightweight):
A streamlined emotion selector featuring:
- Core mood selection (Happy, Sad, Angry, Scared, Worried, Calm)
- Expression faces that animate based on selection
- "Choose-a-Fix" workflow suggesting coping strategies
- Age-gated vocabulary (simpler terms for younger children)

**3-Level Feelings Wheel** (Advanced Option):
For deeper emotional exploration:

**Level 1 - Core Emotions** (6 categories with distinct colors):
- Happy (yellow) – Joy, Contentment, Pride
- Sad (blue) – Loneliness, Disappointment, Grief
- Angry (red) – Frustrated, Annoyed, Furious
- Scared (purple) – Worried, Anxious, Terrified
- Confused (teal) – Uncertain, Surprised, Curious
- Calm (green) – Peaceful, Safe, Relaxed

**Level 2 - Secondary Feelings**: Each core emotion expands into 3-4 more specific feelings
**Level 3 - Tertiary Feelings**: The most precise emotional granularity

After selecting a feeling, children use an **intensity slider** (1-10) to express how strongly they're experiencing this emotion.

**Why This Matters**: The feelings data is sent to the backend where it influences:
- Story themes and plot arcs
- Character challenges and growth opportunities
- Therapeutic messaging and coping strategies
- The "Wisdom Gem" – a gentle lesson tailored to the emotion

Users can also **skip** mood selection to generate non-therapeutic adventure stories.

### 4. **Step 3: Companion Selection** (`lib/screens/wizard_steps/companion_selector_step.dart`)
Children choose who joins their hero on the adventure:
- **Companions**: Magical creatures, animals, robots, or imaginary friends
- **Real Friends/Siblings**: Multi-character mode allows adding other saved characters

This step feeds into multi-character story generation or adds supportive NPCs to single-character tales.

### 5. **Step 4: Magic Review & Launch** (`lib/screens/wizard_steps/magic_review_step.dart`)
The final wizard screen shows a beautiful summary of all selected options:
- Character card with avatar and traits
- Selected feeling (if any) with color and emoji
- Chosen companion(s)
- Story theme preview

Tapping **"Create My Story"** triggers the story generation pipeline.

### 6. **Story Generation Pipeline**

When the user confirms, the Flutter app sends a comprehensive payload to the backend:

**Frontend** (`lib/services/api_service_manager.dart`):
```dart
POST /generate-story
{
  "characterName": "Luna",
  "age": 7,
  "theme": "Adventure",
  "selectedFeeling": {
    "core": "Happy",
    "secondary": "Joyful",
    "tertiary": "Excited",
    "intensity": 8
  },
  "characterTraits": ["curious", "brave"],
  "companion": "magical_unicorn",
  "storyDuration": "5min", // or "10min"
  "interactiveMode": false
}
```

**Backend Processing** (`backend/services/story_service.py`, `backend/routes/story_routes.py`):

1. **Age Calibration**: The `AdvancedStoryEngine` class applies age-appropriate guidelines:
   - Ages 3-5: 100-150 words, simple CVC + sight words, rhyming format
   - Ages 6-8: 150-250 words, basic phonics, short sentences, humor required
   - Ages 9-12: 250-400 words, grade-level vocabulary, emotional arcs
   - Ages 13-15: 400-600 words, advanced vocabulary, identity exploration
   - Ages 16+: 600-800 words, literary prose, philosophical themes

2. **Therapeutic Integration**: If a feeling was selected:
   - The prompt includes the feeling, intensity, and triggers
   - Gemini generates a story where the hero faces a challenge related to that emotion
   - The narrative models healthy coping strategies
   - A "Wisdom Gem" (therapeutic insight) is included at the end

3. **Safety Guardrails**: All prompts include strict safety rules:
   - No violence, weapons, scary content, or bullying
   - Focus on kindness, courage, teamwork, problem-solving
   - Age-appropriate language and concepts
   - No invented family members unless specified

4. **Gemini API Call**: The backend uses `google-generativeai` Python SDK to call Gemini 2.0 Flash:
   ```python
   model = genai.GenerativeModel('gemini-2.0-flash-exp')
   response = model.generate_content(prompt)
   ```

5. **Story Parsing**: The response is parsed into structured data:
   - Title
   - Full story text
   - Pages (for storybook UI with page-turning animations)
   - Wisdom Gem (therapeutic takeaway)
   - Suggested illustration prompts

6. **Database Storage**: The story is saved to the backend's SQLite/PostgreSQL database with user ID, character ID, timestamps, and metadata.

7. **Response**: The backend returns JSON with the complete story data.

### 7. **Story Result Screen** (`lib/story_result_screen.dart`)

The generated story appears in a beautiful, feature-rich viewer:

**Display Options**:
- **Storybook Mode**: Page-by-page display with page-turning animations (`lib/widgets/storybook_page.dart`)
- **Scroll Mode**: Continuous reading with progress indicator
- **Reader Mode**: Dedicated reading view with Text-to-Speech support

**Key Features**:
- **Achievements**: First story, story streak, therapeutic story milestones
- **Story Rating**: 1-5 stars with optional feedback
- **Sharing**: Export story as text or PDF
- **Offline Saving**: Stories are cached locally using Isar database for offline access

**Action Buttons**:
1. **Generate Illustrations** – Create AI images for the story
2. **Create Coloring Page** – Generate printable coloring sheets
3. **Continue Adventure** – Generate a sequel with the same character
4. **Save to Library** – Bookmark for later re-reading

### 8. **Illustration Generation** (`lib/story_illustration_service.dart`, `backend/routes/illustration_routes.py`)

When users tap "Generate Illustrations":

1. **Frontend** sends story segments to backend:
   ```dart
   POST /generate-illustration
   {
     "storySegment": "Luna discovered a shimmering door...",
     "characterDescription": "7-year-old girl with curly brown hair...",
     "storyContext": "magical adventure in enchanted forest"
   }
   ```

2. **Backend** uses Gemini Imagen 3 to generate illustrations:
   - Imagen 3 is Google's state-of-the-art image generation model
   - Prompts are enhanced with safety filters and art style guidance
   - Images are returned as base64 data or cloud URLs

3. **Frontend** displays illustrations inline with story text in the storybook viewer

**Art Styles Available**:
- Watercolor storybook
- Digital illustration
- Cartoon style
- Realistic painting

### 9. **Coloring Page Generation** (`lib/coloring_book_service.dart`, `backend/routes/coloring_routes.py`)

Similar to illustrations, but optimized for black-and-white line art:

1. The system extracts key scenes from the story
2. Generates simple, bold outlines suitable for coloring
3. Returns printable PDF format
4. Saved to coloring book library for later printing

### 10. **Subscription & BYOK System** (`lib/subscription_service.dart`, `backend/models/user.py`)

Story Weaver offers four tiers:

**Free Tier**:
- 10 stories per day (100 per month)
- 2 characters maximum
- Basic illustrations (5 per month)
- Standard story length (5-minute stories)

**Premium Tier** ($9.99/month or $79.99/year):
- 20 stories per day
- 5 characters maximum
- Unlimited illustrations
- Extended story lengths (5 or 10-minute stories)
- Interactive choose-your-own-adventure mode
- Multi-character stories
- Story export features
- Ad-free experience

**Family Tier** ($19.99/month or $159.99/year):
- Unlimited stories
- 20 characters maximum
- All Premium features
- Priority support
- Early access to new features

**BYOK (Bring Your Own Key)**:
- Users can provide their own Google Gemini API key
- All generation costs are billed directly to their Google Cloud account
- No monthly limits
- Stored securely using `flutter_secure_storage`
- Setup wizard guides users through API key configuration
- When BYOK is active, the Flutter app calls Gemini directly, bypassing the backend

**Subscription Management**:
- Stored locally in `SharedPreferences` for offline access
- Synced with backend via `POST /subscription-status`
- Grace period system allows continued access if payment fails temporarily
- Usage tracking prevents abuse

### 11. **Additional Story Modes**

**Quick Story Mode** (`lib/quick_story_screen.dart`):
- Simplified creation flow
- Pre-selected themes with beautiful image cards
- Minimal configuration
- Fast generation for spontaneous storytelling

**Multi-Character Mode** (`lib/multi_character_screen.dart`):
- Create stories featuring siblings, friends, or multiple heroes
- Each character gets development and dialogue
- Promotes social skills and cooperation themes

**Pick-A-Path Adventure** (`lib/pick_a_path_adventure_screen.dart`):
- Interactive branching narratives
- 3-5 choice points throughout the story
- Multiple endings based on decisions
- Replay value and decision-making practice

**Conflict Resolution Stories** (`lib/conflict_resolution_stories.dart`):
- Pre-built scenarios for common childhood conflicts
- Sibling rivalry, sharing, friendship struggles, playground dynamics
- Guided therapeutic narratives with modeled solutions
- Age-appropriate conflict resolution strategies

## 🏗️ Technical Architecture

### Frontend (Flutter)
```
lib/
├── main_story.dart                 # Main app entry point
├── screens/
│   ├── wizard_story_screen.dart    # 4-step wizard (primary entry)
│   ├── wizard_steps/               # Individual wizard steps
│   │   ├── hero_creator_step.dart
│   │   ├── feeling_selection_step.dart
│   │   ├── companion_selector_step.dart
│   │   └── magic_review_step.dart
│   ├── character_library_screen.dart
│   ├── character_selection_screen.dart
│   ├── byok_setup_wizard.dart      # BYOK API key setup
│   ├── story_reader_screen.dart    # TTS-enabled reader
│   └── subscription_success_screen.dart
├── services/
│   ├── api_service_manager.dart    # Backend/direct API routing
│   ├── story_complexity_service.dart
│   ├── subscription_service.dart
│   ├── avatar_generation_service.dart
│   ├── character_template_service.dart # Quick-start templates
│   ├── progression_service.dart    # XP, levels, achievements
│   ├── achievement_service.dart
│   ├── isar_service.dart           # Local NoSQL database
│   ├── story_narrator.dart         # TTS narration
│   └── offline_story_service.dart
├── widgets/
│   ├── storybook_page.dart         # Page-turning animation
│   ├── expanding_feelings_wheel.dart
│   ├── mood_magic_picker.dart      # Lightweight mood selector
│   ├── moon_phase_progress.dart
│   └── user_friendly_error_dialog.dart
├── models/
│   ├── models.dart                 # Character, Story models
│   ├── story_generation_result.dart
│   ├── generated_avatar.dart
│   └── subscription_models.dart    # Free, Premium, Family tiers
├── story_result_screen.dart        # Post-generation UI
├── conflict_resolution_stories.dart # Pre-built conflict scenarios
├── feelings_wheel_data.dart        # 3-level emotion hierarchy
└── config/
    └── environment.dart             # Backend URL configuration
```

**Key Technologies**:
- **Flutter 3.22+** with Dart 3.8+
- **http** package for REST API calls
- **Isar** database for local story/character caching
- **SharedPreferences** for user settings
- **flutter_secure_storage** for API keys (BYOK)
- **google_generative_ai** for direct Gemini calls (BYOK mode)
- **flutter_tts** for text-to-speech narration
- **path_provider** for file storage
- **share_plus** for story sharing

### Backend (Python/Flask)
```
backend/
├── app.py                          # Flask app factory, Sentry init, middleware
├── routes/
│   ├── story_routes.py             # /generate-story, /interactive-choice
│   ├── character_routes.py         # /save-character, /get-characters
│   ├── illustration_routes.py      # /generate-illustration
│   ├── coloring_routes.py          # /generate-coloring-page
│   ├── stripe_routes.py            # Payment webhook endpoints
│   └── admin_routes.py             # Admin panel
├── services/
│   ├── story_service.py            # AdvancedStoryEngine class
│   ├── story_generation_service.py
│   ├── story_duration_service.py   # 5-min vs 10-min configs
│   ├── avatar_generation_service.py
│   └── stripe_service.py           # Payment processing
├── models/
│   ├── user.py                     # SQLAlchemy User model
│   ├── character.py                # Character model
│   ├── story.py                    # Story model
│   └── achievement.py              # Achievement tracking
├── database.py                     # SQLAlchemy setup
├── config.py                       # Environment configs
└── celery_config.py                # Async task queue
```

**Key Technologies**:
- **Flask** web framework
- **SQLAlchemy** ORM (SQLite dev, PostgreSQL prod)
- **Flask-CORS** for cross-origin requests
- **Flask-JWT-Extended** for authentication
- **Flask-Limiter** for rate limiting
- **google-generativeai** Python SDK
- **Celery** for async tasks (illustration generation)
- **Sentry** for crash reporting and monitoring
- **Railway** for deployment

### Database Schema

**users** table:
- id, email, created_at
- subscription_tier (free/premium/byok)
- gemini_api_key (encrypted)
- stories_created_this_month
- total_stories_created

**characters** table:
- id, user_id, name, age, role, avatar
- personality_traits (JSON)
- goals, challenges, comfort_items
- created_at, updated_at

**stories** table:
- id, user_id, character_id
- title, content, pages (JSON)
- wisdom_gem, theme
- feeling_data (JSON)
- illustrations (JSON array)
- created_at, duration_minutes

**user_achievements** table:
- id, user_id, achievement_id
- unlocked_at, progress

## ✨ Core Features

### 1. Feelings-First Storytelling
The Mood Magic picker and optional 3-level feelings wheel are based on established emotion research (Plutchik, Geneva Emotion Wheel). Children learn emotional granularity by identifying their current mood, with age-appropriate vocabulary that adapts to the child's developmental stage. This promotes emotional literacy and self-awareness.

### 2. Age-Aware Prompts
Every story is calibrated for developmental stage:
- **Learning to Read Mode** (ages 4-7): Rhyming, repetitive frames, CVC words
- **Humor Integration** (ages 5-8): Sound effects, silly names, gentle physical comedy
- **Emotional Complexity** (ages 9+): Character growth, moral dilemmas, layered plots

### 3. Therapeutic Integration
When a feeling is selected, the story becomes a therapeutic tool:
- **Validation**: "It's okay to feel [emotion]"
- **Modeling**: Hero experiences similar feelings and works through them
- **Coping Skills**: Breathing, talking to trusted adults, problem-solving
- **Reframing**: Finding silver linings or growth in challenges
- **Wisdom Gem**: Age-appropriate life lesson

### 4. Interactive Stories
Premium users can create choose-your-own-adventure stories:
- 3-5 decision points
- Branching plot paths
- Multiple endings
- Choices reflect values (kindness vs. speed, caution vs. bravery)

### 5. Character Persistence & Evolution
Characters are saved both to the backend and cached locally (via Isar database), ensuring they persist across app sessions and work offline. Characters can:
- Level up based on stories completed
- Earn achievements (First Adventure, Feelings Explorer, etc.)
- Unlock new traits and customization options
- Sync seamlessly between devices when online
- Be created from templates for quick starts

### 6. Multi-Character Stories
Perfect for families with multiple children:
- Each child creates their own character
- Stories feature all siblings working together
- Balanced screen time for each character
- Promotes cooperation and conflict resolution

### 7. Offline Support
Stories are cached locally using Isar database:
- Read previously generated stories without internet
- Sync new stories when connection is restored
- Illustrations are stored as base64 in local database

### 8. Parent Dashboard (Roadmap)
Future feature for parents to:
- View emotional trends over time
- Track reading progress
- Set screen time limits
- Approve new characters
- Export stories for therapy sessions

## ⚙️ Environment Configuration

The app uses build flavors defined in `lib/config/flavor_config.dart`:

| Flavor | Command | Backend URL | Banner |
|--------|---------|-------------|--------|
| Development | `flutter run --dart-define=FLAVOR=development` | `http://127.0.0.1:5000` | `DEV` |
| Staging | `flutter run --dart-define=FLAVOR=staging` | `https://story-weaver-staging.up.railway.app` | `STAGING` |
| Production | `flutter build web --release --dart-define=FLAVOR=production` | `https://story-weaver-app-production.up.railway.app` | none |

**Override Backend**:
```bash
flutter run --dart-define=CUSTOM_BACKEND_URL=https://my-custom-backend.com
```

**Inject API Keys**:
```bash
flutter run --dart-define=DEV_GEMINI_API_KEY=your_key_here
```

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK**: 3.22+
- **Dart SDK**: 3.8+ (included with Flutter)
- **Python**: 3.11+
- **Google Gemini API Key**: Get from [Google AI Studio](https://aistudio.google.com/app/apikey)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/story-weaver-app.git
   cd story-weaver-app
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set up backend**:
   ```bash
   cd backend
   python -m venv .venv
   source .venv/bin/activate  # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

4. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env and add:
   # GEMINI_API_KEY=your_gemini_api_key_here
   ```

5. **Initialize database**:
   ```bash
   python app.py
   # This creates the SQLite database on first run
   ```

6. **Run backend**:
   ```bash
   python app.py
   # Runs on http://127.0.0.1:5000
   ```

7. **Run Flutter app** (new terminal):
   ```bash
   cd ..
   flutter run -d chrome
   # Or for mobile: flutter run -d android / flutter run -d ios
   ```

8. **Create your first story**:
   - Create a character in Step 1
   - Select a feeling in Step 2 (or skip for adventure mode)
   - Choose a companion in Step 3
   - Review and generate in Step 4
   - Wait 10-15 seconds for generation
   - Read, illustrate, and share your story!

## 🧪 Testing

**Frontend**:
```bash
flutter test
```

**Backend**:
```bash
cd backend
pytest tests/
```

**Manual QA Checklist**: See `TESTING_AND_DEPLOYMENT.md`

## 🌐 Deployment

### Flutter Web (Netlify)
```bash
flutter build web --release --dart-define=FLAVOR=production
# Deploy build/web/ to Netlify
```

### Backend (Railway)
```bash
cd backend
railway login
railway init
railway variables set GEMINI_API_KEY=your_key
railway up
```

See `DEPLOYMENT_INSTRUCTIONS.md` and `DEPLOYMENT_CHECKLIST.md` for complete guides.

## 📊 Usage Limits

| Tier | Stories | Characters | Illustrations | Story Length | Interactive Mode |
|------|---------|------------|---------------|--------------|------------------|
| Free | 10/day (100/month) | 2 | 5/month | 5-minute | ❌ |
| Premium | 20/day | 5 | Unlimited | 5 or 10-minute | ✅ |
| Family | Unlimited | 20 | Unlimited | 5 or 10-minute | ✅ |
| BYOK | Unlimited | Unlimited | Unlimited | 5 or 10-minute | ✅ |

## 🧠 Key Workflows

### Story Generation Flow
1. User creates/selects character → Frontend
2. User selects feeling (optional) → Frontend
3. Frontend sends payload → Backend `/generate-story`
4. Backend builds age-calibrated prompt → `story_service.py`
5. Backend calls Gemini API → Google AI
6. Gemini generates structured story → JSON response
7. Backend saves to database → `stories` table
8. Backend returns story data → Frontend
9. Frontend displays in storybook UI → `story_result_screen.dart`
10. User optionally generates illustrations → Backend `/generate-illustration`

### Mood Selection Flow
**Mood Magic (Default)**:
1. User sees animated mood faces → `feeling_selection_step.dart`
2. Taps a core mood (Happy, Sad, Angry, Scared, Worried, Calm)
3. Expression refinement options appear
4. "Choose-a-Fix" suggests coping strategies
5. Data stored in `WizardData` object
6. Sent to backend in story generation request

**3-Level Feelings Wheel (Advanced)**:
1. User switches to advanced mode
2. Core emotion selected (e.g., "Sad")
3. Wheel expands to show secondary feelings (e.g., "Lonely")
4. Wheel expands again to show tertiary (e.g., "Missing Someone")
5. Intensity slider appears (1-10)
6. Data stored in `WizardData` object
7. Sent to backend in story generation request

### Subscription Flow
1. User hits free tier limit
2. Paywall dialog appears → `paywall_dialog.dart`
3. User selects Premium, Family, or BYOK
4. **Premium/Family**: Redirects to Stripe checkout (integration in progress)
5. **BYOK**: Opens setup wizard → `byok_setup_wizard.dart`
6. API key stored securely → `flutter_secure_storage`
7. Subscription updated → `subscription_service.dart`
8. Backend notified → `POST /subscription-status`
9. Usage limits adjusted per tier

## 🧭 Roadmap

**Completed**:
- ✅ Core story generation with Gemini 2.0 Flash
- ✅ Mood Magic picker (lightweight emotion selector)
- ✅ 3-level feelings wheel (advanced option)
- ✅ Age-calibrated prompts (3-17+)
- ✅ Character creation with avatar gallery (55 pre-made avatars)
- ✅ AI avatar generation (Gemini Imagen 3)
- ✅ Character persistence (local Isar cache + backend sync)
- ✅ Character templates for quick creation
- ✅ Wizard-guided story creation
- ✅ Storybook UI with page turning
- ✅ Illustration generation (Imagen 3)
- ✅ Coloring page generation
- ✅ Offline story caching
- ✅ Achievement system
- ✅ Multi-character stories
- ✅ Interactive choose-your-own-path
- ✅ Conflict resolution stories
- ✅ Secure BYOK storage (flutter_secure_storage)
- ✅ BYOK setup wizard
- ✅ Backend task queue (Celery)
- ✅ Crash reporting (Sentry)
- ✅ Text-to-Speech narration (flutter_tts)
- ✅ Family subscription tier

**In Progress**:
- 🔄 Stripe payment integration (routes exist, webhook integration pending)
- 🔄 Integration tests for story generation and paywall flows

**Planned** (see `codex_improvements.md`):
1. Parent dashboard (emotion trends, reading stats)
2. Story export to PDF with illustrations
3. Social sharing (shareable story links)
4. Story templates library
5. Seasonal theme packs
6. Therapist collaboration mode

## 📚 Additional Documentation

- **COMPREHENSIVE_APP_SUMMARY.md** – Complete app overview for market research
- **TEAM_COORDINATION.md** – Development history and session logs
- **GEMINI_CODEX_TASKS.md** – Parallel task board for AI agents
- **TASK_PLANS.md** – Multi-week milestone planning
- **SESSION_HANDOFF.md** – Stateful notes between contributors
- **codex_improvements.md** – Prioritized improvement backlog
- **DEPLOYMENT_INSTRUCTIONS.md** – Netlify deployment guide
- **DEPLOYMENT_CHECKLIST.md** – Pre-launch checklist
- **TESTING_AND_DEPLOYMENT.md** – QA procedures

## 🤝 Contributing

We welcome contributions! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- **Google Gemini** for powering story and image generation
- **Flutter** team for the amazing cross-platform framework
- **Plutchik** and **Geneva Emotion Wheel** research for feelings wheel design
- **Child development research** informing age-appropriate content guidelines

---

**Ready to create magical stories that help children understand their emotions?** 🌟

Start the backend, launch the app, and watch as AI transforms feelings into adventures!
