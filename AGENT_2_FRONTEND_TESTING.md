# Agent 2: Frontend/UI Testing Instructions

**Your Role:** Test the Pick-A-Path Adventures user interface and user experience in a browser.

**Tools You'll Use:** Web browser (Chrome recommended), Flutter app

**Time Estimate:** 45-60 minutes

---

## Your Mission

Verify that the Pick-A-Path Adventures frontend works correctly by:
1. Navigating through the wizard story creator
2. Enabling Interactive Mode and launching Pick-A-Path
3. Playing through a complete story (making choices)
4. Testing inventory and state tracking UI
5. Verifying save functionality
6. Testing different configurations (ages, lengths)
7. Testing error states and edge cases

---

## Prerequisites

### Step 1: Start the Backend Server

**In Terminal 1:**
```bash
cd C:\dev\story-weaver-app\backend
python app.py
```

**Wait for:** Server running on `http://localhost:5000`

### Step 2: Start the Frontend

**In Terminal 2:**
```bash
cd C:\dev\story-weaver-app
flutter run -d chrome
```

**Or for mobile:**
```bash
flutter run -d [your-device]
```

**Wait for:** App opens in browser/device

**If this fails, STOP and report the issue.**

---

## Your Test Plan

**Reference Document:** `PICK_A_PATH_TESTING_PLAN.md` (Part 2: Frontend/UI Tests)

You will execute **Test Suites F through K** (29 total tests).

---

## Test Execution Order

### 1. Test Suite F: Wizard Integration (5 tests)

**Goal:** Navigate through the wizard and launch Pick-A-Path mode

#### F1. Access Wizard Story Creator

**Steps:**
1. Open the app
2. Look for "Create Story" or "Wizard" button
3. Click to open wizard

**Check:**
- ✅ Wizard opens
- ✅ Shows moon phase progress indicator at top
- ✅ Shows "Step 1 of 4" or similar
- ✅ No console errors (press F12 in Chrome to see console)

**Screenshot:** Take a picture of the wizard landing screen

---

#### F2. Complete Hero Creator (Step 1)

**Steps:**
1. Select an archetype card (e.g., "Brave Adventurer")
2. Enter character name: "TestHero"
3. Set age slider to: 8
4. Click "Next" button (or right arrow)

**Check:**
- ✅ Character name displays correctly
- ✅ Age displays correctly
- ✅ Can proceed to Step 2
- ✅ Progress indicator updates

**Screenshot:** Character creation screen with filled data

---

#### F3. Select Feelings (Step 2)

**Steps:**
1. Select any scenario (e.g., "Lost Toy", "New School", etc.)
2. Select 2-3 emotion chips
3. Click "Next"

**Check:**
- ✅ Selected emotions highlight/change color
- ✅ Can proceed to Step 3
- ✅ Progress indicator updates

**Screenshot:** Feelings selection with emotions selected

---

#### F4. Choose Companion (Step 3)

**Steps:**
1. Select a companion OR click "Skip" if no companions
2. Click "Next"

**Check:**
- ✅ Companion selection works
- ✅ Can proceed to Step 4
- ✅ Progress indicator updates

**Screenshot:** Companion selection screen

---

#### F5. Enable Interactive Mode (Step 4) ⭐ CRITICAL

**Steps:**
1. In the Magic Review step, scroll down
2. Look for "Interactive Mode" toggle switch
3. Toggle it **ON** (should turn blue/green)
4. Verify summary shows all your selections
5. Click the big "Make Magic" button

**Check:**
- ✅ Toggle exists and is visible
- ✅ Toggle changes state when clicked
- ✅ Summary card shows character, feelings, companion
- ✅ "Make Magic" button is enabled (not grayed out)

**Screenshot:** Review screen with Interactive Mode toggle ON

**CRITICAL CHECKPOINT:** After clicking "Make Magic", the app should navigate to a NEW screen called "Pick-A-Path Adventure" (NOT the old story result screen).

---

### 2. Test Suite G: Pick-A-Path Adventure Screen (12 tests)

**Goal:** Verify the new interactive story experience

#### G1. Story Loading ⭐

**Immediately after clicking "Make Magic":**

**Check:**
- ✅ App navigates to new screen (not old story result)
- ✅ Shows loading spinner
- ✅ Shows text like "Weaving your adventure..." or similar
- ✅ App bar shows "Pick-A-Path Adventure" title
- ✅ No error messages
- ✅ No console errors

**Screenshot:** Loading state

**WAIT 10-30 seconds for story to generate...**

---

#### G2. Initial Segment Display ⭐

**After story loads:**

**Visual elements to check:**
- ✅ App bar title: "Pick-A-Path Adventure" or story title
- ✅ Progress indicator (top right): "Segment 1 of 3" (or similar)
- ✅ Story content paragraph (100-150 words for age 8)
- ✅ Illustration/image appears (or placeholder if error)
- ✅ 2-4 choice buttons at bottom
- ✅ Choice buttons have descriptive text (not just "Choice 1")

**Check text quality:**
- ✅ Story is age-appropriate (age 8 = simple but engaging)
- ✅ No grammar errors or broken sentences
- ✅ Story makes sense and has a clear setting

**Screenshot:** First segment fully loaded

---

#### G3. Inventory Section

**Steps:**
1. Scroll to find "Inventory" section (should be between story and choices)
2. Click the header to expand if collapsed

**Check:**
- ✅ Section exists and is visible
- ✅ Shows count: "Inventory (0)" initially
- ✅ Expand/collapse icon (arrow up/down) works
- ✅ Shows empty state or "No items yet" if empty

**Screenshot:** Inventory section expanded (empty)

---

#### G4. Adventure Status Section

**Steps:**
1. Find "Adventure Status" or "Story State" section
2. Click to expand if collapsed

**Check:**
- ✅ Section exists and is visible
- ✅ Shows "Location: [starting location]"
- ✅ Shows "Goal: [main objective]"
- ✅ Shows "Clues: []" or "No clues yet"
- ✅ Shows "Companion: [companion description]" (if you selected one)
- ✅ All text is readable and makes sense

**Screenshot:** Adventure Status expanded

---

#### G5. Make First Choice ⭐

**Steps:**
1. Read both/all choice options
2. Click the **FIRST** choice button
3. Observe what happens

**Check:**
- ✅ Button shows loading indicator (spinner or "Loading...")
- ✅ Other buttons become disabled/grayed out
- ✅ No errors appear
- ✅ Story stays on screen (doesn't disappear)

**Screenshot:** Choice button in loading state

**WAIT 10-30 seconds for next segment...**

---

#### G6. Second Segment Display ⭐

**After choice loads:**

**Check changes:**
- ✅ Progress updates: "Segment 2 of 3"
- ✅ NEW story text appears (different from segment 1)
- ✅ NEW illustration appears
- ✅ NEW choice buttons (2-4 options, different text)
- ✅ Story logically continues from your choice
- ✅ Previous segment text is NOT visible (only current segment)

**Verify continuity:**
- ✅ Story references your previous choice
- ✅ Story flows naturally
- ✅ No contradictions

**Screenshot:** Second segment loaded

---

#### G7. Inventory Updates

**Steps:**
1. Expand Inventory section (if collapsed)
2. Check if any items were added

**Check:**
- ✅ If items added: Count updates "Inventory (1)" or "(2)"
- ✅ If items added: Items display with icon (star, backpack, etc.)
- ✅ If items added: Item names are story-relevant
- ✅ If NO items: That's OK too! Just note it.

**Screenshot:** Inventory (with or without items)

---

#### G8. Adventure Status Updates

**Steps:**
1. Expand Adventure Status
2. Compare to what you saw in segment 1

**Check:**
- ✅ Location changed OR stayed same (both OK if logical)
- ✅ Goal updated OR stayed same
- ✅ Clues list may have items now
- ✅ Companion status updated (shows what companion is doing)
- ✅ **At least ONE field changed** from segment 1

**Screenshot:** Updated Adventure Status

---

#### G9. Complete Short Story ⭐

**Steps:**
1. Make another choice (the second one)
2. Wait for segment 3 to load
3. Story should END at segment 3 (short stories = 3 total)

**Final segment indicators:**
- ✅ Progress shows: "Segment 3 of 3" OR "Adventure complete!"
- ✅ Final story text (climax/resolution)
- ✅ Final illustration
- ✅ **NO choice buttons** visible (story ended)
- ✅ Completion UI appears (see next test)

**Screenshot:** Final segment without choice buttons

---

#### G10. Completion Screen ⭐

**After story ends:**

**Visual elements:**
- ✅ Large icon appears (star, trophy, sparkles, etc.)
- ✅ Text: "Adventure Complete!" or similar celebration
- ✅ "Save to Library" button visible and enabled
- ✅ Choice buttons are gone
- ✅ Overall layout looks polished

**Screenshot:** Completion screen

---

#### G11. Save Story to Library ⭐

**Steps:**
1. Click "Save to Library" button
2. Wait for save operation (1-3 seconds)
3. Look for confirmation message

**Check:**
- ✅ Button shows loading state briefly
- ✅ Success message appears: "✓ Saved to your library!" (green text)
- ✅ Button becomes disabled OR changes to "Saved" (prevents duplicate saves)
- ✅ No errors
- ✅ No console errors

**Screenshot:** After successful save (with checkmark message)

---

#### G12. Navigate to Library

**Steps:**
1. Click back button or navigate to main menu
2. Find "Saved Stories" or "My Library" section
3. Look for your completed story

**Check:**
- ✅ Story appears in library list
- ✅ Shows correct title
- ✅ Shows "Interactive" badge or indicator
- ✅ Can tap to view/read story again

**Screenshot:** Library showing saved Pick-A-Path story

---

### 3. Test Suite H: Different Configurations (4 tests)

**Goal:** Test that age and length settings work correctly

#### H1. Test Medium Story (3 choices, 5-6 segments)

**Steps:**
1. Go back to wizard
2. Create new character (age 8)
3. In Step 4 (Review), set story length to "Medium" or "Standard"
4. Enable Interactive Mode
5. Click "Make Magic"
6. Play through story

**Check:**
- ✅ Shows **3 choices** per segment (not 2)
- ✅ Story continues past segment 3
- ✅ Story completes around segment 5 or 6
- ✅ Progress indicator accurate

**Screenshot:** Medium story with 3 choice buttons

---

#### H2. Test Long Story (4 choices, 7-10 segments)

**Steps:**
1. Create new character (age 8)
2. Set length to "Long" or "Epic"
3. Enable Interactive Mode
4. Generate story
5. Play through (this takes longer!)

**Check:**
- ✅ Shows **4 choices** per segment
- ✅ Story continues past segment 6
- ✅ Story completes around segment 8-10
- ✅ Inventory accumulates multiple items
- ✅ State changes multiple times

**Screenshot:** Long story with 4 choice buttons

---

#### H3. Test Age 5 Content

**Steps:**
1. Create new character with **age 5**
2. Enable Interactive Mode
3. Generate short story

**Check:**
- ✅ Very simple vocabulary (no big words)
- ✅ Shorter text (50-80 words per segment)
- ✅ Very short sentences (3-6 words each)
- ✅ Gentle, reassuring themes
- ✅ No scary or intense content

**Screenshot:** Story segment for age 5

---

#### H4. Test Age 14 Content

**Steps:**
1. Create new character with **age 14**
2. Enable Interactive Mode
3. Generate short story

**Check:**
- ✅ More complex vocabulary
- ✅ Longer text (200-280 words per segment)
- ✅ Varied sentence lengths (10-20 words)
- ✅ More sophisticated themes and plot
- ✅ Still age-appropriate (no adult content)

**Screenshot:** Story segment for age 14

---

### 4. Test Suite I: Error Handling (3 tests)

**Goal:** Verify app handles problems gracefully

#### I1. Network Error During Generation

**Steps:**
1. Start generating a new story
2. **During the loading screen** (while "Weaving your adventure..." shows):
   - Turn off Wi-Fi OR disconnect ethernet
3. Wait for error to appear

**Check:**
- ✅ Shows user-friendly error message (not technical jargon)
- ✅ Shows "Retry" button
- ✅ App doesn't crash or freeze
- ✅ When you turn Wi-Fi back on and click Retry, it works

**Screenshot:** Error message

---

#### I2. Network Error During Choice

**Steps:**
1. Load a story successfully
2. Disconnect network
3. Try to make a choice

**Check:**
- ✅ Shows helpful error message
- ✅ Doesn't lose story progress
- ✅ Can retry when network restored

---

#### I3. Minimal Data Handling

**Steps:**
1. Create wizard with minimal selections:
   - Skip feelings (if possible)
   - Skip companion
   - Don't add custom elements
2. Enable Interactive Mode
3. Generate story

**Check:**
- ✅ Story still generates successfully
- ✅ Uses reasonable defaults
- ✅ No crashes or errors

---

### 5. Test Suite J: UI/UX Polish (4 tests)

#### J1. Responsive Layout (Desktop Browser)

**Steps (if testing in browser):**
1. Resize browser window to very wide
2. Resize to very narrow
3. Check all elements

**Check:**
- ✅ Story text remains readable at all widths
- ✅ Buttons stay visible and clickable
- ✅ No horizontal scrolling required
- ✅ No elements cut off or overlapping

---

#### J2. Scroll Behavior

**Steps:**
1. Generate a story
2. Scroll down to read all content
3. Make a choice
4. Observe what happens when next segment loads

**Check:**
- ✅ Page auto-scrolls to show new segment content
- ✅ Scrolling is smooth (not jerky)
- ✅ Don't have to manually scroll to see new content

---

#### J3. Loading States

**Check throughout all interactions:**
- ✅ Initial story load: Spinner + descriptive text
- ✅ Choice selection: Loading indicator on button
- ✅ Save to library: Loading state on button
- ✅ Loading states don't block entire screen
- ✅ Always clear what's happening

---

#### J4. Haptic Feedback (Mobile Only)

**If testing on mobile:**
1. Tap choice buttons
2. Tap save button

**Check:**
- ✅ Feel slight vibration on tap
- ✅ Feels responsive

**If testing in browser: SKIP this test**

---

### 6. Test Suite K: Persistence (2 tests)

#### K1. Resume In-Progress Story ⭐

**Steps:**
1. Start a MEDIUM or LONG story
2. Complete 2 segments (stop partway through)
3. **Close the app completely** (don't save to library)
4. Reopen the app
5. Look for "Continue" or "In Progress" section

**Check:**
- ✅ In-progress story appears in a list
- ✅ Shows correct segment number (e.g., "Continue from Segment 2")
- ✅ Can tap to resume
- ✅ Resumes at correct point
- ✅ Inventory preserved
- ✅ State preserved (same location, goal, clues)

**Screenshot:** In-progress story list + resumed story

---

#### K2. Offline Mode (Library Access)

**Steps:**
1. Make sure you have at least 1 saved story
2. Turn off Wi-Fi completely
3. Navigate to Library
4. Open a saved story

**Check:**
- ✅ Story loads from local storage (no spinner)
- ✅ All text visible
- ✅ All segments accessible
- ✅ No "network error" messages

---

## Your Deliverable

Create a file called `FRONTEND_TEST_RESULTS.md` with this template:

```markdown
# Pick-A-Path Adventures - Frontend Test Results

**Date:** [TODAY'S DATE]
**Tester:** Agent 2 (Frontend)
**Browser/Device:** [Chrome/Firefox/Safari/Mobile]
**Screen Size:** [e.g., 1920x1080]

## Test Results Summary

### Test Suite F: Wizard Integration
- F1. Access Wizard: PASS/FAIL
- F2. Hero Creator: PASS/FAIL
- F3. Feelings Selection: PASS/FAIL
- F4. Companion Selection: PASS/FAIL
- F5. Interactive Mode Toggle: PASS/FAIL

### Test Suite G: Pick-A-Path Screen
- G1. Story Loading: PASS/FAIL
- G2. Initial Segment: PASS/FAIL
- G3. Inventory Section: PASS/FAIL
- G4. Adventure Status: PASS/FAIL
- G5. First Choice: PASS/FAIL
- G6. Second Segment: PASS/FAIL
- G7. Inventory Updates: PASS/FAIL
- G8. Status Updates: PASS/FAIL
- G9. Story Completion: PASS/FAIL
- G10. Completion Screen: PASS/FAIL
- G11. Save to Library: PASS/FAIL
- G12. Library Display: PASS/FAIL

### Test Suite H: Configurations
- H1. Medium Story (3 choices): PASS/FAIL
- H2. Long Story (4 choices): PASS/FAIL
- H3. Age 5 Content: PASS/FAIL
- H4. Age 14 Content: PASS/FAIL

### Test Suite I: Error Handling
- I1. Network Error (Generation): PASS/FAIL
- I2. Network Error (Choice): PASS/FAIL
- I3. Minimal Data: PASS/FAIL

### Test Suite J: UI/UX
- J1. Responsive Layout: PASS/FAIL
- J2. Scroll Behavior: PASS/FAIL
- J3. Loading States: PASS/FAIL
- J4. Haptic Feedback: PASS/FAIL/SKIP

### Test Suite K: Persistence
- K1. Resume Story: PASS/FAIL
- K2. Offline Mode: PASS/FAIL

## Overall Results

**Total Tests Run:** [X/29]
**Passed:** [X]
**Failed:** [X]
**Skipped:** [X]
**Pass Rate:** [X%]

## Critical Issues Found

[List any FAIL results]

1. Issue: [Description]
   - Test: [Test ID]
   - Steps to reproduce: [1, 2, 3...]
   - Expected: [What should happen]
   - Actual: [What happened]
   - Screenshot: [filename]
   - Severity: Critical/High/Medium/Low

## UI/UX Observations

[Any design feedback, polish issues, or improvements]

- Example: "Choice buttons are hard to read on mobile"
- Example: "Story text is too small for age 5"

## Screenshots Attached

[List all screenshots you took]

1. wizard_step1.png - Hero Creator
2. pick_a_path_segment1.png - First segment loaded
3. completion_screen.png - Story complete
...

## Sample Story Content

[Paste an example story segment to show quality]

**Age 8 Story Sample:**
"You stand at the edge of the Enchanted Forest. The trees shimmer with golden leaves that..."

## Console Errors

[Paste any errors from browser console (F12)]

No errors found / OR:

```
Error: ...
```

## Conclusion

[Overall assessment]

Example:
"The Pick-A-Path Adventures feature works well overall. The wizard integration is smooth, stories generate successfully, and the UI is polished. Found minor issue with inventory section not expanding on first click. Recommend fixing before production."
```

---

## Success Criteria

**Minimum to Pass:**
- ✅ 25/29 tests pass (86%)
- ✅ All of Suite G passes (core Pick-A-Path screen)
- ✅ Stories generate and save successfully
- ✅ No crashes

**Ideal:**
- ✅ 27/29 tests pass (93%)
- ✅ All UI elements polished
- ✅ Fast loading times
- ✅ No visual bugs

---

## Tips for Success

1. **Take lots of screenshots** - Visual proof is valuable
2. **Read the stories** - Make sure content quality is good
3. **Try to break it** - Click fast, go back, disconnect network
4. **Test on different browsers** - If you have time, try Firefox/Safari too
5. **Note small issues** - Even if tests pass, UX issues matter
6. **Be patient** - Story generation takes 10-30 seconds (AI is working!)

---

## Common Issues & Solutions

**Interactive Mode toggle not found:**
- It's in Step 4 (Magic Review), scroll down
- Look for a switch/toggle control

**Story takes forever to load:**
- Wait up to 60 seconds first time
- Check backend server is running
- Check network connection

**Choices don't appear:**
- Make sure you enabled Interactive Mode
- Check you're not on old InteractiveStoryScreen
- Look for app bar title "Pick-A-Path Adventure"

**Can't find library:**
- Look for "Saved Stories" or "My Library" button
- Check sidebar or main menu

---

## Files You'll Reference

1. `PICK_A_PATH_TESTING_PLAN.md` - Your main guide (Part 2: Frontend)
2. `lib/pick_a_path_adventure_screen.dart` - The new screen code
3. `FRONTEND_TEST_RESULTS.md` - Your output (create this)

---

**Good luck! The UI is polished - you should have a great experience! 🎮**
