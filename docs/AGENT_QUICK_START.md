# Agent Quick Start Guide
**For:** Codex and Gemini Agents
**Purpose:** Get started quickly without reading long documents

---

## 🚀 QUICK START (30 seconds)

### Step 1: Check What's Available
1. Open `TEAM_COORDINATION.md`
2. Look at "CURRENT AGENT ASSIGNMENTS" section (lines 10-30)
3. If someone is already working → don't take their task
4. If idle → proceed to Step 2

### Step 2: Pick a Task
1. Open `AGENT_TASK_DELEGATION_PLAN.md`
2. Find a **CRITICAL PRIORITY** task that's unclaimed
3. Read the instructions for that task

### Step 3: Claim the Task
1. Go back to `TEAM_COORDINATION.md`
2. Add yourself under "Active Work" section:

```markdown
### [Your Name] - Task [Number]: [Task Title]
**Status:** IN PROGRESS
**Started:** [Current Date/Time]
**Files Working On:** [List files from task instructions]
```

### Step 4: Do the Work
1. Follow the instructions in your task
2. Create/modify only the files listed
3. Write tests as you go
4. Run tests before committing

### Step 5: Mark Complete
1. Update `TEAM_COORDINATION.md` "Active Work" section:

```markdown
### [Your Name] - Task [Number]: [Task Title]
**Status:** ✅ COMPLETED
**Completed:** [Date/Time]
**Results:** [Tests passing: X/X] [Files modified: X]
```

2. Move yourself back to "Available for Assignment"

---

## 📋 RECOMMENDED FIRST TASKS

### If You're Codex:
**Start with:** Task 1 - Subscription Service Tests
- **Why:** Straightforward, well-defined, no dependencies
- **Time:** 2-3 hours
- **Impact:** 15 new tests

### If You're Gemini:
**Start with:** Task 7 - Fix Flutter Test Failures
- **Why:** Quick wins, high impact, clear errors to fix
- **Time:** 1-2 hours
- **Impact:** Get to 100% test pass rate

---

## ⚠️ IMPORTANT RULES

### DON'T:
- ❌ Work on files another agent is editing
- ❌ Skip claiming your task in TEAM_COORDINATION.md
- ❌ Commit without running tests
- ❌ Guess if instructions are unclear

### DO:
- ✅ Read TEAM_COORDINATION.md first
- ✅ Update when you start and finish
- ✅ Run tests before committing
- ✅ Ask Claude if blocked

---

## 📁 KEY FILES TO KNOW

### Coordination
- `TEAM_COORDINATION.md` - **CHECK THIS FIRST** (who's working on what)
- `AGENT_TASK_DELEGATION_PLAN.md` - All available tasks with instructions

### Status Reports
- `WEEKLY_STATUS_REPORT_2026-02-12.md` - What's been done, what's needed
- `LAUNCH_READINESS_PLAN.md` - Overall launch plan
- `TEST_STATUS_CONSOLIDATED.md` - Detailed test status

### Technical Reference
- `backend/tests/conftest.py` - Test fixtures (use these!)
- `test/helpers/test_fixtures.dart` - Frontend test data (use these!)
- `test/helpers/mocks.dart` - Mock services (use these!)

---

## 🎯 TASK PRIORITY LEVELS

### CRITICAL (Do These First)
- Task 1: Subscription Service Tests
- Task 2: Stripe Service Tests
- Task 3: Isar Service Tests
- Task 4: Authorization Tests
- Task 5: Rate Limiting Tests
- Task 7: Fix Flutter Test Failures

### HIGH (Do These Second)
- Task 6: Character Routes Tests
- Task 8: Magic Review Animations
- Task 9: Page Turn Animation

### MEDIUM/LOW (Do If Time)
- Task 10: Subscription Routes Tests
- Task 11: Stripe Routes Tests
- Task 12: Documentation

---

## 🔍 HOW TO CHECK FOR CONFLICTS

Before claiming a task, verify:

1. **File-level conflicts:**
   ```bash
   # Check git status
   git status

   # If files are modified, check who's working on them in TEAM_COORDINATION.md
   ```

2. **Agent assignments:**
   - Read "CURRENT AGENT ASSIGNMENTS" in TEAM_COORDINATION.md
   - If agent is working on same directory, pick different task

3. **Task dependencies:**
   - Each task in AGENT_TASK_DELEGATION_PLAN.md lists dependencies
   - If dependency shows "None" → safe to start
   - If dependency shows another task → wait for that task

---

## 🧪 HOW TO RUN TESTS

### Backend Tests
```bash
cd backend
python -m pytest tests/unit -v          # Unit tests
python -m pytest tests/security -v      # Security tests
python -m pytest tests/api -v           # API tests
python -m pytest                        # All tests
```

### Frontend Tests
```bash
flutter test                            # All tests
flutter test test/unit                  # Unit tests only
flutter test test/widgets               # Widget tests only
flutter test --coverage                 # With coverage
```

### Check Test Pass Rate
```bash
# Backend
cd backend && python -m pytest --tb=short | tail -5

# Frontend
flutter test 2>&1 | grep -E "(passed|failed|Some tests)"
```

---

## 💡 EXAMPLE: CLAIMING A TASK

### Before You Start
```markdown
## 🎯 CURRENT AGENT ASSIGNMENTS

**Last Updated:** 2026-02-12, 10:30 AM

### Available for Assignment
- **Codex Agent:** IDLE
- **Gemini Agent:** IDLE

### Active Work
- **Claude (Supervisor):** Creating reports
```

### After You Claim Task 1
```markdown
## 🎯 CURRENT AGENT ASSIGNMENTS

**Last Updated:** 2026-02-12, 11:00 AM

### Available for Assignment
- **Gemini Agent:** IDLE

### Active Work
- **Claude (Supervisor):** Creating reports
- **Codex Agent - Task 1:** Subscription Service Tests
  **Status:** IN PROGRESS
  **Started:** 2026-02-12, 11:00 AM
  **Files Working On:** test/unit/services/subscription_service_test.dart
  **Estimated Completion:** 2026-02-12, 1:00 PM
```

### After You Complete
```markdown
## 🎯 CURRENT AGENT ASSIGNMENTS

**Last Updated:** 2026-02-12, 1:15 PM

### Available for Assignment
- **Codex Agent:** IDLE (just completed Task 1)
- **Gemini Agent:** IDLE

### Active Work
- **Claude (Supervisor):** Creating reports

### Recently Completed
- **Codex Agent - Task 1:** Subscription Service Tests ✅
  **Status:** COMPLETED
  **Completed:** 2026-02-12, 1:15 PM
  **Results:** 15/15 tests passing, 85% coverage
  **Files Created:** test/unit/services/subscription_service_test.dart (150 lines)
  **Commits:** abc123def
```

---

## 🆘 IF YOU GET BLOCKED

### Test Failures
1. Document the error in TEAM_COORDINATION.md
2. Add to your task status:
   ```markdown
   **Blocker:** Test X failing with error Y
   **Tried:** [What you attempted]
   **Need:** [What would unblock you]
   ```
3. Move to next task or wait for Claude

### Unclear Instructions
1. Mark task as "NEEDS CLARIFICATION"
2. Document specific questions
3. Wait for Claude response
4. Work on different task meanwhile

### File Conflicts
1. Check git status
2. If merge conflict → ask Claude
3. If another agent working → pick different task

---

## ✅ SUCCESS CHECKLIST

Before marking your task complete:

- [ ] All new tests passing
- [ ] Existing tests still passing
- [ ] No new lint warnings/errors
- [ ] Code follows project patterns
- [ ] Committed with clear message
- [ ] Updated TEAM_COORDINATION.md
- [ ] Files match task instructions

---

## 🎉 READY TO START?

1. ✅ Read "CURRENT AGENT ASSIGNMENTS" in TEAM_COORDINATION.md
2. ✅ Pick a CRITICAL task from AGENT_TASK_DELEGATION_PLAN.md
3. ✅ Claim it in TEAM_COORDINATION.md
4. ✅ Follow the task instructions
5. ✅ Run tests
6. ✅ Commit
7. ✅ Mark complete
8. ✅ Pick next task

**Estimated Time to First Task Complete:** 2-3 hours

**Good luck! 🚀**

---

**Last Updated:** 2026-02-12
**Maintained By:** Claude Sonnet 4.5
