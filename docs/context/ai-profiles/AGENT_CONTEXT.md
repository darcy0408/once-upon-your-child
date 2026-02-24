# Agent Context - Story Weaver App

**Last Updated:** 2025-11-09

## Specialized Agents Overview

This file contains context for specialized AI agents that work on specific aspects of the Story Weaver App project.

## Available Agents

### Closing Agent (`/close-session-gemini` ⭐ or `/close-session`)
**Purpose:** Document and close work sessions systematically

**Two Versions:**
- **`/close-session-gemini`** - Uses Gemini (RECOMMENDED - saves Claude tokens)
- **`/close-session`** - Uses Claude (backup option)

**Responsibilities:**
1. Summarize session activities comprehensively
2. Update SESSION_HISTORY.md with detailed entry
3. Update all AI context files (CLAUDE_CONTEXT.md, GEMINI_CONTEXT.md, AGENT_CONTEXT.md)
4. Check and update core project files (README.md, PROJECT_STATUS.md)
5. Create meaningful git commits with "why" context

**When to Use:** At the end of every work session, especially after:
- Adding features
- Fixing bugs
- Major refactoring
- Documentation updates
- Any significant changes
- Before taking breaks or switching projects

**Implementation Notes:**
- Slash commands require Claude Code restart to load initially
- Can be run manually if slash commands aren't loaded yet
- Located in `.claude/commands/` directory
- Comprehensive documentation in `.claude/SETUP_GUIDE.md`

### Future Agent Ideas
- **Testing Agent:** Runs comprehensive tests, reports issues
- **Deployment Agent:** Handles full deployment pipeline
- **Documentation Agent:** Updates all docs based on code changes
- **Code Review Agent:** Reviews code for best practices and issues

## Agent Best Practices

### Context Awareness
- Always read SESSION_HISTORY.md before starting work
- Check relevant AI context files (CLAUDE_CONTEXT.md, etc.)
- Understand recent changes and current project state

### Documentation Standards
- Write clear, concise summaries
- Focus on "why" over "what"
- Include impact and next steps
- Update all relevant files

### Git Commit Guidelines
- Use semantic categories: Feature, Fix, Refactor, Docs, Chore, Deploy
- Explain motivation and impact
- List key changes in bullet points
- Reference issues or tasks if applicable

### File Organization
- Keep context files updated with each session
- Archive old session notes if needed
- Maintain clean, navigable documentation structure

## Project Context Quick Reference

**Main Language:** Dart (Flutter frontend), Python (backend)

**Key Directories:**
- `lib/` - Flutter app code
- `backend/` - Python API
- `docs/` - All documentation
- `.claude/` - Claude-specific tools

**Current Focus:** Deployment and bug fixes

**Active Branch:** `gemini-deploy` (working), `main` (stable)

**Known Issues:**
- UI overflow problems
- Character creation bugs

**Documentation Files:**
- `SESSION_HISTORY.md` - Session logs
- `DEPLOYMENT_INSTRUCTIONS.md` - How to deploy
- `TESTING_AND_DEPLOYMENT.md` - Testing guide
- Task files: `GEMINI_DEPLOYMENT_TASK.md`, `CODEX_PERSONALITY_SLIDERS_TASK.md`

## Using This File
Agents should:
1. Read this file at the start of specialized tasks
2. Update their sections when capabilities change
3. Add new agent types as they're created
4. Keep information current and accurate

## User Workflow Preferences
- **Documentation:** Automated > Manual
- **Version Control:** Everything is tracked in Git
- **Commit Messages:** Detailed with context and rationale
- **Organization:** Systematic and structured
- **AI Collaboration:** Multiple AIs (Claude, Gemini, Codex) working together on different branches
- **User Challenge:** Struggles with documentation - closing agent solves this
- **Token Optimization:** Use Gemini for docs, save Claude for complex coding

## Multi-AI Collaboration
The user works with multiple AI assistants simultaneously:
- **Claude:** Complex coding, architecture, debugging
- **Gemini:** Deployment, documentation, routine tasks
- **Codex:** Feature development on separate branches

**Project Locations:**
- Windows: `C:\dev\story-weaver-app`
- WSL: `/mnt/c/dev/story-weaver-app-codex-dev`

**Why Context Files Matter:**
- Seamless handoffs between different AIs
- Each AI stays informed of what others did
- No information loss between sessions
- All AIs can read SESSION_HISTORY.md to catch up
