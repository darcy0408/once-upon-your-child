# Story Weaver App - Gemini AI Context

## 🚀 Session Handoff - January 27, 2026

### Summary
Executed a comprehensive **Multi-Age Developmental Logic Audit** which identified a critical flaw in the Interactive Adventure (Pick-a-Path) prompt logic. The system was incorrectly applying *total story* word count constraints to *individual segments*, leading to massive, novel-length generated segments for older users.

### ✅ Key Achievements
1.  **Fixed Interactive Story Logic:**
    *   Updated `InteractiveAdventurePromptBuilder` in `backend/services/interactive_adventure_prompt_builder.py`.
    *   Introduced `PATH_DEPTHS` table to estimate path length (4-14 segments) based on age.
    *   Implemented `_calculate_per_segment_word_count` to divide total word count by path depth, ensuring readable segment lengths (e.g., 300-400 words for teens instead of 3000+).
    *   Added dynamic `sensory_palette` defaults to prevent "babyish" descriptions for older users.
2.  **Verified Audit Pass:**
    *   Ran `audit_generator.py` (since deleted) to verify prompt generation across all 7 age bands.
    *   Confirmed Age 5 prompts remain simple and Age 17 prompts are now appropriately sized and tonally mature.
3.  **Maintenance:**
    *   Performed git maintenance and pushed fixes to `main`.
    *   Updated asset configuration in `pubspec.yaml` (added `assets/images/themes/`).

### 🧪 Testing Status
- **Audit:** Passed for all age groups (Logic Check).
- **Manual Verification:** "Deep Dive" prints confirmed prompt text structure is correct.

### 📋 Next Steps
1.  **User Acceptance:** Verify the live app's interactive story output.
2.  **Monitor Costs:** Ensure the new shorter segments don't cause context fragmentation or excessive API calls due to increased turn-taking.

---

## 🚀 Session Handoff - January 7, 2026

### Summary
This session achieved a major milestone: **Full "Coverage v2" Compliance**. The backend story generation engine was refactored to strictly enforce the "Age × Length × Mode" constraint matrix. We verified that stories are now age-appropriate, length-accurate, and structurally sound across all modes (Interactive, Regular, Rhyme, Learn-to-Read).

### ✅ Key Achievements
1.  **Backend Configuration v2:** Implemented a master `AGE_CONSTRAINTS` table in `backend/services/story_service.py` and `interactive_adventure_prompt_builder.py`.
    *   **7 Age Bands:** 3-4, 5-7, 8-10, 11-13, 13-15, 15-18, Adult.
    *   **3 Length Tiers:** Short, Medium, Long (with exact word/node counts).
2.  **Quality Assurance Verified:**
    *   **Deep Dive Simulation:** Validated that Age 6 prompts enforce "Second-Person POV", "650-900 words", and "Sparky the Dragon" integration.
    *   **Learn-to-Read Strictness:** Verified that Age 4 prompts enforce "CVC words only" and "8 pages".
    *   **Pick-a-Path:** Updated logic to map "linear segments" to the requested "node counts" (e.g., 9-12 nodes for Age 5-7).
3.  **Deployment:** The stable, tested codebase was pushed to `main` (Commit `35b7953`), triggering production deployments on Railway and Netlify.

### 🧪 Testing Status
- **Backend Tests:** All 21 tests are **GREEN**.
- **Frontend Tests:** All 73 tests are **GREEN**.
- **Manual Verification:** "Recipe for Magic" verification scripts confirm prompt engineering aligns with user requirements.

### 📋 Next Steps
1.  **User Acceptance:** Verify the live app's story output matches the "Delight" quality seen in simulations.
2.  **Monitor Costs:** The longer stories (up to 7800 words for Adults) will consume more tokens. Monitor Gemini API usage.

---

## 📜 Story Generation Constraints (Coverage v2)

The system now enforces these hard limits. **Do not modify without approval.**

| Age | Regular (Words) | Rhyme (Words) | Learn-to-Read (Pages) | Pick-a-Path (Nodes) |
| :--- | :--- | :--- | :--- | :--- |
| **3-4** | S:200-300 / M:300-450 / L:450-650 | 150-500 | 6 / 8 / 10 | 7-13 |
| **5-7** | S:450-650 / M:650-900 / L:900-1200 | 350-950 | 8 / 10 / 12 | 9-18 |
| **8-10** | S:900-1200 / M:1200-1800 / L:1800-2400 | 650-1800 | 10 / 12 / 14 | 12-24 |
| **11-13** | S:1300-1700 / M:1800-2600 / L:2600-3400 | 900-2800 | (Optional) | 14-26 |
| **13-15** | S:1600-2200 / M:2400-3400 / L:3400-4500 | 1100-3400 | N/A | 16-32 |
| **15-18** | S:2000-2800 / M:3000-4200 / L:4200-6000 | 1400-4800 | N/A | 18-38 |
| **Adult** | S:2000-3000 / M:3200-5200 / L:5200-7800 | 1500-5500 | N/A | 18-44 |

**Mandatory Features:**
*   **Continuity:** Companions must appear by name.
*   **Therapeutic:** Show coping in action.
*   **Personalization:** Earned "small win" ending.

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
