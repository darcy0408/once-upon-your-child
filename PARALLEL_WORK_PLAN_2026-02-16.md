# Parallel Work Plan - Multi-Agent Task Distribution
**Created:** 2026-02-16
**Target:** Complete remaining 75 tests + security hardening in 2-3 weeks
**Agents:** Claude Sonnet 4.5 (Supervisor), Codex Agent, Gemini Agent

---

## 🎯 **STRATEGY: Divide & Conquer**

The remaining work is divided into **3 parallel tracks** that can be executed simultaneously:
- **Track A (Backend):** API tests, security, performance
- **Track B (Frontend):** Screen tests, service tests, widgets
- **Track C (Integration):** End-to-end flows, manual testing

Each track is assigned to a different agent to maximize throughput.

---

## 📋 **TRACK A: Backend Tests & Security**
**Agent:** Gemini Agent
**Estimated Time:** 14-18 hours
**Priority:** HIGH (blocking security)

### **Phase 1: Backend Integration Tests** (8-10 hours)
**Location:** Create `backend/tests/integration/`

#### Task A1: Age Group Integration Tests (4 hours)
**File:** `backend/tests/integration/test_age_groups.py`
```python
# Test story generation for each age band
# 15 tests total (3 per age: 4, 7, 9, 12, 16)
```
**Tests:**
- [ ] Generate story for age 4 (300-500 words expected)
- [ ] Generate story for age 7 (500-800 words expected)
- [ ] Generate story for age 9 (800-1200 words expected)
- [ ] Generate story for age 12 (1200-1600 words expected)
- [ ] Generate story for age 16 (1600-2000 words expected)
- [ ] Verify vocabulary matches age band
- [ ] Verify word count matches expectations
- [ ] Verify complexity matches age
- [ ] Verify no inappropriate content
- [ ] Test consistency (3 stories per age)

#### Task A2: Story Duration Tests (2 hours)
**File:** `backend/tests/integration/test_story_durations.py`
```python
# Test story lengths and reading times
# 9 tests total
```
**Tests:**
- [ ] Quick stories: 300-500 words (3-5 min read)
- [ ] Standard stories: 800-1200 words (8-12 min read)
- [ ] Epic stories: 1500-2000 words (15-20 min read)
- [ ] Verify reading time calculations
- [ ] Test across different age groups (3 tests)
- [ ] Verify pagination (page count based on length)

#### Task A3: Feature Integration Tests (2 hours)
**File:** `backend/tests/integration/test_features.py`
```python
# Test all features work together
# 7 tests total
```
**Tests:**
- [ ] Test archetype integration (6 archetypes)
- [ ] Test companion integration (6 companions)
- [ ] Test custom elements inclusion
- [ ] Test mood physics system
- [ ] Test therapeutic prompts
- [ ] Test rhyme time mode
- [ ] Test illustration generation

### **Phase 2: Security Hardening** (4-6 hours)

#### Task A4: Token Refresh Flow Implementation (3 hours)
**Files:**
- `backend/routes/auth_routes.py` (create if needed)
- `backend/tests/security/test_token_refresh.py`

**Implementation:**
- [ ] Create `/auth/refresh` endpoint
- [ ] Add refresh token storage (database table)
- [ ] Implement token rotation
- [ ] Add expiry handling
- [ ] Write 8 tests for refresh flow

#### Task A5: Advanced Authorization Tests (2 hours)
**File:** `backend/tests/security/test_advanced_authorization.py`

**Tests (15 total):**
- [ ] Admin vs user permissions (5 tests)
- [ ] Resource-level permissions (5 tests)
- [ ] Cross-tenant isolation (3 tests)
- [ ] Privilege escalation prevention (2 tests)

#### Task A6: Security Headers Implementation (1 hour)
**Files:**
- `backend/middleware/security_headers.py`
- `backend/tests/security/test_security_headers.py`

**Tests (3 tests):**
- [ ] Content Security Policy (CSP)
- [ ] X-Frame-Options
- [ ] X-Content-Type-Options

### **Phase 3: Performance Tests** (2-3 hours)

#### Task A7: Performance Benchmarks (3 hours)
**File:** `backend/tests/performance/test_benchmarks.py`

**Tests (10 total):**
- [ ] Story generation < 20s (95th percentile)
- [ ] Character creation < 1s
- [ ] Character list < 500ms
- [ ] Story save < 500ms
- [ ] Image generation < 15s
- [ ] 10 concurrent users
- [ ] 50 concurrent users
- [ ] 100 concurrent users
- [ ] Memory leak detection
- [ ] Database connection pooling

---

## 📋 **TRACK B: Frontend Tests**
**Agent:** Codex Agent
**Estimated Time:** 12-16 hours
**Priority:** HIGH (user-facing)

### **Phase 1: Frontend Screen Tests** (6-8 hours)

#### Task B1: Wizard Step Tests (4 hours)
**Location:** `test/widgets/wizard_steps/`

**Files to create:**
- `hero_creator_step_test.dart` (3 tests)
- `companion_selector_step_test.dart` (3 tests)
- `magic_review_step_test.dart` (4 tests)

**Tests (10 total):**
- [ ] Hero creator: Avatar selection
- [ ] Hero creator: Name input validation
- [ ] Hero creator: Age selection
- [ ] Companion: Companion grid display
- [ ] Companion: Companion selection
- [ ] Companion: Empty state
- [ ] Magic review: Mode selection
- [ ] Magic review: Length selection
- [ ] Magic review: Make Magic button
- [ ] Magic review: Navigation controls

#### Task B2: Settings Screen Tests (2 hours)
**File:** `test/screens/settings_screen_test.dart`

**Tests (5 total):**
- [ ] Theme toggle (light/dark)
- [ ] Reading settings (font size, speed)
- [ ] Account settings display
- [ ] Subscription management navigation
- [ ] Logout functionality

#### Task B3: Character Library Tests (2 hours)
**File:** `test/screens/character_library_test.dart`

**Tests (5 total):**
- [ ] Character list display
- [ ] Character creation navigation
- [ ] Character edit navigation
- [ ] Character delete confirmation
- [ ] Empty state display

#### Task B4: Story Reader Tests (2 hours)
**File:** `test/screens/story_reader_test.dart`

**Tests (5 total):**
- [ ] Typewriter animation
- [ ] Page navigation (prev/next)
- [ ] Audio ambience toggle
- [ ] High contrast mode
- [ ] Share story functionality

#### Task B5: Coloring Screen Tests (2 hours)
**File:** `test/screens/coloring_screen_test.dart`

**Tests (5 total):**
- [ ] Image loading
- [ ] Color palette display
- [ ] Color application
- [ ] Save colored image
- [ ] Share colored image

### **Phase 2: Additional Service Tests** (4-6 hours)

#### Task B6: Avatar Service Tests (3 hours)
**File:** `test/unit/services/avatar_service_test.dart`

**Tests (10 total):**
- [ ] Curated avatar loading
- [ ] Avatar filtering by age
- [ ] Avatar filtering by skin tone
- [ ] Avatar filtering by hair color
- [ ] Avatar selection
- [ ] Generated avatar handling
- [ ] Avatar metadata parsing
- [ ] Error handling (network)
- [ ] Error handling (invalid data)
- [ ] Cache management

#### Task B7: Analytics Service Tests (2 hours)
**File:** `test/unit/services/analytics_service_test.dart`

**Tests (5 total):**
- [ ] Event logging
- [ ] User tracking
- [ ] Story analytics
- [ ] Feature usage tracking
- [ ] Error tracking

#### Task B8: Achievement Service Tests (1 hour)
**File:** `test/unit/services/achievement_service_test.dart`

**Tests (5 total):**
- [ ] Achievement unlocking
- [ ] Progress tracking
- [ ] Badge awarding
- [ ] Milestone detection
- [ ] Notification triggers

### **Phase 3: Cross-Browser Testing** (2-3 hours)

#### Task B9: Browser Compatibility Tests (3 hours)
**Location:** `test/integration/browser/`

**Manual Test Matrix:**
- [ ] Chrome Windows (story creation + reading)
- [ ] Chrome Mac (story creation + reading)
- [ ] Firefox Windows (story creation + reading)
- [ ] Safari Mac (story creation + reading)
- [ ] Edge Windows (story creation + reading)
- [ ] iOS Safari (responsive layout)
- [ ] Chrome Mobile Android (responsive layout)

**Document results in:** `BROWSER_COMPATIBILITY_REPORT.md`

---

## 📋 **TRACK C: Integration & Quality**
**Agent:** Claude Sonnet 4.5 (Supervisor)
**Estimated Time:** 8-12 hours
**Priority:** MEDIUM (validation)

### **Phase 1: Pick-A-Path Integration** (3-4 hours)

#### Task C1: Interactive Story Flow Tests (4 hours)
**File:** `test/integration/pick_a_path_test.dart` (enhance existing)

**Tests (5 total):**
- [ ] Create interactive story
- [ ] Display first segment with choices
- [ ] Select choice and continue
- [ ] Navigate through branching paths
- [ ] Reach story completion
- [ ] Test maximum depth limits
- [ ] Verify choice persistence

**Backend equivalent:** `backend/tests/integration/test_pick_a_path.py`
- [ ] API contract for interactive stories
- [ ] Segment generation consistency
- [ ] Choice validation
- [ ] State persistence

### **Phase 2: Content Quality Manual Verification** (4-6 hours)

#### Task C2: Story Quality Checklist (6 hours)
**Location:** Create `STORY_QUALITY_VERIFICATION_2026-02-16.md`

**Process:**
1. Generate 15 test stories (3 per age: 4, 7, 9, 12, 16)
2. For each story, verify:
   - [ ] 3+ senses per scene (touch, smell, sound, taste, sight)
   - [ ] One impossible element at climax
   - [ ] Protagonist solves own problem
   - [ ] Companion uses special skill
   - [ ] No passive voice or clichés
   - [ ] Distinct companion voices
   - [ ] Warm glow ending
   - [ ] Custom elements included (if provided)
3. Document results with scores
4. Identify patterns in failures
5. Adjust prompts if needed

#### Task C3: Accessibility Testing (2 hours)
**File:** `test/accessibility/accessibility_test.dart`

**Tests (10 total):**
- [ ] Screen reader labels (5 tests)
- [ ] Keyboard navigation (3 tests)
- [ ] Color contrast validation (1 test)
- [ ] Font scaling (1 test)

### **Phase 3: Deployment Preparation** (2-3 hours)

#### Task C4: Production Environment Setup (3 hours)
**Files to create/update:**
- `DEPLOYMENT_CHECKLIST.md`
- `PRODUCTION_RUNBOOK.md`
- `.env.production.example`

**Tasks:**
- [ ] Document environment variables
- [ ] Create database migration scripts
- [ ] Document backup procedures
- [ ] Document recovery procedures
- [ ] Set up monitoring alerts
- [ ] Configure error tracking
- [ ] Test production build locally

---

## 📊 **COORDINATION & CHECKPOINTS**

### **Daily Standup (Async)**
Each agent updates `TEAM_COORDINATION.md` with:
- **Morning:** What I'm working on today
- **Evening:** What I completed, any blockers

### **Weekly Checkpoint (Claude Review)**
Every Friday, Claude reviews:
- Test coverage progress
- Integration between tracks
- Blocking issues
- Next week priorities

### **Conflict Prevention**
- **File Ownership:** Each agent owns specific files (no overlap)
- **Database Schema:** Only Claude modifies database models
- **Shared Files:** Use atomic commits with clear messages

---

## 🎯 **MILESTONES & DEADLINES**

### **Week 1 (Feb 16-23): Foundation**
- **Track A:** Complete age group + duration tests (15 tests)
- **Track B:** Complete wizard step tests (10 tests)
- **Track C:** Complete Pick-A-Path integration (5 tests)
- **Target:** +30 tests, 60% → 65% coverage

### **Week 2 (Feb 23-Mar 2): Expansion**
- **Track A:** Complete security hardening + performance (25 tests)
- **Track B:** Complete screen tests + avatar service (25 tests)
- **Track C:** Complete quality verification + accessibility (10 tests)
- **Target:** +60 tests, 65% → 75% coverage

### **Week 3 (Mar 2-9): Polish & Launch**
- **Track A:** Final security audit
- **Track B:** Cross-browser testing
- **Track C:** Deployment preparation
- **Target:** Launch-ready (75%+ coverage)

---

## 📝 **AGENT-SPECIFIC INSTRUCTIONS**

### **For Gemini Agent (Track A - Backend)**

1. **Setup:**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # or venv\Scripts\activate on Windows
   pip install -r requirements.txt
   ```

2. **Test Framework:**
   ```python
   # Use pytest with fixtures from conftest.py
   # Run tests: pytest tests/integration -v
   # Check coverage: pytest --cov=backend tests/
   ```

3. **Coordination:**
   - Update TEAM_COORDINATION.md after each task
   - Run full test suite before committing
   - Use atomic commits (one feature per commit)

### **For Codex Agent (Track B - Frontend)**

1. **Setup:**
   ```bash
   flutter pub get
   flutter test --help  # Familiarize with test commands
   ```

2. **Test Framework:**
   ```dart
   // Use flutter_test with mocktail for mocking
   // Run tests: flutter test test/unit/services
   // Run specific: flutter test test/screens/settings_screen_test.dart
   ```

3. **Coordination:**
   - Update TEAM_COORDINATION.md after each task
   - Run `flutter analyze` before committing
   - Ensure no test regressions

### **For Claude (Track C - Supervisor)**

1. **Responsibilities:**
   - Review PRs from Codex/Gemini
   - Resolve conflicts
   - Make architectural decisions
   - Coordinate between tracks

2. **Review Checklist:**
   - [ ] Tests are comprehensive
   - [ ] No duplicate coverage
   - [ ] Follows project patterns
   - [ ] Documentation updated

---

## 🚀 **GETTING STARTED**

### **Immediate Actions (Today)**

**Gemini Agent:**
```bash
# Start with Task A1: Age Group Integration Tests
cd backend
pytest tests/integration/test_age_groups.py -v
```

**Codex Agent:**
```bash
# Start with Task B1: Wizard Step Tests
flutter test test/widgets/wizard_steps/hero_creator_step_test.dart
```

**Claude:**
```bash
# Start with Task C1: Pick-A-Path Integration Tests
flutter test test/integration/pick_a_path_test.dart
```

### **Communication Protocol**

**Questions/Blockers:**
- Post in TEAM_COORDINATION.md under "Blockers" section
- Tag with agent name and urgency (HIGH/MEDIUM/LOW)
- Claude will respond within 4 hours

**Completed Work:**
- Update TEAM_COORDINATION.md with completion notes
- Include test results (X/X passing)
- Mention any follow-up needed

---

## 📈 **SUCCESS METRICS**

### **Coverage Targets**
- **Week 1:** 503 → 533 tests (+30)
- **Week 2:** 533 → 593 tests (+60)
- **Week 3:** 593 → 620 tests (+27 polish)
- **Final:** 620+ tests, 75%+ coverage

### **Quality Metrics**
- [ ] 100% test pass rate
- [ ] Zero critical security vulnerabilities
- [ ] All CI/CD pipelines green
- [ ] Cross-browser compatible
- [ ] Accessibility compliant

### **Velocity Tracking**
Track daily test additions in TEAM_COORDINATION.md:
```
Daily Progress:
- Feb 16: +0 (CI fixes)
- Feb 17: +15 (age groups)
- Feb 18: +10 (wizard steps)
...
```

---

## ⚠️ **RISK MITIGATION**

### **If Behind Schedule**
1. **Prioritize Track A** (backend security - most critical)
2. **Defer Track C** (quality verification - can be done post-launch)
3. **Parallelize within tracks** (e.g., Gemini splits A1/A2)

### **If Tests Fail**
1. **Don't commit broken tests**
2. **Document failure in TEAM_COORDINATION.md**
3. **Tag Claude for architectural review**

### **If Conflicts Arise**
1. **Stop work on conflicting file**
2. **Post in TEAM_COORDINATION.md**
3. **Wait for Claude to resolve**
4. **Pull latest before resuming**

---

## 🎓 **BEST PRACTICES**

### **Test Writing**
- Use descriptive test names: `test_story_generation_for_age_4_returns_300_to_500_words`
- Include setup/teardown for clean state
- Mock external dependencies (AI, Stripe, etc.)
- Test both happy path and error cases

### **Commits**
- Small, atomic commits
- Clear commit messages following project style
- Run tests before pushing
- Include "Co-Authored-By: [Agent]" in message

### **Documentation**
- Update TEAM_COORDINATION.md daily
- Document assumptions and decisions
- Link to related issues/PRs
- Keep README up to date

---

*Plan created by Claude Sonnet 4.5*
*Target completion: March 9, 2026*
*Estimated total effort: 34-46 hours across 3 agents (1.5-2 weeks with parallel work)*
