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

Darcy runs ~10 simultaneous instances, so the relevant handoff context is usually spread across many recent closes — not just the most recent one. Read **up to 15 session files** with branch-aware prioritisation:

1. **First fill (branch-matched).** From the Recent Sessions table, find every row where `Branch` matches the current branch. Take the most recent **up to 10**.
2. **Then top up (main-branch context).** If the result has fewer than 15 entries and the current branch is not `main`, add the most recent `main`-branch rows until you reach 15. Note in the briefing: *"Including N closes from main for context."*
3. **If the current branch is `main`**, just take the most recent 15 rows from any branch.
4. **If a row's `File` link points to a path that doesn't exist**, skip that row (it may be from before the per-session file system, or the file was archived) — don't fail.
5. **Read each selected session file** from `docs/sessions/`. These files are small (30–60 lines each); reading 15 is fine.
6. **Always note other live work today**: count rows from today's date in the table and report e.g. *"15 closes today across 4 branches."*

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
- Read up to 15 session files in `docs/sessions/` per Step 2. Reading more without a specific reason wastes context; reading fewer misses cross-instance context.
- Don't update or write to `TEAM_COORDINATION.md` during start. That's the close skill's job.
- If the Recent Sessions table is empty (fresh repo), say so and brief from `git log` only.
- Never invent session IDs or task IDs. If you can't find one, say "no record found."
