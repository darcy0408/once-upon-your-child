# YOU ARE AGENT 2 - Riverpod State Management

**⚠️ IMPORTANT: You are Agent 2. This is YOUR task file. Do NOT read other agent files.**

---

## Your Assignment

**Task:** Refactor from setState to Riverpod for centralized state management
**Your Branch:** `feature/riverpod-state-management`
**Estimated Time:** 3 days
**Terminal:** WSL Codex

---

## BEFORE YOU START - Branch Verification

Run these commands and verify:

```bash
cd /mnt/c/dev/story-weaver-app
git checkout main
git pull origin main
git checkout -b feature/riverpod-state-management

# VERIFY YOU'RE ON THE RIGHT BRANCH
git branch --show-current
# Must show: feature/riverpod-state-management

# If it shows anything else, STOP and ask supervisor
```

---

## Your File Scope (ONLY TOUCH THESE)

✅ **You CAN modify:**
- `lib/providers/` (CREATE new directory)
- `lib/providers/story_provider.dart` (CREATE)
- `lib/providers/theme_provider.dart` (CREATE)
- `lib/main.dart` (MODIFY - wrap with ProviderScope)
- `lib/saved_stories_screen.dart` (MODIFY - convert to ConsumerWidget)
- `lib/settings_screen.dart` (MODIFY - convert to ConsumerWidget)
- `pubspec.yaml` (ADD dependencies)

❌ **DO NOT touch:**
- Backend files (`backend/**`)
- Widget files (`lib/widgets/**`)
- Other screens
- Test files (unless creating new provider tests)

---

## Step-by-Step Instructions

### Step 1: Add Dependencies (15 minutes)

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

dev_dependencies:
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.6
```

Run:
```bash
flutter pub get
```

---

### Step 2: Wrap App with ProviderScope (15 minutes)

Update `lib/main.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing initialization (Isar, Firebase, etc.)

  runApp(
    ProviderScope(  // NEW - wrap app
      child: const StoryWeaverApp(),
    ),
  );
}
```

---

### Step 3: Create Story Provider (1 hour)

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

Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This creates `story_provider.g.dart` - commit this file too.

---

### Step 4: Create Theme Provider (1 hour)

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

Generate code again:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Step 5: Convert Saved Stories Screen (2 hours)

Update `lib/saved_stories_screen.dart`:

**BEFORE (setState):**
```dart
class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  late OfflineStoryService _offlineService;
  List<StoryLocal> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _offlineService = OfflineStoryService(IsarService.instance);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final stories = await _offlineService.getAllStories();
    setState(() {
      _stories = stories;
      _isLoading = false;
    });
  }
}
```

**AFTER (Riverpod):**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/story_provider.dart';

class SavedStoriesScreen extends ConsumerWidget {
  const SavedStoriesScreen({super.key});

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
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.refresh(storyListProvider),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

**Key changes:**
- StatefulWidget → ConsumerWidget
- No more setState
- Use `ref.watch()` to listen to state
- Use `ref.read().notifier` to update state
- Automatic rebuilds when data changes

---

### Step 6: Convert Settings Screen (1 hour)

Update `lib/settings_screen.dart` to use theme provider:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

// Find the dark mode toggle section and replace with:

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return Scaffold(
      // ... existing scaffold structure
      body: ListView(
        children: [
          // ... existing settings

          // Dark mode toggle
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeNotifierProvider.notifier).toggle();
            },
          ),

          // ... rest of settings
        ],
      ),
    );
  }
}
```

---

### Step 7: Update Main App to Use Theme Provider (30 minutes)

Update `lib/main.dart`:

```dart
import 'providers/theme_provider.dart';

class StoryWeaverApp extends ConsumerWidget {
  const StoryWeaverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return MaterialApp(
      themeMode: themeMode,
      // ... rest of MaterialApp config
    );
  }
}
```

**Change:** `StatelessWidget` → `ConsumerWidget`

---

### Step 8: Testing (MANDATORY - 2 hours)

```bash
# Generate all provider code
flutter pub run build_runner build --delete-conflicting-outputs

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
# 6. Kill and restart app - verify theme persists
```

**Expected results:**
- All existing tests should still pass
- Dark mode persists across restarts
- Story list updates without setState
- No "setState called during build" errors

---

### Step 9: Commit and Push

```bash
git add lib/providers/ lib/main.dart lib/saved_stories_screen.dart lib/settings_screen.dart pubspec.yaml pubspec.lock

git commit -m "Feature: Implement Riverpod state management

- Add flutter_riverpod dependencies
- Create providers for stories, favorites, theme
- Convert SavedStoriesScreen to ConsumerWidget
- Convert SettingsScreen to use ThemeModeProvider
- Update main app to use ProviderScope and ConsumerWidget
- Remove setState from converted screens
- Generate provider code with build_runner

Benefits:
- Centralized state management
- Better performance (selective rebuilds)
- Easier to test
- State persists across navigation
- No props drilling
- Eliminates setState bugs

Test Results: [paste flutter test output]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/riverpod-state-management

git log --oneline -1
```

---

### Step 10: Report Completion

Update `TEAM_COORDINATION.md` with this section:

```markdown
## Agent 2 - Riverpod State Management | 2025-12-04

### Task: Riverpod Implementation

### Files Changed
- Created: lib/providers/story_provider.dart
- Created: lib/providers/story_provider.g.dart
- Created: lib/providers/theme_provider.dart
- Created: lib/providers/theme_provider.g.dart
- Modified: lib/main.dart (ProviderScope, ConsumerWidget)
- Modified: lib/saved_stories_screen.dart (ConsumerWidget)
- Modified: lib/settings_screen.dart (ConsumerWidget)
- Modified: pubspec.yaml (riverpod dependencies)

### Test Results
```
[PASTE FULL flutter test OUTPUT HERE]
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
- Screens converted to Riverpod: 2 (saved_stories, settings)
- setState removed: Yes
- Providers created: 4 (story list, favorites, theme, offline service)

### Issues Encountered
[List any issues or "None"]

### Status
✅ COMPLETE - Ready for supervisor verification
```

Then report:
```
✅ Agent 2 COMPLETE - Pushed to feature/riverpod-state-management. Ready for supervisor merge.
```

---

## Success Criteria

Before reporting complete, verify:

- [x] Riverpod installed and configured
- [x] ProviderScope wraps app in main.dart
- [x] Story provider implemented
- [x] Theme provider implemented
- [x] At least 2 screens use ConsumerWidget
- [x] No setState in converted screens
- [x] All tests pass
- [x] State persists across navigation
- [x] Dark mode persists across app restarts
- [x] Generated .g.dart files committed

---

## IMPORTANT REMINDERS

**Branch Check:**
- Always verify: `git branch --show-current` shows `feature/riverpod-state-management`
- If you see ANY other branch name, STOP and ask supervisor

**File Scope:**
- ONLY touch files listed in "Your File Scope" section
- DO NOT modify backend files
- DO NOT modify widget files
- DO NOT modify other screens (beyond saved_stories, settings)

**Testing:**
- Paste FULL flutter test output (not just "tests passed")
- Do manual testing checklist
- Test dark mode persistence across restarts

**DO NOT:**
- Merge to main (wait for supervisor)
- Work outside your file scope
- Skip testing
- Read other agents' instruction files

---

## Need Help?

If you encounter issues:
1. Check you're on the right branch
2. Check you're only modifying files in your scope
3. Run `flutter pub get` if build errors
4. Run `flutter pub run build_runner build` if .g.dart files missing
5. Ask supervisor for help

---

**Ready? Start with Step 1: Add Dependencies**

Good luck! 🚀
