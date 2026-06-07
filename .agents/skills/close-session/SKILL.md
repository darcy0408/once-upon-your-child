---
name: close-session
description: "Close out the current work session: commit pending changes, write a per-session record file in docs/sessions/, append manual tasks to docs/MANUAL_TASKS.md with monotonic IDs, and add an index row to TEAM_COORDINATION.md. Use when the user requests to close the session or stop work."
---

You are the **Session Close Agent** for Story Weaver / Once Upon YOUR Child. Execute every step thoroughly and quickly to ensure a clean handoff.

The system is **race-safe by design**: each session writes to its own file in `docs/sessions/`, so concurrent closes never collide. The shared `TEAM_COORDINATION.md` is only touched once per session (a single appended index row), and `docs/MANUAL_TASKS.md` is append-only.

---

## Step 1 — Orient

Gather the context needed for the session record. Run these in the terminal (adjusting for Windows PowerShell or POSIX bash):

1. Git Status: `git status`
2. Git Log: `git log --oneline -8`
3. Git Diff: `git diff --stat HEAD`
4. Branch Name: `git branch --show-current`
5. Date & Time:
   - **PowerShell**: `Get-Date -Format "yyyy-MM-dd HH:mm"`
   - **Bash**: `date +"%Y-%m-%d %H:%M"`
   - **Python Fallback**: `python -c "import datetime; print(datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))"`
6. 4-character Session ID (hex):
   - **PowerShell**: `-join ((48..57+97..102) | Get-Random -Count 4 | %{[char]$_})`
   - **Bash**: `openssl rand -hex 2`
   - **Python Fallback**: `python -c "import random; print(''.join(random.choices('0123456789abcdef', k=4)))"`

Capture the date, time, branch name, and the 4-char session ID. You need all four for the filename and heading.

---

## Step 2 — Commit pending changes (if any)

1. Check `git status` for modified/untracked files.
2. If there are uncommitted changes to tracked files **owned by this session**, stage and commit them:
   - Group logically (don't lump unrelated files in one commit).
   - Format: `[type]: short description\n\nBullets if needed`
   - Types: `feat`, `fix`, `docs`, `chore`, `refactor`
3. **Untracked files** (`.png` screenshots, `.env`, scratch scripts) — never commit. Note them in Manual Tasks.
4. **Modified files that aren't from this session** (parallel-session work in flight) — leave alone, mention in the session record.
5. Do NOT force-push, amend published commits, or use `--no-verify`.
6. If nothing committable, note "No commits needed" in the record.

---

## Step 3 — Analyze what happened

Review the conversation and extract:

- **Accomplished** — concrete things shipped (with commit SHAs)
- **Still Pending / Deferred** — half-done work, with file:line or error code so future-you can pick up
- **Blockers** — what stopped completion
- **Files touched** — every path that appears in `git diff --name-only` for your commits this session
- **Manual Tasks** — things only Darcy can do (production verification, browser-only tests, decisions, deletes, credential steps, restarts)
- **Next session: start here** — 1–2 sentence recommendation

---

## Step 4 — Update `docs/MANUAL_TASKS.md` (manual-task backlog)

This file is the global, append-only manual-task backlog. **Read it first**, then update.

### 4a. Closing tasks you resolved this session
If your session resolved any open `MT-NNN` items, find each line under `## Open tasks` and update it in place:
```
- **MT-042** [open] Visual smoke-test adolescent flow (created by 9c11) — context.
```
becomes
```
- **MT-042** [done] Visual smoke-test adolescent flow (created by 9c11) — context. (closed by a7f3)
```
Then **move the line** from `## Open tasks` to the top of `## Closed tasks`. Use the file edit tools for in-place updates.

### 4b. Adding new manual tasks
Before adding, **scan the last ~10 entries under `## Open tasks`** for duplicates. If your task already exists (fuzzy match — same first noun and same intent), reference its existing `MT-NNN` in your session record and DO NOT add a new one.

If genuinely new, **find the highest MT-NNN currently in the file** (open OR closed) and increment by 1, padded to 3 digits. Append at the top of `## Open tasks`:
```
- **MT-NNN** [open] Short imperative task (created by <session-id>) — where to pick up / what to check.
```
If two sessions race on the same number, the second one to write will see its edit fail and should retry with `MT-(N+1)`.

---

## Step 5 — Write the per-session record file

Path: `docs/sessions/{YYYY-MM-DD}-{HHMM}-{id}.md`
Example: `docs/sessions/2026-04-22-1547-a7f3.md`

This file is yours alone — no other session writes to it. Use a single `write_to_file` call.

### File template

```markdown
# SESSION CLOSE — {YYYY-MM-DD} {HH:MM} [{id}] — Branch: {branch} — {1-line topic summary}

## Accomplished
- {item with commit SHA}
- ...

## Still Pending / Deferred
- {file:line or error code — brief context}
- ...

## Blockers
- {blocker — or "None"}

## Files touched
- {path1}
- {path2}
- ...

## Manual tasks
- Created: {MT-NNN, MT-NNN+1}    (or "none")
- Closed:  {MT-NNN, MT-NNN+2}    (or "none")

## Next session: start here
> {1–2 sentences}
```

If nothing was accomplished (pure exploratory session), write a minimal record noting what was investigated and what was learned. Honesty over filler.

---

## Step 6 — Append index row to `TEAM_COORDINATION.md`

`TEAM_COORDINATION.md` has a **Recent Sessions** table near the top. Insert your row directly **after the marker comment that sits below the `|---|---|...|` separator row** (so newest is on top, above all existing data rows).

### How to insert safely
Use the `replace_file_content` tool to locate the marker comment:
`<!-- New session-close entries go here. Most recent at top. -->`
And insert your row immediately below it, preserving the marker comment. This is extremely robust and avoids platform-dependent awk/sed shell commands.

Row Format:
```markdown
| {YYYY-MM-DD} | {HH:MM} | {id} | {branch} | {topic ≤60 chars} | [link](docs/sessions/{YYYY-MM-DD}-{HHMM}-{id}.md) |
```

If the edit fails because the file was modified concurrently, read the file again and retry.

---

## Step 7 — Commit the docs

Stage and commit all three doc updates together:
```bash
git add docs/sessions/{YYYY-MM-DD}-{HHMM}-{id}.md docs/MANUAL_TASKS.md TEAM_COORDINATION.md
git commit -m "docs(session): close {id} — {1-line topic}"
```

---

## Step 7b — Push to remote

Push your committed work, regardless of what's in the working tree:
```bash
git push
```
If `git push` fails due to a non-fast-forward (another session pushed first), run:
```bash
git pull --rebase && git push
```
Do NOT use `--force` or `--force-with-lease` to resolve a non-fast-forward — always rebase.

**If the push is rejected by branch protection** (error mentions `protected branch`, force-push, or deletion blocked) — this is NOT a routine non-fast-forward. `main` is protected against force-push and deletion, so this rejection means something attempted to rewrite or delete history on `main`, which must never happen on a normal close. Do NOT retry, rebase around it, or work around it. **Stop and surface the exact error to Darcy** — it signals a real problem (e.g. a stale local `main`, a bad reset, or a misdirected push).

---

## Step 8 — Final report to user

Output this summary (≤30 lines) directly in your response:

```
SESSION CLOSED — {branch} — {YYYY-MM-DD} {HH:MM} [{id}]

COMMITTED THIS SESSION: {commit SHA(s) or "nothing"}
SESSION RECORD: docs/sessions/{file}.md

ACCOMPLISHED:
  • {item}

STILL PENDING:
  • {item}

MANUAL TASKS:
  Created: MT-NNN, MT-NNN
  Closed:  MT-NNN
  See: docs/MANUAL_TASKS.md

PICK UP NEXT TIME:
  {priority recommendation}
```

---

## Important Rules

- Never commit `.png` screenshots, `.env` files, scratch scripts, or credentials.
- Never use `--no-verify` or `--force` on git commands.
- Never delete files without explicit user confirmation.
- Never modify or delete other sessions' record files in `docs/sessions/`.
- Never renumber `MT-NNN` IDs or rewrite history in `MANUAL_TASKS.md`.
- Push after every session close (Step 7b).
- The tone of session records should be a handoff note from one engineer to another, not a changelog.
- If absolutely nothing happened this session (pure read), still write the record — a one-paragraph "explored X, learned Y, no changes" is better than silence.
