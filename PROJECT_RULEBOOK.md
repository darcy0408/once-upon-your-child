# Project Rulebook - Story Weaver App

**READ THIS FIRST when starting any task in this project!**

This document contains critical rules and cost-saving practices that ALL agents and developers must follow.

---

## 🚨 CRITICAL COST-SAVING RULE #1: ALWAYS USE MOCK MODE FOR TESTING

### Before Running ANY Tests:

**ALWAYS check and enable mock mode first:**

```bash
# Windows Command Prompt:
set MOCK_TESTING_MODE=true

# Windows PowerShell:
$env:MOCK_TESTING_MODE = "true"

# Then verify it's enabled:
echo %MOCK_TESTING_MODE%  # Should show: true
```

### Why This Matters:
- Mock mode = $0.00 cost
- Real API = ~$0.0034 per story
- Running 100 tests in mock = $0.00
- Running 100 tests in real API = $0.34

**NEVER run tests without checking mock mode first!**

---

## 🔧 Current Setup (As of 2025-12-26)

### API Configuration:
- **API Key**: `story_weaver_backend` (Tier 1 with billing enabled)
- **Current Model**: `gemini-2.0-flash-exp` ⚠️ **SHOULD BE CHANGED**
- **Recommended Model**: `gemini-2.5-flash` (stable, better quotas)
- **Location**: `backend/.env` and `backend/config/__init__.py` line 23

### Known Issues:
1. **Quota Issue**: Using experimental model with free-tier limits even on Tier 1
2. **Solution**: Switch to `gemini-2.5-flash` in `backend/config/__init__.py` line 23

---

## 📋 AGENT TASK CHECKLIST

When starting ANY task, follow these steps:

### Step 1: Read Current Mode
```bash
# Check if mock mode is enabled
echo %MOCK_TESTING_MODE%

# Or check via API (if backend running)
curl http://localhost:5000/usage/mock-mode
```

### Step 2: Enable Mock Mode for Testing
```bash
# ALWAYS set this before testing
set MOCK_TESTING_MODE=true

# Add to .env for persistence (optional)
echo MOCK_TESTING_MODE=true >> backend\.env
```

### Step 3: Verify Backend is Running
```bash
# Check backend health
curl http://localhost:5000/health

# If not running, start it:
# python backend/app.py
```

### Step 4: Run Your Tests (Now FREE!)
```bash
# Run phase 3 tests
python run_phase3_tests.py

# You should see:
# MOCK TESTING MODE: ENABLED ✅ (FREE)
# Cost per test: $0.00
```

### Step 5: Check Usage After Testing
```bash
# View usage summary
curl http://localhost:5000/usage/summary?days=1

# Should show mock calls with $0.00 cost
```

---

## 🎯 WHEN TO USE MOCK vs REAL API

### ✅ ALWAYS Use Mock Mode For:
- **Development**: Writing new code, debugging, refactoring
- **Unit Tests**: Testing individual functions/components
- **Integration Tests**: Testing how components work together
- **Regression Tests**: Verifying old features still work
- **CI/CD**: Automated test runs
- **Learning**: Exploring how the system works
- **Debugging**: Investigating issues
- **Performance Tests**: Load testing, stress testing

### ❌ ONLY Use Real API For:
- **Final Validation**: 1-2 tests before production deploy
- **Quality Check**: Verify AI responses meet standards
- **User Acceptance**: Show real results to stakeholders
- **Production Bugs**: Reproduce issues that only occur with real API

### Rule of Thumb:
**Default to Mock Mode. Only disable for specific, justified reasons.**

---

## 🔄 HOW TO SWITCH MODES

### Enable Mock Mode (FREE):
```bash
set MOCK_TESTING_MODE=true
python run_phase3_tests.py
```

### Disable Mock Mode (COSTS MONEY):
```bash
set MOCK_TESTING_MODE=false
python run_phase3_tests.py
```

### Persistent Configuration:
Add to `backend/.env`:
```bash
# For development (recommended)
MOCK_TESTING_MODE=true

# For production
# MOCK_TESTING_MODE=false
```

---

## 📊 AVAILABLE ENDPOINTS

### Story Generation:
- **Mock**: `POST /generate-story-mock` (instant, free)
- **Real**: `POST /generate-story` (12s, ~$0.0034)

### Avatar Generation:
- **Mock**: `POST /avatar/generate-avatar-mock` (instant, free)
- **Real**: `POST /avatar/generate-avatar` (8s, ~$0.0002)

### Illustrations:
- **Mock**: `POST /generate-illustrations-mock` (instant, free)
- **Real**: `POST /generate-illustrations` (10s, ~$0.0002)

### Coloring Pages:
- **Mock**: `POST /generate-coloring-pages-mock` (instant, free)
- **Real**: `POST /generate-coloring-pages` (10s, ~$0.0002)

### Usage Tracking:
- `GET /usage/summary?days=30` - View usage stats
- `GET /usage/daily?days=7` - Daily breakdown
- `GET /usage/mock-mode` - Check current mode

---

## 🧪 TESTING WORKFLOWS

### Development Workflow (Default):
```bash
# 1. Enable mock mode
set MOCK_TESTING_MODE=true

# 2. Make your code changes
# ... edit files ...

# 3. Run tests (unlimited, free!)
python run_phase3_tests.py
flutter test
pytest backend/tests/

# 4. Verify with manual testing
flutter run -d chrome

# 5. Check usage (should be $0.00)
curl http://localhost:5000/usage/summary

# Total Cost: $0.00
```

### Pre-Deploy Workflow:
```bash
# 1. Run full test suite in mock mode
set MOCK_TESTING_MODE=true
python run_phase3_tests.py

# 2. If all pass, run 2-3 real API tests for validation
set MOCK_TESTING_MODE=false
python -c "import requests; print(requests.post('http://localhost:5000/generate-story', json={'character': 'Test', 'age': 8, 'theme': 'Adventure'}).json())"

# 3. Check usage
curl http://localhost:5000/usage/summary

# Total Cost: ~$0.01 (1 cent)
```

---

## 💰 COST MONITORING

### Check Your Usage:
```bash
# Last 7 days
curl http://localhost:5000/usage/summary?days=7

# Last 30 days
curl http://localhost:5000/usage/summary?days=30

# Daily breakdown
curl http://localhost:5000/usage/daily?days=7
```

### Usage File Location:
- **Path**: `backend/usage_data.json`
- **Format**: JSON with all API calls
- **Retention**: Keep 90 days by default

### Cost Estimation:
The tracking service automatically estimates costs based on:
- Gemini 2.5 Flash pricing
- Token counts (actual or estimated)
- Input: $0.30 per 1M tokens
- Output: $2.50 per 1M tokens

---

## 🚨 EMERGENCY PROCEDURES

### If You Accidentally Run Real API Tests:

1. **Stop immediately**:
   ```bash
   # Press Ctrl+C to stop tests
   ```

2. **Check damage**:
   ```bash
   curl http://localhost:5000/usage/summary?days=1
   ```

3. **Re-enable mock mode**:
   ```bash
   set MOCK_TESTING_MODE=true
   ```

4. **Document what happened**:
   - How many calls were made?
   - What was the cost?
   - Why did it happen?

### If You Hit Quota Limits:

1. **Switch to mock mode immediately**:
   ```bash
   set MOCK_TESTING_MODE=true
   ```

2. **Fix the model issue** (if using experimental):
   - Edit `backend/config/__init__.py` line 23
   - Change to `gemini-2.5-flash`
   - Restart backend

3. **Wait for quota reset**:
   - Per minute: Wait 60 seconds
   - Per day: Wait until midnight UTC

---

## 📝 AGENT RESPONSIBILITIES

### Before Starting Any Task:

1. ✅ Read this rulebook
2. ✅ Check current mock mode status
3. ✅ Enable mock mode if doing testing
4. ✅ Verify backend is running
5. ✅ Check usage before and after work

### When Writing Code:

1. ✅ Add new features with mock endpoints in mind
2. ✅ Test with mock mode first
3. ✅ Only test with real API if absolutely necessary
4. ✅ Document any real API usage in commit messages

### When Committing:

Include in commit message if you used real API:
```
feat: Add new story feature

Tested with mock mode: Yes
Real API tests run: 3 (cost: ~$0.01)
Reason for real API: Verify AI response quality
```

### When Reporting Back to User:

Always mention:
- Whether you used mock or real API
- How many tests were run
- Estimated cost (if any)

Example:
```
I've completed the task! Here's what I did:
- Ran 50 tests in MOCK MODE (cost: $0.00)
- Ran 2 final tests in REAL API mode (cost: ~$0.007)
- Total estimated cost: $0.007
```

---

## 🔧 BACKEND RESTART PROCEDURE

### When Backend Needs Restart:

**After changing code, .env, or config:**

```bash
# 1. Stop current backend
# Press Ctrl+C in backend terminal

# 2. Verify it stopped
# Check terminal for "Shutting down..." message

# 3. Restart backend
python backend/app.py

# 4. Verify it started
curl http://localhost:5000/health

# 5. Check mock mode status
curl http://localhost:5000/usage/mock-mode
```

### After Restart, Verify:
- Backend health endpoint responds
- Mock mode configuration loaded correctly
- All routes registered (avatar, story, usage, etc.)

---

## 📚 KEY FILES TO KNOW

### Configuration:
- `backend/.env` - Environment variables (MOCK_TESTING_MODE, GEMINI_API_KEY)
- `backend/config/__init__.py` - Main config (line 23 has model name)

### Testing:
- `run_phase3_tests.py` - Auto-switching test script
- `test_mock_endpoints.py` - Test all mock endpoints (local only)

### Documentation:
- `COMPLETE_TESTING_SETUP_GUIDE.md` - Full setup instructions
- `MOCK_TESTING_GUIDE.md` - Mock testing details
- `IMPLEMENTATION_SUMMARY.md` - Recent changes summary
- `PROJECT_RULEBOOK.md` - THIS FILE

### Endpoints:
- `backend/routes/story_routes.py` - Story & illustration endpoints
- `backend/routes/avatar_routes.py` - Avatar endpoints
- `backend/routes/utility_routes.py` - Usage tracking endpoints

### Services:
- `backend/services/usage_tracking_service.py` - Usage tracking logic
- `backend/services/story_service.py` - Story generation
- `backend/services/avatar_generation_service.py` - Avatar generation

---

## ⚙️ RECOMMENDED CONFIGURATION

### For Development (Current State):
```bash
# backend/.env
MOCK_TESTING_MODE=true
GEMINI_MODEL=gemini-2.5-flash
GEMINI_API_KEY=REDACTED-ROTATED-KEY
```

### For Production:
```bash
# backend/.env
MOCK_TESTING_MODE=false
GEMINI_MODEL=gemini-2.5-flash
GEMINI_API_KEY=REDACTED-ROTATED-KEY
```

---

## 🎓 QUICK REFERENCE COMMANDS

### Essential Commands:

```bash
# Check mock mode
curl http://localhost:5000/usage/mock-mode

# Enable mock mode
set MOCK_TESTING_MODE=true

# Disable mock mode
set MOCK_TESTING_MODE=false

# Run tests
python run_phase3_tests.py

# Check usage
curl http://localhost:5000/usage/summary

# Test mock endpoints
python test_mock_endpoints.py

# Restart backend
python backend/app.py

# Check backend health
curl http://localhost:5000/health
```

---

## ✅ PRE-TASK CHECKLIST (Copy This!)

```
Before starting task:
[ ] Read PROJECT_RULEBOOK.md
[ ] Check mock mode: curl http://localhost:5000/usage/mock-mode
[ ] Enable mock mode: set MOCK_TESTING_MODE=true
[ ] Verify backend running: curl http://localhost:5000/health
[ ] Check current usage: curl http://localhost:5000/usage/summary

After completing task:
[ ] Run tests in mock mode
[ ] Check usage: curl http://localhost:5000/usage/summary
[ ] Report cost to user
[ ] Commit changes with cost info
```

---

## 🎯 SUMMARY FOR AGENTS

**Three Golden Rules:**

1. **ALWAYS use mock mode by default** (`set MOCK_TESTING_MODE=true`)
2. **ONLY use real API when absolutely necessary** (2-3 final validation tests)
3. **ALWAYS check and report costs** (`curl http://localhost:5000/usage/summary`)

**Remember:**
- Mock mode = FREE, instant, unlimited
- Real API = Costs money, slower, has quotas
- When in doubt, use mock mode!

---

**Last Updated**: 2025-12-26
**Rulebook Version**: 1.0
**Applies To**: All agents, developers, and CI/CD systems

---

## 📞 Need Help?

- Check `COMPLETE_TESTING_SETUP_GUIDE.md` for full setup
- Check `IMPLEMENTATION_SUMMARY.md` for recent changes
- Check backend logs in terminal for errors
- Check `backend/usage_data.json` for detailed usage history

**When in doubt: Use mock mode!** 🎯
