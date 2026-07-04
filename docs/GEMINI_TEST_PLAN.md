# Gemini Test Plan for Story Weaver App

**Created:** 2026-02-02
**Created By:** Claude (Supervisor)
**For:** Gemini CLI instances
**Purpose:** Run verification tests while Claude is unavailable

---

## Context for Gemini

You are helping test the Story Weaver App, a Flutter + Python/Flask application that generates personalized children's stories using AI. The app recently underwent:

1. **SDK Migration:** From deprecated `google-generativeai` to new `google-genai` SDK
2. **API Key Rotation:** Fixed leaked key issues
3. **Bug Fixes:** Story length validation, character persistence, lint cleanup

**Project Structure:**
- `backend/` - Python Flask API
- `lib/` - Flutter/Dart frontend
- `backend/.env` - Environment variables (API keys)
- `TEAM_COORDINATION.md` - Session log (UPDATE THIS after testing)

---

## Pre-Flight Checks

Before running any tests, verify the environment:

```bash
cd C:\dev\story-weaver-app\backend

# 1. Check API keys are set
python -c "
from dotenv import load_dotenv
import os
load_dotenv()
print('GEMINI_API_KEY:', 'SET' if os.getenv('GEMINI_API_KEY') else 'MISSING')
print('OPENROUTER_API_KEY:', 'SET' if os.getenv('OPENROUTER_API_KEY') else 'MISSING')
"

# 2. Quick Gemini connectivity test
python -c "
from dotenv import load_dotenv
import os
load_dotenv()
from google import genai
client = genai.Client(api_key=os.getenv('GEMINI_API_KEY'))
r = client.models.generate_content(model='gemini-2.0-flash', contents='Say OK')
print('Gemini:', r.text)
"
```

**Expected:** Both keys SET, Gemini responds with "OK" or similar.

---

## Test Suite 1: Backend Unit Tests

### 1.1 Custom Elements Enforcement

Tests that user-submitted story ideas appear in generated stories.

```bash
cd C:\dev\story-weaver-app\backend
python -m pytest tests/test_custom_elements.py -v
```

**Expected:** 4/4 tests pass

### 1.2 Story Personalization Logic (Prompt-Only Mode)

Tests prompt construction for all age/mode combinations WITHOUT calling the API.

```bash
cd C:\dev\story-weaver-app\backend
python tests/manual/story_personalization_suite.py --prompt-only
```

**Expected:** 100% logic alignment across all age groups

---

## Test Suite 2: Backend Integration Tests

### 2.1 Start the Backend Server

```bash
cd C:\dev\story-weaver-app\backend
python app.py
```

Keep this running in a separate terminal. Expected output includes:
- `GEMINI_API_KEY loaded: True`
- `Running on http://127.0.0.1:5000`

### 2.2 Health Check

```bash
curl http://localhost:5000/health
```

**Expected:** `{"status": "healthy", "database": "connected"}`

### 2.3 Run Phase 3 Test Suite

In a new terminal:

```bash
cd C:\dev\story-weaver-app
python run_phase3_tests.py
```

**Expected Results:**
| Test | Expected |
|------|----------|
| Backend Health | PASS |
| Custom Elements - Simple | PASS |
| Custom Elements - Multiple | PASS |
| Empty Custom Elements | PASS |
| Special Characters | PASS |
| Story Length - QUICK | PASS |
| Story Length - STANDARD | PASS |
| Story Length - EPIC | PASS |

**Success Rate Target:** 100% (8/8 tests)

### 2.4 Manual Story Generation Test

Test a full story generation with all parameters:

```bash
curl -X POST http://localhost:5000/generate-story \
  -H "Content-Type: application/json" \
  -d '{
    "character": "Luna",
    "age": 7,
    "gender": "girl",
    "archetype": "The Brave Explorer",
    "theme": "Adventure",
    "story_length": "standard",
    "custom_elements": "I want to find a magical crystal",
    "mood_selection": ["excited", "curious"],
    "companion": {"name": "Sparkle", "type": "unicorn"}
  }'
```

**Expected:**
- HTTP 200 response
- JSON with `story` field containing narrative
- Story mentions "Luna", "Sparkle", and "crystal"

---

## Test Suite 3: Flutter Analysis

### 3.1 Flutter Analyze

```bash
cd C:\dev\story-weaver-app
flutter analyze
```

**Expected:**
- 0 errors
- Warnings/info are acceptable (deprecations, style hints)

### 3.2 Flutter Test (if unit tests exist)

```bash
flutter test
```

**Expected:** All tests pass (or skip if no tests configured)

---

## Test Suite 4: Interactive Story (Pick-a-Path) Mode

### 4.1 Start Interactive Story

```bash
curl -X POST http://localhost:5000/generate-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_123",
    "character_id": "test_char_1",
    "theme": "Magic",
    "tone": "whimsical",
    "length": "medium",
    "age": 8
  }'
```

**Expected:**
- HTTP 200
- JSON with `story_id`, `segment` (story text), and `choices` (array of 2-3 options)
- Segment length should be ~100-200 words (age-appropriate)

### 4.2 Continue Interactive Story

Use the `story_id` and a `choice_id` from the previous response:

```bash
curl -X POST http://localhost:5000/continue-interactive-story \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "<story_id_from_start>",
    "choice_id": "<choice_id_from_previous_response>"
  }'
```

**Expected:** New segment with new choices, story continues coherently

---

## Test Suite 5: Error Handling

### 5.1 Invalid Age

```bash
curl -X POST http://localhost:5000/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character": "Test", "age": -5, "theme": "Adventure"}'
```

**Expected:** HTTP 400 with validation error

### 5.2 Missing Required Fields

```bash
curl -X POST http://localhost:5000/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character": "Test"}'
```

**Expected:** HTTP 400 with error listing missing fields

---

## Troubleshooting Guide

### Issue: 429 RESOURCE_EXHAUSTED

**Cause:** Gemini free tier quota exceeded for the project.

**Fix:**
1. Check which project the API key belongs to at https://aistudio.google.com/apikey
2. Switch to a key from a different project
3. Or wait for daily quota reset

### Issue: 403 PERMISSION_DENIED / "Key leaked"

**Cause:** API key was flagged by Google's security.

**Fix:**
1. Generate new key at https://aistudio.google.com/apikey
2. Update `backend/.env` with new `GEMINI_API_KEY`

### Issue: 500 Internal Server Error

**Cause:** Backend exception, check logs.

**Fix:**
1. Check terminal running `python app.py` for stack trace
2. Common issues: missing env vars, import errors

### Issue: Connection Refused

**Cause:** Backend not running.

**Fix:** Start backend with `python app.py`

---

## Updating TEAM_COORDINATION.md

After completing tests, add a new entry at the TOP of the session notes (after the header section).

**Template:**

```markdown
---

## Supervisor Notes | 2026-02-XX (Test Verification)

### Session: Gemini-Led Test Verification - [STATUS]

**Goal:** Run comprehensive test suite to verify app stability.

**Status:** [COMPLETED/PARTIAL/BLOCKED]

**Test Results:**

| Suite | Result | Notes |
|-------|--------|-------|
| Pre-Flight Checks | PASS/FAIL | |
| Backend Unit Tests | X/4 | |
| Phase 3 Integration | X/8 | |
| Flutter Analyze | PASS/FAIL | X errors |
| Interactive Story | PASS/FAIL | |
| Error Handling | PASS/FAIL | |

**Issues Found:**
- [List any failures or unexpected behavior]

**Actions Taken:**
- [List any fixes applied]

**Next Steps:**
- [Recommendations for when Claude returns]

---
```

---

## Priority Order

If time is limited, run tests in this order:

1. **Pre-Flight Checks** (must pass to continue)
2. **Phase 3 Integration Tests** (most comprehensive)
3. **Flutter Analyze** (catch any regressions)
4. **Interactive Story Test** (validates Pick-a-Path mode)
5. **Backend Unit Tests** (already covered by Phase 3)

---

## Success Criteria

The app is ready for deployment if:

- [ ] Gemini API responds successfully
- [ ] Phase 3 tests: 8/8 pass
- [ ] Flutter analyze: 0 errors
- [ ] Interactive story starts and continues
- [ ] TEAM_COORDINATION.md updated with results

---

## Contact

If major issues are found that Gemini cannot resolve:
- Document everything in TEAM_COORDINATION.md
- Note the exact error messages and stack traces
- Claude will review when available (in ~3 days)

---

*This plan was generated by Claude (Supervisor) on 2026-02-02*
