# Gemini Context - Story Weaver App

**Last Updated:** 2025-11-09

## Project Overview
Story Weaver App is a Flutter application for creating AI-assisted interactive stories. You (Gemini) are used for various tasks in this project.

## Your Role
Gemini is used for:
- Story generation and creative content
- Code assistance and development
- Documentation and planning (including session closing workflows)
- Testing and debugging
- **Session documentation** - Running the closing agent to save Claude tokens

## Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend:** Python
- **Deployment:** Netlify (web), considering mobile app stores
- **Version Control:** Git/GitHub

## Project Architecture
```
Frontend (Flutter) <-> Backend API (Python) <-> AI Models (Gemini/Claude)
```

## Key Components
- Character management system
- Story generation engine
- Achievement/gamification system
- Rhyme mode feature
- Feelings wheel integration

## Current Development Focus
- Deployment to production (see `gemini-deploy` branch)
- Bug fixes for UI overflow issues
- Character creation improvements

## How to Help Effectively
1. **Ask clarifying questions** before major changes
2. **Test your changes** before suggesting them
3. **Explain your reasoning** in commits and documentation
4. **Follow existing patterns** in the codebase
5. **Update context files** when you learn something new about the project

## Code Style
- Use Dart best practices for Flutter
- Keep functions focused and single-purpose
- Comment complex logic
- Use meaningful variable names

## Deployment Process
1. Test locally
2. Build for web: `flutter build web`
3. Deploy to Netlify (automated)
4. Check deployment at production URL

## Known Issues & Solutions
- UI overflow issues: Check constraints and flex layouts
- Character creation failures: Validate backend API responses
- Story generation timing out: Implement proper async handling

## Context Files to Check
- `SESSION_HISTORY.md` - What's been done recently
- `CLAUDE_CONTEXT.md` - Additional project context
- `AGENT_CONTEXT.md` - Specialized agent information

## User Preferences
- Comprehensive documentation
- Git commits with clear "why" explanations
- Treating all work as code with version control
- Automated workflows over manual processes
- User struggles with documentation - needs automated help

## Closing Agent System (Important!)
**You play a key role in the closing agent workflow!**

When the user runs `/close-session-gemini` in Claude Code:
1. **You** (Gemini) are invoked to do the documentation work
2. This saves expensive Claude tokens for complex coding tasks
3. You're great at summarization and documentation - perfect for this!

**Your tasks when invoked as closing agent:**
- Analyze the entire conversation history
- Create comprehensive session summary
- Update `docs/context/sessions/SESSION_HISTORY.md`
- Update AI context files (CLAUDE_CONTEXT.md, GEMINI_CONTEXT.md, AGENT_CONTEXT.md)
- Check if core project files need updates (README.md, PROJECT_STATUS.md)
- Create meaningful git commit with "why" context

**Why Gemini for this?**
- Documentation and summarization are your strengths
- Saves Claude tokens for actual development work
- Just as thorough as Claude for routine session closing
- Cost-effective and efficient

## Multi-AI Workflow
- User works with Claude, Gemini, and Codex simultaneously on different branches
- Multiple project directories: Windows (`C:\dev\story-weaver-app`) and WSL (`/mnt/c/dev/story-weaver-app-codex-dev`)
- Context files keep all AIs informed of project state
- Session history prevents information loss between sessions
