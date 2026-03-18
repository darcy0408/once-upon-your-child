# Walk: "Magic Ear" Read-Aloud Button

## Goal
Add a persistent "Magic Ear" button to every wizard step that reads the current question and available choices aloud using the existing `AppTtsService`. This is for sighted kids who can't read yet or who prefer audio guidance — NOT a screen reader replacement.

## Background

### What Already Exists
- **`AppTtsService`** (`lib/services/app_tts_service.dart`): singleton with `speak(text, {awaitCompletion})` and `stop()`. Uses ElevenLabs with on-device fallback. Has a pre-warm cache for common phrases.
- **Pre-warmed phrases** (`kWarmUpPhrases`, line 17-39): already includes wizard prompts like "Pick your hero look!", "Tap your buddies to bring them along!", "Where should your adventure happen?"
- **Existing audio prompts**: `companion_selector_step.dart` already has a `_audioPrompt()` method (line 188) that creates a speaker icon button calling `AppTtsService.instance.speak(text)`. This is the pattern to generalize.
- **`VoiceMicButton`** (`lib/widgets/voice_mic_button.dart`): reusable mic button for speech input — already exists, no changes needed for Walk tier.

### Architecture Decision
Rather than a global toggle, each wizard step gets a **"Magic Ear" FloatingActionButton** (or inline button in the header) that reads the step's prompt + choices when tapped. This is simpler and more discoverable than a toggle.

---

## Implementation

### Step 1: Create `MagicEarButton` Widget

**New file: `lib/widgets/magic_ear_button.dart`**

```dart
import 'package:flutter/material.dart';
import '../services/app_tts_service.dart';

/// A golden speaker button that reads a prompt aloud via TTS.
/// Place in the AppBar or header row of each wizard step.
class MagicEarButton extends StatefulWidget {
  /// The full text to speak (question + choices).
  final String spokenText;
  final double size;

  const MagicEarButton({
    super.key,
    required this.spokenText,
    this.size = 36,
  });

  @override
  State<MagicEarButton> createState() => _MagicEarButtonState();
}

class _MagicEarButtonState extends State<MagicEarButton>
    with SingleTickerProviderStateMixin {
  bool _isSpeaking = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

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

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _isSpeaking ? 'Stop reading aloud' : 'Read this question aloud',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) => Transform.scale(
            scale: _isSpeaking ? 1.0 + (_pulseCtrl.value * 0.15) : 1.0,
            child: child,
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSpeaking
                  ? const Color(0xFFFFD700).withOpacity(0.3)
                  : const Color(0xFFFFD700).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: Icon(
              _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: const Color(0xFFFFD700),
              size: widget.size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
```

### Step 2: Add Pre-Warm Phrases

**File: `lib/services/app_tts_service.dart`**

Add these new phrases to `kWarmUpPhrases` (line 17-39):

```dart
// Walk tier — Magic Ear full prompts
"What is your hero's name? You can type it or tap the microphone to say it!",
"Pick your hero's look! Swipe through the pictures and tap the one you like.",
"Choose your adventure! Swipe through the cards. You can pick Rainbow Land, Crystal Cave, Dragon Friends, or tap Imagine It to make your own!",
"Pick your travel buddies! Tap a companion to bring them along. You can pick a tiny dragon, a wise owl, a shadow cat, a star dog, a magic unicorn, or a clever fox.",
"Here is your story recipe! Check everything looks right, then tap Make Magic to start!",
```

### Step 3: Add MagicEarButton to Each Wizard Step

#### 3a. `lib/screens/wizard_steps/hero_creator_step.dart`

The hero creator is a multi-page wizard. Each sub-page needs its own spoken prompt. Find the page builder and add the button to each page's header.

**For the Name page** (search for the page that shows `_nameController`):
```dart
MagicEarButton(
  spokenText: "What is your hero's name? You can type it or tap the microphone to say it!",
)
```

**For the Look/Avatar page** (search for archetype selection):
```dart
MagicEarButton(
  spokenText: "Pick your hero's look! Swipe through the pictures and tap the one you like.",
)
```

**For the Role page** (search for role/archetype cards):
```dart
MagicEarButton(
  spokenText: _buildRoleSpokenText(), // see below
)
```

Add a helper method:
```dart
String _buildRoleSpokenText() {
  // Dynamically build from available archetypes
  return "Choose your hero's role! You can be The Explorer, The Guardian, The Creator, or The Dreamer. Tap the one that feels right!";
}
```

**Placement pattern:** Add the `MagicEarButton` to the `Row` containing each sub-page's title text, similar to how `companion_selector_step.dart` already does it with `_audioPrompt()`.

#### 3b. `lib/screens/wizard_steps/feeling_selection_step.dart`

Find the title Row (line 222-249) and add the button:

```dart
Row(
  children: [
    MagicEarButton(
      spokenText: _buildScenarioSpokenText(),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text('Choose Your Adventure!', /* ... */),
    ),
    // existing Guardian Mode icon button
  ],
),
```

Add helper:
```dart
String _buildScenarioSpokenText() {
  final scenarioNames = _scenarios.map((s) => s.titleForAge(
    widget.wizardData.characterAge <= 0 ? 5 : widget.wizardData.characterAge,
  )).join(', ');
  return 'Choose your adventure! Where shall we go today? You can pick $scenarioNames. Swipe through the cards and tap the one you like!';
}
```

#### 3c. `lib/screens/wizard_steps/companion_selector_step.dart`

**Replace** the existing `_audioPrompt` method (line 188-193) with:
```dart
Widget _audioPrompt() {
  return MagicEarButton(
    spokenText: _buildCompanionSpokenText(),
  );
}

String _buildCompanionSpokenText() {
  final names = _magicalCompanions.map((c) => c.name).join(', ');
  return 'Pick your travel buddies! Tap a companion to bring them along. You can choose $names.';
}
```

Update the call site (line 207) from `_audioPrompt("Choose a travel buddy")` to `_audioPrompt()`.

#### 3d. `lib/screens/wizard_steps/magic_review_step.dart`

Add to the review screen header:
```dart
MagicEarButton(
  spokenText: _buildReviewSpokenText(),
)
```

Add helper:
```dart
String _buildReviewSpokenText() {
  final wd = widget.wizardData;
  final hero = wd.characterName.isEmpty ? 'your hero' : wd.characterName;
  final scenario = wd.selectedScenario ?? 'a magical place';
  final companions = wd.companionNames.isEmpty
      ? 'no companions yet'
      : wd.companionNames.join(' and ');
  return 'Here is your story recipe! $hero is adventuring in $scenario with $companions. Check everything looks right, then tap Make Magic to start!';
}
```

### Step 4: Auto-Speak on Step Entry (Optional Enhancement)

For the youngest users (age 3-5), auto-speak when entering each step. Add this to each step's `initState`:

```dart
@override
void initState() {
  super.initState();
  // Auto-speak for young children
  if (widget.wizardData.characterAge <= 5) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppTtsService.instance.speak(_spokenText);
      }
    });
  }
}
```

Where `_spokenText` is the same string used by `MagicEarButton`. Consider extracting these strings into a shared constant or method.

---

## Testing Checklist
- [ ] MagicEarButton appears on every wizard step header
- [ ] Tapping it reads the full question + choices aloud via ElevenLabs voice
- [ ] Tapping again while speaking stops playback
- [ ] Button pulses while speaking, stops when done
- [ ] Pre-warmed phrases play instantly (no loading delay)
- [ ] Dynamic phrases (companion names, hero name in review) read correctly
- [ ] Auto-speak fires for age <= 5 on step entry
- [ ] Button has proper Semantics for screen readers
- [ ] Does NOT interfere with VoiceMicButton (STT) — stop TTS before starting STT
