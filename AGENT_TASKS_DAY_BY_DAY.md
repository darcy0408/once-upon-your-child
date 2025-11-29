# Story Weaver: 3-Agent Parallel Deployment Plan
**Each agent works independently without conflicts**

---

# WEEK 1: MAKE IT WORK

## Day 1: Critical Bug Fixes

### Agent 1 (Backend - Story Systems)
**Focus: Fix Interactive Stories**
```
Priority: CRITICAL - Interactive stories showing code instead of choices

Tasks:
□ Review backend/routes/interactive_story.py endpoint
□ Add logging to see exact Gemini API response
□ Test with simple prompt: "A dragon makes a friend"
□ Check if response parsing is breaking on code blocks
□ Fix prompt engineering to prevent code in responses
□ Add instruction: "Never include code snippets in stories"
□ Test: Generate 3 interactive stories
□ Verify choices appear correctly (not code)
□ Deploy fix to Railway backend
□ Document fix in INTERACTIVE_STORY_FIX.md

Time Estimate: 3-4 hours
Deliverable: Interactive stories working with proper choices
```

### Agent 2 (Frontend - Visual Systems)
**Focus: Fix Avatar Display**
```
Priority: CRITICAL - Avatars show generic icons due to CORS

Tasks:
□ Open lib/avatar_models.dart
□ Find line 67: return Uri.https('avataaars.io', '/', query).toString();
□ Replace with: return Uri.https('api.dicebear.com', '/7.x/avataaars/svg', query).toString();
□ Test locally: Create character with custom hair/clothes
□ Verify avatar updates in real-time
□ Test character selection screen shows custom avatars
□ Deploy to Railway frontend
□ Test in production: Create 3 different characters
□ Verify each shows unique customized avatar
□ Take screenshot of working avatars for proof
□ Document in AVATAR_FIX.md

Time Estimate: 1 hour
Deliverable: Custom avatars displaying correctly
```

### Agent 3 (QA/Integration - Testing & Documentation)
**Focus: Document all bugs and test fixes**
```
Priority: Document current state + verify Agent 1 & 2 fixes

Tasks:
□ Test current interactive stories - take screenshots of code showing
□ Document exact error in BUG_REPORT.md
□ Test avatar display - screenshot generic icons
□ Try to generate story with image - document failure
□ Test age gate - attempt to trigger Stack Overflow
□ Document steps to reproduce in BUG_REPORT.md
□ After Agent 2 deploys avatar fix:
  - Create 5 characters with different customizations
  - Verify each shows unique avatar (not generic icon)
  - Document success with screenshots
□ After Agent 1 deploys interactive fix:
  - Generate 5 interactive stories
  - Verify choices appear (not code)
  - Test making choices and continuing story
  - Document success
□ Update BUG_REPORT.md with "FIXED" status

Time Estimate: Full day (monitoring other agents)
Deliverable: Complete bug documentation + verification of fixes
```

**End of Day 1 Success Criteria:**
- ✅ Interactive stories show choices (not code)
- ✅ Avatars display customizations (not generic icons)
- ✅ All bugs documented

---

## Day 2: Image Generation & Stack Overflow

### Agent 1 (Backend - Image Systems)
**Focus: Get DALL-E image generation working**
```
Priority: CRITICAL - Image generation has never worked

Tasks:
□ Check Railway environment: railway variables --service story-weaver-app-backend
□ Verify OPENAI_API_KEY is set
□ Test API key with curl:
  curl https://api.openai.com/v1/images/generations \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"dall-e-3","prompt":"cute dragon","n":1,"size":"1024x1024"}'
□ If key missing: Add to Railway environment variables
□ If key invalid: Get new key from OpenAI dashboard
□ If no credits: Add credits to OpenAI account
□ Add detailed logging to backend/services/image_service.py
□ Log every step: request sent, response received, URL extracted
□ Test image generation endpoint locally
□ Deploy logging updates to Railway
□ Generate 3 test stories with images
□ Verify images display in story results
□ Take screenshots of working images
□ Document fix in IMAGE_GENERATION_FIX.md

Time Estimate: 3-4 hours
Deliverable: DALL-E images generating successfully
```

### Agent 2 (Frontend - Navigation/Flow)
**Focus: Fix Stack Overflow in age gate**
```
Priority: CRITICAL - App crashes on age gate

Tasks:
□ Set up Flutter DevTools for debugging
□ Add logging to lib/screens/age_gate_screen.dart:
  - Log every setState call
  - Log widget build calls
  - Log navigation events
□ Add logging to lib/main.dart age gate transitions
□ Reproduce Stack Overflow:
  - Clear browser cache
  - Open app in incognito
  - Enter age 9
  - Click parental consent
  - Monitor DevTools for infinite loop
□ Identify widget causing infinite rebuild (likely setState in build())
□ Implement fix (probably move setState out of build method)
□ Remove temporary age gate bypass from lib/main.dart line 131
□ Change: if (onboardingStatus || true) back to if (onboardingStatus)
□ Test ages: 4, 9, 13, 17, 25 - all should work
□ Test parental consent flow for under-13
□ Deploy to production
□ Document fix in STACK_OVERFLOW_FIX.md

Time Estimate: 3-4 hours
Deliverable: Age gate working without crashes
```

### Agent 3 (QA/Integration - End-to-End Testing)
**Focus: Verify all fixes and test full workflow**
```
Priority: Test Agent 1 & 2 fixes, run full regression

Tasks:
□ After Agent 1 deploys image fix:
  - Generate 5 stories with "include image" checked
  - Verify images load within 15 seconds
  - Verify images match story content
  - Test image save/download
  - Test on slow connection (throttle to 3G)
  - Document success with screenshots
□ After Agent 2 deploys Stack Overflow fix:
  - Test age gate with ages: 3, 7, 10, 13, 16, 18, 25
  - Test parental consent for age 9
  - Verify no crashes or infinite loops
  - Test "Cancel" in parental consent
  - Verify age gate → app transition smooth
  - Document success
□ Full workflow regression test:
  1. Complete age gate (test as age 10)
  2. Grant parental consent
  3. Create character with custom avatar
  4. Select emotion from feelings wheel
  5. Generate standard story with image
  6. Verify story + image display correctly
  7. Save story to library
  8. Generate interactive story
  9. Make choices and continue story
  10. Save interactive story
  11. Share a story
□ Document any new bugs found
□ Create prioritized bug list for Day 3

Time Estimate: Full day
Deliverable: Complete regression test results
```

**End of Day 2 Success Criteria:**
- ✅ Images generate and display
- ✅ Age gate works without crashing
- ✅ Full app workflow tested and working

---

## Day 3: Age Range & Error Handling

### Agent 1 (Backend - Age Systems)
**Focus: Support ages 3-99**
```
Priority: HIGH - Expand age range from 3-17 to 3-99

Tasks:
□ Open backend/services/story_complexity_service.py
□ Update age groups:
  - Ages 3-5: Very simple, 2-3 sentence paragraphs
  - Ages 6-8: Simple, 4-5 sentence paragraphs
  - Ages 9-12: Elementary, fuller paragraphs
  - Ages 13-17: Young adult, complex themes
  - Ages 18-30: Adult contemporary
  - Ages 31-50: Mature life experiences
  - Ages 51-70: Reflection and wisdom
  - Ages 71-99: Life wisdom, gentle pacing
□ Test story generation for each bracket
□ Update API validation to accept 3-99
□ Add error handling to all story endpoints:
  - Wrap in try-catch
  - Return user-friendly errors
  - Log to Sentry (if configured)
  - Never expose stack traces to users
□ Test error scenarios:
  - API timeout (mock)
  - Rate limit exceeded
  - Invalid API key
□ Document age ranges in AGE_RANGES.md

Time Estimate: 4-5 hours
Deliverable: Ages 3-99 supported, robust error handling
```

### Agent 2 (Frontend - Age UI)
**Focus: Update age range UI and error states**
```
Priority: HIGH - Update UI for 3-99 age range

Tasks:
□ Open lib/character_creation_screen_enhanced.dart
□ Update line 438: clamp(3, 99) instead of clamp(3, 17)
□ Update line 674: if (age < 3 || age > 99) instead of > 17
□ Update line 758: Same validation (3-99)
□ Update UI labels: "Age (3-99)" everywhere it says "Age (3-17)"
□ Add age group hints:
  - 3-5: "Preschool"
  - 6-12: "Elementary"
  - 13-17: "Teen"
  - 18-30: "Young Adult"
  - 31-50: "Adult"
  - 51-70: "Mature Adult"
  - 71-99: "Senior"
□ Update age slider/picker max value to 99
□ Add friendly error messages:
  - API timeout: "The story weaver is taking a break. Try again?"
  - Rate limit: "You've created many amazing stories! Upgrade for unlimited."
  - Generation failed: "Oops! The magic didn't quite work. Try again?"
□ Add "Try Again" buttons to error states
□ Test with ages: 3, 10, 18, 35, 65, 99
□ Deploy to production

Time Estimate: 2-3 hours
Deliverable: UI supports 3-99, friendly error handling
```

### Agent 3 (QA/Integration - Age Range Testing)
**Focus: Test all age groups thoroughly**
```
Priority: Verify age-appropriate content for all ages

Tasks:
□ Create test characters for each age bracket:
  - Age 3: "Tiny Tim"
  - Age 7: "Sally Student"
  - Age 13: "Teen Taylor"
  - Age 18: "College Chris"
  - Age 25: "Professional Pat"
  - Age 45: "Manager Mike"
  - Age 65: "Retired Rita"
  - Age 85: "Wise Walter"
  - Age 99: "Elder Eve"
□ Generate stories for each character
□ Verify age-appropriate content:
  - Age 3: Very simple, gentle, short
  - Age 13: Teen themes, appropriate complexity
  - Age 35: Adult situations, deeper themes
  - Age 75: Reflective, respectful
  - Age 99: Wise, gentle, appropriate
□ Test error scenarios:
  - Disconnect internet mid-generation
  - Verify friendly error message appears
  - Click "Try Again" - verify it works
  - Generate 20 stories quickly (trigger rate limit)
  - Verify friendly rate limit message
□ Document age-appropriate story examples
□ Create AGE_TESTING_RESULTS.md

Time Estimate: Full day
Deliverable: Verification that all ages work appropriately
```

**End of Day 3 Success Criteria:**
- ✅ Ages 3-99 supported
- ✅ Stories appropriate for all ages
- ✅ Error handling user-friendly

---

## Day 4: Feelings Wheel & Regression

### Agent 1 (Backend - Emotions)
**Focus: Verify feelings wheel backend**
```
Priority: MEDIUM - Ensure emotion tracking works

Tasks:
□ Review backend emotion tracking endpoints
□ Test emotion → story theme mapping
□ Verify emotions stored correctly
□ Add logging for emotion selection events
□ Create test: Select "sad" emotion, verify story addresses sadness
□ Create test: Select "excited" emotion, verify upbeat story
□ Test emotion history endpoint (if exists)
□ Document emotion → theme mapping in EMOTIONS.md
□ No code changes unless bugs found

Time Estimate: 2-3 hours (mostly testing)
Deliverable: Emotion tracking verified working
```

### Agent 2 (Frontend - Feelings Wheel)
**Focus: Commit and test feelings wheel work**
```
Priority: MEDIUM - Finalize uncommitted feelings wheel work

Tasks:
□ Review uncommitted changes in lib/main_story.dart
□ Test feelings wheel functionality:
  - Open feelings corner
  - Select different emotions
  - Verify UI is age-appropriate
  - Test emotion intensity selection
□ Verify reference image displays (assets/images/FeelingsWheel.png)
□ Test emotion → story generation flow
□ If stable and working, commit with message:
  ```
  feat: Age-aware feelings wheel with enhanced UX

  - Added reference image for feelings wheel
  - Age-appropriate emotion selections
  - Fixed color fallback (sunsetPeach)
  - Enhanced therapeutic story integration

  🤖 Generated with Claude Code
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
□ Push to repository
□ Verify deploy successful

Time Estimate: 2-3 hours
Deliverable: Feelings wheel committed and deployed
```

### Agent 3 (QA/Integration - Full Regression)
**Focus: Complete end-to-end testing of entire app**
```
Priority: HIGH - Verify everything works together

Full Workflow Test (Do this 3 times with different ages):

Test 1 - Young Child (Age 5):
□ Clear browser data
□ Open app
□ Enter age 5 in age gate
□ Request parental consent
□ Grant consent as parent
□ Create character "Lily" (customize hair, clothes)
□ Verify avatar shows customizations
□ Open feelings wheel
□ Select "Happy" emotion
□ Generate standard story with image
□ Verify story is age-appropriate (very simple)
□ Verify image matches story
□ Save story to library
□ Generate interactive story
□ Make 2 choices
□ Verify story continues appropriately
□ Save interactive story
□ Share story (test share functionality)

Test 2 - Teenager (Age 14):
□ Same workflow as above
□ Verify teen-appropriate story complexity
□ Test with "Anxious" emotion

Test 3 - Adult (Age 35):
□ Same workflow as above
□ Verify adult-appropriate themes
□ Test with "Reflective" emotion

□ Test on multiple devices:
  - Desktop Chrome
  - Desktop Firefox
  - Mobile (if available)
□ Document any issues in REGRESSION_RESULTS.md
□ Create prioritized bug list for Week 2

Time Estimate: Full day
Deliverable: Complete regression test documentation
```

**End of Day 4 Success Criteria:**
- ✅ Feelings wheel working and committed
- ✅ Full app tested end-to-end
- ✅ All features verified working
- ✅ Ready for Week 2 (Security)

---

## Day 5: Polish & Preparation

### Agent 1 (Backend - Code Quality)
**Focus: Clean up and improve logging**
```
Priority: MEDIUM - Prepare backend for security work

Tasks:
□ Replace all print() with logger.info() throughout backend
□ Add structured logging to key endpoints:
  - Story generation: log user_id, age, theme, duration
  - Image generation: log success/failure, duration
  - Errors: log full context
□ Clean up commented-out code in backend/
□ Remove any debug code left in production
□ Test logging appears in Railway console
□ Add performance timing logs:
  - Log API call durations
  - Log slow queries (>1 second)
□ Create LOGGING_STRATEGY.md
□ No feature changes - just cleanup

Time Estimate: 3-4 hours
Deliverable: Clean, well-logged backend code
```

### Agent 2 (Frontend - UX Polish)
**Focus: Improve loading and error states**
```
Priority: MEDIUM - Make UX smoother

Tasks:
□ Add loading states to all async operations:
  - Story generation: "Weaving your story..."
  - Image generation: "Painting your scene..."
  - Character save: "Saving your character..."
□ Replace generic CircularProgressIndicator with themed spinners
□ Add smooth transitions between screens:
  - Fade in/out instead of instant changes
  - Gentle slide animations
□ Polish character creation screen:
  - Smooth avatar preview updates
  - Clear visual feedback on changes
□ Polish story result screen:
  - Nice layout for story + image
  - Clear CTA buttons (Save, Share, Create Another)
□ Test all improvements
□ Deploy to production

Time Estimate: 3-4 hours
Deliverable: Smoother, more polished UX
```

### Agent 3 (QA/Integration - Week 1 Report)
**Focus: Document Week 1 and prepare Week 2**
```
Priority: HIGH - Create comprehensive Week 1 report

Tasks:
□ Create WEEK_1_REPORT.md with:
  - What was broken at start of week
  - What got fixed each day
  - Current state of all features
  - Bugs remaining (if any)
  - Screenshots of before/after
□ Test all fixes from Week 1:
  - Interactive stories (choices not code) ✓
  - Avatars (custom not generic) ✓
  - Images (DALL-E working) ✓
  - Age gate (no Stack Overflow) ✓
  - Age range (3-99 supported) ✓
  - Feelings wheel (committed) ✓
□ Performance testing:
  - Test app on slow 3G connection
  - Verify loading states appear
  - Verify errors handled gracefully
  - Document load times
□ Create Week 2 Preparation Checklist:
  - Security testing tools needed
  - Test users to create (Alice, Bob)
  - Stripe test mode setup
□ Create prioritized Week 2 task list

Time Estimate: Full day
Deliverable: Week 1 complete report + Week 2 ready
```

**End of Day 5 / Week 1 Success Criteria:**
- ✅ All broken features fixed
- ✅ App stable and functional
- ✅ Code cleaned up
- ✅ UX polished
- ✅ Week 1 documented
- ✅ Ready for Week 2 security work

---

# WEEK 2: MAKE IT SECURE & PROFITABLE

## Day 6: Security - Authorization

### Agent 1 (Backend - Authorization)
**Focus: Implement ownership checks (fix IDOR vulnerability)**
```
Priority: CRITICAL - Security vulnerability must be fixed

Tasks:
□ Verify all models have user_id field:
  - Character model
  - SavedStory model
  - UserAchievement model
□ Add ownership check helper function in backend/utils/auth.py:
  def verify_ownership(resource, user_id):
      if resource.user_id != user_id:
          abort(403, 'Forbidden')
□ Add ownership checks to Character endpoints:
  - GET /api/characters/<id> - verify requester owns character
  - PUT /api/characters/<id> - verify requester owns character
  - DELETE /api/characters/<id> - verify requester owns character
□ Add ownership checks to Story endpoints:
  - GET /api/stories/<id>
  - DELETE /api/stories/<id>
□ Add ownership checks to SavedStory endpoints:
  - GET /api/saved-stories/<id>
  - DELETE /api/saved-stories/<id>
  - PUT /api/saved-stories/<id>
□ Test: Create resource as user A, try to access as user B (should fail)
□ Document in AUTHORIZATION.md

Time Estimate: 4-5 hours
Deliverable: IDOR vulnerability fixed, authorization enforced
```

### Agent 2 (Frontend - Gender Selection)
**Focus: Improve gender selection UX**
```
Priority: MEDIUM - Better UX for character creation

Tasks:
□ Create new widget: lib/widgets/gender_selection_card.dart
□ Design illustrated cards:
  - "Boy" card with male character illustration
  - "Girl" card with female character illustration
  - Cards should be visual and engaging, not just text
□ Replace dropdown in character_creation_screen_v3.dart
□ Add visual selection state (border highlight when selected)
□ Verify backend receives "male" or "female"
□ Verify stories use correct pronouns:
  - male → he/him/his
  - female → she/her/hers
□ Test: Create character as "Girl", verify story uses "she"
□ Test: Create character as "Boy", verify story uses "he"
□ Deploy to production

Time Estimate: 2-3 hours
Deliverable: Beautiful gender selection UI
```

### Agent 3 (QA/Integration - Security Testing)
**Focus: Test authorization and penetration testing**
```
Priority: CRITICAL - Verify security fixes work

Tasks:
□ Create two test users in production:
  - User A (Alice): alice.test@example.com
  - User B (Bob): bob.test@example.com
□ As Alice:
  - Create character "Alice's Dragon"
  - Generate story "Alice's Adventure"
  - Save story to library
  - Subscribe to Premium tier
□ As Bob:
  - Note Alice's character ID from network tab
  - Try GET /api/characters/<alice_character_id>
  - Should receive 403 Forbidden
  - Try DELETE /api/characters/<alice_character_id>
  - Should receive 403 Forbidden
  - Try GET /api/saved-stories/<alice_story_id>
  - Should receive 403 Forbidden
□ Document all authorization test results
□ If any endpoint returns Alice's data to Bob: CRITICAL BUG
□ Test gender selection:
  - Create character as "Boy", generate story
  - Verify pronouns: he/him/his
  - Create character as "Girl", generate story
  - Verify pronouns: she/her/hers
□ Document in SECURITY_TEST_RESULTS.md

Time Estimate: Full day
Deliverable: Authorization verified, security test report
```

**End of Day 6 Success Criteria:**
- ✅ Authorization enforced (users can't access others' data)
- ✅ Gender selection improved
- ✅ Security tested and verified

---

## Day 7: Security - Secrets & Stripe Webhook

### Agent 1 (Backend - Stripe Webhook)
**Focus: Implement automatic subscription fulfillment**
```
Priority: CRITICAL - Subscriptions don't work without this

Tasks:
□ Open backend/routes/webhook_handler.py
□ Create @stripe_webhook route:
  @app.route('/api/webhooks/stripe', methods=['POST'])
□ Implement signature verification:
  - Get stripe signing secret from env
  - Verify webhook signature from Stripe
  - Reject if invalid
□ Handle checkout.session.completed event:
  - Extract customer email
  - Extract subscription tier from metadata
  - Find user by email
  - Update user.subscription_tier
  - Log success
□ Handle customer.subscription.deleted (cancellation):
  - Find user by stripe_customer_id
  - Set user.subscription_tier = 'free'
  - Log cancellation
□ Handle customer.subscription.updated (tier change):
  - Extract new tier
  - Update user.subscription_tier
□ Test with Stripe CLI:
  stripe listen --forward-to localhost:5000/api/webhooks/stripe
  stripe trigger checkout.session.completed
□ Document in STRIPE_WEBHOOK.md

Time Estimate: 4-5 hours
Deliverable: Stripe webhook working, subscriptions auto-update
```

### Agent 2 (Frontend - Subscription UI)
**Focus: Build subscription management interface**
```
Priority: HIGH - Users need to manage subscriptions

Tasks:
□ Add "Manage Subscription" section to settings screen
□ Display current subscription info:
  - Current tier (Free, Premium, Family, BYOK)
  - Features included
  - Renewal date (if applicable)
  - Cost per month
□ Create backend endpoint (coordinate with Agent 1):
  POST /api/stripe/create-portal-session
  Returns: { url: "https://billing.stripe.com/..." }
□ Add "Manage Subscription" button:
  - Calls portal session endpoint
  - Opens Stripe Customer Portal in new tab
  - User can upgrade, downgrade, cancel there
□ Add upgrade prompts for free users:
  - "Unlock unlimited stories with Premium!"
  - Show feature comparison table
□ Test subscription flow:
  - Click "Manage Subscription"
  - Portal opens
  - Can upgrade/cancel
□ Deploy to production

Time Estimate: 3-4 hours
Deliverable: Subscription management UI working
```

### Agent 3 (QA/Integration - Stripe Testing)
**Focus: End-to-end subscription testing**
```
Priority: CRITICAL - Verify money flow works

Tasks:
□ Set up Stripe test mode:
  - Use test card: 4242 4242 4242 4242
  - Expiry: any future date
  - CVC: any 3 digits
□ Test free → premium upgrade:
  - Create new user
  - Verify tier shows "Free"
  - Click upgrade to Premium
  - Enter test card info
  - Complete purchase
  - Wait for webhook (should be instant)
  - Refresh page
  - Verify tier now shows "Premium"
  - Verify rate limits increased
□ Test premium → family upgrade:
  - Click "Manage Subscription"
  - Upgrade to Family tier
  - Verify tier updates to "Family"
□ Test cancellation:
  - Click "Manage Subscription"
  - Cancel subscription
  - Verify tier reverts to "Free"
□ Test Stripe webhook logs:
  - Check Railway logs for webhook events
  - Verify signature verification passing
  - Verify tier updates logged
□ Document full subscription lifecycle in STRIPE_TESTING.md

Time Estimate: Full day
Deliverable: Subscription flow verified end-to-end
```

**End of Day 7 Success Criteria:**
- ✅ Stripe webhook auto-updates subscriptions
- ✅ Subscription management UI works
- ✅ Full payment flow tested

---

## Day 8: Database Migrations & Customization

### Agent 1 (Backend - Database Migrations)
**Focus: Implement proper database change management**
```
Priority: HIGH - Replace manual migrations

Tasks:
□ Add Flask-Migrate to requirements.txt
□ Initialize in backend/app.py:
  from flask_migrate import Migrate
  migrate = Migrate(app, db)
□ Run locally:
  flask db init  # Creates migrations/ folder
  flask db migrate -m "Initial schema"  # Snapshot current DB
  flask db upgrade  # Apply migrations
□ Test on fresh database:
  - Delete test DB
  - Run flask db upgrade
  - Verify all tables created
□ Delete manual migration endpoints from app.py:
  - /admin/run-db-optimization
  - /admin/add-missing-columns
□ Update deployment docs:
  - Add "run flask db upgrade" to deploy process
□ Test in Railway staging environment
□ Document in DATABASE_MIGRATIONS.md

Time Estimate: 3-4 hours
Deliverable: Flask-Migrate implemented, manual endpoints removed
```

### Agent 2 (Frontend - Character Customization)
**Focus: Add eye color, glasses, accessories**
```
Priority: MEDIUM - Expand customization options

Tasks:
□ Update lib/character_customization_constants.dart:
  - Add eyeColorOptions: ['Brown', 'Blue', 'Green', 'Hazel', 'Gray', 'Amber']
  - Add glassesOptions: ['None', 'Round', 'Square', 'Sunglasses', 'Reading']
  - Add hatOptions: ['None', 'Baseball Cap', 'Wizard Hat', 'Crown', 'Bow', 'Beanie']
□ Update Character model to include:
  - eye_color field
  - glasses field
  - hat field
□ Add UI pickers in character_creation_screen_v3.dart:
  - Build eye color picker (similar to hair color picker)
  - Build glasses selector (icon buttons)
  - Build hat selector (icon buttons)
□ Update avatar preview to show new customizations:
  - Pass eye_color, glasses, hat to DiceBear URL
  - Test that preview updates in real-time
□ Test: Create character with all options customized
□ Verify avatar shows all selections
□ Deploy to production

Time Estimate: 3-4 hours
Deliverable: Eye color, glasses, hats added to character creator
```

### Agent 3 (QA/Integration - Migration & Customization Testing)
**Focus: Verify migrations and new customization**
```
Priority: Verify Agent 1 & 2 work

Tasks:
□ Test database migrations:
  - Pull Agent 1's code
  - Create fresh test database
  - Run flask db upgrade
  - Verify schema created:
    - All tables exist
    - All columns present
    - Indexes created
    - Constraints working
□ Test migration rollback:
  - flask db downgrade
  - Verify tables removed
  - flask db upgrade again
  - Verify tables recreated
□ Test character customization:
  - Create 10 characters with different combinations:
    1. Brown eyes, round glasses, wizard hat
    2. Blue eyes, sunglasses, baseball cap
    3. Green eyes, no glasses, crown
    4. Hazel eyes, square glasses, beanie
    5. (etc...)
  - Verify each avatar shows all customizations
  - Verify customizations save correctly
  - Edit character, change options
  - Verify changes persist
□ Test avatar rendering:
  - Verify all eye colors render
  - Verify all glasses styles render
  - Verify all hats render
□ Document in CUSTOMIZATION_TEST.md

Time Estimate: Full day
Deliverable: Migrations verified, customization tested
```

**End of Day 8 Success Criteria:**
- ✅ Database migrations in place
- ✅ Character customization expanded
- ✅ All features working

---

## Day 9: Backend Refactoring

### Agent 1 (Backend - Blueprint Refactoring)
**Focus: Extract routes into Blueprints**
```
Priority: HIGH - Improve code maintainability

Tasks:
□ Create backend/routes/ directory
□ Create backend/routes/character_routes.py:
  - Move all character CRUD endpoints
  - from flask import Blueprint
  - character_bp = Blueprint('characters', __name__)
  - Register in app.py: app.register_blueprint(character_bp)
□ Create backend/routes/admin_routes.py:
  - Move all admin endpoints (already protected)
  - admin_bp = Blueprint('admin', __name__)
  - Register in app.py
□ Update app.py:
  - Remove moved endpoints
  - Add blueprint registrations
  - Verify app.py is now < 500 lines
□ Test all endpoints still work:
  - Character CRUD
  - Admin endpoints
  - Story endpoints
□ Run backend test suite
□ Deploy to staging, verify no breakage
□ Document in BACKEND_REFACTOR.md

Time Estimate: 4-5 hours
Deliverable: Routes organized in Blueprints
```

### Agent 2 (Frontend - Onboarding Polish)
**Focus: Improve onboarding UX**
```
Priority: MEDIUM - Better first-time experience

Tasks:
□ Add skip confirmation dialog to onboarding:
  - When user clicks "Skip"
  - Show: "Skip for now? You can complete this anytime in Settings."
  - Buttons: "Stay", "Skip"
□ Update button text from "Skip" to "Skip for now"
□ Add progress indicator to onboarding:
  - "Step 1 of 4: What's your name?"
  - Progress dots at top
□ Add helper text to each step:
  - Step 1: "We'll use this to personalize your stories"
  - Step 2: "This helps us create age-appropriate stories"
  - Step 3: "Choose what kinds of adventures you'd like"
□ Improve visual design:
  - Consistent spacing
  - Clear typography hierarchy
  - Friendly copy
□ Test onboarding flow 5 times
□ Get feedback from someone unfamiliar with app
□ Deploy to production

Time Estimate: 3-4 hours
Deliverable: Onboarding more user-friendly
```

### Agent 3 (QA/Integration - Refactor Verification)
**Focus: Complete regression after refactor**
```
Priority: HIGH - Verify no breakage from refactor

Tasks:
□ Test all character endpoints:
  - Create character
  - Get character by ID
  - Update character
  - Delete character
  - List user's characters
□ Test all admin endpoints (as admin user):
  - Access should work
  - Test as regular user - should be blocked
□ Test all story endpoints:
  - Generate standard story
  - Generate interactive story
  - Continue interactive story
  - Save story
  - Get saved stories
□ Run integration tests:
  - End-to-end story creation
  - End-to-end character management
□ Verify error handling still works
□ Check logging is consistent
□ Test onboarding improvements:
  - Complete onboarding
  - Try to skip - verify confirmation shows
  - Test progress indicator shows correctly
  - Verify helper text is helpful
□ Full regression of entire app
□ Document any issues in REFACTOR_REGRESSION.md

Time Estimate: Full day
Deliverable: Refactor verified, no breakage
```

**End of Day 9 Success Criteria:**
- ✅ Backend organized in Blueprints
- ✅ Onboarding improved
- ✅ All features still working

---

## Day 10: Service Layer & Sharing

### Agent 1 (Backend - Service Layer)
**Focus: Extract business logic into services**
```
Priority: MEDIUM - Better architecture

Tasks:
□ Open backend/services/story_service.py
□ Create create_story_for_user(user_id, character, theme, age, emotion):
  - Move prompt generation from routes to here
  - Move API call logic to here
  - Move response processing to here
  - Return formatted story object
□ Update story routes to be thin wrappers:
  @story_bp.route('/generate', methods=['POST'])
  def generate():
      data = request.json
      story = story_service.create_story_for_user(...)
      return jsonify(story), 200
□ Create similar service functions:
  - generate_interactive_story(...)
  - continue_interactive_story(...)
  - generate_story_image(...)
□ Test service layer functions independently
□ Update routes to use service layer
□ Verify all story generation still works
□ Document in SERVICE_LAYER.md

Time Estimate: 4-5 hours
Deliverable: Service layer implemented, routes simplified
```

### Agent 2 (Frontend - Share Feature)
**Focus: Add story sharing functionality**
```
Priority: MEDIUM - Enable viral growth

Tasks:
□ Add "Share" button to story result screen
□ Generate shareable content:
  - Story title
  - Character name
  - Story text (truncated if long)
  - Wisdom gem
  - "Created with Story Weaver" footer
□ Integrate with share_plus package:
  - Share.share(formattedText)
  - On web: Shows share dialog
  - On mobile: Native share sheet
□ If story has image, offer image share option:
  - "Share Text" button
  - "Share Image" button
□ Add analytics tracking:
  - Track when user clicks share
  - Track which share method used
□ Test sharing:
  - Web: Verify share dialog appears
  - Copy share text, send to yourself
  - Verify it looks good
□ Deploy to production

Time Estimate: 2-3 hours
Deliverable: Story sharing works
```

### Agent 3 (QA/Integration - Service Layer & Sharing)
**Focus: Test service layer and sharing**
```
Priority: Verify Agent 1 & 2 changes

Tasks:
□ Test service layer (work with Agent 1):
  - Write unit test for create_story_for_user()
  - Test with different inputs
  - Verify correct story returned
  - Test error handling in service
□ Test story generation still works:
  - Generate 10 stories
  - Verify all complete successfully
  - Verify quality unchanged
□ Test sharing feature:
  - Generate story
  - Click "Share Text"
  - Verify share dialog appears
  - Share to yourself via email/message
  - Verify shared content looks good:
    - Title clear
    - Story text readable
    - Attribution included
  - Generate story with image
  - Click "Share Image"
  - Verify image share works
□ Test sharing analytics:
  - Check analytics dashboard
  - Verify share events tracked
□ Performance test:
  - Generate 20 stories quickly
  - Verify service layer handles volume
□ Document in SERVICE_TEST.md

Time Estimate: Full day
Deliverable: Service layer verified, sharing tested
```

**End of Day 10 / Week 2 Success Criteria:**
- ✅ Service layer improves architecture
- ✅ Story sharing works
- ✅ App secure and profitable
- ✅ Code maintainable
- ✅ Ready for Week 3 (Magic)

---

# WEEK 3: MAKE IT MAGICAL

## Day 11: Animations & Parent Dashboard API

### Agent 1 (Backend - Parent Dashboard)
**Focus: Create parent insights API**
```
Priority: MEDIUM - Enable parent visibility

Tasks:
□ Create backend/routes/dashboard_routes.py
□ Create endpoint: GET /api/dashboard/stats/<user_id>
  Returns:
  {
    "total_stories": 45,
    "stories_this_week": 7,
    "favorite_themes": ["Dragons", "Space", "Friendship"],
    "emotional_trends": {
      "happy": 12,
      "sad": 3,
      "excited": 8,
      "calm": 6
    }
  }
□ Create endpoint: GET /api/dashboard/stories/<user_id>
  - Paginated story history
  - Filter by date range
  - Include themes and emotions
□ Create endpoint: GET /api/dashboard/emotions/<user_id>
  - Emotion timeline
  - Group by week/month
□ Create endpoint: GET /api/dashboard/wisdom-gems/<user_id>
  - All wisdom gems collected
  - Categorized by theme
□ Add date range filtering to all endpoints
□ Test with sample data
□ Document API in Swagger

Time Estimate: 4-5 hours
Deliverable: Parent dashboard API ready
```

### Agent 2 (Frontend - Animations)
**Focus: Add delightful micro-animations**
```
Priority: MEDIUM - Make app feel magical

Tasks:
□ Add particle effects (use particles_flutter package):
  - Story completion: confetti/sparkles
  - Character created: gentle celebration
  - Achievement unlocked: burst of stars
□ Add micro-animations to buttons:
  - Scale on press (0.95x)
  - Bounce back (spring animation)
  - Ripple effect
□ Add loading animations:
  - Story generation: animated book pages turning
  - Image generation: paint brush animation
  - Character save: gentle fade pulse
□ Add smooth transitions:
  - Page changes: fade in/out
  - Modal dialogs: scale up from center
  - Lists: stagger fade-in
□ Test performance:
  - Verify 60fps on all animations
  - Test on low-end device
  - Ensure no jank or stuttering
□ Add accessibility option:
  - Settings: "Reduce animations"
  - Respect system prefers-reduced-motion
□ Deploy to production

Time Estimate: Full day (animations take time to polish)
Deliverable: Delightful animations throughout app
```

### Agent 3 (QA/Integration - Animation Testing)
**Focus: Verify animations enhance experience**
```
Priority: Test animations don't hurt performance

Tasks:
□ Test all animations on multiple devices:
  - Desktop (Chrome, Firefox)
  - Mobile (if available)
  - Tablet (if available)
□ Performance testing:
  - Use DevTools FPS meter
  - Verify 60fps during animations
  - Test on throttled CPU (4x slowdown)
  - Verify no dropped frames
□ Accessibility testing:
  - Enable "Reduce animations" in settings
  - Verify animations simplified or removed
  - Test with screen reader (if possible)
□ User experience feedback:
  - Get 3 people to use app
  - Ask: "Do animations feel magical or distracting?"
  - Document feedback
□ Test parent dashboard API:
  - Call all endpoints with test user
  - Verify correct data returned
  - Test date filtering
  - Test pagination
□ Document in ANIMATION_TEST.md

Time Estimate: Full day
Deliverable: Animations verified, performance good
```

**End of Day 11 Success Criteria:**
- ✅ Animations add delight without lag
- ✅ Parent dashboard API ready
- ✅ Performance maintained

---

## Day 12: Parent Dashboard UI & Achievements

### Agent 1 (Backend - Achievements)
**Focus: Create achievement system**
```
Priority: MEDIUM - Gamification backend

Tasks:
□ Create Achievement model:
  - id, name, description, icon, unlock_criteria
□ Create UserAchievement model:
  - user_id, achievement_id, unlocked_at
□ Seed initial achievements:
  - "First Story" (create 1 story)
  - "Story Enthusiast" (create 5 stories)
  - "Story Master" (create 20 stories)
  - "Character Creator" (create first character)
  - "Emotion Explorer" (use feelings wheel 5 times)
  - "Interactive Adventurer" (complete interactive story)
□ Create endpoint: POST /api/achievements/check/<user_id>
  - Checks user's progress
  - Auto-unlocks eligible achievements
  - Returns newly unlocked achievements
□ Create endpoint: GET /api/achievements/<user_id>
  - Returns all achievements
  - Marks which are unlocked
□ Add auto-check after story creation
□ Test achievement unlocking
□ Document in ACHIEVEMENTS.md

Time Estimate: 4-5 hours
Deliverable: Achievement system working
```

### Agent 2 (Frontend - Parent Dashboard UI)
**Focus: Build beautiful dashboard for parents**
```
Priority: MEDIUM - Parent visibility

Tasks:
□ Create lib/screens/parent_dashboard_screen.dart
□ Design overview section:
  - Large stat cards:
    - Total stories created
    - Stories this week
    - Favorite themes
  - Beautiful charts/graphs
□ Create story history section:
  - List of recent stories
  - Shows title, date, theme, emotion
  - Click to view full story
□ Create emotion timeline:
  - Chart showing emotion trends over time
  - Visual representation (colors for emotions)
  - Filterable by date range
□ Create wisdom gems collection:
  - Display all wisdom gems
  - Categorized by theme
  - Beautiful card layout
□ Add date range picker:
  - Last week, Last month, Last 3 months, All time
□ Connect to backend APIs (from Day 11)
□ Test with real data
□ Polish UI design (colors, spacing, typography)
□ Add navigation: Settings → "Parent Dashboard"
□ Deploy to production

Time Estimate: Full day
Deliverable: Beautiful parent dashboard
```

### Agent 3 (QA/Integration - Dashboard & Achievement Testing)
**Focus: Verify dashboard and achievements**
```
Priority: Test both Agent 1 & 2 features

Tasks:
□ Test achievement system:
  - Create new user
  - Generate 1 story
  - Verify "First Story" achievement unlocks
  - Generate 5 stories
  - Verify "Story Enthusiast" unlocks
  - Create character
  - Verify "Character Creator" unlocks
  - Use feelings wheel 5 times
  - Verify "Emotion Explorer" unlocks
  - Complete interactive story
  - Verify "Interactive Adventurer" unlocks
□ Test parent dashboard:
  - Create user with 20+ stories
  - Open parent dashboard
  - Verify stats show correctly:
    - Total stories count accurate
    - Favorite themes accurate
    - Emotion trends accurate
  - Test date filtering:
    - Select "Last week"
    - Verify only last week's data shows
    - Select "Last month"
    - Verify data updates
  - Test story history:
    - Verify all stories listed
    - Click story to view
    - Verify full story displays
  - Test wisdom gems collection:
    - Verify all gems displayed
    - Verify categorization correct
□ Test on multiple screen sizes:
  - Desktop (1920x1080)
  - Tablet (768px)
  - Mobile (375px)
□ Document in DASHBOARD_TEST.md

Time Estimate: Full day
Deliverable: Dashboard and achievements verified
```

**End of Day 12 Success Criteria:**
- ✅ Achievement system working
- ✅ Parent dashboard beautiful and functional
- ✅ Parents can track child's journey

---

## Day 13: Gamification & Unlockables

### Agent 1 (Backend - Unlockables)
**Focus: Create unlockable content system**
```
Priority: MEDIUM - Drive engagement

Tasks:
□ Create UnlockableItem model:
  - type (hair_color, accessory, theme, hat)
  - name
  - unlock_requirement (stories_count, achievement_id)
  - tier (free, premium, achievement)
□ Seed unlockable items:
  Hair colors:
  - "Emerald Green" (5 stories)
  - "Midnight Purple" (10 stories)
  - "Rose Gold" (20 stories)
  Accessories:
  - "Magic Wand" (10 stories)
  - "Dragon Pet" (25 stories)
  Hats:
  - "Star Crown" (15 stories)
  - "Rainbow Hat" (30 stories)
  Themes:
  - "Underwater Adventure" (premium)
  - "Space Odyssey" (premium)
□ Create endpoint: GET /api/unlockables/available/<user_id>
  - Returns all unlockables
  - Marks which are locked/unlocked
  - Shows progress (3/5 stories to unlock)
□ Create endpoint: POST /api/unlockables/check/<user_id>
  - Auto-unlocks based on story count
  - Returns newly unlocked items
□ Test unlocking logic
□ Document in UNLOCKABLES.md

Time Estimate: 4-5 hours
Deliverable: Unlockable system working
```

### Agent 2 (Frontend - Gamification UI)
**Focus: Show locked items and progression**
```
Priority: MEDIUM - Visual gamification

Tasks:
□ Update character creation screen:
  - Show locked items with lock icon overlay
  - Add tooltip on hover: "Complete 5 stories to unlock!"
  - Disable selection of locked items
  - Show progress bar: "3/5 stories to unlock Emerald Eyes"
□ Create unlock animation:
  - When item unlocks, show celebration
  - Sparkles/confetti around unlocked item
  - Toast notification: "You unlocked Emerald Green hair!"
□ Create Unlockables Gallery screen:
  - Grid of all unlockable items
  - Shows locked/unlocked state
  - Shows unlock requirements
  - Shows progress toward next unlock
□ Add navigation: Settings → "Unlockables"
□ Test progression feels rewarding:
  - Create new user
  - Generate 5 stories
  - Watch "Emerald Green" unlock
  - Verify celebration triggers
  - Verify item now selectable
□ Balance unlock timing:
  - Not too easy (keep items special)
  - Not too hard (don't frustrate users)
□ Deploy to production

Time Estimate: Full day
Deliverable: Gamification UI polished
```

### Agent 3 (QA/Integration - Gamification Testing)
**Focus: Test entire progression system**
```
Priority: Verify gamification creates engagement

Tasks:
□ Create fresh user account
□ Document progression journey:
  Story 1: Character created
  - Verify only default customizations available
  - Verify locked items show with lock icons
  Story 5: First unlock
  - Verify "Emerald Green" hair unlocks
  - Verify unlock animation triggers
  - Verify can now select Emerald Green
  Story 10: Second unlock
  - Verify "Magic Wand" accessory unlocks
  - Verify celebration
  Story 15: Third unlock
  - Verify "Star Crown" hat unlocks
  Story 20: Fourth unlock
  - Verify "Rose Gold" hair unlocks
  Story 25: Fifth unlock
  - Verify "Dragon Pet" unlocks
□ Test unlockables gallery:
  - Verify all items shown
  - Verify locked items grayed out
  - Verify progress bars accurate
  - Verify unlock requirements clear
□ Test premium unlockables:
  - Verify marked as "Premium"
  - Verify unlock only with subscription
□ Get user feedback:
  - Ask: "Does progression feel rewarding?"
  - Ask: "Are unlock requirements fair?"
  - Ask: "Do you want to create more stories to unlock?"
□ Document in GAMIFICATION_TEST.md

Time Estimate: Full day
Deliverable: Gamification verified engaging
```

**End of Day 13 Success Criteria:**
- ✅ Unlockable system creates progression
- ✅ UI shows progression clearly
- ✅ Users motivated to create more stories

---

## Day 14-16: Final Polish & Deployment

### Agent 1 (Backend) - Days 14-16

**Day 14: Bug Fixes**
```
□ Review all bugs reported by Agent 3
□ Prioritize: Critical, High, Medium, Low
□ Fix all Critical and High bugs
□ Test fixes
□ Deploy to staging
```

**Day 15: Production Prep**
```
□ Update Railway environment variables:
  - Set strong SECRET_KEY (not default)
  - Set strong JWT_SECRET_KEY
  - Verify OPENAI_API_KEY
  - Set Stripe production keys
  - Set STRIPE_WEBHOOK_SECRET
□ Set up Sentry error monitoring
□ Configure production logging
□ Test database connection
□ Create deployment script
□ Run database migrations on production DB
```

**Day 16: Deploy & Monitor**
```
□ Deploy backend to Railway production
□ Monitor logs for first 2 hours
□ Verify all endpoints responding
□ Test critical features in production
□ Set up uptime monitoring (UptimeRobot)
□ Create incident response plan
□ Document deployment in PRODUCTION_DEPLOY.md
```

### Agent 2 (Frontend) - Days 14-16

**Day 14: Bug Fixes**
```
□ Fix all UI bugs reported by Agent 3
□ Polish animations based on feedback
□ Fix any visual inconsistencies
□ Improve error messages
□ Test all fixes
```

**Day 15: Production Build**
```
□ Update lib/config/environment.dart:
  - Set production API URL
  - Remove debug flags
  - Set production analytics
□ Remove all debug logging
□ Build production Flutter web bundle:
  flutter build web --release
□ Optimize bundle size
□ Test production build locally
□ Verify no console errors
```

**Day 16: Deploy & Verify**
```
□ Deploy to production hosting (Netlify/Vercel)
□ Configure production domain
□ Set up SSL certificates
□ Test production environment:
  - App loads
  - API calls work (CORS configured)
  - Images load
  - Payments work
□ Create FRONTEND_DEPLOY.md
```

### Agent 3 (QA) - Days 14-16

**Day 14: Final Regression**
```
□ Complete regression test of ALL features:
  - Age gate
  - Character creation
  - Feelings wheel
  - Story generation (standard)
  - Story generation (interactive)
  - Image generation
  - Story saving
  - Story sharing
  - Subscription management
  - Parent dashboard
  - Achievement unlocking
  - Unlockable items
□ Test on real devices (not emulators)
□ Create prioritized bug list
□ Document in FINAL_REGRESSION.md
```

**Day 15: Staging Environment**
```
□ Deploy to staging environment
□ Run full smoke test
□ Test payment flow (Stripe test mode)
□ Verify webhooks work
□ Test email notifications
□ Load test with realistic traffic
□ Create deployment checklist
□ Document in STAGING_TEST.md
```

**Day 16: Production Verification**
```
□ Smoke test in production:
  - User registration
  - Age gate flow
  - Character creation
  - Story generation
  - Image generation
  - Subscription purchase (small $1 test)
  - Webhook triggers
  - Dashboard displays correctly
□ Monitor error logs for first 4 hours
□ Create incident response plan
□ Document in PRODUCTION_VERIFICATION.md
□ Celebrate! 🎉
```

**End of Week 3 / Full Plan Success Criteria:**
- ✅ All features working
- ✅ App secure
- ✅ Subscriptions automated
- ✅ UX delightful and magical
- ✅ Deployed to production
- ✅ Monitoring in place
- ✅ **Ready for users!**

---

# Days 17-21: Buffer & Enhancement

Use as needed for:
- Production hotfixes
- User feedback incorporation
- Performance optimization
- App store preparation
- Marketing materials
- Story Arcs feature (if time)
- Voice narration (if time)
- Additional polish

---

# Agent Coordination Rules

1. **Daily Standup (async):**
   - Each agent updates DAILY_STATUS.md at start of day
   - List: What I'm working on today
   - List: What I need from other agents
   - List: Blockers

2. **No Overlapping Files:**
   - Agent 1: Only touches `backend/`
   - Agent 2: Only touches `lib/` and frontend files
   - Agent 3: Only touches test files and documentation
   - Exception: Agent 3 can read anything for testing

3. **Communication:**
   - Use BUG_REPORT.md for bugs
   - Use FEATURE_REQUEST.md for new features
   - Use BLOCKERS.md if stuck waiting on another agent

4. **End of Day:**
   - Each agent updates DAILY_STATUS.md with:
     - ✅ What got done
     - 🚧 What's in progress
     - ⏭️ What's next for tomorrow

5. **Testing Gates:**
   - Agent 3 must verify before moving to next day
   - If Agent 3 finds critical bug, day repeats
   - No moving forward with broken features

---

This plan ensures all 3 agents work in parallel without conflicts while building a functional, secure, and magical app.
