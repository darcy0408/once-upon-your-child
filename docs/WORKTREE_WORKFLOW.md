# Worktree-per-session workflow

Darcy runs ~10 concurrent Claude Code sessions in `C:\dev\story-weaver-app`. They all
share **one** git index, HEAD, branch, and working tree. That sharing is the root cause
of a long tail of incidents:

- `git add` + `commit` in one session sweeps up another session's staged files.
- `git reset --hard` / `git checkout` in one session silently reverts another's
  uncommitted edits and flips its branch.
- A merge started by session A blocks session B from committing at all.

The durable fix is **one git worktree per session**: each session gets its own
directory, index, and HEAD backed by the same `.git`. A checkout/reset in the main tree
can no longer touch your files.

## Start a session

From the main repo root, run:

```powershell
.\scripts\new-worktree.ps1 -Name <short-label>
```

Example: `-Name pricing` creates `C:\dev\sw-pricing` on branch `session/pricing`, cut
fresh from `origin/main`. Worktrees are **sibling dirs** (`C:\dev\sw-<name>`), kept
outside the repo so the main checkout stays clean.

Options: `-BaseRef <ref>` (default `origin/main`), `-NoFetch` (skip the fetch).

## The two rules that prevent the known traps

1. **Absolute paths only.** PowerShell turns a relative `..\name` worktree path into a
   literal `..name` folder *inside* the repo. The script always uses absolute paths;
   if you ever run `git worktree add` by hand, do the same.

2. **Keep your shell at the main root; drive git with `git -C`.** The `git-guard`
   PreToolUse hook resolves `.claude/hooks/git_guard.py` relative to the shell's cwd.
   If you `cd` into a worktree and run git, the hook can't find itself and **every git
   command in that shell breaks**. So:

   ```powershell
   # from C:\dev\story-weaver-app (main root):
   git -C C:\dev\sw-pricing add <paths>
   git -C C:\dev\sw-pricing commit -m "feat: ..."
   git -C C:\dev\sw-pricing push -u origin session/pricing
   ```

   Edit files with absolute paths under the worktree (Read/Edit/Write tools are
   cwd-independent — prefer them over shell file ops). If you must run `flutter
   analyze` / `pytest` *inside* the worktree, `cd` in and `cd` back in the **same**
   Bash call: `cd C:\dev\sw-pricing; flutter analyze; cd C:\dev\story-weaver-app`.

## Integrate via PR

Never edit `main`'s working tree directly. Push your branch and open a PR:

```powershell
git -C C:\dev\sw-pricing push -u origin session/pricing
gh pr create --head session/pricing --fill
```

If you want a nicer PR branch name than `session/<name>`:
`git -C C:\dev\sw-pricing push origin HEAD:refs/heads/<nice-name>` then
`gh pr create --head <nice-name>`.

## Clean up after merge

```powershell
git -C C:\dev\story-weaver-app worktree remove C:\dev\sw-pricing
git -C C:\dev\story-weaver-app branch -d session/pricing
```

List/inspect worktrees anytime: `git worktree list`. Prune stale registrations after a
manual folder delete: `git worktree prune`.

## Gotchas (hard-won)

- **Commit early.** Commit objects live in shared `.git` and survive any main-tree
  `reset --hard`. Uncommitted edits in a worktree are safe from *other* sessions, but
  commit anyway so nothing is lost to your own mistakes.
- **A `locked` worktree is not proof of a live session.** Claude agent worktrees keep
  their lock string if the parent process exits abnormally — locks persist on disk
  indefinitely. Don't infer "another session is here" from a stale lock; ask, or check
  `git log -1 --format=%cs <branch>` for a stale tip.
- **Subagent `isolation: "worktree"` does not fully escape the race** — it branches off
  whatever HEAD is at creation time, which a parallel session may have advanced. For
  real isolation use a dedicated worktree created by this script and cut from
  `origin/main`.
- **Don't put a failing command (`exit 1`/`false`) in a parallel tool batch as a
  "flush"** — an erroring call cancels every other queued call in the batch. Use plain
  `echo` probes to wait.
