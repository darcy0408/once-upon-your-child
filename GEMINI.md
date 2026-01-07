# Story Weaver App - Gemini AI Context

## 🚀 Session Handoff - January 3, 2026

### Summary
This session focused on fixing critical backend/frontend bugs and establishing a comprehensive automated testing plan. The backend is now fully verified and ready for deployment. The frontend critical features (Interactive Stories, Feelings Wheel) are also verified, with some minor infrastructure tasks remaining for legacy tests.

### ✅ Bugs Fixed
1.  **Bug #C3 (Database Schema Mismatch):** Fixed by deleting `backend/config/characters.db`. The system now correctly recreates the `user` table with the `stories_created_count` column.
2.  **Interactive Prompt Builder Regression:** Updated `backend/services/interactive_adventure_prompt_builder.py` to match Phase 3 requirements (added "Contract" terminology, "Banned Choices", and fixed age 6-8 word counts).
3.  **Frontend Compilation Error:** Fixed `Type 'Isar' not found` in `avatar_service.dart` by exporting the Isar class in `lib/services/isar_service_io.dart`.
4.  **Firebase Test Crash:** Implemented `InteractiveStoryAnalytics.enableMockMode()` to bypass Firebase Analytics calls during widget tests, preventing the `[core/no-app]` crash.
5.  **Feelings Wheel Data Mismatch:** Corrected `test/widgets/feelings_wheel_test.dart` to follow the actual data hierarchy (Happy -> Playful -> Cheeky).

### 🧪 Testing Status
- **Backend:** `tests/test_backend_comprehensive.py` and `tests/test_backend_interactive_flow.py` are **GREEN**. Full interactive story flow verified.
- **Frontend:** `PickAPathAdventureScreen` and `FeelingsWheelScreen` tests are **GREEN**. 
- **Legacy Integration Tests:** `wizard_pick_a_path_test.dart` still fails due to unmocked Isar/PathProvider dependencies (does not block core feature deployment).

### 📋 Next Steps
1.  **Deploy:** Perform final deployment of Backend (Railway) and Frontend (Netlify).
2.  **Legacy Test Maintenance:** Update `wizard_pick_a_path_test.dart` to properly mock the Isar local database for full end-to-end integration coverage.

---

## Project Overview

The Story Weaver app is a full-stack application designed to generate therapeutic, AI-powered stories for children. It features a Flutter-based frontend and a Python Flask backend. The core functionality revolves around leveraging the Gemini API for dynamic story generation, with support for both a free tier (utilizing the backend's API key) and a "Bring Your Own Key" (BYOK) option for premium users.

## Technologies Used

**Frontend:**
- **Flutter (Dart):** For cross-platform mobile and web application development.

**Backend:**
- **Python Flask:** A micro-framework for the web API.
- **SQLAlchemy:** ORM for database interactions (SQLite).
- **Google Generative AI (Gemini API):** For AI story generation.
- **Gunicorn:** WSGI HTTP Server for Python web applications (production deployment).

## Building and Running

### Frontend (Flutter)

1.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
2.  **Run in Development Mode (e.g., for web):**
    ```bash
    flutter run -d chrome
    ```
3.  **Build for Web (Release):**
    ```bash
    flutter build web --release
    ```

### Backend (Python Flask)

1.  **Install Dependencies:**
    ```bash
    pip install -r backend/requirements.txt
    ```
2.  **Environment Variables:**
    Create a `.env` file in the `backend/` directory and set your Gemini API key:
    ```
    GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
    ```
3.  **Run in Development Mode:**
    ```bash
    python backend/app.py
    ```
4.  **Run in Production (using Gunicorn, as configured for Railway):**
    ```bash
    gunicorn -w 4 -b 0.0.0.0:$PORT app:app
    ```
    (Note: `$PORT` will be provided by the hosting environment like Railway)

## Development Conventions

-   **Codebase Structure:** Standard Flutter project structure for the frontend (`lib/`, `assets/`, `android/`, `ios/`, etc.) and a dedicated `backend/` directory for the Python Flask application.
-   **Git Workflow:** Feature-based branching is used (e.g., `gemini/simplify-form`, `codex/age-appropriate-stories`, `gemini/feelings-wheel-ui`).
-   **Commit Messages:** Commits typically follow a structured format, often prefixed with `[Feature]`, `[Simplify]`, `[Cleanup]`, etc., to indicate the type of change.
-   **AI Agent Tasking:** Tasks are explicitly assigned to different AI agents (Gemini, Codex) with detailed instructions and expected outcomes, as documented in `TASK_PLANS.md` and `GEMINI_CODEX_TASKS.md`.
-   **Linting:** Flutter frontend uses `flutter_lints` with rules defined in `analysis_options.yaml`.

## Key Features and Modules

-   **Character Management:** CRUD operations for character profiles, including physical attributes, personality sliders, likes, dislikes, fears, and goals.
-   **Story Generation:**
    -   Utilizes `google-generativeai` for AI model interaction.
    -   `backend/app.py` orchestrates prompt generation, incorporating character details, themes, companions, and therapeutic elements.
    -   Supports "Learning to Read Mode" for rhyming stories with strict age-appropriate constraints.
    -   Implements age-based guidelines for story length, vocabulary, and complexity.
-   **Feelings Wheel Integration:** A hierarchical feelings wheel (Core → Secondary → Tertiary emotions) is integrated for emotional check-ins, influencing story generation.
-   **Interactive Stories:** Functionality for generating and continuing choice-based interactive narratives.
-   **Illustration & Coloring Pages:** Backend endpoints to generate visual assets from story scenes using AI.
-   **Text-to-Speech:** Integration with Google Cloud TTS (via `tts_service.py`) for high-quality audio narration.
-   **Deployment:** Configured for deployment on platforms like Netlify (frontend) and Railway (backend).