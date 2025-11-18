# PROJECT_RULEBOOK.md - Story Weaver App Agent Guidelines

## Overview
This rulebook contains all essential information for AI agents working on the Story Weaver therapeutic storytelling application. Read and internalize this entire document before starting any task. Follow all guidelines strictly to maintain project quality, safety, and synchronization.

## Project Context
**App Name:** Story Weaver  
**Purpose:** Therapeutic AI storytelling for children (ages 3-17+) with emotional learning features  
**Tech Stack:** Frontend: Flutter/Dart (web, mobile, desktop), Backend: Python/Flask + PostgreSQL, AI: Google Gemini  
**Deployment:** Netlify (frontend), Railway (backend)  
**Key Features:** Character creation, feelings wheel, emotion recognition, coping strategies, subscription management  

## Core Responsibilities
1. **Git Synchronization:** Follow the Master Git Automation workflow exactly
2. **Team Coordination:** Update TEAM_COORDINATION.md with all progress, blockers, and completions
3. **Quality Standards:** Adhere to code style guidelines and therapeutic safety protocols
4. **Testing:** Run appropriate tests and ensure they pass before marking tasks complete

## Master Git Automation & Persistence Manager

### Context & Background
You are the centralized Version Control Authority for this project. The environment consists of a user operating AI agents that generate code locally, requiring a streamlined, fail-safe Git workflow. You must maintain perfect, direct synchronization with the remote main branch to prevent data loss. The user forbids the use of Pull Requests and requires all successful commits to be clearly timestamped.

### Core Role & Capabilities
- Full-Cycle Git Automation: Manages the entire Git flow from session start to completion push.
- Data Loss Prevention Specialist: Ensures local work is secured immediately and prioritized during conflict resolution.
- Timestamp Logger: Automatically integrates the current YYYY-MM-DD HH:MM:SS stamp into all relevant commit messages and final reports.
- Workflow Enforcer: Strictly adheres to the "No Pull Request, Direct-to-Main" policy.

### Technical Configuration
- Target Branch: main (Strictly enforced).
- Git Strategy: --strategy-option=ours for automated conflict resolution (favors local changes).
- Timestamp Utility: Utilize system time functions (e.g., date +%F\ %T).

### Operational Guidelines
1. [START OF TASK] Initialization: Before generating or modifying any code, execute: git status -> git stash (if needed) -> git pull origin main -> git stash pop (if stashed).
2. [TASK COMPLETE] Synchronization: Execute: git add . -> git commit -m "[AGENT SYNC | YYYY-MM-DD HH:MM:SS] <Task Summary>" -> git pull origin main --strategy-option=ours --no-edit -> git push origin main.
3. [ERROR/TIMEOUT] Maintenance: If synchronization fails, retry the Synchronization sequence exactly one time.

### Output Specifications
- Completion Status: All successful synchronization actions must end with: "✅ Repository Synced. Timestamp: YYYY-MM-DD HH:MM:SS."
- Log Detail: Output the full command log and the final commit hash pushed to the remote.
- Format: Use Code Blocks for all shell commands and outputs.

### Advanced Features
- Smart Stashing: Only apply git stash if git status reveals unstaged or uncommitted changes during Initialization.
- Commit Message Generation: If unsure of <Task Summary>, default to "Automated Code Update" but never skip the timestamp.

### Error Handling
- Conflict Resolution: If a merge conflict persists, halt and report: "⚠️ Manual Merge Required. Local files preserved."
- Rejected Push: Automatically retry Synchronization once.
- Authentication Failure: Stop and prompt for credentials.
- Detached HEAD: Switch to main branch.

### Quality Controls
- Status Check: Final state must show clean working tree.
- History Check: Local HEAD matches or is descendant of remote HEAD.

### Safety Protocols
- Force Push Ban: Never use git push --force.
- Data Security: Do not commit .env, API keys, or credential files.
- Branch Policy: All operations target main branch.

## Team Coordination Protocol

### TEAM_COORDINATION.md Updates
- **Required:** Update TEAM_COORDINATION.md after every major action, completion, or blocker.
- **Format:** Use dated entries with agent name, e.g., "- 2025-11-18 · [Agent Name] → Team: [Update]"
- **Content:** Include task status, blockers, next steps, file changes.
- **Frequency:** Daily updates at minimum, immediately for blockers.

### Communication Guidelines
- Tag other agents when dependencies exist: @[Agent Name]
- Use clear, actionable language.
- Document decisions and rationale.
- Escalate blockers within 4 hours.

## Build/Lint/Test Commands

### Flutter (Frontend)
- **Build:** flutter pub get, flutter build web --release
- **Run:** flutter run -d chrome
- **Test:** flutter test (all), flutter test test/story_complexity_service_test.dart (single)
- **Lint:** flutter analyze

### Python Backend
- **Install:** cd backend && pip install -r requirements.txt
- **Run:** cd backend && python app.py
- **Test:** cd backend && python -m pytest tests/

## Code Style Guidelines

### Dart/Flutter
- **Imports:** Group by type (dart:*, package:*, relative), blank line between groups
- **Naming:** camelCase for variables/functions, PascalCase for classes, UPPER_SNAKE for constants
- **Types:** Use explicit types, prefer final for immutables, nullable with ?
- **Async:** Use async/await, handle errors with try/catch
- **Formatting:** Follow flutter_lints (analysis_options.yaml)

### Python Backend
- **Imports:** Standard library first, then third-party, then local (blank lines between)
- **Naming:** snake_case for variables/functions, PascalCase for classes
- **Types:** Use type hints where possible
- **Error Handling:** Use try/except with specific exceptions, log with logging module

## Therapeutic Safety Protocols

### Child Safety is Non-Negotiable
- **COPPA Compliance:** Parental consent required, no personal data collection from children <13
- **Content Filtering:** All stories must be age-appropriate
- **Emotional Safety:** Stories should be therapeutic, not triggering

### Therapeutic Features to Protect
1. Character Evolution System - Tracks emotional growth across 5 stages
2. Emotion Recognition - Interactive games for identifying emotions
3. Coping Strategies - 8 types of coping skills (breathing, grounding, etc.)
4. Feelings Wheel - 3-level hierarchy for emotion identification

### When Reviewing Code/Features
- Is this age-appropriate for the target user?
- Does this support emotional learning?
- Could this trigger anxiety or distress?
- Is the vocabulary suitable for the child's age?

## File Structure Key Directories
- `lib/` - Flutter frontend code
- `backend/` - Python Flask backend
- `test/` - Flutter tests
- `backend/tests/` - Python tests
- `TEAM_COORDINATION.md` - Live project status
- `AGENTS.md` - This rulebook reference

## Final Instructions
- **Read this file first** before any task.
- **Follow Git workflow** for all changes.
- **Update coordination** after every action.
- **Maintain quality** and safety standards.
- **Communicate clearly** with other agents.

**Last Updated:** 2025-11-18