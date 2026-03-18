# Pick-A-Path Adventures - Comprehensive Testing Plan

**Feature:** Pick-A-Path Adventures interactive storytelling system
**Status:** 95% Complete - Ready for Testing
**Created:** 2025-12-25

---

## Testing Strategy Overview

This plan is divided into two categories:
1. **Backend/API Tests** - No browser required (Agent 1)
2. **Frontend/UI Tests** - Browser required (Agent 2)

---

# Part 1: Backend/API Tests (No Browser Required)

**Agent Instructions:** Execute these tests using command line tools (curl, Python, pytest). No browser needed.

## Prerequisites

### 1. Start Backend Server
```bash
cd backend
python app.py
```

**Verify server is running:**
```bash
curl http://localhost:5000/health
# Expected: {"status": "healthy"}
```

---

## Test Suite A: Database Schema Validation

### A1. Verify All Tables Exist
```bash
# Windows
python -c "from backend.app import create_app; from backend.database import db; app = create_app('development'); app.app_context().push(); print('Tables:', db.engine.table_names())"

# Expected output should include:
# - interactive_story
# - story_segment
# - story_choice
# - inventory_item
# - story_state
```

**Pass Criteria:** All 5 tables exist in database

### A2. Verify Table Relationships
```bash
python -c "from backend.models.interactive_story import InteractiveStory, StorySegment, StoryChoice; print('Relationships OK')"
```

**Pass Criteria:** No import errors

---

## Test Suite B: API Endpoint Tests

### B1. Test `/generate-interactive-story` - Create New Story

**Test Case:** Generate short story for 8-year-old

```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_001",
    "character_id": "test_char_001",
    "theme": "Magic",
    "tone": "whimsical",
    "length": "short",
    "age": 8
  }' \
  -w "\n\nStatus Code: %{http_code}\nTime: %{time_total}s\n"
```

**Expected Response:**
```json
{
  "story_id": "uuid-string",
  "title": "Story Title",
  "segment": {
    "id": "segment-uuid",
    "segment_number": 1,
    "content": "Story text (100-150 words for age 8)",
    "image_description": "Scene description",
    "image_url": "base64-image-data",
    "choices": [
      {"id": "choice_1", "choice_number": 1, "text": "First choice"},
      {"id": "choice_2", "choice_number": 2, "text": "Second choice"}
    ]
  },
  "inventory": [],
  "state": {
    "current_location": "Starting location",
    "current_goal": "Main goal",
    "key_clues": [],
    "companion_status": "Companion description",
    "time_pressure": null
  },
  "is_completed": false
}
```

**Pass Criteria:**
- ✅ Status code: 200
- ✅ Response time: < 30 seconds
- ✅ `story_id` is present
- ✅ `segment.choices` has exactly 2 items (short = 2 choices)
- ✅ `segment.content` word count between 100-150 words
- ✅ `is_completed` is false

**SAVE THE STORY_ID AND CHOICE_1 ID FOR NEXT TESTS**

---

### B2. Test Age Calibration - Age 5

```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_002",
    "character_id": "test_char_002",
    "theme": "Adventure",
    "tone": "whimsical",
    "length": "short",
    "age": 5
  }'
```

**Pass Criteria:**
- ✅ `segment.content` word count between 50-80 words (age 3-5 band)
- ✅ Simple vocabulary (no complex words)
- ✅ Very short sentences

---

### B3. Test Age Calibration - Age 14

```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_003",
    "character_id": "test_char_003",
    "theme": "Mystery",
    "tone": "mystery",
    "length": "short",
    "age": 14
  }'
```

**Pass Criteria:**
- ✅ `segment.content` word count between 200-280 words (age 13-16 band)
- ✅ More complex vocabulary
- ✅ Longer, varied sentences

---

### B4. Test Choice Counts by Length

**Short Story (2 choices):**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "short", "age": 8}'
```
**Pass:** `choices` array has 2 items

**Medium Story (3 choices):**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "medium", "age": 8}'
```
**Pass:** `choices` array has 3 items

**Long Story (4 choices):**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "long", "age": 8}'
```
**Pass:** `choices` array has 4 items

---

### B5. Test `/continue-interactive-story` - Progress Story

**Using story_id from B1:**

```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "STORY_ID_FROM_B1",
    "choice_id": "CHOICE_1_ID_FROM_B1"
  }'
```

**Expected Response:**
```json
{
  "story_id": "same-uuid",
  "segment": {
    "id": "new-segment-uuid",
    "segment_number": 2,
    "content": "Next part of story",
    "image_description": "New scene",
    "image_url": "base64-image-data",
    "choices": [...]
  },
  "inventory": ["item1"],  // May have items now
  "state": {
    "current_location": "New location",
    "current_goal": "Same or updated goal",
    "key_clues": ["clue1"],
    "companion_status": "Updated status",
    "time_pressure": null
  },
  "is_completed": false  // or true if at target segment
}
```

**Pass Criteria:**
- ✅ Status code: 200
- ✅ `segment.segment_number` incremented to 2
- ✅ `state.current_location` changed from segment 1
- ✅ Response time: < 30 seconds

---

### B6. Test Story Completion (Short Story = 3 segments max)

**Continue story until completion:**

```bash
# Segment 2 → 3 (should complete for short story)
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "STORY_ID_FROM_B1",
    "choice_id": "CHOICE_ID_FROM_SEGMENT_2"
  }'
```

**Pass Criteria:**
- ✅ `segment.segment_number` is 3 (at target for short)
- ✅ `is_completed` is true
- ✅ `segment.choices` is empty array (no more choices)

---

### B7. Test `/interactive-story/<story_id>` - Get Full Story

```bash
curl http://localhost:5000/interactive-story/STORY_ID_FROM_B1
```

**Expected Response:**
```json
{
  "id": "story-uuid",
  "title": "Story Title",
  "theme": "Magic",
  "tone": "whimsical",
  "length": "short",
  "age": 8,
  "is_completed": true,
  "segments": [
    {"segment_number": 1, "content": "...", "choices": [...]},
    {"segment_number": 2, "content": "...", "choices": [...]},
    {"segment_number": 3, "content": "...", "choices": []}
  ],
  "inventory": [...],
  "state": {...}
}
```

**Pass Criteria:**
- ✅ Status code: 200
- ✅ All 3 segments present
- ✅ Segments in order (1, 2, 3)

---

### B8. Test `/interactive-story/<story_id>/resume` - Resume Story

**Create a new story and stop at segment 1:**
```bash
# Create story
NEW_STORY_ID=$(curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Dragons", "tone": "whimsical", "length": "medium", "age": 10}' \
  | jq -r '.story_id')

# Resume it
curl http://localhost:5000/interactive-story/$NEW_STORY_ID/resume
```

**Pass Criteria:**
- ✅ Returns current segment (segment 1)
- ✅ Returns current inventory
- ✅ Returns current state

---

## Test Suite C: Error Handling

### C1. Test Invalid Story ID

```bash
curl http://localhost:5000/interactive-story/invalid-uuid-999
```

**Pass Criteria:**
- ✅ Status code: 404
- ✅ Error message: "Story not found"

---

### C2. Test Missing Required Fields

```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test"
  }'
```

**Pass Criteria:**
- ✅ Status code: 400
- ✅ Error message indicates missing fields

---

### C3. Test Invalid Choice ID

```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "STORY_ID_FROM_B1",
    "choice_id": "invalid-choice-999"
  }'
```

**Pass Criteria:**
- ✅ Status code: 400 or 404
- ✅ Error message about invalid choice

---

## Test Suite D: Database Persistence

### D1. Verify Story Saved to Database

```bash
python -c "
from backend.app import create_app
from backend.database import db
from backend.models.interactive_story import InteractiveStory

app = create_app('development')
with app.app_context():
    stories = InteractiveStory.query.all()
    print(f'Total stories: {len(stories)}')
    for story in stories:
        print(f'- {story.title} (Segments: {len(story.segments)})')
"
```

**Pass Criteria:**
- ✅ At least 4 stories exist (from tests above)
- ✅ Each story has segments

---

### D2. Verify Inventory Persistence

```bash
python -c "
from backend.app import create_app
from backend.database import db
from backend.models.interactive_story import InteractiveStory, InventoryItem

app = create_app('development')
with app.app_context():
    # Find a story with inventory
    stories = InteractiveStory.query.all()
    for story in stories:
        if story.inventory:
            print(f'Story: {story.title}')
            for item in story.inventory:
                print(f'  - {item.name} (acquired at segment {item.acquired_at_segment})')
"
```

**Pass Criteria:**
- ✅ Some stories have inventory items
- ✅ Items have `acquired_at_segment` values

---

### D3. Verify State Tracking

```bash
python -c "
from backend.app import create_app
from backend.database import db
from backend.models.interactive_story import InteractiveStory

app = create_app('development')
with app.app_context():
    story = InteractiveStory.query.first()
    if story.state:
        print(f'Location: {story.state.current_location}')
        print(f'Goal: {story.state.current_goal}')
        print(f'Clues: {story.state.key_clues}')
        print(f'Companion: {story.state.companion_status}')
"
```

**Pass Criteria:**
- ✅ State exists for stories
- ✅ All state fields populated

---

## Test Suite E: Performance & Load

### E1. Concurrent Story Generation

```bash
# Create a script to test concurrent requests
cat > test_concurrent.sh << 'EOF'
#!/bin/bash
for i in {1..5}; do
  curl -X POST http://localhost:5000/generate-interactive-story \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"concurrent_test_$i\", \"character_id\": \"test\", \"theme\": \"Magic\", \"tone\": \"whimsical\", \"length\": \"short\", \"age\": 8}" &
done
wait
EOF

chmod +x test_concurrent.sh
./test_concurrent.sh
```

**Pass Criteria:**
- ✅ All 5 requests succeed
- ✅ No timeout errors
- ✅ Each gets unique story_id

---

### E2. Response Time Benchmarks

```bash
# Test 10 story generations and measure times
for i in {1..10}; do
  curl -X POST http://localhost:5000/generate-interactive-story \
    -H "Content-Type: application/json" \
    -d '{"user_id": "perf_test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "short", "age": 8}' \
    -w "Request $i Time: %{time_total}s\n" \
    -o /dev/null -s
done
```

**Pass Criteria:**
- ✅ Average time: < 20 seconds
- ✅ No timeouts
- ✅ No server errors (500)

---

## Backend Test Summary Template

**After running all tests, create this summary:**

```
=== PICK-A-PATH BACKEND TEST RESULTS ===
Date: [DATE]
Tester: [AGENT NAME]

Test Suite A: Database Schema
- A1. Tables Exist: [PASS/FAIL]
- A2. Relationships: [PASS/FAIL]

Test Suite B: API Endpoints
- B1. Generate Story: [PASS/FAIL]
- B2. Age 5 Calibration: [PASS/FAIL]
- B3. Age 14 Calibration: [PASS/FAIL]
- B4. Choice Counts: [PASS/FAIL]
- B5. Continue Story: [PASS/FAIL]
- B6. Story Completion: [PASS/FAIL]
- B7. Get Full Story: [PASS/FAIL]
- B8. Resume Story: [PASS/FAIL]

Test Suite C: Error Handling
- C1. Invalid Story ID: [PASS/FAIL]
- C2. Missing Fields: [PASS/FAIL]
- C3. Invalid Choice: [PASS/FAIL]

Test Suite D: Database Persistence
- D1. Stories Saved: [PASS/FAIL]
- D2. Inventory Saved: [PASS/FAIL]
- D3. State Saved: [PASS/FAIL]

Test Suite E: Performance
- E1. Concurrent Load: [PASS/FAIL]
- E2. Response Times: [PASS/FAIL]

TOTAL: [X/15] PASSED

Critical Issues: [LIST ANY FAILURES]
Warnings: [LIST ANY CONCERNS]
```

---

# Part 2: Frontend/UI Tests (Browser Required)

**Agent Instructions:** Execute these tests in a browser using the Flutter web app or mobile app. Visual confirmation required.

## Prerequisites

### 1. Start Frontend
```bash
flutter run -d chrome
# Or for mobile: flutter run -d [device]
```

**Verify app loads:**
- ✅ App opens without errors
- ✅ Main screen visible

---

## Test Suite F: Wizard Integration

### F1. Access Wizard Story Creator

**Steps:**
1. Open app
2. Navigate to story creation
3. Find "Wizard Story Screen" or similar button
4. Click to open wizard

**Pass Criteria:**
- ✅ Wizard opens with moon phase progress indicator
- ✅ Shows "Step 1 of 4" or similar
- ✅ No console errors

---

### F2. Complete Hero Creator (Step 1)

**Steps:**
1. Select an archetype (e.g., "Brave Adventurer")
2. Enter character name: "TestHero"
3. Set age: 8
4. Click "Next" or arrow button

**Pass Criteria:**
- ✅ Character preview appears
- ✅ Name and age display correctly
- ✅ Can proceed to Step 2

---

### F3. Select Feelings (Step 2)

**Steps:**
1. Select a scenario (e.g., "Lost Toy")
2. Select 2-3 emotion chips
3. Click "Next"

**Pass Criteria:**
- ✅ Selected emotions highlight
- ✅ Can proceed to Step 3

---

### F4. Choose Companion (Step 3)

**Steps:**
1. Select a companion or skip
2. Click "Next"

**Pass Criteria:**
- ✅ Companion selection works
- ✅ Can proceed to Step 4

---

### F5. Enable Interactive Mode (Step 4)

**Steps:**
1. In Magic Review step, look for "Interactive Mode" toggle
2. Toggle it ON
3. Verify summary shows selections
4. Click "Make Magic" button

**Pass Criteria:**
- ✅ Toggle exists and works
- ✅ Summary shows all selections
- ✅ "Make Magic" button enabled

**CRITICAL:** After clicking "Make Magic", app should navigate to **PickAPathAdventureScreen**

---

## Test Suite G: Pick-A-Path Adventure Screen

### G1. Story Loading

**Immediately after clicking "Make Magic":**

**Pass Criteria:**
- ✅ Shows loading indicator
- ✅ Shows text: "Weaving your adventure..." or similar
- ✅ No immediate errors

**Wait 10-30 seconds for story generation...**

---

### G2. Initial Segment Display

**After story loads:**

**Visual Elements to Verify:**
- ✅ App bar shows title: "Pick-A-Path Adventure" (or story title)
- ✅ Progress indicator shows: "Segment 1 of [X]"
- ✅ Story content displays (paragraph of text)
- ✅ Illustration appears (or placeholder if error)
- ✅ 2-4 choice buttons appear at bottom
- ✅ Choice buttons have descriptive text

**Pass Criteria:**
- ✅ All elements visible
- ✅ Text is readable (age-appropriate)
- ✅ Layout looks correct (no overflow)

---

### G3. Inventory Section (Initially Empty)

**Steps:**
1. Look for "Inventory" section
2. Click to expand if collapsed

**Pass Criteria:**
- ✅ Inventory section exists
- ✅ Shows "(0)" or empty state initially
- ✅ Expand/collapse works

---

### G4. Adventure Status Section

**Steps:**
1. Look for "Adventure Status" or "Story State" section
2. Click to expand if collapsed

**Visual Elements:**
- ✅ Location: [Starting location]
- ✅ Goal: [Main objective]
- ✅ Clues: [Empty initially]
- ✅ Companion: [Companion description if present]

**Pass Criteria:**
- ✅ Section visible and expandable
- ✅ All fields populated
- ✅ Text makes sense

---

### G5. Make First Choice

**Steps:**
1. Read the two choice options
2. Click the first choice button
3. Observe loading state

**Pass Criteria:**
- ✅ Button shows loading indicator
- ✅ Other buttons disabled during load
- ✅ No errors in console

**Wait for next segment (10-30 seconds)...**

---

### G6. Second Segment Display

**After choice loads:**

**Verify Changes:**
- ✅ Progress shows: "Segment 2 of [X]"
- ✅ New story text appears (different from segment 1)
- ✅ New illustration appears
- ✅ New choice buttons (2-4 options)
- ✅ Story flows logically from choice made

**Pass Criteria:**
- ✅ Segment incremented
- ✅ Content changed
- ✅ No duplication of previous segment

---

### G7. Inventory Updates

**After segment 2:**

**Steps:**
1. Expand inventory section
2. Check if any items added

**Pass Criteria:**
- ✅ If items added, they display with icon
- ✅ Count updates: "Inventory (1)" or similar
- ✅ Items are story-relevant

*Note: Inventory may still be empty - that's OK*

---

### G8. Adventure Status Updates

**After segment 2:**

**Steps:**
1. Expand Adventure Status
2. Compare to segment 1

**Verify Updates:**
- ✅ Location changed (or stayed same if logical)
- ✅ Goal updated or same
- ✅ Clues list may have items
- ✅ Companion status updated

**Pass Criteria:**
- ✅ At least ONE field changed from segment 1

---

### G9. Complete Short Story (3 segments)

**Steps:**
1. Continue making choices until story ends
2. For short story: should complete at segment 3

**Final Segment Indicators:**
- ✅ Progress shows: "Segment 3 of 3" or "Adventure complete!"
- ✅ Final story text (climax/resolution)
- ✅ Illustration for final scene
- ✅ **NO choice buttons** (story ended)
- ✅ Completion celebration UI appears

---

### G10. Completion Screen

**After story ends:**

**Visual Elements:**
- ✅ Large icon (star, trophy, etc.)
- ✅ Text: "Adventure Complete!" or similar
- ✅ "Save to Library" button appears
- ✅ No choice buttons visible

**Pass Criteria:**
- ✅ Completion clearly indicated
- ✅ Save button enabled

---

### G11. Save Story to Library

**Steps:**
1. Click "Save to Library" button
2. Wait for save operation
3. Look for confirmation

**Pass Criteria:**
- ✅ Button shows loading state
- ✅ Success message appears: "✓ Saved to your library!"
- ✅ No errors
- ✅ Button disabled after save (prevents duplicate saves)

---

### G12. Navigate Away and Check Library

**Steps:**
1. Go back to main menu
2. Navigate to "Saved Stories" or "Library"
3. Look for the completed Pick-A-Path story

**Pass Criteria:**
- ✅ Story appears in library
- ✅ Shows correct title
- ✅ Shows "Interactive" or special badge
- ✅ Can tap to view full story

---

## Test Suite H: Different Configurations

### H1. Test Medium Story (4-6 segments)

**Steps:**
1. Create new wizard story
2. Set length to "Standard" or "Medium"
3. Enable Interactive Mode
4. Generate story

**Pass Criteria:**
- ✅ Shows 3 choices per segment (not 2)
- ✅ Story continues beyond segment 3
- ✅ Completes around segment 5-6
- ✅ Progress indicator updates correctly

---

### H2. Test Long Story (7-10 segments)

**Steps:**
1. Create new wizard story
2. Set length to "Epic" or "Long"
3. Enable Interactive Mode
4. Generate story

**Pass Criteria:**
- ✅ Shows 4 choices per segment
- ✅ Story continues beyond segment 6
- ✅ Completes around segment 8-10
- ✅ Inventory accumulates multiple items
- ✅ State changes multiple times

---

### H3. Test Different Age (Age 5)

**Steps:**
1. Create wizard with age 5
2. Enable Interactive Mode
3. Generate story

**Pass Criteria:**
- ✅ Very simple language (short words)
- ✅ Shorter story text (50-80 words per segment)
- ✅ Very short sentences
- ✅ Gentle themes (no scary content)

---

### H4. Test Different Age (Age 14)

**Steps:**
1. Create wizard with age 14
2. Enable Interactive Mode
3. Generate story

**Pass Criteria:**
- ✅ More complex vocabulary
- ✅ Longer story text (200-280 words per segment)
- ✅ Varied sentence lengths
- ✅ More sophisticated themes

---

## Test Suite I: Error Handling

### I1. Network Error Simulation

**Steps:**
1. Start generating a story
2. Turn off Wi-Fi/disconnect network during load
3. Observe error handling

**Pass Criteria:**
- ✅ Shows user-friendly error message
- ✅ "Retry" button appears
- ✅ Clicking retry works when network restored
- ✅ No app crash

---

### I2. Story Generation Timeout

**Steps:**
1. Generate a story
2. If it takes > 60 seconds, observe behavior

**Pass Criteria:**
- ✅ Shows helpful message: "Taking longer than usual..."
- ✅ Doesn't hang indefinitely
- ✅ Allows retry

---

### I3. Invalid Data Handling

**Steps:**
1. Complete wizard with minimal data (no feelings, no companion)
2. Enable Interactive Mode
3. Generate story

**Pass Criteria:**
- ✅ Story still generates
- ✅ Uses defaults gracefully
- ✅ No crashes

---

## Test Suite J: UI/UX Polish

### J1. Responsive Layout (Desktop)

**Steps:**
1. Resize browser window (if web)
2. Make it very wide, then narrow
3. Check all screen elements

**Pass Criteria:**
- ✅ Story text remains readable
- ✅ Buttons stay visible
- ✅ No horizontal scrolling
- ✅ No elements cut off

---

### J2. Scroll Behavior

**Steps:**
1. Generate story with long text
2. Scroll through story content
3. Make a choice
4. Observe scroll position after new segment loads

**Pass Criteria:**
- ✅ Auto-scrolls to show new content
- ✅ Smooth scrolling animation
- ✅ New segment visible without manual scroll

---

### J3. Loading States

**Steps:**
1. Observe all loading indicators throughout flow

**Check:**
- ✅ Initial story load has spinner + text
- ✅ Choice selection shows loading on button
- ✅ Save to library shows loading
- ✅ Loading states don't block entire UI

---

### J4. Haptic Feedback (Mobile Only)

**Steps:**
1. On mobile device, tap choice buttons
2. Tap save button

**Pass Criteria:**
- ✅ Haptic vibration on button press
- ✅ Feels responsive

---

## Test Suite K: Data Persistence & Resume

### K1. Resume In-Progress Story

**Steps:**
1. Start a medium/long story
2. Complete 2 segments
3. **Close the app** (don't save to library)
4. Reopen app
5. Look for "In Progress" or "Resume" section

**Pass Criteria:**
- ✅ Story appears in resume list
- ✅ Shows correct segment number
- ✅ Can tap to resume
- ✅ Resumes at correct point
- ✅ Inventory preserved
- ✅ State preserved

---

### K2. Offline Mode

**Steps:**
1. Generate and save a completed story
2. Turn off network
3. Navigate to library
4. Open the saved story

**Pass Criteria:**
- ✅ Story loads from local storage
- ✅ All segments visible
- ✅ All images cached
- ✅ No "network error" messages

---

## Frontend Test Summary Template

**After running all tests, create this summary:**

```
=== PICK-A-PATH FRONTEND TEST RESULTS ===
Date: [DATE]
Tester: [AGENT NAME]
Browser/Device: [Chrome/Firefox/Mobile/etc]

Test Suite F: Wizard Integration
- F1. Access Wizard: [PASS/FAIL]
- F2. Hero Creator: [PASS/FAIL]
- F3. Feelings Selection: [PASS/FAIL]
- F4. Companion Selection: [PASS/FAIL]
- F5. Interactive Mode Toggle: [PASS/FAIL]

Test Suite G: Pick-A-Path Screen
- G1. Story Loading: [PASS/FAIL]
- G2. Initial Segment: [PASS/FAIL]
- G3. Inventory Section: [PASS/FAIL]
- G4. Adventure Status: [PASS/FAIL]
- G5. First Choice: [PASS/FAIL]
- G6. Second Segment: [PASS/FAIL]
- G7. Inventory Updates: [PASS/FAIL]
- G8. Status Updates: [PASS/FAIL]
- G9. Story Completion: [PASS/FAIL]
- G10. Completion Screen: [PASS/FAIL]
- G11. Save to Library: [PASS/FAIL]
- G12. Library Display: [PASS/FAIL]

Test Suite H: Configurations
- H1. Medium Story: [PASS/FAIL]
- H2. Long Story: [PASS/FAIL]
- H3. Age 5 Content: [PASS/FAIL]
- H4. Age 14 Content: [PASS/FAIL]

Test Suite I: Error Handling
- I1. Network Error: [PASS/FAIL]
- I2. Timeout: [PASS/FAIL]
- I3. Invalid Data: [PASS/FAIL]

Test Suite J: UI/UX
- J1. Responsive Layout: [PASS/FAIL]
- J2. Scroll Behavior: [PASS/FAIL]
- J3. Loading States: [PASS/FAIL]
- J4. Haptic Feedback: [PASS/FAIL]

Test Suite K: Persistence
- K1. Resume Story: [PASS/FAIL]
- K2. Offline Mode: [PASS/FAIL]

TOTAL: [X/29] PASSED

Critical Issues: [LIST ANY FAILURES]
Warnings: [LIST ANY CONCERNS]
Screenshots: [ATTACH KEY SCREENS]
```

---

# Quick Test Checklist (Minimum Viable)

If time is limited, run these critical tests first:

## Backend (No Browser)
1. ✅ B1 - Generate story (any age, short)
2. ✅ B4 - Verify choice counts
3. ✅ B5 - Continue story once
4. ✅ D1 - Verify database save

## Frontend (Browser)
1. ✅ F5 - Enable interactive mode in wizard
2. ✅ G2 - First segment displays correctly
3. ✅ G5 - Make a choice
4. ✅ G6 - Second segment loads
5. ✅ G11 - Save to library works

**If all 9 critical tests pass, the feature is functional! 🎉**

---

# Known Limitations & Warnings

1. **Illustration Generation**: May occasionally fail (Gemini API rate limits). Error handling should show placeholder.
2. **Response Times**: First story generation may take 20-30 seconds (Gemini warm-up).
3. **Age Calibration**: AI may not always perfectly match word count targets - variation of ±20 words is acceptable.
4. **Inventory**: Not all stories will add inventory items (depends on story flow).
5. **Browser Compatibility**: Primarily tested on Chrome. May have minor UI issues on Safari/Firefox.

---

# Success Criteria

**Minimum for "Ready to Ship":**
- ✅ 90% of backend tests pass (13/15)
- ✅ 85% of frontend tests pass (25/29)
- ✅ All critical tests pass (9/9)
- ✅ No app crashes
- ✅ No data loss

**Ideal for "Production Ready":**
- ✅ 100% backend tests pass
- ✅ 95% frontend tests pass
- ✅ All error states handled gracefully
- ✅ Performance benchmarks met

---

# Reporting

**After completing tests, create:**
1. `BACKEND_TEST_RESULTS.md` with filled-in summary
2. `FRONTEND_TEST_RESULTS.md` with filled-in summary + screenshots
3. `ISSUES.md` listing any failures with:
   - Test ID
   - Expected vs Actual behavior
   - Steps to reproduce
   - Severity (Critical/High/Medium/Low)

---

**END OF TESTING PLAN**

Good luck testing! 🚀
