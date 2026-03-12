# Run: Bedtime Audio Wizard Mode

## Goal
Build a dedicated "Bedtime Mode" — a screen-free, voice-driven story creation experience. The screen shows only a gentle pulsing animation. The app asks questions aloud, the child answers by speaking, and the story is generated and read aloud automatically.

## Background

### Existing Infrastructure to Reuse
- **`AppTtsService`** (`lib/services/app_tts_service.dart`): `speak(text, {awaitCompletion: true})` — speaks text and waits until audio finishes. This is the core output channel.
- **`SpeechToText`** (package `speech_to_text`): already used in `welcome_screen.dart`, `hero_creator_step.dart`, and `VoiceMicButton`. Handles mic permissions, listening, and transcription.
- **`VoiceMicButton`** (`lib/widgets/voice_mic_button.dart`): reusable STT widget — may be useful as reference but the bedtime mode will manage its own listen/speak loop.
- **`WizardData`** (`lib/models/wizard_data.dart`): the data model that all wizard steps populate. The bedtime wizard must produce a fully populated `WizardData` by the end.
- **`WizardDataMapper`** (`lib/screens/wizard_steps/wizard_data_mapper.dart`): maps `WizardData` → API request payload. Reuse as-is.
- **`MagicReviewStep._generateStory()`** logic: the actual story generation API call. Extract or call the same code path.
- **`StoryResultScreen`**: the story display screen — for bedtime mode, skip the visual display and just read the story aloud.
- **`AudioAmbienceService`** (`lib/services/audio_ambience_service.dart`): ambient background sounds — perfect for a gentle bedtime atmosphere.
- **Scenario data**: `lib/data/scenario_data.dart` — `ScenarioData.all` gives the list of available scenarios with titles.
- **Companion data**: `lib/data/companion_data.dart` or the hardcoded list in `companion_selector_step.dart` (lines 77-141).
- **Archetype data**: search `hero_creator_step.dart` for the archetype/role list.

### Key Architectural Decisions
1. **New screen, not a modification** of the existing wizard. The bedtime wizard is a completely separate flow.
2. **State machine pattern**: each "question" is a state. The loop is: speak question → listen → parse answer → advance state → repeat.
3. **Fuzzy matching**: child speech is imprecise. Use contains/similarity matching, not exact matching. E.g., if child says "dragon", match to companion "a tiny dragon".
4. **Graceful fallback**: if STT fails or is unavailable, show tap-to-select buttons as fallback (but keep them dim/minimal).
5. **Minimal screen**: just a pulsing orb/star + the current question as faint text. Screen brightness should auto-dim.

---

## Implementation

### Step 1: Create the Bedtime Audio Wizard Screen

**New file: `lib/screens/bedtime_wizard_screen.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/app_tts_service.dart';
import '../services/audio_ambience_service.dart';
import '../models.dart';
import '../data/scenario_data.dart';
import 'wizard_steps/wizard_data_mapper.dart';

/// Voice-driven bedtime story wizard.
/// Minimal screen — just a pulsing star and voice interaction.
class BedtimeWizardScreen extends StatefulWidget {
  /// Pre-filled with the child's name and age from the welcome screen.
  final String childName;
  final int childAge;

  const BedtimeWizardScreen({
    super.key,
    required this.childName,
    required this.childAge,
  });

  @override
  State<BedtimeWizardScreen> createState() => _BedtimeWizardScreenState();
}

enum BedtimeStep {
  greeting,       // "Hi [name]! Let's make a bedtime story!"
  heroName,       // "What's your hero's name?" (may reuse child's name)
  companion,      // "Who's coming with you? A dragon, an owl, a cat...?"
  setting,        // "Where will your adventure happen?"
  feeling,        // "What kind of story? A brave one, a funny one...?"
  confirm,        // "OK! [name] and [companion] in [setting]. Ready?"
  generating,     // "Making your story now... close your eyes..."
  reading,        // Reading the story aloud
  done,           // "The end. Goodnight [name]!"
}

class _BedtimeWizardScreenState extends State<BedtimeWizardScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  BedtimeStep _step = BedtimeStep.greeting;
  final WizardData _wizardData = WizardData();

  // Collected answers
  String? _heroName;
  String? _companionChoice;
  String? _settingChoice;
  String? _feelingChoice;

  // UI state
  String _statusText = '';
  bool _isListening = false;
  bool _isSpeaking = false;

  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Dim screen, lock orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initAndStart();
  }

  Future<void> _initAndStart() async {
    _speechAvailable = await _speech.initialize();
    // Start ambient bedtime sounds
    // AudioAmbienceService.instance.play('bedtime'); // if available
    await _runStep();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _speech.stop();
    AppTtsService.instance.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── Main Loop ──────────────────────────────────────────

  Future<void> _runStep() async {
    switch (_step) {
      case BedtimeStep.greeting:
        await _speakAndAdvance(
          "Hi ${widget.childName}! Let's make a magical bedtime story together. Just talk to me!",
          BedtimeStep.heroName,
        );
        break;

      case BedtimeStep.heroName:
        final answer = await _askQuestion(
          "What's your hero's name? Or should I use ${widget.childName}?",
        );
        _heroName = answer.isNotEmpty ? answer : widget.childName;
        _advance(BedtimeStep.companion);
        break;

      case BedtimeStep.companion:
        final answer = await _askQuestion(
          "Who's coming with $_heroName? A tiny dragon, a wise owl, a shadow cat, a star dog, or someone else?",
        );
        _companionChoice = _fuzzyMatchCompanion(answer);
        _advance(BedtimeStep.setting);
        break;

      case BedtimeStep.setting:
        final answer = await _askQuestion(
          "Where will the adventure happen? A rainbow land, a crystal cave, a land of dragons, or somewhere you imagine?",
        );
        _settingChoice = _fuzzyMatchScenario(answer);
        _advance(BedtimeStep.feeling);
        break;

      case BedtimeStep.feeling:
        final answer = await _askQuestion(
          "What kind of story? A brave adventure, a funny story, a story about friendship, or a calming story?",
        );
        _feelingChoice = _matchStoryMood(answer);
        _advance(BedtimeStep.confirm);
        break;

      case BedtimeStep.confirm:
        final summary = "$_heroName and $_companionChoice in $_settingChoice. A $_feelingChoice story.";
        final answer = await _askQuestion(
          "Here's your story recipe: $summary. Shall I make it? Say yes, or tell me what to change.",
        );
        if (_isAffirmative(answer)) {
          _advance(BedtimeStep.generating);
        } else {
          // Go back to beginning of choices
          _advance(BedtimeStep.companion);
        }
        break;

      case BedtimeStep.generating:
        await _speak("Making your story now. Close your eyes and imagine...");
        await _generateAndReadStory();
        break;

      case BedtimeStep.reading:
        // Story reading is handled in _generateAndReadStory
        break;

      case BedtimeStep.done:
        await _speak("The end. Goodnight, ${widget.childName}. Sweet dreams.");
        // Wait a moment, then pop
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.of(context).pop();
        break;
    }
  }

  void _advance(BedtimeStep next) {
    if (!mounted) return;
    setState(() => _step = next);
    _runStep();
  }

  Future<void> _speakAndAdvance(String text, BedtimeStep next) async {
    await _speak(text);
    _advance(next);
  }

  // ─── Voice I/O ──────────────────────────────────────────

  Future<void> _speak(String text) async {
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _statusText = text;
    });
    await AppTtsService.instance.speak(text, awaitCompletion: true);
    if (mounted) setState(() => _isSpeaking = false);
  }

  /// Speaks a question, then listens for an answer. Returns transcribed text.
  /// Falls back to showing tap buttons if STT unavailable.
  Future<String> _askQuestion(String question) async {
    await _speak(question);

    if (!_speechAvailable) {
      // STT unavailable — show fallback UI (handled in build)
      // For now return empty and let the step use defaults
      return '';
    }

    return await _listen();
  }

  Future<String> _listen() async {
    if (!mounted) return '';
    final completer = Completer<String>();
    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _statusText = '"${result.recognizedWords}"');
        if (result.finalResult) {
          completer.complete(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );

    // Timeout fallback
    final answer = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );

    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    return answer;
  }

  // ─── Fuzzy Matching ─────────────────────────────────────

  String _fuzzyMatchCompanion(String input) {
    final lower = input.toLowerCase();
    final companions = {
      'dragon': 'a tiny dragon',
      'owl': 'a wise owl',
      'cat': 'a shadow cat',
      'dog': 'a star dog',
      'unicorn': 'a magic unicorn',
      'fox': 'a clever fox',
      'robin': 'a rockin\' robin',
    };
    for (final entry in companions.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    // If no match, use what they said as a custom companion
    return input.isNotEmpty ? input : 'a tiny dragon';
  }

  String _fuzzyMatchScenario(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('rainbow')) return 'rainbow_land';
    if (lower.contains('crystal') || lower.contains('cave')) return 'crystal_cavern';
    if (lower.contains('dragon')) return 'volcano_dragons';
    if (lower.contains('friend')) return 'brave_friend';
    if (lower.contains('feel')) return 'big_feelings_quest';
    // Use as custom setting
    return 'safe_space'; // custom — store input in wizardData.customElements
  }

  String _matchStoryMood(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('brave') || lower.contains('adventure')) return 'brave';
    if (lower.contains('funny') || lower.contains('silly')) return 'funny';
    if (lower.contains('friend')) return 'friendship';
    if (lower.contains('calm') || lower.contains('relax') || lower.contains('sleep')) return 'calming';
    return 'brave'; // default
  }

  bool _isAffirmative(String input) {
    final lower = input.toLowerCase();
    return lower.contains('yes') || lower.contains('yeah') ||
           lower.contains('ok') || lower.contains('sure') ||
           lower.contains('ready') || lower.isEmpty; // silence = yes
  }

  // ─── Story Generation ───────────────────────────────────

  Future<void> _generateAndReadStory() async {
    // Populate WizardData from collected answers
    _wizardData.characterName = _heroName ?? widget.childName;
    _wizardData.characterAge = widget.childAge;
    _wizardData.selectedCompanions = [_companionChoice ?? 'dragon'];
    _wizardData.companionNames = [_companionChoice ?? 'a tiny dragon'];
    _wizardData.selectedScenario = _settingChoice;
    if (_settingChoice == 'safe_space') {
      _wizardData.customElements = _settingChoice ?? '';
    }
    // Map feeling choice to a scenario or lifeChallenge if appropriate

    // Use WizardDataMapper to build the API payload
    // Then call the story generation API (same as magic_review_step.dart)
    // This is the key integration point — extract the API call from
    // MagicReviewStep._generateStory() into a shared service, or
    // duplicate the HTTP call here.

    try {
      // TODO: Call story generation API using WizardDataMapper
      // final payload = WizardDataMapper.toApiPayload(_wizardData);
      // final response = await ApiServiceManager.instance.generateStory(payload);
      // final storyText = response['story'];

      // For now, placeholder:
      final storyText = "Once upon a time..."; // Replace with real API call

      setState(() => _step = BedtimeStep.reading);

      // Read the story aloud, paragraph by paragraph
      final paragraphs = storyText.split('\n\n');
      for (final paragraph in paragraphs) {
        if (paragraph.trim().isEmpty) continue;
        if (!mounted) return;
        setState(() => _statusText = ''); // Keep screen minimal
        await AppTtsService.instance.speak(paragraph.trim(), awaitCompletion: true);
        // Brief pause between paragraphs
        await Future.delayed(const Duration(milliseconds: 800));
      }

      _advance(BedtimeStep.done);
    } catch (e) {
      await _speak("Oh no, something went wrong making the story. Let's try again tomorrow. Goodnight!");
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2E), // Deep night sky
      body: SafeArea(
        child: GestureDetector(
          // Tap anywhere to exit if done, or repeat question if stuck
          onTap: () {
            if (_step == BedtimeStep.done) {
              Navigator.of(context).pop();
            }
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing orb
                AnimatedBuilder(
                  animation: _orbController,
                  builder: (context, child) {
                    final scale = 1.0 + (_orbController.value * 0.3);
                    final opacity = 0.4 + (_orbController.value * 0.6);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _isListening
                                  ? Colors.purple.withOpacity(opacity)
                                  : _isSpeaking
                                      ? Colors.amber.withOpacity(opacity)
                                      : Colors.indigo.withOpacity(opacity * 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic
                              : _isSpeaking
                                  ? Icons.auto_stories
                                  : Icons.star,
                          color: Colors.white.withOpacity(0.8),
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Subtle status text (very dim — screen should be ignorable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 60),

                // Exit button (very subtle)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Exit Bedtime Mode',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### Step 2: Add Entry Point

The bedtime mode needs a button on the home/main screen. The app appears to use `WelcomeScreen` for onboarding and then navigates to a main screen.

**Find the main navigation screen** (likely `lib/main.dart` or wherever the wizard is launched from) and add a "Bedtime Mode" button:

```dart
// Moon icon button — place alongside the "Start Adventure" button
IconButton(
  icon: const Icon(Icons.bedtime_outlined, color: Color(0xFFB8A9FF), size: 32),
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BedtimeWizardScreen(
          childName: userName, // from SharedPreferences or state
          childAge: userAge,
        ),
      ),
    );
  },
  tooltip: 'Bedtime Story Mode',
)
```

Also add `Semantics(button: true, label: "Start bedtime story mode. Voice only, no screen needed.")` around it.

### Step 3: Extract Story Generation into Shared Service

Currently, story generation logic lives inside `magic_review_step.dart`. To reuse it:

**New file: `lib/services/story_generation_service.dart`**

```dart
/// Shared story generation that both the visual wizard and bedtime mode can use.
class StoryGenerationService {
  /// Generate a story from populated WizardData.
  /// Returns the story text (and optionally title, wisdom gem, etc).
  static Future<Map<String, dynamic>> generate(WizardData wizardData) async {
    final payload = WizardDataMapper.toApiPayload(wizardData);
    // Move the HTTP call from magic_review_step.dart here
    // Return {'title': ..., 'story': ..., 'wisdom_gem': ...}
  }
}
```

Then refactor `magic_review_step.dart` to call `StoryGenerationService.generate()` instead of having inline HTTP logic.

### Step 4: Auto-Read Story in Bedtime Mode

In `_generateAndReadStory()`, after getting the story text:

1. Split into paragraphs
2. Read each paragraph with `AppTtsService.instance.speak(paragraph, awaitCompletion: true)`
3. Add 800ms pause between paragraphs
4. When done, advance to `BedtimeStep.done`
5. Say "The end. Goodnight, [name]. Sweet dreams."
6. Wait 3 seconds, then pop the screen

### Step 5: Handle Edge Cases

1. **STT unavailable**: Show minimal tap buttons as fallback
   - Display choice buttons (dim, large touch targets) at bottom of screen
   - Still speak the question aloud
   - Child taps instead of speaks

2. **No internet**: Show a friendly error and suggest trying again
   - "I can't reach the story maker right now. Let's try again tomorrow!"

3. **Child says something unexpected**: Use the fuzzy matchers. If no match, use their exact words as custom input (the backend handles freeform text in `customElements`).

4. **Child goes silent**: After the 10-second listen timeout, gently re-ask:
   - "I didn't hear anything. Want to try again?" Then re-listen.

5. **Parent wants to exit**: The subtle "Exit Bedtime Mode" button, or swipe down / back gesture.

6. **Screen auto-dims**: Set screen brightness low:
   ```dart
   // In initState, after a brief delay:
   SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
   // Consider using screen_brightness package to dim to minimum
   ```

---

## File Summary

| Action | File |
|--------|------|
| **Create** | `lib/screens/bedtime_wizard_screen.dart` — the main bedtime mode screen |
| **Create** | `lib/services/story_generation_service.dart` — extracted story gen logic |
| **Modify** | `lib/screens/wizard_steps/magic_review_step.dart` — refactor to use `StoryGenerationService` |
| **Modify** | Main navigation screen — add "Bedtime Mode" entry button |
| **Modify** | `lib/services/app_tts_service.dart` — add bedtime phrases to `kWarmUpPhrases` |

## Dependencies
- No new packages needed. Uses existing `speech_to_text`, `audioplayers`, and `flutter_tts`.
- Optional: `screen_brightness` package for auto-dimming.

## Testing Checklist
- [ ] Can launch bedtime mode from main screen
- [ ] Screen shows pulsing orb, minimal text
- [ ] App speaks greeting with child's name
- [ ] App asks each question and waits for voice answer
- [ ] Fuzzy matching correctly maps "dragon" → companion, "rainbow" → scenario
- [ ] Custom/unexpected answers are accepted gracefully
- [ ] Confirmation step summarizes choices correctly
- [ ] Story generates and reads aloud paragraph by paragraph
- [ ] "Goodnight" message plays at the end
- [ ] Screen pops after story completes
- [ ] STT fallback buttons appear when mic is unavailable
- [ ] Exit button works at any point
- [ ] No crashes if child stays silent (timeout handling)
- [ ] Works with ElevenLabs voice (primary) and on-device TTS (fallback)
