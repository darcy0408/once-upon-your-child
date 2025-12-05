# YOU ARE AGENT 2 - Riverpod Expansion

**⚠️ IMPORTANT: You are Agent 2. This is YOUR task file. Do NOT read other agent files.**

---

## Your Assignment

**Task:** Expand Riverpod to remaining screens and add advanced state features
**Your Branch:** `feature/riverpod-expansion`
**Estimated Time:** 2 days
**Terminal:** WSL Codex

---

## BEFORE YOU START - Branch Verification

Run these commands and verify:

```bash
cd /mnt/c/dev/story-weaver-app
git checkout main
git pull origin main
git checkout -b feature/riverpod-expansion

# VERIFY YOU'RE ON THE RIGHT BRANCH
git branch --show-current
# Must show: feature/riverpod-expansion

# If it shows anything else, STOP and ask supervisor
```

---

## Your File Scope (ONLY TOUCH THESE)

✅ **You CAN modify:**
- `lib/providers/` (ADD new providers)
- `lib/providers/character_provider.dart` (CREATE)
- `lib/providers/quick_story_provider.dart` (CREATE)
- `lib/providers/subscription_provider.dart` (CREATE)
- `lib/quick_story_screen.dart` (CONVERT to ConsumerWidget)
- `lib/character_creation_screen_enhanced.dart` (CONVERT to ConsumerWidget)
- `lib/main_story.dart` (CONVERT to ConsumerWidget)
- `lib/onboarding_screen.dart` (CONVERT to ConsumerWidget)
- `pubspec.yaml` (if adding dependencies)

❌ **DO NOT touch:**
- Test files (`test/**`) - Agent 3 owns
- Widget files (`lib/widgets/**`) - Agent 4 owns
- Error handling code - Agent 4 owns
- Backend files (`backend/**`)

---

## Context

You successfully implemented Riverpod for SavedStoriesScreen and SettingsScreen in Wave 2.

Now expand Riverpod to:
1. Character creation state
2. Quick story generation state
3. Subscription/paywall state
4. Main story screen state

This will complete the Riverpod migration across all major screens.

---

## Step-by-Step Instructions

### Step 1: Create Character Provider (1 hour)

Create `lib/providers/character_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local/character_local.dart';
import '../services/isar_service.dart';

part 'character_provider.g.dart';

@riverpod
class CharacterList extends _$CharacterList {
  @override
  Future<List<CharacterLocal>> build() async {
    final isar = await IsarService.getInstance();
    return await isar.characterLocals.where().findAll();
  }

  Future<void> addCharacter(CharacterLocal character) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.put(character);
    });
    ref.invalidateSelf();
  }

  Future<void> deleteCharacter(int id) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.delete(id);
    });
    ref.invalidateSelf();
  }

  Future<void> updateCharacter(CharacterLocal character) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.put(character);
    });
    ref.invalidateSelf();
  }
}

/// Provider for the currently selected character
@riverpod
class SelectedCharacter extends _$SelectedCharacter {
  @override
  CharacterLocal? build() {
    return null;
  }

  void selectCharacter(CharacterLocal character) {
    state = character;
  }

  void clearSelection() {
    state = null;
  }
}
```

Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Step 2: Create Quick Story Provider (1 hour)

Create `lib/providers/quick_story_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/api_service_manager.dart';

part 'quick_story_provider.g.dart';

/// State for quick story generation
class QuickStoryState {
  final bool isGenerating;
  final String? storyText;
  final String? error;

  const QuickStoryState({
    this.isGenerating = false,
    this.storyText,
    this.error,
  });

  QuickStoryState copyWith({
    bool? isGenerating,
    String? storyText,
    String? error,
  }) {
    return QuickStoryState(
      isGenerating: isGenerating ?? this.isGenerating,
      storyText: storyText ?? this.storyText,
      error: error ?? this.error,
    );
  }
}

@riverpod
class QuickStory extends _$QuickStory {
  @override
  QuickStoryState build() {
    return const QuickStoryState();
  }

  Future<void> generateStory({
    required String characterName,
    required int characterAge,
    required String theme,
    String? emotion,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final apiService = ApiServiceManager();
      final result = await apiService.generateStory(
        params: {
          'character_name': characterName,
          'character_age': characterAge,
          'theme': theme,
          if (emotion != null) 'emotion': emotion,
        },
      );

      state = state.copyWith(
        isGenerating: false,
        storyText: result['story_text'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const QuickStoryState();
  }
}
```

Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Step 3: Create Subscription Provider (1.5 hours)

Create `lib/providers/subscription_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/subscription_service.dart';

part 'subscription_provider.g.dart';

/// Subscription status state
class SubscriptionState {
  final String status; // 'active', 'inactive', 'past_due', etc.
  final String tier; // 'free', 'basic', 'premium'
  final int storiesRemaining;
  final int dailyLimit;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.status = 'inactive',
    this.tier = 'free',
    this.storiesRemaining = 0,
    this.dailyLimit = 3,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    String? status,
    String? tier,
    int? storiesRemaining,
    int? dailyLimit,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      tier: tier ?? this.tier,
      storiesRemaining: storiesRemaining ?? this.storiesRemaining,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get canCreateStory => storiesRemaining > 0;
  bool get isFreeTier => tier == 'free';
  bool get isPremium => tier == 'premium';
}

@riverpod
class Subscription extends _$Subscription {
  @override
  SubscriptionState build() {
    _loadSubscriptionStatus();
    return const SubscriptionState(isLoading: true);
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final service = SubscriptionService();
      final data = await service.getSubscriptionStatus();

      state = state.copyWith(
        status: data['status'] as String? ?? 'inactive',
        tier: data['tier'] as String? ?? 'free',
        storiesRemaining: data['stories_remaining'] as int? ?? 3,
        dailyLimit: data['daily_limit'] as int? ?? 3,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadSubscriptionStatus();
  }

  void decrementStoriesRemaining() {
    if (state.storiesRemaining > 0) {
      state = state.copyWith(
        storiesRemaining: state.storiesRemaining - 1,
      );
    }
  }
}
```

Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Step 4: Convert Quick Story Screen (1 hour)

Update `lib/quick_story_screen.dart`:

**BEFORE (setState):**
```dart
class _QuickStoryScreenState extends State<QuickStoryScreen> {
  bool _isGenerating = false;
  String? _storyText;

  Future<void> _generateStory() async {
    setState(() => _isGenerating = true);
    // ... API call
    setState(() {
      _isGenerating = false;
      _storyText = result;
    });
  }
}
```

**AFTER (Riverpod):**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/quick_story_provider.dart';
import 'providers/subscription_provider.dart';

class QuickStoryScreen extends ConsumerWidget {
  const QuickStoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickStory = ref.watch(quickStoryProvider);
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Story')),
      body: Column(
        children: [
          // Show subscription status
          if (subscription.isFreeTier)
            Text('Stories remaining today: ${subscription.storiesRemaining}'),

          // Show story or loading
          if (quickStory.isGenerating)
            const CircularProgressIndicator()
          else if (quickStory.storyText != null)
            Expanded(child: Text(quickStory.storyText!))
          else
            const Text('Generate a quick story!'),

          // Generate button
          ElevatedButton(
            onPressed: subscription.canCreateStory
                ? () {
                    ref.read(quickStoryProvider.notifier).generateStory(
                          characterName: 'Hero',
                          characterAge: 8,
                          theme: 'Adventure',
                        );
                    ref.read(subscriptionProvider.notifier).decrementStoriesRemaining();
                  }
                : null,
            child: const Text('Generate Story'),
          ),
        ],
      ),
    );
  }
}
```

---

### Step 5: Convert Character Creation Screen (1.5 hours)

Update `lib/character_creation_screen_enhanced.dart`:

Convert from `StatefulWidget` to `ConsumerStatefulWidget`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/character_provider.dart';

class CharacterCreationScreenEnhanced extends ConsumerStatefulWidget {
  const CharacterCreationScreenEnhanced({super.key});

  @override
  ConsumerState<CharacterCreationScreenEnhanced> createState() =>
      _CharacterCreationScreenEnhancedState();
}

class _CharacterCreationScreenEnhancedState
    extends ConsumerState<CharacterCreationScreenEnhanced> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Character')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            ElevatedButton(
              onPressed: _saveCharacter,
              child: const Text('Save Character'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCharacter() async {
    final character = CharacterLocal()
      ..name = _nameController.text
      ..age = int.tryParse(_ageController.text) ?? 8
      ..createdAt = DateTime.now();

    await ref.read(characterListProvider.notifier).addCharacter(character);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
```

---

### Step 6: Convert Main Story Screen (1 hour)

Update `lib/main_story.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/subscription_provider.dart';

class MainStoryScreen extends ConsumerWidget {
  const MainStoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Weaver'),
        actions: [
          // Show subscription tier
          Chip(
            label: Text(subscription.tier.toUpperCase()),
            backgroundColor: subscription.isPremium
                ? Colors.amber
                : Colors.grey,
          ),
        ],
      ),
      body: Column(
        children: [
          // Show paywall if no stories remaining
          if (!subscription.canCreateStory)
            Card(
              color: Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Daily story limit reached!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to subscription screen
                      },
                      child: const Text('Upgrade to Premium'),
                    ),
                  ],
                ),
              ),
            ),

          // Main content
          Expanded(
            child: Center(
              child: Text('Stories remaining: ${subscription.storiesRemaining}'),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Step 7: Testing (1 hour)

Run tests to ensure no regressions:

```bash
# Generate all provider code
flutter pub run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Run app
flutter run -d chrome
```

**Manual tests:**
1. Create a character → verify it appears in character list
2. Generate a quick story → verify loading state shows
3. Generate stories until limit → verify paywall appears
4. Toggle dark mode → verify subscription state persists
5. Navigate between screens → verify state persists

---

### Step 8: Commit and Push

```bash
git add lib/providers/ lib/quick_story_screen.dart lib/character_creation_screen_enhanced.dart lib/main_story.dart pubspec.yaml pubspec.lock

git commit -m "Feature: Expand Riverpod to all major screens

- Create character_provider for character CRUD operations
- Create quick_story_provider for story generation state
- Create subscription_provider for paywall/tier management
- Convert QuickStoryScreen to ConsumerWidget
- Convert CharacterCreationScreen to ConsumerStatefulWidget
- Convert MainStoryScreen to ConsumerWidget with subscription UI
- Add paywall UI when daily limit reached
- Generate all provider .g.dart files

Benefits:
- Complete Riverpod coverage across app
- Centralized character management
- Real-time subscription state
- No setState in major screens
- State persists across navigation
- Better testability

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin feature/riverpod-expansion
```

---

### Step 9: Report Completion

Update `TEAM_COORDINATION.md`:

```markdown
## Agent 2 - Riverpod Expansion | 2025-12-04

### Task: Expand Riverpod to All Major Screens

### Files Changed
- Created: lib/providers/character_provider.dart (.g.dart)
- Created: lib/providers/quick_story_provider.dart (.g.dart)
- Created: lib/providers/subscription_provider.dart (.g.dart)
- Modified: lib/quick_story_screen.dart (ConsumerWidget)
- Modified: lib/character_creation_screen_enhanced.dart (ConsumerStatefulWidget)
- Modified: lib/main_story.dart (ConsumerWidget with paywall UI)

### Screens Converted
- QuickStoryScreen ✅
- CharacterCreationScreen ✅
- MainStoryScreen ✅

### Test Results
[PASTE flutter test OUTPUT]

### Manual Testing
- [x] Character creation works
- [x] Quick story generation works
- [x] Subscription state updates
- [x] Paywall shows when limit reached
- [x] State persists across navigation

### Status
✅ COMPLETE - Ready for supervisor verification
```

Then report:
```
✅ Agent 2 COMPLETE - Riverpod expansion complete, pushed to feature/riverpod-expansion
```

---

## Success Criteria

- [x] 3 new providers created (character, quick_story, subscription)
- [x] 3 screens converted to Riverpod
- [x] All .g.dart files generated and committed
- [x] Tests pass
- [x] Manual testing completed
- [x] No setState in converted screens

---

## IMPORTANT REMINDERS

**Branch Check:**
- Always verify: `git branch --show-current` shows `feature/riverpod-expansion`

**File Scope:**
- ONLY touch files in your scope
- DO NOT modify test files (Agent 3)
- DO NOT modify widget files (Agent 4)

**Testing:**
- Run `flutter pub run build_runner build` after creating providers
- Test state persistence across navigation
- Test paywall UI

**DO NOT:**
- Merge to main (wait for supervisor)
- Work outside your file scope
- Read other agents' instruction files

---

**Ready? Start with Step 1: Create Character Provider**

Good luck! 🚀
