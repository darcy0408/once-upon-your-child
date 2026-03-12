# Crawl: Screen Reader Accessibility Audit & Fix

## Goal
Make every interactive element in the Story Weaver wizard, welcome screen, and story result screen fully accessible to iOS VoiceOver and Android TalkBack.

## Background

### What Already Exists
- `Semantics` widgets on **scenario cards** in `lib/screens/wizard_steps/feeling_selection_step.dart:885` (good pattern to follow)
- `Semantics` widgets on **archetype cards** and **role cards** in `lib/screens/wizard_steps/hero_creator_step.dart` (lines 2310, 2418, 4881, 5056)
- A few `Semantics` in widgets: `archetype_card.dart`, `pill_button.dart`, `image_continue_button.dart`, `image_make_magic_button.dart`

### What's Missing
Almost every other interactive element lacks proper semantic labels. Screen readers will announce raw widget types ("button", "slider") with no context.

---

## Files to Modify (in priority order)

### 1. `lib/screens/welcome_screen.dart`
**Current state:** No Semantics. Has name input, age picker bubbles, and a "go" button.

**Changes needed:**
- Wrap the title "Story Weaver" text with `Semantics(header: true, label: 'Story Weaver. Welcome!')`
- Wrap each age bubble (the `_ageEntries` loop ~line 46-58) in:
  ```dart
  Semantics(
    button: true,
    selected: _selectedAge == entry.value,
    label: 'Age ${entry.label}. ${_selectedAge == entry.value ? "Selected" : "Double tap to select"}',
    child: /* existing GestureDetector/InkWell */,
  )
  ```
- Wrap the name `TextField` with `Semantics(label: "Enter your name", textField: true)`
- Wrap the "Let's Go" / submit button with `Semantics(button: true, label: "Start your adventure")`
- Add `ExcludeSemantics` around any purely decorative stars/sparkle animations

### 2. `lib/screens/wizard_steps/hero_creator_step.dart`
**Current state:** Has Semantics on archetype cards and role cards only.
**File is very large (~5000+ lines) — search for these patterns:**

**Changes needed:**
- **Name input field** (~search for `_nameController`): wrap `TextField` in `Semantics(label: "Hero name", textField: true)`
- **Age display/picker** (if separate from welcome): add `Semantics(label: "Hero age: ${age}")`
- **Avatar gallery** (search `AvatarGallerySelector`): ensure each avatar option has `Semantics(button: true, selected: isSelected, label: "Avatar option ${index + 1} of ${total}. ${isSelected ? 'Selected' : 'Double tap to select'}")`
- **Custom avatar button** (search `CustomAvatarScreen`): `Semantics(button: true, label: "Create custom avatar")`
- **"Imagine It" text field** (search `_imagineItController`): `Semantics(label: "Describe your own adventure setting", textField: true)`
- **Mic buttons** (search `_speech`, `VoiceMicButton`): `Semantics(button: true, label: "Tap to speak your answer")`
- **Page navigation dots** (search `PageController`): `Semantics(label: "Step ${_heroPage + 1} of ${totalPages}")`
- **Continue/Next buttons**: `Semantics(button: true, label: "Continue to next step")`
- **Pet creation section** (search `pets`, `_isPetAvatarGenerating`): label pet name/species fields
- Add `ExcludeSemantics` around sparkle animations (`_sparkleCtrl`), decorative gradients, and background images

### 3. `lib/screens/wizard_steps/feeling_selection_step.dart`
**Current state:** Scenario cards have Semantics (line 885). Nothing else does.

**Changes needed:**
- **Guardian Mode toggle** (line 235-248, the shield `IconButton`):
  ```dart
  Semantics(
    button: true,
    toggled: _showParentalInput,
    label: 'Guardian Mode. ${_showParentalInput ? "Open. Double tap to close" : "Closed. Double tap to open"}',
  )
  ```
- **Life Challenge chips** (line 436-458): each `ChoiceChip` — wrap in `Semantics(button: true, selected: isSelected, label: "$challenge. ${isSelected ? 'Selected' : 'Double tap to select'}")`
- **Personality sliders** (`_buildSlider` method, line 118-171): wrap each `Slider` in:
  ```dart
  Semantics(
    slider: true,
    label: '$leftLabel to $rightLabel',
    value: '${value.round()} percent',
  )
  ```
- **Parental Note text field** (line 537): `Semantics(label: "Parental note for story guidance", textField: true)`
- **Math gate** (line 596-668): label the input `Semantics(label: "Answer: what is $_mathA plus $_mathB", textField: true)` and the Unlock button
- **Story DNA chips** (lines 710-733, 750-772): same pattern as Life Challenge chips
- **Avoid topics text field** (line 785): `Semantics(label: "Topics to avoid in the story", textField: true)`
- **Feelings Quest button** (search `_openFeelingsQuest`): `Semantics(button: true, label: "Open feelings picker")`
- **Continue button** (line 282): `Semantics(button: true, label: "Continue. Your adventure choice is ${_selectedScenario ?? 'not yet selected'}")`

### 4. `lib/screens/wizard_steps/companion_selector_step.dart`
**Current state:** No Semantics at all. Has an audio prompt button but no screen reader labels.

**Changes needed:**
- **Audio prompt button** (`_audioPrompt` method, line 188-193): `Semantics(button: true, label: "Listen to this question")`
- **Each companion card** (in the `ListView` building companion cards): wrap in:
  ```dart
  Semantics(
    button: true,
    selected: _selectedCompanions.contains(companion.id),
    label: '${companion.name}. ${companion.description}. ${_selectedCompanions.contains(companion.id) ? "Selected" : "Double tap to add to your team"}',
    child: /* existing card */,
  )
  ```
- **Section headers** ("Your Friends", "Magical Companions"): `Semantics(header: true)`
- **Continue/Done button**: `Semantics(button: true, label: "Continue with ${_selectedCompanions.length} companions selected")`

### 5. `lib/screens/wizard_steps/magic_review_step.dart`
**Changes needed:**
- **Review summary** (hero name, scenario, companions listed): `Semantics(label: "Your story: Hero is [name], adventuring in [scenario] with [companions]")`
- **"Make Magic" button**: `Semantics(button: true, label: "Generate your story. Tap to begin!")`
- **Loading state**: `Semantics(liveRegion: true, label: _loadingStatus)` so screen readers announce progress
- **Go Back button** (if present): `Semantics(button: true, label: "Go back to edit your choices")`

### 6. `lib/story_result_screen.dart`
**Changes needed:**
- **Story text**: `Semantics(label: storyText)` or use `readOnly: true` so TalkBack can read it
- **Page navigation** (page flip): `Semantics(label: "Page ${currentPage + 1} of ${totalPages}. Swipe to turn page")`
- **Read aloud button** (if exists): `Semantics(button: true, label: "Read story aloud")`
- **Share button**: `Semantics(button: true, label: "Share this story")`
- **Save button**: `Semantics(button: true, label: "Save story for later")`
- **Illustrations**: `Semantics(image: true, label: "Story illustration")` (or `ExcludeSemantics` if redundant)

### 7. `lib/widgets/voice_mic_button.dart`
**Current state:** No Semantics. The GestureDetector (line 122) is invisible to screen readers.

**Changes needed:**
```dart
Semantics(
  button: true,
  label: _listening
      ? 'Listening. ${_lastHeard.isEmpty ? "Speak now" : "Heard: $_lastHeard"}. Tap to stop'
      : unavailable
          ? 'Microphone unavailable'
          : widget.hint,
  liveRegion: _listening, // Announce changes while listening
  child: GestureDetector(/* existing code */),
)
```

### 8. Other widgets to check
- `lib/widgets/image_continue_button.dart` — verify existing Semantics label says "Continue"
- `lib/widgets/image_make_magic_button.dart` — verify label says "Make Magic" or similar
- `lib/widgets/pill_button.dart` — verify Semantics passes through the button label
- `lib/widgets/feelings_quest_modal.dart` — add Semantics to emotion cloud bubbles

---

## Implementation Rules

1. **Never nest Semantics unnecessarily.** If a widget already has `Semantics`, update it rather than wrapping another layer.
2. **Use `ExcludeSemantics`** for purely decorative elements (sparkle animations, gradient backgrounds, decorative emojis that are repeated in the label).
3. **Use `MergeSemantics`** when a card has multiple text children that should be read as one unit.
4. **Always include interaction hints** in labels: "Double tap to select", "Swipe to change", etc.
5. **Use `liveRegion: true`** for content that changes dynamically (loading states, listening feedback).
6. **Test with:** iOS VoiceOver (Settings > Accessibility > VoiceOver) and Android TalkBack (Settings > Accessibility > TalkBack). Navigate every screen with only the screen reader.

## Testing Checklist
- [ ] Welcome screen: can navigate name → age → go with screen reader only
- [ ] Hero creator: can pick name, archetype, avatar, and advance with screen reader only
- [ ] Feeling selection: can pick scenario, open Guardian Mode, use sliders with screen reader only
- [ ] Companion selector: can pick companions and advance with screen reader only
- [ ] Magic review: can hear summary and tap Make Magic with screen reader only
- [ ] Story result: can navigate pages and hear story with screen reader only
- [ ] VoiceMicButton: screen reader announces state changes
