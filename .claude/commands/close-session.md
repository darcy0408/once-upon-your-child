---
description: "Close a work session: verify, commit by path, write a per-session record to the PRIVATE notes directory, update the MT-NNN backlog and the TEAM_COORDINATION index, then push. Use when stopping work."
---

You are the **Session Close Agent**. Execute every step. Be thorough but fast.

The goal: nothing in flight is lost, the repo is left in a state a cold session
can pick up, and Darcy gets an honest summary — including what *isn't* done.

**This repo is PUBLIC. Session records are private.** They go to the directory
whose path is in `.claude/notes-location.txt` (untracked, repo root — read it
first; call it `<notes-dir>`). If that file is missing, **STOP and ask Darcy**
where notes live. Never fall back to writing a record inside this repo. Records
closed before 2026-07-30 sit read-only in `docs/sessions/`; never add there.

The system is **race-safe by design**: each session writes its own file in
`<notes-dir>`, so concurrent closes never collide. `TEAM_COORDINATION.md` gets
exactly one appended row, and `docs/MANUAL_TASKS.md` is append-only.

**`TEAM_COORDINATION.md` and `docs/MANUAL_TASKS.md` are also public.** Keep what
you write there sanitized — what *area* was worked on, never an unverified
vulnerability, a flag state, a money figure, a private filesystem path, or
personal context. All of that belongs in the private record.

---

## Step 1 — Orient

Run in parallel:

```bash
git status --short
git log --oneline -8
git diff --stat HEAD
git branch --show-current
date +"%Y-%m-%d %H:%M"
openssl rand -hex 2              # 4-char session ID, e.g. a7f3
cat .claude/notes-location.txt   # <notes-dir> — the PRIVATE record location
```

Capture date, time, branch, session ID, and `<notes-dir>` — you need all five.

**Keep the shell's cwd at the repo root** (CLAUDE.md rule 3). The git-guard hook
evaluates at the *previous* call's cwd, so a self-correcting `cd root && git ...`
still fails. If a step needs `backend/`, reset cwd in its own separate call.

---

## Step 2 — Verify before committing

Run the gates for whatever this session actually touched. Never silently commit
red — if something fails, tell Darcy and ask whether to fix now or commit as WIP
with the failure recorded.

```bash
flutter analyze                             # ~130s — background it
cd backend && python -m black --check .     # CI checks the ENTIRE tree, incl. new untracked files
cd backend && python -m flake8              # must run FROM backend/ for .flake8 to apply
```

Then the suites for the touched side (Flutter `test/`, or `backend/tests/`).

**If this session changed anything user-visible, CLAUDE.md rule 2 applies:** a
green test suite is not evidence. Build web release, serve it, and drive it at
360x740 before calling the fix done. The device pass has caught defects that code
review and passing tests could not — repeatedly. If you did not do it, do not
imply you did: record it under "Risks / unverified" in plain words.

`jq` is **not installed**. Use `gh ... -q` for CI checks, and never read a silent
background loop as success.

---

## Step 3 — Commit pending changes

1. **Commit by explicit path** — `git commit -- <paths>` — never staged-mode
   (CLAUDE.md rule 3). A staged commit once swept in a parallel session's images
   and a 48-line edit that was never `git add`-ed.
2. **Run `git branch --show-current` first.** A parallel session's `checkout -b`
   moves the branch under everyone. To recover, point main at your specific
   **commit hash** (`git branch -f main <hash>`) — never at a branch name another
   session is still committing to.
3. Group logically; don't lump unrelated files together. Format:
   `type: short description` + bullets. Types: feat, fix, docs, chore, refactor.
4. **Never commit** `.png` screenshots, `.env`, scratch scripts, or credentials.
   Note them in Manual Tasks instead.
5. **Leave alone** modified files that aren't yours — parallel work in flight.
   Mention them in the record. The seven generated plugin-registrant files with
   empty diffs are CRLF/LF churn, not work (CLAUDE.md rule 6); leave them.
6. Never `--force`, never `--no-verify`, never amend a published commit.
7. Nothing committable? Note "No commits needed" in the record.

---

## Step 4 — Analyze what happened

Extract from the session:

- **Accomplished** — what shipped, with commit SHAs.
- **Still pending / deferred** — with `file:line` or an error code so future-you
  can resume cold.
- **Decisions** — choices made and the one-line why, especially anything that
  overrides or extends earlier direction. These bind future sessions.
- **Blockers** — what stopped completion.
- **Files touched** — every path in `git diff --name-only` for your commits.
- **Manual tasks** — things only Darcy can do: production verification,
  device-only tests, credentials, store consoles, purchases, decisions, deletes.
- **Verification level** — be precise. "tests pass", "source-verified only",
  "seen working on a device" are three very different claims.

---

## Step 5 — Update `docs/MANUAL_TASKS.md`

Append-only global backlog. **Read it first.**

**Closing tasks you resolved.** Update the line in place under `## Open tasks`:

```
- **MT-042** [open] Visual smoke-test adolescent flow (created by 9c11) — context.
```
becomes
```
- **MT-042** [done] Visual smoke-test adolescent flow (created by 9c11) — context. (closed by a7f3)
```

Then move the line to the top of `## Closed tasks`. Use `Edit` for in-place
updates.

**Adding new tasks.** Scan the last ~10 entries under `## Open tasks` for
duplicates first — fuzzy match, same first noun and same intent. If it already
exists, cite the existing `MT-NNN` in your record and do NOT add another.

If genuinely new, take the highest `MT-NNN` in the file (open **or** closed),
increment, pad to 3 digits, and append at the top of `## Open tasks`:

```
- **MT-NNN** [open] OWNER|CODE / <kind> — Short imperative task (created by <id>) — where to pick up.
```

Mark **OWNER** (only Darcy can do it) or **CODE** (a session can) — the open
command splits the briefing on that and it's the most useful field in the file.

IDs race across parallel sessions: take the max across `main`, any open PR
diffs, and unpushed closes. If an `Edit` fails because another session wrote
first, retry at `MT-(N+1)`. **Never renumber existing IDs.**

---

## Step 6 — Write the private session record

Path: `<notes-dir>\{YYYY-MM-DD}-{HHMM}-{id}.md`, using the `<notes-dir>` you read
in Step 1. **NOT inside this repo.** The real path lives only in the untracked
pointer file — never write it into any tracked file, including this one.

This file is yours alone. Single `Write` call.

```markdown
# SESSION CLOSE — {YYYY-MM-DD} {HH:MM} [{id}] — Branch: {branch} — {1-line topic}

## Accomplished
- {item, with commit SHA}

## Decisions
- {choice — and the one-line why}

## Still pending / deferred
- {file:line or error code — brief context}

## Blockers
- {blocker — or "None"}

## Blocked on Darcy
- {credentials, device tests, store consoles, purchases, decisions — or omit}

## Risks / unverified
- {what a future session must NOT assume is solid — or omit}

## Files touched
- {path}

## Manual tasks
- Created: {MT-NNN}   (or "none")
- Closed:  {MT-NNN}   (or "none")

## Verification level
- {precisely what was and wasn't proven}

## Next session: start here
> {1–2 sentences}
```

Write it for a reader with **zero context**: no shorthand, no unexplained
codenames, spell out file paths. Tone is a handoff note between engineers, not a
changelog. Pure exploratory session? Still write it — "explored X, learned Y, no
changes" beats silence. Honesty over filler.

---

## Step 7 — Append the index row to `TEAM_COORDINATION.md`

One row, at the top of the Recent Sessions table body.

```bash
ROW="| {YYYY-MM-DD} | {HH:MM} | {id} | {branch} | {topic} | private |"
```

The last column is the literal word `private` — records aren't linkable from a
public file. Keep the topic to **one or two sentences**: this table is an index,
and rows have drifted into essay length, which defeats it. Detail goes in the
private record. Keep it sanitized (see the intro).

Race-safe insert — prints the marker first, so the new row lands on top:

```bash
awk -v row="$ROW" '
  /^<!-- New session-close entries go here\. Most recent at top\. -->$/ {
    print
    print row
    next
  }
  { print }
' TEAM_COORDINATION.md > TEAM_COORDINATION.md.tmp && mv TEAM_COORDINATION.md.tmp TEAM_COORDINATION.md
```

If the marker is missing, fall back to `Read` + `Edit` to insert below the table
separator, retrying up to 3 times on "File has been modified since read."

---

## Step 8 — Commit the docs (two repos)

**In this (public) repo** — only the two shared index files. The record must
never appear here:

```bash
git commit -- docs/MANUAL_TASKS.md TEAM_COORDINATION.md -m "docs(session): close {id} — {1-line topic}"
```

**In the private notes repo** — commit the record by path and push. Use `git -C`
from here; do not `cd` into it. `<notes-repo-root>` is the git root containing
`<notes-dir>`:

```bash
git -C "<notes-repo-root>" add "<record path relative to that root>"
git -C "<notes-repo-root>" commit -m "notes(session): {id} — {1-line topic}"
git -C "<notes-repo-root>" push
```

If the private push fails, report it — the record still exists on disk.

---

## Step 9 — Push

```bash
git push
```

Push regardless of what's in the working tree: `git push` only sends commits, so
a parallel session's uncommitted files on disk are unaffected. That is **not** a
reason to skip it.

On a non-fast-forward, `git pull --rebase && git push`. **Never** `--force` or
`--force-with-lease`. If the push fails or there's no remote, say so explicitly —
don't let Darcy believe work is backed up when it isn't.

Note `gh pr merge --delete-branch` fails when worktrees are present; the merge
still succeeds server-side. Merge without the flag, then delete the remote branch
via the API.

---

## Step 10 — Final report

≤30 lines. Lead with anything left dirty, red, or unpushed.

```
SESSION CLOSED — {branch} — {YYYY-MM-DD} {HH:MM} [{id}]

COMMITTED: {SHAs, or "nothing"}
PUSHED:    {yes / no — and why not}
RECORD:    <notes-dir>\{file}.md (private)

ACCOMPLISHED
  • {item}

STILL PENDING
  • {item}

MANUAL TASKS
  Created: MT-NNN    Closed: MT-NNN
  See docs/MANUAL_TASKS.md

PICK UP NEXT TIME
  {priority recommendation}
```

---

## Rules

- Never write a session record inside this repo — it is PUBLIC.
- Never modify or delete another session's record, in `<notes-dir>` or the frozen
  `docs/sessions/`.
- Never renumber `MT-NNN` IDs or rewrite history in `MANUAL_TASKS.md`.
- Never commit screenshots, `.env`, scratch scripts, or credentials.
- Never use `--force` or `--no-verify`.
- Never delete files without Darcy's explicit confirmation.
- Never claim a verification level you didn't reach. "Tests pass" is not "works".
