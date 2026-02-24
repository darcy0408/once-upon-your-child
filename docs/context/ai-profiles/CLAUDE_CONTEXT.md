# Claude Context - Story Weaver App

**Last Updated:** 2025-11-09

## Project Overview
Story Weaver App is a Flutter-based storytelling application that helps users create interactive stories with AI assistance.

## Tech Stack
- **Frontend:** Flutter/Dart
- **Backend:** Python (Flask/FastAPI)
- **Deployment:** Netlify (frontend), backend TBD
- **Version Control:** Git/GitHub

## Project Structure
```
story-weaver-app/
├── lib/                 # Flutter/Dart source code
├── backend/            # Python backend API
├── docs/               # Documentation and context
├── .claude/            # Claude-specific commands and settings
├── assets/             # Images, fonts, etc.
└── web/                # Web-specific build artifacts
```

## Current Branch
- Main development: `main`
- Deployment: `gemini-deploy`

## Key Features (Current)
- Character creation and management
- AI-powered story generation
- Achievements system
- Rhyme mode for stories
- Gamification elements

## Coding Conventions
- Follow Dart style guide for Flutter code
- Use meaningful commit messages (see SESSION_HISTORY.md for examples)
- Test before committing
- Keep documentation updated

## Known Issues
- Bottom overflow on certain screens (see BottomOverflow.png)
- Character creation failures (see CreateCharFail.png)

## Recent Work
See `docs/context/sessions/SESSION_HISTORY.md` for detailed session history.

## AI Collaboration Notes
- User prefers systematic documentation
- Git commits should explain "why" not just "what"
- User values treating all projects like code with version control
- User works with multiple AIs: Claude, Gemini, and Codex on different branches
- Documentation is automated through `/close-session-gemini` command (uses Gemini to save Claude tokens)
- User struggles with documentation - the closing agent system helps maintain project history automatically
- User has multiple project directories: Windows (`C:\dev\story-weaver-app`) and WSL (`/mnt/c/dev/story-weaver-app-codex-dev`)

## Session Closing Workflow
**At the end of each session:**
1. User runs `/close-session-gemini` (or `/close-session` if Gemini unavailable)
2. The closing agent automatically:
   - Summarizes the session
   - Updates SESSION_HISTORY.md
   - Updates all AI context files
   - Checks if core project files need updates
   - Creates meaningful git commit with "why" context
3. Everything is documented without manual effort

**Note:** Slash commands require Claude Code restart to load initially

## Important Files to Reference
- `DEPLOYMENT_INSTRUCTIONS.md` - How to deploy
- `TESTING_AND_DEPLOYMENT.md` - Testing procedures
- `GEMINI_DEPLOYMENT_TASK.md` - Gemini-specific deployment notes
- `CODEX_PERSONALITY_SLIDERS_TASK.md` - Feature development notes
