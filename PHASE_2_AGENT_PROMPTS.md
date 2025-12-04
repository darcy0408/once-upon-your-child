# Phase 2: Multi-Agent Prompts

**Created:** 2025-12-03
**Supervisor:** Claude
**Goal:** Complete 4 MEDIUM PRIORITY tasks in 2 waves

---

## WAVE 1: Infrastructure (Week 1)

### AGENT 1: Offline-First with Isar

**You are Agent 1 (Backend/Data)** working on Story Weaver app.

#### Mission
Replace SharedPreferences with Isar database for true offline-first functionality.

#### Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/offline-first
```

#### Working Directory
`C:\dev\story-weaver-app`

#### Your Scope
You ONLY work on:
- `lib/models/local/` - Isar data models
- `lib/services/isar_service.dart` - Database initialization
- `lib/services/offline_story_service.dart` - Offline data layer
- `lib/saved_stories_screen.dart` - Update to use Isar
- `pubspec.yaml` - Add dependencies

**DO NOT touch:**
- Backend files (`backend/**`)
- Other frontend screens
- API services
- Widget files

#### Task Steps

**1. Add Dependencies**
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

Run: `flutter pub get`

**2. Create Isar Models**

Create `lib/models/local/story_local.dart`:
```dart
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
  late String? imageUrl;

  @Index()
  late DateTime createdAt;

  late bool isSyncedToServer;

  // Convert from API response
  static StoryLocal fromJson(Map<String, dynamic> json) {
    return StoryLocal()
      ..storyId = json['id'] ?? ''
      ..title = json['title'] ?? ''
      ..storyText = json['storyText'] ?? json['story_text'] ?? ''
      ..theme = json['theme'] ?? ''
      ..isFavorite = json['isFavorite'] ?? json['is_favorite'] ?? false
      ..imageUrl = json['imageUrl'] ?? json['image_url']
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now()
      ..isSyncedToServer = true;
  }

  // Convert to API format
  Map<String, dynamic> toJson() => {
    'id': storyId,
    'title': title,
    'storyText': storyText,
    'theme': theme,
    'isFavorite': isFavorite,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
  };
}
```

Create `lib/models/local/character_local.dart`:
```dart
import 'package:isar/isar.dart';

part 'character_local.g.dart';

@collection
class CharacterLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String characterId; // Server ID

  late String name;
  late int age;
  late String? avatarUrl;
  late bool isSyncedToServer;

  @Index()
  late DateTime createdAt;

  static CharacterLocal fromJson(Map<String, dynamic> json) {
    return CharacterLocal()
      ..characterId = json['id'] ?? ''
      ..name = json['name'] ?? ''
      ..age = json['age'] ?? 5
      ..avatarUrl = json['avatarUrl'] ?? json['avatar_url']
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now()
      ..isSyncedToServer = true;
  }

  Map<String, dynamic> toJson() => {
    'id': characterId,
    'name': name,
    'age': age,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt.toIso8601String(),
  };
}
```

**3. Generate Isar Code**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This creates `*.g.dart` files. Commit these.

**4. Create Isar Service**

Create `lib/services/isar_service.dart`:
```dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local/story_local.dart';
import '../models/local/character_local.dart';

class IsarService {
  static Isar? _isar;

  static Future<Isar> getInstance() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [StoryLocalSchema, CharacterLocalSchema],
      directory: dir.path,
      inspector: true, // Enable Isar Inspector for debugging
    );
    return _isar!;
  }

  static Isar get instance {
    if (_isar == null) {
      throw Exception('IsarService not initialized. Call getInstance() first.');
    }
    return _isar!;
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
```

**5. Create Offline Story Service**

Create `lib/services/offline_story_service.dart`:
```dart
import 'package:isar/isar.dart';
import '../models/local/story_local.dart';
import 'isar_service.dart';

class OfflineStoryService {
  final Isar _isar;

  OfflineStoryService(this._isar);

  // Save story (works offline)
  Future<void> saveStory(StoryLocal story) async {
    await _isar.writeTxn(() async {
      await _isar.storyLocals.put(story);
    });
  }

  // Get all stories (works offline)
  Future<List<StoryLocal>> getAllStories() async {
    return await _isar.storyLocals
        .where()
        .sortByCreatedAtDesc()
        .findAll();
  }

  // Get favorites only
  Future<List<StoryLocal>> getFavorites() async {
    return await _isar.storyLocals
        .filter()
        .isFavoriteEqualTo(true)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // Toggle favorite
  Future<void> toggleFavorite(String storyId) async {
    final story = await _isar.storyLocals
        .filter()
        .storyIdEqualTo(storyId)
        .findFirst();

    if (story != null) {
      story.isFavorite = !story.isFavorite;
      await _isar.writeTxn(() async {
        await _isar.storyLocals.put(story);
      });
    }
  }

  // Delete story
  Future<void> deleteStory(String storyId) async {
    final story = await _isar.storyLocals
        .filter()
        .storyIdEqualTo(storyId)
        .findFirst();

    if (story != null) {
      await _isar.writeTxn(() async {
        await _isar.storyLocals.delete(story.id);
      });
    }
  }

  // Get unsynced stories (for background sync)
  Future<List<StoryLocal>> getUnsyncedStories() async {
    return await _isar.storyLocals
        .filter()
        .isSyncedToServerEqualTo(false)
        .findAll();
  }

  // Mark story as synced
  Future<void> markAsSynced(String storyId) async {
    final story = await _isar.storyLocals
        .filter()
        .storyIdEqualTo(storyId)
        .findFirst();

    if (story != null) {
      story.isSyncedToServer = true;
      await _isar.writeTxn(() async {
        await _isar.storyLocals.put(story);
      });
    }
  }

  // Clear all stories (for testing/logout)
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.storyLocals.clear();
    });
  }
}
```

**6. Initialize in main.dart**

Update `lib/main.dart` - add this AFTER `WidgetsFlutterBinding.ensureInitialized()`:
```dart
import 'services/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database
  await IsarService.getInstance();

  // ... rest of initialization
}
```

**7. Migrate Saved Stories Screen**

Update `lib/saved_stories_screen.dart` to use Isar instead of SharedPreferences.

Find the current implementation that uses `SharedPreferences` and replace with:
```dart
import 'services/isar_service.dart';
import 'services/offline_story_service.dart';
import 'models/local/story_local.dart';

class SavedStoriesScreen extends StatefulWidget {
  // ... existing code
}

class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  late OfflineStoryService _offlineService;
  List<StoryLocal> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _offlineService = OfflineStoryService(IsarService.instance);
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);

    try {
      final stories = await _offlineService.getAllStories();
      setState(() {
        _stories = stories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(String storyId) async {
    await _offlineService.toggleFavorite(storyId);
    await _loadStories(); // Reload
  }

  Future<void> _deleteStory(String storyId) async {
    await _offlineService.deleteStory(storyId);
    await _loadStories(); // Reload
  }

  // ... rest of widget build with _stories list
}
```

**8. Add Migration Helper**

Create `lib/services/storage_migration.dart`:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'isar_service.dart';
import 'offline_story_service.dart';
import '../models/local/story_local.dart';

class StorageMigration {
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool('isar_migration_complete') ?? false;

    if (migrated) return; // Already migrated

    print('Starting migration from SharedPreferences to Isar...');

    final isar = await IsarService.getInstance();
    final offlineService = OfflineStoryService(isar);

    // Migrate cached stories
    final cachedStories = prefs.getStringList('cached_stories') ?? [];
    int migratedCount = 0;

    for (final storyJson in cachedStories) {
      try {
        final json = jsonDecode(storyJson);
        final story = StoryLocal.fromJson(json);
        await offlineService.saveStory(story);
        migratedCount++;
      } catch (e) {
        print('Failed to migrate story: $e');
      }
    }

    // Mark migration complete
    await prefs.setBool('isar_migration_complete', true);
    await prefs.remove('cached_stories'); // Clean up old data

    print('Migration complete! Migrated $migratedCount stories.');
  }
}
```

Call this in `main.dart` after initializing Isar:
```dart
import 'services/storage_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await IsarService.getInstance();
  await StorageMigration.migrateFromSharedPreferences();

  // ... rest
}
```

**9. Testing Requirements (MANDATORY)**

Run these tests and paste FULL output in your report:

```bash
# Run flutter tests
flutter test

# Run the app
flutter run -d chrome

# Test offline mode:
# 1. Generate a story
# 2. Save it to favorites
# 3. Enable airplane mode (Dev Tools > Network > Offline)
# 4. Restart app
# 5. Verify story is still accessible
# 6. Disable airplane mode
# 7. Verify sync status

# Test migration:
# 1. Clear app data
# 2. Manually add story to SharedPreferences (using Dev Tools)
# 3. Restart app
# 4. Verify story migrated to Isar
# 5. Verify old SharedPreferences entry deleted
```

**10. Commit and Push**

```bash
git add .
git commit -m "Feature: Implement Isar for offline-first storage

- Add Isar database dependencies
- Create StoryLocal and CharacterLocal models
- Implement IsarService for database access
- Create OfflineStoryService with offline CRUD operations
- Update saved_stories_screen to use Isar
- Add migration from SharedPreferences
- Initialize Isar in main.dart

Benefits:
- True offline-first functionality
- Stories accessible without internet
- Background sync when online
- Better performance than SharedPreferences
- Unlimited storage (not limited to 50 stories)

Tests: [paste results]
Migration: [paste results]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/offline-first
```

**11. Report in TEAM_COORDINATION.md**

Add this section:
```markdown
## Agent 1 - Offline-First | 2025-12-03

### Task: Isar Database Implementation

### Files Changed
- Created: lib/models/local/story_local.dart
- Created: lib/models/local/character_local.dart
- Created: lib/services/isar_service.dart
- Created: lib/services/offline_story_service.dart
- Created: lib/services/storage_migration.dart
- Modified: lib/main.dart (Isar initialization)
- Modified: lib/saved_stories_screen.dart (use Isar)
- Modified: pubspec.yaml (add dependencies)

### Test Results
```
[PASTE FULL flutter test OUTPUT HERE]
```

### Manual Testing Results
- [ ] Stories save offline: SUCCESS/FAIL
- [ ] App works in airplane mode: SUCCESS/FAIL
- [ ] Stories accessible after restart: SUCCESS/FAIL
- [ ] Migration from SharedPreferences: SUCCESS/FAIL (X stories migrated)
- [ ] Old data deleted: SUCCESS/FAIL

### Issues Encountered
[List any issues or "None"]

### Status
✅ COMPLETE - Ready for supervisor verification
```

#### Success Criteria
- [ ] Isar dependencies added
- [ ] Data models created with generators
- [ ] Isar initialized in main.dart
- [ ] Offline service implements CRUD operations
- [ ] saved_stories_screen uses Isar
- [ ] Migration from SharedPreferences works
- [ ] All flutter tests pass
- [ ] App works in airplane mode
- [ ] Stories persist across app restarts

#### IMPORTANT
- DO NOT merge to main - wait for supervisor
- DO NOT work on backend files
- DO NOT modify other screens beyond saved_stories
- TEST OFFLINE MODE THOROUGHLY

---

## AGENT 2: Celery Async Task Queue

**You are Agent 2 (Backend)** working on Story Weaver app.

#### Mission
Make story generation async using Celery to prevent UI blocking.

#### Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/celery-integration
```

#### Working Directory
`C:\dev\story-weaver-app\backend`

#### Your Scope
You ONLY work on:
- `backend/celery_config.py` - Celery configuration
- `backend/routes/story_routes.py` - Update story endpoints
- `backend/tasks/story_tasks.py` - Celery task definitions
- `backend/requirements.txt` - Add dependencies

**DO NOT touch:**
- Frontend files (`lib/**`)
- Other backend routes
- Database models

#### Task Steps

**1. Verify Celery Setup**

Check `backend/celery_config.py` exists. If not, create it:
```python
from celery import Celery
import os

# Get Redis URL from environment
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')

# Initialize Celery
celery = Celery(
    'story_weaver',
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=['backend.tasks.story_tasks']
)

# Celery configuration
celery.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=600,  # 10 minute max per task
    result_expires=3600,  # Results expire after 1 hour
)
```

**2. Add Dependencies**

Update `backend/requirements.txt`:
```
celery==5.3.4
redis==5.0.1
```

Run: `pip install -r requirements.txt`

**3. Create Story Tasks**

Create `backend/tasks/story_tasks.py`:
```python
from backend.celery_config import celery
from backend.services.story_service import AdvancedStoryEngine
from backend.database import db
from backend.models.story import Story
from backend.models.character import Character
import traceback

@celery.task(bind=True, name='tasks.generate_story')
def generate_story_task(self, **kwargs):
    """
    Async story generation task.

    Args:
        character_id: ID of character
        theme: Story theme
        user_id: User ID
        ... other story params

    Returns:
        dict: Story data
    """
    try:
        # Update task state
        self.update_state(state='PROCESSING', meta={'status': 'Generating story...'})

        # Initialize story engine
        engine = AdvancedStoryEngine()

        # Get character
        character = Character.query.get(kwargs.get('character_id'))
        if not character:
            raise ValueError(f"Character {kwargs.get('character_id')} not found")

        # Generate story
        result = engine.generate_story(
            character=character,
            theme=kwargs.get('theme'),
            include_illustrations=kwargs.get('include_illustrations', False),
            rhyme_time_mode=kwargs.get('rhyme_time_mode', False),
            learning_to_read_mode=kwargs.get('learning_to_read_mode', False),
        )

        # Save to database
        story = Story(
            title=result.get('title'),
            story_text=result.get('story'),
            theme=kwargs.get('theme'),
            user_id=kwargs.get('user_id'),
            character_id=kwargs.get('character_id'),
        )
        db.session.add(story)
        db.session.commit()

        return {
            'status': 'complete',
            'story': {
                'id': story.id,
                'title': story.title,
                'story_text': story.story_text,
                'theme': story.theme,
            }
        }

    except Exception as e:
        # Log error
        error_msg = str(e)
        traceback.print_exc()

        # Update task state
        self.update_state(
            state='FAILURE',
            meta={'error': error_msg, 'traceback': traceback.format_exc()}
        )

        raise
```

**4. Update Story Route**

Modify `backend/routes/story_routes.py` to use async task:

Find the `/generate-story` endpoint and update:
```python
from ..tasks.story_tasks import generate_story_task

@story_bp.route('/generate-story', methods=['POST'])
def generate_story():
    """Start async story generation"""
    data = request.get_json()

    # Validate input
    character_id = data.get('character_id')
    theme = data.get('theme')
    user_id = data.get('user_id', 'anonymous')

    if not character_id or not theme:
        return jsonify({'error': 'character_id and theme required'}), 400

    # Start async task
    task = generate_story_task.delay(
        character_id=character_id,
        theme=theme,
        user_id=user_id,
        include_illustrations=data.get('include_illustrations', False),
        rhyme_time_mode=data.get('rhyme_time_mode', False),
        learning_to_read_mode=data.get('learning_to_read_mode', False),
    )

    return jsonify({
        'task_id': task.id,
        'status': 'processing',
        'message': 'Story generation started',
        'poll_url': f'/task-status/{task.id}'
    }), 202  # HTTP 202 Accepted

@story_bp.route('/task-status/<task_id>', methods=['GET'])
def get_task_status(task_id):
    """Poll for task completion"""
    from ..celery_config import celery

    task = celery.AsyncResult(task_id)

    if task.state == 'PENDING':
        response = {
            'status': 'pending',
            'message': 'Task is waiting to start'
        }
    elif task.state == 'PROCESSING':
        response = {
            'status': 'processing',
            'message': task.info.get('status', 'Generating story...')
        }
    elif task.state == 'SUCCESS':
        response = {
            'status': 'complete',
            'result': task.result
        }
    elif task.state == 'FAILURE':
        response = {
            'status': 'failed',
            'error': str(task.info),
        }
    else:
        response = {
            'status': task.state.lower(),
            'message': f'Task state: {task.state}'
        }

    return jsonify(response)
```

**5. Update App Initialization**

Ensure `backend/app.py` imports celery_config:
```python
from .celery_config import celery
```

**6. Testing Requirements (MANDATORY)**

Test locally:

```bash
# Terminal 1: Start Redis
redis-server

# Terminal 2: Start Celery worker
cd backend
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
celery -A backend.celery_config worker --loglevel=info

# Terminal 3: Start Flask
cd backend
source .venv/bin/activate
python app.py

# Terminal 4: Test endpoint
curl -X POST http://localhost:5000/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character_id": 1, "theme": "adventure", "user_id": "test"}'

# Should return: {"task_id": "xxx", "status": "processing", ...}

# Poll for result
curl http://localhost:5000/task-status/xxx

# Should eventually return: {"status": "complete", "result": {...}}
```

**Paste FULL output in your report.**

**7. Commit and Push**

```bash
git add .
git commit -m "Feature: Integrate Celery for async story generation

- Configure Celery with Redis backend
- Create story generation async task
- Update /generate-story to return task_id (202 Accepted)
- Add /task-status/<task_id> polling endpoint
- Add proper error handling and state updates

Benefits:
- Story generation no longer blocks UI
- Better user experience
- Can handle concurrent generation requests
- Task status tracking

Tests: [paste results]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com}"

git push origin feature/celery-integration
```

**8. Report in TEAM_COORDINATION.md**

```markdown
## Agent 2 - Backend Tasks | 2025-12-03

### Task: Celery Async Task Queue

### Files Changed
- Modified: backend/celery_config.py
- Created: backend/tasks/story_tasks.py
- Modified: backend/routes/story_routes.py
- Modified: backend/requirements.txt
- Modified: backend/app.py

### Test Results
```
[PASTE CELERY TEST OUTPUT]
```

### Manual Testing Results
- [ ] Redis starts: SUCCESS/FAIL
- [ ] Celery worker starts: SUCCESS/FAIL
- [ ] /generate-story returns task_id: SUCCESS/FAIL
- [ ] /task-status polls correctly: SUCCESS/FAIL
- [ ] Story completes successfully: SUCCESS/FAIL
- [ ] Error handling works: SUCCESS/FAIL

### Performance
- Story generation time: X seconds
- Task queue latency: X ms
- Concurrent tasks handled: X

### Issues Encountered
[List any issues or "None"]

### Status
✅ COMPLETE - Ready for supervisor verification

### Deployment Notes
Production requires:
- Redis instance (Railway addon or external)
- Celery worker process running
- Environment variable: REDIS_URL
```

#### Success Criteria
- [ ] Celery configured with Redis
- [ ] Story task implemented
- [ ] /generate-story returns 202 + task_id
- [ ] /task-status polls work
- [ ] Error handling implemented
- [ ] Local testing successful
- [ ] Documentation updated

#### IMPORTANT
- DO NOT merge to main - wait for supervisor
- DO NOT modify frontend
- TEST WITH REAL REDIS - not mocks
- DOCUMENT DEPLOYMENT REQUIREMENTS

---

## WAVE 2: Code Quality (Week 2)

### AGENT 3: State Management with Riverpod

**You are Agent 3 (Frontend Architecture)** working on Story Weaver app.

#### Mission
Refactor from setState to Riverpod for centralized state management.

#### Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/state-management
```

#### Working Directory
`C:\dev\story-weaver-app`

#### Your Scope
You ONLY work on:
- `lib/providers/` - State providers
- `lib/main.dart` - Wrap with ProviderScope
- `lib/saved_stories_screen.dart` - Convert to ConsumerWidget
- `lib/story_screen.dart` - Convert to ConsumerWidget
- `lib/settings_screen.dart` - Convert to ConsumerWidget
- `pubspec.yaml` - Add dependencies

**DO NOT touch:**
- Backend files (`backend/**`)
- Complex screens with forms (leave for now)
- Widget components

#### Task Steps

**1. Add Dependencies**

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

dev_dependencies:
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.6
```

Run: `flutter pub get`

**2. Wrap App with ProviderScope**

Update `lib/main.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing initialization

  runApp(
    ProviderScope(
      child: const StoryWeaverApp(),
    ),
  );
}
```

**3. Create Story Provider**

Create `lib/providers/story_provider.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local/story_local.dart';
import '../services/isar_service.dart';
import '../services/offline_story_service.dart';

part 'story_provider.g.dart';

@riverpod
OfflineStoryService offlineStoryService(OfflineStoryServiceRef ref) {
  return OfflineStoryService(IsarService.instance);
}

@riverpod
class StoryList extends _$StoryList {
  @override
  Future<List<StoryLocal>> build() async {
    final service = ref.watch(offlineStoryServiceProvider);
    return await service.getAllStories();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(offlineStoryServiceProvider);
      return await service.getAllStories();
    });
  }

  Future<void> toggleFavorite(String storyId) async {
    final service = ref.read(offlineStoryServiceProvider);
    await service.toggleFavorite(storyId);
    await refresh();
  }

  Future<void> deleteStory(String storyId) async {
    final service = ref.read(offlineStoryServiceProvider);
    await service.deleteStory(storyId);
    await refresh();
  }
}

@riverpod
class FavoriteStories extends _$FavoriteStories {
  @override
  Future<List<StoryLocal>> build() async {
    final service = ref.watch(offlineStoryServiceProvider);
    return await service.getFavorites();
  }
}
```

**4. Generate Provider Code**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**5. Convert Saved Stories Screen**

Update `lib/saved_stories_screen.dart`:

BEFORE (setState):
```dart
class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  List<StoryLocal> _stories = [];
  bool _isLoading = true;

  void _loadStories() async {
    setState(() => _isLoading = true);
    final stories = await offlineService.getAllStories();
    setState(() {
      _stories = stories;
      _isLoading = false;
    });
  }
}
```

AFTER (Riverpod):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/story_provider.dart';

class SavedStoriesScreen extends ConsumerWidget {
  const SavedStoriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storyListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Stories')),
      body: storiesAsync.when(
        data: (stories) => ListView.builder(
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            return ListTile(
              title: Text(story.title),
              subtitle: Text(story.theme),
              trailing: IconButton(
                icon: Icon(
                  story.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                onPressed: () {
                  ref.read(storyListProvider.notifier).toggleFavorite(story.storyId);
                },
              ),
              onLongPress: () {
                ref.read(storyListProvider.notifier).deleteStory(story.storyId);
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.refresh(storyListProvider),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

**6. Create Theme Provider**

Create `lib/providers/theme_provider.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode') ?? 'system';
    state = _themeModeFromString(themeString);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  void toggle() {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setThemeMode(newMode);
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
```

Generate: `flutter pub run build_runner build`

**7. Update Settings Screen**

Convert `lib/settings_screen.dart` to use theme provider:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return ListTile(
      title: const Text('Dark Mode'),
      trailing: Switch(
        value: themeMode == ThemeMode.dark,
        onChanged: (value) {
          ref.read(themeModeNotifierProvider.notifier).toggle();
        },
      ),
    );
  }
}
```

**8. Update Main App**

Update `lib/main.dart` to use theme provider:
```dart
class StoryWeaverApp extends ConsumerWidget {
  const StoryWeaverApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return MaterialApp(
      themeMode: themeMode,
      // ... rest of MaterialApp
    );
  }
}
```

**9. Testing Requirements**

```bash
# Run tests
flutter test

# Run app
flutter run -d chrome

# Manual tests:
# 1. Toggle dark mode - verify it persists after restart
# 2. Add/remove favorites - verify state updates
# 3. Delete story - verify list updates
# 4. Pull to refresh - verify loading state
# 5. Navigate between screens - verify state persists
```

**10. Commit and Push**

```bash
git add .
git commit -m "Refactor: Implement Riverpod state management

- Add flutter_riverpod dependencies
- Create providers for stories, favorites, theme
- Convert SavedStoriesScreen to ConsumerWidget
- Convert SettingsScreen to use ThemeModeProvider
- Update main app to use ProviderScope
- Remove setState from converted screens

Benefits:
- Centralized state management
- Better performance (selective rebuilds)
- Easier to test
- State persists across navigation
- No props drilling

Tests: [paste results]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/state-management
```

**11. Report in TEAM_COORDINATION.md**

```markdown
## Agent 3 - State Management | 2025-12-03

### Task: Riverpod Implementation

### Files Changed
- Created: lib/providers/story_provider.dart
- Created: lib/providers/theme_provider.dart
- Modified: lib/main.dart (ProviderScope, ConsumerWidget)
- Modified: lib/saved_stories_screen.dart (ConsumerWidget)
- Modified: lib/settings_screen.dart (ConsumerWidget)
- Modified: pubspec.yaml (riverpod dependencies)

### Test Results
```
[PASTE flutter test OUTPUT]
```

### Manual Testing Results
- [ ] Dark mode toggle works: SUCCESS/FAIL
- [ ] Dark mode persists after restart: SUCCESS/FAIL
- [ ] Story list updates on changes: SUCCESS/FAIL
- [ ] Favorite toggle works: SUCCESS/FAIL
- [ ] Delete story works: SUCCESS/FAIL
- [ ] Refresh works: SUCCESS/FAIL
- [ ] State persists across navigation: SUCCESS/FAIL

### Code Metrics
- Screens converted to Riverpod: 3
- setState removed from: saved_stories, settings, main app
- Providers created: 4 (story list, favorites, theme, offline service)

### Issues Encountered
[List any issues or "None"]

### Status
✅ COMPLETE - Ready for supervisor verification
```

#### Success Criteria
- [ ] Riverpod installed and configured
- [ ] ProviderScope wraps app
- [ ] Story provider implemented
- [ ] Theme provider implemented
- [ ] At least 2 screens use ConsumerWidget
- [ ] No setState in converted screens
- [ ] All tests pass
- [ ] State persists across navigation

#### IMPORTANT
- DO NOT convert ALL screens at once - start small
- DO NOT touch backend
- DO NOT modify complex form screens yet
- TEST each screen after conversion

---

### AGENT 4: Accessibility Fix

**You are Agent 4 (Frontend UX)** working on Story Weaver app.

#### Mission
Re-add accessibility (Semantics widgets) safely without causing infinite loops.

#### Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/accessibility-fix
```

#### Working Directory
`C:\dev\story-weaver-app`

#### Your Scope
You ONLY work on:
- `lib/widgets/app_button.dart` - Add tooltips
- `lib/widgets/app_switch.dart` - Use built-in semantics
- `lib/main_story.dart` - Navigation semantics only
- `lib/story_result_screen.dart` - Action button semantics
- Test files for accessibility

**DO NOT touch:**
- Backend files
- Complex screens (saved_stories, character_creation)
- Any StatefulWidgets with frequent rebuilds

#### Background: Why We Removed Semantics
Semantics widgets were causing **infinite rebuild loops** (Stack Overflow):
1. Semantics widget wraps StatefulWidget
2. Semantics triggers parent rebuild
3. Parent rebuilds Semantics
4. Loop → crash

#### Solution: Use Built-in Semantic Properties

**❌ BAD (causes loops):**
```dart
Semantics(
  label: 'Delete',
  button: true,
  child: IconButton(...), // Triggers rebuild
)
```

**✅ GOOD (safe):**
```dart
IconButton(
  tooltip: 'Delete story', // Automatic semantics
  icon: Icon(Icons.delete),
)
```

#### Task Steps

**1. Phase 1: Critical Navigation (1 hour)**

Update `lib/widgets/app_button.dart`:

BEFORE:
```dart
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}
```

AFTER:
```dart
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final String? semanticLabel; // NEW

  const AppButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.semanticLabel, // NEW
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip( // NEW - provides semantics
      message: semanticLabel ?? text,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
```

Update `lib/widgets/app_switch.dart`:

BEFORE:
```dart
Switch(value: value, onChanged: onChanged)
```

AFTER:
```dart
SwitchListTile( // Built-in semantics
  title: Text(label),
  value: value,
  onChanged: onChanged,
  secondary: icon != null ? Icon(icon) : null,
)
```

**2. Test After Phase 1**

```bash
flutter test
flutter run -d chrome

# Enable screen reader (browser extension)
# Navigate to buttons
# Verify screen reader announces button labels
```

**3. Phase 2: Story Actions (30 min)**

Update `lib/story_result_screen.dart`:

Add tooltips to action buttons:
```dart
IconButton(
  tooltip: 'Share story', // Automatic semantics
  icon: const Icon(Icons.share),
  onPressed: _shareStory,
)

IconButton(
  tooltip: 'Save to favorites',
  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
  onPressed: _toggleFavorite,
)

IconButton(
  tooltip: 'Delete story',
  icon: const Icon(Icons.delete),
  onPressed: _deleteStory,
)
```

**4. Test After Phase 2**

```bash
flutter run -d chrome
# Test with screen reader
# Verify all action buttons announced
```

**5. Create Accessibility Tests**

Create `test/accessibility_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/app_button.dart';

void main() {
  testWidgets('AppButton has semantic label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            text: 'Click Me',
            semanticLabel: 'Submit form',
            onPressed: () {},
          ),
        ),
      ),
    );

    // Find by semantic label
    final semanticFinder = find.bySemanticsLabel('Submit form');
    expect(semanticFinder, findsOneWidget);

    // Verify tappable
    final semantics = tester.getSemantics(semanticFinder);
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('IconButton with tooltip has semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconButton(
            tooltip: 'Delete story',
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ),
      ),
    );

    final semanticFinder = find.bySemanticsLabel('Delete story');
    expect(semanticFinder, findsOneWidget);
  });
}
```

**6. Testing Requirements**

```bash
# Run accessibility tests
flutter test test/accessibility_test.dart

# Run all tests
flutter test

# Manual screen reader testing
# iOS: Enable VoiceOver
# Android: Enable TalkBack
# Web: Use browser screen reader

# Navigate entire app using ONLY screen reader
# Verify:
# - All buttons announced
# - All actions accessible
# - No infinite loops
# - No crashes
```

**7. Commit and Push**

```bash
git add .
git commit -m "Accessibility: Add semantic labels to critical UI elements

Phase 1: Critical navigation
- Add tooltips to AppButton (automatic semantics)
- Convert Switch to SwitchListTile (built-in semantics)
- Test with screen readers - no infinite loops

Phase 2: Story actions
- Add tooltips to share, favorite, delete buttons
- Test accessibility of story result screen

Created accessibility_test.dart with semantic tests.

Benefits:
- Screen readers can navigate app
- Complies with accessibility standards
- Safe implementation (no infinite loops)
- Tested with VoiceOver/TalkBack

Tests: [paste results]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/accessibility-fix
```

**8. Report in TEAM_COORDINATION.md**

```markdown
## Agent 4 - Accessibility | 2025-12-03

### Task: Safe Semantics Implementation

### Files Changed
- Modified: lib/widgets/app_button.dart (added tooltip)
- Modified: lib/widgets/app_switch.dart (SwitchListTile)
- Modified: lib/story_result_screen.dart (action button tooltips)
- Created: test/accessibility_test.dart

### Test Results
```
[PASTE flutter test OUTPUT]
```

### Manual Testing Results
- [ ] Screen reader announces buttons: SUCCESS/FAIL
- [ ] Navigation accessible: SUCCESS/FAIL
- [ ] Action buttons announced: SUCCESS/FAIL
- [ ] No infinite loops: SUCCESS/FAIL
- [ ] No crashes: SUCCESS/FAIL

### Screen Reader Testing
- Platform tested: iOS/Android/Web
- Screen reader: VoiceOver/TalkBack/Browser
- Issues found: [list or "None"]

### Issues Encountered
[List any issues or "None"]

### Status
✅ COMPLETE - Ready for supervisor verification
```

#### Success Criteria
- [ ] Tooltips added to buttons
- [ ] SwitchListTile used for switches
- [ ] Accessibility tests created
- [ ] All tests pass
- [ ] Screen reader testing successful
- [ ] No infinite rebuild loops
- [ ] No crashes

#### IMPORTANT Rules
1. ✅ DO use built-in semantic properties (tooltip, semanticLabel)
2. ✅ DO test after EACH change
3. ❌ DON'T wrap StatefulWidgets in Semantics
4. ❌ DON'T add Semantics to frequently-rebuilding widgets
5. ❌ DON'T modify complex screens yet

---

## Coordination Protocol

### File Ownership
- **Agent 1:** lib/models/local/, lib/services/isar*, lib/services/offline*, lib/saved_stories_screen.dart
- **Agent 2:** backend/celery*, backend/tasks/, backend/routes/story_routes.py
- **Agent 3:** lib/providers/, lib/main.dart, lib/settings_screen.dart
- **Agent 4:** lib/widgets/app_button.dart, lib/widgets/app_switch.dart, test/accessibility_test.dart

### Conflict Prevention
- Each agent works on separate files
- No shared files in Phase 2
- All agents work on separate branches

### Reporting
All agents MUST report in TEAM_COORDINATION.md with:
- Full test output (not just "tests passed")
- Manual testing results
- Issues encountered
- Files changed

### DO NOT
- Merge to main (wait for supervisor)
- Work outside your scope
- Skip testing
- Mark tasks complete yourself

---

**END OF PHASE 2 PROMPTS**
