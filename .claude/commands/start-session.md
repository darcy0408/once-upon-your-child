---
description: "Project briefing and session kickoff for Story Weaver development. Use this skill whenever the user says 'start session', 'what did I work on last', 'where did I leave off', 'catch me up', 'session briefing', 'what's the status', or anything suggesting they're sitting down to work and need context on the current state of the project. Also trigger when the user opens a new conversation and mentions Story Weaver development work."
---

You are the **Session Start Agent**. Brief Darcy on the current state of the project so they can pick up productively. Be concise — one screenful, no fluff.

The session-handoff system is **per-session-file based**: each closed session has its own file in `docs/sessions/`, indexed from the **Recent Sessions** table at the top of `TEAM_COORDINATION.md`. Manual tasks live globally in `docs/MANUAL_TASKS.md` with stable `MT-NNN` IDs.

---

## Step 1 — Gather context (run in parallel where possible)

```bash
git branch --show-current        # what branch is this instance on?
git status
git log --oneline -5
git branch -a | grep -v dependabot | head -10
```

Then read these files:

1. **`TEAM_COORDINATION.md`** — read the **Recent Sessions** table near the top (don't read the whole file; it's long and historical).
2. **`docs/MANUAL_TASKS.md`** — list of open manual tasks for Darcy.
3. **`backend_errors.log`** — if present, scan recent entries for active errors.

---

## Step 2 — Pick relevant session files

From the Recent Sessions table:

1. **Filter by current branch.** Find the most recent 1–3 rows where `Branch` matches the current branch.
2. **If none match**, fall back to the most recent row on `main` and explicitly note in the briefing: *"No prior closes on branch `<X>`; pulling context from main."*
3. **Read those session files** from `docs/sessions/`.
4. **Always note other live work today**: count rows from today's date and report e.g. *"Other today: 4 closes on main, 1 on bug-004-fix."*

---

## Step 3 — Conflict warning

For each "Files touched" listed in the session file(s) you read, check whether OTHER sessions in the table from the last 24h touched the same files. If so, warn:

> **⚠ File contention:** `lib/screens/welcome_screen.dart` was also edited by sessions `9c11` (14:22) and `b01a` (15:03) — review those commits before editing it.

This catches multi-instance collisions early.

---

## Step 4 — Deliver the briefing

Format (one screenful, bold the key facts):

```
**Branch:** <current-branch>
**Last Session (this branch):** [HH:MM, id, 1-2 sentences — what was done]
**Other Live Work Today:** [N closes on main, M on other branches — or "none"]

**Left Unfinished:**
- [bullets from session-file's "Still Pending"]
- ...

**Open Manual Tasks (yours to action):**
- MT-NNN: short description
- MT-NNN: short description
- (top ~5 — if more, say "+N more in docs/MANUAL_TASKS.md")

**Git State:** <branch>, [N uncommitted, X untracked] | last commit: <sha> <subject>

**Active Errors:** [backend errors with line refs, or "None — clean"]

**File Contention Warning:** [if any, from Step 3 — else omit this line]

**Suggested Focus:** [1–2 highest-priority items, calling out an MT-NNN or a Pending item by name]
```

---

## Important Rules

- Don't read the whole `TEAM_COORDINATION.md` — only the Recent Sessions table and Pending Tasks table near the top. Old SESSION CLOSE blocks below are historical, not current.
- Don't read more than 3 session files in `docs/sessions/`. If you need more context, ask Darcy first.
- Don't update or write to `TEAM_COORDINATION.md` during start. That's the close skill's job.
- If the Recent Sessions table is empty (fresh repo), say so and brief from `git log` only.
- Never invent session IDs or task IDs. If you can't find one, say "no record found."
