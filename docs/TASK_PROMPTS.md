# Sub-Agent Task Prompts
> Paste these into Codex (GPT-4.5) or Gemini 2 Pro.
> When done, report back to Claude with "Task BW-X complete" and paste any errors.
> Claude will review, commit, and assign the next task.

---

## Task BW-1 — Update bedtime_wizard_screen.dart (listeners step + wire bedtimeMode)

**File to edit:** `lib/screens/bedtime_wizard_screen.dart`

**Context:** This is a Flutter/Dart voice-driven bedtime wizard. It currently collects heroName, companion, setting, and feeling. We need to add a "listeners" step so siblings and friends can be included in the story, and wire the new `bedtimeMode: true` parameter into the story generation call.

**Do the following changes in order. Do NOT rewrite the whole file — make surgical edits only.**

### Change 1 — Add `listeners` to the enum

Find this block:
```dart
enum BedtimeStep {
  greeting, // "Hi [name]! Let's make a bedtime story!"
  heroName, // "What's your hero's name?" (may reuse child's name)
  companion, // "Who's coming with you?"
  setting, // "Where will your adventure happen?"
  feeling, // "What kind of story?"
  confirm, // "OK! [name] and [companion] in [setting]. Ready?"
  generating, // "Making your story now... close your eyes..."
  reading, // Reading the story aloud
  done, // "The end. Goodnight!"
}
```

Replace with:
```dart
enum BedtimeStep {
  greeting,   // "Hi [name]! Let's make a bedtime story!"
  heroName,   // "What's your hero's name?"
  companion,  // "Who's coming with you?"
  listeners,  // "Are any brothers, sisters, or friends listening too?"
  setting,    // "Where will your adventure happen?"
  feeling,    // "What kind of story?"
  confirm,    // "OK! Ready?"
  generating, // "Making your story now... close your eyes..."
  reading,    // Reading the story aloud
  done,       // "The end. Goodnight!"
}
```

### Change 2 — Add `_listenerNames` field

Find this block near the top of `_BedtimeWizardScreenState`:
```dart
  // Collected answers
  String? _heroName;
  String? _companionChoice;
  String? _settingChoice;
  String? _feelingChoice;
```

Replace with:
```dart
  // Collected answers
  String? _heroName;
  String? _companionChoice;
  List<String> _listenerNames = [];
  String? _settingChoice;
  String? _feelingChoice;
```

### Change 3 — Add the listeners case in `_runStep()`

Find this case in the `switch` inside `_runStep()`:
```dart
      case BedtimeStep.companion:
        final answer = await _askQuestion(
          "Who's coming with $_heroName? A tiny dragon, a wise owl, a shadow cat, a star dog, or someone else?",
        );
        _companionChoice = _fuzzyMatchCompanion(answer);
        _advance(BedtimeStep.setting);
        break;
```

Replace with:
```dart
      case BedtimeStep.companion:
        final answer = await _askQuestion(
          "Who's coming with $_heroName? A tiny dragon, a wise owl, a shadow cat, a star dog, or someone else?",
        );
        _companionChoice = _fuzzyMatchCompanion(answer);
        _advance(BedtimeStep.listeners);
        break;

      case BedtimeStep.listeners:
        final listenersAnswer = await _askQuestion(
          "Are any brothers, sisters, or friends listening with you tonight? Say their names, or say 'just me'.",
        );
        _listenerNames = _parseListenerNames(listenersAnswer);
        _advance(BedtimeStep.setting);
        break;
```

### Change 4 — Update the confirm summary to mention listeners

Find this case:
```dart
      case BedtimeStep.confirm:
        final summary =
            "$_heroName and $_companionChoice in $_settingChoice. A $_feelingChoice story.";
        final answer = await _askQuestion(
          "Here's your story recipe: $summary. Shall I make it? Say yes, or tell me what to change.",
        );
        if (_isAffirmative(answer)) {
          _advance(BedtimeStep.generating);
        } else {
          _advance(BedtimeStep.companion);
        }
        break;
```

Replace with:
```dart
      case BedtimeStep.confirm:
        final listenersText = _listenerNames.isEmpty
            ? ''
            : ', with ${_listenerNames.join(' and ')}';
        final summary =
            "$_heroName$listenersText and $_companionChoice in $_settingChoice. A $_feelingChoice story.";
        final answer = await _askQuestion(
          "Here's your story: $summary. Shall I make it? Say yes, or tell me what to change.",
        );
        if (_isAffirmative(answer)) {
          _advance(BedtimeStep.generating);
        } else {
          _advance(BedtimeStep.companion);
        }
        break;
```

### Change 5 — Add the `_parseListenerNames` helper method

Add this method to `_BedtimeWizardScreenState`, after the `_isAffirmative` method:

```dart
  List<String> _parseListenerNames(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty ||
        lower.contains('just me') ||
        lower.contains('nobody') ||
        lower.contains('no one') ||
        lower.contains('only me')) {
      return [];
    }
    // Split on "and", commas, "with"
    final parts = input
        .replaceAll(' and ', ',')
        .replaceAll(' with ', ',')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .toList();
    return parts.take(5).toList(); // cap at 5 listeners
  }
```

### Change 6 — Wire `bedtimeMode`, `bedtimeMood`, and `additionalCharacters` into `_generateAndReadStory`

Find this block in `_generateAndReadStory`:
```dart
    _wizardData.characterName = _heroName ?? widget.childName;
    _wizardData.characterAge = widget.childAge;
    _wizardData.companionNames = [_companionChoice ?? 'a tiny dragon'];
    _wizardData.customElements = '$_feelingChoice story about $_settingChoice';
    _wizardData.storyLength = 'standard';
```

Replace with:
```dart
    _wizardData.characterName = _heroName ?? widget.childName;
    _wizardData.characterAge = widget.childAge;
    _wizardData.companionNames = [_companionChoice ?? 'a tiny dragon'];
    _wizardData.customElements = '$_feelingChoice story about $_settingChoice';
    _wizardData.storyLength = 'standard';
    final additionalChars = _listenerNames
        .map((n) => <String, dynamic>{'name': n})
        .toList();
```

### Change 7 — Pass new params to `generateStory` in `_runRegularStory`

Find the `generateStory` call in `_runRegularStory`:
```dart
    final result = await ApiServiceManager.generateStory(
        characterName: requestData['character'] ?? 'Hero',
        age: requestData['age'] ?? 5,
        theme: _settingChoice ?? 'Magical Adventure',
        companion: requestData['companion'] ?? '',
        characterDetails: requestData['characterDetails'],
        currentFeeling: null,
        additionalCharacters: null,
        includeIllustrations: false,
        rhymeTimeMode: false,
        learningToReadMode: false,
        companionPets: requestData['companion_pets'],
        companionCharacters: requestData['companion_characters'],
        storyLength: requestData['storyLength'] ?? 'standard',
        customElements: requestData['customElements'] ?? '',
        subscriptionTier: 'free',
        onProgress: (status) {
          if (mounted) setState(() => _statusText = status);
        });
```

Replace with:
```dart
    final result = await ApiServiceManager.generateStory(
        characterName: requestData['character'] ?? 'Hero',
        age: requestData['age'] ?? 5,
        theme: _settingChoice ?? 'Magical Adventure',
        companion: requestData['companion'] ?? '',
        characterDetails: requestData['characterDetails'],
        currentFeeling: null,
        additionalCharacters: additionalChars.isEmpty
            ? null
            : additionalChars.map((m) => m['name'] as String).toList(),
        includeIllustrations: false,
        rhymeTimeMode: false,
        learningToReadMode: false,
        companionPets: requestData['companion_pets'],
        companionCharacters: requestData['companion_characters'],
        storyLength: requestData['storyLength'] ?? 'standard',
        customElements: requestData['customElements'] ?? '',
        subscriptionTier: 'free',
        bedtimeMode: true,
        bedtimeMood: _feelingChoice ?? 'calming',
        onProgress: (status) {
          if (mounted) setState(() => _statusText = status);
        });
```

**Note:** `additionalChars` is the variable you defined in Change 6 inside `_generateAndReadStory`. Make sure `_runRegularStory` takes it as a parameter. Update the call site in `_generateAndReadStory` to pass `additionalChars` to `_runRegularStory`:

Find:
```dart
      await _runRegularStory(requestData);
```

Replace with:
```dart
      await _runRegularStory(requestData, additionalChars);
```

And update the method signature:
```dart
  Future<void> _runRegularStory(Map<String, dynamic> requestData) async {
```
to:
```dart
  Future<void> _runRegularStory(
    Map<String, dynamic> requestData,
    List<Map<String, dynamic>> additionalChars,
  ) async {
```

**Verification:** Run `flutter analyze lib/screens/bedtime_wizard_screen.dart`. Should report 0 errors.

---

## Task BW-2 — BYOK key gate at bedtime wizard entry

**File to edit:** `lib/screens/bedtime_wizard_screen.dart`

**Context:** Bedtime/audio-only mode is a BYOK (Bring Your Own Key) feature — it uses the child's parent-supplied Gemini API key. If no key is configured, the wizard should show a helpful message before starting rather than failing silently mid-story.

**Prerequisite:** BW-1 must be complete first.

**Do the following:**

### Change 1 — Add the key check in `_initAndStart`

Find:
```dart
  Future<void> _initAndStart() async {
    _speechAvailable = await _speech.initialize();
    await _runStep();
  }
```

Replace with:
```dart
  Future<void> _initAndStart() async {
    _speechAvailable = await _speech.initialize();
    final hasKey = await ApiServiceManager.isUsingOwnApiKey();
    if (!hasKey && mounted) {
      await _speak(
        "To use bedtime stories, a parent needs to add a Gemini API key in Settings first. Goodnight!",
      );
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _runStep();
  }
```

**Verification:** Run `flutter analyze lib/screens/bedtime_wizard_screen.dart`. Should report 0 errors.

---

## Task BW-3 — Story duration picker (10 / 15 / 20 minutes)

**Context:** Parents want to set a read-aloud runtime target. Average narrated audiobook pace is ~130 words/minute for children's content. So:
- 10 min = ~1300 words
- 15 min = ~1950 words
- 20 min = ~2600 words

This affects both the word-count in the prompt and optionally the TTS session timer.

### Part A — Backend: `story_service.py`

**File:** `backend/services/story_service.py`

Add a duration-to-word-count helper at the top of the file (after the imports, before `AGE_CONSTRAINTS`):

```python
# Approximate words per minute for narrated children's audio.
_NARRATION_WPM = 130

def _duration_minutes_to_word_range(minutes: int) -> tuple[int, int]:
    """Convert a desired runtime in minutes to a target word-count range."""
    target = minutes * _NARRATION_WPM
    return (int(target * 0.85), int(target * 1.15))
```

Then in `_build_bedtime_prompt`, after the `length_key` / `word_range` block, add duration override support:

Find:
```python
    word_range = _BEDTIME_WORD_RANGES.get(band, _BEDTIME_WORD_RANGES['5-7'])[length_key]
```

Replace with:
```python
    if duration_minutes and duration_minutes > 0:
        word_range = _duration_minutes_to_word_range(duration_minutes)
    else:
        word_range = _BEDTIME_WORD_RANGES.get(band, _BEDTIME_WORD_RANGES['5-7'])[length_key]
```

Also add `duration_minutes: int | None = None` to the `_build_bedtime_prompt` function signature.

### Part B — Backend: `story_tasks.py`

**File:** `backend/tasks/story_tasks.py`

In the `bedtime_mode` branch, pass `duration_minutes`:
```python
                prompt = _build_bedtime_prompt(
                    character_name=character_name,
                    age=age,
                    theme=theme,
                    mood=kwargs.get("bedtime_mood", "calming"),
                    all_listeners=extra_chars,
                    companion=companion,
                    companion_pets=companion_pets,
                    companion_characters=companion_character_details,
                    story_length=story_length,
                    duration_minutes=kwargs.get("bedtime_duration_minutes"),
                )
```

### Part C — Backend: `story_routes.py`

Add to `task_kwargs`:
```python
"bedtime_duration_minutes": payload.get("bedtime_duration_minutes"),
```

### Part D — Frontend: `api_service_manager.dart`

Add `int? bedtimeDurationMinutes` parameter to `generateStory()`, `_generateStoryWithBackendRetry()`, and `_generateStoryWithBackend()`.

In `_generateStoryWithBackend()`, add to the body map:
```dart
'bedtime_duration_minutes': bedtimeDurationMinutes,
```

In `_buildBedtimePrompt()`, add `int? durationMinutes` parameter and override the word count:
```dart
final (int minWords, int maxWords) = durationMinutes != null && durationMinutes > 0
    ? ((durationMinutes * 110), (durationMinutes * 150))  // ~130wpm ±15%
    : switch (age) {
        <= 4  => storyLength == 'short' ? (180, 260)  : (260, 380),
        ...existing cases...
      };
```

### Part E — Frontend: `bedtime_wizard_screen.dart`

Add a duration picker step to the wizard. Add `BedtimeStep.duration` between `feeling` and `confirm`.

Add field:
```dart
int _storyDurationMinutes = 15; // default
```

Add case in `_runStep()`:
```dart
      case BedtimeStep.duration:
        final answer = await _askQuestion(
          "How long should the story be? Say ten minutes, fifteen minutes, or twenty minutes.",
        );
        _storyDurationMinutes = _parseDurationMinutes(answer);
        _advance(BedtimeStep.confirm);
        break;
```

Add helper:
```dart
  int _parseDurationMinutes(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('twenty') || lower.contains('20')) return 20;
    if (lower.contains('ten') || lower.contains('10')) return 10;
    return 15; // default
  }
```

Pass `bedtimeDurationMinutes: _storyDurationMinutes` to the `generateStory()` call.

**Verification:** Run `flutter analyze` on all changed files. All should pass. Then run `python -c "import ast; ast.parse(open('backend/services/story_service.py', encoding='utf-8').read()); print('OK')"`.

---

## Reporting Back to Claude

When a task is done, come back to Claude and say:

> "Task BW-X complete. Here is the flutter analyze output: [paste output]"

Claude will review, commit, and give you the next task prompt.
