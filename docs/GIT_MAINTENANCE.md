# Git Maintenance Plan
**Version:** 2.2
**Last Updated:** June 29, 2026
**Purpose:** Comprehensive git repository maintenance and cleanup

---

## 🎯 Overview

This document provides a complete, agent-executable git maintenance plan covering:
1. Repository status analysis
2. Branch cleanup (outdated branches)
3. Dependency updates (security & feature)
4. Commit organization
5. Final verification

**Run this:** When repository needs cleanup, after major feature merges, or monthly for maintenance.

---

## 📋 Pre-Flight Checklist

Before starting, verify:
- [ ] You have write access to the repository
- [ ] You're on the `main` branch
- [ ] Working directory is clean (or changes are intentional)
- [ ] Backend dependencies can be updated (no production freeze)
- [ ] You have 30-60 minutes for full maintenance

---

## 🚀 Execution Plan

### Phase 1: Repository Status Analysis
**Duration:** 5 minutes
**Purpose:** Understand current state

```bash
# 1.1: Check current branch and status
git status
git branch -a

# 1.2: Count total branches
echo "Total branches: $(git branch -a | grep -v HEAD | wc -l)"

# 1.3: Check for uncommitted changes
git status --short

# 1.4: View recent commits
git log --oneline -n 10

# 1.5: Check branch relationships
git log --oneline --graph --all --decorate | head -n 30

# 1.6: Identify branches ahead/behind main
for branch in $(git branch -r | grep -v HEAD | grep -v main); do
  echo "$branch: $(git rev-list --left-right --count origin/main...$branch)"
done
```

**Decision Point:**
- If branches are outdated → Continue to Phase 2
- If dependencies are outdated → Continue to Phase 3
- If repository is clean → Skip to Phase 5

---

### Phase 2: Branch Analysis & Cleanup
**Duration:** 10-15 minutes
**Purpose:** Remove outdated branches

#### Step 2.1: Identify Outdated Branches
```bash
# Check all branches against main
git for-each-ref --format='%(refname:short)|%(committerdate:short)' refs/remotes/origin/ | grep -v HEAD | sort -t'|' -k2 -r
```

**Categorize branches:**
- **DELETE:** Branches >100 commits behind main, fully merged
- **REVIEW:** Branches with unique commits (ahead of main)
- **KEEP:** Active development, emergency rollback, backup branches

#### Step 2.2: Delete Outdated Feature Branches
```bash
# Template for deletion (replace with actual branch names)
git push origin --delete feature/old-feature-name
git push origin --delete fix/old-fix-name
```

**Common outdated patterns:**
- `feature/*` - Features already in main
- `fix/*` - Fixes already applied
- `merge-phase*` - Old merge branches
- `*-dev` - Old development branches
- `grok*/`, `codex/` - AI agent branches already merged

#### Step 2.3: Clean Up Local References
```bash
# Prune deleted remote branches
git fetch --prune

# Remove local tracking branches
git branch -vv | grep ': gone]' | awk '{print $1}' | xargs -r git branch -d

# Clean up worktrees
git worktree prune
```

---

### Phase 3: Dependency Updates
**Duration:** 20-30 minutes
**Purpose:** Update backend dependencies to latest secure versions

#### Step 3.1: Check Current Dependency Versions
```bash
cd backend

# View current versions
cat requirements.txt | grep -E "(werkzeug|sentry-sdk|stripe|redis|Flask-)"

# Check installed versions
pip list | grep -E "(werkzeug|sentry-sdk|stripe|redis|Flask-)"
```

#### Step 3.2: Identify Available Updates
Check for:
- **Security updates** (patch versions)
- **Minor updates** (new features, backward compatible)
- **Major updates** (may have breaking changes)

**Dependabot PRs:** Check https://github.com/[username]/story-weaver-app/pulls for automated PRs

#### Step 3.3: Update requirements.txt

**Safe updates (always apply):**
- Werkzeug (patch versions)
- sentry-sdk (minor versions)
- Flask-JWT-Extended (minor versions)
- Flask-Caching (minor versions)
- apispec (minor versions)

**Caution updates (test first):**
- stripe (major versions - test payment flow)
- redis (major versions - test caching/Celery)
- Flask-Limiter (major versions - test rate limiting)

**Update pattern:**
```txt
# Example: Update security patches
Werkzeug==3.1.4           # Was: 3.1.3 (security)
sentry-sdk[flask]==2.46.0 # Was: 2.33.2 (improvements)
```

#### Step 3.4: Install and Test
```bash
# Install updates
pip install -r requirements.txt --upgrade

# Test critical imports
python -c "import stripe; import redis; import sentry_sdk; from flask_limiter import Limiter; from flask_caching import Cache; from flask_jwt_extended import JWTManager; print('All imports successful')"

# Verify versions
pip list | grep -E "(stripe|redis|sentry|Flask-)"

# Test backend startup (optional but recommended)
python app.py &
sleep 5
curl http://127.0.0.1:5000/health || echo "Backend health check"
kill %1
```

#### Step 3.5: Review Stripe Usage (if updating stripe)
```bash
# Check stripe usage in codebase
grep -r "stripe\." backend/routes/stripe_routes.py backend/routes/webhook_handler.py

# Common stable methods:
# - stripe.checkout.Session.create()
# - stripe.Subscription.list()
# - stripe.webhook.construct_event()
```

---

### Phase 4: Commit Organization
**Duration:** 10 minutes
**Purpose:** Organize uncommitted changes into logical commits

#### Step 4.1: Review Uncommitted Changes
```bash
# Check what's modified
git status --short

# View diffs
git diff --stat
```

#### Step 4.2: Stage and Commit Logically

**Template commits:**

```bash
# Backend dependency updates
git add backend/requirements.txt
git commit -m "deps: Update backend dependencies to latest versions

- Werkzeug 3.1.3 → 3.1.4 (security)
- sentry-sdk 2.33.2 → 2.46.0 (improvements)
- stripe X.X.X → Y.Y.Y (if updated)
- redis X.X.X → Y.Y.Y (if updated)
- Flask-* minor updates

All imports tested and verified.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Documentation updates
git add *.md
git commit -m "docs: Update git maintenance and dependency documentation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Code changes (if any)
git add lib/ backend/
git commit -m "feat/fix: [describe changes]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Phase 5: Final Sync and Verification
**Duration:** 5 minutes
**Purpose:** Push changes and verify clean state

#### Step 5.1: Push All Changes
```bash
# Push to remote
git push origin main

# Verify push succeeded
git status
```

#### Step 5.2: Final Verification
```bash
# Count final branches
echo "Total branches after cleanup: $(git branch -a | grep -v HEAD | wc -l)"

# Show remaining branches
git branch -a | grep -v HEAD

# Verify working directory is clean
git status --short

# Show recent commits
git log --oneline -n 5
```

#### Step 5.3: Generate Summary Report
```bash
echo "=== Git Maintenance Complete ==="
echo "Date: $(date)"
echo "Branch count: $(git branch -a | grep -v HEAD | wc -l)"
echo "Latest commit: $(git log -1 --oneline)"
echo "Working directory: $(git status --short | wc -l) uncommitted files"
echo "Next maintenance: $(date -d '+30 days' 2>/dev/null || date -v+30d)"
```

---

## 📝 Maintenance Checklist

### Pre-Maintenance
- [x] Backup current state (emergency branch)
- [x] Review uncommitted changes
- [x] Verify branch access permissions

### During Maintenance
- [x] Analyze repository status
- [x] Identify outdated branches
- [x] Delete obsolete branches (15+ commits behind)
- [x] Update security patches (werkzeug, sentry)
- [x] Test major updates (stripe, redis)
- [x] Commit changes logically
- [x] Push to remote

### Post-Maintenance
- [x] Verify all changes pushed
- [x] Check GitHub for auto-closed dependabot PRs
- [x] Manually merge remaining GitHub Actions PRs
- [x] Schedule next maintenance (30 days)
- [x] Update maintenance log

---

## 🚨 Emergency Procedures

### If Something Breaks During Maintenance

**Immediate Rollback:**
```bash
# Revert last commit
git reset --hard HEAD~1

# Revert specific file
git checkout HEAD -- backend/requirements.txt

# Force push if needed (CAUTION)
git push origin main --force
```

**Restore from Emergency Branch:**
```bash
# If emergency-rollback exists
git checkout emergency-rollback
git checkout -b emergency-fix
# Fix issues, then merge back to main
```

**Dependency Rollback:**
```bash
cd backend
git checkout HEAD~1 -- requirements.txt
pip install -r requirements.txt --force-reinstall
```

---

## 📊 Branch Deletion Criteria

### Safe to Delete
- ✅ Branch is >50 commits behind main
- ✅ All commits are merged into main
- ✅ No unique commits (ahead: 0)
- ✅ Last commit >30 days old
- ✅ Branch name matches obsolete pattern (old-feature, merge-phase, etc.)

### Review Before Deleting
- ⚠️ Branch has unique commits (ahead >0)
- ⚠️ Recent activity (<30 days)
- ⚠️ Unknown purpose or naming
- ⚠️ Contains "backup" or "emergency" in name

### Never Delete
- ❌ `main` branch
- ❌ Active feature branches (<7 days old)
- ❌ Emergency rollback branches (keep 30 days)
- ❌ Production deployment branches

---

## 🔧 Automated Scripts

### Quick Maintenance Script
```bash
#!/bin/bash
# quick_maintenance.sh
# Run this for fast maintenance (no dependency updates)

echo "Running quick git maintenance..."

# Fetch latest
git fetch --prune

# Show status
git status

# Count branches
echo "Total branches: $(git branch -a | grep -v HEAD | wc -l)"

# Commit any uncommitted docs
if git status --short | grep -q ".md"; then
  git add *.md
  git commit -m "docs: Update documentation" || true
  git push
fi

echo "Quick maintenance complete!"
```

### Full Maintenance Script
```bash
#!/bin/bash
# full_maintenance.sh
# Complete maintenance including dependency updates

echo "Running FULL git maintenance..."
echo "This will take 30-60 minutes"
echo "Press Ctrl+C to cancel, Enter to continue..."
read

# Phase 1: Status
echo "=== Phase 1: Status Analysis ==="
git status
git fetch --prune
echo "Total branches: $(git branch -a | grep -v HEAD | wc -l)"

# Phase 2: Branch cleanup (manual step - list only)
echo "=== Phase 2: Branch Analysis ==="
echo "Branches >100 commits behind main:"
# List candidates for deletion
# (Actual deletion requires manual review)

# Phase 3: Dependencies
echo "=== Phase 3: Dependency Check ==="
cd backend
pip list | grep -E "(werkzeug|sentry|stripe|redis|Flask-)"

# Phase 4: Commit
echo "=== Phase 4: Commit Changes ==="
git status --short

# Phase 5: Push
echo "=== Phase 5: Final Sync ==="
git push

echo "Full maintenance complete!"
echo "Review BRANCH_STATUS_ANALYSIS.md for deletion candidates"
```

---

## 📅 Maintenance Schedule

### Weekly (Quick)
- Check for uncommitted changes
- Commit and push documentation updates
- Review new dependabot PRs

### Monthly (Full)
- Run full git maintenance
- Delete outdated branches
- Update dependencies
- Review emergency branches

### Quarterly
- Major dependency updates
- Architecture review
- Delete old emergency branches
- Clean up worktrees

---

## 📒 Maintenance Log

### 2026-06-29 — Fossil cleanup during active multi-session work (Claude Code)
- **Context:** run mid-flight with **5 open PRs** (#320 legal-fixes, #321/#332/#335 safety audit, #336 audit-fixes) and 6 live worktrees — NOT the clean `main`-only state of the 2026-06-26 run. Cleanup was scoped to **protect all in-flight work**; "main-only" was explicitly NOT the goal.
- **Main checkout restored:** it was sitting on the merged `fix/gemini-byok-consent-guard` (#319); switched back to `main` (ff to `origin/main`), branch deleted local + remote.
- **25 fossil branches deleted, all verified first:**
  - 12 `worktree-agent-*` — `ahead=0` vs `origin/main` (fully contained in main).
  - 13 `mt-*` / `fix-mt280-*` — each `ahead=1` squash commit but with a **MERGED PR** (#316/#317/#318/#322/#323/#324/#325/#326/#327/#328/#329/#330/#331).
  - Recovery breadcrumb (branch→SHA map) saved to session scratchpad; recover any with `git push origin <SHA>:refs/heads/<name>`.
- **Protected (untouched):** `main` + the 5 open-PR branches (`session/audit-fixes`, `legal-fixes`, `safety-authz`, `safety-egress`, `safety-p0`) and every worktree.
- **Worktree removal DEFERRED:** `sw-audit-fixes` removal (flagged by the prior session) is **blocked — #336 is still OPEN** (changes requested). After #336 merges: `git -C C:\dev\story-weaver-app worktree remove C:\dev\sw-audit-fixes`.
- **Transient churn discarded:** generated `*_plugin_registrant.*` pub-get drift in 3 worktrees; confirmed no real work stranded.
- **Dependencies (Phase 3): no-op** — zero open dependabot PRs.

### 2026-06-26 — Branch cleanup sweep (Claude Code)
- **Branches deleted: 24 fossils → repo is `main`-only.**
  - 21 remote: 18 `session/*` (ado-ux, antihero ×6, azure-pin, claude, claude-direct, close0447, compliance, openai-provider, prompt-heart, tts-coppa, u13gate), `chore/dependabot-backend-batch`, `chore/unify-parent-focus-keys`, and 3 leftover `worktree-agent-*` push-refs (PRs #309/#310/#311).
  - 3 local: `fix/mt-293-dependabot-cryptography`, `worktree-story-notes-mt254`, `docs/close-mt254-v2`.
- **Verification before deletion:** every branch's feature confirmed shipped to `origin/main` (MT-248/254/293/295/296/303, antihero saga, story-gen providers, u13 ElevenLabs gate, parent-focus-key drift guard) via `git log origin/main --grep`. All were squash-merge fossils (original commits show "ahead" by hash; content on main).
- **Recovery breadcrumb:** branch→SHA map saved to scratchpad (`deleted-branches-recovery-<sha>.txt`); recover any with `git push origin <SHA>:refs/heads/<branch-name>`.
- **Dependencies (Phase 3): no-op by design** — zero open dependabot PRs; last security fix (cryptography 48.0.1, MT-293) already on main. Bulk `pip-compile` deliberately avoided — it adds the 3.13-only `audioop-lts` shim and reds CI on the 3.11 install lane (hand-pin single packages instead).
- **Note:** an incidental `pubspec.lock` drift (transitive `pub get` bumps, `pubspec.yaml` unchanged) was reverted rather than committed — unvetted lockfile drift should not land on `main` without a deliberate `flutter pub upgrade` + build-verify + PR.

---

## 📖 Reference Documents

Related documentation:
- `BRANCH_STATUS_ANALYSIS.md` - Detailed branch analysis
- `DEPENDENCY_UPDATE_PLAN.md` - Dependency update strategy
- `DEPENDABOT_RESOLUTION.md` - Dependabot PR handling
- `EMERGENCY_BRANCH_CLEANUP_REMINDER.md` - Emergency branch guide

---

## ✅ Success Criteria

Maintenance is complete when:
- [x] Repository status is clean
- [x] Outdated branches deleted (behind >100 commits)
- [x] Security patches applied
- [x] All changes committed and pushed
- [x] Working directory clean
- [x] Branch count reduced by 50%+ (if applicable)
- [x] Dependencies up to date
- [x] Documentation updated

---

## 🎯 Quick Reference Commands

```bash
# Full status check
git status && git branch -a && git log --oneline -n 5

# Delete remote branch
git push origin --delete branch-name

# Update all dependencies
cd backend && pip install -r requirements.txt --upgrade

# Commit all docs
git add *.md && git commit -m "docs: Update documentation" && git push

# Prune deleted branches
git fetch --prune

# Count branches
git branch -a | grep -v HEAD | wc -l
```

---

**Next Maintenance Due:** $(date -d '+30 days' 2>/dev/null || echo "30 days from last run")

**Maintainer:** Claude Code Agent
**Support:** Review documentation in repo root
