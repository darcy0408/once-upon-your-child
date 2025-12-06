# Agent Task Assignments - Phase 2 Wave 3

**Status:** 📋 READY TO START
**Date:** 2025-12-05
**Supervisor:** Claude (Agent 1 - Manager)
**Current Main Commit:** `a01f8f7` (Railway fixes complete, backend deploying)

---

## ✅ Current Status - What's Done

### Phase 2 Wave 2 - COMPLETE ✅
All merged to `main` and deployed:
- ✅ **Riverpod State Management** - SavedStoriesScreen & SettingsScreen converted
- ✅ **Test Improvements** - All tests passing (37/39)
- ✅ **Error Handling** - ErrorBoundary & LoadingOverlay on all critical screens
- ✅ **Railway Deployment Fixes** - Frontend & backend both deploying successfully

### POST-THANKSGIVING Tasks Status
From `POST_THANKSGIVING_TASKS.md`:
- ✅ **Offline-First (Isar)** - DONE (Phase 2 Wave 1)
- ✅ **Celery Integration** - DONE (Phase 2 Wave 1)
- ✅ **Accessibility Fix** - DONE (Phase 2 Wave 1)
- ✅ **Error Handling** - DONE (Phase 2 Wave 2)
- ⏳ **Backend Modularization** - Partially done, needs completion
- ⏳ **Secure Storage** - NOT STARTED
- ⏳ **Crash Reporting** - NOT STARTED
- ⏳ **State Management (Riverpod Expansion)** - Partially done, needs expansion
- ⏳ **Mobile IAP** - NOT STARTED

---

## 🎯 Next: Phase 2 Wave 3 (OR Continue Post-Thanksgiving Tasks)

We have two options:

### Option A: Continue Phase 2 Wave 3 (Original Plan)
- Agent 2: Riverpod Expansion
- Agent 3: E2E Testing & Monitoring
- Agent 4: UI Polish & Animations

### Option B: Finish Post-Thanksgiving Tasks
- Backend Modularization
- Secure Storage
- Crash Reporting
- Complete Riverpod migration
- Mobile IAP (lower priority)

**RECOMMENDATION:** Let's finish the high-priority Post-Thanksgiving tasks first, then do Wave 3.

---

## 📋 AGENT ASSIGNMENTS - Post-Thanksgiving Completion

### 🔵 AGENT 2 - CODEX (WSL)

**Branch:** `feature/backend-modularization`
**Task:** Backend Modularization
**Priority:** 🔴 HIGH
**Estimated Time:** 2 days

**What to do:**
1. Read `POST_THANKSGIVING_TASKS.md` Task 1 (lines 39-169)
2. Create branch `feature/backend-modularization`
3. Extract 21 routes from `backend/app.py` to blueprints:
   - `backend/routes/story_routes.py` (7 endpoints)
   - `backend/routes/character_routes.py` (5 endpoints)
   - `backend/routes/admin_routes.py` (admin endpoints)
   - `backend/routes/health_routes.py` (health/version)
4. Reduce `app.py` from 1,128 lines to <300 lines
5. Test: `python -m pytest tests/` must pass
6. Push to `feature/backend-modularization`

**DO NOT:**
- ❌ Don't touch frontend files (`lib/**`)
- ❌ Don't merge to main yet - wait for review
- ❌ Don't work on `feature/security-hardening` (Agent 4's branch)
- ❌ Don't work on `feature/riverpod-expansion` (Agent 3's branch)

**Files to modify:**
- `backend/app.py` (reduce from 1,128 lines)
- `backend/routes/story_routes.py` (CREATE)
- `backend/routes/character_routes.py` (CREATE)
- `backend/routes/admin_routes.py` (CREATE)
- `backend/routes/health_routes.py` (CREATE)

---

### 🟢 AGENT 3 - CODEX (WSL)

**Branch:** `feature/riverpod-expansion`
**Task:** Complete Riverpod Migration
**Priority:** 🟡 MEDIUM
**Estimated Time:** 3 days

**What to do:**
1. Read `AGENT_2_RIVERPOD_EXPANSION_TASK.md` (full file)
2. Create branch `feature/riverpod-expansion`
3. Create providers:
   - `lib/providers/character_provider.dart`
   - `lib/providers/quick_story_provider.dart`
   - `lib/providers/subscription_provider.dart`
4. Convert screens to Riverpod:
   - `lib/quick_story_screen.dart`
   - `lib/character_creation_screen_enhanced.dart`
   - `lib/main_story.dart`
5. Add paywall UI when daily limit reached
6. Test: `flutter test` must pass
7. Push to `feature/riverpod-expansion`

**DO NOT:**
- ❌ Don't touch backend files (`backend/**`)
- ❌ Don't touch Agent 2's files (stay out of backend!)
- ❌ Don't touch Agent 4's files (`lib/widgets/**` animation widgets)
- ❌ Don't work on `feature/security-hardening` or `feature/backend-modularization`

**Files to modify:**
- `lib/providers/character_provider.dart` (CREATE)
- `lib/providers/quick_story_provider.dart` (CREATE)
- `lib/providers/subscription_provider.dart` (CREATE)
- `lib/quick_story_screen.dart` (MODIFY)
- `lib/character_creation_screen_enhanced.dart` (MODIFY)
- `lib/main_story.dart` (MODIFY)

---

### 🟣 AGENT 4 - GEMINI 2.5 PRO (Windows)

**Branch:** `feature/security-hardening`
**Task:** Secure Storage + Crash Reporting
**Priority:** 🔴 HIGH
**Estimated Time:** 2 days

**What to do:**

**Part 1: Secure Storage (Day 1)**
1. Read `POST_THANKSGIVING_TASKS.md` Task 2 (lines 172-284)
2. Create branch `feature/security-hardening`
3. Add `flutter_secure_storage: ^9.0.0` to `pubspec.yaml`
4. Create `lib/services/secure_storage_service.dart`
5. Migrate API keys from SharedPreferences to SecureStorage
6. Update files:
   - `lib/services/api_service_manager.dart` (lines 74-76)
   - `lib/screens/byok_setup_wizard.dart`
7. Test: `flutter test` must pass
8. Commit and push

**Part 2: Crash Reporting (Day 2)**
1. Read `POST_THANKSGIVING_TASKS.md` Task 3 (lines 287-397)
2. Add `sentry_flutter: ^7.14.0` to `pubspec.yaml`
3. Initialize Sentry in `lib/main.dart`
4. Add SentryNavigatorObserver
5. Add manual error reporting in catch blocks
6. Test crash reporting
7. Commit and push to `feature/security-hardening`

**DO NOT:**
- ❌ Don't touch backend files (`backend/**`)
- ❌ Don't touch Agent 2's backend blueprint files
- ❌ Don't touch Agent 3's provider files (`lib/providers/*_provider.dart`)
- ❌ Don't work on `feature/backend-modularization` or `feature/riverpod-expansion`

**Files to modify:**
- `pubspec.yaml` (add dependencies)
- `lib/services/secure_storage_service.dart` (CREATE)
- `lib/services/api_service_manager.dart` (migrate to secure storage)
- `lib/screens/byok_setup_wizard.dart` (migrate to secure storage)
- `lib/main.dart` (add Sentry)

---

## ⚠️ CRITICAL RULES - Prevent Branch Conflicts

### Branch Discipline
1. **ALWAYS verify you're on the correct branch** before making changes
2. **NEVER** work on another agent's branch
3. **NEVER** work on `main` directly
4. If you see another agent's task file (e.g., you're Agent 2 but see `AGENT_3_*`), **STOP and switch tasks**

### File Ownership (DO NOT VIOLATE)
```
Agent 2 (Codex WSL) OWNS:
  ✅ backend/routes/*.py (NEW FILES ONLY)
  ✅ backend/app.py (MODIFY to register blueprints)
  ❌ NO frontend files
  ❌ NO lib/** files

Agent 3 (Codex WSL) OWNS:
  ✅ lib/providers/*.dart (NEW provider files)
  ✅ lib/quick_story_screen.dart
  ✅ lib/character_creation_screen_enhanced.dart
  ✅ lib/main_story.dart
  ❌ NO backend files
  ❌ NO lib/widgets/** animation files

Agent 4 (Gemini Windows) OWNS:
  ✅ lib/services/secure_storage_service.dart (NEW)
  ✅ lib/main.dart (add Sentry only)
  ✅ lib/services/api_service_manager.dart (migrate to secure storage)
  ✅ lib/screens/byok_setup_wizard.dart (migrate to secure storage)
  ❌ NO backend files
  ❌ NO provider files (lib/providers/)
```

---

## 🔄 Git Workflow (All Agents Must Follow)

### Start of Task
```bash
# 1. Verify you're on main
git checkout main

# 2. Pull latest changes
git pull origin main

# 3. Create YOUR feature branch (use exact name from assignment above)
git checkout -b feature/<your-branch-name>

# 4. VERIFY you're on correct branch
git branch --show-current
# Must match your assigned branch!

# 5. If wrong branch, STOP and ask supervisor
```

### During Work
```bash
# Commit frequently with clear messages
git add .
git commit -m "feat: <what you did>

- Bullet point changes
- Test results
- Next steps

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to YOUR branch regularly
git push origin feature/<your-branch-name>
```

### Before Finishing
```bash
# 1. Run tests
flutter test  # Frontend agents
python -m pytest tests/  # Backend agents

# 2. Ensure tests pass
# 3. Push final changes
git push origin feature/<your-branch-name>

# 4. Update TEAM_COORDINATION.md with completion status
# 5. Report to supervisor (Claude)
```

---

## ✅ Definition of Done

Each agent's task is complete when:

1. ✅ All assigned files created/modified
2. ✅ Tests pass (`flutter test` or `pytest`)
3. ✅ Code committed with proper message format
4. ✅ Pushed to correct feature branch
5. ✅ TEAM_COORDINATION.md updated
6. ✅ Reported completion to supervisor

---

## 🚨 What NOT to Do

### ❌ DON'T:
1. Work on `main` branch directly
2. Merge your own branch to main
3. Touch files outside your scope
4. Work on another agent's branch
5. Skip tests
6. Push directly to main
7. Force push (`git push --force`)
8. Commit .env files or secrets
9. Make changes without committing frequently

### ✅ DO:
1. Stay on your assigned branch
2. Only modify files in your scope
3. Run tests before pushing
4. Commit frequently with clear messages
5. Ask supervisor if unsure
6. Update TEAM_COORDINATION.md
7. Report blockers immediately

---

## 📊 Progress Tracking

Each agent should update this section in TEAM_COORDINATION.md:

```markdown
## Agent Progress - [DATE]

### Agent 2 (Backend Modularization)
- Status: [In Progress / Blocked / Complete]
- Branch: feature/backend-modularization
- Files Modified: [List files]
- Tests: [Pass/Fail count]
- Blockers: [Any issues]
- Next: [Next steps]

### Agent 3 (Riverpod Expansion)
- Status: [In Progress / Blocked / Complete]
- Branch: feature/riverpod-expansion
- Files Modified: [List files]
- Tests: [Pass/Fail count]
- Blockers: [Any issues]
- Next: [Next steps]

### Agent 4 (Security Hardening)
- Status: [In Progress / Blocked / Complete]
- Branch: feature/security-hardening
- Files Modified: [List files]
- Tests: [Pass/Fail count]
- Blockers: [Any issues]
- Next: [Next steps]
```

---

## 🎯 Success Criteria - All Agents

**When all agents are done:**
1. ✅ 3 feature branches created and pushed
2. ✅ All tests passing on each branch
3. ✅ No conflicts between branches
4. ✅ Backend modularized (<300 lines in app.py)
5. ✅ Riverpod expanded to main screens
6. ✅ Secure storage implemented
7. ✅ Crash reporting (Sentry) working
8. ✅ TEAM_COORDINATION.md updated
9. ✅ Ready for supervisor (Claude) to review and merge

---

## 📝 Questions & Support

**If you have questions:**
1. Check your task file first (`POST_THANKSGIVING_TASKS.md` or `AGENT_*_TASK.md`)
2. Check this file (AGENT_TASK_ASSIGNMENTS.md)
3. Ask supervisor (Claude)

**If you're blocked:**
1. Document the blocker in TEAM_COORDINATION.md
2. Push your current work
3. Report to supervisor immediately

**If you finish early:**
1. Run all tests again
2. Review your changes
3. Update documentation
4. Report completion to supervisor
5. Wait for next assignment (don't start another task)

---

**Last Updated:** 2025-12-05
**Supervisor:** Claude (Agent 1)
**Status:** Ready to deploy agents

