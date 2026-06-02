<#
.SYNOPSIS
    Create an isolated per-session git worktree for Story Weaver.

.DESCRIPTION
    Darcy runs ~10 concurrent Claude Code sessions in C:\dev\story-weaver-app.
    They SHARE one git index / HEAD / branch / working tree, so concurrent
    `git add`+commit, `reset --hard`, and `checkout` clobber each other (see
    docs/WORKTREE_WORKFLOW.md and the parallel-index-race notes).

    The durable fix is one worktree per session. This script creates a sibling
    worktree at C:\dev\sw-<name> on a fresh branch cut from origin/main, with its
    OWN index/HEAD/working tree backed by the same .git. Another session's
    checkout/reset in the main tree can no longer touch your files.

.PARAMETER Name
    Short kebab-case label for this session's work, e.g. "pricing" or "csp-fix".
    Becomes the dir (C:\dev\sw-<name>) and branch (session/<name>).

.PARAMETER BaseRef
    Ref to branch from. Default: origin/main (always cut from the latest remote
    main so you don't inherit a parallel session's local commits).

.PARAMETER NoFetch
    Skip the `git fetch origin` step (offline / already fresh).

.EXAMPLE
    .\scripts\new-worktree.ps1 -Name pricing
    Creates C:\dev\sw-pricing on branch session/pricing off origin/main.

.NOTES
    Gotchas this script defends against (learned the hard way):
      * Windows/PowerShell mangles relative `..\name` worktree paths into a
        literal "..name" folder INSIDE the repo -> always use absolute paths.
      * The git-guard PreToolUse hook resolves .claude/hooks/git_guard.py
        relative to the SHELL cwd. So do NOT `cd` into the worktree to run git.
        Keep your shell at the main repo root and drive git with
        `git -C C:\dev\sw-<name> ...` (see the printed next-steps banner).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [string]$BaseRef = "origin/main",

    [switch]$NoFetch
)

$ErrorActionPreference = "Stop"

# --- Resolve the MAIN repo root (this script lives in <root>\scripts) ----------
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
    throw "Could not find the main repo .git at '$RepoRoot'. Run this script from its checked-in location (<repo>\scripts\new-worktree.ps1)."
}

# --- Sanitize the name --------------------------------------------------------
$clean = ($Name.Trim().ToLower() -replace '[^a-z0-9-]', '-') -replace '-+', '-'
$clean = $clean.Trim('-')
if ([string]::IsNullOrWhiteSpace($clean)) {
    throw "Name '$Name' reduces to empty after sanitizing. Use letters/numbers/hyphens, e.g. -Name pricing."
}

$Branch       = "session/$clean"
$ParentDir    = Split-Path -Parent $RepoRoot          # normally C:\dev
$WorktreePath = Join-Path $ParentDir "sw-$clean"      # normally C:\dev\sw-<name>

# --- Pre-flight checks --------------------------------------------------------
if (Test-Path $WorktreePath) {
    throw "Worktree path already exists: $WorktreePath  (remove it first: git -C `"$RepoRoot`" worktree remove `"$WorktreePath`")"
}

$branchExists = (& git -C $RepoRoot branch --list $Branch)
if ($branchExists) {
    throw "Branch '$Branch' already exists. Pick a different -Name, or delete it: git -C `"$RepoRoot`" branch -D $Branch"
}

# --- Fetch latest remote so we branch from current origin/main ----------------
if (-not $NoFetch) {
    Write-Host "Fetching origin..." -ForegroundColor DarkGray
    & git -C $RepoRoot fetch origin --quiet
    if ($LASTEXITCODE -ne 0) { throw "git fetch origin failed." }
}

# --- Create the worktree (absolute path, fresh branch off the base ref) --------
Write-Host "Creating worktree '$WorktreePath' on branch '$Branch' from '$BaseRef'..." -ForegroundColor Cyan
& git -C $RepoRoot worktree add $WorktreePath -b $Branch $BaseRef
if ($LASTEXITCODE -ne 0) { throw "git worktree add failed." }

$tip = (& git -C $WorktreePath rev-parse --short HEAD)

# --- Next-steps banner --------------------------------------------------------
$banner = @"

  Worktree ready.
    Path:    $WorktreePath
    Branch:  $Branch  (tip $tip, from $BaseRef)

  HOW TO USE IT (keep your shell at the MAIN root: $RepoRoot)
    - Edit files with absolute paths under $WorktreePath
      (Read/Edit/Write tools are cwd-independent - prefer them).
    - Run git WITHOUT cd-ing in (avoids the git-guard hook cwd trap):
        git -C "$WorktreePath" add <paths>
        git -C "$WorktreePath" commit -m "..."
        git -C "$WorktreePath" push -u origin $Branch
    - Need flutter/pytest INSIDE the worktree? cd in and cd back in ONE call:
        cd "$WorktreePath"; flutter analyze; cd "$RepoRoot"

  INTEGRATE
        gh pr create --head $Branch --fill

  CLEANUP (after the PR merges)
        git -C "$RepoRoot" worktree remove "$WorktreePath"
        git -C "$RepoRoot" branch -d $Branch

  See docs/WORKTREE_WORKFLOW.md for the full protocol.

"@
Write-Host $banner -ForegroundColor Green
