# Story Weaver: Function-First Deployment Plan
**Philosophy:** Make it work → Make it secure → Make it profitable → Make it magical

## Current Broken Features (Must Fix First)

Based on testing and user reports:

1. ❌ **Stack Overflow** - Age gate causes app crash
2. ❌ **Interactive Stories** - Shows "end story here" and code snippets instead of choices
3. ❌ **Character Avatars** - Generic icons due to CORS (avataaars.io blocked)
4. ❌ **Story Images (DALL-E)** - Has never worked
5. ⚠️ **Age Range** - Limited to 3-17 (should be 3-99)
6. ⚠️ **Stripe Webhook** - Missing (subscriptions don't work automatically)
7. ⚠️ **Security** - Authorization holes, weak secrets, unprotected admin endpoints

---

# 3-WEEK PLAN: Function → Security → Revenue → Magic

## WEEK 1: MAKE IT WORK (Fix All Broken Features)

### Day 1: Critical Bug Fixes (Core Functionality)

#### Agent 1 (Backend)
**Priority 1: Fix Interactive Stories (2-3 hours)**
- [ ] Review interactive story generation endpoint
- [ ] Check prompt engineering - is it returning code instead of choices?
- [ ] Test with simple prompt to verify endpoint works
- [ ] Add logging to see exact API response
- [ ] Fix parsing of choices from Gemini response
- [ ] Test: Generate interactive story, verify choices appear
- [ ] Document what was broken and fix

**Priority 2: Diagnose Image Generation (1-2 hours)**
- [ ] Check if `OPENAI_API_KEY` set in Railway environment
- [ ] Test API key with curl (verify it works)
- [ ] Check backend logs for DALL-E errors
- [ ] Add comprehensive logging to image generation
- [ ] Document findings in `IMAGE_GENERATION_DIAGNOSIS.md`

#### Agent 2 (Frontend)
**Priority 1: Fix Avatar Display (30 minutes)**
- [ ] Read current `lib/avatar_models.dart` implementation
- [ ] Change line 67 from `avataaars.io` to `api.dicebear.com/7.x/avataaars/svg`
- [ ] Test: Create character, customize, verify avatar changes
- [ ] Verify avatar shows in character selection screen
- [ ] **CRITICAL:** This is a 1-line change that fixes visual feedback

**Priority 2: Verify Interactive Story UI (1 hour)**
- [ ] Test current interactive story flow
- [ ] Document exact error (screenshot of code showing)
- [ ] Verify UI is correctly parsing backend response
- [ ] Check if issue is backend (wrong format) or frontend (wrong parsing)
- [ ] Document findings for Agent 1

#### Agent 3 (QA/Integration)
**Testing & Coordination (Full Day)**
- [ ] Test current interactive stories - document exact error
- [ ] Create test character - verify avatar shows as generic icon
- [ ] Try to generate story with image - document failure
- [ ] Test age gate - try to trigger Stack Overflow
- [ ] Coordinate between Agent 1 & 2 on interactive story bug
- [ ] After Agent 2 deploys avatar fix, verify avatars work
- [ ] After Agent 1 fixes interactive stories, test end-to-end
- [ ] Document all findings

**Success Criteria for Day 1:**
- ✅ Avatars display custom characters (not generic icons)
- ✅ Interactive stories show choices (not code)
- ✅ Understand why image generation doesn't work
- ✅ All critical bugs documented

---

### Day 2: Fix Image Generation & Stack Overflow

#### Agent 1 (Backend)
**Priority: Get Image Generation Working (3-4 hours)**
- [ ] Based on Day 1 diagnosis, fix root cause:
  - If API key missing: Set in Railway environment
  - If no credits: Add credits to OpenAI account
  - If error handling issue: Fix error logging
  - If cost tracking blocking: Adjust limits
- [ ] Test image generation locally
- [ ] Deploy fix to production
- [ ] Test: Generate 3 stories with images in production
- [ ] **PROOF:** 3 working story illustrations
- [ ] Document fix in `IMAGE_GENERATION_FIX.md`

#### Agent 2 (Frontend)
**Priority: Fix Stack Overflow in Age Gate (3-4 hours)**
- [ ] Set up Flutter DevTools
- [ ] Add extensive logging to age gate screen
- [ ] Add logging to main.dart age gate → app transition
- [ ] Reproduce Stack Overflow
- [ ] Identify widget causing infinite rebuild
- [ ] Implement fix (likely setState loop or circular dependency)
- [ ] Remove temporary age gate bypass
- [ ] Test: Ages 4, 9, 13, 17 all work without crash
- [ ] Test parental consent flow for under-13
- [ ] Document fix in `STACK_OVERFLOW_FIX.md`

#### Agent 3 (QA/Integration)
**Verification (Full Day)**
- [ ] Test image generation after Agent 1 deploys
- [ ] Verify images: Match story content, load correctly, saveable
- [ ] Test age gate after Agent 2 fixes Stack Overflow
- [ ] Test all age ranges: 3, 7, 10, 13, 16, 17
- [ ] Test parental consent for under-13 users
- [ ] Verify COPPA compliance working
- [ ] Full regression: Generate 10 stories (5 interactive, 5 standard)
- [ ] Document any new bugs found

**Success Criteria for Day 2:**
- ✅ Story images generate and display
- ✅ Age gate works without Stack Overflow
- ✅ App is COPPA compliant
- ✅ All core features functional

---

### Day 3: Expand Age Range & Add Error Handling

#### Agent 1 (Backend)
**Priority: Support Ages 3-99 (2-3 hours)**
- [ ] Update `story_complexity_service.dart` age groups:
  - 3-5: Simple, gentle stories
  - 6-8: Elementary vocabulary
  - 9-12: Middle grade complexity
  - 13-17: Young adult themes
  - 18-30: Adult contemporary
  - 31-50: Mature themes
  - 51-70: Life experience themes
  - 70+: Wisdom and reflection themes
- [ ] Test story generation for each age bracket
- [ ] Verify therapeutic elements work for all ages
- [ ] Update API validation to accept 3-99
- [ ] Document age-appropriate storytelling in `AGE_RANGES.md`

**Add Robust Error Handling (1-2 hours)**
- [ ] Add try-catch to all story generation endpoints
- [ ] Return user-friendly errors (not technical stack traces)
- [ ] Log all errors to Sentry
- [ ] Add rate limit error messages
- [ ] Test error scenarios

#### Agent 2 (Frontend)
**Priority: Update Age Range UI (1-2 hours)**
- [ ] Change validation in `character_creation_screen_enhanced.dart`:
  - Line 438: `clamp(3, 99)` instead of `clamp(3, 17)`
  - Line 674: `age < 3 || age > 99` instead of `> 17`
  - Line 758: Same validation update
- [ ] Update UI labels: "Age (3-99)" instead of "Age (3-17)"
- [ ] Add age group hints in character creation
- [ ] Test with ages: 3, 10, 18, 35, 65, 99
- [ ] Update age slider max value

**Add Error UI (1 hour)**
- [ ] Create friendly error messages for common failures
- [ ] Add "Try Again" buttons where appropriate
- [ ] Add loading states with timeouts
- [ ] Test error handling UX

#### Agent 3 (QA/Integration)
**Age Range Testing (Full Day)**
- [ ] Create characters for ages: 3, 7, 13, 18, 25, 45, 65, 85, 99
- [ ] Generate stories for each age
- [ ] Verify age-appropriate content:
  - Age 3: Very simple, gentle
  - Age 13: Teen appropriate
  - Age 35: Adult themes
  - Age 75: Mature, reflective
  - Age 99: Respectful, wise
- [ ] Test error scenarios (API timeout, rate limit, etc.)
- [ ] Verify error messages are user-friendly
- [ ] Document age range expansion success

**Success Criteria for Day 3:**
- ✅ App supports ages 3-99
- ✅ Stories appropriate for all age groups
- ✅ Error handling user-friendly
- ✅ All ages tested and working

---

### Day 4: Commit Pending Work & Test Feelings Wheel

#### Agent 1 (Backend)
**Feelings Wheel Backend Support (2-3 hours)**
- [ ] Review current feelings wheel data structure
- [ ] Verify emotion → story theme mapping works
- [ ] Test feelings wheel with different ages
- [ ] Add logging for emotion tracking
- [ ] Create endpoint for emotion history (if missing)
- [ ] Test therapeutic story generation with emotions

#### Agent 2 (Frontend)
**Commit Feelings Wheel Work (2-3 hours)**
- [ ] Review uncommitted changes in `lib/main_story.dart`
- [ ] Test feelings wheel functionality thoroughly
- [ ] Verify age-aware feelings wheel works
- [ ] Check reference image displays correctly
- [ ] Test emotion selection → story generation flow
- [ ] If stable, commit with message:
  ```
  feat: Age-aware feelings wheel with enhanced UX

  - Added reference image for feelings wheel
  - Age-appropriate emotion selections
  - Fixed color fallback (sunsetPeach)
  - Enhanced therapeutic story integration

  🤖 Generated with Claude Code
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

#### Agent 3 (QA/Integration)
**Full Regression Testing (Full Day)**
- [ ] Test feelings wheel with multiple ages
- [ ] Verify emotions influence story generation
- [ ] Test emotion journal/history
- [ ] Complete end-to-end testing:
  - Create character (verify avatar shows)
  - Select emotion (verify UI works)
  - Generate standard story (verify text + image)
  - Generate interactive story (verify choices work)
  - Save story (verify library works)
  - Share story (verify sharing works)
- [ ] Test on multiple devices (desktop, tablet, phone)
- [ ] Document any bugs or issues

**Success Criteria for Day 4:**
- ✅ Feelings wheel integrated and working
- ✅ Pending work committed to git
- ✅ Full app workflow tested end-to-end
- ✅ All features functional

---

### Day 5: Polish Core UX (Pre-Security)

#### Agent 1 (Backend)
**Code Cleanup & Logging (2-3 hours)**
- [ ] Replace all `print()` statements with `logger.info()`
- [ ] Add structured logging to key endpoints
- [ ] Clean up commented-out code
- [ ] Add API response timing logs
- [ ] Test logging in Railway console
- [ ] Document logging strategy

#### Agent 2 (Frontend)
**Core UX Polish (3-4 hours)**
- [ ] Add loading states to all async operations
- [ ] Add proper error states (not just red text)
- [ ] Smooth transitions between screens
- [ ] Add loading spinners with friendly messages
- [ ] Polish character creation flow
- [ ] Polish story result screen
- [ ] Test UX improvements

#### Agent 3 (QA/Integration)
**UX Testing & Bug Reporting (Full Day)**
- [ ] Test all loading states
- [ ] Test all error states
- [ ] Verify smooth transitions
- [ ] Test on slow network (throttle to 3G)
- [ ] Identify any UX friction points
- [ ] Create prioritized bug list for Week 2
- [ ] Document UX improvements

**Success Criteria for Day 5:**
- ✅ Week 1 Complete: All features work
- ✅ Core UX is smooth and responsive
- ✅ Logging infrastructure in place
- ✅ Ready for security hardening

---

## WEEK 2: MAKE IT SECURE & PROFITABLE

### Day 6: Security Hardening (Part 1)

#### Agent 1 (Backend)
**Critical Security Fixes (Full Day)**

**Priority 1: Authorization (3-4 hours)**
- [ ] Add `user_id` field to all user-owned models (if missing)
- [ ] Implement ownership checks on Character endpoints:
  ```python
  if character.user_id != current_user_id:
      return jsonify({'error': 'Forbidden'}), 403
  ```
- [ ] Add ownership checks to Story endpoints
- [ ] Add ownership checks to SavedStory endpoints
- [ ] Test: Create user A and user B, verify B can't access A's data

**Priority 2: Admin Security (1-2 hours)**
- [ ] Add `role` field to User model (default: 'user')
- [ ] Create migration for role field
- [ ] Create `@admin_required` decorator
- [ ] Protect all `/admin/*` endpoints with decorator
- [ ] Test: Regular user can't access admin endpoints

**Priority 3: Secret Management (1 hour)**
- [ ] Update `ProductionConfig` to raise error if `SECRET_KEY` not set
- [ ] Update to raise error if `JWT_SECRET_KEY` not set
- [ ] Verify production secrets are strong (not defaults)
- [ ] Test: App won't start with missing secrets

#### Agent 2 (Frontend)
**Gender Selection UX (2 hours)**
- [ ] Create illustrated "Boy" and "Girl" selection widget
- [ ] Design beautiful visual cards with character previews
- [ ] Replace dropdown in `character_creation_screen_v3.dart`
- [ ] Ensure backend maps gender → pronouns correctly
- [ ] Test stories use correct pronouns

**Story Reporting Feature (2 hours)**
- [ ] Add "Report" button to saved stories
- [ ] Create report dialog with optional reason
- [ ] Connect to backend `/api/reports` endpoint
- [ ] Add analytics for report tracking
- [ ] Test report flow

#### Agent 3 (QA/Integration)
**Security Penetration Testing (Full Day)**
- [ ] Create two test users (Alice and Bob)
- [ ] Alice creates character, story, subscription
- [ ] Try to access Alice's data as Bob (should fail with 403)
- [ ] Try to modify Alice's character as Bob (should fail)
- [ ] Try to delete Alice's story as Bob (should fail)
- [ ] Try to access `/admin/*` as regular user (should fail)
- [ ] Try to access `/admin/*` as admin (should work)
- [ ] Test app won't start with weak secrets (in dev environment)
- [ ] Document all security test results
- [ ] Report any authorization failures to Agent 1

**Success Criteria for Day 6:**
- ✅ Authorization enforced on all endpoints
- ✅ Admin endpoints protected
- ✅ Secrets properly validated
- ✅ Security vulnerabilities patched

---

### Day 7: Security Hardening (Part 2) + Stripe Webhook

#### Agent 1 (Backend)
**Prompt Injection Protection (1-2 hours)**
- [ ] Create `sanitize_prompt_input()` in `backend/utils/security.py`
- [ ] Strip/escape: backticks, brackets, quotes
- [ ] Block injection phrases: "ignore previous", "new instructions"
- [ ] Apply to character name, theme, interests
- [ ] Apply to interactive story inputs
- [ ] Test injection attempts
- [ ] Document sanitization rules

**Stripe Webhook Implementation (3-4 hours)**
- [ ] Create webhook route in `webhook_handler.py`
- [ ] Implement signature verification
- [ ] Handle `checkout.session.completed` event
- [ ] Update user `subscription_tier` on successful purchase
- [ ] Handle `customer.subscription.deleted` (cancellation)
- [ ] Handle `customer.subscription.updated` (tier change)
- [ ] Test with Stripe CLI webhook forwarding
- [ ] Add comprehensive logging
- [ ] Document webhook implementation

#### Agent 2 (Frontend)
**Subscription Management UI (3-4 hours)**
- [ ] Add "Manage Subscription" button to settings
- [ ] Create backend endpoint for Stripe Customer Portal URL
- [ ] Implement frontend to call endpoint and open portal
- [ ] Display current subscription tier in settings
- [ ] Show renewal date and features for current tier
- [ ] Add upgrade prompts for free users
- [ ] Test subscription management flow

#### Agent 3 (QA/Integration)
**Security & Subscription Testing (Full Day)**
- [ ] Test prompt injection attempts (should be sanitized)
- [ ] Verify normal creative inputs still work
- [ ] Test Stripe webhook with test mode:
  - Simulate successful purchase
  - Verify user tier updated in database
  - Test cancellation flow
  - Test tier upgrade flow
- [ ] Test subscription management UI
- [ ] Verify free → premium upgrade works
- [ ] Verify premium → family upgrade works
- [ ] Document security and subscription test results

**Success Criteria for Day 7:**
- ✅ Prompt injection protection active
- ✅ Stripe webhook auto-updates subscriptions
- ✅ Subscription management works
- ✅ All security holes patched

---

### Day 8: Database Migrations & Backend Refactor (Part 1)

#### Agent 1 (Backend)
**Flask-Migrate Setup (2 hours)**
- [ ] Add `Flask-Migrate` to `requirements.txt`
- [ ] Initialize Flask-Migrate in `create_app()`
- [ ] Run `flask db init` to create migrations folder
- [ ] Run `flask db migrate -m "Initial schema"` to snapshot DB
- [ ] Test migration on clean database
- [ ] Delete manual migration endpoints from `app.py`
- [ ] Document migration workflow

**Extract Story Routes Blueprint (2-3 hours)**
- [ ] Create `backend/routes/story_routes.py`
- [ ] Move story endpoints to Blueprint:
  - `/api/stories/generate`
  - `/api/stories/interactive`
  - `/api/stories/continue`
  - `/api/stories/save`
  - `/api/stories/user/<user_id>`
- [ ] Register Blueprint in `app.py`
- [ ] Test all story endpoints still work
- [ ] Verify no routes broken in refactor

#### Agent 2 (Frontend)
**Enhanced Character Customization (3-4 hours)**
- [ ] Add eye color options to `character_customization_constants.dart`
- [ ] Add glasses options (None, Round, Square, Sunglasses)
- [ ] Add hat options (None, Cap, Wizard Hat, Crown, Bow)
- [ ] Build eye color picker widget
- [ ] Build glasses selector
- [ ] Build hat selector
- [ ] Update avatar preview to show new options
- [ ] Test all combinations

#### Agent 3 (QA/Integration)
**Migration & Refactor Testing (Full Day)**
- [ ] Pull latest backend changes
- [ ] Create fresh test database
- [ ] Run migration scripts
- [ ] Verify schema created correctly
- [ ] Test story generation endpoints (post-refactor)
- [ ] Test interactive stories still work
- [ ] Test saved stories retrieval
- [ ] Run backend test suite
- [ ] Test character customization (new options)
- [ ] Create 10 characters with different customizations
- [ ] Verify avatars show all customizations

**Success Criteria for Day 8:**
- ✅ Database migrations in place
- ✅ Story routes extracted to Blueprint
- ✅ Character customization expanded
- ✅ All features still working post-refactor

---

### Day 9: Backend Refactor (Part 2)

#### Agent 1 (Backend)
**Extract Remaining Blueprints (Full Day)**

**Character Routes (2 hours)**
- [ ] Create `backend/routes/character_routes.py`
- [ ] Move all character CRUD endpoints
- [ ] Register Blueprint in `app.py`
- [ ] Test character endpoints

**Admin Routes (1 hour)**
- [ ] Create `backend/routes/admin_routes.py`
- [ ] Move admin endpoints (already protected)
- [ ] Register Blueprint
- [ ] Test admin endpoints

**Code Cleanup (2 hours)**
- [ ] Verify `app.py` is now < 500 lines (down from 1500+)
- [ ] Clean up imports
- [ ] Remove dead code
- [ ] Update API documentation
- [ ] Run full backend test suite

#### Agent 2 (Frontend)
**Onboarding Improvements (3-4 hours)**
- [ ] Add skip confirmation dialog
- [ ] Change button text to "Skip for now"
- [ ] Add progress tracking to onboarding
- [ ] Improve visual design of onboarding steps
- [ ] Add friendly helper text
- [ ] Test onboarding flow
- [ ] Get feedback on UX

#### Agent 3 (QA/Integration)
**Complete Refactor Verification (Full Day)**
- [ ] Test all character endpoints post-refactor
- [ ] Test all admin endpoints
- [ ] Test all story endpoints
- [ ] Run integration tests across all Blueprints
- [ ] Verify error handling still works
- [ ] Check logging is consistent
- [ ] Test onboarding improvements
- [ ] Full regression test of entire app
- [ ] Document test coverage

**Success Criteria for Day 9:**
- ✅ Backend properly modularized (Blueprints)
- ✅ app.py cleaned up and maintainable
- ✅ Onboarding improved
- ✅ All features working post-refactor

---

### Day 10: Service Layer & Cost Tracking

#### Agent 1 (Backend)
**Service Layer Abstraction (3-4 hours)**
- [ ] Create `create_story_for_user()` in `story_service.py`
- [ ] Move prompt generation logic to service
- [ ] Move API call logic to service
- [ ] Move response processing to service
- [ ] Update routes to be thin wrappers calling services
- [ ] Test service layer independently

**Persist Cost Tracking (2-3 hours)**
- [ ] Create `CostEvent` model in `models.py`
- [ ] Create migration for CostEvent table
- [ ] Update `cost_tracking.py` to save to database
- [ ] Update `get_cost_report()` to query DB
- [ ] Test cost tracking with volume
- [ ] Document cost tracking architecture

#### Agent 2 (Frontend)
**Share Story Feature (2-3 hours)**
- [ ] Add "Share" button to story result screen
- [ ] Generate formatted text summary of story
- [ ] Include character name, theme, wisdom gem
- [ ] Integrate with `share_plus` package
- [ ] Support sharing text or image (if available)
- [ ] Add analytics for shares
- [ ] Test sharing on web and mobile

#### Agent 3 (QA/Integration)
**Service Layer & Sharing Tests (Full Day)**
- [ ] Write unit tests for service layer
- [ ] Test service functions in isolation
- [ ] Verify routes correctly call services
- [ ] Generate stories to create cost events
- [ ] Verify cost events saved to DB
- [ ] Test cost reports show correct data
- [ ] Test share functionality
- [ ] Verify shared content looks good
- [ ] Test analytics events fire

**Success Criteria for Day 10:**
- ✅ Week 2 Complete: Secure and profitable
- ✅ Service layer implemented
- ✅ Cost tracking persistent
- ✅ Sharing works
- ✅ Backend architecture clean

---

## WEEK 3: MAKE IT MAGICAL

### Day 11: Visual Polish & Animations

#### Agent 1 (Backend)
**Parent Dashboard API (3-4 hours)**
- [ ] Create `dashboard_routes.py` Blueprint
- [ ] Endpoint: `GET /api/dashboard/stats` (story count, emotions)
- [ ] Endpoint: `GET /api/dashboard/stories` (paginated history)
- [ ] Endpoint: `GET /api/dashboard/emotions` (timeline)
- [ ] Endpoint: `GET /api/dashboard/wisdom-gems` (collection)
- [ ] Add date range filtering
- [ ] Test with sample data
- [ ] Document API in Swagger

#### Agent 2 (Frontend)
**Add Delightful Animations (Full Day)**
- [ ] Add particle effects to key interactions
- [ ] Story completion: confetti/sparkles
- [ ] Character creation: gentle celebration
- [ ] Unlock achievement: burst animation
- [ ] Add micro-animations to buttons (scale, bounce)
- [ ] Smooth page transitions
- [ ] Add loading animations (not just spinners)
- [ ] Test performance on low-end devices
- [ ] Ensure animations are smooth, not laggy
- [ ] Add accessibility: option to reduce motion

#### Agent 3 (QA/Integration)
**Animation & Performance Testing (Full Day)**
- [ ] Test all animations on multiple devices
- [ ] Test on low-end device (verify smooth)
- [ ] Test reduced motion accessibility setting
- [ ] Test parent dashboard API
- [ ] Verify stats are accurate
- [ ] Test date filtering
- [ ] Performance test with large datasets
- [ ] Document animation guidelines
- [ ] Get feedback: magical or distracting?

**Success Criteria for Day 11:**
- ✅ Animations add delight without lag
- ✅ Parent dashboard API ready
- ✅ Accessibility settings work
- ✅ App feels polished

---

### Day 12: Parent Dashboard UI

#### Agent 1 (Backend)
**Achievement System (3-4 hours)**
- [ ] Create `Achievement` model
- [ ] Create `UserAchievement` model
- [ ] Seed achievements: "First Story", "Character Creator", etc.
- [ ] Endpoint: `POST /api/achievements/unlock`
- [ ] Endpoint: `GET /api/achievements/user/<user_id>`
- [ ] Auto-unlock based on story count
- [ ] Test achievement system

#### Agent 2 (Frontend)
**Parent Dashboard UI (Full Day)**
- [ ] Create `parent_dashboard_screen.dart`
- [ ] Design overview with key stats
- [ ] Show story history with themes
- [ ] Display emotional journey timeline
- [ ] Create emotion chart widget
- [ ] Show achievements and progress
- [ ] Display wisdom gems collection
- [ ] Add date range picker
- [ ] Connect to backend APIs
- [ ] Test with real data
- [ ] Polish UI design

#### Agent 3 (QA/Integration)
**Dashboard Testing (Full Day)**
- [ ] Create test user with rich history
- [ ] Generate 20+ stories with varied emotions
- [ ] Verify dashboard shows accurate stats
- [ ] Test date filtering works
- [ ] Test emotion timeline chart
- [ ] Verify achievements display correctly
- [ ] Test on multiple screen sizes
- [ ] Get parent feedback on usefulness
- [ ] Document dashboard features

**Success Criteria for Day 12:**
- ✅ Parent dashboard fully functional
- ✅ Achievement system working
- ✅ Emotional insights valuable
- ✅ UI beautiful and intuitive

---

### Day 13: Gamification & Unlockables

#### Agent 1 (Backend)
**Unlockable Content System (3-4 hours)**
- [ ] Create `UnlockableItem` model
- [ ] Seed unlockables: rare hair colors, special accessories, themes
- [ ] Add unlock requirements (5 stories, 10 stories, etc.)
- [ ] Endpoint: `GET /api/unlockables/available`
- [ ] Endpoint: `POST /api/unlockables/check` (auto-unlock)
- [ ] Test unlock logic
- [ ] Document progression system

#### Agent 2 (Frontend)
**Gamification UI (Full Day)**
- [ ] Show locked items in character creator with lock icon
- [ ] Add tooltip: "Complete 5 stories to unlock!"
- [ ] Create unlock animation when requirement met
- [ ] Create "Unlockables Gallery" screen
- [ ] Show progress bars: "3/5 stories to unlock Emerald Eyes"
- [ ] Add celebration when item unlocks
- [ ] Test gamification loop
- [ ] Balance reward timing (not too slow/fast)

#### Agent 3 (QA/Integration)
**Gamification Testing (Full Day)**
- [ ] Create new user, generate 15 stories
- [ ] Verify items unlock at correct thresholds
- [ ] Test unlock animations
- [ ] Verify locked items can't be selected
- [ ] Test unlocked items persist
- [ ] Test progression feels rewarding
- [ ] Get feedback on reward timing
- [ ] Document full progression path

**Success Criteria for Day 13:**
- ✅ Gamification creates engagement
- ✅ Unlockables feel rewarding
- ✅ Progression balanced
- ✅ Retention mechanics in place

---

### Day 14-16: Final Polish & Deployment

#### Agent 1 (Backend) - Final Tasks
**Day 14:**
- [ ] Fix all Agent 3 reported bugs
- [ ] Performance optimization
- [ ] Set up Sentry error monitoring
- [ ] Configure production logging

**Day 15:**
- [ ] Update Railway environment variables
- [ ] Set strong production secrets
- [ ] Configure Stripe production keys
- [ ] Test database connections
- [ ] Create deployment script

**Day 16:**
- [ ] Run database migrations on production
- [ ] Deploy backend to production Railway
- [ ] Monitor logs for errors
- [ ] Verify all endpoints work
- [ ] Set up uptime monitoring

#### Agent 2 (Frontend) - Final Tasks
**Day 14:**
- [ ] Fix all UI/UX bugs
- [ ] Final animation polish
- [ ] Cross-browser testing
- [ ] Mobile responsiveness check

**Day 15:**
- [ ] Update environment configs for production
- [ ] Remove debug logging
- [ ] Build production bundle
- [ ] Optimize bundle size
- [ ] Test production build locally

**Day 16:**
- [ ] Deploy to production hosting
- [ ] Configure production domain
- [ ] Set up SSL certificates
- [ ] Test production environment
- [ ] Verify cross-origin API calls work

#### Agent 3 (QA/Integration) - Final Tasks
**Day 14:**
- [ ] Complete regression test of ALL features
- [ ] Test on real devices (not emulators)
- [ ] Create comprehensive bug list
- [ ] Prioritize bugs by severity

**Day 15:**
- [ ] Deploy to staging environment
- [ ] Run full smoke test on staging
- [ ] Test payment flow with Stripe test mode
- [ ] Verify webhooks work
- [ ] Load testing with realistic traffic
- [ ] Create deployment checklist

**Day 16:**
- [ ] Smoke test all critical features in production
- [ ] Test user registration flow
- [ ] Test story generation
- [ ] Test subscription purchase
- [ ] Monitor error logs for first hours
- [ ] Create incident response plan

**Success Criteria for Days 14-16:**
- ✅ All bugs fixed
- ✅ Production environment ready
- ✅ App deployed and stable
- ✅ Monitoring in place
- ✅ Ready for users!

---

### Days 17-21: Buffer & Enhancement

Use remaining days for:
- **Fixing production issues** discovered post-launch
- **User feedback incorporation** from early users
- **Performance optimization** based on real usage
- **App store preparation** (screenshots, description, etc.)
- **Accessibility improvements** (implement Semantics properly)
- **Marketing materials** (video demos, social media content)
- **Story Arcs feature** (if time permits - multi-chapter quests)
- **Voice narration** (text-to-speech for stories)

---

## Priority Philosophy

### Week 1: FUNCTION
**Goal:** Everything works as intended
- No crashes
- No broken features
- No visual placeholders
- No confusing UX

### Week 2: SECURITY & REVENUE
**Goal:** Safe to use and profitable
- Can't be hacked
- Subscriptions work automatically
- Code is maintainable
- Costs are tracked

### Week 3: MAGIC
**Goal:** Delightful and engaging
- Animations add joy
- Gamification creates retention
- Parents get insights
- Users want to share

**Function enables magic. Magic without function is frustration.**

---

## Current vs. Future State

### Current State (Broken):
- ❌ Stack Overflow on age gate
- ❌ Interactive stories show code
- ❌ Avatars show generic icons
- ❌ Images never generate
- ❌ Age limited to 3-17
- ❌ Subscriptions manual
- ❌ Security holes
- ❌ No gamification
- ⚠️ Works but boring

### After Week 1 (Functional):
- ✅ No crashes
- ✅ All features work
- ✅ Avatars display
- ✅ Images generate
- ✅ Ages 3-99 supported
- ⚠️ Not secure
- ⚠️ Not profitable
- ⚠️ Not magical

### After Week 2 (Secure & Profitable):
- ✅ Fully functional
- ✅ Secure (no vulnerabilities)
- ✅ Subscriptions automated
- ✅ Code maintainable
- ✅ Costs tracked
- ⚠️ Not magical yet

### After Week 3 (MAGICAL):
- ✅ Fully functional
- ✅ Secure
- ✅ Profitable
- ✅ Delightful animations
- ✅ Engaging gamification
- ✅ Parent insights
- ✅ Users love it
- ✅ **Ready to scale**

---

## Success Metrics

**Week 1:**
- 100% of core features working
- 0 critical bugs
- < 5 minor bugs

**Week 2:**
- 0 security vulnerabilities
- 100% subscription automation
- < 1000ms average API response time

**Week 3:**
- > 80% user satisfaction
- > 30% return user rate
- > 10% share rate
- App store ready

---

This plan prioritizes **function first** (Week 1), then **security and revenue** (Week 2), then **magic** (Week 3).

Every feature must work before it can be made magical.
