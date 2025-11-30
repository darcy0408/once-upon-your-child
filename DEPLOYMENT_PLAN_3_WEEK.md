# Story Weaver 3-Week Deployment Plan
**Created:** November 28, 2025
**Goal:** Deploy a stable, secure, feature-complete app ready for app store submission

## Philosophy
- **Fix critical bugs FIRST** - Can't deploy broken features
- **Security SECOND** - Can't deploy vulnerable app
- **Revenue infrastructure THIRD** - Must monetize properly
- **New features LAST** - Only after stability

## Agent Roles
- **Agent 1 (Backend)** - Backend routes, APIs, database, security
- **Agent 2 (Frontend)** - Flutter UI, screens, widgets, UX
- **Agent 3 (QA/Integration)** - Testing, bug fixes, deployment verification

---

# WEEK 1: Critical Bug Fixes & Security Hardening

## Day 1 - Emergency Fixes

### Agent 1 (Backend)
**Goal:** Diagnose and fix image generation issue
- [ ] Check Railway logs for image generation errors
- [ ] Verify OpenAI API key is set correctly in production
- [ ] Test DALL-E endpoint locally with test prompt
- [ ] Add better error logging to `enhanced_illustration_service.dart`
- [ ] Verify cost tracking isn't blocking image requests
- [ ] Document findings in `IMAGE_GENERATION_FIX.md`

### Agent 2 (Frontend)
**Goal:** Debug and fix Stack Overflow in age gate
- [ ] Set up Flutter DevTools for production debugging
- [ ] Add extensive logging to `lib/screens/age_gate_screen.dart`
- [ ] Add logging to `lib/main.dart` transition logic
- [ ] Identify which widget is causing infinite rebuild loop
- [ ] Create minimal reproduction case
- [ ] Document findings in `STACK_OVERFLOW_DEBUG.md`

### Agent 3 (QA/Integration)
**Goal:** Verify current production state and commit pending work
- [ ] Test current production app - document ALL issues
- [ ] Review uncommitted changes in `lib/main_story.dart` (feelings wheel work)
- [ ] Verify feelings wheel functionality works correctly
- [ ] Commit feelings wheel changes if stable
- [ ] Create comprehensive bug report for Week 1
- [ ] Set up test environment for parallel testing

**End of Day 1:** Should know root cause of both critical bugs

---

## Day 2 - Fix Stack Overflow

### Agent 1 (Backend)
**Goal:** Implement admin role system (security prerequisite)
- [ ] Add `role` field to User model (default: 'user', admin: 'admin')
- [ ] Create database migration for role field
- [ ] Create `@admin_required` decorator in `backend/decorators.py`
- [ ] Test decorator with sample protected endpoint
- [ ] Document in `ADMIN_SECURITY.md`

### Agent 2 (Frontend)
**Goal:** Fix Stack Overflow bug identified on Day 1
- [ ] Implement fix based on Day 1 findings
- [ ] Remove temporary age gate bypass from `lib/main.dart`
- [ ] Test age gate flow: under 13, 13-17, 18+
- [ ] Verify no infinite loops in any flow
- [ ] Re-enable age gate properly
- [ ] Add unit tests for age gate component

### Agent 3 (QA/Integration)
**Goal:** Comprehensive testing of age gate fix
- [ ] Test age gate with various ages (4, 9, 13, 16, 21)
- [ ] Test parental consent flow for under-13 users
- [ ] Verify app loads correctly after consent granted
- [ ] Test "Cancel" scenarios in consent flow
- [ ] Performance test - no memory leaks or slowdowns
- [ ] Document test results

**End of Day 2:** Age gate working, app COPPA compliant

---

## Day 3 - Security Hardening (Part 1)

### Agent 1 (Backend)
**Goal:** Protect admin endpoints and fix secret management
- [ ] Apply `@admin_required` to all `/admin/*` endpoints
- [ ] Modify `ProductionConfig` to raise error if `SECRET_KEY` not set
- [ ] Modify `ProductionConfig` to raise error if `JWT_SECRET_KEY` not set
- [ ] Add validation that secrets are not default values
- [ ] Test that app won't start with missing secrets
- [ ] Update Railway environment variables with strong secrets
- [ ] Document in `SECURITY_HARDENING.md`

### Agent 2 (Frontend)
**Goal:** Fix image generation UI (based on Day 1 findings)
- [ ] Implement frontend fixes for image generation
- [ ] Add loading states for image generation
- [ ] Add error handling with user-friendly messages
- [ ] Test image generation end-to-end
- [ ] Add retry mechanism for failed generations
- [ ] Update `story_result_screen.dart` with better UX

### Agent 3 (QA/Integration)
**Goal:** Security testing
- [ ] Attempt to access `/admin/*` endpoints without auth - should fail
- [ ] Attempt to access `/admin/*` as regular user - should fail
- [ ] Verify admin user can access admin endpoints
- [ ] Test that production won't start with weak secrets
- [ ] Run security scan with `safety check` on requirements.txt
- [ ] Document all security test results

**End of Day 3:** Critical security holes patched

---

## Day 4 - Security Hardening (Part 2)

### Agent 1 (Backend)
**Goal:** Implement authorization checks (fix IDOR vulnerability)
- [ ] Add ownership check to `GET /characters/<id>` endpoint
- [ ] Add ownership check to `PUT /characters/<id>` endpoint
- [ ] Add ownership check to `DELETE /characters/<id>` endpoint
- [ ] Add ownership check to all story endpoints
- [ ] Add ownership check to saved story endpoints
- [ ] Create test cases for unauthorized access attempts
- [ ] Document authorization model in `AUTHORIZATION.md`

### Agent 2 (Frontend)
**Goal:** Improve gender selection UI
- [ ] Create illustrated "Boy" and "Girl" selection widget
- [ ] Design visual cards with character previews
- [ ] Replace dropdown in `character_creation_screen_v3.dart`
- [ ] Ensure backend maps gender → pronouns (male→he/him, female→she/her)
- [ ] Test that stories use correct pronouns
- [ ] Update character edit screen with same widget

### Agent 3 (QA/Integration)
**Goal:** Authorization penetration testing
- [ ] Create 2 test users (Alice and Bob)
- [ ] Have Alice create character, story, subscription
- [ ] Try to access Alice's data as Bob - should all fail (403 Forbidden)
- [ ] Try to modify Alice's character as Bob - should fail
- [ ] Try to delete Alice's story as Bob - should fail
- [ ] Document any authorization failures found
- [ ] Verify fixes after Agent 1 completes

**End of Day 4:** App secure against basic attacks

---

## Day 5 - Prompt Injection Protection

### Agent 1 (Backend)
**Goal:** Sanitize all user inputs to prevent prompt injection
- [ ] Create `sanitize_prompt_input()` function in `backend/utils/security.py`
- [ ] Strip/escape special characters: backticks, brackets, quotes
- [ ] Block common injection phrases: "ignore previous", "new instructions"
- [ ] Apply to character name, theme, interests in story generation
- [ ] Apply to all interactive story user inputs
- [ ] Add tests for injection attempts
- [ ] Document sanitization rules in `PROMPT_SECURITY.md`

### Agent 2 (Frontend)
**Goal:** Restore safe features lost in rollback
- [ ] Add "Report Story" button to saved stories screen
- [ ] Implement report dialog with optional reason
- [ ] Connect to backend `/api/reports` endpoint
- [ ] Add "Skip Confirmation" dialog to onboarding
- [ ] Change button text to "Skip for now"
- [ ] Test both features work correctly

### Agent 3 (QA/Integration)
**Goal:** Test prompt injection defenses
- [ ] Try to inject malicious prompts via character name
- [ ] Try injection via story theme field
- [ ] Try injection in interactive story choices
- [ ] Verify all attempts are sanitized/blocked
- [ ] Test that normal creative inputs still work
- [ ] Document injection test results

**End of Day 5:** Week 1 Complete - App secure and critical bugs fixed

---

# WEEK 2: Revenue Infrastructure & Backend Refactoring

## Day 6 - Stripe Webhook (CRITICAL)

### Agent 1 (Backend)
**Goal:** Implement Stripe webhook for automatic subscription fulfillment
- [ ] Create `@stripe_webhook` route in `webhook_handler.py`
- [ ] Implement signature verification using Stripe signing secret
- [ ] Handle `checkout.session.completed` event
- [ ] Extract user_id and subscription_tier from event
- [ ] Update User.subscription_tier in database
- [ ] Handle `customer.subscription.deleted` (cancellation)
- [ ] Handle `customer.subscription.updated` (tier change)
- [ ] Test with Stripe CLI webhook forwarding
- [ ] Add comprehensive logging
- [ ] Document in `STRIPE_WEBHOOK.md`

### Agent 2 (Frontend)
**Goal:** Build subscription management UI
- [ ] Add "Manage Subscription" button to settings screen
- [ ] Create backend endpoint to generate Stripe Customer Portal URL
- [ ] Implement frontend to call endpoint and open portal
- [ ] Add subscription status display in settings
- [ ] Show current tier, renewal date, features
- [ ] Test portal flow: upgrade, downgrade, cancel
- [ ] Document in user-facing help text

### Agent 3 (QA/Integration)
**Goal:** End-to-end subscription testing
- [ ] Use Stripe test mode to simulate purchase
- [ ] Verify webhook updates user tier correctly
- [ ] Test free → premium upgrade flow
- [ ] Test premium → family upgrade flow
- [ ] Test cancellation flow (should downgrade to free)
- [ ] Verify rate limits change with tier
- [ ] Document complete subscription lifecycle

**End of Day 6:** Subscriptions work automatically

---

## Day 7 - Database Migrations

### Agent 1 (Backend)
**Goal:** Replace manual migrations with Flask-Migrate
- [ ] Add `Flask-Migrate` to `requirements.txt`
- [ ] Initialize Flask-Migrate in `create_app()`
- [ ] Run `flask db init` to create migrations folder
- [ ] Run `flask db migrate -m "Initial schema"` to snapshot current DB
- [ ] Delete manual migration endpoints from `app.py`
- [ ] Test migration on clean database
- [ ] Document migration workflow in `DATABASE_MIGRATIONS.md`
- [ ] Update deployment docs with migration commands

### Agent 2 (Frontend)
**Goal:** Enhanced onboarding experience
- [ ] Create `onboarding_flow_screen.dart` with PageView
- [ ] Design illustrated page for "What's your name?"
- [ ] Design illustrated page for "How old are you?"
- [ ] Design illustrated page for "Pick a story theme"
- [ ] Add smooth page transition animations
- [ ] Test onboarding flow feels magical and engaging
- [ ] Get feedback on UX improvements

### Agent 3 (QA/Integration)
**Goal:** Migration testing and validation
- [ ] Pull latest backend changes
- [ ] Create fresh test database
- [ ] Run migration scripts - should build schema from scratch
- [ ] Verify all tables, indexes, constraints created
- [ ] Test downgrade/upgrade migrations
- [ ] Verify production Railway can run migrations
- [ ] Document migration testing procedures

**End of Day 7:** Proper database change management in place

---

## Day 8 - Backend Refactoring (Part 1)

### Agent 1 (Backend)
**Goal:** Extract story routes into Blueprint
- [ ] Create `backend/routes/story_routes.py`
- [ ] Move `generate_story` endpoint to story Blueprint
- [ ] Move `generate_interactive_story` endpoint
- [ ] Move `continue_interactive_story` endpoint
- [ ] Move `save_story` endpoint
- [ ] Move `get_user_stories` endpoint
- [ ] Register Blueprint in `app.py`
- [ ] Test all story endpoints still work
- [ ] Document Blueprint architecture in `BACKEND_ARCHITECTURE.md`

### Agent 2 (Frontend)
**Goal:** Expand character customization
- [ ] Add eye color options to `character_customization_constants.dart`
- [ ] Add glasses/accessories options
- [ ] Build eye color picker widget in character creation
- [ ] Build accessories picker widget
- [ ] Update avatar preview to show new options
- [ ] Test all combinations render correctly
- [ ] Save new fields to character model

### Agent 3 (QA/Integration)
**Goal:** Regression testing after refactor
- [ ] Test story generation endpoint works identically
- [ ] Test interactive stories work
- [ ] Test saved stories retrieval works
- [ ] Run full backend test suite
- [ ] Verify no routes were missed in refactor
- [ ] Performance test - no slowdowns introduced
- [ ] Document test coverage

**End of Day 8:** Story routes modularized

---

## Day 9 - Backend Refactoring (Part 2)

### Agent 1 (Backend)
**Goal:** Extract character and admin routes
- [ ] Create `backend/routes/character_routes.py`
- [ ] Move all character CRUD endpoints to Blueprint
- [ ] Create `backend/routes/admin_routes.py`
- [ ] Move all admin endpoints to Blueprint
- [ ] Register both Blueprints in `app.py`
- [ ] Verify `app.py` is now < 500 lines (down from 1500+)
- [ ] Run full test suite
- [ ] Update API documentation

### Agent 2 (Frontend)
**Goal:** Theme/color improvements
- [ ] Restore improved color contrast from rollback
- [ ] Update primary colors in `app_theme.dart`
- [ ] Add focus indicators to buttons
- [ ] Improve hover states
- [ ] Test accessibility (color contrast ratios)
- [ ] Ensure WCAG AA compliance for text
- [ ] Document color palette

### Agent 3 (QA/Integration)
**Goal:** Complete refactor verification
- [ ] Test all character endpoints after refactor
- [ ] Test all admin endpoints after refactor
- [ ] Run integration tests across all Blueprints
- [ ] Verify error handling still works
- [ ] Check logging is consistent
- [ ] Verify no broken imports or references
- [ ] Full regression test of entire app

**End of Day 9:** Backend properly modularized and maintainable

---

## Day 10 - Service Layer Abstraction

### Agent 1 (Backend)
**Goal:** Extract business logic from routes into services
- [ ] Create `create_story_for_user()` in `story_service.py`
- [ ] Move prompt generation logic from routes to service
- [ ] Move API call logic to service
- [ ] Move response processing to service
- [ ] Refactor story routes to be thin wrappers
- [ ] Create `character_service.py` for character business logic
- [ ] Test service layer independently
- [ ] Document service layer pattern

### Agent 2 (Frontend)
**Goal:** Build "Share Your Story" feature
- [ ] Add "Share" button to story result screen
- [ ] Generate formatted text summary of story
- [ ] Include character name, theme, wisdom gem
- [ ] Integrate with `share_plus` package
- [ ] Support sharing as text or image (if illustration exists)
- [ ] Test sharing on web and mobile
- [ ] Add analytics tracking for shares

### Agent 3 (QA/Integration)
**Goal:** Service layer and sharing tests
- [ ] Write unit tests for service layer functions
- [ ] Test service functions in isolation
- [ ] Verify routes correctly call services
- [ ] Test share functionality on multiple devices
- [ ] Verify shared content looks good
- [ ] Test analytics events fire correctly
- [ ] Document testing procedures

**End of Day 10:** Week 2 Complete - Clean architecture and revenue system working

---

# WEEK 3: New Features & Polish

## Day 11 - Cost Tracking to Database

### Agent 1 (Backend)
**Goal:** Persist cost data to database
- [ ] Create `CostEvent` model in `models.py`
- [ ] Fields: operation, user_id, cost, timestamp, model, tokens
- [ ] Create migration for CostEvent table
- [ ] Modify `track_cost()` in `cost_tracking.py` to save to DB
- [ ] Update `get_cost_report()` to query database
- [ ] Update budget alert queries to use DB
- [ ] Test with high volume of cost events
- [ ] Document cost tracking architecture

### Agent 2 (Frontend)
**Goal:** Parent/Therapist Dashboard UI (Part 1)
- [ ] Create `parent_dashboard_screen.dart`
- [ ] Design overview screen with key stats
- [ ] Show total stories created
- [ ] Show emotional trends (feelings wheel data)
- [ ] Create story history list view
- [ ] Add date range filters
- [ ] Use placeholder data for now
- [ ] Focus on UX and visual design

### Agent 3 (QA/Integration)
**Goal:** Cost tracking validation
- [ ] Generate multiple stories to create cost events
- [ ] Verify events saved to database correctly
- [ ] Check cost calculations are accurate
- [ ] Test budget alert thresholds trigger correctly
- [ ] Verify cost reports show correct data
- [ ] Performance test with large datasets
- [ ] Document cost tracking accuracy

**End of Day 11:** Persistent, scalable cost tracking

---

## Day 12 - Parent Dashboard Backend

### Agent 1 (Backend)
**Goal:** Create Parent Dashboard API
- [ ] Create `dashboard_routes.py` Blueprint
- [ ] Endpoint: `GET /api/dashboard/stats` - return story count, feeling trends
- [ ] Endpoint: `GET /api/dashboard/stories` - paginated story history
- [ ] Endpoint: `GET /api/dashboard/emotions` - emotion timeline
- [ ] Endpoint: `GET /api/dashboard/wisdom-gems` - collected wisdom
- [ ] Add date range filtering to all endpoints
- [ ] Test with sample data
- [ ] Document API in Swagger

### Agent 2 (Frontend)
**Goal:** Connect Dashboard to Live Data
- [ ] Create `DashboardService` to call backend APIs
- [ ] Replace placeholder data with live API calls
- [ ] Implement data refresh/pull-to-refresh
- [ ] Add loading states and error handling
- [ ] Create emotion timeline chart widget
- [ ] Test with real user data
- [ ] Polish UI based on actual data

### Agent 3 (QA/Integration)
**Goal:** End-to-end dashboard testing
- [ ] Create test user with rich history
- [ ] Generate 20+ stories with varied emotions
- [ ] Verify dashboard shows accurate stats
- [ ] Test date filtering works correctly
- [ ] Verify charts render properly
- [ ] Test on multiple screen sizes
- [ ] Document dashboard feature set

**End of Day 12:** Working Parent Dashboard

---

## Day 13 - Story Arcs Backend

### Agent 1 (Backend)
**Goal:** Implement Story Arcs system
- [ ] Create `StoryArc` model (title, description, theme, age_range)
- [ ] Create `StoryArcChapter` model (arc_id, chapter_num, title, prompt_template)
- [ ] Create `UserArcProgress` model (user_id, arc_id, current_chapter)
- [ ] Endpoint: `GET /api/story-arcs` - list available arcs
- [ ] Endpoint: `GET /api/story-arcs/<id>/chapters` - get chapters
- [ ] Endpoint: `POST /api/story-arcs/<id>/start` - start arc
- [ ] Endpoint: `POST /api/story-arcs/<id>/continue` - next chapter
- [ ] Seed database with 3 sample arcs
- [ ] Document Story Arc architecture

### Agent 2 (Frontend)
**Goal:** Story Arcs UI
- [ ] Create `story_arcs_screen.dart` to browse arcs
- [ ] Display arcs as cards with theme, description
- [ ] Create `story_arc_detail_screen.dart` for chapters
- [ ] Show progress through arc (chapter 3 of 8)
- [ ] "Start Arc" or "Continue" button
- [ ] Integrate with story generation
- [ ] Test complete arc flow

### Agent 3 (QA/Integration)
**Goal:** Story Arcs testing
- [ ] Browse available story arcs
- [ ] Start a new arc
- [ ] Complete all chapters in sequence
- [ ] Verify progress saved correctly
- [ ] Test resuming an arc in progress
- [ ] Test starting multiple arcs
- [ ] Document feature and test results

**End of Day 13:** Story Arcs feature complete

---

## Day 14 - Polish & Bug Fixes

### Agent 1 (Backend)
**Goal:** Final backend polish
- [ ] Review and fix all Agent 3 reported bugs
- [ ] Add comprehensive error handling to all routes
- [ ] Improve API response consistency
- [ ] Add request/response logging for debugging
- [ ] Performance optimization based on logs
- [ ] Update all API documentation
- [ ] Code review and cleanup

### Agent 2 (Frontend)
**Goal:** UI/UX Polish
- [ ] Fix all visual bugs reported by Agent 3
- [ ] Smooth all animations and transitions
- [ ] Improve loading states across app
- [ ] Better error messages for users
- [ ] Add helpful tooltips/hints
- [ ] Ensure consistent spacing and typography
- [ ] Final UX review of entire flow

### Agent 3 (QA/Integration)
**Goal:** Full regression test
- [ ] Complete end-to-end test of every feature
- [ ] Test on web browser (Chrome, Safari, Firefox)
- [ ] Test on mobile emulator (iOS and Android)
- [ ] Test all subscription tiers (free, premium, family, BYOK)
- [ ] Test all user roles (user, admin)
- [ ] Document all bugs found with severity
- [ ] Create final bug list for Day 15

**End of Day 14:** App polished and stable

---

## Day 15 - Pre-Production Testing

### Agent 1 (Backend)
**Goal:** Production environment preparation
- [ ] Update all Railway environment variables
- [ ] Set strong SECRET_KEY and JWT_SECRET_KEY
- [ ] Configure Stripe production keys
- [ ] Set up Sentry error monitoring
- [ ] Configure production logging
- [ ] Test database connection strings
- [ ] Create production deployment script
- [ ] Document deployment procedures

### Agent 2 (Frontend)
**Goal:** Production build preparation
- [ ] Update environment configs for production
- [ ] Remove all debug logging
- [ ] Set production API URLs
- [ ] Build production Flutter web bundle
- [ ] Optimize bundle size
- [ ] Test production build locally
- [ ] Prepare deployment to hosting

### Agent 3 (QA/Integration)
**Goal:** Staging environment testing
- [ ] Deploy to staging environment
- [ ] Run full smoke test on staging
- [ ] Test payment flow with Stripe test mode
- [ ] Verify webhooks work in staging
- [ ] Test email notifications
- [ ] Load testing with realistic traffic
- [ ] Create deployment checklist

**End of Day 15:** Ready for production deployment

---

## Day 16 - Production Deployment

### Agent 1 (Backend)
**Goal:** Deploy backend to production
- [ ] Run database migrations on production DB
- [ ] Deploy backend to Railway production
- [ ] Verify all services start correctly
- [ ] Monitor logs for errors
- [ ] Test all critical endpoints work
- [ ] Verify Stripe webhooks configured correctly
- [ ] Set up uptime monitoring

### Agent 2 (Frontend)
**Goal:** Deploy frontend to production
- [ ] Deploy Flutter web build to hosting
- [ ] Configure production domain
- [ ] Set up SSL certificates
- [ ] Configure CDN if applicable
- [ ] Test app loads from production URL
- [ ] Verify API calls work cross-origin
- [ ] Update app store metadata

### Agent 3 (QA/Integration)
**Goal:** Post-deployment verification
- [ ] Smoke test all critical features in production
- [ ] Test user registration flow
- [ ] Test story generation
- [ ] Test subscription purchase (small amount)
- [ ] Verify webhook triggers correctly
- [ ] Monitor error logs for first hours
- [ ] Create incident response plan

**End of Day 16:** App live in production!

---

## Day 17-21: Buffer & Enhancement

**Use these days for:**
- Fixing any production issues discovered
- Implementing accessibility features (Semantics) properly
- App store submission preparation
- Marketing materials
- User onboarding improvements
- Performance optimization
- User feedback incorporation

---

## Key Differences from Gemini's Plan

1. **Priorities Reordered**: Critical bugs → Security → Revenue → Features (not features first)
2. **More Realistic Timeline**: 3 weeks instead of 13 days for this scope
3. **Addresses Current Issues**: Stack Overflow, image generation, missing feelings commit
4. **Security First**: Can't deploy vulnerable app to production
5. **Agent Naming**: Generic Agent 1/2/3 so you can use any model
6. **Gender Handling**: Practical solution respecting your preference
7. **Testing at Every Step**: Agent 3 validates before moving forward
8. **Buffer Time**: Days 17-21 for unexpected issues

## Success Criteria

**End of Week 1:**
- ✅ No critical bugs (Stack Overflow fixed, images working)
- ✅ Security vulnerabilities patched
- ✅ Age gate working (COPPA compliant)

**End of Week 2:**
- ✅ Subscriptions work automatically (Stripe webhook)
- ✅ Backend properly modularized (maintainable)
- ✅ Database migrations in place

**End of Week 3:**
- ✅ New features complete (Dashboard, Story Arcs, Sharing)
- ✅ Production deployment successful
- ✅ App stable and ready for users

## Notes for Execution

- Each day's tasks should be **tested before moving forward**
- Agent 3 gates progress - if tests fail, fix before next day
- Commit working code daily (never leave broken code)
- Document everything for future reference
- Prioritize stability over feature completion
