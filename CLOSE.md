# CLOSE.md - Agent Session Completion & Git Sync

## 🏁 EXECUTE THIS AT THE END OF EVERY SESSION

---

## Step 1: Verify Your Work

Before committing, ensure:
- [ ] Code compiles (no syntax errors)
- [ ] Basic functionality tested (if applicable)
- [ ] No .env or secret files in your changes

**Quick check:**
```bash
git status
```
Review the list of changed files - does it look correct?

---

## Step 2: Stage All Changes

```bash
git add .
```

**What this does:** Stages all new, modified, and deleted files
**Note:** Respects `.gitignore` (won't stage .env, credentials, etc.)

---

## Step 3: Commit with Timestamp

### 3.1: Generate Timestamp

**Windows PowerShell:**
```powershell
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
echo $timestamp
```

**Git Bash / Linux / Mac:**
```bash
date '+%Y-%m-%d %H:%M:%S'
```

### 3.2: Create Commit

Use this exact format:

```bash
git commit -m "[AGENT SYNC | YYYY-MM-DD HH:MM:SS] Brief description of what you accomplished"
```

**Examples:**
- `[AGENT SYNC | 2025-11-23 21:45:00] Fix: Interactive story character_age bug`
- `[AGENT SYNC | 2025-11-23 21:45:00] Feat: Complete Stripe backend integration`
- `[AGENT SYNC | 2025-11-23 21:45:00] Docs: Update team coordination with task status`

**Windows PowerShell (with auto-timestamp):**
```powershell
git commit -m "[AGENT SYNC | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Your description here"
```

**Git Bash / Linux / Mac (with auto-timestamp):**
```bash
git commit -m "[AGENT SYNC | $(date '+%Y-%m-%d %H:%M:%S')] Your description here"
```

---

## Step 4: Sync with Remote (Pull Before Push)

```bash
git pull origin main --strategy-option=ours --no-edit
```

**What this does:**
- Downloads any changes other agents pushed while you were working
- If conflicts occur, keeps YOUR changes (`--strategy-option=ours`)
- Automatically merges without opening an editor

**Expected output:**
- `Already up to date.` (best case - no conflicts)
- Or: `Merge made by the 'recursive' strategy.` (auto-merged)

---

## Step 5: Push to GitHub

```bash
git push origin main
```

**What this does:** Uploads your committed changes to GitHub

**Expected output:**
```
Enumerating objects: X, done.
Counting objects: 100% (X/X), done.
Writing objects: 100% (X/X), Y KiB | Z MiB/s, done.
To https://github.com/darcy0408/story-weaver-app.git
   abc1234..def5678  main -> main
```

---

## Step 6: Verify Success

```bash
git status
```

**Expected output:**
```
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

Get your commit hash:
```bash
git log -1 --oneline
```

---

## Step 7: Update TEAM_COORDINATION.md

Add an entry to `TEAM_COORDINATION.md` documenting what you accomplished:

**Format:**
```markdown
- YYYY-MM-DD · [Agent Name] → Team: [Brief update]
  - Task completed: [Description]
  - Files modified: [Key files]
  - Status: [✅ Complete / ⚠️ Blocked / 🚧 In Progress]
  - Notes: [Any important info for other agents]
```

**Example:**
```markdown
- 2025-11-23 · Gemini → Team: STRIPE BACKEND INTEGRATION COMPLETED ✅
  - Registered stripe_routes and webhook_routes in app.py
  - Added subscription-status endpoint
  - Files: backend/app.py, backend/routes/stripe_routes.py
  - Status: ✅ Complete, tested on Railway
```

**Then commit the coordination update:**
```bash
git add TEAM_COORDINATION.md
git commit -m "[AGENT SYNC | $(date '+%Y-%m-%d %H:%M:%S')] Docs: Update team coordination"
git push origin main
```

---

## Step 8: Report Completion

After all steps complete, respond to the user:

```
✅ Task Integration Complete - Repository Synced
- Timestamp: YYYY-MM-DD HH:MM:SS
- Commit Hash: abc1234
- Changes Pushed: Yes
- TEAM_COORDINATION.md: Updated
- Working Tree: Clean

Session complete. All work saved to GitHub.
```

---

## 🔧 Error Handling

### Error: "nothing to commit, working tree clean"
**Meaning:** No changes were made
**Action:** Skip to Step 8, report "No changes to commit"

### Error: "rejected (non-fast-forward)"
**Meaning:** Remote has changes you don't have yet
**Fix:** Run Step 4 again, then retry Step 5:
```bash
git pull origin main --strategy-option=ours --no-edit
git push origin main
```

### Error: "CONFLICT (content): Merge conflict in <file>"
**This should NOT happen** with `--strategy-option=ours`, but if it does:
- **Stop immediately**
- **Alert user:** "⚠️ Manual merge required in <file>. Cannot auto-resolve."

### Error: "Authentication failed"
**Stop immediately**
**Alert user:** "⚠️ Git authentication failed. User needs to re-authenticate with GitHub."

---

## 🎯 Quick Reference - Full Command Sequence

**Windows PowerShell:**
```powershell
git add .
git commit -m "[AGENT SYNC | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Your description"
git pull origin main --strategy-option=ours --no-edit
git push origin main
git status
```

**Git Bash / Linux / Mac:**
```bash
git add .
git commit -m "[AGENT SYNC | $(date '+%Y-%m-%d %H:%M:%S')] Your description"
git pull origin main --strategy-option=ours --no-edit
git push origin main
git status
```

**One-liner (Git Bash):**
```bash
git add . && git commit -m "[AGENT SYNC | $(date '+%Y-%m-%d %H:%M:%S')] Your description" && git pull origin main --strategy-option=ours --no-edit && git push origin main
```

---

## 🛡️ Safety Protocols

### DO NOT commit:
- ❌ `.env` files
- ❌ `*key*.json` files
- ❌ `credentials.*` files
- ❌ API keys or secrets

### DO commit:
- ✅ `.env.example` (template files)
- ✅ Code files (`.py`, `.dart`, `.js`, etc.)
- ✅ Documentation (`.md` files)
- ✅ Configuration (non-secret configs)

**The `.gitignore` file protects you**, but always verify with `git status` before committing!

---

## 📊 Success Criteria

Before ending session, verify:
- [x] All changes committed with timestamped message
- [x] Changes pulled from remote (no surprises)
- [x] Changes pushed to GitHub
- [x] TEAM_COORDINATION.md updated
- [x] `git status` shows clean working tree
- [x] No secrets or .env files committed

---

**Session End Complete** → Your work is safely stored on GitHub. Other agents can now see your changes.
