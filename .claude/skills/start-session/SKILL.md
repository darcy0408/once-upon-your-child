---
name: start-session
description: "Project briefing and session kickoff for Story Weaver development. Use this skill whenever the user says 'start session', 'what did I work on last', 'where did I leave off', 'catch me up', 'session briefing', 'what's the status', or anything suggesting they're sitting down to work and need context on the current state of the project. Also trigger when the user opens a new conversation and mentions Story Weaver development work."
---

# Start Session — Story Weaver Project Briefing

You're helping Darcy, a solo developer building Story Weaver (therapeutic AI storytelling app for kids). This skill gathers project state and delivers a concise briefing so Darcy can jump right into productive work.

## What to do

Read the following files in parallel, then synthesize a briefing:

### 1. Gather context (read all of these)

- `docs/context/sessions/SESSION_HISTORY.md` — Read the **first entry only** (most recent session). Extract: what was done, what was left unfinished, any handoff notes.
- `docs/PROJECT_STATUS.md` — Current project status, in-progress items, planned features.
- `TEAM_COORDINATION.md` — Scan for any items marked with `[ ]` (unchecked boxes) or "deferred". These are open action items.
- `backend_errors.log` — Check if it exists and has recent content. If so, flag the errors.

### 2. Check git state

Run these bash commands:
- `git log --oneline -5` — Last 5 commits (what happened recently)
- `git status` — Any uncommitted work or untracked files
- `git branch -a | grep -v dependabot | head -10` — Active branches (filter out dependabot noise)

### 3. Deliver the briefing

Format the briefing as a concise, scannable summary. Keep it short and action-oriented — Darcy's preference is "direct and dense, no fluff."

**Structure:**

**Last Session:** [1-2 sentences on what was accomplished and when]

**Left Unfinished:** [Bullet any incomplete items from session history + deferred items from TEAM_COORDINATION]

**Git State:** [Current branch, uncommitted changes if any, last commit]

**Active Errors:** [Any backend errors or "None — clean"]

**Suggested Focus:** [Based on what's unfinished and what seems highest-priority, suggest 1-2 things to tackle. Frame these as options, not commands — Darcy makes the call.]

### 4. Isolate this session before editing code

Darcy runs ~10 concurrent sessions in one checkout (`C:\dev\story-weaver-app`), sharing a single git index/HEAD/branch/working tree — the cause of repeated commit-contamination, `reset --hard` wipes, and branch-flip incidents. **Before making any code or doc edits**, offer to set up an isolated worktree:

```powershell
.\scripts\new-worktree.ps1 -Name <short-label>   # e.g. -Name pricing
```

Creates a sibling worktree `C:\dev\sw-<label>` on `session/<label>` cut from `origin/main`. Edit there (absolute paths), run git from the main root via `git -C C:\dev\sw-<label> ...` (never `cd` in for git), integrate via PR. Full protocol: `docs/WORKTREE_WORKFLOW.md`. Skip only for a pure read-only briefing; treat as mandatory if the git state shows another session's in-flight work.

### Guidelines

- Be concise. The whole briefing should fit in one screenful.
- Bold key facts so Darcy can skim.
- If PROJECT_STATUS.md is stale (last updated months ago), mention that it needs updating and offer to refresh it at end of session.
- If there are deferred UX bugs in TEAM_COORDINATION.md, count them and list the critical/high ones by ID.
- Don't repeat information Darcy already knows (like what the app does). Jump straight to actionable state.
- **Keep `TEAM_COORDINATION.md` updated throughout the session.** When fixes are completed, mark items as `[x]` with a brief note. When new issues are found, add them. Commit updates as needed.
