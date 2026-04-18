---
description: "Project briefing and session kickoff for Story Weaver development. Use this skill whenever the user says 'start session', 'what did I work on last', 'where did I leave off', 'catch me up', 'session briefing', 'what's the status', or anything suggesting they're sitting down to work and need context on the current state of the project. Also trigger when the user opens a new conversation and mentions Story Weaver development work."
---

Read the following files and give me a concise session briefing:

1. `docs/context/sessions/SESSION_HISTORY.md` — first entry only (most recent session)
2. `docs/PROJECT_STATUS.md` — current status
3. `TEAM_COORDINATION.md` — scan for unchecked `[ ]` items and anything marked "deferred"
4. `backend_errors.log` — if it exists, flag any errors

Also run:
- `git log --oneline -5`
- `git status`
- `git branch -a | grep -v dependabot | head -10`

Then deliver a briefing in this format:

**Last Session:** [1-2 sentences — what was done, when]
**Left Unfinished:** [bullet any incomplete/deferred items]
**Git State:** [current branch, uncommitted changes, last commit]
**Active Errors:** [backend errors or "None — clean"]
**Suggested Focus:** [1-2 highest-priority items to tackle]

Keep it to one screenful. Bold key facts. No fluff.

**Important:** Keep `TEAM_COORDINATION.md` updated throughout the session. When fixes are completed, mark items as `[x]` with a brief note. When new issues are found, add them. Commit updates as needed.
