# 21-Day Master Production Launch Plan
**Story Weaver App - Comprehensive Launch Strategy**
**Created:** 2025-11-10
**Target Launch:** Day 21 (2025-12-01)
**Incorporates:** Gemini's architecture + Codex's production readiness + Claude's additions

---

## 🎯 Mission

Launch a **scalable, secure, monetizable** therapeutic storytelling app that:
- ✅ Works reliably for 100+ concurrent users
- ✅ Protects user data and prevents revenue leakage
- ✅ Processes payments through real app stores
- ✅ Provides measurable therapeutic value
- ✅ Has clean, maintainable code for future growth

---

## 📊 Combined Priority Framework

### Sources Integrated:
- 🔵 **Gemini:** Architecture, scalability, code quality (10 items)
- 🟠 **Codex:** Production, security, monetization (10 items)
- 🟢 **Claude:** Analytics, onboarding, final polish (3 items)

**Total: 23 improvements across 21 days**

---

## 📅 The 21-Day Roadmap

### **WEEK 1: Critical Infrastructure** (Days 1-7)
**Theme:** Make it work at scale, protect revenue, enable debugging

### **WEEK 2: Architecture & Revenue** (Days 8-14)
**Theme:** Clean code, real billing, beta testing

### **WEEK 3: Polish & Launch** (Days 15-21)
**Theme:** Professional UX, final testing, confident launch

---

## Week 1: Foundation (Days 1-7)

### **Day 1: Database & Configuration** 🚨
**Owner:** Claude
**Goal:** Scalable database + single source of truth for URLs

#### Morning: PostgreSQL Migration
- [ ] **Provision PostgreSQL on Railway** (Gemini #4)
  - Add PostgreSQL service to Railway project
  - Get connection string from Railway
  - Update `backend/app.py`:
    ```python
    DATABASE_URL = os.getenv('DATABASE_URL')  # Railway provides
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL
    ```

- [ ] **Create migration script**
  ```python
  # migrate_sqlite_to_postgres.py
  import sqlite3
  import psycopg2
  # Export all characters from SQLite
  # Import into PostgreSQL
  ```

- [ ] **Test character CRUD with PostgreSQL**

#### Afternoon: Centralize Backend URLs
- [ ] **Fix hardcoded URLs** (Codex #2 + Gemini #5)
  - Search codebase for `http://127.0.0.1:5000`
  - Replace ALL instances with `Environment.backendUrl`
  - Files to update:
    - `lib/main_story.dart` (multiple locations)
    - `lib/character_creation_screen_enhanced.dart`
    - `lib/character_edit_screen.dart`
    - `lib/character_gallery_screen.dart`
    - Any other API calls

- [ ] **Verify all endpoints use centralized URL**
  - Test character creation
  - Test story generation
  - Test interactive stories

**Deliverable:** App uses PostgreSQL and has single backend URL configuration

---

### **Day 2: Async Task Queue** 🚨
**Owner:** Claude
**Goal:** Non-blocking story generation

#### Morning: Set Up Redis + Celery
- [ ] **Provision Redis on Railway** (Gemini #3)
  - Add Redis service
  - Get `REDIS_URL` from Railway

- [ ] **Install Celery in backend**
  ```bash
  cd backend
  pip install celery redis
  pip freeze > requirements.txt
  ```

- [ ] **Create `backend/celery_config.py`**
  ```python
  from celery import Celery
  import os

  celery = Celery(
      'story_weaver',
      broker=os.getenv('REDIS_URL'),
      backend=os.getenv('REDIS_URL')
  )

  @celery.task(bind=True)
  def generate_story_task(self, prompt):
      # Move Gemini API call here
      response = model.generate_content(prompt)
      return response.text
  ```

#### Afternoon: Refactor API Endpoints
- [ ] **Update `/generate-story` endpoint**
  ```python
  @app.route('/generate-story', methods=['POST'])
  def generate_story():
      # Build prompt
      task = generate_story_task.delay(prompt)
      return jsonify({'task_id': task.id}), 202
  ```

- [ ] **Create `/task-status/<task_id>` endpoint**
  ```python
  @app.route('/task-status/<task_id>')
  def task_status(task_id):
      task = generate_story_task.AsyncResult(task_id)
      if task.ready():
          return jsonify({
              'status': 'complete',
              'result': task.result
          })
      return jsonify({'status': 'pending', 'progress': task.info})
  ```

- [ ] **Update frontend to poll for completion**
  - Modify `ApiServiceManager._generateStoryWithBackend`
  - Add loading states with progress
  - Test end-to-end

**Deliverable:** Stories generate asynchronously, app doesn't freeze

---

### **Day 3-4: Testing Framework** ✅
**Owner:** Claude + Codex
**Goal:** Prevent regressions, enable confident deployment

#### Day 3: Backend Tests (Gemini #9)
- [ ] **Set up Pytest**
  ```bash
  cd backend
  pip install pytest pytest-flask
  mkdir tests
  ```

- [ ] **Write API endpoint tests**
  ```python
  # tests/test_api.py
  def test_generate_story_returns_task_id(client):
      response = client.post('/generate-story', json={
          'character': 'Test',
          'theme': 'Adventure',
          'character_age': 7
      })
      assert response.status_code == 202
      assert 'task_id' in response.json
  ```

- [ ] **Write service tests**
  - Test prompt generation
  - Test emotion extraction
  - Test feelings wheel data parsing

- [ ] **Write model tests**
  - Test Character CRUD operations
  - Test relationship fields (siblings, friends)

#### Day 4: Frontend Tests (Codex #6)
- [ ] **Set up Flutter test framework**
  ```bash
  flutter test
  ```

- [ ] **Write widget tests**
  - Character creation form validation
  - Feelings wheel selection
  - Age-appropriate mode toggles

- [ ] **Write integration tests** (Codex specific scenarios)
  - Mock `ApiServiceManager`
  - Test: feelings wheel data flows into prompts
  - Test: paywall limits behave correctly
  - Test: offline caching works

- [ ] **Add to CI/CD**
  - Create `.github/workflows/test.yml`
  - Run tests on every PR
  - Add coverage reporting

**Deliverable:** Core flows have test coverage, CI/CD running

---

### **Day 5: Secure Storage** 🔐
**Owner:** Claude
**Goal:** Protect API keys and prevent revenue leakage (Codex #4)

- [ ] **Install flutter_secure_storage**
  ```yaml
  # pubspec.yaml
  dependencies:
    flutter_secure_storage: ^9.0.0
  ```

- [ ] **Migrate API keys from SharedPreferences**
  ```dart
  // Before: ApiServiceManager
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('user_api_key');

  // After:
  final secureStorage = FlutterSecureStorage();
  final apiKey = await secureStorage.read(key: 'user_api_key');
  ```

- [ ] **Migrate subscription data**
  - Move premium status to secure storage
  - Prevents rooted devices from bypassing paywall

- [ ] **Test on both platforms**
  - iOS: Uses Keychain
  - Android: Uses Keystore

**Deliverable:** User secrets are encrypted and secure

---

### **Day 6: Crash Reporting** 📊
**Owner:** Claude
**Goal:** Debug production issues (Codex #5)

- [ ] **Set up Sentry**
  ```bash
  flutter pub add sentry_flutter
  ```

- [ ] **Initialize in main.dart**
  ```dart
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

- [ ] **Wrap async story generation**
  ```dart
  try {
    final story = await ApiServiceManager.generateStory(...);
  } catch (e, stackTrace) {
    await Sentry.captureException(e, stackTrace: stackTrace);
    rethrow;
  }
  ```

- [ ] **Add breadcrumbs for debugging**
  - Log: feelings wheel selection
  - Log: API request parameters
  - Log: paywall interactions

- [ ] **Test error reporting**
  - Trigger test error
  - Verify in Sentry dashboard

**Deliverable:** Production errors reach team with full context

---

### **Day 7: Start Real Billing** 💰
**Owner:** Claude
**Goal:** Begin IAP integration (Codex #8)

- [ ] **Set up in-app purchases package**
  ```yaml
  dependencies:
    in_app_purchase: ^3.1.13
  ```

- [ ] **Configure App Store Connect (iOS)**
  - Create IAP products (monthly, yearly subscriptions)
  - Set pricing tiers
  - Submit for review

- [ ] **Configure Google Play Console (Android)**
  - Create IAP products
  - Set pricing
  - Submit for review

- [ ] **Create `RealBillingService`**
  ```dart
  class RealBillingService {
    Future<void> purchaseSubscription(String productId) async {
      // Call in_app_purchase
      // Verify receipt server-side
      // Update user entitlements
    }
  }
  ```

- [ ] **Design receipt verification endpoint**
  ```python
  @app.route('/verify-receipt', methods=['POST'])
  def verify_receipt():
      # Verify with Apple/Google
      # Store receipt in database
      # Return entitlement status
  ```

**Deliverable:** IAP products created, integration started (continues Day 8)

---

## Week 2: Architecture & Revenue (Days 8-14)

### **Day 8: Complete Billing Integration** 💰
**Owner:** Claude
**Goal:** Real payments working end-to-end (Codex #8)

- [ ] **Implement receipt verification**
  - Add Apple App Store verification
  - Add Google Play verification
  - Store receipts in PostgreSQL

- [ ] **Update SubscriptionService**
  - Replace local JSON with real billing
  - Sync entitlements with server
  - Handle subscription lifecycle (renew, cancel, expire)

- [ ] **Add restore purchases**
  - Users can restore on new devices
  - Sync with server-side state

- [ ] **Test payment flow**
  - Purchase subscription in sandbox
  - Verify entitlements unlock features
  - Test restore purchases

**Deliverable:** Real payments work, revenue is tracked

---

### **Day 9: Backend Resilience** 🔄
**Owner:** Claude
**Goal:** Handle flaky networks gracefully (Codex #7)

- [ ] **Add retry logic to ApiServiceManager**
  ```dart
  Future<String> _generateStoryWithRetry() async {
    int attempts = 0;
    while (attempts < 3) {
      try {
        return await _generateStoryWithBackend(...);
      } catch (e) {
        attempts++;
        if (attempts >= 3) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
  }
  ```

- [ ] **Add timeouts**
  ```dart
  final response = await http.post(url, body: body)
      .timeout(Duration(seconds: 30));
  ```

- [ ] **Improve error messages**
  - Network error: "Check your connection and try again"
  - Server error: "Our story engine is taking a break"
  - Timeout: "This is taking longer than usual, try again?"

- [ ] **Add exponential backoff**
  - First retry: 2s
  - Second retry: 4s
  - Third retry: 8s

**Deliverable:** App handles network issues gracefully

---

### **Day 10-11: State Management Refactor** 🏗️
**Owner:** Claude
**Goal:** Clean up "God Class" (Gemini #1)

#### Day 10: Implement Riverpod
- [ ] **Install Riverpod**
  ```yaml
  dependencies:
    flutter_riverpod: ^2.4.9
  ```

- [ ] **Create providers**
  ```dart
  // lib/providers/character_provider.dart
  final charactersProvider = StateNotifierProvider<CharacterNotifier, List<Character>>((ref) {
    return CharacterNotifier();
  });

  // lib/providers/story_provider.dart
  final storyGenerationProvider = FutureProvider.family<String, StoryParams>((ref, params) async {
    return ApiServiceManager.generateStory(...);
  });
  ```

- [ ] **Refactor `_StoryScreenState`**
  - Extract state to providers
  - Remove `setState` calls
  - Use `ref.watch` and `ref.read`

#### Day 11: Complete Refactor
- [ ] **Update remaining screens**
  - Character creation
  - Story result
  - Insights dashboard

- [ ] **Add loading/error states**
  - Use `AsyncValue` for async operations
  - Show loading spinners
  - Show error messages

- [ ] **Test thoroughly**
  - Verify all features still work
  - Check for performance improvements
  - Fix any regressions

**Deliverable:** Clean architecture, better performance

---

### **Day 12-13: Backend Modularization** 🏗️
**Owner:** Claude
**Goal:** Organize 1000-line God File (Gemini #2)

#### Day 12: Create Module Structure
- [ ] **Create folder structure**
  ```
  backend/
    models/
      character.py
      story.py
    routes/
      character_routes.py
      story_routes.py
    services/
      story_generation_service.py
      emotion_service.py
    app.py
  ```

- [ ] **Extract Character model**
  ```python
  # backend/models/character.py
  from extensions import db

  class Character(db.Model):
      # Move model definition here
  ```

- [ ] **Extract route handlers**
  ```python
  # backend/routes/story_routes.py
  from flask import Blueprint

  story_bp = Blueprint('story', __name__)

  @story_bp.route('/generate-story', methods=['POST'])
  def generate_story():
      # Move handler here
  ```

#### Day 13: Complete Refactor
- [ ] **Extract services**
  - `StoryGenerationService` - Prompt building, AI calls
  - `EmotionService` - Feelings wheel data handling
  - `PromptService` - Age-appropriate guidelines

- [ ] **Update app.py**
  ```python
  from routes.story_routes import story_bp
  from routes.character_routes import character_bp

  app.register_blueprint(story_bp)
  app.register_blueprint(character_bp)
  ```

- [ ] **Update tests**
  - Adjust imports
  - Verify all tests pass

**Deliverable:** Clean, maintainable backend structure

---

### **Day 14: Server-Side Sync + Beta Release** 🚀
**Owner:** Claude
**Goal:** Multi-device support, launch beta (Codex #9)

#### Morning: User Accounts & Sync
- [ ] **Add user authentication**
  ```python
  # Simple email + password for MVP
  # Use Firebase Auth or Auth0 for production
  ```

- [ ] **Sync progression data**
  - Mirror `ProgressionService` to backend
  - API: `/sync-progression`
  - Store per user account

- [ ] **Sync unlocked achievements**
  - Store in PostgreSQL per user
  - Return on login

#### Afternoon: Beta Release
- [ ] **Deploy to beta testers**
  - Upload to TestFlight (iOS)
  - Upload to Internal Testing (Android)
  - Share links with 5-10 beta testers

- [ ] **Create feedback form**
  - Google Form or Typeform
  - Questions:
    - Does story generation work?
    - Is the feelings wheel intuitive?
    - Would you pay for this?
    - What's missing?

- [ ] **Monitor metrics**
  - Crash rate
  - Story generation success rate
  - Feelings wheel usage
  - Time to first story

**Deliverable:** App in beta testers' hands, collecting feedback

---

## Week 3: Polish & Launch (Days 15-21)

### **Day 15: Build Flavors & Environment Switching** ⚙️
**Owner:** Claude
**Goal:** Clean staging/prod separation (Codex #3)

- [ ] **Set up build flavors**
  ```dart
  // lib/config/flavor_config.dart
  enum Flavor { development, staging, production }

  class FlavorConfig {
    final Flavor flavor;
    final String backendUrl;

    FlavorConfig({required this.flavor, required this.backendUrl});
  }
  ```

- [ ] **Configure launch configs**
  ```json
  // .vscode/launch.json
  {
    "configurations": [
      {
        "name": "Development",
        "args": ["--dart-define=FLAVOR=development"]
      },
      {
        "name": "Production",
        "args": ["--dart-define=FLAVOR=production"]
      }
    ]
  }
  ```

- [ ] **Update build commands**
  ```bash
  # Development
  flutter run --dart-define=FLAVOR=development

  # Production
  flutter build web --dart-define=FLAVOR=production
  flutter build apk --dart-define=FLAVOR=production
  ```

**Deliverable:** Easy switching between environments

---

### **Day 16: Offline Improvements** 📱
**Owner:** Codex
**Goal:** Better offline UX (Gemini #6)

- [ ] **Install Isar database**
  ```yaml
  dependencies:
    isar: ^3.1.0
    isar_flutter_libs: ^3.1.0
  ```

- [ ] **Define schemas**
  ```dart
  @collection
  class CachedStory {
    Id id = Isar.autoIncrement;
    late String title;
    late String storyText;
    late String theme;
    late DateTime createdAt;
  }
  ```

- [ ] **Implement offline-first pattern**
  1. Check Isar cache first
  2. Show cached data immediately
  3. Fetch from API in background
  4. Update UI when fresh data arrives

- [ ] **Add sync indicator**
  - Show "Syncing..." when fetching
  - Show "Offline" when no connection
  - Show "Synced" when up-to-date

**Deliverable:** App works great offline

---

### **Day 17: UX Polish** ✨
**Owner:** Codex
**Goal:** Professional user experience

#### Morning: Complete TODOs
- [ ] **StoryResultScreen polish** (Codex #10)
  - Hydrate avatar appearance
  - Pull character outfit data
  - Add export/share options
  - Tie into celebration dialogs

- [ ] **Onboarding flow** (Claude addition)
  - First-time user tutorial
  - Show value before paywall
  - Quick "Create your first story" guide
  - Feelings wheel tutorial

#### Afternoon: General Polish
- [ ] **Consistent loading states**
  - Same spinner everywhere
  - Same animation timing
  - Same colors

- [ ] **Better error messages**
  - User-friendly language
  - Actionable suggestions
  - Contact support option

- [ ] **Smooth transitions**
  - Hero animations
  - Fade transitions
  - Page route animations

- [ ] **Responsive design**
  - Test on small phones
  - Test on tablets
  - Test on web

**Deliverable:** App feels polished and professional

---

### **Day 18: Analytics Integration** 📊
**Owner:** Claude
**Goal:** Measure what matters (Claude addition)

- [ ] **Set up Firebase Analytics**
  ```yaml
  dependencies:
    firebase_analytics: ^10.7.4
  ```

- [ ] **Track key events**
  ```dart
  analytics.logEvent(
    name: 'story_created',
    parameters: {
      'character_age': age,
      'theme': theme,
      'used_feelings_wheel': currentFeeling != null,
      'story_mode': learningToReadMode ? 'learning' : 'regular',
    },
  );
  ```

- [ ] **Track funnels**
  - Character creation started → completed
  - Story creation started → completed
  - Feelings check-in shown → completed
  - Paywall shown → converted

- [ ] **Track retention metrics**
  - Daily active users (DAU)
  - Weekly active users (WAU)
  - Story streak lengths
  - Churn rate

- [ ] **Set up dashboards**
  - Firebase Console
  - Key metrics at a glance

**Deliverable:** Data-driven decision making enabled

---

### **Day 19: Documentation** 📚
**Owner:** Claude
**Goal:** Two readmes for two audiences

#### Morning: User-Facing README (Codex #1)
- [ ] **Create README.md**
  - Project purpose and value proposition
  - Screenshots of key features
  - "Create a story in 3 steps" guide
  - Download links (App Store, Play Store)
  - Pricing tiers explanation
  - Contact/support information

- [ ] **Add screenshots**
  - Character creation
  - Feelings wheel
  - Generated story
  - Insights dashboard

#### Afternoon: Developer ARCHITECTURE.md (Gemini #10)
- [ ] **Create ARCHITECTURE.md**
  - System overview diagram
  - Frontend architecture (Riverpod providers)
  - Backend architecture (routes/services/models)
  - Database schema
  - API endpoints documentation
  - Deployment process

- [ ] **Add code documentation**
  - Docstrings on all public methods
  - Explain complex algorithms
  - Document therapeutic story approach

**Deliverable:** Project is well-documented for users and developers

---

### **Day 20: Final Testing & Bug Bash** 🐛
**Owner:** Everyone
**Goal:** Find and fix all critical bugs

- [ ] **Internal testing**
  - Test all user flows end-to-end
  - Test on iOS, Android, Web
  - Test with slow/no network
  - Test error scenarios

- [ ] **Review beta feedback**
  - Address all critical issues
  - Fix high-priority bugs
  - Document known issues

- [ ] **Performance testing**
  - Profile slow screens
  - Optimize image loading
  - Check memory leaks
  - Verify story generation is fast

- [ ] **Security audit**
  - Verify secure storage works
  - Test paywall can't be bypassed
  - Check API keys are encrypted
  - Test receipt verification

- [ ] **Accessibility check**
  - Font scaling works
  - Color contrast passes
  - Screen reader compatible

**Deliverable:** App is thoroughly tested and polished

---

### **Day 21: Launch Day** 🚀
**Owner:** Claude
**Goal:** Go live with confidence

#### Morning: Final Deployment
- [ ] **Deploy backend to Railway**
  - Verify all environment variables set
  - Run database migrations
  - Test health endpoint

- [ ] **Deploy frontend**
  - Flutter web to Netlify
  - Submit iOS app to App Store
  - Submit Android app to Play Store

- [ ] **Configure production services**
  - Enable Sentry monitoring
  - Set up database backups
  - Configure rate limiting
  - Set up uptime monitoring

#### Afternoon: Launch Activities
- [ ] **Create launch materials**
  - App Store listing (screenshots, description)
  - Social media announcement
  - Demo video
  - Landing page (if needed)

- [ ] **Soft launch**
  - Share with small group
  - Monitor for critical issues
  - Quick fixes if needed

- [ ] **Public launch**
  - Publish to app stores
  - Social media announcement
  - Notify beta testers
  - Monitor Sentry for errors
  - Monitor Firebase Analytics

#### Evening: Celebrate! 🎉
- [ ] **Review metrics**
  - Crash-free rate > 99.5%
  - Story generation success rate > 95%
  - Average time to first story < 5 minutes

- [ ] **Document launch**
  - What went well
  - What could be better
  - Lessons learned

**Deliverable:** Story Weaver App is live! 🎊

---

## 📋 Implementation Checklist

### Critical Path Items (Can't Launch Without)
- [x] PostgreSQL database
- [x] Async task queue
- [x] Secure storage for API keys
- [x] Real billing integration
- [x] Crash reporting
- [x] Testing framework
- [x] Server-side sync
- [x] Documentation

### High Value Items (Should Launch With)
- [x] State management refactor
- [x] Backend modularization
- [x] Backend resilience
- [x] Offline improvements
- [x] Analytics integration
- [x] Build flavors
- [x] UX polish

### Nice-to-Have Items (Can Ship After)
- [ ] Parent dashboard (post-launch)
- [ ] Advanced gamification (post-launch)
- [ ] A/B testing framework (post-launch)

---

## 🎯 Success Metrics

### By Day 21, the app must:
1. ✅ Generate stories reliably (< 2% error rate)
2. ✅ Handle 100+ concurrent users without blocking
3. ✅ Store data persistently in PostgreSQL with backups
4. ✅ Process real payments through app stores
5. ✅ Work offline (cached stories and characters)
6. ✅ Track emotional check-ins (pre + post story)
7. ✅ Report crashes and errors automatically
8. ✅ Have test coverage on critical paths (> 70%)
9. ✅ Be fully documented (user + developer)
10. ✅ Be deployed to production with monitoring

### Key Performance Indicators (KPIs)
- **Crash-free rate:** > 99.5%
- **Story generation success:** > 95%
- **Average time to first story:** < 5 minutes
- **Paywall conversion rate:** Track baseline
- **Feelings wheel usage rate:** Track baseline
- **Daily active users (DAU):** Track baseline
- **Story creation rate:** Track baseline

---

## 🆘 Risk Management

### High Risk Items
1. **IAP approval delays** - Start Day 7, allow 7 days for review
2. **Celery/Redis complexity** - Have fallback to synchronous if needed
3. **Beta tester availability** - Recruit early, have backups
4. **App store rejection** - Follow guidelines strictly

### Mitigation Strategies
- **Daily standups** - Check progress, adjust plan
- **Parallel work** - Frontend/backend can work independently
- **MVP fallbacks** - Can ship without some features if needed
- **Extra buffer** - Days 20-21 are mostly polish

---

## 📈 Post-Launch Roadmap (Days 22-30)

### Week 4: Monitor & Iterate
- Monitor production metrics daily
- Fix critical bugs within 24 hours
- Collect user feedback
- A/B test paywall copy and pricing

### Weeks 5-8: Growth Features
- Parent dashboard v1
- Advanced gamification
- Referral program
- Social sharing features

---

## 🎓 Lessons from the AI Audits

### What Gemini Taught Us:
- Architecture matters for scale
- God classes hurt maintainability
- Async operations are critical
- Testing enables confident deployment

### What Codex Taught Us:
- Security enables monetization
- Real billing is non-negotiable
- Polish creates paid conversions
- Production reliability matters

### What Claude Added:
- Analytics drives optimization
- Onboarding affects retention
- Both perspectives are essential
- 21 days is perfect for quality + speed

---

## 🚀 Let's Ship This!

**The plan is comprehensive, realistic, and achievable.**

You have:
- ✅ Clear daily objectives
- ✅ Realistic timelines
- ✅ All critical improvements
- ✅ Risk mitigation strategies
- ✅ Success criteria

**Next steps:**
1. Review and approve this plan
2. Fix Railway API key issue
3. Start Day 1 tomorrow
4. Ship confidently on Day 21

**Ready to build something amazing? Let's go! 🎉**
