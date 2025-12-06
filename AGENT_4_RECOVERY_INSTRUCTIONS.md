# Agent 4 - Recovery & Restart Instructions

**Status:** You were on the WRONG branch and touched the WRONG files. This has been fixed.

---

## ⚠️ What Went Wrong

1. You started work on `feature/riverpod-expansion` (Agent 3's branch)
2. You modified files you shouldn't have touched:
   - `lib/character_creation_screen_enhanced.dart` ❌
   - `lib/quick_story_screen.dart` ❌
   - Created `lib/providers/` directory ❌
   - These are ALL Agent 3's files!

3. Your work has been **stashed and discarded** because it was on the wrong branch

---

## ✅ What I (Claude) Fixed For You

1. ✅ Removed git lock file
2. ✅ Stashed your incorrect changes
3. ✅ Switched you back to `main` branch
4. ✅ Created a fresh `feature/security-hardening` branch for you
5. ✅ You are now on the CORRECT branch: `feature/security-hardening`

---

## 🎯 Your Clean Slate - Start Fresh

**Current Branch:** `feature/security-hardening` ✅
**Status:** Clean working tree, ready to start
**Task:** Secure Storage + Crash Reporting (HIGH PRIORITY)

---

## 📋 Step-by-Step Instructions - DO THIS EXACTLY

### Step 1: Verify Your Branch (MANDATORY)
```bash
git branch --show-current
```
**MUST OUTPUT:** `feature/security-hardening`

**If it shows anything else, STOP and ask for help!**

---

### Step 2: Verify Clean State
```bash
git status
```
**MUST OUTPUT:** `On branch feature/security-hardening` with clean working tree

---

### Step 3: Read Your Task Instructions

Read these files IN THIS ORDER:
1. `AGENT_TASK_ASSIGNMENTS.md` - Find the "Agent 4" section
2. `POST_THANKSGIVING_TASKS.md` - Read Task 2 (lines 172-284) and Task 3 (lines 287-397)

**Your Tasks:**
- **Day 1:** Secure Storage (Task 2)
- **Day 2:** Crash Reporting (Task 3)

---

### Step 4: What You ARE Allowed to Touch

**✅ YOU CAN MODIFY:**
```
pubspec.yaml (add dependencies only)
lib/services/secure_storage_service.dart (CREATE THIS)
lib/services/api_service_manager.dart (ONLY migrate to secure storage)
lib/screens/byok_setup_wizard.dart (ONLY migrate to secure storage)
lib/main.dart (ONLY add Sentry initialization)
```

**❌ YOU CANNOT TOUCH:**
```
backend/** (Agent 2's files)
lib/providers/** (Agent 3's files)
lib/quick_story_screen.dart (Agent 3's file)
lib/character_creation_screen_enhanced.dart (Agent 3's file)
lib/main_story.dart (Agent 3's file)
```

---

### Step 5: Start Task 2 - Secure Storage

**Part A: Add Dependency**
1. Open `pubspec.yaml`
2. Add under `dependencies:`:
   ```yaml
   flutter_secure_storage: ^9.0.0
   ```
3. Run: `flutter pub get`

**Part B: Create Secure Storage Service**
1. Create file: `lib/services/secure_storage_service.dart`
2. Copy code from `POST_THANKSGIVING_TASKS.md` lines 199-229
3. This is a NEW file, safe to create

**Part C: Migrate API Service Manager**
1. Open `lib/services/api_service_manager.dart`
2. Find lines 74-76 (API key storage)
3. Replace `SharedPreferences` calls with `SecureStorageService` calls
4. Follow pattern from `POST_THANKSGIVING_TASKS.md` lines 234-237

**Part D: Migrate BYOK Setup Wizard**
1. Open `lib/screens/byok_setup_wizard.dart`
2. Find API key save/load code
3. Replace `SharedPreferences` with `SecureStorageService`

**Part E: Test**
```bash
flutter test
# Must pass!
```

**Part F: Commit**
```bash
git add pubspec.yaml lib/services/secure_storage_service.dart lib/services/api_service_manager.dart lib/screens/byok_setup_wizard.dart
git commit -m "feat: Implement secure storage for API keys

- Add flutter_secure_storage package
- Create SecureStorageService wrapper
- Migrate API keys from SharedPreferences
- Update api_service_manager.dart
- Update byok_setup_wizard.dart

Fixes insecure plain-text API key storage.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/security-hardening
```

---

### Step 6: Start Task 3 - Crash Reporting (Next Day)

**Part A: Add Dependency**
1. Open `pubspec.yaml`
2. Add under `dependencies:`:
   ```yaml
   sentry_flutter: ^7.14.0
   ```
3. Run: `flutter pub get`

**Part B: Initialize Sentry in main.dart**
1. Open `lib/main.dart`
2. Add Sentry initialization (see `POST_THANKSGIVING_TASKS.md` lines 309-329)
3. ONLY modify main.dart for Sentry - don't touch anything else!

**Part C: Test & Commit**
```bash
flutter test
git add pubspec.yaml lib/main.dart
git commit -m "feat: Add Sentry crash reporting

- Add sentry_flutter package
- Initialize Sentry in main.dart
- Add navigator observer for screen tracking
- Configure environment-based reporting

All crashes and errors now reported to Sentry.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/security-hardening
```

---

## ⚠️ CRITICAL SAFETY RULES

### Before Modifying ANY File:
1. Check the file path
2. Ask: "Is this in my allowed list?"
3. If NO, STOP and ask supervisor

### If You See These Warnings, STOP:
- ❌ "You are modifying `lib/providers/`" → WRONG, that's Agent 3's!
- ❌ "You are modifying `backend/`" → WRONG, that's Agent 2's!
- ❌ "You are modifying `lib/quick_story_screen.dart`" → WRONG, Agent 3's!
- ❌ "You are modifying `lib/character_creation_screen_enhanced.dart`" → WRONG, Agent 3's!

### Your Only Safe Zones:
- ✅ `lib/services/secure_storage_service.dart` (new file)
- ✅ `lib/services/api_service_manager.dart` (only migrate storage)
- ✅ `lib/screens/byok_setup_wizard.dart` (only migrate storage)
- ✅ `lib/main.dart` (only add Sentry)
- ✅ `pubspec.yaml` (only add dependencies)

---

## 🚨 Verification Checklist

Before starting:
- [ ] `git branch --show-current` shows `feature/security-hardening`
- [ ] `git status` shows clean working tree
- [ ] You've read `POST_THANKSGIVING_TASKS.md` Task 2 & 3
- [ ] You understand what files you CAN and CANNOT touch

After each commit:
- [ ] Only modified files in your allowed list
- [ ] Tests pass (`flutter test`)
- [ ] Committed with proper message format
- [ ] Pushed to `feature/security-hardening`

---

## 📞 If You Get Stuck

**STOP and report:**
1. What branch you're on: `git branch --show-current`
2. What files you modified: `git status`
3. What error you're seeing
4. Wait for supervisor (Claude) to help

**DO NOT:**
- ❌ Switch branches on your own
- ❌ Force push
- ❌ Merge anything
- ❌ Touch files outside your scope

---

## ✅ Success Criteria

When you're done:
1. ✅ `flutter_secure_storage` added to pubspec.yaml
2. ✅ `SecureStorageService` created
3. ✅ API keys use secure storage
4. ✅ Sentry initialized
5. ✅ Tests pass
6. ✅ 2 commits pushed to `feature/security-hardening`
7. ✅ Only modified files in your allowed list
8. ✅ TEAM_COORDINATION.md updated

---

**You are now ready to start fresh on the CORRECT branch with the CORRECT task!**

**Branch:** `feature/security-hardening` ✅
**Files to touch:** Only the 5 listed in "Your Only Safe Zones"
**Files to avoid:** Everything else, especially `backend/**` and `lib/providers/**`

**Good luck! And remember: When in doubt, ask before touching a file!** 🛡️
