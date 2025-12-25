# Agent 1: Backend/API Testing Instructions

**Your Role:** Test the Pick-A-Path Adventures backend APIs and database without using a browser.

**Tools You'll Use:** Command line (curl, Python scripts)

**Time Estimate:** 30-45 minutes

---

## Your Mission

Verify that the Pick-A-Path Adventures backend system works correctly by:
1. Testing API endpoints with curl commands
2. Validating database schema and data persistence
3. Checking age calibration and choice count logic
4. Testing error handling
5. Measuring performance benchmarks

---

## Prerequisites

### Step 1: Start the Backend Server

```bash
cd C:\dev\story-weaver-app\backend
python app.py
```

**Wait for:** Server starts on `http://localhost:5000`

### Step 2: Verify Server is Running

```bash
curl http://localhost:5000/health
```

**Expected:** `{"status": "healthy"}` or similar

**If this fails, STOP and report the issue.**

---

## Your Test Plan

**Reference Document:** `PICK_A_PATH_TESTING_PLAN.md` (Part 1: Backend/API Tests)

You will execute **Test Suites A through E** (15 total tests).

---

## Test Execution Order

### 1. Test Suite A: Database Schema (2 tests)

**Open:** `PICK_A_PATH_TESTING_PLAN.md` and go to "Test Suite A"

**Run:**
- **A1**: Verify all 5 tables exist
- **A2**: Verify table relationships

**Commands are provided in the testing plan - copy and paste them.**

**Record results in:** Notes or text file

---

### 2. Test Suite B: API Endpoints (8 tests)

**This is the CORE test suite - most important!**

**Run in order:**

#### B1. Generate New Story (Age 8, Short)
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

**CRITICAL: Save the `story_id` and `choice_1.id` from the response!**

**Check:**
- ✅ Status code 200
- ✅ Has `story_id`
- ✅ Has 2 choices (short = 2 choices)
- ✅ Content is 100-150 words
- ✅ Time < 30 seconds

#### B2. Age Calibration - Age 5
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

**Check:**
- ✅ Content is 50-80 words (age 3-5 band)
- ✅ Simple vocabulary

#### B3. Age Calibration - Age 14
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

**Check:**
- ✅ Content is 200-280 words (age 13-16 band)
- ✅ More complex vocabulary

#### B4. Choice Counts by Length

**Short (2 choices):**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "short", "age": 8}'
```
**Check:** `choices` array has 2 items

**Medium (3 choices):**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "medium", "age": 8}'
```
**Check:** `choices` array has 3 items

**Long (4 choices):**
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "long", "age": 8}'
```
**Check:** `choices` array has 4 items

#### B5. Continue Story (Using story from B1)
```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "PASTE_STORY_ID_FROM_B1",
    "choice_id": "PASTE_CHOICE_1_ID_FROM_B1"
  }'
```

**Check:**
- ✅ `segment_number` is 2
- ✅ `current_location` changed
- ✅ Response time < 30 seconds

#### B6. Story Completion
Continue the story from B5 one more time to reach segment 3 (completion for short story)

```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "PASTE_SAME_STORY_ID",
    "choice_id": "PASTE_CHOICE_ID_FROM_SEGMENT_2"
  }'
```

**Check:**
- ✅ `segment_number` is 3
- ✅ `is_completed` is true
- ✅ `choices` is empty array

#### B7. Get Full Story
```bash
curl http://localhost:5000/interactive-story/PASTE_STORY_ID
```

**Check:**
- ✅ Returns all 3 segments
- ✅ Segments in order (1, 2, 3)

#### B8. Resume Story
Create a new story and immediately resume it:

```bash
# Create
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "character_id": "test", "theme": "Dragons", "tone": "whimsical", "length": "medium", "age": 10}'

# Save the story_id, then resume:
curl http://localhost:5000/interactive-story/PASTE_NEW_STORY_ID/resume
```

**Check:**
- ✅ Returns current segment
- ✅ Returns inventory and state

---

### 3. Test Suite C: Error Handling (3 tests)

#### C1. Invalid Story ID
```bash
curl http://localhost:5000/interactive-story/invalid-uuid-999
```
**Check:** Status code 404

#### C2. Missing Required Fields
```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test"}'
```
**Check:** Status code 400

#### C3. Invalid Choice ID
```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "PASTE_VALID_STORY_ID",
    "choice_id": "invalid-choice-999"
  }'
```
**Check:** Status code 400 or 404

---

### 4. Test Suite D: Database Persistence (3 tests)

#### D1. Verify Stories Saved
```bash
python -c "
from backend.app import create_app
from backend.database import db
from backend.models.interactive_story import InteractiveStory

app = create_app('development')
with app.app_context():
    stories = InteractiveStory.query.all()
    print(f'Total stories: {len(stories)}')
    for story in stories[:5]:
        print(f'- {story.title} (Segments: {len(story.segments)})')
"
```

**Check:** At least 4 stories exist

#### D2. Verify Inventory Persistence
```bash
python -c "
from backend.app import create_app
from backend.database import db
from backend.models.interactive_story import InteractiveStory

app = create_app('development')
with app.app_context():
    stories = InteractiveStory.query.all()
    for story in stories:
        if story.inventory:
            print(f'Story: {story.title}')
            for item in story.inventory[:3]:
                print(f'  - {item.name} (segment {item.acquired_at_segment})')
            break
"
```

**Check:** Some stories have inventory items

#### D3. Verify State Tracking
```bash
python -c "
from backend.app import create_app
from backend.database import db
from backend.models.interactive_story import InteractiveStory

app = create_app('development')
with app.app_context():
    story = InteractiveStory.query.first()
    if story and story.state:
        print(f'Location: {story.state.current_location}')
        print(f'Goal: {story.state.current_goal}')
        print(f'Clues: {story.state.key_clues}')
"
```

**Check:** State fields are populated

---

### 5. Test Suite E: Performance (Optional)

#### E1. Concurrent Requests
```bash
# Create test script
cat > test_concurrent.sh << 'EOF'
#!/bin/bash
for i in {1..5}; do
  curl -X POST http://localhost:5000/generate-interactive-story \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"concurrent_$i\", \"character_id\": \"test\", \"theme\": \"Magic\", \"tone\": \"whimsical\", \"length\": \"short\", \"age\": 8}" \
    -s -o /dev/null -w "Request $i: %{http_code} in %{time_total}s\n" &
done
wait
EOF

chmod +x test_concurrent.sh
./test_concurrent.sh
```

**Check:** All 5 succeed with status 200

#### E2. Response Time Benchmark
```bash
for i in {1..5}; do
  curl -X POST http://localhost:5000/generate-interactive-story \
    -H "Content-Type: application/json" \
    -d '{"user_id": "perf_test", "character_id": "test", "theme": "Magic", "tone": "whimsical", "length": "short", "age": 8}' \
    -w "Request $i: %{time_total}s\n" \
    -o /dev/null -s
done
```

**Check:** Average time < 20 seconds

---

## Your Deliverable

Create a file called `BACKEND_TEST_RESULTS.md` with this template:

```markdown
# Pick-A-Path Adventures - Backend Test Results

**Date:** [TODAY'S DATE]
**Tester:** Agent 1 (Backend)
**Environment:** Windows/Mac/Linux

## Test Results Summary

### Test Suite A: Database Schema
- A1. Tables Exist: PASS/FAIL
- A2. Relationships: PASS/FAIL

### Test Suite B: API Endpoints
- B1. Generate Story (Age 8): PASS/FAIL
- B2. Age Calibration (Age 5): PASS/FAIL
- B3. Age Calibration (Age 14): PASS/FAIL
- B4. Choice Counts (Short/Medium/Long): PASS/FAIL
- B5. Continue Story: PASS/FAIL
- B6. Story Completion: PASS/FAIL
- B7. Get Full Story: PASS/FAIL
- B8. Resume Story: PASS/FAIL

### Test Suite C: Error Handling
- C1. Invalid Story ID: PASS/FAIL
- C2. Missing Fields: PASS/FAIL
- C3. Invalid Choice: PASS/FAIL

### Test Suite D: Database Persistence
- D1. Stories Saved: PASS/FAIL
- D2. Inventory Saved: PASS/FAIL
- D3. State Saved: PASS/FAIL

### Test Suite E: Performance (Optional)
- E1. Concurrent Load: PASS/FAIL
- E2. Response Times: PASS/FAIL

## Overall Results

**Total Tests Run:** [X/15]
**Passed:** [X]
**Failed:** [X]
**Pass Rate:** [X%]

## Critical Issues Found

[List any FAIL results here with details]

1. Issue: [Description]
   - Test: [Test ID]
   - Expected: [What should happen]
   - Actual: [What happened]
   - Severity: Critical/High/Medium/Low

## Warnings/Notes

[Any non-critical observations]

## Sample API Responses

[Paste 1-2 example successful responses]

Example from B1:
```json
{
  "story_id": "...",
  "title": "...",
  ...
}
```

## Conclusion

[Overall assessment - Ready for production? Needs fixes?]
```

---

## Success Criteria

**Minimum to Pass:**
- ✅ 13/15 tests pass (87%)
- ✅ All of Suite B passes (API endpoints)
- ✅ No critical errors

**Ideal:**
- ✅ 15/15 tests pass (100%)
- ✅ Response times under 20s average
- ✅ All data persists correctly

---

## If You Encounter Errors

**Server won't start:**
1. Check if port 5000 is in use
2. Check Python version (need 3.8+)
3. Check if `backend/.env` has `GEMINI_API_KEY`

**API returns 500 errors:**
1. Check server logs in terminal
2. Verify database tables exist (Test A1)
3. Check if Gemini API key is valid

**Tests taking too long (>60s):**
1. This may be Gemini API rate limiting
2. Wait 1 minute between tests
3. Note in results but don't fail the test

**Database errors:**
1. Check if `backend/instance/app.db` exists
2. Try deleting it and restarting server
3. Migration should auto-run

---

## Tips for Success

1. **Copy-paste commands carefully** - One wrong character breaks the test
2. **Save story IDs** - You'll need them for continuation tests
3. **Count words** - Use online word counter or: `echo "text" | wc -w`
4. **Time responses** - curl's `-w` flag shows timing
5. **Read error messages** - They tell you what's wrong
6. **Take breaks** - Some API calls take 20-30 seconds

---

## Files You'll Reference

1. `PICK_A_PATH_TESTING_PLAN.md` - Your main guide (Part 1: Backend)
2. `backend/app.py` - Server code (for debugging)
3. `backend/models/interactive_story.py` - Database models
4. `BACKEND_TEST_RESULTS.md` - Your output (create this)

---

## Questions?

If you get stuck, document:
1. Which test failed
2. The exact error message
3. What command you ran
4. What you expected vs what happened

**Good luck! The backend is solid - you should see mostly PASSes! 🚀**
