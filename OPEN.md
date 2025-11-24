# OPEN.md - Agent Session Initialization

## 🚀 EXECUTE THIS AT THE START OF EVERY SESSION

---

## Step 1: Read Project Documentation (Required)

Before starting any work, read these files in order:

1. **`PROJECT_RULEBOOK.md`** - Master rules, git workflow, code standards, therapeutic safety protocols
2. **`TEAM_COORDINATION.md`** - Current project status, recent updates, what other agents are working on

**Purpose:** Understand the project context, rules, and current state before making changes.

---

## Step 2: Sync Repository (Pull Latest Code)

Execute these git commands to ensure you have the latest code:

### 2.1: Check Current Status
```bash
git status
```
**Expected:** Should show you're on `main` branch

### 2.2: Handle Existing Changes (If Any)
If `git status` shows uncommitted changes:
```bash
git stash
```
**Note:** This temporarily saves any local changes

### 2.3: Pull Latest from Remote
```bash
git pull origin main --strategy-option=ours --no-edit
```
**What this does:**
- Downloads latest code from GitHub
- If conflicts occur, keeps local changes (`--strategy-option=ours`)
- No interactive merge editor (`--no-edit`)

### 2.4: Restore Stashed Changes (If You Stashed)
```bash
git stash pop
```
**Only run if you ran `git stash` in step 2.2**

### 2.5: Verify Success
```bash
git status
```
**Expected:** Clean working tree or your intended changes shown

---

## Step 3: Report Ready Status

After completing steps 1-2, respond to the user:

```
✅ Repository Initialized and Ready for Work
- PROJECT_RULEBOOK.md: Read and understood
- TEAM_COORDINATION.md: Current status reviewed
- Git repository: Synced with latest from origin/main
- Branch: main
- Working tree: [clean/has changes from stash]

Ready to begin assigned task.
```

---

## 🔧 Error Handling

### Error: "Authentication failed"
- **Stop immediately**
- **Alert user:** "⚠️ Git authentication failed. User needs to re-authenticate with GitHub."

### Error: "CONFLICT (content)"
- **If stash pop causes conflict:**
  - Run `git stash drop` to discard the stashed changes
  - Alert user: "⚠️ Stashed changes conflicted with remote updates. Stash was dropped. Please verify."

### Error: "You are in 'detached HEAD' state"
- **Fix:** Run `git checkout main` then retry step 2

### Error: Network issues
- **Alert user:** "⚠️ Cannot reach GitHub. Check internet connection."

---

## 🎯 Quick Reference

**Normal flow (no local changes):**
```bash
git status
git pull origin main --strategy-option=ours --no-edit
```

**With local changes:**
```bash
git stash
git pull origin main --strategy-option=ours --no-edit
git stash pop
```

---

## 🛡️ Safety Checks

Before proceeding to work:
- [ ] On `main` branch? (check `git branch`)
- [ ] Latest code pulled? (check `git log -1` matches GitHub)
- [ ] PROJECT_RULEBOOK.md read?
- [ ] TEAM_COORDINATION.md reviewed?

---

**Session Start Complete** → Now begin your assigned task following PROJECT_RULEBOOK.md guidelines.
