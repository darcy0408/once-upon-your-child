# 🧪 AGENT 1 TASK: Wizard Manual Testing

**Agent:** Codex or Gemini
**Branch:** `feature/gui-redesign`
**Time Estimate:** 1-2 hours
**Priority:** HIGH - Blocking deployment

---

## 🎯 YOUR MISSION

Thoroughly test the new magical wizard UI flow and document all findings. This is the final validation before production deployment.

---

## ⚠️ CRITICAL: BRANCH SETUP (DO THIS FIRST!)

**YOU MUST BE ON THE CORRECT BRANCH!**

```bash
# 1. Navigate to project directory
cd C:\dev\story-weaver-app

# 2. Check current branch
git branch --show-current

# 3. If NOT on feature/gui-redesign, checkout the branch
git checkout feature/gui-redesign

# 4. Pull latest changes
git pull origin feature/gui-redesign

# 5. Verify you're on the right branch
git branch --show-current
```

**Expected output:** `feature/gui-redesign`

**If you see anything else, STOP and ask for help.**

---

## 📋 TASK BREAKDOWN

### Task 1: Launch the App (5 minutes)

```bash
# Start the Flutter app
flutter run -d chrome
```

**Verify:**
- [ ] App launches without red errors
- [ ] No exceptions in console
- [ ] Main screen appears

---

### Task 2: Navigate to Wizard (2 minutes)

**Steps:**
1. From main screen, find the button to create a story
2. Tap/click to navigate to wizard

**Verify:**
- [ ] Wizard screen opens
- [ ] Purple/lavender gradient background shows
- [ ] Moon phase progress indicator at top (4 circles)
- [ ] Step 1 content displays

---

### Task 3: Test Step 1 - Hero Creator (10 minutes)

**Test Items:**
- [ ] Character preview shows at top with sparkle circle
- [ ] Can see 6 archetype cards in horizontal scroll
- [ ] Can scroll through all archetype cards
- [ ] Can tap an archetype card
- [ ] Tapped archetype has gold glow/border
- [ ] Character emoji in preview changes when archetype selected
- [ ] "Continue" button appears after selection
- [ ] Continue button is tappable
- [ ] Tapping "Continue" advances to Step 2
- [ ] No console errors during this step

**Document:**
- Which archetypes are available?
- Do animations feel smooth?
- Any visual glitches?

---

### Task 4: Test Step 2 - Feeling Selection (10 minutes)

**Test Items:**
- [ ] Progress indicator shows Step 2 active (second circle glowing)
- [ ] Can see scenario cards in horizontal scroll
- [ ] Can scroll through all scenario cards
- [ ] Can select a scenario (gets gold border)
- [ ] Can see emotion chips below scenarios
- [ ] Can tap emotion chips (they show selection state)
- [ ] Multiple emotion chips can be selected
- [ ] Gear icon visible in top-right for parental settings
- [ ] Tapping gear opens parental settings (if implemented)
- [ ] "Continue" button appears after scenario selection
- [ ] Tapping "Continue" advances to Step 3
- [ ] No console errors during this step

**Document:**
- How many scenarios are available?
- How many emotion chips?
- Do selections persist when navigating back?

---

### Task 5: Test Step 3 - Companion Selector (10 minutes)

**Test Items:**
- [ ] Progress indicator shows Step 3 active (third circle glowing)
- [ ] Can see 6 companion cards in grid layout (2 columns)
- [ ] All companion images/emojis display correctly
- [ ] Tapping companion triggers bounce animation
- [ ] Greeting bubble appears briefly on tap
- [ ] Selected companion has gold glow
- [ ] Selected companion shows checkmark
- [ ] Only one companion can be selected at a time
- [ ] "Continue" button appears after selection
- [ ] Tapping "Continue" advances to Step 4
- [ ] No console errors during this step

**Document:**
- Which companions are available?
- Do animations feel responsive?
- Any layout issues?

---

### Task 6: Test Step 4 - Magic Review (10 minutes)

**Test Items:**
- [ ] Progress indicator shows Step 4 active (all circles filled/glowing)
- [ ] Character preview shows at top
- [ ] Summary cards display all selections:
  - [ ] Selected archetype shows
  - [ ] Selected scenario shows
  - [ ] Selected emotions show
  - [ ] Selected companion shows
- [ ] Summary card information is accurate
- [ ] Big purple "Make Magic ✨" button displays
- [ ] Button has pulse animation
- [ ] Button is tappable
- [ ] No console errors on this screen

**Don't trigger story generation yet - we'll test that separately**

---

### Task 7: Test Navigation (10 minutes)

**Go back through the wizard:**

- [ ] From Step 4, tap back arrow → goes to Step 3
- [ ] From Step 3, tap back arrow → goes to Step 2
- [ ] From Step 2, tap back arrow → goes to Step 1
- [ ] From Step 1, tap back arrow → exits wizard (or shows confirmation)
- [ ] Progress indicator updates correctly when going back

**Test data persistence:**
- [ ] Archetype selection persists when navigating back and forward
- [ ] Scenario selection persists when navigating back and forward
- [ ] Emotion chip selections persist when navigating back and forward
- [ ] Companion selection persists when navigating back and forward

**Test edge cases:**
- [ ] Can change archetype selection and continue
- [ ] Can change scenario selection and continue
- [ ] Can deselect and reselect emotions
- [ ] Can change companion selection

---

### Task 8: Test Story Generation (15 minutes)

**IMPORTANT:** This will make an actual API call to the backend.

**Steps:**
1. Complete all 4 wizard steps with valid selections
2. Tap "Make Magic ✨" button
3. Observe what happens

**Test Items:**
- [ ] Loading indicator shows during generation
- [ ] No immediate errors or crashes
- [ ] Wait for story generation to complete (may take 5-10 seconds)
- [ ] Check console for any errors during generation
- [ ] Story result screen appears (or error message shows)

**If Story Generation Succeeds:**
- [ ] Story text displays
- [ ] Story title displays
- [ ] Story reflects archetype personality
- [ ] Story theme matches selected scenario
- [ ] Companion appears in the story
- [ ] Story is appropriate for children
- [ ] No technical errors visible to user

**If Story Generation Fails:**
- Document the error message
- Check console for stack trace
- Note which step failed (request, response, parsing, etc.)

---

### Task 9: Test Console Logs (5 minutes)

**Review browser console (F12 → Console tab):**

- [ ] No red errors visible
- [ ] No yellow warnings about missing imports
- [ ] No "Navigator" context errors
- [ ] No widget build errors
- [ ] Only expected debug prints (if any)

**Document:**
- Copy any errors or warnings you see
- Note frequency of issues (one-time vs repeated)

---

### Task 10: Test Responsiveness (5 minutes - OPTIONAL)

**If you have time:**

- [ ] Resize browser window → wizard layout adapts
- [ ] Test in portrait orientation (narrow window)
- [ ] Test in landscape orientation (wide window)
- [ ] Text remains readable at different sizes
- [ ] Buttons remain tappable at different sizes

---

## 📊 TESTING SUMMARY TEMPLATE

After completing all tests, fill out this summary:

```
═══════════════════════════════════════════════════════════
WIZARD TESTING REPORT
Date: [Current Date/Time]
Agent: [Your Name - Codex/Gemini]
Branch: feature/gui-redesign
Commit: [Run: git log -1 --oneline]
═══════════════════════════════════════════════════════════

## OVERALL STATUS
[ ] PASS - All tests passed, ready for deployment
[ ] PARTIAL - Most tests passed, minor issues found
[ ] FAIL - Critical issues found, not ready for deployment

## TEST RESULTS

### Step 1 - Hero Creator
Tests Passed: ___/10
Issues Found: [List any issues]

### Step 2 - Feeling Selection
Tests Passed: ___/12
Issues Found: [List any issues]

### Step 3 - Companion Selector
Tests Passed: ___/11
Issues Found: [List any issues]

### Step 4 - Magic Review
Tests Passed: ___/14
Issues Found: [List any issues]

### Navigation
Tests Passed: ___/10
Issues Found: [List any issues]

### Story Generation
Status: [ ] SUCCESS [ ] FAILED
Issues Found: [List any issues]

### Console Errors
Clean Console: [ ] YES [ ] NO
Errors Found: [List any errors]

## CRITICAL ISSUES (Must fix before deploy)
1.
2.
3.

## MINOR ISSUES (Can fix later)
1.
2.
3.

## OBSERVATIONS
- Performance: [Smooth / Laggy / Other]
- Animations: [Smooth / Choppy / Other]
- Visual Polish: [Excellent / Good / Needs Work]
- User Experience: [Intuitive / Confusing / Other]

## RECOMMENDATIONS
- [ ] Ready to deploy as-is
- [ ] Fix critical issues first
- [ ] Needs more work

═══════════════════════════════════════════════════════════
```

---

## 🔄 GIT SYNC (DO THIS AT THE END)

**After completing all testing:**

```bash
# 1. Check status
git status

# 2. Stage all changes (if you made any test files)
git add .

# 3. Commit your test report
git commit -m "test: Complete wizard manual testing

Test Results: [PASS/PARTIAL/FAIL]
Tests Passed: [X/67]
Critical Issues: [Number]
Minor Issues: [Number]

Agent: [Your Name]
Date: [Current Date]

See WIZARD_TESTING_REPORT.md for details"

# 4. Pull latest (in case others pushed)
git pull origin feature/gui-redesign --no-edit

# 5. Push to remote
git push origin feature/gui-redesign

# 6. Verify
git log -1 --oneline
```

---

## ❌ COMMON MISTAKES TO AVOID

1. **Wrong Branch** - Always verify you're on `feature/gui-redesign`
2. **Skipping Tests** - Don't skip items, mark them as FAILED if they don't work
3. **Not Documenting Errors** - Copy exact error messages, don't paraphrase
4. **Rushing Story Generation** - Let it complete, don't cancel early
5. **Ignoring Console** - Check console after EVERY step

---

## 🆘 IF YOU GET STUCK

**If app won't launch:**
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

**If wizard won't show:**
- Check that you're on feature/gui-redesign branch
- Check console for import errors
- Try hot reload (press 'r' in flutter terminal)

**If story generation fails:**
- Document the error
- This is a CRITICAL finding
- Include full stack trace in report

---

## ✅ DEFINITION OF DONE

You're done when:
- [ ] All 67 test items attempted
- [ ] Testing summary completed
- [ ] All issues documented
- [ ] Console logs reviewed
- [ ] Test report committed and pushed
- [ ] Git sync completed successfully

---

**IMPORTANT:** This testing is critical for production deployment. Be thorough, document everything, and don't rush!

**Good luck! 🎯**
