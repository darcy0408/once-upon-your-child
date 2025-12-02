# Phase 1: Multi-Agent Prompts

**Created:** 2025-12-02
**Supervisor:** Claude
**Goal:** Complete 3 HIGH PRIORITY tasks in parallel

---

## AGENT 1: Backend Modularization

### Context
You are **Agent 1 (Backend API)** working on the Story Weaver therapeutic storytelling app.

### Your Mission
Extract 21 routes from `backend/app.py` into organized blueprint files to improve code maintainability.

### Branch
```bash
git checkout main
git pull origin main
git checkout -b refactor/backend-modularization
```

### Files You Will Create
```
backend/routes/story_routes.py         # 7 story endpoints
backend/routes/character_routes.py     # 5 character endpoints
backend/routes/admin_routes.py         # Admin endpoints
backend/routes/health_routes.py        # Health/version endpoints
```

### Files You Will Modify
```
backend/app.py                         # Remove routes, add blueprint imports
```

### Task Details

#### Step 1: Read Current Code
Read `backend/app.py` (currently ~1,128 lines) and identify all route definitions.

#### Step 2: Create Story Routes Blueprint
Create `backend/routes/story_routes.py`:
```python
from flask import Blueprint, request, jsonify
from ..database import db
from ..models.story import Story
from ..models.user import User
from ..services.story_service import AdvancedStoryEngine

story_bp = Blueprint('story', __name__)

# Move these routes from app.py:
# - /generate-story (POST)
# - /generate-interactive-story (POST)
# - /continue-interactive-story (POST)
# - /save-story (POST)
# - /get-stories (GET)
# - /stories/<story_id> (GET, PATCH, DELETE)
# - /report-story (POST)
```

#### Step 3: Create Character Routes Blueprint
Create `backend/routes/character_routes.py`:
```python
from flask import Blueprint, request, jsonify
from ..database import db
from ..models.character import Character
from ..services import character_service

character_bp = Blueprint('character', __name__)

# Move these routes from app.py:
# - /create-character (POST)
# - /get-characters (GET)
# - /characters/<char_id> (GET, PATCH, PUT, DELETE)
```

#### Step 4: Create Admin Routes Blueprint
Create `backend/routes/admin_routes.py`:
```python
from flask import Blueprint, request, jsonify
from ..database import db

admin_bp = Blueprint('admin', __name__)

# Move these routes from app.py:
# - /admin/run-db-optimization (POST)
# Any other /admin/* routes not in analytics_bp
```

#### Step 5: Create Health Routes Blueprint
Create `backend/routes/health_routes.py`:
```python
from flask import Blueprint, jsonify
import os

health_bp = Blueprint('health', __name__)

# Move these routes from app.py:
# - /health (GET)
# - /version (GET)
```

#### Step 6: Update app.py
In `backend/app.py`, after existing blueprint registrations (~line 341):
```python
# Import new blueprints
from .routes.story_routes import story_bp
from .routes.character_routes import character_bp
from .routes.admin_routes import admin_bp
from .routes.health_routes import health_bp

# Register new blueprints
app.register_blueprint(story_bp)
app.register_blueprint(character_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(health_bp)
```

Remove all the route definitions you moved to blueprints.

### Testing Requirements (MANDATORY)

#### 1. Run Backend Tests
```bash
cd backend
.venv\Scripts\activate  # Windows
python -m pytest tests/ -v
```
**Copy full test output to your report.**

#### 2. Start Backend
```bash
cd backend
.venv\Scripts\activate
python app.py
```
Verify it starts without errors.

#### 3. Test Health Endpoint
```bash
curl http://localhost:5000/health
```
Should return `{"status": "healthy"}`

#### 4. Test Story Endpoint
```bash
curl -X POST http://localhost:5000/generate-story ^
  -H "Content-Type: application/json" ^
  -d "{\"theme\": \"adventure\", \"character_id\": 1}"
```
Should return story data (or appropriate error if no character exists)

#### 5. Test Character Endpoint
```bash
curl http://localhost:5000/get-characters
```
Should return character list or empty array.

#### 6. Verify Line Count
```bash
find /c /v "" backend\app.py
```
Should be < 300 lines.

### Success Criteria
- [ ] `backend/routes/story_routes.py` created with 7 endpoints
- [ ] `backend/routes/character_routes.py` created with 5 endpoints
- [ ] `backend/routes/admin_routes.py` created
- [ ] `backend/routes/health_routes.py` created
- [ ] `backend/app.py` reduced to < 300 lines
- [ ] All blueprints registered in app.py
- [ ] All pytest tests pass (provide output)
- [ ] Backend starts without errors
- [ ] `/health` endpoint returns 200 OK
- [ ] Manual endpoint tests work

### Reporting Format

Update `TEAM_COORDINATION.md` under a new section:

```markdown
## Agent 1 - Backend API | 2025-12-02

### Task: Backend Modularization

### Files Changed
- Created: backend/routes/story_routes.py (7 endpoints)
- Created: backend/routes/character_routes.py (5 endpoints)
- Created: backend/routes/admin_routes.py
- Created: backend/routes/health_routes.py
- Modified: backend/app.py (reduced from 1,128 to XXX lines)

### Test Results
```
[PASTE FULL pytest OUTPUT HERE]
```

### Manual Testing Results
- [ ] Backend starts: SUCCESS/FAIL
- [ ] /health endpoint: SUCCESS/FAIL (response: ...)
- [ ] /generate-story endpoint: SUCCESS/FAIL
- [ ] /get-characters endpoint: SUCCESS/FAIL

### Issues Encountered
[List any issues or none]

### Status
✅ COMPLETE - Ready for supervisor verification
```

### Commit Message
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

### IMPORTANT
- DO NOT mark task as complete in todo list
- DO NOT merge to main
- WAIT for Supervisor (Claude) verification
- Only work on files in backend/**

---

## AGENT 2: Crash Reporting with Sentry

### Context
You are **Agent 2 (Frontend Core)** working on the Story Weaver therapeutic storytelling app.

### Your Mission
Add Sentry crash reporting to the Flutter app to track errors and crashes in production.

### Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/security-hardening
```

### Files You Will Create
None (will modify existing files)

### Files You Will Modify
```
pubspec.yaml                           # Add sentry_flutter dependency
lib/main.dart                          # Initialize Sentry
```

### Task Details

#### Step 1: Add Sentry Dependency
In `pubspec.yaml`, add under dependencies:
```yaml
dependencies:
  sentry_flutter: ^7.14.0
```

Then run:
```bash
flutter pub get
```

#### Step 2: Initialize Sentry in main.dart
Read current `lib/main.dart` and modify the `main()` function:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://your-dsn@sentry.io/project-id';
      // Use environment name from existing Environment config
      options.environment = Environment.isDevelopment ? 'development' : 'production';
      options.tracesSampleRate = 0.1; // 10% of transactions
      options.beforeSend = (event, hint) {
        // Don't send events in development
        if (Environment.isDevelopment) {
          return null;
        }
        return event;
      };
    },
    appRunner: () => runApp(const MyApp()),
  );
}
```

#### Step 3: Add Navigator Observer
Find the `MaterialApp` widget and add:
```dart
MaterialApp(
  navigatorObservers: [
    SentryNavigatorObserver(),
  ],
  // ... rest of MaterialApp config
)
```

#### Step 4: Add Test Crash Button (Temporary)
In settings screen or main screen, add a test button:
```dart
// TODO: REMOVE BEFORE PRODUCTION
if (Environment.isDevelopment) {
  ElevatedButton(
    onPressed: () {
      throw Exception('Test crash for Sentry verification');
    },
    child: Text('Test Crash (Dev Only)'),
  )
}
```

### Testing Requirements (MANDATORY)

#### 1. Run Flutter Tests
```bash
flutter test
```
**Copy full test output to your report.**

#### 2. Build and Run App
```bash
flutter run -d chrome
```
Verify app starts without errors.

#### 3. Test Crash in Development
- Click "Test Crash" button
- Verify app shows error
- Verify crash does NOT appear in Sentry (due to environment filter)

#### 4. Test Crash in Production Mode
```bash
# Build for web in release mode
flutter build web --release

# Or run in profile mode to test production behavior
flutter run -d chrome --profile
```
- Trigger test crash
- Check Sentry dashboard at sentry.io
- Verify crash appears

#### 5. Test Normal App Functionality
- Create character
- Generate story
- Save story
- Verify no Sentry errors for normal operations

### Success Criteria
- [ ] `sentry_flutter` added to pubspec.yaml
- [ ] Sentry initialized in main.dart
- [ ] Navigator observer added
- [ ] Environment filtering works (dev crashes not sent)
- [ ] All flutter tests pass
- [ ] App starts without errors
- [ ] Test crash appears in Sentry dashboard
- [ ] Normal app usage doesn't generate errors

### Reporting Format

Update `TEAM_COORDINATION.md`:

```markdown
## Agent 2 - Frontend Core | 2025-12-02

### Task: Crash Reporting with Sentry

### Files Changed
- Modified: pubspec.yaml (added sentry_flutter: ^7.14.0)
- Modified: lib/main.dart (Sentry initialization)
- Modified: [screen with test button]

### Test Results
```
[PASTE flutter test OUTPUT HERE]
```

### Manual Testing Results
- [ ] App starts in dev mode: SUCCESS/FAIL
- [ ] Test crash in dev (should NOT send to Sentry): SUCCESS/FAIL
- [ ] Test crash in production mode (SHOULD send): SUCCESS/FAIL
- [ ] Sentry dashboard shows crash: SUCCESS/FAIL
- [ ] Normal app usage: SUCCESS/FAIL

### Sentry Dashboard
- Project: [project name]
- Test crash visible: YES/NO
- Environment tag correct: YES/NO
- Screenshot: [optional]

### Issues Encountered
[List any issues or none]

### Status
✅ COMPLETE - Ready for supervisor verification
```

### Commit Message
```bash
git add pubspec.yaml lib/main.dart [other files]
git commit -m "Feature: Add Sentry crash reporting

- Add sentry_flutter package
- Initialize Sentry in main.dart
- Add navigator observer for screen tracking
- Configure environment-based reporting
- Add test crash button (TODO: remove)

All crashes and errors now reported to Sentry.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/security-hardening
```

### IMPORTANT
- DO NOT mark task as complete
- DO NOT merge to main
- WAIT for Supervisor verification
- Only work on frontend files (lib/**)
- Coordinate with Agent 3 on same branch

---

## AGENT 3: Secure Storage

### Context
You are **Agent 3 (Frontend Widgets & Services)** working on the Story Weaver therapeutic storytelling app.

### Your Mission
Replace insecure SharedPreferences storage with flutter_secure_storage for API keys and sensitive data.

### Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/security-hardening
```

**NOTE:** Agent 2 is also on this branch. Coordinate file changes.

### Files You Will Create
```
lib/services/secure_storage_service.dart
```

### Files You Will Modify
```
pubspec.yaml                                    # Add dependency
lib/services/api_service_manager.dart          # Update API key storage
lib/screens/byok_setup_wizard.dart             # Update BYOK flow
[Any other files using SharedPreferences for sensitive data]
```

### Task Details

#### Step 1: Add Dependency
In `pubspec.yaml`, add:
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

Run:
```bash
flutter pub get
```

#### Step 2: Create SecureStorageService
Create `lib/services/secure_storage_service.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // API Keys
  static Future<void> saveApiKey(String provider, String value) async {
    await _storage.write(key: 'api_key_$provider', value: value);
  }

  static Future<String?> getApiKey(String provider) async {
    return await _storage.read(key: 'api_key_$provider');
  }

  static Future<void> deleteApiKey(String provider) async {
    await _storage.delete(key: 'api_key_$provider');
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

  // Migration helper - one-time migration from SharedPreferences
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate API keys
    final geminiKey = prefs.getString('gemini_api_key');
    if (geminiKey != null) {
      await saveApiKey('gemini', geminiKey);
      await prefs.remove('gemini_api_key');
    }

    final openaiKey = prefs.getString('openai_api_key');
    if (openaiKey != null) {
      await saveApiKey('openai', openaiKey);
      await prefs.remove('openai_api_key');
    }

    // Mark migration complete
    await prefs.setBool('secure_storage_migrated', true);
  }
}
```

#### Step 3: Update API Service Manager
Find `lib/services/api_service_manager.dart` and replace SharedPreferences calls with SecureStorageService:

Before:
```dart
final prefs = await SharedPreferences.getInstance();
final apiKey = prefs.getString('gemini_api_key');
```

After:
```dart
final apiKey = await SecureStorageService.getApiKey('gemini');
```

#### Step 4: Update BYOK Setup Wizard
Find where API keys are saved and replace with secure storage:

Before:
```dart
await prefs.setString('gemini_api_key', apiKey);
```

After:
```dart
await SecureStorageService.saveApiKey('gemini', apiKey);
```

#### Step 5: Add Migration on App Start
In `lib/main.dart`, after WidgetsFlutterBinding.ensureInitialized():
```dart
// One-time migration to secure storage
final prefs = await SharedPreferences.getInstance();
final migrated = prefs.getBool('secure_storage_migrated') ?? false;
if (!migrated) {
  await SecureStorageService.migrateFromSharedPreferences();
}
```

### Testing Requirements (MANDATORY)

#### 1. Run Flutter Tests
```bash
flutter test
```
**Copy output to report.**

#### 2. Test BYOK Flow (Most Important)
```bash
flutter run -d chrome
```

Manual test:
1. Go to Settings
2. Click "Bring Your Own Key"
3. Enter a test API key
4. Save
5. Close app completely
6. Restart app
7. Verify API key persists
8. Try generating a story with the key

#### 3. Test Migration
1. Clear secure storage
2. Add an API key to SharedPreferences manually (using dev tools)
3. Restart app
4. Verify key migrated to secure storage
5. Verify old SharedPreferences entry deleted

#### 4. Test Logout
1. Save API key
2. Trigger logout/delete all
3. Verify API key deleted from secure storage

### Success Criteria
- [ ] flutter_secure_storage added to pubspec.yaml
- [ ] SecureStorageService created
- [ ] All API key access uses SecureStorageService
- [ ] Migration from SharedPreferences works
- [ ] All flutter tests pass
- [ ] BYOK flow works
- [ ] API keys persist across app restart
- [ ] Logout clears secure storage

### Reporting Format

Update `TEAM_COORDINATION.md`:

```markdown
## Agent 3 - Frontend Widgets & Services | 2025-12-02

### Task: Secure Storage

### Files Changed
- Modified: pubspec.yaml (added flutter_secure_storage)
- Created: lib/services/secure_storage_service.dart
- Modified: lib/services/api_service_manager.dart
- Modified: lib/screens/byok_setup_wizard.dart
- Modified: lib/main.dart (migration)
- Modified: [any other files]

### Test Results
```
[PASTE flutter test OUTPUT HERE]
```

### Manual Testing Results
- [ ] BYOK flow - save API key: SUCCESS/FAIL
- [ ] API key persists after restart: SUCCESS/FAIL
- [ ] Migration from SharedPreferences: SUCCESS/FAIL
- [ ] Logout deletes secure data: SUCCESS/FAIL
- [ ] Story generation with BYOK: SUCCESS/FAIL

### Migration Test
- Old SharedPreferences entries found: [count]
- Successfully migrated: [count]
- Verification: [PASS/FAIL]

### Issues Encountered
[List any issues or none]

### Status
✅ COMPLETE - Ready for supervisor verification
```

### Commit Message
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

### IMPORTANT
- DO NOT mark task as complete
- DO NOT merge to main
- WAIT for Supervisor verification
- Coordinate with Agent 2 (same branch)
- Only work on frontend files (lib/**)

---

## COORDINATION NOTES

### Shared Branch: feature/security-hardening
- **Agent 2** and **Agent 3** share this branch
- **Agent 2** works on: lib/main.dart (Sentry)
- **Agent 3** works on: lib/main.dart (migration), lib/services/**, pubspec.yaml
- **Conflict risk:** lib/main.dart, pubspec.yaml
- **Solution:** Agent 3 should merge Agent 2's changes before committing

### File Locks
- 🔒 Agent 1: backend/app.py
- 🔒 Agent 2: lib/main.dart (Sentry section)
- 🔒 Agent 3: lib/main.dart (migration section), lib/services/**

### Timeline
- All 3 agents work in parallel
- Estimated time: 4-6 hours per agent
- Supervisor verification: 2-3 hours
- Total Phase 1: 1-2 days

---

## SUPERVISOR (CLAUDE) VERIFICATION CHECKLIST

### For Agent 1 (Backend Modularization):
- [ ] Read agent's TEAM_COORDINATION.md report
- [ ] Review git diff for backend/app.py and new route files
- [ ] Run pytest myself: `cd backend && .venv\Scripts\activate && python -m pytest tests/ -v`
- [ ] Start backend myself and test endpoints
- [ ] Verify line count reduction
- [ ] Check code quality (imports, error handling)
- [ ] Mark todo as completed only if all pass

### For Agent 2 (Crash Reporting):
- [ ] Read agent's TEAM_COORDINATION.md report
- [ ] Review git diff for main.dart and pubspec.yaml
- [ ] Run flutter test myself
- [ ] Run app and trigger test crash
- [ ] Check Sentry dashboard personally
- [ ] Test environment filtering
- [ ] Mark todo as completed only if all pass

### For Agent 3 (Secure Storage):
- [ ] Read agent's TEAM_COORDINATION.md report
- [ ] Review git diff for secure storage changes
- [ ] Run flutter test myself
- [ ] Test BYOK flow personally
- [ ] Test migration personally
- [ ] Verify API key persistence across restart
- [ ] Mark todo as completed only if all pass

### Phase 1 Integration:
- [ ] All 3 agents verified
- [ ] Merge feature/security-hardening (Agents 2+3)
- [ ] Test frontend with both Sentry and secure storage
- [ ] Test backend with modularized routes
- [ ] Full integration test: Create character, generate story, save, restart
- [ ] Update TEAM_COORDINATION.md with Phase 1 completion
- [ ] Mark Phase 1 complete in todo list

---

**END OF PHASE 1 AGENT PROMPTS**
