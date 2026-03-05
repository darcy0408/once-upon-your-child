# Manual Browser Testing Checklist - Pick-A-Path Adventures

## Prerequisites

1. ✅ Backend server running
2. ✅ Flutter web app running (`flutter run -d chrome`)
3. ✅ Test character created (age 8, with companion)

---

## Test Suite 1: Basic Story Creation

### Test 1.1: Create New Adventure
**Steps:**
1. Navigate to Pick-A-Path Adventures
2. Select a character (age 8)
3. Choose theme: "Magic" or "Adventure"
4. Start adventure

**Expected Results:**
- ✅ Story begins loading
- ✅ First segment appears
- ✅ Loading indicator shown during generation

**Pass/Fail:** ___________

---

### Test 1.2: Verify Longer Segments
**Steps:**
1. Read the first segment completely
2. Count approximate words (or copy text to word counter)

**Expected Results:**
- ✅ Segment has approximately 350-500 words (for age 8)
- ✅ Segment is notably longer than old ~120 word segments
- ✅ Story feels more immersive

**Actual word count:** ___________

**Pass/Fail:** ___________

---

### Test 1.3: Verify Second-Person POV
**Steps:**
1. Read the story text carefully
2. Count instances of "you" vs child's name

**Expected Results:**
- ✅ Story primarily uses "you" (second-person)
- ✅ Child's name appears 0-2 times max
- ✅ No "Leo jumped" or "She ran" third-person narration

**You count:** ___________
**Name count:** ___________

**Pass/Fail:** ___________

---

## Test Suite 2: CONTINUE/CHOICE System

### Test 2.1: CONTINUE Button Appears
**Steps:**
1. Generate a new story
2. Look for "Continue" button (not choices) on some segments

**Expected Results:**
- ✅ Some segments show a single "Continue" button
- ✅ Button has arrow icon →
- ✅ Button says "Continue" (not "What do you do next?")

**Did CONTINUE appear?** ___________
**Which segment?** ___________

**Pass/Fail:** ___________

---

### Test 2.2: CONTINUE Button Works
**Steps:**
1. Click the "Continue" button
2. Observe next segment loading

**Expected Results:**
- ✅ Button disables while loading
- ✅ Next segment appears
- ✅ Story flows naturally without jarring interruption

**Pass/Fail:** ___________

---

### Test 2.3: Choice Screens Appear at Decision Points
**Steps:**
1. Continue through the story
2. Find segments with choices (not CONTINUE)

**Expected Results:**
- ✅ Some segments show choices
- ✅ Prompt says "What do you do next?"
- ✅ Exactly 2-3 choices displayed (not 4+)

**Choice count:** ___________

**Pass/Fail:** ___________

---

## Test Suite 3: Choice Quality

### Test 3.1: No Filler Choices
**Steps:**
1. Read all choices carefully
2. Check for banned patterns

**Expected Results:**
- ❌ NO choices saying "Ask what to do"
- ❌ NO choices saying "Ask more questions"
- ❌ NO passive choices like "Wait and see"
- ✅ All choices are concrete actions

**Found any banned patterns?** ___________
**Example (if any):** ___________

**Pass/Fail:** ___________

---

### Test 3.2: Choices Are Distinct
**Steps:**
1. Read the available choices
2. Imagine the outcomes

**Expected Results:**
- ✅ Each choice feels different (not just different wording)
- ✅ Choices have different "flavors" (brave/clever/kind)
- ✅ You can predict different outcomes from each

**Pass/Fail:** ___________

---

### Test 3.3: Choices Have Consequences
**Steps:**
1. Select a choice
2. Read the next segment
3. Verify it reflects your choice

**Expected Results:**
- ✅ Next segment clearly follows from your choice
- ✅ Choice isn't ignored or feels cosmetic
- ✅ Story branches based on your decision

**Pass/Fail:** ___________

---

## Test Suite 4: Companion Integration

### Test 4.1: Companion Appears Frequently
**Steps:**
1. Read through 3-4 segments
2. Count companion mentions per segment

**Expected Results:**
- ✅ Companion mentioned 3+ times per segment
- ✅ Companion speaks (dialogue)
- ✅ Companion performs actions

**Segment 1 companion mentions:** ___________
**Segment 2 companion mentions:** ___________
**Segment 3 companion mentions:** ___________

**Pass/Fail:** ___________

---

### Test 4.2: Companion Helps
**Steps:**
1. Look for moments where companion assists

**Expected Results:**
- ✅ Companion provides helpful ideas/tools
- ✅ Companion doesn't solve everything for child
- ✅ Child still makes the final decisions

**Example of companion help:** ___________

**Pass/Fail:** ___________

---

### Test 4.3: Bond Moments Present
**Steps:**
1. Look for relationship moments with companion

**Expected Results:**
- ✅ Companion encourages the child
- ✅ Friendly interactions (high-five, joke, shared look)
- ✅ Companion feels like a friend, not just a tool

**Example bond moment:** ___________

**Pass/Fail:** ___________

---

## Test Suite 5: Inventory System

### Test 5.1: Inventory Section Visible
**Steps:**
1. Look for "Inventory" section on screen
2. Acquire an item during the story

**Expected Results:**
- ✅ Inventory section is visible (accordion or chips)
- ✅ Items appear when acquired
- ✅ Item count updates

**Pass/Fail:** ___________

---

### Test 5.2: Items Referenced in Story
**Steps:**
1. Acquire an item
2. Read the next segment

**Expected Results:**
- ✅ Story mentions the item you just got
- ✅ Item feels relevant, not random
- ✅ Hint about how item might be useful later

**Item acquired:** ___________
**Was it mentioned?** ___________

**Pass/Fail:** ___________

---

## Test Suite 6: Reading Experience

### Test 6.1: Text Readability
**Steps:**
1. Read several paragraphs
2. Evaluate readability

**Expected Results:**
- ✅ Text is broken into short paragraphs
- ✅ Line spacing is adequate
- ✅ Font size is appropriate
- ✅ No huge walls of text

**Pass/Fail:** ___________

---

### Test 6.2: Sensory Details Present
**Steps:**
1. Read segments for sensory language

**Expected Results:**
- ✅ Multiple senses mentioned (sight, sound, touch, smell)
- ✅ Details help you imagine the scene
- ✅ Writing feels immersive, not flat

**Senses found:** ___________

**Pass/Fail:** ___________

---

### Test 6.3: Pacing Feels Good
**Steps:**
1. Complete an entire adventure
2. Reflect on pacing

**Expected Results:**
- ✅ Story doesn't feel like constant quizzing
- ✅ Good balance of reading vs. choosing
- ✅ Choices appear at natural decision points

**Pass/Fail:** ___________

---

## Test Suite 7: Completion & Error Handling

### Test 7.1: Story Completes Successfully
**Steps:**
1. Complete an adventure to the end

**Expected Results:**
- ✅ "Adventure Complete!" message appears
- ✅ Save to Library button works
- ✅ No errors or crashes

**Pass/Fail:** ___________

---

### Test 7.2: Save Story Works
**Steps:**
1. Complete story
2. Click "Save to Library"
3. Navigate to saved stories

**Expected Results:**
- ✅ Story saves without error
- ✅ Toast/confirmation shown
- ✅ Story appears in library

**Pass/Fail:** ___________

---

### Test 7.3: Error Handling (Network)
**Steps:**
1. Start a story
2. Disconnect network mid-story
3. Try to make a choice

**Expected Results:**
- ✅ Clear error message shown
- ✅ Retry button available
- ✅ Can recover after reconnecting

**Pass/Fail:** ___________

---

## Test Suite 8: Visual Presentation

### Test 8.1: Choice Buttons Look Good
**Steps:**
1. Look at choice buttons on screen

**Expected Results:**
- ✅ Buttons are visually distinct from Continue button
- ✅ Adequate spacing between choices
- ✅ Buttons are tappable/clickable

**Pass/Fail:** ___________

---

### Test 8.2: Continue Button Stands Out
**Steps:**
1. When Continue appears, evaluate design

**Expected Results:**
- ✅ Continue button is clear and obvious
- ✅ Has arrow icon or visual indicator
- ✅ Different from choice buttons

**Pass/Fail:** ___________

---

### Test 8.3: Loading States Clear
**Steps:**
1. Observe loading states during generation

**Expected Results:**
- ✅ Loading indicator shows while generating
- ✅ User knows something is happening
- ✅ No hanging/unclear states

**Pass/Fail:** ___________

---

## Test Suite 9: Edge Cases

### Test 9.1: Very Young Character (Age 5)
**Steps:**
1. Create story with age 5 character

**Expected Results:**
- ✅ Simpler vocabulary used
- ✅ Word count adjusted (~250-350)
- ✅ Stakes are gentler

**Pass/Fail:** ___________

---

### Test 9.2: Older Character (Age 12)
**Steps:**
1. Create story with age 12 character

**Expected Results:**
- ✅ More complex vocabulary
- ✅ Word count higher (~450-650)
- ✅ Stakes are more engaging

**Pass/Fail:** ___________

---

### Test 9.3: Story Without Companion
**Steps:**
1. Create story with character that has no companion

**Expected Results:**
- ✅ Story works without companion
- ✅ No companion beats in UI
- ✅ No errors

**Pass/Fail:** ___________

---

## Test Suite 10: Performance

### Test 10.1: Segment Generation Time
**Steps:**
1. Time how long segments take to generate
2. Test several segments

**Expected Results:**
- ✅ First segment: < 30 seconds
- ✅ Continuation segments: < 20 seconds
- ✅ No excessive delays

**Avg generation time:** ___________

**Pass/Fail:** ___________

---

### Test 10.2: UI Responsiveness
**Steps:**
1. Interact with UI during story

**Expected Results:**
- ✅ Buttons respond immediately
- ✅ Scrolling is smooth
- ✅ No lag or freezing

**Pass/Fail:** ___________

---

### Test 10.3: Memory Usage
**Steps:**
1. Complete 2-3 full adventures
2. Check browser memory (DevTools)

**Expected Results:**
- ✅ No significant memory leaks
- ✅ App remains responsive
- ✅ No crashes after extended use

**Pass/Fail:** ___________

---

## Summary

**Total Tests:** 30
**Passed:** ___________
**Failed:** ___________
**Skipped:** ___________

**Critical Issues Found:**

1. ___________________________________________
2. ___________________________________________
3. ___________________________________________

**Overall Assessment:** ___________

**Tested By:** ___________
**Date:** ___________
**Browser:** ___________
**OS:** ___________
