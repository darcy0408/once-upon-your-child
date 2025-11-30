# Multi-Agent Setup: 4 Agents + 1 Supervisor

**Goal:** Maximize parallel work while avoiding conflicts and session limits

## Agent Roles

### Agent 1: Backend API (Codex or Gemini)
**Focus:** Backend endpoints, database, API logic
- **Files:** `backend/**/*.py` (routes, services, models)
- **Responsibilities:**
  - API endpoint implementation
  - Database models and migrations
  - Service layer logic
  - Authentication/authorization
  - Stripe webhook handling
- **Cannot touch:** Frontend files, tests
- **Reports to:** TEAM_COORDINATION.md under `## Agent 1 - Backend API`

### Agent 2: Frontend Core (Codex or Gemini)
**Focus:** Main screens and core user flows
- **Files:** `lib/screens/*`, `lib/main*.dart`, `lib/services/api_service*.dart`
- **Responsibilities:**
  - Main screen implementation (story, character creation, results)
  - API integration
  - Core navigation flows
  - State management
- **Cannot touch:** Widgets, backend files
- **Reports to:** TEAM_COORDINATION.md under `## Agent 2 - Frontend Core`

### Agent 3: Frontend Widgets (Codex or Gemini)
**Focus:** Reusable components and visual polish
- **Files:** `lib/widgets/**/*.dart`, `lib/theme/**`, assets
- **Responsibilities:**
  - Widget components (buttons, cards, overlays)
  - Theming and styling
  - Animations and transitions
  - Visual polish
- **Cannot touch:** Screens, backend files
- **Reports to:** TEAM_COORDINATION.md under `## Agent 3 - Frontend Widgets`

### Agent 4: Testing & Analytics (Codex or Gemini)
**Focus:** Quality assurance and data tracking
- **Files:** `tests/**`, analytics services, documentation
- **Responsibilities:**
  - Test implementation and execution
  - Bug verification
  - Analytics integration
  - Performance monitoring
  - Documentation updates
- **Can read:** All files (for testing)
- **Reports to:** TEAM_COORDINATION.md under `## Agent 4 - Testing & Analytics`

### Claude (Supervisor)
**Focus:** Planning, coordination, unsticking agents
- **Responsibilities:**
  - Break down complex tasks into agent-specific work
  - Review TEAM_COORDINATION.md for blockers
  - Help when agents get stuck
  - Approve major architectural decisions
  - Final code review before deployment
  - Integration of agent work
- **Authority:** Can modify any file to fix integration issues
- **Workspace:** This main Claude Code session

## Communication Protocol

### Daily Check-in (Each Agent)
Each agent adds to TEAM_COORDINATION.md:
```markdown
## Agent [N] - [Role] | [DATE]

### Working On
- Task 1
- Task 2

### Completed
- ✅ Task A (file: path/to/file.ext)
- ✅ Task B (file: path/to/file.ext)

### Blockers
- ⚠️ Blocked on: [description] (needs Agent X)

### Questions for Supervisor
- ❓ Question about architecture/approach
```

### Conflict Prevention Rules

1. **File Ownership:**
   - Agent 1: `backend/**`
   - Agent 2: `lib/screens/**`, `lib/*_screen.dart`, `lib/main*.dart`
   - Agent 3: `lib/widgets/**`, `lib/theme/**`
   - Agent 4: `tests/**`, analytics files

2. **Shared Files (Need Coordination):**
   - `lib/services/api_service_manager.dart` - Agent 2 owns, Agent 1 consults
   - `lib/services/*_analytics.dart` - Agent 4 owns, others consult
   - Models (`lib/models/**`) - Creator owns, others coordinate

3. **When File Conflict Occurs:**
   - Post in TEAM_COORDINATION.md: "🔒 Locking [file] for [task]"
   - Other agents must wait
   - Post when done: "🔓 Released [file]"

## Work Assignment Strategy

### Example: "Fix Interactive Stories Feature"

**Supervisor (Claude) breaks down:**
1. Agent 1: Fix backend story parsing in `backend/services/story_service.py`
2. Agent 2: Update story result screen to display choices in `lib/story_result_screen.dart`
3. Agent 3: Create choice button widget in `lib/widgets/story_choice_button.dart`
4. Agent 4: Create integration test for full interactive story flow

**Execution Order:**
- Parallel: Agent 1, Agent 3 (no dependencies)
- After Agent 1 done: Agent 2 (needs working API)
- After Agent 2 done: Agent 4 (needs working feature)

### Example: "Add New Character Customization"

**Supervisor (Claude) breaks down:**
1. Agent 1: Add `accessories` field to Character model, update API
2. Agent 3: Create accessory picker widget
3. Agent 2: Integrate accessory picker into character creation screen
4. Agent 4: Test accessory selection and persistence

**Execution Order:**
- Parallel: Agent 1, Agent 3
- After both done: Agent 2 (needs both)
- After Agent 2 done: Agent 4

## Supervisor Workflow

### 1. Morning Planning
```markdown
Review TEAM_COORDINATION.md:
- What did each agent complete yesterday?
- Any blockers?
- Any questions for me?

Assign today's work:
- Break down tasks to avoid conflicts
- Specify dependencies
- Set clear success criteria
```

### 2. Throughout Day
```markdown
Monitor TEAM_COORDINATION.md for:
- 🚨 Blockers (urgent)
- ❓ Questions (address quickly)
- 🔒 File locks (watch for conflicts)

Respond in TEAM_COORDINATION.md under:
## Supervisor Notes | [DATE]
```

### 3. End of Day Review
```markdown
1. Review all agent completions
2. Test integration points
3. Fix any integration issues
4. Plan tomorrow's work
5. Update overall project status
```

## Session Limit Management

### Agent Sessions (Codex/Gemini)
- Use for straightforward, well-defined tasks
- Each session = 1 task typically
- Post completion report in TEAM_COORDINATION.md
- Exit when task done

### Supervisor Session (Claude)
- Keep this session for:
  - Planning and coordination
  - Reviewing agent work
  - Fixing integration issues
  - Complex problem solving
- Delegate everything else to agents
- Use concise prompts to conserve tokens

## Starting an Agent Session

### Template Prompt for Agent:
```
You are Agent [N] ([Role]) working on Story Weaver.

RULES:
1. Only modify files in: [your file scope]
2. Report all work in TEAM_COORDINATION.md under "## Agent [N] - [Role] | [DATE]"
3. If blocked, post blocker and wait for supervisor
4. When done, summarize completion and exit

TODAY'S TASK:
[Specific task description]

FILES TO MODIFY:
- [file 1]
- [file 2]

SUCCESS CRITERIA:
- [ ] Criterion 1
- [ ] Criterion 2

CONTEXT:
[Any relevant context from other agents' work]

Start by reading the files you need, then complete the task.
```

## Example Multi-Agent Day

### Morning (Supervisor)
```
Task: Fix avatars and improve character creation

Agent 1: Update Character API to support new fields (glasses, accessories)
Agent 2: None (waiting on Agent 1)
Agent 3: Create glasses picker and accessory picker widgets
Agent 4: None (waiting on feature completion)
```

### Midday (Check-in)
```
Agent 1: ✅ Completed API changes
Agent 3: ✅ Completed picker widgets
Supervisor: Assign Agent 2 to integrate widgets into character screen
```

### Afternoon
```
Agent 2: ✅ Integrated pickers, deployed
Supervisor: Assign Agent 4 to test character creation
```

### Evening
```
Agent 4: ✅ Tests passing, found minor bug in accessory save
Supervisor: Quick fix, verify, done for the day
```

## Benefits of This Structure

1. **Parallel Work:** 3-4 agents working simultaneously
2. **No Conflicts:** Clear file ownership prevents overwrites
3. **Session Limit Management:** Use cheaper models for routine work, save Claude for complex tasks
4. **Clear Communication:** TEAM_COORDINATION.md is single source of truth
5. **Fast Unblocking:** Supervisor monitors and responds quickly
6. **Quality:** Agent 4 dedicated to testing everything

## Getting Started

1. **Supervisor (you):** Read current project state in TEAM_COORDINATION.md
2. **Plan today's work:** What needs to be done?
3. **Break into agent tasks:** Use file ownership rules
4. **Start Agent 1:** Create session with template prompt
5. **Start Agent 2-4:** As dependencies allow
6. **Monitor:** Watch TEAM_COORDINATION.md
7. **Review & integrate:** When agents complete
8. **Repeat:** Plan next tasks

## Current Priority (Week 1, Function First)

Based on DEPLOYMENT_PLAN_3_WEEK.md, current priorities:
1. ✅ Stack Overflow fix (DONE - age gate bypass)
2. ❌ Interactive stories showing code (CRITICAL)
3. ❌ Avatars showing generic icons (CRITICAL)
4. ❌ Image generation not working (HIGH)
5. ⚠️ Age range limited to 3-17 (should be 3-99) (MEDIUM)

### Suggested First Agent Tasks:

**Agent 1 (Backend API):**
- Task: Debug and fix interactive story parsing
- Files: `backend/services/story_service.py`, `backend/routes/interactive_story.py`

**Agent 3 (Frontend Widgets):**
- Task: Fix avatar display to use DiceBear
- Files: `lib/avatar_models.dart` (line 67)

**Agent 2 (Frontend Core):**
- Task: (Wait for Agent 1) Update story result screen to display choices
- Files: `lib/story_result_screen.dart`

**Agent 4 (Testing):**
- Task: Document all current bugs with reproduction steps
- Files: Create `BUG_REPORT.md`

Ready to start? I can help you:
1. Create specific agent prompts
2. Monitor TEAM_COORDINATION.md
3. Unblock agents
4. Integrate their work
