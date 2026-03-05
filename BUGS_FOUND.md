# Bugs Found During Deployment Testing
**Date:** 2025-12-28
**Tester:** AI Agent
**Environment:** Local Development (http://localhost:53900)

---

## Critical Bugs (Block Deployment) 🔴

> Critical bugs prevent core functionality or cause data loss. These MUST be fixed before deployment.

### Bug #C0: Gradle Build Failure (Java 25 Incompatibility)

**Severity:** Critical
**Test:** Build Android App
**Status:** 🟢 FIXED

**Steps to Reproduce:**
1. Run `flutter run` or build on Windows.
2. System uses Java 25 (Class version 69).

**Actual Behavior:**
`BUG! exception in phase 'semantic analysis' in source unit '_BuildScript_' Unsupported class file major version 69`

**Fix Applied:**
Updated `android/gradle.properties` to ensure `org.gradle.java.home` uses forward slashes for the JDK 21 path to properly force a supported Java version.

### Bug #C1: Age 5 Story Uses Wrong Perspective

**Severity:** Critical
**Test:** Test 3a: Five-Minute Story (Age 5)
**Status:** 🟢 FIXED

**Steps to Reproduce:**
1. Create character "Lacy", Age 5.
2. Generate 5-minute story.
3. Read story text.

**Expected Behavior:**
Story should use "You" (Second Person) perspective for Age 5.

**Actual Behavior:**
Story used "Lacy" (Third Person) perspective.

**Fix Applied:**
Updated prompt generation in `api_service_manager.dart` to explicitly enforce Second Person perspective for Age <= 5.

### Bug #C2: Database Schema Mismatch (Missing stage_label)

**Severity:** Critical
**Test:** Interactive Story Generation (Pick-A-Path)
**Status:**  FIXED

**Steps to Reproduce:**
1. Generate an interactive story (Pick-A-Path).
2. Backend attempts to save story segment.

**Expected Behavior:**
Story segment saves successfully.

**Actual Behavior:**
500 Error: `sqlite3.OperationalError: table story_segment has no column named stage_label`

**Root Cause:**
The local SQLite database schema is outdated and missing the `stage_label` column in the `story_segment` table, while the backend code expects it.

**Fix Applied:**
Ran admin utility `/admin/add-missing-columns` to update local database schema.

### Bug #C3: Database Schema Mismatch (User Table)

**Severity:** Critical
**Test:** Backend Logs Analysis
**Status:** 🔴 OPEN

**Steps to Reproduce:**
1. Generate any story.
2. Check backend logs for `sqlite3.OperationalError`.

**Actual Behavior:**
Logs show `no such column: user.stories_created_count`. This causes `ForeignKeyViolation` when saving stories.

**Fix Required:**
Delete local `story_weaver.db` file to force full schema recreation.

---

## High Priority Bugs (Should Fix Before Launch) 🟠

> High priority bugs affect user experience or core features but have workarounds.

### Bug #H1: [Bug Title Here]

**Severity:** High
**Test:** [Which test?]
**Status:** 🔴 OPEN / 🟡 IN PROGRESS / 🟢 FIXED

**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**


**Actual Behavior:**


**Screenshot/Error:**
```
[Paste error message]
```

**Impact:** [How does this affect users?]

**Workaround:** [Is there a way to work around this?]

---

## Medium Priority Bugs (Can Fix Post-Launch) 🟡

> Medium priority bugs are visual glitches or minor UX issues that don't break functionality.

### Bug #M1: [Bug Title Here]

**Severity:** Medium
**Test:** [Which test?]
**Status:** 🔴 OPEN / 🟡 IN PROGRESS / 🟢 FIXED

**Description:**


**Impact:** [Minor UX issue, visual glitch, etc.]

**Screenshot:**
```
[Attach if helpful]
```

---

## Low Priority / Enhancement Requests 🔵

> Nice-to-haves, enhancements, or polish items.

### Enhancement #E1: [Title Here]

**Type:** Enhancement / Polish / Nice-to-have
**Description:**


**Benefit:** [How would this improve the app?]

**Priority for v1.1:** Low / Medium / High

---

## Bug Summary

**Total Bugs Found:** _______
- Critical: _______
- High: _______
- Medium: _______
- Low: _______

**Deployment Decision:**
- [ ] ✅ PROCEED - No critical bugs, ready to deploy
- [ ] 🛑 BLOCKED - Critical bugs must be fixed first
- [ ] ⚠️ CONDITIONAL - Deploy with known high-priority issues documented

---

## Quick Bug Templates

### Choice Buttons Disabled (Known Bug)
**Test:** Test 3 or Test 9 (Pick-A-Path)
1. Generate Pick-A-Path adventure (age 5)
2. Complete segment 1, click a choice
3. On segment 2, try to click choice buttons
**Expected:** Buttons enabled
**Actual:** Buttons disabled

### Name Hallucination
**Character:** [Name, age]
**Story used:** [Wrong name like "Max" instead of "you"]
**Example:** "Max, you see a winding staircase..."

### Word Count Issue
**Age:** [5/8/12/16]
**Expected:** [Word range]
**Actual:** _______ words

---

**Testing Tips:**
- Include character age with every bug (behavior varies by age)
- Copy exact error messages from browser console (F12)
- Take screenshots of visual bugs
- Note if bug happens in mock mode vs real API mode