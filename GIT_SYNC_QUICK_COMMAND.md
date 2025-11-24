# Quick Git Sync Command - Story Weaver Project

## Purpose
Fast, safe synchronization command for any agent to use when they need to sync the repository. This complements the PROJECT_RULEBOOK.md workflow.

---

## 🚀 Quick Sync Prompt (Copy & Paste to Any Agent)

```
Execute a git sync now:
1. Check git status
2. Stage all changes with git add .
3. Commit with timestamp: [AGENT SYNC | YYYY-MM-DD HH:MM:SS] <brief description>
4. Pull from origin main with --strategy-option=ours --no-edit
5. Push to origin main
6. Report final status with commit hash
```

---

## 📋 Manual Command (For Terminal)

```bash
# One-liner sync (Windows PowerShell)
git add . && git commit -m "[AGENT SYNC | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Agent updates" && git pull origin main --strategy-option=ours --no-edit && git push origin main

# One-liner sync (Git Bash / Linux / Mac)
git add . && git commit -m "[AGENT SYNC | $(date '+%Y-%m-%d %H:%M:%S')] Agent updates" && git pull origin main --strategy-option=ours --no-edit && git push origin main
```

---

## 🤖 Agent Instructions

### When to Use This Sync:
- ✅ After completing a major task or set of changes
- ✅ Before switching to another agent
- ✅ When you see "Changes not staged for commit"
- ✅ At the end of your session
- ✅ When explicitly asked by the user

### When NOT to Use:
- ❌ In the middle of editing files
- ❌ When tests are failing (fix first, then sync)
- ❌ If you haven't made any changes
- ❌ Multiple times in rapid succession (wait for previous push to complete)

---

## 🔧 Execution Steps (Detailed)

### Step 1: Check Status
```bash
git status
```
**Expected Output:** List of modified, untracked, or deleted files
**Action:** Note what will be committed

### Step 2: Stage All Changes
```bash
git add .
```
**What This Does:** Stages all new, modified, and deleted files
**Note:** Respects .gitignore (won't stage .env, etc.)

### Step 3: Commit with Timestamp
```bash
# Windows PowerShell
git commit -m "[AGENT SYNC | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Brief description of changes"

# Git Bash / Linux / Mac
git commit -m "[AGENT SYNC | $(date '+%Y-%m-%d %H:%M:%S')] Brief description of changes"
```
**Format:** `[AGENT SYNC | 2025-11-23 21:30:00] Description`
**Description Examples:**
- "Stripe integration completed"
- "Fixed interactive story bug"
- "Updated frontend UI components"
- "Backend API enhancements"

### Step 4: Pull with Local Priority
```bash
git pull origin main --strategy-option=ours --no-edit
```
**What This Does:**
- Downloads latest changes from GitHub
- If conflicts occur, keeps YOUR local changes
- No interactive merge message editor

**Why `--strategy-option=ours`?**
- Matches PROJECT_RULEBOOK.md policy
- Prevents losing local agent work
- Assumes local changes are intentional and newer

### Step 5: Push to Remote
```bash
git push origin main
```
**What This Does:** Uploads your committed changes to GitHub
**Result:** Remote repository now matches your local state

### Step 6: Verify Success
```bash
git status
```
**Expected Output:**
```
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

**Get Final Commit Hash:**
```bash
git log -1 --oneline
```

---

## ⚠️ Error Handling

### Error: "nothing to commit, working tree clean"
**Meaning:** No changes to sync
**Action:** No sync needed, continue working

### Error: "Your branch is behind 'origin/main'"
**Meaning:** Remote has changes you don't have locally
**Fix:**
```bash
git pull origin main --strategy-option=ours --no-edit
```

### Error: "rejected (non-fast-forward)"
**Meaning:** Remote has commits you don't have
**Fix:** Run the full sync sequence again (pull before push)
```bash
git pull origin main --strategy-option=ours --no-edit && git push origin main
```

### Error: "CONFLICT (content): Merge conflict in <file>"
**Meaning:** Both local and remote changed the same lines
**Project Policy:** Use `--strategy-option=ours` (keeps local)
**Already Handled:** The `--strategy-option=ours` flag prevents this

### Error: "Authentication failed"
**Meaning:** Git credentials expired or missing
**Action:** Alert user, they need to re-authenticate with GitHub

### Error: "detached HEAD state"
**Meaning:** Not on main branch
**Fix:**
```bash
git checkout main
git pull origin main
```

---

## 🛡️ Safety Checks

### Before Syncing:
- [ ] Are you on the main branch? (`git branch` should show `* main`)
- [ ] Have you tested your changes? (at least basic verification)
- [ ] Are there any .env or secret files staged? (check `git status`)

### After Syncing:
- [ ] Does `git status` show "working tree clean"?
- [ ] Did `git log -1` show your commit with timestamp?
- [ ] Can you see your commit on GitHub? (optional verification)

---

## 📊 Verification Commands

```bash
# Check if sync was successful
git status

# View last 3 commits
git log --oneline -3

# Compare local and remote
git log origin/main..main  # Should be empty if synced
```

---

## 🎯 Quick Decision Tree

```
Do you have changes to sync?
├─ YES → Are tests passing?
│   ├─ YES → Run sync command
│   └─ NO → Fix tests first, then sync
└─ NO → No action needed
```

---

## 💡 Tips for AI Agents

1. **Always describe your changes** in the commit message
2. **Use present tense** ("Fix bug" not "Fixed bug")
3. **Be specific but brief** ("Add Stripe checkout" not "Changes")
4. **Sync at logical breakpoints** (after completing a feature, not mid-edit)
5. **Check status first** to avoid empty commits

---

## 🔗 Relationship to PROJECT_RULEBOOK.md

This document **complements** the rulebook:
- PROJECT_RULEBOOK.md: Full workflow for task execution
- GIT_SYNC_QUICK_COMMAND.md: Quick reference for just the sync part

**Conflict Resolution:** Both use `--strategy-option=ours` (local priority)
**Commit Format:** Both use `[AGENT SYNC | timestamp]` format
**Target Branch:** Both work on `main` directly

---

## 📝 Example Session

```bash
# Agent completes work and needs to sync
$ git status
On branch main
Changes not staged for commit:
	modified:   backend/app.py
	modified:   lib/services/stripe_service.dart

# Run sync
$ git add . && \
  git commit -m "[AGENT SYNC | 2025-11-23 21:45:00] Complete Stripe integration" && \
  git pull origin main --strategy-option=ours --no-edit && \
  git push origin main

# Output
[main abc1234] [AGENT SYNC | 2025-11-23 21:45:00] Complete Stripe integration
 2 files changed, 150 insertions(+), 20 deletions(-)
Already up to date.
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 2.45 KiB | 2.45 MiB/s, done.
Total 4 (delta 3), reused 0 (delta 0), pack-reused 0
To https://github.com/darcy0408/story-weaver-app.git
   def5678..abc1234  main -> main

# Verify
$ git status
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean

✅ Sync successful! Commit: abc1234
```

---

## 🆘 When to Ask for Help

Contact user if:
- Sync fails after 2 attempts
- Authentication errors occur
- Merge conflicts persist despite `--strategy-option=ours`
- You're not sure what to put in commit message
- The repository seems corrupted

---

**Last Updated:** 2025-11-23
**Maintained By:** Claude Code
**Complements:** PROJECT_RULEBOOK.md (Master Git Automation)
