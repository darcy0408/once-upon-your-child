# Story Weaver App - Complete Overview

## What Is This App?

**Story Weaver** is a children's storytelling application that uses AI (Google Gemini) to create personalized, age-appropriate stories for kids ages 3-16.

Think of it as a magical story creator that weaves unique tales featuring your child as the hero, with their friends, pets, and interests woven into the narrative.

---

## Who Is It For?

**Primary Users:** Parents, caregivers, teachers, and children

**Target Audience:**
- Children ages 3-16
- Families looking for personalized bedtime stories
- Educators creating engaging classroom content
- Parents wanting to encourage reading and imagination

---

## Core Features

### 1. **Personalized Characters**
- Create custom characters with names, ages, genders, personality traits
- Add character fears, strengths, and special abilities
- Assign archetypes (Adventurer, Scientist, Artist, Leader, etc.)
- Include companions (pets, siblings, friends) with special powers

### 2. **AI-Powered Story Generation**
- Stories generated using Google Gemini 2.0 Flash
- Age-calibrated vocabulary and complexity (4 age bands: 3-5, 6-8, 9-12, 13-16)
- Multiple themes: Adventure, Magic, Mystery, Sci-Fi, Fantasy, Dragons, Space, Ocean
- Adjustable tone: Whimsical, Mystery, Cozy-Adventure
- Story lengths: Quick (100-200 words), Standard (300-500 words), Epic (600-1000 words)

### 3. **Story Wizard (Step-by-Step Creator)**
- **Step 1:** Hero Creation - Name, age, gender, personality
- **Step 2:** Companions - Add friends, pets, magical beings
- **Step 3:** Emotions & Themes - Select mood, theme, special elements
- **Step 4:** Magic Review - Preview and customize
- **Step 5:** Story Generation - Watch the magic happen

### 4. **Pick-A-Path Adventures (NEW!)**
The flagship interactive feature that makes this app unique:

#### What Makes Pick-A-Path Special:
- **Branching Narratives:** Kids make choices that change the story
- **Age-Calibrated Choices:**
  - Short stories = 2 choices per segment
  - Medium stories = 3 choices per segment
  - Long stories = 4 choices per segment
- **Inventory System:** Collect items throughout the adventure (magic wands, keys, potions)
- **State Tracking:** Story remembers location, goals, clues, companion status
- **Illustrations:** One AI-generated image per story segment
- **Resumable Stories:** Save progress and continue later
- **Story Completion:** Adventure completes after target segment count:
  - Short: 2-3 segments
  - Medium: 4-6 segments
  - Long: 7-10 segments

#### How Pick-A-Path Works:
1. Enable "Interactive Mode" in the wizard
2. AI generates first story segment with choices
3. Child selects a choice
4. Story continues based on that choice
5. Inventory and story state update automatically
6. Repeat until adventure completes
7. Save completed story to library

### 5. **Story Library**
- Save favorite stories
- Mark stories as favorites
- Filter by theme, character, date
- Share stories (planned feature)
- Resume in-progress Pick-A-Path adventures

### 6. **Offline Support**
- Stories cached locally using Isar database
- Read saved stories without internet
- Sync progress when back online

### 7. **Illustrations**
- AI-generated images using Gemini Imagen
- Character avatars integrated into scenes
- Companion appearances in illustrations
- Age-appropriate visual style

---

## Technical Stack

### Frontend
- **Framework:** Flutter (Dart)
- **Platform:** Cross-platform (iOS, Android, Web, Desktop)
- **State Management:** Riverpod
- **Local Database:** Isar (NoSQL, offline-first)
- **UI Components:** Custom design system (AppButton, AppCard, ErrorMessage)

### Backend
- **Framework:** Flask (Python)
- **Database:** PostgreSQL (production) / SQLite (development)
- **ORM:** SQLAlchemy
- **AI Provider:** Google Gemini API (gemini-2.0-flash-exp model)
- **Task Queue:** Celery (for async story generation)
- **Storage:** Local file storage or cloud (for illustrations)

### Key Backend Models
- **User:** User accounts and authentication
- **Character:** Child character profiles
- **Story:** Traditional linear stories
- **InteractiveStory:** Pick-A-Path adventures (parent record)
- **StorySegment:** Individual segments of Pick-A-Path stories
- **StoryChoice:** Choices available at each segment
- **InventoryItem:** Items collected during adventures
- **StoryState:** Current state tracking (location, goals, clues)

---

## User Journey Example

### Traditional Story:
1. Parent opens app → Clicks "Create New Story"
2. Wizard Step 1: Names child "Emma", age 7, personality: brave, curious
3. Wizard Step 2: Adds companion "Max the Dog" with power "Super Smell"
4. Wizard Step 3: Selects "Adventure" theme, adds "treehouse" element
5. Wizard Step 4: Reviews settings, clicks "Weave My Story"
6. AI generates 400-word adventure about Emma and Max finding treasure
7. Story displays with illustration
8. Parent saves to library

### Pick-A-Path Adventure:
1. Parent enables "Interactive Mode" in Step 4
2. AI generates first segment: "Emma finds a mysterious map in her treehouse..."
3. Displays illustration of treehouse scene
4. Shows 3 choices:
   - "Follow the map into the forest"
   - "Ask Max to sniff for clues"
   - "Call your best friend for help"
5. Child selects "Follow the map into the forest"
6. Inventory updates: +1 "Ancient Map"
7. State updates: Location = "Dark Forest", Goal = "Find the treasure"
8. AI generates next segment based on choice
9. Process repeats for 4-6 segments until treasure is found
10. Story marked complete and saved to library

---

## Age Calibration Details

The app automatically adjusts content based on child's age:

### Age 3-5:
- **Word Count:** 50-80 words per segment
- **Vocabulary:** Simple, concrete nouns (cat, tree, house)
- **Sentences:** 3-6 words max
- **Themes:** Everyday adventures, animals, family
- **Example:** "Emma sees a big red ball. The ball rolls away. Emma runs fast. She catches the ball!"

### Age 6-8:
- **Word Count:** 100-150 words per segment
- **Vocabulary:** Common descriptive words (sparkling, mysterious, brave)
- **Sentences:** 6-10 words
- **Themes:** Friendship, simple mysteries, magical animals
- **Example:** "Emma discovered a sparkling key hidden under an old oak tree. Max barked excitedly and wagged his tail. 'This must be important!' Emma said."

### Age 9-12:
- **Word Count:** 150-220 words per segment
- **Vocabulary:** More complex words (ancient, investigate, cautiously)
- **Sentences:** 10-15 words
- **Themes:** Complex plots, moral choices, character development
- **Example:** "As Emma examined the ancient map, she noticed strange symbols that seemed to glow in the moonlight. Max growled softly, his super smell detecting something unusual nearby."

### Age 13-16:
- **Word Count:** 200-280 words per segment
- **Vocabulary:** Sophisticated language (atmospheric, contemplated, enigmatic)
- **Sentences:** 12-20 words
- **Themes:** Ethical dilemmas, complex relationships, abstract concepts
- **Example:** "The enigmatic symbols on the weathered parchment seemed to pulse with an otherworldly energy. Emma contemplated the implications of following this mysterious trail into uncharted territory."

---

## API Endpoints (For Testing)

### Story Generation
- `POST /generate-interactive-story` - Create new Pick-A-Path adventure
- `POST /continue-interactive-story` - Continue story with choice selection
- `GET /interactive-story/<story_id>` - Get full story with all segments
- `GET /interactive-story/<story_id>/resume` - Resume in-progress story

### Traditional Stories
- `POST /generate-story` - Generate linear story
- `GET /stories` - List user's stories
- `GET /story/<story_id>` - Get specific story

### Utilities
- `GET /health` - Server health check
- `POST /characters` - Create character profile
- `GET /characters` - List characters

---

## Current Development Status

### Completed (95%):
✅ Backend API for Pick-A-Path Adventures
✅ Database models and migrations
✅ Age calibration engine
✅ Frontend UI for interactive stories
✅ Inventory and state tracking
✅ Illustration generation per segment
✅ Resume/save functionality
✅ Offline support with Isar
✅ Wizard integration with interactive mode toggle

### Ready for Testing:
🧪 15 backend API tests
🧪 29 frontend UI tests
🧪 Complete testing documentation

### Future Enhancements:
🔮 Story sharing between users
🔮 Multiplayer adventures (multiple children in same story)
🔮 Voice narration
🔮 Animated illustrations
🔮 Parent dashboard with reading analytics
🔮 Premium subscription features

---

## Key Files Reference

### Frontend (Flutter):
- `lib/pick_a_path_adventure_screen.dart` - Main interactive story UI
- `lib/screens/wizard_steps/magic_review_step.dart` - Wizard final step with toggle
- `lib/services/interactive_story_service.dart` - API client
- `lib/models.dart` - Data models
- `lib/services/offline_story_service_io.dart` - Offline persistence

### Backend (Python):
- `backend/routes/story_routes.py` - API endpoints
- `backend/models/interactive_story.py` - Database models
- `backend/services/interactive_adventure_service.py` - Business logic
- `backend/services/interactive_adventure_prompt_builder.py` - Gemini prompt engineering

### Documentation:
- `PICK_A_PATH_TESTING_PLAN.md` - Master testing guide (1,146 lines)
- `AGENT_1_BACKEND_TESTING.md` - Backend test instructions
- `AGENT_2_FRONTEND_TESTING.md` - Frontend test instructions
- `TESTING_HANDOFF.md` - Quick delegation guide
- `INTERACTIVE_STORY_IMPLEMENTATION_SUMMARY.md` - Feature documentation

---

## Testing Instructions Summary

To test Pick-A-Path Adventures:

1. **Backend Testing (No browser needed):**
   - Start backend: `cd backend && python app.py`
   - Follow `AGENT_1_BACKEND_TESTING.md`
   - Test 15 API endpoints using curl commands
   - Validate database persistence
   - Check age calibration and choice counts

2. **Frontend Testing (Browser required):**
   - Start frontend: `flutter run -d chrome`
   - Follow `AGENT_2_FRONTEND_TESTING.md`
   - Navigate through wizard with interactive mode enabled
   - Play through complete Pick-A-Path adventure
   - Test inventory, state tracking, save functionality
   - Take screenshots of key screens

3. **Success Criteria:**
   - Backend: 13/15 tests pass (87% minimum)
   - Frontend: 25/29 tests pass (86% minimum)
   - No crashes or data loss
   - Core flow works end-to-end

---

## Quick Start for New Developers

```bash
# Clone repository
git clone <repo-url>
cd story-weaver-app

# Backend setup
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
echo "GEMINI_API_KEY=your-api-key-here" > .env
python app.py

# Frontend setup (new terminal)
cd ..
flutter pub get
flutter run -d chrome

# Run tests
cd backend && pytest
cd .. && flutter test
```

---

## Unique Selling Points

1. **Age-Calibrated AI:** Not just "kid-friendly" but specifically calibrated to 4 age bands
2. **True Interactivity:** Real branching narratives with persistent state, not just multiple choice quizzes
3. **Character Integration:** Child's avatar, companions, fears, and strengths woven into every story
4. **Educational Value:** Encourages reading, decision-making, and creative thinking
5. **Offline-First:** Works without internet after initial story generation
6. **Cross-Platform:** One codebase for iOS, Android, Web, Desktop

---

## Common Questions

**Q: How long does story generation take?**
A: First segment: 10-30 seconds. Subsequent segments: 5-15 seconds.

**Q: Is data saved if the app crashes?**
A: Yes, progress is saved to local Isar database after each segment.

**Q: Can multiple children use the same app?**
A: Yes, create multiple character profiles. Each has their own library.

**Q: What happens if Wi-Fi cuts out mid-story?**
A: Current segment displays normally. New segments require internet to generate.

**Q: Can stories be exported or printed?**
A: Planned feature. Currently stories are viewable in the app library.

**Q: Is the AI content safe for kids?**
A: Yes. Gemini API has built-in safety filters, plus we enforce age-appropriate themes and vocabulary.

---

## Contact & Resources

- Testing Plans: See `TESTING_HANDOFF.md` for agent assignment
- Feature Docs: See `INTERACTIVE_STORY_IMPLEMENTATION_SUMMARY.md`
- API Reference: See `PICK_A_PATH_TESTING_PLAN.md` Part 1
- UI Reference: See `PICK_A_PATH_TESTING_PLAN.md` Part 2

**Current Branch:** `main`
**Feature Status:** 95% complete, ready for testing
**Last Updated:** December 25, 2025
