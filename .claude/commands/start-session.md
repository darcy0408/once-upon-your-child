---
description: "Project briefing and session kickoff for Story Weaver development. Use this skill whenever the user says 'start session', 'what did I work on last', 'where did I leave off', 'catch me up', 'session briefing', 'what's the status', or anything suggesting they're sitting down to work and need context on the current state of the project. Also trigger when the user opens a new conversation and mentions Story Weaver development work."
---

Read the following files and give me a concise session briefing:

1. `TEAM_COORDINATION.md` — read the **first SESSION CLOSE block** (most recent session handoff) for last-session summary, pending items, blockers, and manual tasks; also scan the Pending Tasks table for any unchecked items
2. `backend_errors.log` — if it exists, flag any errors

Also run:
- `git log --oneline -5`
- `git status`
- `git branch -a | grep -v dependabot | head -10`

Then deliver a briefing in this format:

**Last Session:** [branch, date, 1-2 sentences — what was done]
**Left Unfinished:** [bullets from the SESSION CLOSE "Still Pending" and "Manual Tasks" sections]
**Git State:** [current branch, uncommitted changes, last commit]
**Active Errors:** [backend errors or "None — clean"]
**Suggested Focus:** [1-2 highest-priority items to tackle]

Keep it to one screenful. Bold key facts. No fluff.

**Important:** Keep `TEAM_COORDINATION.md` updated throughout the session. When fixes are completed, mark items as `[x]` with a brief note. When new issues are found, add them. Commit updates as needed.
