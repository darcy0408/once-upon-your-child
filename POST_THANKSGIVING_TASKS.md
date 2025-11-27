# Post-Thanksgiving Task List

**Created:** 2025-11-26
**Status:** App is LIVE and working for Thanksgiving demo
**Next Phase:** Code quality improvements on feature branches

---

## 🎯 Overview

These tasks will be completed on **feature branches** to keep `main` branch stable. Each agent will work on their own branch, and we'll merge after thorough testing.

**Branch Strategy:**
- `main` - Always stable, always deployed to production
- `refactor/backend-modularization` - Backend cleanup (Grok)
- `feature/state-management` - Frontend state refactor (Codex 1)
- `feature/offline-first` - Isar database (Codex 2)
- `feature/security-hardening` - Secure storage + crash reporting (Grok)
- `feature/mobile-iap` - In-app purchases (Codex 1)
- `feature/celery-integration` - Async task queue (Grok)

---

## 📊 Priority Matrix

| Priority | Task | Agent | Branch | Risk | Days |
|----------|------|-------|--------|------|------|
| 🔴 HIGH | Backend Modularization | Grok | `refactor/backend-modularization` | Medium | 2 |
| 🔴 HIGH | Secure Storage | Grok | `feature/security-hardening` | Low | 1 |
| 🔴 HIGH | Crash Reporting | Grok | `feature/security-hardening` | Low | 1 |
| 🟡 MEDIUM | Celery Integration | Grok | `feature/celery-integration` | High | 2 |
| 🟡 MEDIUM | Offline-First (Isar) | Codex 2 | `feature/offline-first` | Medium | 3 |
| 🟡 MEDIUM | State Management | Codex 1 | `feature/state-management` | High | 3 |
| 🟡 MEDIUM | Fix Accessibility (Semantics) | Codex 1 | `feature/accessibility-fix` | Medium | 0.5 |
| 🟢 LOW | Mobile IAP | Codex 1 | `feature/mobile-iap` | Medium | 2 |

---

## 🎯 GROK - Backend Infrastructure Tasks

### **Task 1: Backend Modularization (2 days, HIGH PRIORITY)**

**Branch:** `refactor/backend-modularization`

**Current State:**
- `app.py` is 1,128 lines with 21 routes still defined directly
- Models and services are already modularized ✅
- Only 3 blueprints are registered (stripe, webhook, analytics)

**Goal:** Reduce `app.py` to <300 lines by extracting all routes to blueprints

**Steps:**

1. **Create the feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b refactor/backend-modularization
   ```

2. **Create missing blueprint files:**
   ```bash
   # Create these files in backend/routes/
   backend/routes/story_routes.py         # Story generation routes
   backend/routes/character_routes.py     # Character CRUD routes
   backend/routes/admin_routes.py         # Admin endpoints
   backend/routes/health_routes.py        # Health check, version
   ```

3. **Extract routes by category:**

   **A. Story Routes (`backend/routes/story_routes.py`):**
   - `/generate-story` (POST)
   - `/generate-interactive-story` (POST)
   - `/continue-interactive-story` (POST)
   - `/save-story` (POST)
   - `/get-stories` (GET)
   - `/stories/<story_id>` (GET, PATCH, DELETE)
   - `/report-story` (POST)

   **B. Character Routes (`backend/routes/character_routes.py`):**
   - `/create-character` (POST)
   - `/get-characters` (GET)
   - `/characters/<char_id>` (GET, PATCH, PUT, DELETE)

   **C. Admin Routes (`backend/routes/admin_routes.py`):**
   - `/admin/analytics/*` (already in analytics_bp, just verify)
   - `/admin/run-db-optimization` (POST)
   - `/admin/cost-report` (GET) - already in analytics_bp

   **D. Health Routes (`backend/routes/health_routes.py`):**
   - `/health` (GET)
   - `/version` (GET)

4. **Blueprint Template:**
   ```python
   # backend/routes/story_routes.py
   from flask import Blueprint, request, jsonify
   from ..database import db
   from ..models.story import Story
   from ..models.user import User
   from ..services.story_service import StoryService

   story_bp = Blueprint('story', __name__)

   @story_bp.route('/generate-story', methods=['POST'])
   def generate_story():
       # Move implementation from app.py here
       pass

   @story_bp.route('/save-story', methods=['POST'])
   def save_story():
       # Move implementation from app.py here
       pass

   # ... etc
   ```

5. **Update `app.py` to register all blueprints:**
   ```python
   # After line 341 where analytics_bp is registered:
   from .routes.story_routes import story_bp
   from .routes.character_routes import character_bp
   from .routes.admin_routes import admin_bp
   from .routes.health_routes import health_bp

   app.register_blueprint(story_bp)
   app.register_blueprint(character_bp)
   app.register_blueprint(admin_bp)
   app.register_blueprint(health_bp)
   ```

6. **Test locally:**
   ```bash
   cd backend
   .venv/Scripts/activate  # Windows
   python -m pytest tests/ -v
   flask run
   # Test each endpoint with curl/Postman
   ```

7. **Commit to feature branch:**
   ```bash
   git add backend/routes/*.py backend/app.py
   git commit -m "Refactor: Extract 21 routes from app.py to blueprints

   - Create story_routes.py with 7 story endpoints
   - Create character_routes.py with 5 character endpoints
   - Create admin_routes.py with admin endpoints
   - Create health_routes.py with health/version
   - app.py reduced from 1,128 to ~300 lines

   All tests passing. Ready for review.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin refactor/backend-modularization
   ```

8. **DO NOT MERGE YET** - Wait for testing and approval

**Success Criteria:**
- ✅ `app.py` is <300 lines
- ✅ All 21 routes moved to appropriate blueprints
- ✅ All pytest tests pass
- ✅ Backend starts without errors
- ✅ `/health` endpoint returns 200 OK

---

### **Task 2: Secure Storage (1 day, HIGH PRIORITY)**

**Branch:** `feature/security-hardening`

**Current State:**
- API keys stored in SharedPreferences (insecure, plain text)
- No encryption for sensitive data

**Goal:** Use `flutter_secure_storage` for all sensitive data

**Steps:**

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/security-hardening
   ```

2. **Add dependency:**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_secure_storage: ^9.0.0
   ```

3. **Create secure storage service:**
   ```dart
   // lib/services/secure_storage_service.dart
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';

   class SecureStorageService {
     static const _storage = FlutterSecureStorage();

     // API Keys
     static Future<void> saveApiKey(String key, String value) async {
       await _storage.write(key: 'api_key_$key', value: value);
     }

     static Future<String?> getApiKey(String key) async {
       return await _storage.read(key: 'api_key_$key');
     }

     // User tokens
     static Future<void> saveUserToken(String token) async {
       await _storage.write(key: 'user_token', value: token);
     }

     static Future<String?> getUserToken() async {
       return await _storage.read(key: 'user_token');
     }

     // Delete all secure data (logout)
     static Future<void> deleteAll() async {
       await _storage.deleteAll();
     }
   }
   ```

4. **Migrate existing API key storage:**
   - Find all `SharedPreferences` usages for API keys
   - Replace with `SecureStorageService`
   - Files to update:
     - `lib/services/api_service_manager.dart` (lines 74-76)
     - `lib/screens/byok_setup_wizard.dart`
     - Any other files storing sensitive data

5. **Add migration helper:**
   ```dart
   // One-time migration from SharedPreferences to SecureStorage
   Future<void> migrateToSecureStorage() async {
     final prefs = await SharedPreferences.getInstance();
     final oldApiKey = prefs.getString('gemini_api_key');
     if (oldApiKey != null) {
       await SecureStorageService.saveApiKey('gemini', oldApiKey);
       await prefs.remove('gemini_api_key');
     }
   }
   ```

6. **Test:**
   ```bash
   flutter test
   flutter run
   # Test BYOK flow, verify API keys work
   ```

7. **Commit:**
   ```bash
   git add .
   git commit -m "Security: Implement secure storage for API keys and tokens

   - Add flutter_secure_storage package
   - Create SecureStorageService wrapper
   - Migrate API keys from SharedPreferences
   - Add one-time migration helper
   - Update all sensitive data access points

   Fixes insecure plain-text API key storage.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin feature/security-hardening
   ```

**Success Criteria:**
- ✅ `flutter_secure_storage` added to pubspec.yaml
- ✅ All API keys use SecureStorageService
- ✅ Migration from SharedPreferences works
- ✅ Tests pass
- ✅ BYOK flow still works

---

### **Task 3: Crash Reporting (1 day, HIGH PRIORITY)**

**Branch:** `feature/security-hardening` (same as secure storage)

**Current State:**
- No crash reporting
- Errors are lost if app crashes

**Goal:** Add Sentry for crash and error tracking

**Steps:**

1. **Already on feature branch from Task 2**

2. **Add dependency:**
   ```yaml
   # pubspec.yaml
   dependencies:
     sentry_flutter: ^7.14.0
   ```

3. **Initialize Sentry in main.dart:**
   ```dart
   // lib/main.dart
   import 'package:sentry_flutter/sentry_flutter.dart';

   Future<void> main() async {
     await SentryFlutter.init(
       (options) {
         options.dsn = 'YOUR_SENTRY_DSN'; // Get from sentry.io
         options.environment = Environment.current.name;
         options.tracesSampleRate = 0.1; // 10% of transactions
         options.beforeSend = (event, hint) {
           // Don't send events in development
           if (Environment.isDevelopment) {
             return null;
           }
           return event;
         };
       },
       appRunner: () => runApp(MyApp()),
     );
   }
   ```

4. **Add error boundary:**
   ```dart
   // Wrap MaterialApp in Sentry navigator observer
   MaterialApp(
     navigatorObservers: [
       SentryNavigatorObserver(),
     ],
     // ...
   )
   ```

5. **Add manual error reporting:**
   ```dart
   // In error handlers, add:
   try {
     // risky operation
   } catch (error, stackTrace) {
     await Sentry.captureException(error, stackTrace: stackTrace);
     // Show user-friendly error
   }
   ```

6. **Test crash reporting:**
   ```dart
   // Add test button (remove after testing):
   ElevatedButton(
     onPressed: () {
       throw Exception('Test crash for Sentry');
     },
     child: Text('Test Crash'),
   )
   ```

7. **Environment variables:**
   ```bash
   # .env (don't commit!)
   SENTRY_DSN=https://your-dsn@sentry.io/project-id
   ```

8. **Commit:**
   ```bash
   git add .
   git commit -m "Feature: Add Sentry crash reporting

   - Add sentry_flutter package
   - Initialize Sentry in main.dart
   - Add navigator observer for screen tracking
   - Add manual exception capture in error handlers
   - Configure environment-based reporting
   - Add test crash button (TODO: remove)

   All crashes and errors now reported to Sentry.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin feature/security-hardening
   ```

9. **Create PR for security-hardening branch**

**Success Criteria:**
- ✅ Sentry initialized
- ✅ Test crash appears in Sentry dashboard
- ✅ Environment filtering works (no dev crashes sent)
- ✅ User-facing errors still friendly

---

### **Task 4: Celery Integration (2 days, MEDIUM PRIORITY)**

**Branch:** `feature/celery-integration`

**Current State:**
- Celery is configured but NOT used
- Story generation is synchronous (blocks request)

**Goal:** Use Celery for async story generation

**Steps:**

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/celery-integration
   ```

2. **Verify Celery setup:**
   ```bash
   cd backend
   # Check celery_config.py exists
   # Check redis is in requirements.txt
   ```

3. **Update story route to use Celery:**
   ```python
   # In backend/routes/story_routes.py (or app.py if not modularized yet)

   @story_bp.route('/generate-story', methods=['POST'])
   def generate_story():
       data = request.get_json()

       # Start async task
       from ..celery_config import generate_story_task
       task = generate_story_task.delay(
           user_id=data['user_id'],
           theme=data['theme'],
           characters=data['characters'],
           # ... other params
       )

       return jsonify({
           'task_id': task.id,
           'status': 'processing',
           'poll_url': f'/task-status/{task.id}'
       }), 202  # Accepted

   @story_bp.route('/task-status/<task_id>', methods=['GET'])
   def get_task_status(task_id):
       from ..celery_config import celery
       task = celery.AsyncResult(task_id)

       if task.state == 'PENDING':
           response = {'status': 'processing'}
       elif task.state == 'SUCCESS':
           response = {
               'status': 'complete',
               'result': task.result
           }
       elif task.state == 'FAILURE':
           response = {
               'status': 'failed',
               'error': str(task.info)
           }
       else:
           response = {'status': task.state}

       return jsonify(response)
   ```

4. **Update frontend to poll:**
   ```dart
   // lib/services/api_service_manager.dart

   Future<Story> generateStoryAsync(params) async {
     // Start generation
     final response = await http.post(
       Uri.parse('$baseUrl/generate-story'),
       body: jsonEncode(params),
     );

     final data = jsonDecode(response.body);
     final taskId = data['task_id'];

     // Poll for completion
     while (true) {
       await Future.delayed(Duration(seconds: 2));

       final statusResponse = await http.get(
         Uri.parse('$baseUrl/task-status/$taskId'),
       );

       final status = jsonDecode(statusResponse.body);

       if (status['status'] == 'complete') {
         return Story.fromJson(status['result']);
       } else if (status['status'] == 'failed') {
         throw Exception(status['error']);
       }

       // Show progress to user
       _updateProgress(status['status']);
     }
   }
   ```

5. **Add progress indicator:**
   ```dart
   // In story generation screen
   StreamBuilder<String>(
     stream: _progressStream,
     builder: (context, snapshot) {
       return Text(snapshot.data ?? 'Generating...');
     },
   )
   ```

6. **Test:**
   ```bash
   # Start Redis
   redis-server

   # Start Celery worker
   cd backend
   celery -A celery_config worker --loglevel=info

   # Start Flask
   flask run

   # Test from frontend
   flutter run
   ```

7. **Commit:**
   ```bash
   git add .
   git commit -m "Feature: Integrate Celery for async story generation

   - Update /generate-story to return task_id
   - Add /task-status/<task_id> polling endpoint
   - Update frontend to poll for completion
   - Add progress indicator in UI
   - Update deployment docs for Redis + Celery

   Story generation is now non-blocking.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin feature/celery-integration
   ```

**Success Criteria:**
- ✅ `/generate-story` returns 202 with task_id
- ✅ Frontend polls `/task-status/<task_id>`
- ✅ Story generation completes successfully
- ✅ Redis and Celery running in production
- ✅ Progress shown to user

---

## 🎯 CODEX 2 - Offline & Data Tasks

### **Task 5: Offline-First with Isar (3 days, MEDIUM PRIORITY)**

**Branch:** `feature/offline-first`

**Current State:**
- Only SharedPreferences caching (50 stories max)
- No true offline-first database

**Goal:** Implement Isar for proper offline-first storage

**Steps:**

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/offline-first
   ```

2. **Add dependencies:**
   ```yaml
   # pubspec.yaml
   dependencies:
     isar: ^3.1.0
     isar_flutter_libs: ^3.1.0
     path_provider: ^2.1.1

   dev_dependencies:
     isar_generator: ^3.1.0
     build_runner: ^2.4.6
   ```

3. **Create Isar models:**
   ```dart
   // lib/models/local/story_local.dart
   import 'package:isar/isar.dart';

   part 'story_local.g.dart';

   @collection
   class StoryLocal {
     Id id = Isar.autoIncrement;

     @Index()
     late String storyId; // Server ID

     late String title;
     late String storyText;
     late String theme;
     late bool isFavorite;

     @Index()
     late DateTime createdAt;

     late bool isSyncedToServer;

     // JSON serialization
     Map<String, dynamic> toJson() => {
       'id': storyId,
       'title': title,
       'storyText': storyText,
       'theme': theme,
       'isFavorite': isFavorite,
       'createdAt': createdAt.toIso8601String(),
     };

     static StoryLocal fromJson(Map<String, dynamic> json) {
       return StoryLocal()
         ..storyId = json['id']
         ..title = json['title']
         ..storyText = json['storyText']
         ..theme = json['theme']
         ..isFavorite = json['isFavorite'] ?? false
         ..createdAt = DateTime.parse(json['createdAt'])
         ..isSyncedToServer = true;
     }
   }

   // Similar for CharacterLocal
   ```

4. **Initialize Isar:**
   ```dart
   // lib/services/isar_service.dart
   import 'package:isar/isar.dart';
   import 'package:path_provider/path_provider.dart';

   class IsarService {
     static Isar? _isar;

     static Future<Isar> getInstance() async {
       if (_isar != null) return _isar!;

       final dir = await getApplicationDocumentsDirectory();
       _isar = await Isar.open(
         [StoryLocalSchema, CharacterLocalSchema],
         directory: dir.path,
       );
       return _isar!;
     }

     static Isar get instance => _isar!;
   }
   ```

5. **Create offline-first data layer:**
   ```dart
   // lib/services/offline_story_service.dart
   class OfflineStoryService {
     final Isar isar;

     OfflineStoryService(this.isar);

     // Save story (works offline)
     Future<void> saveStory(StoryLocal story) async {
       await isar.writeTxn(() async {
         await isar.storyLocals.put(story);
       });
     }

     // Get all stories (works offline)
     Future<List<StoryLocal>> getAllStories() async {
       return await isar.storyLocals
           .where()
           .sortByCreatedAtDesc()
           .findAll();
     }

     // Get favorites (works offline)
     Future<List<StoryLocal>> getFavorites() async {
       return await isar.storyLocals
           .filter()
           .isFavoriteEqualTo(true)
           .sortByCreatedAtDesc()
           .findAll();
     }

     // Sync to server when online
     Future<void> syncToServer() async {
       final unsynced = await isar.storyLocals
           .filter()
           .isSyncedToServerEqualTo(false)
           .findAll();

       for (final story in unsynced) {
         try {
           await _uploadToServer(story);
           story.isSyncedToServer = true;
           await isar.writeTxn(() async {
             await isar.storyLocals.put(story);
           });
         } catch (e) {
           print('Sync failed for story ${story.storyId}: $e');
         }
       }
     }
   }
   ```

6. **Add sync indicator:**
   ```dart
   // Show sync status in UI
   StreamBuilder<bool>(
     stream: _syncStatusStream,
     builder: (context, snapshot) {
       if (snapshot.data == true) {
         return Icon(Icons.cloud_done, color: Colors.green);
       } else {
         return Icon(Icons.cloud_off, color: Colors.grey);
       }
     },
   )
   ```

7. **Generate Isar code:**
   ```bash
   flutter pub get
   flutter pub run build_runner build
   ```

8. **Migrate from SharedPreferences:**
   ```dart
   // One-time migration
   Future<void> migrateToIsar() async {
     final prefs = await SharedPreferences.getInstance();
     final oldStories = prefs.getStringList('cached_stories') ?? [];

     final isar = await IsarService.getInstance();
     await isar.writeTxn(() async {
       for (final storyJson in oldStories) {
         final story = StoryLocal.fromJson(jsonDecode(storyJson));
         await isar.storyLocals.put(story);
       }
     });

     await prefs.remove('cached_stories');
   }
   ```

9. **Test:**
   ```bash
   flutter test
   flutter run
   # Test offline mode (airplane mode)
   # Verify stories accessible offline
   # Test sync when back online
   ```

10. **Commit:**
    ```bash
    git add .
    git commit -m "Feature: Implement Isar for offline-first storage

    - Add Isar and dependencies
    - Create StoryLocal and CharacterLocal models
    - Implement IsarService for database access
    - Create OfflineStoryService with sync logic
    - Add sync status indicator in UI
    - Migrate from SharedPreferences to Isar
    - Update saved_stories_screen to use Isar

    App now works fully offline with background sync.

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    Co-Authored-By: Claude <noreply@anthropic.com>"

    git push origin feature/offline-first
    ```

**Success Criteria:**
- ✅ Isar database initialized
- ✅ Stories saved offline
- ✅ App works in airplane mode
- ✅ Auto-sync when online
- ✅ Migration from SharedPreferences works
- ✅ No data loss

---

## 🎯 CODEX 1 - Frontend Enhancements

### **Task 6: State Management Refactor (3 days, MEDIUM PRIORITY)**

**Branch:** `feature/state-management`

**Current State:**
- Using setState everywhere
- No centralized state management
- Props drilling through multiple widgets

**Goal:** Implement Riverpod for state management

**Steps:**

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/state-management
   ```

2. **Add dependencies:**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_riverpod: ^2.4.9
     riverpod_annotation: ^2.3.3

   dev_dependencies:
     riverpod_generator: ^2.3.9
     build_runner: ^2.4.6
   ```

3. **Wrap app with ProviderScope:**
   ```dart
   // lib/main.dart
   import 'package:flutter_riverpod/flutter_riverpod.dart';

   void main() {
     runApp(
       ProviderScope(
         child: MyApp(),
       ),
     );
   }
   ```

4. **Create providers for app state:**
   ```dart
   // lib/providers/user_provider.dart
   import 'package:riverpod_annotation/riverpod_annotation.dart';

   part 'user_provider.g.dart';

   @riverpod
   class UserState extends _$UserState {
     @override
     User? build() => null;

     void setUser(User user) {
       state = user;
     }

     void logout() {
       state = null;
     }
   }

   // lib/providers/story_provider.dart
   @riverpod
   class StoryList extends _$StoryList {
     @override
     Future<List<Story>> build() async {
       // Fetch stories from API
       return await ref.watch(apiServiceProvider).getStories();
     }

     Future<void> addStory(Story story) async {
       state = AsyncValue.loading();
       state = await AsyncValue.guard(() async {
         final stories = await ref.read(storyListProvider.future);
         return [...stories, story];
       });
     }
   }

   // lib/providers/theme_provider.dart
   @riverpod
   class ThemeMode extends _$ThemeMode {
     @override
     ThemeMode build() => ThemeMode.system;

     void toggle() {
       state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
     }
   }
   ```

5. **Generate provider code:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

6. **Convert screens to use Riverpod:**
   ```dart
   // Before (setState):
   class _StoryScreenState extends State<StoryScreen> {
     List<Story> stories = [];

     void loadStories() async {
       final result = await apiService.getStories();
       setState(() {
         stories = result;
       });
     }
   }

   // After (Riverpod):
   class StoryScreen extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final storiesAsync = ref.watch(storyListProvider);

       return storiesAsync.when(
         data: (stories) => ListView.builder(...),
         loading: () => CircularProgressIndicator(),
         error: (err, stack) => ErrorWidget(err),
       );
     }
   }
   ```

7. **Convert key screens:**
   - `saved_stories_screen.dart`
   - `story_screen.dart`
   - `character_creation_screen.dart`
   - `settings_screen.dart`

8. **Test:**
   ```bash
   flutter test
   flutter run
   # Verify all screens work
   # Check no setState warnings
   ```

9. **Commit:**
   ```bash
   git add .
   git commit -m "Refactor: Implement Riverpod state management

   - Add flutter_riverpod dependencies
   - Create providers for user, stories, theme
   - Convert screens from setState to ConsumerWidget
   - Add async state handling with AsyncValue
   - Remove props drilling
   - Improve code maintainability

   All screens now use centralized state management.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin feature/state-management
   ```

**Success Criteria:**
- ✅ Riverpod installed
- ✅ All major screens use providers
- ✅ No setState in main screens
- ✅ State persists across navigations
- ✅ Tests pass

---

### **Task 7: Mobile IAP (2 days, LOW PRIORITY)**

**Branch:** `feature/mobile-iap`

**Current State:**
- Web Stripe only
- No in-app purchases for iOS/Android

**Goal:** Add RevenueCat for mobile subscriptions

**Steps:**

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/mobile-iap
   ```

2. **Add dependency:**
   ```yaml
   # pubspec.yaml
   dependencies:
     purchases_flutter: ^6.12.0
   ```

3. **Set up RevenueCat:**
   - Create account at revenuecat.com
   - Add iOS and Android products
   - Get API keys

4. **Initialize RevenueCat:**
   ```dart
   // lib/services/revenue_cat_service.dart
   import 'package:purchases_flutter/purchases_flutter.dart';

   class RevenueCatService {
     static Future<void> initialize() async {
       await Purchases.configure(
         PurchasesConfiguration('YOUR_API_KEY')
           ..appUserID = null, // Use anonymous ID
       );
     }

     static Future<List<Package>> getOfferings() async {
       final offerings = await Purchases.getOfferings();
       return offerings.current?.availablePackages ?? [];
     }

     static Future<bool> purchasePackage(Package package) async {
       try {
         final purchaserInfo = await Purchases.purchasePackage(package);
         return purchaserInfo.entitlements.active.isNotEmpty;
       } catch (e) {
         return false;
       }
     }

     static Future<bool> hasActiveSubscription() async {
       final purchaserInfo = await Purchases.getCustomerInfo();
       return purchaserInfo.entitlements.active.isNotEmpty;
     }
   }
   ```

5. **Add subscription screen:**
   ```dart
   // Update lib/screens/subscription_screen.dart
   class SubscriptionScreen extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return FutureBuilder<List<Package>>(
         future: RevenueCatService.getOfferings(),
         builder: (context, snapshot) {
           if (!snapshot.hasData) return CircularProgressIndicator();

           return ListView.builder(
             itemCount: snapshot.data!.length,
             itemBuilder: (context, index) {
               final package = snapshot.data![index];
               return SubscriptionCard(
                 title: package.storeProduct.title,
                 price: package.storeProduct.priceString,
                 onTap: () async {
                   final success = await RevenueCatService.purchasePackage(package);
                   if (success) {
                     // Show success message
                   }
                 },
               );
             },
           );
         },
       );
     }
   }
   ```

6. **Configure iOS:**
   ```xml
   <!-- ios/Runner/Info.plist -->
   <key>SKAdNetworkItems</key>
   <array>
     <!-- Add RevenueCat SKAdNetwork IDs -->
   </array>
   ```

7. **Configure Android:**
   ```gradle
   // android/app/build.gradle
   dependencies {
     implementation 'com.revenuecat.purchases:purchases:6.+'
   }
   ```

8. **Test:**
   ```bash
   # iOS
   flutter run -d ios --debug
   # Use sandbox Apple ID to test

   # Android
   flutter run -d android --debug
   # Use test user in Google Play Console
   ```

9. **Commit:**
   ```bash
   git add .
   git commit -m "Feature: Add mobile in-app purchases with RevenueCat

   - Add purchases_flutter package
   - Create RevenueCatService
   - Update subscription screen for mobile IAP
   - Configure iOS and Android
   - Add sandbox testing instructions

   Users can now subscribe via App Store / Play Store.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin feature/mobile-iap
   ```

**Success Criteria:**
- ✅ RevenueCat configured
- ✅ Subscriptions visible in app
- ✅ Test purchase works in sandbox
- ✅ Entitlements synced

---

### **Task 8: Fix Accessibility (Semantics Widgets) (Half day, MEDIUM PRIORITY)**

**Branch:** `feature/accessibility-fix`

**Current State:**
- ALL Semantics widgets removed (emergency fix for Thanksgiving)
- App works but has NO accessibility features
- Screen readers can't properly announce UI elements

**Why It Broke:**
Semantics widgets were causing **infinite loops** (Stack Overflow errors) because they were triggering rebuild cycles:
1. Semantics widget built
2. Triggered parent widget rebuild
3. Parent rebuilt Semantics widget
4. Infinite loop → Stack Overflow crash

**Goal:** Re-implement accessibility correctly without causing infinite loops

**Steps:**

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/accessibility-fix
   ```

2. **Understand the problem:**
   - Read Flutter docs on Semantics best practices
   - Study ExcludeSemantics usage
   - Learn about semantic merge behaviors

3. **Strategy for safe Semantics:**
   ```dart
   // ❌ BAD - Can cause infinite loops
   Semantics(
     label: 'Delete button',
     button: true,
     child: StatefulWidget(...), // Stateful widget that rebuilds
   )

   // ✅ GOOD - Use excludeSemantics on parent
   ExcludeSemantics(
     child: ParentWidget(
       child: IconButton(
         semanticLabel: 'Delete button', // Built-in semantic property
         icon: Icon(Icons.delete),
       ),
     ),
   )

   // ✅ GOOD - Use MergeSemantics to prevent conflicts
   MergeSemantics(
     child: Row(
       children: [
         Icon(Icons.delete),
         Text('Delete'),
       ],
     ),
   )
   ```

4. **Priority order (add incrementally):**

   **Phase 1: Critical navigation (1 hour)**
   - Bottom navigation bar
   - App bar actions
   - Primary action buttons (Generate Story, Save Story)
   - Test with screen reader after EACH addition

   **Phase 2: Story management (1 hour)**
   - Story list items
   - Favorite toggle
   - Share button
   - Test again

   **Phase 3: Forms and inputs (30 min)**
   - Character name input
   - Age selection
   - Theme selection
   - Test again

5. **Use built-in semantics where possible:**
   ```dart
   // Instead of wrapping in Semantics, use semantic properties:

   // Buttons
   IconButton(
     tooltip: 'Delete story', // Automatically provides semantics
     icon: Icon(Icons.delete),
   )

   // Text fields
   TextField(
     decoration: InputDecoration(
       labelText: 'Character name', // Provides semantics
       hintText: 'Enter a name',
     ),
   )

   // Images
   Image.network(
     url,
     semanticLabel: 'Story illustration showing...', // Built-in
   )
   ```

6. **Add semantic tests:**
   ```dart
   // test/accessibility_test.dart
   testWidgets('Delete button is accessible', (tester) async {
     await tester.pumpWidget(MyApp());

     final deleteButtonFinder = find.bySemanticsLabel('Delete story');
     expect(deleteButtonFinder, findsOneWidget);

     // Verify tappable
     final semantics = tester.getSemantics(deleteButtonFinder);
     expect(semantics.hasAction(SemanticsAction.tap), isTrue);
   });
   ```

7. **Test with actual screen readers:**
   ```bash
   # iOS
   flutter run -d ios
   # Enable VoiceOver: Settings → Accessibility → VoiceOver

   # Android
   flutter run -d android
   # Enable TalkBack: Settings → Accessibility → TalkBack

   # Web
   flutter run -d chrome
   # Use browser screen reader extension
   ```

8. **Files to update (in priority order):**
   - `lib/widgets/app_button.dart` - Use tooltip instead of Semantics
   - `lib/widgets/app_switch.dart` - Use SwitchListTile's built-in semantics
   - `lib/main_story.dart` - Add semantics to main navigation only
   - `lib/story_result_screen.dart` - Add semantics to action buttons
   - `lib/settings_screen.dart` - Use ListTile's built-in semantics
   - `lib/quick_story_screen.dart` - Add semantics to form fields
   - `lib/saved_stories_screen.dart` - Add semantics to list items (LAST, test carefully)

9. **Commit after each phase passes:**
   ```bash
   git add .
   git commit -m "Accessibility: Phase 1 - Critical navigation semantics

   - Add semantic labels to bottom navigation
   - Add tooltips to app bar actions
   - Add semantic labels to primary action buttons
   - Use built-in semantic properties instead of Semantics wrapper
   - Tested with VoiceOver/TalkBack - no infinite loops

   Screen readers can now navigate core app features.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>"

   git push origin feature/accessibility-fix
   ```

10. **Final verification:**
    ```bash
    # Run semantic tests
    flutter test test/accessibility_test.dart

    # Run app with semantics debugger
    flutter run --debug
    # Enable "Show Semantics Tree" in Flutter DevTools

    # Test with screen reader on real device
    # Navigate entire app using only screen reader
    ```

**Key Rules to Prevent Infinite Loops:**

1. ✅ **DO** use built-in semantic properties (tooltip, semanticLabel, labelText)
2. ✅ **DO** use ExcludeSemantics to prevent parent conflicts
3. ✅ **DO** test after adding each Semantics widget
4. ✅ **DO** use MergeSemantics for grouped elements
5. ❌ **DON'T** wrap StatefulWidgets directly in Semantics
6. ❌ **DON'T** add Semantics to widgets that rebuild frequently
7. ❌ **DON'T** nest Semantics widgets deeply

**Success Criteria:**
- ✅ All critical UI elements have semantic labels
- ✅ Screen reader can navigate entire app
- ✅ No Stack Overflow errors
- ✅ No infinite rebuild loops
- ✅ Semantic tests pass
- ✅ Manual screen reader testing successful
- ✅ App works for users with disabilities

**Time Estimate:** 2-3 hours (done incrementally, tested carefully)

**Assigned To:** Codex 1 (frontend specialist)

---

## 📋 Merge Checklist

Before merging any branch to `main`:

1. ✅ All tests pass (`flutter test`, `pytest`)
2. ✅ Code review completed (PR approved)
3. ✅ Manual testing on dev/staging
4. ✅ No breaking changes to API
5. ✅ Database migrations tested (if applicable)
6. ✅ Documentation updated
7. ✅ Railway preview deployment tested
8. ✅ Performance benchmarks acceptable

---

## 🚀 Deployment Strategy

1. **Feature Branch Development:**
   - Work on feature branch
   - Push to GitHub
   - Railway creates preview deployment
   - Test on preview URL

2. **Merge to Main:**
   - Create PR from feature branch
   - Get approval
   - Merge via GitHub PR (don't use fast-forward)
   - Railway auto-deploys to production

3. **Rollback Plan:**
   - If production breaks, revert PR
   - Railway auto-deploys previous version

---

## 📞 Questions?

See `DEPLOYMENT_STATUS.md` for current production status and Railway URLs.

**Note:** All these tasks should be done AFTER Thanksgiving when the app is stable and you have time for careful testing.
