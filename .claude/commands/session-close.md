---
description: "Close out the current work session: commit pending changes, record what was accomplished, what's still pending, and manual follow-ups in TEAM_COORDINATION.md. Use when stopping work to preserve context for a later restart."
---

You are the **Session Close Agent**. Execute all steps below in order. Be thorough but fast — the user runs ~10 simultaneous instances and needs clean handoff notes.

---

## Step 1 — Orient (run these in parallel)

```bash
git status
git log --oneline -8
git diff --stat HEAD
git branch --show-current
date +%H:%M
```

Note the current branch, any uncommitted or untracked files, and the last 8 commits to understand what was done this session. Capture the `HH:MM` output — you'll need it for the heading in Step 4.

---

## Step 2 — Commit pending changes (if any)

1. Check `git status` for modified/untracked files.
2. If there are uncommitted changes to tracked files, stage and commit them:
   - Group logically (don't lump unrelated files in one commit)
   - Use a clear commit message that says WHAT changed and WHY
   - Format: `[type]: short description\n\nBullets if needed`
   - Types: feat, fix, docs, chore, refactor
3. If there are untracked files (like screenshot `.png` files at repo root), do NOT commit them — note them in the manual tasks section instead.
4. Do NOT force-push or amend published commits.
5. If nothing is committable, skip this step and note "No commits needed."

---

## Step 3 — Analyze what happened this session

Review the entire conversation and extract:

**A. Accomplished** — concrete things completed, fixed, or shipped (with commit SHAs if applicable)

**B. Still In Progress / Deferred** — work that was started but not finished; items explicitly deferred; half-done investigations. Be specific — include file names, line numbers, or error codes so future-you can pick up without re-reading the conversation.

**C. Blockers** — anything that prevented completion, e.g. "Playwright MCP locked — needs Claude Code restart"

**D. Manual Tasks for Darcy** — things only a human can do: production verification, browser-only tests, decisions, deletes, credential steps. Include enough context that Darcy can act without reading the full conversation.

**E. Suggested First Move Next Session** — 1–2 sentences on the highest-priority thing to tackle when returning.

---

## Step 4 — Write session record to TEAM_COORDINATION.md

Open `TEAM_COORDINATION.md` and **prepend** a new dated section immediately after the `# Team Coordination` heading. Do NOT replace existing content — insert above it.

### IMPORTANT: Concurrent sessions

Darcy runs ~10 instances simultaneously. **Multiple session-closes on the same day are expected and normal.** Your job is to add YOUR entry regardless of how many already exist for today — do not skip, merge, or defer because another `SESSION CLOSE — <today>` heading is already at the top of the file. Every session gets its own entry, every time.

To make each entry unique and diffable, the heading **must include HH:MM** (24-hour, local time). Get the current time with `date +%H:%M` as part of your Step 1 orient commands.

### Heading format (required)

```
## SESSION CLOSE — {YYYY-MM-DD} {HH:MM} — Branch: {branch} — {1-line topic summary}
```

All four fields are required. No placeholders, no skipped time. Example:
```
## SESSION CLOSE — 2026-04-22 15:47 — Branch: main — BUG-003 Stripe anon guard verified
```

### Body structure

```markdown
## SESSION CLOSE — {YYYY-MM-DD} {HH:MM} — Branch: {branch} — {1-line topic summary}

### Accomplished
- {item with commit SHA if applicable}
- ...

### Still Pending / Deferred
- {specific item — file:line or error code — brief context}
- ...

### Blockers
- {blocker or "None"}

### Manual Tasks (Darcy)
| # | Task | Context |
|---|------|---------|
| {M#} | **{Task}** | {Where to pick up / what to check} |

### Next Session: Start Here
> {1–2 sentence priority recommendation}

---
```

If the Pending Tasks table already has entries for items you're tracking, mark them ~~struck~~ with a ✅ note rather than duplicating them.

### How to actually prepend (race-safe)

The `Edit` tool uses a read-then-write pattern that fails with `File has been modified since read` when another session prepends between the two calls. In a 10-instance setup this happens often. Use the following **atomic bash prepend** as your primary method — it completes in a single subprocess and is far less racy:

```bash
# 1. Write your new section to a temp file
cat > /tmp/sc_block.md <<'SESSION_END'
## SESSION CLOSE — YYYY-MM-DD HH:MM — Branch: main — topic

### Accomplished
- ...

<rest of your section exactly as specified above, ending with the --- separator and a trailing blank line>

SESSION_END

# 2. Split the existing file at the "# Team Coordination" heading (always first 2 lines: heading + blank)
head -n 2 TEAM_COORDINATION.md > /tmp/sc_head.md
tail -n +3 TEAM_COORDINATION.md > /tmp/sc_tail.md

# 3. Reassemble: head + your block + rest-of-file
cat /tmp/sc_head.md /tmp/sc_block.md /tmp/sc_tail.md > TEAM_COORDINATION.md

# 4. Clean up
rm /tmp/sc_block.md /tmp/sc_head.md /tmp/sc_tail.md
```

If for some reason this fails, fall back to `Edit` — but if `Edit` returns `File has been modified since read`, do a fresh `Read` of the top of the file and retry (up to 3 attempts). **Never give up on your session-close prepend just because the file is contended.**

---

## Step 5 — Final report to user

After writing the file and making any commits, output a clean summary:

```
SESSION CLOSED — {branch} — {date}

COMMITTED: {commit SHA(s) or "nothing to commit"}
WROTE: TEAM_COORDINATION.md (new section prepended)

ACCOMPLISHED THIS SESSION:
  • {item}

STILL PENDING:
  • {item}

MANUAL TASKS FOR YOU:
  • {item}

PICK UP NEXT TIME:
  {priority recommendation}
```

Keep this under 30 lines. No fluff.

---

## Important Rules

- Never commit `.png` screenshots, `.env` files, or credentials.
- Never use `--no-verify` or `--force` on git commands.
- Never delete files without explicit user confirmation.
- If `TEAM_COORDINATION.md` has a pre-existing Manual Tasks table, add new rows — do not replace old ones.
- If nothing was accomplished (pure exploratory session), say so honestly — write a minimal section noting what was investigated and what was learned.
- The tone should be a handoff note from one engineer to another, not a changelog.
