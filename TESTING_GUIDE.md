# Testing Guide - Pick-A-Path Adventures UX Improvements

This guide explains how to test all the UX improvements implemented for Pick-A-Path Adventures.

---

## Quick Start

### Backend Tests (No Browser)
```bash
# Windows
run_backend_tests.bat

# Linux/Mac
python tests/test_backend_comprehensive.py
```

### Frontend Tests (Requires Browser)
```bash
# Manual testing
Open: tests/TEST_MANUAL_BROWSER.md

# Automated Flutter tests
flutter test integration_test/pick_a_path_test.dart
```

---

## Test Categories

### 1. Backend Tests (No Browser Required)

These tests validate:
- Prompt generation
- Database models
- Word count calculations
- JSON schema validation
- Story generation (if API key available)

**Location**: `tests/test_backend_comprehensive.py`

**How to Run**:

#### Option A: Using pytest (Recommended)
```bash
pip install pytest
python -m pytest tests/test_backend_comprehensive.py -v
```

#### Option B: Using unittest
```bash
python tests/test_backend_comprehensive.py
```

#### Option C: Windows Batch Script
```bash
run_backend_tests.bat
```

**Tests Included**:

| Test Class | Test Count | Purpose |
|------------|------------|---------|
| TestPromptBuilder | 8 | Verify prompt improvements |
| TestDatabaseModels | 3 | Check new database fields |
| TestWordCountCalculation | 1 | Validate word counting |
| TestJSONSchemaValidation | 1 | Schema correctness |
| TestStoryGeneration* | 6 | Full story generation |

*Requires GEMINI_API_KEY

**Expected Output**:
```
================================================================================
 COMPREHENSIVE BACKEND TESTS - PICK-A-PATH UX IMPROVEMENTS
================================================================================

✓ Word count for age 6-8: (350, 500)
✓ Choice counts: {'short': 2, 'medium': 2, 'long': 2}
...

================================================================================
 TEST SUMMARY
================================================================================
Tests run: 19
Successes: 19
Failures: 0
Errors: 0

✅ ALL TESTS PASSED!
```

---

### 2. Frontend/Browser Tests (Requires Browser)

#### 2A: Manual Testing Checklist

**Location**: `tests/TEST_MANUAL_BROWSER.md`

**How to Use**:
1. Open the markdown file
2. Start the Flutter app (`flutter run -d chrome`)
3. Follow each test step
4. Mark Pass/Fail for each test

**Test Suites** (30 tests total):
1. Basic Story Creation (3 tests)
2. CONTINUE/CHOICE System (3 tests)
3. Choice Quality (3 tests)
4. Companion Integration (3 tests)
5. Inventory System (2 tests)
6. Reading Experience (3 tests)
7. Completion & Error Handling (3 tests)
8. Visual Presentation (3 tests)
9. Edge Cases (3 tests)
10. Performance (3 tests)

**Sample Test**:
```markdown
### Test 2.1: CONTINUE Button Appears
**Steps:**
1. Generate a new story
2. Look for "Continue" button

**Expected Results:**
- ✅ Some segments show Continue button
- ✅ Button has arrow icon
- ✅ Button says "Continue"

**Pass/Fail:** ___________
```

#### 2B: Automated Flutter Integration Tests

**Location**: `integration_test/pick_a_path_test.dart`

**How to Run**:

##### Option 1: Simple Test Run
```bash
flutter test integration_test/pick_a_path_test.dart
```

##### Option 2: With Chrome Driver (Full Integration)
```bash
# Terminal 1: Start Chrome driver
chromedriver --port=4444

# Terminal 2: Run tests
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/pick_a_path_test.dart \
  -d chrome
```

**Tests Included**:
- App launches successfully
- Navigate to Pick-A-Path screen
- Story segment displays
- Continue button functionality
- Choice button functionality
- Choice selection works
- Inventory section visible
- Completion screen works
- Model unit tests

---

## Test Prerequisites

### For Backend Tests

**Required**:
- Python 3.8+
- Backend dependencies installed:
  ```bash
  pip install -r backend/requirements.txt
  ```

**Optional** (for story generation tests):
- `GEMINI_API_KEY` environment variable set
- Gemini API access

**Setup**:
```bash
# Windows
set GEMINI_API_KEY=your-api-key-here

# Linux/Mac
export GEMINI_API_KEY=your-api-key-here
```

### For Frontend Tests

**Required**:
- Flutter SDK installed
- Chrome browser
- Backend server running (for integration tests)

**Setup**:
```bash
# Install Flutter
flutter doctor

# Get dependencies
flutter pub get

# Run backend (in separate terminal)
python backend/app.py
```

---

## Detailed Test Descriptions

### Backend Test Details

#### Test 1: Word Count Ranges
**What it tests**: Verifies word counts increased to 350-500 (age 6-8)

**Pass criteria**:
- Minimum ≥ 300 words
- Maximum ≥ 450 words

**Example output**:
```
✓ Word count for age 6-8: (350, 500)
```

---

#### Test 2: Choice Count Reduction
**What it tests**: Verifies choices reduced to 2

**Pass criteria**:
- Medium stories: 2 choices
- Long stories: 2 choices

**Example output**:
```
✓ Choice counts: {'short': 2, 'medium': 2, 'long': 2}
```

---

#### Test 3: POV Requirements in Prompt
**What it tests**: Prompt includes second-person POV rules

**Pass criteria**:
- Contains "second-person"
- Contains "you" examples
- Mentions POV requirements

**Example output**:
```
✓ Opening prompt includes POV requirements
```

---

#### Test 4: Companion Contract
**What it tests**: Companion contract rules in prompt

**Pass criteria**:
- Mentions "companion contract"
- Specifies "3" beats
- Includes "bond" requirement

**Example output**:
```
✓ Opening prompt includes Companion Contract
```

---

#### Test 5: Inventory Contract
**What it tests**: Inventory contract in prompt

**Pass criteria**:
- Contains "inventory contract"
- Mentions "visibility"

**Example output**:
```
✓ Opening prompt includes Inventory Contract
```

---

#### Test 6: Banned Choices
**What it tests**: Filler choices explicitly banned

**Pass criteria**:
- Contains "ask what to do"
- Contains "banned"

**Example output**:
```
✓ Opening prompt bans filler choices
```

---

#### Test 7: Output Type System
**What it tests**: CONTINUE/CHOICE system explained

**Pass criteria**:
- Contains "output_type"
- Mentions "continue" and "choice"

**Example output**:
```
✓ Opening prompt includes output_type system
```

---

#### Test 8: Database Fields
**What it tests**: New fields exist in database

**Pass criteria**:
- `output_type` column exists
- `word_count` column exists
- `to_dict()` includes both fields

**Example output**:
```
✓ StorySegment has output_type column
✓ StorySegment has word_count column
✓ to_dict() includes output_type and word_count
```

---

#### Test 9-14: Story Generation Tests
**What they test**: Actual story generation with Gemini

**Requirements**: GEMINI_API_KEY must be set

**Tests**:
- Generate opening segment
- Word count in range (300-500+)
- Second-person POV dominant (you count > 5)
- Companion beats present (≥3)
- No banned choice patterns
- Choice count is 2

**Example output**:
```
→ Generating story with Gemini...
✓ Generated segment with output_type=CHOICE
✓ Word count: 427 (target: 350-500)
✓ POV check: 'you' appears 18 times
✓ Companion beats: 4 (dialogue, action, bond, dialogue)
✓ No banned patterns in 2 choices
✓ Choice count: 2
```

---

### Frontend Test Details

#### Manual Test: Basic Story Creation
**Tests**:
1. Can create new adventure
2. Segments are longer (~350-500 words)
3. Second-person POV is used

**How to verify**:
- Copy story text to word counter
- Count "you" vs child's name
- Confirm immersive feel

---

#### Manual Test: CONTINUE/CHOICE System
**Tests**:
1. Continue button appears
2. Continue button works
3. Choices appear at decision points

**How to verify**:
- Look for single "Continue" button
- Verify it advances story
- Confirm choices appear separately

---

#### Manual Test: Choice Quality
**Tests**:
1. No filler choices
2. Choices are distinct
3. Choices have consequences

**How to verify**:
- Check for banned phrases
- Imagine different outcomes
- Verify next segment reflects choice

---

#### Manual Test: Companion Integration
**Tests**:
1. Companion appears frequently
2. Companion helps
3. Bond moments present

**How to verify**:
- Count companion mentions (≥3 per segment)
- Find examples of help
- Look for relationship moments

---

## Troubleshooting

### Backend Tests Fail

**Problem**: "Module not found"
**Solution**:
```bash
pip install -r backend/requirements.txt
```

**Problem**: "GEMINI_API_KEY not set" warning
**Solution**: This is okay - story generation tests will be skipped

**Problem**: Tests timeout
**Solution**: Increase timeout or check network connection

---

### Frontend Tests Fail

**Problem**: "Unable to connect to backend"
**Solution**: Make sure backend is running:
```bash
python backend/app.py
```

**Problem**: "Widget not found"
**Solution**: Tests may need adjustment based on actual UI structure

**Problem**: Chrome driver not found
**Solution**: Install Chrome driver:
```bash
# Windows (with chocolatey)
choco install chromedriver

# Or download from:
# https://chromedriver.chromium.org/
```

---

## Continuous Integration

### GitHub Actions (Future)

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      - run: pip install -r backend/requirements.txt
      - run: pip install pytest
      - run: python -m pytest tests/test_backend_comprehensive.py
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter test integration_test/pick_a_path_test.dart
```

---

## Test Metrics & Goals

### Target Pass Rates

| Test Category | Target | Current |
|---------------|--------|---------|
| Backend Unit Tests | 100% | TBD |
| Backend Integration | 100% | TBD |
| Frontend Manual | 90%+ | TBD |
| Frontend Automated | 80%+ | TBD |

### Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Prompt Builder | 90%+ |
| Models | 100% |
| Service Layer | 80%+ |
| UI Components | 70%+ |

---

## Reporting Issues

If tests fail, please report with:

1. **Test name** that failed
2. **Error message** (full stack trace)
3. **Environment**:
   - OS and version
   - Python version
   - Flutter version (for frontend tests)
   - Browser (for manual tests)
4. **Steps to reproduce**
5. **Expected vs actual** behavior

**Example**:
```
Test: test_word_count_in_range
Error: AssertionError: Story should have at least 300 words, got 287

Environment:
- OS: Windows 11
- Python: 3.11
- Browser: Chrome 120

Steps: Ran python tests/test_backend_comprehensive.py

Expected: 350-500 words
Actual: 287 words
```

---

## Next Steps After Testing

### If All Tests Pass ✅
1. Deploy to staging environment
2. Run manual QA pass
3. Get user feedback
4. Deploy to production

### If Tests Fail ❌
1. Review failure logs
2. Fix issues
3. Re-run tests
4. Create regression tests
5. Document findings

---

## Test Maintenance

### When to Update Tests

**Update backend tests when**:
- Prompt structure changes
- Word count targets change
- New requirements added
- API endpoints modified

**Update frontend tests when**:
- UI components change
- Navigation flow changes
- New features added
- Visual design updates

### Test Review Schedule

- **Daily**: Run backend tests during development
- **Weekly**: Full manual test pass
- **Before release**: Complete test suite (backend + frontend)
- **Monthly**: Review and update test cases

---

## Additional Resources

- **Test Files**:
  - `tests/test_backend_comprehensive.py` - Backend tests
  - `tests/TEST_MANUAL_BROWSER.md` - Manual checklist
  - `integration_test/pick_a_path_test.dart` - Flutter tests

- **Documentation**:
  - `PICK_A_PATH_UX_IMPROVEMENTS.md` - Design spec
  - `IMPLEMENTATION_COMPLETE.md` - What was implemented

- **Tools**:
  - `run_backend_tests.bat` - Windows test runner
  - `test_pick_a_path_improvements.py` - Story generation tester

---

## Contact

For questions about testing:
- Check test comments in code
- Review this guide
- Consult implementation docs
