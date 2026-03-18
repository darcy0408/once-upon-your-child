# Agent Task Delegation Plan
**Created:** 2026-02-12
**Purpose:** Coordinate work between Claude, Codex, and Gemini agents
**Coordination File:** TEAM_COORDINATION.md

---

## 🤖 AGENT ROLES & CAPABILITIES

### Claude Sonnet 4.5 (Supervisor)
**Strengths:** Planning, architecture, complex problem-solving, coordination
**Tasks:** High-level planning, code review, integration work, complex refactoring

### Codex/Gemini (Specialist Agents)
**Strengths:** Implementation, testing, repetitive tasks, specific feature work
**Tasks:** Creating tests, implementing features, fixing bugs, documentation

---

## 📋 COORDINATION PROTOCOL

### Before Starting Work
1. **Read** `TEAM_COORDINATION.md` - Check "Current Agent Assignments" section
2. **Claim** a task by adding your name to "Current Agent Assignments"
3. **Update** with start time and status "IN PROGRESS"
4. **Check** no conflicts with other agents' work

### While Working
1. **Focus** on your assigned task only
2. **Document** progress in code comments
3. **Commit** atomically (small, focused commits)

### After Completing
1. **Update** TEAM_COORDINATION.md with "COMPLETED" status
2. **Document** what was done, files changed, test results
3. **Remove** yourself from "Current Agent Assignments"
4. **Claim** next task or wait for assignment

---

## 🎯 AVAILABLE TASKS (Prioritized)

### CRITICAL PRIORITY (Do First)

#### Task 1: Frontend Service Tests - Subscription Service
**Agent Type:** Codex or Gemini
**Time Estimate:** 2-3 hours
**Complexity:** Medium
**Files to Create:**
- `test/unit/services/subscription_service_test.dart`

**Instructions:**
```
Create comprehensive unit tests for SubscriptionSyncService.

Required Tests (15 total):
1. Subscription state management
   - Test initial state (free tier)
   - Test premium state loading
   - Test state transitions (free → premium → free)

2. Tier detection
   - Test free tier detection
   - Test premium tier detection
   - Test expired subscription handling

3. Usage tracking
   - Test story count increment
   - Test usage limit enforcement (free = 3 stories)
   - Test unlimited usage (premium)

4. API synchronization
   - Test sync from backend API
   - Test sync error handling
   - Test offline mode

5. Edge cases
   - Test null subscription data
   - Test malformed API responses
   - Test network errors

Reference Implementation:
- lib/services/subscription_sync_service.dart
- Use test/helpers/mocks.dart for mocking
- Use test/helpers/test_fixtures.dart for sample data

Success Criteria:
- All 15 tests passing
- 85%+ coverage of SubscriptionSyncService
- No new lint warnings
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 2: Frontend Service Tests - Stripe Service
**Agent Type:** Codex or Gemini
**Time Estimate:** 2 hours
**Complexity:** Medium
**Files to Create:**
- `test/unit/services/stripe_service_test.dart`

**Instructions:**
```
Create unit tests for Stripe payment service integration.

Required Tests (10 total):
1. Checkout session creation
   - Test successful session creation
   - Test session with user ID
   - Test session with metadata

2. Payment success handling
   - Test successful payment webhook
   - Test subscription activation
   - Test user tier upgrade

3. Error handling
   - Test API key missing
   - Test network errors
   - Test invalid session ID
   - Test webhook signature validation failure

Reference Implementation:
- lib/services/stripe_service.dart (if exists) or related files
- Backend reference: backend/routes/stripe_routes.py

Success Criteria:
- All 10 tests passing
- Mock Stripe API calls
- No actual API requests during tests
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 3: Frontend Service Tests - Isar Database Service
**Agent Type:** Codex or Gemini
**Time Estimate:** 2-3 hours
**Complexity:** Medium
**Files to Create:**
- `test/unit/services/isar_service_test.dart`

**Instructions:**
```
Create unit tests for Isar local database operations.

Required Tests (10 total):
1. Database initialization
   - Test database creation
   - Test schema migration

2. Character storage
   - Test save character
   - Test update character
   - Test delete character
   - Test get character by ID

3. Story persistence
   - Test save story
   - Test get all stories
   - Test delete story

4. Error handling
   - Test database errors
   - Test concurrent access

Reference Implementation:
- Look for Isar usage in lib/ (search for "Isar" or "isar")
- Use MockIsar from test/helpers/mocks.dart

Success Criteria:
- All 10 tests passing
- Mock database (no real DB created)
- Test cleanup after each test
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 4: Backend Security Tests - Authorization
**Agent Type:** Codex or Gemini
**Time Estimate:** 3-4 hours
**Complexity:** High
**Files to Create:**
- `backend/tests/security/test_authorization.py`

**Instructions:**
```
Create comprehensive authorization tests to verify users can only access their own data.

Required Tests (10 total):
1. User ownership checks
   - Test user can access own characters
   - Test user cannot access other users' characters
   - Test user can access own stories
   - Test user cannot access other users' stories

2. Cross-user access prevention
   - Test character update by wrong user (403)
   - Test character delete by wrong user (403)
   - Test story access by wrong user (403)

3. Resource ownership validation
   - Test GET /api/characters/:id requires ownership
   - Test PATCH /api/characters/:id requires ownership
   - Test DELETE /api/characters/:id requires ownership

Reference Implementation:
- backend/tests/security/test_authentication.py (existing auth tests)
- backend/tests/conftest.py (auth fixtures)
- Use free_user_headers and premium_user_headers fixtures

Success Criteria:
- All 10 tests passing
- Verify 403 Forbidden for unauthorized access
- Verify 200/204 for authorized access
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 5: Backend Security Tests - Rate Limiting
**Agent Type:** Codex or Gemini
**Time Estimate:** 3-4 hours
**Complexity:** High
**Files to Create:**
- `backend/tests/security/test_rate_limiting.py`

**Instructions:**
```
Create rate limiting tests to prevent abuse and enforce tier limits.

Required Tests (10 total):
1. Free tier limits
   - Test free user limited to 3 stories per day
   - Test 4th story returns 429 (rate limit exceeded)
   - Test rate limit resets after 24 hours

2. Premium tier unlimited
   - Test premium user can create 100+ stories
   - Test no rate limits for premium users

3. Abuse prevention
   - Test rapid requests (>10/minute) blocked
   - Test rate limit headers present
   - Test rate limit bypass attempts fail

4. API endpoint rate limiting
   - Test /generate-story rate limits
   - Test /api/characters rate limits (higher limit)

Reference Implementation:
- backend/app.py (limiter configuration)
- Look for @limiter.limit decorators
- Use Flask test client from conftest.py

Success Criteria:
- All 10 tests passing
- Verify 429 status codes
- Verify rate limit headers (X-RateLimit-*)
```

**Dependencies:** None
**Conflicts:** None

---

### HIGH PRIORITY

#### Task 6: Backend API Tests - Character Routes
**Agent Type:** Codex or Gemini
**Time Estimate:** 3-4 hours
**Complexity:** Medium
**Files to Create:**
- `backend/tests/api/test_character_routes.py`

**Instructions:**
```
Create API contract tests for all character CRUD endpoints.

Required Tests (15 total):
1. GET /api/characters (list characters)
   - Test successful list (200)
   - Test empty list
   - Test with auth headers

2. POST /api/characters (create character)
   - Test successful creation (201)
   - Test missing required fields (400)
   - Test duplicate character name
   - Test sanitization of inputs

3. GET /api/characters/:id (get one character)
   - Test successful get (200)
   - Test not found (404)
   - Test authorization (only owner can access)

4. PATCH /api/characters/:id (update character)
   - Test successful update (200)
   - Test partial update
   - Test authorization (only owner can update)
   - Test invalid data (400)

5. DELETE /api/characters/:id (delete character)
   - Test successful delete (204)
   - Test authorization (only owner can delete)
   - Test delete non-existent (404)

Reference Implementation:
- backend/routes/character_routes.py
- backend/tests/api/test_story_routes.py (pattern to follow)
- Use auth_headers, test_character fixtures

Success Criteria:
- All 15 tests passing
- Verify status codes
- Verify response formats
- Verify authorization
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 7: Fix Flutter Test Failures
**Agent Type:** Codex or Gemini
**Time Estimate:** 1-2 hours
**Complexity:** Low-Medium
**Files to Modify:**
- `lib/services/interactive_story_analytics.dart` (or similar)
- `test/widgets/wizard_flow_test.dart`
- `test/widgets/story_result_test.dart`

**Instructions:**
```
Fix 7 failing Flutter tests to achieve 100% pass rate.

Issues to Fix:

1. Firebase Analytics Parameter Type (EASY - 5 min)
   - Error: has_companion should be string/num, not bool
   - Fix: Change all `has_companion: false` to `has_companion: 0`
   - Search for: "has_companion:" in analytics logging
   - Change: false → 0, true → 1

2. Story Result Test Timeout (MEDIUM - 30-60 min)
   - File: test/widgets/story_result_test.dart
   - Issue: Test times out after 10 minutes
   - Investigate: Why is the test hanging?
   - Fix: Add timeout, mock async operations, or skip if unfixable

3. Wizard Flow Test (EASY - 10 min)
   - File: test/widgets/wizard_flow_test.dart
   - Issue: Expected text "Gaze into the Future..." not found
   - Fix: Update test expectation to match current UI text
   - Or: Update UI to match test expectation

4. Story Creation Flow Tests (MEDIUM - 30 min)
   - File: test/integration/story_creation_flow_test.dart
   - Issue: debugPrintStack assertion failures
   - Fix: Guard debugPrintStack calls in ApiServiceManager
   - Or: Mock debugPrintStack in tests

Steps:
1. Run `flutter test` to reproduce failures
2. Fix one issue at a time
3. Verify fix with `flutter test`
4. Commit each fix separately

Success Criteria:
- All 90 Flutter tests passing (100%)
- No timeouts
- No warnings
```

**Dependencies:** None
**Conflicts:** None

---

### MEDIUM PRIORITY (UI/UX Work - Continue Recent Work)

#### Task 8: Magic Review Step - Enhanced Animations
**Agent Type:** Codex or Gemini
**Time Estimate:** 2-3 hours
**Complexity:** Medium
**Files to Modify:**
- `lib/screens/wizard_steps/magic_review_step.dart`

**Instructions:**
```
Continue the Magic Review Step UI enhancements started in previous sessions.

Recent Work Completed (Feb 10-12):
- Multi-layer aura effects (3 gradient layers) ✅
- Sparkle decorations with animations ✅
- Enhanced progress crystals ✅
- Gold shimmer effects ✅

Next Enhancements to Add:

1. Floating Animation for Character Avatars
   - Add gentle up/down float animation
   - Duration: 3 seconds
   - Movement: 10-15px vertical
   - Ease: Curves.easeInOut

2. Pulsing Glow on "Cast Spell" Button
   - Add pulsing animation when ready to submit
   - Colors: Purple → Gold → Purple
   - Duration: 2 seconds
   - Repeat: infinite

3. Shimmer Effect on Toggle Buttons
   - Add shimmer when hovering/tapping
   - Use LinearGradient animation
   - Speed: 1.5 seconds per shimmer

4. Particle Trail on Orb
   - Add trailing particles around the vision orb
   - Use CustomPainter
   - 20-30 particles
   - Fade out after 1 second

Reference:
- Current implementation in lib/screens/wizard_steps/magic_review_step.dart
- Look for _ProgressCrystal, _AuraCircle widgets
- Use AnimatedBuilder and AnimationController

Success Criteria:
- Smooth 60 FPS animations
- No performance degradation
- Magical, delightful feel
- Test on both desktop and mobile
```

**Dependencies:** None
**Conflicts:** None (different file from tests)

---

#### Task 9: Story Result Screen - Enhanced Page Turn Animation
**Agent Type:** Codex or Gemini
**Time Estimate:** 3-4 hours
**Complexity:** High
**Files to Modify:**
- `lib/widgets/page_flip_book_view.dart`
- `lib/screens/story_result_screen.dart`

**Instructions:**
```
Enhance the storybook page turn animation for more realism.

Current State:
- Basic page flip exists
- PageFlipBookView widget implemented
- StoryBookPage widget with decorative corners

Enhancements to Add:

1. 3D Page Curl Effect
   - Add perspective transformation
   - Curl from corner (top-right for next, top-left for prev)
   - Use Transform.matrix4 for 3D rotation
   - Duration: 600ms

2. Shadow Under Curling Page
   - Add dynamic shadow that follows the curl
   - Shadow intensity increases with curl angle
   - Use CustomPainter for shadow

3. Page Texture
   - Add subtle paper texture overlay
   - Use opacity: 0.05
   - Parchment-style effect

4. Sound Effect Integration (Optional)
   - Add page turn sound effect
   - Trigger on page transition
   - Use audioplayers package (already in pubspec.yaml)
   - Sound file: assets/sounds/page_turn.mp3

Reference:
- Current implementation: lib/widgets/page_flip_book_view.dart
- 3D transforms: Use Matrix4.identity() and setEntry()
- Example: Flutter page flip packages for inspiration

Success Criteria:
- Realistic page turn feel
- Smooth animation (60 FPS)
- Works on all screen sizes
- No jank or stuttering
```

**Dependencies:** None
**Conflicts:** None

---

### LOW PRIORITY (Nice to Have)

#### Task 10: Backend API Tests - Subscription Routes
**Agent Type:** Codex or Gemini
**Time Estimate:** 2 hours
**Complexity:** Low-Medium
**Files to Create:**
- `backend/tests/api/test_subscription_routes.py`

**Instructions:**
```
Create API tests for subscription endpoints.

Required Tests (5 total):
1. GET /api/subscription/status
   - Test successful status retrieval
   - Test free tier response
   - Test premium tier response

2. Usage tracking
   - Test story count increments
   - Test usage limits

Reference:
- backend/routes/subscription_routes.py (if exists)
- Pattern: backend/tests/api/test_story_routes.py

Success Criteria:
- All 5 tests passing
- Verify response format
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 11: Backend API Tests - Stripe Webhook Routes
**Agent Type:** Codex or Gemini
**Time Estimate:** 2-3 hours
**Complexity:** Medium
**Files to Create:**
- `backend/tests/api/test_stripe_routes.py`

**Instructions:**
```
Create API tests for Stripe integration endpoints.

Required Tests (5 total):
1. POST /api/stripe/checkout
   - Test session creation
   - Test with user ID

2. GET /api/stripe/portal
   - Test portal link generation

3. GET /api/stripe/status
   - Test subscription status check

4. POST /api/stripe/webhook
   - Test webhook signature validation
   - Test payment success event
   - Test subscription canceled event

Reference:
- backend/routes/stripe_routes.py
- Use stripe.Webhook.construct_event for webhook testing

Success Criteria:
- All 5 tests passing
- Mock Stripe API calls
- Verify webhook signatures
```

**Dependencies:** None
**Conflicts:** None

---

#### Task 12: Documentation - API Endpoint Examples
**Agent Type:** Codex or Gemini
**Time Estimate:** 2 hours
**Complexity:** Low
**Files to Modify:**
- `API_ENDPOINTS.md`

**Instructions:**
```
Add request/response examples to API_ENDPOINTS.md.

For each endpoint, add:
1. Example request (curl command)
2. Example request body (JSON)
3. Example successful response
4. Example error response

Endpoints to Document:
- POST /generate-story
- POST /api/characters
- GET /api/characters
- PATCH /api/characters/:id
- DELETE /api/characters/:id
- GET /api/subscription/status

Format:
```bash
# Create Character
curl -X POST https://api.example.com/api/characters \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Luna",
    "age": 8,
    "gender": "Girl"
  }'

# Response (201 Created)
{
  "id": "char_123",
  "name": "Luna",
  "age": 8,
  "created_at": "2026-02-12T10:00:00Z"
}
```

Success Criteria:
- All major endpoints documented
- Examples tested and working
- Clear, copy-paste ready
```

**Dependencies:** None
**Conflicts:** None

---

## 🔄 TASK ASSIGNMENT TEMPLATE

When claiming a task, add this to TEAM_COORDINATION.md under "Current Agent Assignments":

```markdown
### [Agent Name] - [Task Number]: [Task Title]
**Status:** IN PROGRESS
**Started:** [Date/Time]
**Estimated Completion:** [Date/Time]
**Files Working On:**
- file1.dart
- file2.py

**Notes:**
- [Any important notes or blockers]
```

When completing, update to:

```markdown
### [Agent Name] - [Task Number]: [Task Title]
**Status:** ✅ COMPLETED
**Started:** [Date/Time]
**Completed:** [Date/Time]
**Files Modified:**
- file1.dart (added 50 lines)
- file2.py (added 100 lines)

**Results:**
- [Tests passing: X/X]
- [Coverage: X%]
- [Commits: abc123, def456]

**Next Agent:**
- Review and integrate changes
- Run full test suite
```

---

## 📊 PROGRESS TRACKING

### Tests Created by Agents
- [ ] Task 1: Subscription Service Tests (0/15)
- [ ] Task 2: Stripe Service Tests (0/10)
- [ ] Task 3: Isar Service Tests (0/10)
- [ ] Task 4: Authorization Tests (0/10)
- [ ] Task 5: Rate Limiting Tests (0/10)
- [ ] Task 6: Character Routes Tests (0/15)
- [ ] Task 10: Subscription Routes Tests (0/5)
- [ ] Task 11: Stripe Routes Tests (0/5)

**Total:** 0/80 new tests created

### UI Enhancements by Agents
- [ ] Task 8: Magic Review Step Animations
- [ ] Task 9: Page Turn Animation

### Bug Fixes by Agents
- [ ] Task 7: Flutter Test Failures (7 fixes needed)

---

## ⚠️ IMPORTANT RULES

### DO NOT:
1. ❌ Work on uncommitted changes in TEAM_COORDINATION.md
2. ❌ Modify files another agent is working on
3. ❌ Change core architecture without supervisor approval
4. ❌ Skip test creation for new features
5. ❌ Commit without running tests
6. ❌ Work on multiple tasks simultaneously

### DO:
1. ✅ Read TEAM_COORDINATION.md before starting
2. ✅ Update TEAM_COORDINATION.md when claiming task
3. ✅ Run tests before committing
4. ✅ Write clear commit messages
5. ✅ Document what you changed
6. ✅ Ask for help if blocked

---

## 🎯 RECOMMENDED TASK ORDER

### For Maximum Efficiency (Parallel Work):

**Agent 1 (Codex):**
1. Task 1: Subscription Service Tests (2-3 hours)
2. Task 4: Authorization Tests (3-4 hours)
3. Task 8: Magic Review Animations (2-3 hours)

**Agent 2 (Gemini):**
1. Task 2: Stripe Service Tests (2 hours)
2. Task 5: Rate Limiting Tests (3-4 hours)
3. Task 7: Fix Flutter Tests (1-2 hours)

**Agent 3 (Codex or Gemini):**
1. Task 3: Isar Service Tests (2-3 hours)
2. Task 6: Character Routes Tests (3-4 hours)
3. Task 9: Page Turn Animation (3-4 hours)

**Total Parallel Time:** ~8-12 hours (instead of 24-36 hours sequential)

---

## 📞 ESCALATION

### If Blocked:
1. Update TEAM_COORDINATION.md with blocker details
2. Mark status as "BLOCKED"
3. Move to next available task
4. Wait for supervisor (Claude) to review

### If Tests Failing:
1. Document the failures in TEAM_COORDINATION.md
2. Include error messages
3. List what you tried
4. Request supervisor review

### If Unclear Instructions:
1. Do NOT guess or make assumptions
2. Mark task as "NEEDS CLARIFICATION"
3. Document specific questions
4. Wait for supervisor response

---

**Last Updated:** 2026-02-12
**Next Review:** Daily
**Maintained By:** Claude Sonnet 4.5 (Supervisor)
