# Accessibility & Bedtime Mode Bugfix Plan

This plan fixes all issues identified in the code review of the Crawl/Walk/Run accessibility phases. Each task is self-contained with exact file paths, line numbers, and copy-pasteable code. Complete them in order.

---

## Task 1: Add Android RECORD_AUDIO Permission (CRITICAL)

**File:** `android/app/src/main/AndroidManifest.xml`

**Problem:** Speech recognition in Bedtime Mode silently fails on Android because the `RECORD_AUDIO` permission is missing.

**What to do:** Add the permission on line 5, right after the existing `ACCESS_NETWORK_STATE` permission.

**Find this (lines 3-4):**
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

**Replace with:**
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**Verification:** Open the file and confirm there are now 3 `<uses-permission>` lines.

---

## Task 2: Remove Unused Imports (Lint Cleanup)

### 2a. `lib/screens/bedtime_wizard_screen.dart` — line 9

**Remove this line entirely:**
```dart
import '../story_result_screen.dart';
```

### 2b. `lib/screens/wizard_steps/companion_selector_step.dart` — line 5

**Remove this line entirely:**
```dart
import '../../services/app_tts_service.dart';
```

### 2c. `lib/screens/wizard_steps/hero_creator_step.dart` — line 5

**Remove this line entirely:**
```dart
import 'package:audioplayers/audioplayers.dart';
```

### 2d. `lib/screens/wizard_steps/hero_creator_step.dart` — line 25

**Remove this line entirely:**
```dart
import '../../services/tts_api_service.dart';
```

**Verification:** Run `dart analyze lib/` — the 4 "unused import" warnings should be gone.

---

## Task 3: Fix MagicEarButton Timeout Crash

**File:** `lib/widgets/magic_ear_button.dart`

**Problem:** Line 44 calls `speak(... awaitCompletion: true)` which can throw a `TimeoutException` after 30 seconds. If it throws, the button gets stuck in "speaking" state forever because lines 45-46 never execute.

**Find this (lines 35-47):**
```dart
  Future<void> _toggle() async {
    if (_isSpeaking) {
      await AppTtsService.instance.stop();
      _pulseCtrl.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    _pulseCtrl.repeat(reverse: true);
    await AppTtsService.instance.speak(widget.spokenText, awaitCompletion: true);
    _pulseCtrl.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }
```

**Replace with:**
```dart
  Future<void> _toggle() async {
    if (_isSpeaking) {
      await AppTtsService.instance.stop();
      _pulseCtrl.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    _pulseCtrl.repeat(reverse: true);
    try {
      await AppTtsService.instance.speak(widget.spokenText, awaitCompletion: true);
    } catch (_) {
      // TimeoutException or other — just stop gracefully
    }
    _pulseCtrl.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }
```

**What changed:** Wrapped the `speak` call in try/catch so that the cleanup code (stop pulse, reset state) always runs.

---

## Task 4: Fix Exit Button Missing `mounted` Check

**File:** `lib/screens/bedtime_wizard_screen.dart`

**Problem:** The exit button on line 374 and the GestureDetector on line 310 both call `Navigator.of(context).pop()` without checking `mounted`. If the screen is already being disposed (e.g. during async story generation), this can crash.

### 4a. Fix the GestureDetector tap (line 308-311)

**Find this:**
```dart
          onTap: () {
            if (_step == BedtimeStep.done) {
              Navigator.of(context).pop();
            }
          },
```

**Replace with:**
```dart
          onTap: () {
            if (_step == BedtimeStep.done && mounted) {
              Navigator.of(context).pop();
            }
          },
```

### 4b. Fix the Exit Bedtime Mode button (line 374)

**Find this:**
```dart
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
```

**Replace with:**
```dart
                TextButton(
                  onPressed: () {
                    if (mounted) Navigator.of(context).pop();
                  },
```

---

## Task 5: Add TTS Timeout Handling in Bedtime Story Reading

**File:** `lib/screens/bedtime_wizard_screen.dart`

**Problem:** Each paragraph's TTS playback has a 30-second timeout in `app_tts_service.dart`. If a long paragraph exceeds this, a `TimeoutException` propagates uncaught and kills the entire reading loop.

**Find this (lines 286-293):**
```dart
      final paragraphs = result.storyText.split(RegExp(r'\n\n+'));
      for (final paragraph in paragraphs) {
        if (paragraph.trim().isEmpty) continue;
        if (!mounted) return;
        setState(() => _statusText = '...');
        await AppTtsService.instance.speak(paragraph.trim(), awaitCompletion: true);
        await Future.delayed(const Duration(milliseconds: 800));
      }
```

**Replace with:**
```dart
      final paragraphs = result.storyText.split(RegExp(r'\n\n+'));
      for (final paragraph in paragraphs) {
        if (paragraph.trim().isEmpty) continue;
        if (!mounted) return;
        setState(() => _statusText = '...');
        try {
          await AppTtsService.instance.speak(paragraph.trim(), awaitCompletion: true);
        } catch (_) {
          // Timeout on long paragraph — continue to next
        }
        await Future.delayed(const Duration(milliseconds: 800));
      }
```

---

## Task 6: Handle Speech Unavailable with User Feedback

**File:** `lib/screens/bedtime_wizard_screen.dart`

**Problem:** If speech recognition is unavailable (no mic permissions, no hardware), `_askQuestion` returns an empty string silently. The child hears a question but the app just skips ahead with a hardcoded default. The child has no idea what happened.

**Find this (lines 177-181):**
```dart
  Future<String> _askQuestion(String question) async {
    await _speak(question);
    if (!_speechAvailable) return '';
    return await _listen();
  }
```

**Replace with:**
```dart
  Future<String> _askQuestion(String question) async {
    await _speak(question);
    if (!_speechAvailable) {
      await _speak("I can't hear you right now, so I'll pick for you!");
      return '';
    }
    final answer = await _listen();
    if (answer.isEmpty) {
      await _speak("I didn't catch that, so I'll surprise you!");
    }
    return answer;
  }
```

**What changed:** Two improvements:
1. If mic is unavailable, the child hears a friendly explanation instead of silence.
2. If the child says nothing (empty result from timeout), they hear a friendly fallback message.

---

## Task 7: Improve Fuzzy Matching Robustness

**File:** `lib/screens/bedtime_wizard_screen.dart`

**Problem:** The fuzzy matching only uses exact substring `contains()`. Common speech recognition errors like "dragoon" or "owel" won't match. Also, "friend" ambiguously matches both a scenario and a mood.

### 7a. Replace `_fuzzyMatchCompanion` (lines 210-225)

**Find this:**
```dart
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
    return input.isNotEmpty ? input : 'a tiny dragon';
  }
```

**Replace with:**
```dart
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
    // Exact substring match first
    for (final entry in companions.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    // Prefix match for speech recognition errors (e.g. "drago", "unico")
    for (final entry in companions.entries) {
      if (entry.key.startsWith(lower.trim()) ||
          lower.contains(entry.key.substring(0, (entry.key.length * 0.6).ceil()))) {
        return entry.value;
      }
    }
    return input.isNotEmpty ? input : 'a tiny dragon';
  }
```

### 7b. Fix the "friend" ambiguity in `_fuzzyMatchScenario` (lines 227-235)

**Find this:**
```dart
  String _fuzzyMatchScenario(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('rainbow')) return 'Rainbow Land';
    if (lower.contains('crystal') || lower.contains('cave')) return 'Crystal Cavern';
    if (lower.contains('dragon')) return 'Volcano Dragons';
    if (lower.contains('friend')) return 'Brave Friend';
    if (lower.contains('feel')) return 'Big Feelings Quest';
    return input.isNotEmpty ? input : 'Magical Forest';
  }
```

**Replace with:**
```dart
  String _fuzzyMatchScenario(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('rainbow')) return 'Rainbow Land';
    if (lower.contains('crystal') || lower.contains('cave')) return 'Crystal Cavern';
    if (lower.contains('dragon')) return 'Volcano Dragons';
    if (lower.contains('brave') || lower.contains('hero')) return 'Brave Friend';
    if (lower.contains('feel') || lower.contains('emotion')) return 'Big Feelings Quest';
    if (lower.contains('forest') || lower.contains('magic')) return 'Magical Forest';
    return input.isNotEmpty ? input : 'Magical Forest';
  }
```

**What changed:** Removed "friend" as a scenario trigger (it was ambiguous with the mood matcher). Replaced with "brave"/"hero" which are unambiguous. Added "forest"/"magic" as explicit triggers for the default.

---

## Task 8: Increase TTS Timeout for Story Paragraphs

**File:** `lib/services/app_tts_service.dart`

**Problem:** The 30-second timeout on line 104 is too short for long story paragraphs read aloud by ElevenLabs. A typical paragraph at narration speed can take 45-60 seconds.

**Find this (lines 102-104):**
```dart
        if (awaitCompletion) {
          await _player.onPlayerComplete.first
              .timeout(const Duration(seconds: 30));
        }
```

**Replace with:**
```dart
        if (awaitCompletion) {
          await _player.onPlayerComplete.first
              .timeout(const Duration(seconds: 120));
        }
```

**Why 120:** Generous enough for the longest plausible paragraph (~500 words at narration pace). The try/catch added in Task 5 protects against the timeout still being exceeded.

---

## Task 9: Add Completer Safety Guard in `_listen`

**File:** `lib/screens/bedtime_wizard_screen.dart`

**Problem:** If the `pauseFor` timer fires after the completer's 12-second timeout, `onResult` may call `completer.complete()` on an already-completed completer, throwing a `StateError`.

**Find this (lines 183-208):**
```dart
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

    final answer = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );

    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    return answer;
  }
```

**Replace with:**
```dart
  Future<String> _listen() async {
    if (!mounted) return '';
    final completer = Completer<String>();
    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _statusText = '"${result.recognizedWords}"');
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );

    final answer = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );

    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    return answer;
  }
```

**What changed:** Added `&& !completer.isCompleted` guard on line with `completer.complete()` to prevent double-completion crash.

---

## Task 10: Add Error Logging to TTS Service

**File:** `lib/services/app_tts_service.dart`

**Problem:** All catch blocks silently swallow exceptions, making TTS failures impossible to debug.

### 10a. Add `import 'package:flutter/foundation.dart';` at the top of the file.

**Find this (line 7):**
```dart
import 'dart:typed_data';
```

**Replace with:**
```dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
```

### 10b. Fix the prewarm catch block (line 76)

**Find this:**
```dart
      } catch (_) {}
    }
  }
```
(This is inside the `_prewarm` method's for loop)

**Replace with:**
```dart
      } catch (e) {
        debugPrint('TTS prewarm failed for phrase: $e');
      }
    }
  }
```

### 10c. Fix the speak catch block (line 108)

**Find this:**
```dart
    } catch (_) {}
    // On-device fallback
```

**Replace with:**
```dart
    } catch (e) {
      debugPrint('TTS ElevenLabs failed, falling back to device: $e');
    }
    // On-device fallback
```

---

## Summary Checklist

| # | Task | File(s) | Severity |
|---|------|---------|----------|
| 1 | Add RECORD_AUDIO permission | `AndroidManifest.xml` | CRITICAL |
| 2 | Remove 4 unused imports | 3 files | Low |
| 3 | try/catch in MagicEarButton._toggle | `magic_ear_button.dart` | High |
| 4 | Add mounted checks to exit buttons | `bedtime_wizard_screen.dart` | High |
| 5 | try/catch around paragraph TTS | `bedtime_wizard_screen.dart` | High |
| 6 | Speech unavailable user feedback | `bedtime_wizard_screen.dart` | High |
| 7 | Improve fuzzy matching | `bedtime_wizard_screen.dart` | High |
| 8 | Increase TTS timeout to 120s | `app_tts_service.dart` | Medium |
| 9 | Completer safety guard | `bedtime_wizard_screen.dart` | Medium |
| 10 | Add debugPrint to catch blocks | `app_tts_service.dart` | Low |

**After all tasks:** Run `dart analyze lib/` and confirm zero warnings/errors.
