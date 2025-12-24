# Interactive Adventure Story - Browser Testing Plan

## Overview
This testing plan validates the new interactive adventure story system with age calibration, inventory tracking, and branching narratives.

## Prerequisites
- Backend server running (`python app.py` or `python -m backend.app`)
- Database migrated (tables created)
- Valid GEMINI_API_KEY in environment
- Browser with developer tools open (for inspecting responses)

## Test Environment Setup

### 1. Verify Backend is Running
```bash
# Check server is running
curl http://localhost:5000/health

# Expected: {"status": "healthy"}
```

### 2. Verify Database Tables Exist
```bash
# Run from backend directory
python -c "from backend.app import create_app; from backend.database import db; from backend.models import InteractiveStory; app = create_app('development'); app.app_context().push(); print('Tables:', db.engine.table_names())"

# Expected to see: interactive_story, story_segment, story_choice, inventory_item, story_state
```

### 3. Create Test User and Character
```bash
# Create test user (if not exists)
curl -X POST http://localhost:5000/setup-test-account

# Create test character
curl -X POST http://localhost:5000/create-character \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "name": "Emma",
    "age": 8,
    "role": "hero",
    "gender": "she/her",
    "personality_traits": ["brave", "curious", "kind"],
    "strengths": ["problem-solving", "creativity"],
    "fears": ["darkness"],
    "comfort_item": "teddy bear"
  }'

# Save the character_id from response
```

---

## Test Suite

### Test 1: Create New Interactive Story (Opening Segment)

**Endpoint:** `POST /generate-interactive-story`

**Request:**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "character_id": "REPLACE_WITH_CHARACTER_ID",
    "theme": "Magic",
    "tone": "whimsical",
    "length": "short",
    "age": 8,
    "interests": ["sparkles", "talking animals"],
    "must_include": ["a magical key"]
  }'
```

**Expected Response Structure:**
```json
{
  "story_id": "uuid",
  "title": "Emma's Magical Adventure",
  "segment": {
    "id": "uuid",
    "segment_number": 1,
    "title": null,
    "content": "150-220 words of age-appropriate story prose",
    "image_description": "Visual scene description",
    "image_url": "data:image/png;base64,..." or null,
    "choices": [
      {
        "id": "choice_1",
        "choice_number": 1,
        "text": "First choice option",
        "consequence_type": null,
        "is_selected": false
      },
      {
        "id": "choice_2",
        "choice_number": 2,
        "text": "Second choice option",
        "consequence_type": null,
        "is_selected": false
      }
    ]
  },
  "inventory": [],
  "state": {
    "current_location": "Starting location",
    "current_goal": "What Emma is trying to achieve",
    "key_clues": [],
    "companion_status": "Companion description if any",
    "time_pressure": null
  },
  "is_completed": false
}
```

**Validation Checklist:**
- [ ] Response status is 200
- [ ] `story_id` is present and valid UUID
- [ ] `title` includes character name
- [ ] `segment.segment_number` is 1
- [ ] `segment.content` is 150-220 words (age 6-8 band)
- [ ] `segment.content` uses age-appropriate vocabulary
- [ ] `segment.image_description` is present
- [ ] `segment.choices` has exactly 2 choices (short length)
- [ ] Each choice has unique `id` and distinct `text`
- [ ] `inventory` is empty array
- [ ] `state` has all required fields
- [ ] `is_completed` is false

**Age Calibration Check:**
- Sentence length: 5-10 words per sentence
- Vocabulary: Simple but vivid words
- Stakes: Clear and friendly
- No scary or violent content

**Save for Next Test:**
- `story_id`: _________________
- `choice_1_id`: _________________

---

### Test 2: Continue Story (Second Segment)

**Endpoint:** `POST /continue-interactive-story`

**Request:**
```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "REPLACE_WITH_STORY_ID",
    "choice_id": "REPLACE_WITH_CHOICE_1_ID"
  }'
```

**Expected Response Structure:**
```json
{
  "story_id": "same as before",
  "segment": {
    "id": "new uuid",
    "segment_number": 2,
    "content": "Story continuation based on choice",
    "image_description": "New scene description",
    "image_url": "data:image/png;base64,..." or null,
    "choices": [
      {"id": "choice_1", "choice_number": 1, "text": "..."},
      {"id": "choice_2", "choice_number": 2, "text": "..."}
    ]
  },
  "inventory": ["magical key"] or [],
  "state": {
    "current_location": "Updated location",
    "current_goal": "Updated or same goal",
    "key_clues": ["clue1"],
    "companion_status": "...",
    "time_pressure": null or "..."
  },
  "is_completed": false
}
```

**Validation Checklist:**
- [ ] Response status is 200
- [ ] `segment.segment_number` is 2
- [ ] Content reflects the choice made (check continuity)
- [ ] At least ONE state field changed (location, goal, clues, etc.)
- [ ] Inventory may have items
- [ ] Choices are different from segment 1
- [ ] `is_completed` is false (not at end yet)

**Continuity Check:**
- [ ] Story references previous choice
- [ ] Content flows naturally from segment 1
- [ ] Character name used consistently
- [ ] Any items mentioned in segment 1 are tracked

---

### Test 3: Get Full Story

**Endpoint:** `GET /interactive-story/<story_id>`

**Request:**
```bash
curl http://localhost:5000/interactive-story/REPLACE_WITH_STORY_ID
```

**Expected Response Structure:**
```json
{
  "id": "story_id",
  "user_id": "test_user_123",
  "character_id": "character_id",
  "title": "Emma's Magical Adventure",
  "theme": "Magic",
  "tone": "whimsical",
  "length": "short",
  "age": 8,
  "current_segment_number": 2,
  "is_completed": false,
  "created_at": "2025-12-24T...",
  "updated_at": "2025-12-24T...",
  "inventory": [...],
  "state": {...},
  "segments": [
    {
      "id": "...",
      "segment_number": 1,
      "content": "...",
      "choices": [...]
    },
    {
      "id": "...",
      "segment_number": 2,
      "content": "...",
      "choices": [...]
    }
  ]
}
```

**Validation Checklist:**
- [ ] Response status is 200
- [ ] All metadata present (theme, tone, length, age)
- [ ] `segments` array has 2 segments
- [ ] Segments ordered by `segment_number`
- [ ] `current_segment_number` is 2

---

### Test 4: Resume Story

**Endpoint:** `GET /interactive-story/<story_id>/resume`

**Request:**
```bash
curl http://localhost:5000/interactive-story/REPLACE_WITH_STORY_ID/resume
```

**Expected Response Structure:**
```json
{
  "story_id": "...",
  "title": "Emma's Magical Adventure",
  "current_segment_number": 2,
  "segment": {
    "id": "...",
    "segment_number": 2,
    "content": "...",
    "choices": [...]
  },
  "inventory": [...],
  "state": {...},
  "is_completed": false
}
```

**Validation Checklist:**
- [ ] Response status is 200
- [ ] Returns current segment (not all segments)
- [ ] Can resume from where user left off
- [ ] Inventory and state are current

---

### Test 5: Complete Story (Final Segment)

**Objective:** Continue making choices until story ends

**Process:**
1. Continue calling `/continue-interactive-story` with subsequent choice IDs
2. For "short" story, expect completion at segment 2-3
3. Watch for `is_completed: true`

**Final Segment Expected:**
- `segment.choices` should be empty array
- `is_completed` should be true
- Content should have climax and resolution
- Warm, brave conclusion

**Validation Checklist:**
- [ ] Story reaches natural conclusion
- [ ] `is_completed` transitions to true
- [ ] No choices in final segment
- [ ] Conclusion includes "impossible moment" (wonder-filled feat)
- [ ] Resolution is warm and empowering

---

### Test 6: Age Calibration (Different Age Bands)

**Test 6a: Age 3-5 (Very Young)**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "theme": "Friendship",
    "tone": "cozy-adventure",
    "length": "short",
    "age": 4
  }'
```

**Expected:**
- Sentence length: 3-6 words
- Word count: 50-80 words
- Vocabulary: CVC words, very concrete
- Stakes: Gentle with reassurance
- Minimal suspense

**Test 6b: Age 9-12 (Older Kids)**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "theme": "Dragons",
    "tone": "mystery",
    "length": "medium",
    "age": 11
  }'
```

**Expected:**
- Sentence length: 8-15 words
- Word count: 150-220 words
- Vocabulary: Grade-level, richer descriptive words
- Stakes: Engaging quest structure
- Moderate mystery and puzzles
- 3 choices (medium length)

---

### Test 7: Choice Count by Length

**Test 7a: Short Story (2 choices)**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "theme": "Adventure",
    "length": "short",
    "age": 8
  }'
```

**Expected:** `segment.choices` has exactly 2 choices

**Test 7b: Medium Story (3 choices)**
```bash
# Change "length": "medium"
```

**Expected:** `segment.choices` has exactly 3 choices

**Test 7c: Long Story (4 choices)**
```bash
# Change "length": "long"
```

**Expected:** `segment.choices` has exactly 4 choices

---

### Test 8: Inventory Persistence

**Objective:** Verify items are tracked across segments

**Process:**
1. Start story
2. Continue to segment where item is mentioned (e.g., "you found a magical key")
3. Check `inventory` array includes "magical key"
4. Continue to next segment
5. Verify item still in inventory
6. If item is used, verify it's removed or marked inactive

**Validation Checklist:**
- [ ] Items appear in inventory when acquired
- [ ] Items persist across segments
- [ ] `acquiredAtSegment` is accurate
- [ ] Items can be added/removed dynamically

---

### Test 9: State Tracking

**Objective:** Verify story state updates correctly

**Initial State (Segment 1):**
```json
{
  "current_location": "The Enchanted Forest",
  "current_goal": "Find the Crystal Cave",
  "key_clues": [],
  "companion_status": "Sparkle the unicorn is eager to help"
}
```

**After Segment 2:**
- [ ] At least one field changed
- [ ] Changes make narrative sense
- [ ] Clues accumulate (don't disappear)
- [ ] Location may change
- [ ] Goal may update or remain same

---

### Test 10: Error Handling

**Test 10a: Missing user_id**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "theme": "Magic",
    "length": "short"
  }'
```

**Expected:** Status 400, error message "user_id is required"

**Test 10b: Invalid story_id**
```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "invalid-uuid",
    "choice_id": "choice_1"
  }'
```

**Expected:** Status 404, error message about story not found

**Test 10c: Invalid choice_id**
```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "VALID_STORY_ID",
    "choice_id": "invalid-choice"
  }'
```

**Expected:** Status 404, error message about choice not found

---

## Browser Testing (Manual UI Validation)

### Setup
1. Open browser to `http://localhost:5000` or app frontend
2. Open Developer Tools (F12)
3. Go to Network tab

### Test Flow
1. Navigate to story creation wizard
2. Select "Interactive Adventure" mode (if option exists)
3. Choose character, theme, tone, length
4. Submit and watch network requests
5. Verify story displays with:
   - Story content
   - Inventory section (may be empty initially)
   - Story state section (location, goal, clues)
   - Choice buttons (2, 3, or 4 depending on length)
   - Progress indicator (Segment 1 of 2-3)

### UI Checklist
- [ ] Story text is readable and age-appropriate
- [ ] Illustration loads (if generated)
- [ ] Inventory displays as collapsible card
- [ ] State displays current location and goal
- [ ] Choices are clickable buttons
- [ ] Clicking choice triggers continuation
- [ ] Loading state shows during generation
- [ ] New segment replaces old segment
- [ ] Inventory updates when items acquired
- [ ] State updates when location/goal changes
- [ ] Progress indicator updates (Segment 2 of 3)
- [ ] Story ends gracefully with no choices
- [ ] Save button appears when story completes

---

## Performance Testing

### Test 11: Response Time
**Benchmark:** Each segment should generate within:
- Opening segment: < 15 seconds (includes illustration)
- Continuation: < 10 seconds (includes illustration)

**Measurement:**
```bash
time curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test","theme":"Magic","length":"short","age":8}'
```

### Test 12: Concurrent Requests
**Test:** 3 simultaneous story creations

```bash
# Run these in parallel (separate terminals)
curl -X POST ... & curl -X POST ... & curl -X POST ...
```

**Expected:**
- All requests complete successfully
- No database lock errors
- No race conditions

---

## Database Validation

### Test 13: Data Persistence

**After completing tests above:**
```sql
-- Check interactive_story table
SELECT id, title, theme, length, current_segment_number, is_completed
FROM interactive_story;

-- Check segments created
SELECT story_id, segment_number, LENGTH(content) as content_length
FROM story_segment
ORDER BY story_id, segment_number;

-- Check choices
SELECT segment_id, choice_number, text, is_selected
FROM story_choice
ORDER BY segment_id, choice_number;

-- Check inventory
SELECT story_id, name, acquired_at_segment, is_active
FROM inventory_item;

-- Check story state
SELECT story_id, current_location, current_goal,
       json_array_length(key_clues) as clue_count
FROM story_state;
```

**Validation:**
- [ ] All tables have data
- [ ] Foreign key relationships intact
- [ ] No orphaned records
- [ ] Segment numbers sequential
- [ ] Selected choices marked correctly

---

## Success Criteria

### Core Functionality
- ✅ Can create new interactive story
- ✅ Can continue story based on choices
- ✅ Can get full story with all segments
- ✅ Can resume in-progress story
- ✅ Story completes naturally at target length

### Age Calibration
- ✅ Content matches age band vocabulary
- ✅ Sentence length appropriate for age
- ✅ Word count within target range
- ✅ Stakes and suspense age-appropriate

### Inventory & State
- ✅ Inventory items tracked correctly
- ✅ Items persist across segments
- ✅ State updates with choices
- ✅ Location, goal, clues managed properly

### Branching & Choices
- ✅ Choice count matches length (short=2, medium=3, long=4)
- ✅ Choices lead to distinct consequences
- ✅ Story branches based on selections
- ✅ Continuity maintained across segments

### Character Integration
- ✅ Character name appears in story
- ✅ Character traits influence narrative
- ✅ Fears addressed in story
- ✅ Strengths utilized in solutions

### Safety & Quality
- ✅ Content is psychologically safe
- ✅ No violence or scary themes
- ✅ Language is age-appropriate
- ✅ Stories have warm, empowering conclusions

---

## Known Issues / Notes

- Illustration generation may be slow (10+ seconds) - this is expected
- First request may be slower due to cold start
- JSON mode requires Gemini 2.0 Flash or later
- Some age bands may need vocabulary tuning based on testing

---

## Next Steps After Testing

1. **If tests pass:** Proceed with frontend UI implementation
2. **If tests fail:** Document failures and fix backend issues
3. **Performance issues:** Optimize prompts or add caching
4. **Age calibration issues:** Refine vocabulary filters
5. **Integration issues:** Update frontend service layer

---

## Test Results Log

**Tester:** _________________
**Date:** _________________
**Environment:** _________________

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Create Story | ⬜ | |
| 2 | Continue Story | ⬜ | |
| 3 | Get Full Story | ⬜ | |
| 4 | Resume Story | ⬜ | |
| 5 | Complete Story | ⬜ | |
| 6a | Age 3-5 | ⬜ | |
| 6b | Age 9-12 | ⬜ | |
| 7a | Short (2 choices) | ⬜ | |
| 7b | Medium (3 choices) | ⬜ | |
| 7c | Long (4 choices) | ⬜ | |
| 8 | Inventory | ⬜ | |
| 9 | State Tracking | ⬜ | |
| 10 | Error Handling | ⬜ | |
| 11 | Performance | ⬜ | |
| 12 | Concurrent | ⬜ | |
| 13 | Database | ⬜ | |

**Overall Result:** ⬜ PASS / ⬜ FAIL

**Issues Found:**
-
-
-

**Recommendations:**
-
-
