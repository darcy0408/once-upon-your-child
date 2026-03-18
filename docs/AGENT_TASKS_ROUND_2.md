# Agent Tasks - Round 2
**Created:** 2026-02-12, 8:45 PM
**For:** Codex and Gemini agents after completing Round 1

---

## 📊 ROUND 1 STATUS

### Completed
- ✅ Task 1 (Codex): Subscription Service Tests - 15 tests passing

### In Progress
- 🔄 Task 4 (Codex): Authorization Tests - ~10 tests expected
- 🔄 Task 7 (Gemini): Fix Flutter Test Failures - 7 fixes expected

### Expected After Round 1
- 32 total tests improved/created
- 100% Flutter test pass rate (90/90)
- Critical authorization security coverage

---

## 🎯 ROUND 2 TASKS (Prioritized)

### CRITICAL PRIORITY - Security & Test Infrastructure

#### Task 5: Rate Limiting Tests (3-4 hours) - CRITICAL SECURITY
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `backend/tests/security/test_rate_limiting.py` (NEW)

```
Create rate limiting tests to prevent abuse and enforce tier limits.

Required Tests (10 total):
1. Free tier limits (3 stories per day)
2. 4th story returns 429 (rate limit exceeded)
3. Rate limit resets after 24 hours
4. Premium user unlimited stories
5. Premium user 100+ stories test
6. Rapid requests blocked (>10/minute)
7. Rate limit headers present
8. Rate limit bypass attempts fail
9. /generate-story endpoint rate limits
10. /api/characters rate limits

Reference:
- backend/app.py (limiter configuration)
- backend/tests/security/test_authentication.py (pattern)

Success Criteria:
- 10/10 tests passing
- Verify 429 status codes
- Verify X-RateLimit-* headers
```

---

#### Task 13: Fix test_fixtures.dart (1-2 hours) - HIGH VALUE
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `test/helpers/test_fixtures.dart` (FIX)

```
Fix 32 compilation errors in test_fixtures.dart.

Issue: Models don't exist at expected import paths.

Steps:
1. Find actual model locations:
   - grep -r "class Character" lib/
   - grep -r "class.*Story" lib/
   - grep -r "class GeneratedAvatar" lib/

2. Update imports to correct paths

3. Fix GeneratedAvatar constructor (required params changed)

4. Fix Character, Story, InteractiveStoryData constructors

5. Verify: dart analyze test/helpers/test_fixtures.dart → 0 errors

Success Criteria:
- 0 compilation errors
- All imports resolve
- Future tests can use shared fixtures
```

---

### HIGH PRIORITY - API Contract Tests

#### Task 6: Character Routes API Tests (3-4 hours)
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `backend/tests/api/test_character_routes.py` (NEW)

```
Create API contract tests for character CRUD endpoints.

Required Tests (15 total):

GET /api/characters (3 tests):
1. Successful list (200)
2. Empty list
3. With auth headers

POST /api/characters (4 tests):
4. Successful creation (201)
5. Missing required fields (400)
6. Duplicate character name
7. Input sanitization

GET /api/characters/:id (3 tests):
8. Successful get (200)
9. Not found (404)
10. Authorization check (only owner)

PATCH /api/characters/:id (3 tests):
11. Successful update (200)
12. Partial update
13. Authorization check

DELETE /api/characters/:id (2 tests):
14. Successful delete (204)
15. Authorization check

Reference:
- backend/routes/character_routes.py
- backend/tests/api/test_story_routes.py (pattern)
- backend/tests/conftest.py (fixtures)

Success Criteria:
- 15/15 tests passing
- All status codes verified
- Authorization enforced
```

---

#### Task 10: Subscription Routes Tests (2 hours)
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `backend/tests/api/test_subscription_routes.py` (NEW)

```
Create API tests for subscription endpoints.

Required Tests (5 total):

GET /api/subscription/status (3 tests):
1. Successful status retrieval
2. Free tier response format
3. Premium tier response format

Usage Tracking (2 tests):
4. Story count increments correctly
5. Usage limits enforced

Reference:
- backend/routes/subscription_routes.py (if exists)
- backend/tests/api/test_story_routes.py (pattern)

Success Criteria:
- 5/5 tests passing
- Response formats verified
```

---

#### Task 11: Stripe Routes Tests (2-3 hours)
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `backend/tests/api/test_stripe_routes.py` (NEW)

```
Create API tests for Stripe integration endpoints.

Required Tests (5 total):

POST /api/stripe/checkout (2 tests):
1. Session creation successful
2. Session with user ID

GET /api/stripe/portal (1 test):
3. Portal link generation

GET /api/stripe/status (1 test):
4. Subscription status check

POST /api/stripe/webhook (1 test):
5. Webhook signature validation

Reference:
- backend/routes/stripe_routes.py
- Mock Stripe API calls (no real requests)

Success Criteria:
- 5/5 tests passing
- All Stripe calls mocked
- Webhook signatures verified
```

---

### MEDIUM PRIORITY - Frontend Service Tests

#### Task 2: Stripe Service Tests (2 hours)
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `test/unit/services/stripe_service_test.dart` (NEW)

```
Create unit tests for Stripe service (frontend).

⚠️ Use inline fixtures (test_fixtures.dart is broken)
✅ Follow Codex's pattern from Task 1

Required Tests (10 total):
- Checkout session creation (3 tests)
- Payment success handling (3 tests)
- Error handling (4 tests)

Inline Fixtures Example:
Map<String, dynamic> _checkoutSuccessFixture() {
  return {'id': 'cs_test_123', 'url': 'https://...'};
}

Success Criteria:
- 10/10 tests passing
- Mock all Stripe API calls
- No dependency on test_fixtures.dart
```

---

#### Task 3: Isar Service Tests (2-3 hours)
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `test/unit/services/isar_service_test.dart` (NEW)

```
Create unit tests for Isar database service.

⚠️ Use inline fixtures (test_fixtures.dart is broken)
✅ Follow Codex's pattern from Task 1

Required Tests (10 total):
- Database initialization (2 tests)
- Character storage (4 tests)
- Story persistence (3 tests)
- Error handling (1 test)

Use MockIsar from test/helpers/mocks.dart

Success Criteria:
- 10/10 tests passing
- Mock database (no real DB)
- No dependency on test_fixtures.dart
```

---

### LOW PRIORITY - Documentation & Optimization

#### Task 12: API Documentation Examples (2 hours)
**Assigned to:** Next available agent
**Dependencies:** None
**Files:** `API_ENDPOINTS.md` (UPDATE)

```
Add request/response examples to API_ENDPOINTS.md.

For each endpoint, add:
1. curl command example
2. Request body JSON
3. Success response example
4. Error response example

Endpoints to Document:
- POST /generate-story
- POST /api/characters
- GET /api/characters
- PATCH /api/characters/:id
- DELETE /api/characters/:id
- GET /api/subscription/status
- POST /api/stripe/checkout

Success Criteria:
- All examples tested and working
- Clear, copy-paste ready
- Covers success and error cases
```

---

#### Task 14: Backend Test Coverage Report (1 hour)
**Assigned to:** Next available agent
**Dependencies:** All backend tests complete
**Files:** `BACKEND_COVERAGE_REPORT.md` (NEW)

```
Generate comprehensive coverage report for backend.

Steps:
1. Run: cd backend && pytest --cov=. --cov-report=html --cov-report=term
2. Analyze coverage by module
3. Document coverage gaps
4. Create BACKEND_COVERAGE_REPORT.md with:
   - Overall coverage %
   - Coverage by module
   - Uncovered lines
   - Recommendations for additional tests

Success Criteria:
- Coverage report generated
- Target: 75%+ overall coverage
- Gaps identified and documented
```

---

#### Task 15: Frontend Test Coverage Report (1 hour)
**Assigned to:** Next available agent
**Dependencies:** All frontend tests complete
**Files:** `FRONTEND_COVERAGE_REPORT.md` (NEW)

```
Generate comprehensive coverage report for frontend.

Steps:
1. Run: flutter test --coverage
2. Generate HTML: genhtml coverage/lcov.info -o coverage/html
3. Analyze coverage by module
4. Create FRONTEND_COVERAGE_REPORT.md

Success Criteria:
- Coverage report generated
- Target: 50%+ overall coverage
- Gaps identified
```

---

## 📋 RECOMMENDED ASSIGNMENT ORDER

### For Codex (after Task 4 completes):
1. **Task 5** - Rate Limiting Tests (CRITICAL SECURITY - 3-4 hours)
2. **Task 6** - Character Routes Tests (HIGH VALUE - 3-4 hours)
3. **Task 11** - Stripe Routes Tests (MEDIUM - 2-3 hours)

**Total:** ~9-11 hours of high-value security and API work

### For Gemini (after Task 7 completes):
1. **Task 13** - Fix test_fixtures.dart (HIGH IMPACT - 1-2 hours)
2. **Task 2** - Stripe Service Tests (MEDIUM - 2 hours)
3. **Task 3** - Isar Service Tests (MEDIUM - 2-3 hours)
4. **Task 10** - Subscription Routes Tests (LOW - 2 hours)

**Total:** ~7-9 hours of test infrastructure and service tests

---

## 🎯 EXPECTED OUTCOMES - Round 2

### Tests Created
- Task 2: 10 Stripe service tests
- Task 3: 10 Isar service tests
- Task 5: 10 rate limiting tests
- Task 6: 15 character routes tests
- Task 10: 5 subscription routes tests
- Task 11: 5 Stripe routes tests
- **Total: 55 new tests**

### Infrastructure Fixed
- Task 13: test_fixtures.dart working (unblocks future tests)

### Documentation
- Task 12: API examples complete
- Task 14: Backend coverage report
- Task 15: Frontend coverage report

### Combined with Round 1
- Round 1: 32 tests
- Round 2: 55 tests
- **Total: 87 tests created/fixed**
- **Progress: 87/101 remaining = 86% of Phase 1 complete!**

---

## ⏱️ TIMELINE ESTIMATE

### If Both Agents Work in Parallel
- **Round 1:** 3-4 hours (in progress)
- **Round 2:** 9-11 hours (parallel execution)
- **Total:** 12-15 hours

### Sequential Would Take
- **Round 1:** 6-9 hours
- **Round 2:** 18-22 hours
- **Total:** 24-31 hours

**Parallel Speedup:** ~2x faster (saving 12-16 hours!)

---

## 🚀 AFTER ROUND 2

### Remaining Work for Phase 1
- Only ~14 tests left to reach 270 target
- Can be picked up in Round 3 or ad-hoc
- Or skip if 256/270 tests (95%) is acceptable

### Move to Phase 2: Integration Testing
- Manual age group testing
- Pick-A-Path testing
- Story duration testing
- Cross-browser testing

### Or Focus on Launch Prep
- Performance testing
- Security audit
- Production deployment
- Monitoring setup

---

## 📞 COORDINATION

### When Agents Finish Round 1
1. They update TEAM_COORDINATION.md
2. They check this file (AGENT_TASKS_ROUND_2.md)
3. They pick next task from "Recommended Assignment Order"
4. They claim it in TEAM_COORDINATION.md
5. Repeat!

### Self-Coordinating System
- Agents work independently
- Update TEAM_COORDINATION.md in real-time
- No conflicts (different files)
- Claude (you) reviews when convenient

---

**Created:** 2026-02-12, 8:45 PM
**Maintained By:** Claude Sonnet 4.5
**Status:** Ready for Round 2 deployment
