# Manual Testing Checklist for Story Weaver App
**Date:** 2025-12-28
**Tester:** _______________
**Test Environment:** Local (http://localhost:53900)
**Backend:** http://127.0.0.1:5000
**Mock Mode:** ENABLED (MOCK_TESTING_MODE=true)

---

## Pre-Test Verification

- [ ] Backend server running: `curl http://127.0.0.1:5000/health`
- [ ] Backend is in MOCK mode (check backend/.env file)
- [ ] Flutter app running in Chrome
- [ ] No red error screens visible on app load

---

## Test 1: Age 5 - Five-Minute Story (CRITICAL)

### Setup
1. [ ] Open app in browser
2. [ ] Click "Character Library" or create new character
3. [ ] Create character:
   - Name: "Lacy"
   - Age: 5
   - Add pet: Bird named "Twirp"

### Story Generation
4. [ ] Click "Make Magic" button
5. [ ] Go through wizard steps:
   - [ ] Select archetype: "The Storm Rider" (or any)
   - [ ] Choose scenario: "The Magic Door" (or any)
   - [ ] Select companion: "Tiny Dragon" (or any)
   - [ ] (Optional) Add custom element
6. [ ] Look for "Story Duration" or "Story Length" selector
7. [ ] Select "Quick Adventure (5 min)" or "5 minutes"
8. [ ] Click "Make Magic" to generate

### Verification Checklist
- [ ] Story generates quickly (mock mode = instant)
- [ ] **Word count: 450-700 words total** (copy to wordcounter.net)
  - Actual count: _______ words
- [ ] **Page count: 5-8 pages** (check progress indicator)
  - Actual pages: _______ pages
- [ ] Each page ends with `.`, `!`, or `?` (no mid-sentence breaks)
  - [ ] Page 1 ending: _______________
  - [ ] Page 2 ending: _______________
  - [ ] Page 3 ending: _______________
  - [ ] Page 4 ending: _______________
  - [ ] Page 5 ending: _______________
- [ ] Adventure step labels visible (e.g., "🌟 Step 1: A Magical Beginning")
- [ ] Book page icons visible in progress indicator (📖 icons)
- [ ] Story has humor (sound effects, silly moments)
  - Examples found: _______________
- [ ] Story has magical elements (talking objects, sparkles)
  - Examples found: _______________
- [ ] Story uses simple vocabulary (NO "parchment", "constellations", etc.)
  - Any complex words? _______________
- [ ] Story uses "you" throughout (NO "Max", "Sam", or invented names)
  - Any name hallucinations? _______________

### Result
- [ ] PASS - All checks passed
- [ ] FAIL - Document issues below

**Issues Found:**
```
[Write any issues here]
```

---

## Test 2: Age 5 - Ten-Minute Story

### Setup
Same character as Test 1 (Lacy, age 5)

### Story Generation
1. [ ] Create new story via wizard
2. [ ] Select "Epic Tale (10 min)" or "10 minutes"
3. [ ] Generate story

### Verification Checklist
- [ ] Story generates successfully
- [ ] **Word count: 900-1400 words total**
  - Actual count: _______ words
- [ ] **Page count: 8-12 pages**
  - Actual pages: _______ pages
- [ ] Each page ends with proper punctuation
- [ ] Adventure step labels present
- [ ] Book page icons visible
- [ ] Story quality matches 5-minute test (humor, magic, simple words, uses "you")

### Result
- [ ] PASS
- [ ] FAIL

**Issues Found:**
```
[Write any issues here]
```

---

## Test 3: Age 5 - Pick-A-Path Adventure (CRITICAL)

### Setup
1. [ ] Create new character (age 5) or use existing
2. [ ] Click "Make Magic" → Wizard
3. [ ] Look for "Interactive Mode" or "Pick-A-Path" toggle
4. [ ] Enable interactive/Pick-A-Path mode
5. [ ] Complete wizard and generate

### Segment 1 Verification
- [ ] **Segment word count: 180-280 words**
  - Actual count: _______ words
- [ ] Story feels magical (silly details, magical twists)
  - Examples: _______________
- [ ] Story has 2+ dialogue lines
  - Count: _______ dialogue lines
- [ ] Story uses simple words (NO "parchment", "depicts", "vibrant")
  - Any complex words? _______________
- [ ] Story uses "you" (NO "Max", "Sam", or invented names)
  - Any name issues? _______________
- [ ] Choice buttons appear at end of segment
- [ ] Choice buttons are clickable (not disabled)

### Segment 2 Verification (CRITICAL BUG CHECK)
6. [ ] Click a choice button
7. [ ] Segment 2 loads successfully
8. [ ] **Segment 2 choice buttons are enabled and clickable**
   - [ ] This is the critical bug - verify carefully!
9. [ ] Click another choice to verify it works

### Segment 3 Verification
10. [ ] Segment 3 loads successfully
11. [ ] Choice buttons still work

### Result
- [ ] PASS - All segments and choices work
- [ ] FAIL - Buttons disabled or other issues

**Issues Found:**
```
[Write any issues here]
```

---

## Test 4: Age 8 - Regular Story

### Setup
1. [ ] Create character age 8
2. [ ] Add any customization
3. [ ] Generate regular (non-interactive) story

### Verification Checklist
- [ ] Story generates successfully
- [ ] **Words per page: 220-350** (if paginated)
  - Sample page word count: _______ words
- [ ] Moderate vocabulary (e.g., "mysterious", "ancient" is OK)
- [ ] Fun Recipe elements (silly + magical + dialogue present)
- [ ] Sentence length: 5-12 words average
  - Sample sentences: _______________

### Result
- [ ] PASS
- [ ] FAIL

**Issues Found:**
```
[Write any issues here]
```

---

## Test 5: Age 12 - Pick-A-Path Adventure

### Setup
1. [ ] Create character age 12
2. [ ] Generate Pick-A-Path adventure
3. [ ] Complete wizard

### Verification Checklist
- [ ] **Segment word count: 280-450 words**
  - Actual count: _______ words
- [ ] Clever details and wordplay present
  - Examples: _______________
- [ ] Adventure Recipe (clever + mysterious + puzzle elements)
- [ ] Can use words like "mysterious", "ancient", "shimmering"
- [ ] Choice buttons work on all segments

### Result
- [ ] PASS
- [ ] FAIL

**Issues Found:**
```
[Write any issues here]
```

---

## Test 6: Age 16 - Regular Story

### Setup
1. [ ] Create character age 16
2. [ ] Generate regular story

### Verification Checklist
- [ ] Story generates successfully
- [ ] **Words per page: 320-500**
  - Sample page count: _______ words
- [ ] Sophisticated vocabulary present
- [ ] Depth Recipe (wit, complexity, subtext)
- [ ] Can use advanced words like "constellations", "velvet"

### Result
- [ ] PASS
- [ ] FAIL

**Issues Found:**
```
[Write any issues here]
```

---

## Test 7: Wizard Flow with Custom Element

### Test Steps
1. [ ] Create character from scratch
2. [ ] Go through all 4 wizard steps
3. [ ] Add custom story element: "I want to meet a talking tree"
4. [ ] Generate story
5. [ ] Read the story

### Verification
- [ ] Story generated successfully
- [ ] Custom element (talking tree) appears in story
- [ ] Tree actually talks (has dialogue)
- [ ] Integration feels natural

### Result
- [ ] PASS
- [ ] FAIL

**Issues Found:**
```
[Write any issues here]
```

---

## Test 8: Storybook UI Visual Elements

### Test Steps
1. [ ] Generate any story
2. [ ] Examine the UI carefully

### Visual Checklist
- [ ] Book page icons at bottom (📖 or similar icons)
  - Screenshot or describe: _______________
- [ ] Adventure step labels (not just "Page X")
  - Example label seen: _______________
- [ ] Decorative corners (gold flourishes) - may only be on some screens
  - Present? Yes / No
  - Where? _______________
- [ ] Parchment background color present
  - Color: _______________

### Result
- [ ] PASS - UI looks polished
- [ ] FAIL - Missing elements

**Issues Found:**
```
[Write any issues here]
```

---

## Test 9: Choice Button Bug Verification

### Test Steps
1. [ ] Generate Pick-A-Path adventure (any age)
2. [ ] Complete segment 1, click a choice
3. [ ] **On segment 2:** Check if choice buttons are enabled
4. [ ] Try clicking a segment 2 choice button
5. [ ] Verify segment 3 loads

### Verification
- [ ] Segment 1 buttons: Enabled and clickable
- [ ] **Segment 2 buttons: Enabled and clickable** ← Critical
- [ ] Segment 3 buttons: Enabled and clickable
- [ ] No console errors (press F12 → Console tab)

### Result
- [ ] PASS - Bug is fixed ✅
- [ ] FAIL - Bug still exists (buttons disabled on segment 2)

**Console Errors:**
```
[Paste any errors from browser console]
```

---

## Test 10: Firefox Browser

### Pre-Test
- [ ] Open Firefox
- [ ] Navigate to http://localhost:53900 (or current Flutter port)

### Smoke Test Checklist
- [ ] App loads without errors
- [ ] Can create character
- [ ] Can generate story
- [ ] Story displays correctly
- [ ] No console errors (F12 → Console)

### Result
- [ ] PASS
- [ ] FAIL
- [ ] SKIPPED - Firefox not available

**Issues Found:**
```
[Write any issues here]
```

---

## Test 11: Microsoft Edge Browser

### Pre-Test
- [ ] Open Microsoft Edge
- [ ] Navigate to http://localhost:53900

### Smoke Test Checklist
- [ ] App loads without errors
- [ ] Can create character
- [ ] Can generate story
- [ ] Story displays correctly
- [ ] No console errors (F12 → Console)

### Result
- [ ] PASS
- [ ] FAIL
- [ ] SKIPPED - Edge not available

**Issues Found:**
```
[Write any issues here]
```

---

## Test 12: Safari Browser (if available)

### Pre-Test
- [ ] Open Safari
- [ ] Navigate to http://localhost:53900

### Smoke Test Checklist
- [ ] App loads without errors
- [ ] Can create character
- [ ] Can generate story
- [ ] Story displays correctly
- [ ] No console errors (Develop → Show Error Console)

### Result
- [ ] PASS
- [ ] FAIL
- [ ] SKIPPED - Safari not available (Windows)

**Issues Found:**
```
[Write any issues here]
```

---

## Testing Summary

### Total Tests
- Total test cases: 12
- Passed: _______
- Failed: _______
- Skipped: _______

### Critical Issues Found
List any CRITICAL bugs that block deployment:
```
1.
2.
3.
```

### High Priority Issues
List any HIGH priority bugs that should be fixed before launch:
```
1.
2.
3.
```

### Medium/Low Priority Issues
List any MEDIUM or LOW priority bugs (can be deferred):
```
1.
2.
3.
```

---

## Next Steps

After completing this checklist:

1. **If critical bugs found:**
   - Report them to the AI assistant
   - Do not proceed with deployment
   - Fix bugs first, then re-test

2. **If no critical bugs:**
   - Proceed with deployment steps:
     - Step 18: Production environment setup
     - Step 19: Build production frontend
     - Step 20: Deploy to Netlify
     - Steps 21-22: Production verification
     - Step 24: Deployment report

3. **Document results:**
   - Create BUGS_FOUND.md with any issues
   - Update deployment report with test results

---

## Tools & Resources

**Word Counter:**
- https://wordcounter.net
- Copy story text and paste to count words

**Browser Dev Tools:**
- Chrome/Edge: F12 or Ctrl+Shift+I
- Firefox: F12 or Ctrl+Shift+K
- Safari: Cmd+Option+I (Mac)

**Console Errors:**
- Open Dev Tools
- Click "Console" tab
- Look for red error messages
- Copy/paste any errors into issue reports

---

## Testing Tips

1. **Take screenshots** of any bugs or UI issues
2. **Copy error messages** exactly from console
3. **Note the character details** when a bug occurs (age, name, etc.)
4. **Test in order** - Age 5 tests are highest priority
5. **Don't rush** - thorough testing now saves deployment headaches
6. **Document everything** - even small issues can be important

---

**Good luck with testing! 🚀**
