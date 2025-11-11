# Codex Task B: Post-Story Emotional Check (Week 1)

## 🎯 Goal
Add a post-story emotional check that compares how the child felt BEFORE vs. AFTER the story, showing emotional progress.

---

## 📍 Working Location
```bash
Directory: /mnt/c/dev/story-weaver-app
Branch: codex-post-story-check (create new branch)
Setup:
  git checkout main
  git pull origin main
  git checkout -b codex-post-story-check
```

**IMPORTANT:** Work on `codex-post-story-check` branch (separate from other Codex's `codex-dev` branch).

---

## 📦 What Already Exists (DO NOT MODIFY)

### Files You'll REFERENCE (study these):
- `lib/pre_story_feelings_dialog.dart` - The feelings check-in dialog (USE AS TEMPLATE)
- `lib/emotions_learning_system.dart` - Emotion data structures
- `lib/storage_service.dart` - How stories are saved
- `lib/models.dart` - SavedStory model

### Files You'll MODIFY:
- `lib/story_result_screen.dart` - Add post-story check here
- `lib/models.dart` - Add pre/post emotion fields to SavedStory
- `lib/storage_service.dart` - Save both emotions
- `lib/main_story.dart` - Pass pre-story feeling to story result

---

## 🏗️ What to Build

### Step 1: Create Post-Story Feelings Dialog

**File:** `lib/post_story_feelings_dialog.dart`

**Task:** Clone `pre_story_feelings_dialog.dart` and adapt it for post-story use.

**Key Changes:**
```dart
// Change the header text:
- 'How is ${widget.characterName} feeling?'
+ 'How does ${widget.characterName} feel now?'

// Change the subtitle:
- 'Let\'s create a story about this feeling'
+ 'Did the story help? Let\'s check in'

// Change the button text:
- 'Create Story'
+ 'All Done'

// Make "What happened" field optional or remove it
// (not needed for post-story)

// Return the same CurrentFeeling object
```

**Full Implementation:**
```dart
// lib/post_story_feelings_dialog.dart
import 'package:flutter/material.dart';
import 'emotions_learning_system.dart';
import 'pre_story_feelings_dialog.dart'; // Import for CurrentFeeling class

class PostStoryFeelingsDialog extends StatefulWidget {
  final String characterName;
  final CurrentFeeling? preStoryFeeling; // Show what they felt before

  const PostStoryFeelingsDialog({
    super.key,
    required this.characterName,
    this.preStoryFeeling,
  });

  @override
  State<PostStoryFeelingsDialog> createState() => _PostStoryFeelingsDialogState();

  /// Show the dialog and return the selected feeling
  static Future<CurrentFeeling?> show({
    required BuildContext context,
    required String characterName,
    CurrentFeeling? preStoryFeeling,
  }) async {
    return await showDialog<CurrentFeeling>(
      context: context,
      barrierDismissible: true, // Allow dismiss
      builder: (context) => PostStoryFeelingsDialog(
        characterName: characterName,
        preStoryFeeling: preStoryFeeling,
      ),
    );
  }
}

class _PostStoryFeelingsDialogState extends State<PostStoryFeelingsDialog> {
  final _service = EmotionsLearningService();
  Emotion? _selectedEmotion;
  int _intensity = 3;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How does ${widget.characterName} feel now?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'After the story',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Show before feeling if available
                if (widget.preStoryFeeling != null) _buildBeforeCard(),

                const SizedBox(height: 24),

                // Emotion Selection
                const Text(
                  'Choose how you feel now:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _service.getAllEmotions().map((emotion) {
                      final isSelected = _selectedEmotion?.id == emotion.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedEmotion = emotion);
                        },
                        child: Container(
                          width: 85,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? emotion.color.withOpacity(0.3)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? emotion.color : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emotion.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                emotion.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Emotion Details
                if (_selectedEmotion != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedEmotion!.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedEmotion!.color,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedEmotion!.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedEmotion!.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Intensity Slider
                  const SizedBox(height: 20),
                  const Text(
                    'How strong is this feeling?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Mild', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _intensity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _getIntensityLabel(_intensity),
                          activeColor: _selectedEmotion!.color,
                          onChanged: (value) {
                            setState(() => _intensity = value.toInt());
                          },
                        ),
                      ),
                      const Text('Very Strong', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Center(
                    child: Text(
                      _getIntensityLabel(_intensity),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedEmotion!.color,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedEmotion == null
                            ? null
                            : () {
                                final feeling = CurrentFeeling(
                                  emotion: _selectedEmotion!,
                                  intensity: _intensity,
                                  whatHappened: null, // Not needed post-story
                                );
                                Navigator.of(context).pop(feeling);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedEmotion?.color ?? Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'All Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Row(
        children: [
          Text(
            widget.preStoryFeeling!.emotion.emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Before: ${widget.preStoryFeeling!.emotion.name} (${widget.preStoryFeeling!.intensity}/5)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return 'A little';
      case 2:
        return 'Some';
      case 3:
        return 'Medium';
      case 4:
        return 'Strong';
      case 5:
        return 'Very strong';
      default:
        return 'Medium';
    }
  }
}
```

---

### Step 2: Update SavedStory Model

**File:** `lib/models.dart`

**Task:** Add fields to store pre/post emotions

Find the `SavedStory` class and add these fields:

```dart
class SavedStory {
  final String id;
  final String title;
  final String storyText;
  final String theme;
  final List<Character> characters;
  final DateTime createdAt;
  final bool isInteractive;
  final String? wisdomGem;
  final bool isFavorite;

  // ADD THESE NEW FIELDS:
  final String? preStoryEmotionId;
  final String? preStoryEmotionName;
  final int? preStoryIntensity;
  final String? postStoryEmotionId;
  final String? postStoryEmotionName;
  final int? postStoryIntensity;

  SavedStory({
    required this.id,
    required this.title,
    required this.storyText,
    required this.theme,
    required this.characters,
    required this.createdAt,
    this.isInteractive = false,
    this.wisdomGem,
    this.isFavorite = false,
    this.preStoryEmotionId,
    this.preStoryEmotionName,
    this.preStoryIntensity,
    this.postStoryEmotionId,
    this.postStoryEmotionName,
    this.postStoryIntensity,
  });

  // Update toJson method:
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'storyText': storyText,
      'theme': theme,
      'characters': characters.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isInteractive': isInteractive,
      'wisdomGem': wisdomGem,
      'isFavorite': isFavorite,
      // ADD THESE:
      'preStoryEmotionId': preStoryEmotionId,
      'preStoryEmotionName': preStoryEmotionName,
      'preStoryIntensity': preStoryIntensity,
      'postStoryEmotionId': postStoryEmotionId,
      'postStoryEmotionName': postStoryEmotionName,
      'postStoryIntensity': postStoryIntensity,
    };
  }

  // Update fromJson factory:
  factory SavedStory.fromJson(Map<String, dynamic> json) {
    return SavedStory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      storyText: json['storyText'] ?? '',
      theme: json['theme'] ?? '',
      characters: (json['characters'] as List?)
              ?.map((c) => Character.fromJson(c))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      isInteractive: json['isInteractive'] ?? false,
      wisdomGem: json['wisdomGem'],
      isFavorite: json['isFavorite'] ?? false,
      // ADD THESE:
      preStoryEmotionId: json['preStoryEmotionId'],
      preStoryEmotionName: json['preStoryEmotionName'],
      preStoryIntensity: json['preStoryIntensity'],
      postStoryEmotionId: json['postStoryEmotionId'],
      postStoryEmotionName: json['postStoryEmotionName'],
      postStoryIntensity: json['postStoryIntensity'],
    );
  }

  // ADD copyWith method if it doesn't exist:
  SavedStory copyWith({
    bool? isFavorite,
    String? postStoryEmotionId,
    String? postStoryEmotionName,
    int? postStoryIntensity,
  }) {
    return SavedStory(
      id: id,
      title: title,
      storyText: storyText,
      theme: theme,
      characters: characters,
      createdAt: createdAt,
      isInteractive: isInteractive,
      wisdomGem: wisdomGem,
      isFavorite: isFavorite ?? this.isFavorite,
      preStoryEmotionId: preStoryEmotionId,
      preStoryEmotionName: preStoryEmotionName,
      preStoryIntensity: preStoryIntensity,
      postStoryEmotionId: postStoryEmotionId ?? this.postStoryEmotionId,
      postStoryEmotionName: postStoryEmotionName ?? this.postStoryEmotionName,
      postStoryIntensity: postStoryIntensity ?? this.postStoryIntensity,
    );
  }
}
```

---

### Step 3: Update main_story.dart to Pass Pre-Story Feeling

**File:** `lib/main_story.dart`

**Task:** Pass the pre-story feeling to the story result screen

Find where `StoryResultScreen` is created (around line 330) and update it:

```dart
// Find this code:
await Navigator.of(navContext).push(
  MaterialPageRoute(
    builder: (_) => StoryResultScreen(
      title: title,
      storyText: storyText,
      wisdomGem: wisdomGem,
      characterName: _selectedCharacter?.name,
      storyId: saved.id,
      theme: _selectedTheme,
      characterId: _selectedCharacter?.id,
    ),
  ),
);

// ADD currentFeeling parameter:
await Navigator.of(navContext).push(
  MaterialPageRoute(
    builder: (_) => StoryResultScreen(
      title: title,
      storyText: storyText,
      wisdomGem: wisdomGem,
      characterName: _selectedCharacter?.name,
      storyId: saved.id,
      theme: _selectedTheme,
      characterId: _selectedCharacter?.id,
      preStoryFeeling: currentFeeling, // ADD THIS LINE
    ),
  ),
);
```

---

### Step 4: Update StoryResultScreen

**File:** `lib/story_result_screen.dart`

**Task:** Show post-story check after story is displayed

**Changes needed:**

1. Add import at top:
```dart
import 'post_story_feelings_dialog.dart';
import 'pre_story_feelings_dialog.dart'; // For CurrentFeeling type
import 'storage_service.dart';
```

2. Add parameter to constructor:
```dart
class StoryResultScreen extends StatefulWidget {
  final String title;
  final String storyText;
  final String? wisdomGem;
  final String? characterName;
  final String? storyId;
  final String? theme;
  final String? characterId;
  final CurrentFeeling? preStoryFeeling; // ADD THIS

  const StoryResultScreen({
    super.key,
    required this.title,
    required this.storyText,
    this.wisdomGem,
    this.characterName,
    this.storyId,
    this.theme,
    this.characterId,
    this.preStoryFeeling, // ADD THIS
  });

  // ... rest of class
}
```

3. Add state variable:
```dart
class _StoryResultScreenState extends State<StoryResultScreen> {
  bool _isReading = false;
  bool _postCheckShown = false; // ADD THIS

  // ... existing code
}
```

4. Add method to show post-story check:
```dart
Future<void> _showPostStoryCheck() async {
  if (_postCheckShown) return; // Only show once

  final postFeeling = await PostStoryFeelingsDialog.show(
    context: context,
    characterName: widget.characterName ?? 'Character',
    preStoryFeeling: widget.preStoryFeeling,
  );

  if (postFeeling != null && widget.storyId != null) {
    // Save the post-story emotion
    final storageService = StorageService();
    final stories = await storageService.getStories();
    final storyIndex = stories.indexWhere((s) => s.id == widget.storyId);

    if (storyIndex != -1) {
      final updatedStory = stories[storyIndex].copyWith(
        postStoryEmotionId: postFeeling.emotion.id,
        postStoryEmotionName: postFeeling.emotion.name,
        postStoryIntensity: postFeeling.intensity,
      );

      stories[storyIndex] = updatedStory;
      await storageService.saveStories(stories);

      // Show success message if emotion improved
      if (widget.preStoryFeeling != null &&
          postFeeling.intensity < widget.preStoryFeeling!.intensity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✨ Feeling better! ${widget.preStoryFeeling!.emotion.name} went from ${widget.preStoryFeeling!.intensity} → ${postFeeling.intensity}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  setState(() => _postCheckShown = true);
}
```

5. Call the method after story is shown:
```dart
// Find where the story is displayed (in the build method)
// After the story text widget, add a button or auto-show

// OPTION A: Auto-show after 3 seconds (recommended)
@override
void initState() {
  super.initState();

  // Show post-check after user has had time to read
  Future.delayed(const Duration(seconds: 5), () {
    if (mounted && !_postCheckShown) {
      _showPostStoryCheck();
    }
  });
}

// OPTION B: Button-triggered (if you prefer manual)
// Add this button to the UI:
if (!_postCheckShown && widget.preStoryFeeling != null)
  ElevatedButton(
    onPressed: _showPostStoryCheck,
    child: const Text('How do you feel now?'),
  ),
```

---

### Step 5: Update SavedStory Creation in main_story.dart

**File:** `lib/main_story.dart`

**Task:** Save pre-story emotion when creating the story

Find where `SavedStory` is created (around line 312):

```dart
// Find this code:
final saved = SavedStory(
  title: title,
  storyText: storyText,
  theme: _selectedTheme,
  characters: allSelectedCharacters,
  createdAt: DateTime.now(),
  isInteractive: false,
  wisdomGem: wisdomGem,
);

// ADD pre-story emotion fields:
final saved = SavedStory(
  title: title,
  storyText: storyText,
  theme: _selectedTheme,
  characters: allSelectedCharacters,
  createdAt: DateTime.now(),
  isInteractive: false,
  wisdomGem: wisdomGem,
  preStoryEmotionId: currentFeeling?.emotion.id,
  preStoryEmotionName: currentFeeling?.emotion.name,
  preStoryIntensity: currentFeeling?.intensity,
);
```

---

## 📋 Acceptance Criteria

### Must Have:
- [ ] Post-story feelings dialog works (can select emotion + intensity)
- [ ] Dialog shows pre-story feeling if available
- [ ] Both pre and post emotions saved to SavedStory
- [ ] Post-story check appears automatically after story
- [ ] Shows success message if emotion improved
- [ ] Can skip the post-check
- [ ] No crashes or errors
- [ ] Data persists across app restarts

### Nice to Have:
- [ ] Smooth dialog animations
- [ ] Visual comparison (before/after bars)
- [ ] Celebration animation if feeling improved

### Do NOT Add:
- ❌ Email notifications
- ❌ Complex analytics
- ❌ Social sharing

---

## 🧪 Testing Checklist

Before committing, test:
- [ ] Works when pre-story feeling exists
- [ ] Works when pre-story feeling is null (skipped)
- [ ] Works when user skips post-story check
- [ ] Emotion intensity can improve, worsen, or stay same
- [ ] Data saves correctly to SharedPreferences
- [ ] Data loads correctly after app restart
- [ ] Success message shows when appropriate
- [ ] No console errors or warnings
- [ ] Dialog is dismissible (can press back/outside)

---

## 🚀 When You're Done

**Commit your changes:**
```bash
git add .
git commit -m "Add post-story emotional check and comparison

- Create PostStoryFeelingsDialog (adapted from pre-story)
- Update SavedStory model with pre/post emotion fields
- Pass pre-story feeling to StoryResultScreen
- Auto-show post-check 5 seconds after story
- Display emotion improvement message
- Store emotion delta for analytics

Ref: 3_WEEK_MVP_PLAN.md Week 1 - Codex Task B"
```

**Then push to your branch:**
```bash
git push origin codex-post-story-check
```

**Let user know you're done** - they'll review and merge to main

---

## 🎯 Success Looks Like

At the end of this task, users should experience:

1. Select "Worried, intensity 4" before story
2. Read story about handling worry
3. After 5 seconds, dialog appears: "How do you feel now?"
4. Select "Worried, intensity 2"
5. See message: "✨ Feeling better! Worried went from 4 → 2"
6. Emotion data is saved with the story

**That's the emotional processing loop!** 🔄

---

**Estimated Time:** 1-2 days
**Priority:** P0 (blocking Week 2)
**Owner:** Codex Instance B
**Reviewer:** User
**Parallel With:** Insights Dashboard (Codex Instance A)
