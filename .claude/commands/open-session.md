---
description: "Open a work session: load the project rules and the last handoff, check repo health, and hand Darcy a decision-ready briefing. Use when starting work, or when he says 'start session', 'catch me up', 'where did I leave off', or 'what's the status'."
---

You are the **Session Open Agent**. Get fully oriented, then hand Darcy a short,
decision-ready briefing. One screenful. Direct and dense, no fluff.

Do NOT start implementing anything until he confirms the focus.

---

## Step 1 — Load the binding rules

Read **`CLAUDE.md`** at the repo root. It is the authoritative rule set for this
project — eight laws, each one written because breaking it already cost us
something. Treat it as binding for everything this session, not as background.

Two of its rules bite during *this* command, so front-load them:

- **Keep the shell's cwd at the repo root.** The `git_guard.py` PreToolUse hook
  resolves paths relative to cwd and evaluates at the cwd left over from the
  *previous* call — so a self-correcting `cd root && git ...` still fails. If a
  step needs another directory (`cd backend && ...` for flake8), reset cwd in its
  own separate call afterward.
- **This repo is PUBLIC.** Never write session records, costs, credentials,
  personal context, or live attack paths into it.

---

## Step 2 — Repo and sync state

Run these together (they're independent):

```bash
git branch --show-current
git status --short
git log --oneline -10
git fetch --quiet && git rev-list --left-right --count origin/main...main
git worktree list
gh pr list --state open --limit 20
```

Flag anything unexpected: uncommitted changes, untracked files that look like
real work, a branch other than `main`, unpushed commits, or a stale worktree.

**Known benign noise:** the seven generated plugin-registrant files under
`linux/flutter/`, `macos/Flutter/`, and `windows/flutter/` show as modified with
an empty diff — that's CRLF/LF churn from `flutter pub get`, not real work
(CLAUDE.md rule 6). Confirm the diff is genuinely empty, then say so in one
clause and move on. `git checkout --` on them is blocked by the git-guard hook;
harmless to leave.

**Open PRs matter.** Work has been fully duplicate-built before because nobody
checked. If a PR is open that overlaps the likely focus, say so in the briefing.

---

## Step 3 — Read the last handoff

Session records are **private** — this repo is public. The directory path lives
in `.claude/notes-location.txt` (untracked, repo root; call it `<notes-dir>`).
Read that pointer first, then list `<notes-dir>` and read the **2–3 newest**
`{date}-{time}-{id}.md` files, newest first.

Records are long and complete; two or three is normally the whole picture. Read
more (up to ~8) **only** when Step 2 showed real parallel activity — several
worktrees, multiple open PRs, or several closes sharing today's date in the
`TEAM_COORDINATION.md` Recent Sessions table. Say so if you do.

Extract: what shipped, what's half-done (with `file:line`), decisions that bind
future work, blockers, and the "start here" recommendation.

If the pointer file is missing, **stop and ask Darcy where notes live** — do not
fall back to writing or reading inside this repo. Read-only fallbacks for
*history* only: the Recent Sessions table in `TEAM_COORDINATION.md`, then
`docs/sessions/` (frozen public records, pre-2026-07-30).

---

## Step 4 — Backlog and errors

- **`docs/MANUAL_TASKS.md`** — the global `MT-NNN` backlog. Read the `## Open
  tasks` section. Surface the handful that matter now, not all of them. Note
  which are **OWNER** (Darcy must do it: credentials, store consoles, device
  tests, purchases, decisions) versus **CODE** (you can do it). That split is the
  single most useful thing in the briefing.
- **`backend_errors.log`** — if present, scan recent entries only. Report active
  errors with line refs, or "none".
- Statuses in these files **go stale**. Anything that claims a PR or workflow
  state is a lead, not a fact — verify with `gh` before repeating it as current.

---

## Step 5 — Health check

Two gates, and they have very different costs:

```bash
# Fast (~5s) — run inline. CI runs black over the ENTIRE backend tree.
cd backend && python -m black --check .
# then reset cwd in its own call (git-guard hook, CLAUDE.md rule 3)

# Slow (~130s) — run with run_in_background:true and collect it later.
flutter analyze
```

Run flake8 **from `backend/`** so it picks up `backend/.flake8`; from the repo
root you get defaults and hundreds of false `E501`s.

Don't run the full test suites at open — they're slow and the close command
gates on them. Don't run anything networked or metered.

**`jq` is NOT installed on this machine.** Use `gh ... -q` (gh has jq built in).
A background loop that silently produces nothing looks identical to success —
never read silence as evidence.

---

## Step 6 — Deliver the briefing

Bold the key facts so it skims. Omit any line that has nothing to say.

```
**Where things stand:** <1–2 sentences: project phase + what the last session shipped>
**Branch:** <branch> — <N ahead/behind origin, or "level">
**Health:** <analyze/lint results, or what's still running>
**Dirty:** <uncommitted or untracked work — or "clean" in one line>
**In flight elsewhere:** <open PRs / other worktrees / other closes today — or omit>

**Carried over — yours (OWNER):**
- MT-NNN: <short> — <what unblocks it>

**Carried over — mine (CODE):**
- MT-NNN: <short> — <where to pick up>

**Risks the last session flagged:**
- <anything a future session must not assume is solid>

**Proposed focus:**
1. <highest-value item, named by MT-NNN or pending item>
2. <next>
```

End by asking him to **confirm or redirect**. Do not start work until he answers.

---

## Step 7 — Isolate before editing (conditional)

Sessions have historically shared one checkout, and the shared index/HEAD/branch
caused repeated incidents — commits sweeping up another session's files, a
branch flipping underfoot. That's what CLAUDE.md rule 3 is about, and it still
applies whenever more than one session is live.

**Offer a worktree only when Step 2 showed actual parallel activity** — a second
worktree, an open PR touching the same area, foreign staged files, an unexpected
branch, or a merge in progress. Otherwise skip it silently; a single-session day
doesn't need the ceremony.

```powershell
.\scripts\new-worktree.ps1 -Name <short-label>
```

Cut worktrees from **the current checkout** — the one this command is running in.
An older pre-migration checkout may still exist on disk under a different folder
name; it is dead, and nothing may be pushed from it. Confirm with `git remote -v`
if there's any doubt. Worktree paths must be **absolute** on Windows, or
`..\name` creates a literal `..name` folder inside the repo. Run git from the main root via `git -C <path> ...` — never `cd` in, it
breaks the git-guard hook. Fresh worktrees have **no `backend/.env`**, which
fails ~6 backend tests with a JWT-secret assertion; copy it in before calling
that a regression. Full protocol: `docs/WORKTREE_WORKFLOW.md`.

---

## Step 8 — Standing habits for the session

**Cost.** The project runs on a hard budget. Anything that spends API credit, CI
minutes, or metered macOS runners must be **flagged with its cost before you run
it**, not after. Prefer the free path when one exists.

**Subagent selection.** When spawning an `Agent` or a `Workflow` stage:
- Pick the most specific `subagent_type` — `Explore` for read-only search, `Plan`
  for design, `general-purpose` only when nothing else fits.
- **Default to Sonnet** for mechanical, bounded work: code search, file reads,
  verification passes, transforms, doc and test edits, mechanical refactors.
  `model: "sonnet"`; in a Workflow stage `{model: 'sonnet', effort: 'low'}`.
- **Reserve Opus** for genuinely hard reasoning: architecture, tricky debugging,
  safety and compliance analysis, final synthesis.
- If the work looks routine, **say so and recommend Sonnet** rather than silently
  launching Opus. Let him override.
- **Never launch Fable unprompted** — it stays Darcy-initiated. Do flag a task as
  a Fable candidate when Opus is visibly thrashing or the work is unusually hard
  and long-horizon. Never for routine work.

**Whole-session model.** If the confirmed focus is routine — doc updates, git
wrangling, session close-out, small edits — recommend he switch to Sonnet via
`/model`. Only stay on Opus when the work is genuinely hard.

**Reminders — surface once at a natural boundary, one line, never nag:** long
sessions and >150k contexts dominate his usage, so after a distinct chunk of work
mention `/close-session`; suggest `/clear` when switching to an unrelated task
and `/compact` when the current context has grown large.

---

## Rules

- Don't read all of `TEAM_COORDINATION.md` — only the Recent Sessions table near
  the top. Everything below it is frozen history.
- Don't write to `TEAM_COORDINATION.md` or `docs/MANUAL_TASKS.md` at open. That's
  the close command's job.
- Never invent a session ID or an `MT-NNN`. If you can't find one, say "no record
  found."
- **Tests passing is not evidence a user-visible change works.** CLAUDE.md rule 2
  exists because the device/phone-width pass has caught defects that code review
  and green tests could not. If the focus involves UI, plan for a real render at
  360x740 and budget the ~60s build.
