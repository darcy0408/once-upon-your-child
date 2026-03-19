# UX/UI Audit Fix Plan — Delegation Prompts

**Created:** 2026-03-19
**Source:** Triple-auditor UX/UI review (Claude + Gemini CLI + Codex)
**Purpose:** Self-contained prompts for delegating each fix to Gemini 3 Pro or GPT-5.4

## How to Use This Document

Each task below has:
- **Recommended Model**: Which model to use
- **Prompt**: Copy-paste the entire prompt block into the model
- **Verification**: How to check the work was done correctly

**General rules to include in every session:**
- After completing work, update `TEAM_COORDINATION.md` at the repo root with a new session entry following the existing format
- Commit changes with a descriptive message ending with the model's co-author line
- Use `dart analyze` on changed files if possible
- Do NOT modify files not listed in the task
- Do NOT add emojis to code unless the existing code already uses them there
- Use camelCase for all Dart method/variable names (snake_case causes compile errors)

---

## PHASE 1: Critical Bugs & Broken Functionality

---

### Task 1.1 — Fix BigFeelingsFlowScreen Theme Isolation

**Recommended Model:** Gemini 3 Pro (large widget rework, needs careful reasoning)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix `lib/screens/big_feelings_flow_screen.dart` so it respects the age-band theme system instead of using hardcoded colors and fonts.

## Current Problems (verified in code)
1. Line 178: Background is hardcoded `const Color(0xFF1A0E3A)` — ignores the age-band theme
2. Lines 200, 214: Font is hardcoded `GoogleFonts.fredoka` — should use the band's `uiFontFamily`
3. Lines 38-57: Only 3 feelings (Mad, Sad, Scared) — needs Happy and Excited added
4. Line 316: Choice cards show emoji at fontSize 40 — should use PNG images from `assets/images/feelings/sprout/` (which exist: angry.png, calm.png, confused.png, excited.png, happy.png, sad.png, scared.png, surprised.png)

## What to Change

### A. Accept age parameter
The widget currently takes no parameters. Add an optional `childAge` parameter:
```dart
class BigFeelingsFlowScreen extends StatefulWidget {
  const BigFeelingsFlowScreen({super.key, this.childAge = 5});
  final int childAge;

  static Future<BigFeelingsFlowResult?> show(BuildContext context, {int childAge = 5}) {
    return Navigator.of(context, rootNavigator: true)
        .push<BigFeelingsFlowResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BigFeelingsFlowScreen(childAge: childAge),
      ),
    );
  }
  // ...
}
```

### B. Use age-band theme for background
In the `build()` method, get the theme and use its gradient:
```dart
final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
```
Replace the hardcoded `backgroundColor: const Color(0xFF1A0E3A)` in the Scaffold with:
```dart
backgroundColor: Colors.transparent,
```
And wrap the body in a Container with the band's gradient:
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
    ),
  ),
  child: SafeArea(/* existing child */),
)
```

### C. Use band font instead of hardcoded Fredoka
Replace all `GoogleFonts.fredoka(...)` calls with `GoogleFonts.getFont(band.uiFontFamily, ...)`. Keep the same fontSize and fontWeight values. You need to import `package:google_fonts/google_fonts.dart` (already imported).

### D. Add Happy and Excited to the feelings list
Add these to the `_feelings` list at line 38:
```dart
_ChoiceOption(
  value: 'Happy',
  label: 'Happy',
  emoji: '😊',
  subtitle: 'Big smile feeling',
),
_ChoiceOption(
  value: 'Excited',
  label: 'Excited',
  emoji: '🤩',
  subtitle: 'Bouncy, can\'t-wait feeling',
),
```

Also add trigger, body signal, and coping options for these:
```dart
// In _triggerOptions:
'Happy': [
  _ChoiceOption(value: 'Did something fun', label: 'Fun', emoji: '🎉'),
  _ChoiceOption(value: 'Made a friend', label: 'Friend', emoji: '🤝'),
  _ChoiceOption(value: 'Got a surprise', label: 'Surprise', emoji: '🎁'),
],
'Excited': [
  _ChoiceOption(value: 'Something is coming', label: 'Coming', emoji: '⏰'),
  _ChoiceOption(value: 'Going somewhere', label: 'Going', emoji: '✈️'),
  _ChoiceOption(value: 'Trying something new', label: 'New', emoji: '🌟'),
],

// In _bodyOptions:
'Happy': [
  _ChoiceOption(value: 'Big smiles', label: 'Big smiles', emoji: '😁'),
  _ChoiceOption(value: 'Warm chest', label: 'Warm chest', emoji: '💛'),
  _ChoiceOption(value: 'Bouncy feet', label: 'Bouncy feet', emoji: '🦶'),
],
'Excited': [
  _ChoiceOption(value: 'Butterflies', label: 'Butterflies', emoji: '🦋'),
  _ChoiceOption(value: 'Fast talking', label: 'Fast talking', emoji: '💬'),
  _ChoiceOption(value: 'Wiggly body', label: 'Wiggly body', emoji: '🕺'),
],

// In _helperOptions:
'Happy': [
  _ChoiceOption(value: 'Share the joy', label: 'Share it', emoji: '💝'),
  _ChoiceOption(value: 'Do a happy dance', label: 'Dance', emoji: '💃'),
  _ChoiceOption(value: 'Draw the feeling', label: 'Draw it', emoji: '🖍️'),
],
'Excited': [
  _ChoiceOption(value: 'Take a deep breath', label: 'Deep breath', emoji: '🌬️'),
  _ChoiceOption(value: 'Tell someone', label: 'Tell someone', emoji: '🗣️'),
  _ChoiceOption(value: 'Count to ten', label: 'Count', emoji: '🔢'),
],
```

### E. Use feeling face images instead of emoji
In the `_BigFeelingsChoiceCard` widget (line 316), replace the emoji Text widget:
```dart
// OLD:
Text(option.emoji, style: const TextStyle(fontSize: 40)),

// NEW (only for step 0 — the feelings selection step):
// Map feeling values to image filenames
Image.asset(
  'assets/images/feelings/${_bandFolder()}/\${option.value.toLowerCase()}.png',
  width: 48,
  height: 48,
  errorBuilder: (_, __, ___) => Text(option.emoji, style: const TextStyle(fontSize: 40)),
)
```
Where `_bandFolder()` returns the band name string based on `widget.childAge`:
```dart
String _bandFolder() {
  if (widget.childAge <= 5) return 'sprout';
  if (widget.childAge <= 8) return 'explorer';
  if (widget.childAge <= 11) return 'adventurer';
  if (widget.childAge <= 14) return 'creator';
  if (widget.childAge <= 17) return 'adolescent';
  return 'adult';
}
```
Keep emoji as errorBuilder fallback. For steps 1-3 (triggers, body signals, coping tools), keep the emoji display since there are no image assets for those.

### F. Update the caller
In `lib/screens/wizard_steps/feeling_selection_step.dart`, around line 122, the call to `BigFeelingsFlowScreen.show(context)` should pass the age:
```dart
final result = await BigFeelingsFlowScreen.show(context, childAge: age);
```

Also check `lib/screens/wizard_steps/hero_creator_step.dart` for any calls to `BigFeelingsFlowScreen.show()` and add the childAge parameter there too.

### G. Required imports
Add to big_feelings_flow_screen.dart:
```dart
import '../theme/age_band_theme.dart';
```

## Files to Change
- `lib/screens/big_feelings_flow_screen.dart` (main changes)
- `lib/screens/wizard_steps/feeling_selection_step.dart` (pass childAge)
- `lib/screens/wizard_steps/hero_creator_step.dart` (pass childAge if it calls BigFeelingsFlowScreen)

## Verification
- The Scaffold background should use the age-band gradient, not hardcoded dark purple
- 5 feelings should appear on step 0 (Mad, Sad, Scared, Happy, Excited)
- Step 0 cards should show PNG images with emoji fallback
- All fonts should come from the band's uiFontFamily, not hardcoded Fredoka
- `dart analyze lib/screens/big_feelings_flow_screen.dart` should pass

## After completing, update TEAM_COORDINATION.md at the repo root with a session entry and commit:
```
git add lib/screens/big_feelings_flow_screen.dart lib/screens/wizard_steps/feeling_selection_step.dart lib/screens/wizard_steps/hero_creator_step.dart TEAM_COORDINATION.md
git commit -m "fix: BigFeelingsFlowScreen theme isolation, add Happy/Excited, use face images

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

### Task 1.2 — Fix "Limerick Laughs" Reading Mode Label

**Recommended Model:** GPT-5.4 (simple string replacement)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix a mislabeled reading mode in the hero creator step.

## Problem
In `lib/screens/wizard_steps/hero_creator_step.dart`, the function `_getReadingLabel` (around line 1733) returns "Limerick Laughs" for both Explorer (ages 6-8) and Adventurer (ages 9-11) bands. This is confusing because a Limerick is a poetry style, not a reading level.

## Current Code (around line 1733):
```dart
String _getReadingLabel(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return 'First Reader';
    case AgeBand.explorer:
    case AgeBand.adventurer:
      return 'Limerick Laughs';
    case AgeBand.creator:
    case AgeBand.adolescent:
    case AgeBand.adult:
      return 'First Chapter';
  }
}
```

## Fix
Change to:
```dart
String _getReadingLabel(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return 'First Reader';
    case AgeBand.explorer:
      return 'Easy Reader';
    case AgeBand.adventurer:
      return 'Chapter Reader';
    case AgeBand.creator:
    case AgeBand.adolescent:
    case AgeBand.adult:
      return 'First Chapter';
  }
}
```

## Also check
Search the codebase for any other occurrence of "Limerick Laughs" string and update if found. The magic_review_step.dart has a `_storyTypeLabel` function that may reference this — check around line 467 for:
```dart
return band.band == AgeBand.sprout ? 'Rhyme story' : 'Limerick Laughs story';
```
If found, change to:
```dart
return band.band == AgeBand.sprout ? 'Rhyme story' : 'Rhyme Time story';
```

## Files to Change
- `lib/screens/wizard_steps/hero_creator_step.dart` (the _getReadingLabel function)
- `lib/screens/wizard_steps/magic_review_step.dart` (if "Limerick Laughs" appears there)

## Verification
- Search the entire lib/ directory for "Limerick Laughs" — should return zero results
- `dart analyze` on changed files should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/hero_creator_step.dart lib/screens/wizard_steps/magic_review_step.dart TEAM_COORDINATION.md
git commit -m "fix: rename 'Limerick Laughs' reading label to 'Easy Reader'/'Chapter Reader'

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 1.4 — Fix Bedtime "Go to Settings" Button

**Recommended Model:** GPT-5.4 (simple navigation fix)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix the "Go to Settings" button in the bedtime wizard that doesn't actually navigate to settings.

## Problem
In `lib/screens/bedtime_wizard_screen.dart`, around line 605-617, there is an ElevatedButton labeled "Go to Settings" that only calls `Navigator.of(context).pop()` instead of navigating to settings.

## Current Code (around line 608):
```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.of(context).pop(); // Go back so parent can open Settings
  },
  icon: const Icon(Icons.settings),
  label: const Text('Go to Settings'),
```

## Fix
Replace the onPressed handler to actually navigate to settings. First, check what the settings screen import looks like — search for `SettingsScreen` or `settings_screen` in the codebase to find the correct class name and import path. Then update:

```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.of(context).pop(); // Close bedtime screen first
    // Then navigate to settings from the parent context
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  },
  icon: const Icon(Icons.settings),
  label: const Text('Go to Settings'),
```

If `SettingsScreen` doesn't exist (check by searching), look for `ParentControlsScreen` or `SubscriptionManagementScreen` — whatever screen contains API key settings. The key is that bedtime mode needs a Gemini API key (BYOK), so the settings screen must be the one where users enter their API key.

Add the required import at the top of the file.

## Files to Change
- `lib/screens/bedtime_wizard_screen.dart`

## Verification
- The "Go to Settings" button should navigate to the correct settings/API key screen
- `dart analyze lib/screens/bedtime_wizard_screen.dart` should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/bedtime_wizard_screen.dart TEAM_COORDINATION.md
git commit -m "fix: bedtime 'Go to Settings' button now navigates to settings screen

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 1.5 — Fix Companion Selection ID/Name Mismatch

**Recommended Model:** Gemini 3 Pro (needs careful code analysis across multiple locations)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix inconsistent companion selection logic in `lib/screens/wizard_steps/hero_creator_step.dart` that mixes IDs and names.

## Problem
The companion selection code uses `c.id` in some places and `c.name` in others when adding/removing companions from the selection list. This can cause state desync where a companion appears selected but isn't tracked, or vice versa.

## How to Find the Problem Areas
Search for ALL occurrences of `selectedCompanions` in the file. Also search for `companionNames`. You'll find patterns like:
- `selectedCompanions.contains(c.id)` — checking by ID (correct)
- `selectedCompanions.remove(c.name)` — removing by name (WRONG, should be ID)
- `selectedCompanions.add(c.name)` — adding by name (WRONG, should be ID)
- `companionNames.add(c.name)` — this is fine, companionNames is a display-name list
- `companionNames.remove(c.name)` — this is fine

## The Fix
Standardize ALL companion selection state to use IDs:
1. `selectedCompanions` should ONLY contain IDs (never names)
2. `companionNames` should ONLY contain display names
3. When checking: `selectedCompanions.contains(c.id)` — always use .id
4. When adding: `selectedCompanions.add(c.id)` AND `companionNames.add(c.name)`
5. When removing: `selectedCompanions.remove(c.id)` AND `companionNames.remove(c.name)`

For saved characters (friends), they have both an `id` and a `name`. Use the ID for selectedCompanions.
For pets, they may use a pet name or pet ID — standardize to whatever unique identifier is available.

## Process
1. Read the FULL file (it's large, ~5000 lines)
2. Find every `selectedCompanions.add(`, `selectedCompanions.remove(`, `selectedCompanions.contains(` call
3. For each one, verify whether it's using `.id` or `.name` or a raw string
4. Fix any that use `.name` or raw strings to use `.id` instead
5. Ensure the parallel `companionNames` list is still updated with display names

## Files to Change
- `lib/screens/wizard_steps/hero_creator_step.dart`

## Verification
- Search for `selectedCompanions.add(` — every call should pass an ID, not a name
- Search for `selectedCompanions.remove(` — every call should pass an ID, not a name
- Search for `selectedCompanions.contains(` — every call should check an ID, not a name
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/hero_creator_step.dart TEAM_COORDINATION.md
git commit -m "fix: standardize companion selection to use IDs consistently

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

### Task 1.6 — Fix emotion_recognition_game.dart Asset References

**Recommended Model:** GPT-5.4 (simple path fix or file removal)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix `lib/emotion_recognition_game.dart` which references a non-existent `assets/emotions/` directory.

## Problem
Around line 243, the file references `'assets/emotions/${emotion.id}.png'` but the `assets/emotions/` directory does not exist. The comment says "Placeholder path."

## Options (choose one based on what you find)

### Option A: If the file is actively used (imported by other files)
Change the asset path to use the existing feelings faces directory:
```dart
// OLD:
imagePath: 'assets/emotions/${emotion.id}.png',

// NEW:
imagePath: 'assets/feelings_faces/${emotion.id.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}.png',
```

### Option B: If the file is NOT imported anywhere
Search the entire `lib/` directory for `emotion_recognition_game` (the import). If no other file imports it, it's dead code. In that case:
1. Delete `lib/emotion_recognition_game.dart`
2. Remove any reference to it in route definitions or imports

To check: `grep -r "emotion_recognition_game" lib/`

## Files to Change
- `lib/emotion_recognition_game.dart` (fix or delete)

## Verification
- No references to `assets/emotions/` should remain in any Dart file
- `dart analyze` should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add -A
git commit -m "fix: resolve emotion_recognition_game placeholder asset references

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

## PHASE 2: Age-Band Text & Tone Calibration

---

### Task 2.1 — Make Primary CTAs Band-Configurable

**Recommended Model:** Gemini 3 Pro (touches theme data model + multiple widgets)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Add band-configurable CTA (call-to-action) labels to the age-band theme system and wire them into the wizard.

## Problem
"Make Magic!" and "Gather Party!" button text is hardcoded and feels juvenile for older age bands (Creator 12-14, Adolescent 15-17, Adult 18+).

## Step 1: Add fields to AgeBandThemeData
In `lib/theme/age_band_theme.dart`, add two new fields to the `AgeBandThemeData` class (after `feelingsPrompt` around line 90):
```dart
final String launchStoryLabel;   // "Make Magic!" button on review screen
final String companionCTALabel;  // "Gather Party!" button on companion screen
```

Add them to the constructor, the `copyWith()` method, and the `lerp()` method (following the same pattern as the other label fields).

## Step 2: Set values per band theme
Update each theme constant:

```
sproutTheme:     launchStoryLabel: 'Make Magic!',      companionCTALabel: 'Pick My Friends!'
explorerTheme:   launchStoryLabel: 'Make Magic!',      companionCTALabel: 'Gather Party!'
adventurerTheme: launchStoryLabel: 'Start Adventure!',  companionCTALabel: 'Assemble Party'
creatorTheme:    launchStoryLabel: 'Create Story',      companionCTALabel: 'Set the Cast'
adolescentTheme: launchStoryLabel: 'Start Writing',     companionCTALabel: 'Continue'
adultTheme:      launchStoryLabel: 'Begin',             companionCTALabel: 'Continue'
```

## Step 3: Wire into companion_selector_step.dart
In `lib/screens/wizard_steps/companion_selector_step.dart`:

Around line 489, replace the hardcoded 'Gather Party!' with:
```dart
final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
// ...
label: band.companionCTALabel,
```

Around line 500, replace 'Go Solo (Be Brave!)' with age-appropriate text:
```dart
Text(
  band.band.isMature ? 'Skip' : 'Go Solo (Be Brave!)',
  // ...
)
```

## Step 4: Wire into magic_review_step.dart
In `lib/screens/wizard_steps/magic_review_step.dart`, find the "Make Magic" button text. It may be rendered via the `ImageMakeMagicButton` widget or as text. Search for "Make Magic" in the file and replace with `band.launchStoryLabel`.

Also check `wizard_story_screen.dart` step labels (around line 295) — the last step label should match:
- Currently: 'Make Magic!' for default, 'Start Adventure' for adventurer, 'Create Story' for creator
- These should also use `band.launchStoryLabel` if possible, or at minimum stay consistent

## Files to Change
- `lib/theme/age_band_theme.dart` (add fields + values for all 6 bands)
- `lib/screens/wizard_steps/companion_selector_step.dart` (use band CTA labels)
- `lib/screens/wizard_steps/magic_review_step.dart` (use band launch label)
- `lib/screens/wizard_story_screen.dart` (optional: align step labels)

## Verification
- `dart analyze` on all changed files should pass
- Search for hardcoded "Gather Party" — should only appear in the theme definition, not in widgets
- Search for hardcoded "Make Magic" in magic_review_step.dart — should be replaced

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/theme/age_band_theme.dart lib/screens/wizard_steps/companion_selector_step.dart lib/screens/wizard_steps/magic_review_step.dart lib/screens/wizard_story_screen.dart TEAM_COORDINATION.md
git commit -m "feat: add band-configurable CTA labels (launchStoryLabel, companionCTALabel)

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

### Task 2.2 — Rewrite Creative Brief Labels

**Recommended Model:** GPT-5.4 (string replacements only)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Replace clinical/corporate labels in the Creative Brief (shown to ages 12+) with natural language.

## File
`lib/screens/wizard_steps/hero_creator_step.dart`

## Changes (search for these exact strings and replace)

1. Around line 2983, find `'CREATIVE BRIEF'` and replace with `'Build Your Story'`
2. Around line 2962, find `'INITIALIZE STORY GENERATION'` and replace with `'Create Story'`
3. Around line 3216, find `'PSYCHOLOGICAL VITALITY'` and replace with `'Energy Level'`
4. Around line 3223, find `'SOCIAL ARCHITECTURE'` and replace with `'Social Style'`
5. Search for any other ALL-CAPS labels in the Creative Brief section (lines 2870-3100) that sound clinical:
   - 'Identity & Archetype' -> 'Character & Role'
   - 'Psychological Profile' -> 'Personality'
   - 'Setting & Narrative Focus' -> 'World & Setting'
   - 'Technical Parameters' -> 'Story Options'

## Important
- Only change the label STRINGS, not the code structure
- Keep all the same styling (fonts, colors, spacing)
- These labels are only shown when `isTeen` is true (ages 12+)

## Verification
- Search for "PSYCHOLOGICAL VITALITY", "SOCIAL ARCHITECTURE", "INITIALIZE STORY GENERATION" — all should return zero results
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/hero_creator_step.dart TEAM_COORDINATION.md
git commit -m "fix: replace clinical Creative Brief labels with natural language for 12+

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 2.3 — Update Mature Archetype Names and Descriptions

**Recommended Model:** GPT-5.4 (string changes in data definitions)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix archetype names and descriptions that are shown to users aged 12+ via the `matureName` field.

## File
`lib/widgets/archetype_card.dart`

## Changes

### A. Fix "Senior Architect" mature name (line 282)
The artist archetype's `matureName` is 'Senior Architect' which sounds corporate. Change to:
```dart
matureName: 'Vision Architect',
```

### B. Add `matureDescription` field to ArchetypeData
Add a new optional field to the `ArchetypeData` class (around line 372):
```dart
final String? matureDescription;
```
Add it to the constructor (around line 384):
```dart
this.matureDescription,
```
Add a helper method after `nameForAge` (around line 393):
```dart
String descriptionForAge(int age) {
  if (age >= 12 && matureDescription != null) return matureDescription!;
  return description;
}
```

### C. Add mature descriptions to each archetype

```dart
// adventurer (Storm Rider -> Storm Vanguard)
matureDescription: 'Leads through chaos and thrives when the stakes are highest',

// thinker (Quiz Whiz -> Logic Architect)
matureDescription: 'Deconstructs complex problems and architects elegant solutions',

// artist (Master Creator -> Vision Architect)
matureDescription: 'Creates art that bleeds into reality — illustrations gain a life of their own',

// helper (Heart Healer -> Harmony Mediator)
matureDescription: 'Reads emotional undercurrents and mediates conflicts with empathy',

// athlete (Lightning Runner -> Kinetic Specialist)
matureDescription: 'Channels raw physical energy into precision movement and split-second decisions',

// shyOne (Animal Whisperer -> Ecological Whisperer)
matureDescription: 'Reads the language of ecosystems and hears what the living world doesn\'t say aloud',
```

### D. Fix Animal Whisperer bandImageId (line 344)
Change:
```dart
bandImageId: 'mighty_guardian',
```
To:
```dart
bandImageId: 'animal_whisperer',
```

### E. Wire matureDescription into display
Search the file for where `archetype.description` is displayed in the UI (likely in the ArchetypeCard widget or the detail banner). Replace with:
```dart
archetype.descriptionForAge(characterAge)
```
You'll need to ensure the character's age is available where the description is rendered. Check the widget's parameters.

## Files to Change
- `lib/widgets/archetype_card.dart`

## Verification
- Search for "Senior Architect" — should return zero results
- Search for "mighty_guardian" — should return zero results
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/widgets/archetype_card.dart TEAM_COORDINATION.md
git commit -m "fix: update mature archetype names/descriptions for ages 12+

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 2.4 — Fix Welcome Screen Text

**Recommended Model:** GPT-5.4 (simple string change)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix the welcome screen title that reads "Once Upon YOUR Child" which sounds like parent-facing marketing copy.

## File
`lib/screens/welcome_screen.dart`

## Current Code (around lines 229-255)
A RichText widget renders "Once Upon" + "YOUR" + " Child" in CinzelDecorative font.

## Fix
Change the text to a child-friendly welcome:
```dart
RichText(
  textAlign: TextAlign.center,
  text: TextSpan(
    children: [
      TextSpan(
        text: 'Once Upon\n',
        style: GoogleFonts.cinzelDecorative(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _goldColor,
          height: 1.3,
        ),
      ),
      TextSpan(
        text: 'a Time',
        style: GoogleFonts.cinzelDecorative(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    ],
  ),
),
```

This removes "YOUR Child" (parent-facing) and replaces with "a Time" (universally magical).

## Files to Change
- `lib/screens/welcome_screen.dart`

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/welcome_screen.dart TEAM_COORDINATION.md
git commit -m "fix: welcome screen title from 'Once Upon YOUR Child' to 'Once Upon a Time'

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 2.5 — Adapt Bedtime Mode Prompts Per Age Band

**Recommended Model:** Gemini 3 Pro (needs careful reasoning about band-specific text)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Make the bedtime wizard voice prompts age-band-aware instead of using identical child-focused prompts for all ages.

## File
`lib/screens/bedtime_wizard_screen.dart`

## Problem
The bedtime mode uses the same prompts for everyone. A 16-year-old hears "Hi! Let's make a magical bedtime story together!" and "Goodnight, sweet dreams." This is patronizing for older users.

## How to Fix

### A. Add a band-awareness helper
The file already has access to `widget.childAge`. Add a helper:
```dart
bool get _isMature => widget.childAge >= 12;
bool get _isYoung => widget.childAge <= 8;
```

### B. Adapt key voice prompts
Search for each prompt string and add age-conditional variants. The prompts are in `_advanceStep()` or similar step-handler methods. Key prompts to change:

1. **Greeting** (currently ~"Hi [name]! Let's make a magical bedtime story together. Just talk to me!"):
   - Young (<=8): Keep as-is
   - Mature (12+): "Hey [name]. Let's build your story. Just talk to me."

2. **Companion prompt** (currently ~"Who's coming with [hero]? A tiny dragon, a wise owl, a shadow cat, a star dog, or someone else?"):
   - Read companion names from the age-band-specific companion data if possible
   - For mature: "Who's joining [hero]? A storm hawk, shadow lynx, iron golem, void sprite, or someone else?"

3. **Mood prompt** (currently ~"What kind of story? A brave adventure, a funny story, a story about friendship, or a calming story?"):
   - Young: Keep as-is
   - Mature (12+): "What's the vibe? Brave, funny, friendship, or atmospheric?"

4. **Generating prompt** (currently ~"Making your story now. Close your eyes and imagine..."):
   - Young: Keep as-is
   - Mature (12+): "Writing your story now. Give it a moment..."

5. **Ending prompt** (currently ~"The end. Goodnight, [name]. Sweet dreams."):
   - Young: Keep as-is
   - Mature (12+): "That's the end. Rest well, [name]."

### C. Pattern for changes
For each prompt, use a ternary or if/else:
```dart
final greeting = _isMature
    ? 'Hey $childName. Let\'s build your story. Just talk to me.'
    : 'Hi $childName! Let\'s make a magical bedtime story together. Just talk to me!';
```

## Files to Change
- `lib/screens/bedtime_wizard_screen.dart`

## Verification
- A user aged 14 should hear "Hey [name]" not "Hi [name]!"
- A user aged 14 should hear "Rest well" not "Sweet dreams"
- A user aged 5 should still hear the original prompts unchanged
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/bedtime_wizard_screen.dart TEAM_COORDINATION.md
git commit -m "fix: adapt bedtime voice prompts per age band (mature vs young)

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

### Task 2.6 — Fix FeelingsGardenScreen Tab Labels for Mature Bands

**Recommended Model:** GPT-5.4 (string changes with age conditionals)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Make the feelings garden tab labels age-appropriate for older bands. Currently all ages 8+ see the same juvenile labels.

## File
`lib/screens/feelings_garden_screen.dart`

## Problem
The tab labels are hardcoded:
- Tab 1: "How Big Is My Feeling"
- Tab 2: "Feelings Explorer"
- Tab 3: "My Feelings Journal"

These are fine for ages 6-8 but too juvenile for ages 12+.

## Fix
Find where the tab labels are defined (search for "How Big" in the file). Replace with age-conditional labels:

```dart
String _tab1Label() {
  if (widget.childAge >= 15) return 'Landscape';
  if (widget.childAge >= 12) return 'Mood';
  if (widget.childAge >= 9) return 'Mood Check';
  return 'How Big Is My Feeling';
}

String _tab2Label() {
  if (widget.childAge >= 15) return 'Explore';
  if (widget.childAge >= 12) return 'Explore';
  if (widget.childAge >= 9) return 'Mood Explorer';
  return 'Feelings Explorer';
}

String _tab3Label() {
  if (widget.childAge >= 15) return 'Reflections';
  if (widget.childAge >= 12) return 'Journal';
  if (widget.childAge >= 9) return 'My Journal';
  return 'My Feelings Journal';
}
```

Then use `_tab1Label()`, `_tab2Label()`, `_tab3Label()` wherever the tab names are rendered (likely in a TabBar widget).

## Files to Change
- `lib/screens/feelings_garden_screen.dart`

## Verification
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/feelings_garden_screen.dart TEAM_COORDINATION.md
git commit -m "fix: age-appropriate feelings garden tab labels for mature bands

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 2.7 — Fork Coping Strategies by Age Band

**Recommended Model:** Gemini 3 Pro (data model change + content authoring)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Add mature coping strategies to the feelings data so adults don't see "Stomp like a dinosaur."

## File
`lib/feelings_wheel_data.dart`

## Problem
`FeelingDetail` has a single `coping` list used for all ages. Entries like "Stomp feet safely like a dinosaur then pause" are appropriate for ages 3-8 but not for 15+.

## Step 1: Add matureCoping field
Find the `FeelingDetail` class (around line 162):
```dart
class FeelingDetail {
  final String description;
  final List<String> coping;
  final String? emoji;
  final List<String>? matureCoping;  // ADD THIS

  const FeelingDetail({
    required this.description,
    required this.coping,
    this.emoji,
    this.matureCoping,  // ADD THIS
  });

  // ADD THIS HELPER
  List<String> copingForAge(int age) {
    if (age >= 12 && matureCoping != null) return matureCoping!;
    return coping;
  }
}
```

## Step 2: Add mature coping to each FeelingDetail entry
Search for all `FeelingDetail(` constructors in the file and add `matureCoping` lists. Here are the entries to update:

```dart
'Frustrated': const FeelingDetail(
  description: 'When things feel stuck or not going your way.',
  coping: [
    'Pause and take 3 slow breaths.',
    'Shake out your hands and stretch.',
    'Ask an adult to break the problem into small steps.',
  ],
  matureCoping: [
    'Step back and take a few slow breaths.',
    'Break the problem into smaller parts.',
    'Write down what\'s blocking you.',
  ],
  emoji: '😤',
),

'Worried': matureCoping: [
  'Practice box breathing (4 in, 4 hold, 4 out, 4 hold).',
  'Write down your worry and challenge it with evidence.',
  'Talk to someone you trust about what\'s on your mind.',
],

'Mad': matureCoping: [
  'Remove yourself from the situation for a few minutes.',
  'Use deep breathing to slow your heart rate.',
  'Journal about what triggered the anger.',
],

'Scared': matureCoping: [
  'Ground yourself: name 5 things you see, 4 you hear, 3 you feel.',
  'Remind yourself of times you\'ve faced fear before.',
  'Talk to someone you trust about what feels threatening.',
],

'Sad': matureCoping: [
  'Allow yourself to feel it — sadness is valid.',
  'Reach out to someone you trust.',
  'Do one small thing that usually brings you comfort.',
],

'Lonely': matureCoping: [
  'Reach out to one person, even with a simple message.',
  'Spend time in a shared space, even quietly.',
  'Remember that loneliness is temporary and common.',
],
```

For any FeelingDetail entry that doesn't have child-specific language in its coping list (i.e., the coping is already neutral), you can skip adding matureCoping.

## Step 3: Wire copingForAge into the UI
Search for where `.coping` is accessed on FeelingDetail objects throughout the codebase (especially in feelings_garden_screen.dart, feelings_corner_screen.dart, or similar). Replace `.coping` with `.copingForAge(childAge)` where the child's age is available.

Key files to check:
- `lib/screens/feelings_garden_screen.dart`
- `lib/screens/feelings_corner_screen.dart`
- `lib/widgets/feelings_cloud_picker.dart`

## Files to Change
- `lib/feelings_wheel_data.dart` (add field + data)
- Any widget that reads `.coping` from FeelingDetail

## Verification
- `dart analyze` on all changed files should pass
- Search for `.coping` on FeelingDetail — most should be replaced with `.copingForAge(age)`

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/feelings_wheel_data.dart lib/screens/ lib/widgets/ TEAM_COORDINATION.md
git commit -m "feat: add mature coping strategies for ages 12+ in feelings data

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

## PHASE 3: Visual Consistency & Asset Wiring

---

### Task 3.1 — Wire Per-Band Archetype Images

**Recommended Model:** Gemini 3 Pro (logic change in asset routing)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Wire per-band archetype images into the active flow. Currently only Sprout uses band-specific images.

## File
`lib/widgets/archetype_card.dart`

## Problem
The `imagePathForBand()` method (around line 395) only handles Sprout:
```dart
String? imagePathForBand(AgeBand band) {
  if (band == AgeBand.sprout && sproutImageId != null) {
    return 'assets/images/archetypes/sprout/$sproutImageId.jpg';
  }
  return imagePath; // Falls back to root framed PNG for ALL other bands
}
```

But per-band image directories exist with images:
- `assets/images/archetypes/explorer/` (brave_hero.jpg, clever_inventor.jpg, gentle_dreamer.jpg, kind_healer.jpg, mighty_guardian.jpg, speedy_explorer.jpg)
- `assets/images/archetypes/adventurer/` (same files)
- `assets/images/archetypes/creator/` (same files)
- `assets/images/archetypes/adolescent/` (same files)
- `assets/images/archetypes/adult/` (same files)

## Fix
Update `imagePathForBand()` to check for band-specific images:

```dart
String? imagePathForBand(AgeBand band) {
  if (band == AgeBand.sprout && sproutImageId != null) {
    return 'assets/images/archetypes/sprout/$sproutImageId.jpg';
  }
  if (bandImageId != null) {
    final bandName = band.name; // 'explorer', 'adventurer', etc.
    return 'assets/images/archetypes/$bandName/$bandImageId.jpg';
  }
  return imagePath;
}
```

IMPORTANT: Verify that `AgeBand.name` returns the lowercase enum name ('sprout', 'explorer', etc.) that matches the directory names. If it returns something different, use a switch statement or `.name.toLowerCase()`.

Also verify that the `bandImageId` values in each archetype actually match files in the directories. The Animal Whisperer's `bandImageId` was already fixed to 'animal_whisperer' in Task 2.3 — if that task hasn't been done yet, also change `bandImageId: 'mighty_guardian'` to `bandImageId: 'animal_whisperer'` on the shyOne archetype. Then verify that `animal_whisperer.jpg` exists in each band directory. If it doesn't (the files may be named `mighty_guardian.jpg`), rename the files.

## Files to Change
- `lib/widgets/archetype_card.dart`
- Possibly rename asset files if names don't match

## Verification
- For each band, `imagePathForBand(band)` should return a path under `assets/images/archetypes/{band}/`
- Verify the referenced files actually exist on disk
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/widgets/archetype_card.dart TEAM_COORDINATION.md
git commit -m "feat: wire per-band archetype images for all age bands

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

### Task 3.4 — Move Story Length Picker to Review Screen

**Recommended Model:** Gemini 3 Pro (widget move between screens, medium complexity)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Move the story length picker from the hero creator step to the magic review step, and make labels age-appropriate.

## Current Location
`lib/screens/wizard_steps/hero_creator_step.dart`, lines 1848-1887:
- Heading "How long should it be?" (hardcoded GoogleFonts.fredoka)
- Three `ImageCrystalFormation` widgets (Quick/Classic/Epic)
- Sets `data.storyLength` on tap

## Target Location
`lib/screens/wizard_steps/magic_review_step.dart`, replacing the current read-only `_SummaryRow` for story length (around lines 726-731).

## Steps

### A. Remove from hero_creator_step.dart
Delete the story length section (lines ~1848-1887): the "How long should it be?" heading and the Row of three ImageCrystalFormation widgets. Keep everything before and after intact.

### B. Add to magic_review_step.dart
Replace the `_SummaryRow` for story length (lines ~726-731) with an interactive inline picker. Use a simple `SegmentedButton` or Row of tappable chips:

```dart
// Replace the _SummaryRow with:
_StaggeredReveal(
  index: 1,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!band.band.isYoung) // Hide for Sprout
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LengthChip(
              label: _lengthLabelForBand('quick', band),
              isSelected: data.storyLength == 'quick',
              onTap: () => setState(() => data.storyLength = 'quick'),
              band: band,
            ),
            const SizedBox(width: 8),
            _LengthChip(
              label: _lengthLabelForBand('standard', band),
              isSelected: data.storyLength == 'standard',
              onTap: () => setState(() => data.storyLength = 'standard'),
              band: band,
            ),
            const SizedBox(width: 8),
            _LengthChip(
              label: _lengthLabelForBand('epic', band),
              isSelected: data.storyLength == 'epic',
              onTap: () => setState(() => data.storyLength = 'epic'),
              band: band,
            ),
          ],
        ),
    ],
  ),
),
```

### C. Create the _LengthChip widget
Add a small private widget in magic_review_step.dart:
```dart
class _LengthChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AgeBandThemeData band;

  const _LengthChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? band.accent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(band.buttonRadiusBase),
          border: Border.all(
            color: isSelected ? band.accent : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? band.accent : band.textOnDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: band.body(14),
          ),
        ),
      ),
    );
  }
}
```

### D. Add age-appropriate labels
```dart
String _lengthLabelForBand(String length, AgeBandThemeData band) {
  if (band.band.isMature) {
    switch (length) {
      case 'quick': return 'Short';
      case 'epic': return 'Long';
      default: return 'Medium';
    }
  }
  switch (length) {
    case 'quick': return 'Short tale';
    case 'epic': return 'Big adventure';
    default: return 'Story time';
  }
}
```

### E. For Sprout, hide and default
For Sprout band (`band.band == AgeBand.sprout`), don't show the length picker at all. The default 'standard' is fine. The `if (!band.band.isYoung)` guard handles this if `isYoung` returns true for Sprout. Check the `isYoung` extension — it should return true for Sprout and Explorer. If Explorer should see the picker, adjust the condition to `band.band != AgeBand.sprout`.

## Files to Change
- `lib/screens/wizard_steps/hero_creator_step.dart` (remove length section)
- `lib/screens/wizard_steps/magic_review_step.dart` (add interactive length picker)

## Verification
- The length picker should NOT appear in the hero creator step anymore
- It SHOULD appear on the magic review step as tappable chips
- Sprout should NOT see the picker
- Tapping a chip should change `data.storyLength`
- `dart analyze` on both files should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/hero_creator_step.dart lib/screens/wizard_steps/magic_review_step.dart TEAM_COORDINATION.md
git commit -m "feat: move story length picker to review step with age-appropriate labels

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

### Task 3.5 — Fix CinzelDecorative Font for Sprout

**Recommended Model:** GPT-5.4 (targeted find-and-replace)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Replace CinzelDecorative font usage for Sprout band with Nunito (the Sprout UI font).

## File
`lib/screens/wizard_steps/hero_creator_step.dart`

## Problem
CinzelDecorative is a highly ornamental serif font that's hard for pre-readers (ages 2-5) to parse. The code uses it for both Sprout AND Explorer bands via a `useDecorative` flag.

## Fix
Search for the `useDecorative` variable (around line 4835):
```dart
final bool useDecorative =
    band.band == AgeBand.sprout || band.band == AgeBand.explorer;
```

Change to only use decorative font for Explorer:
```dart
final bool useDecorative = band.band == AgeBand.explorer;
```

Then search for ALL uses of `useDecorative` in the file. For Sprout, the code should fall through to whatever the non-decorative path uses (likely the band's own font from `band.uiFontFamily`).

Also search for any direct `GoogleFonts.cinzelDecorative` calls that don't use the `useDecorative` flag and check if they apply to Sprout.

## Files to Change
- `lib/screens/wizard_steps/hero_creator_step.dart`

## Verification
- Search for `useDecorative` — the condition should NOT include `AgeBand.sprout`
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/hero_creator_step.dart TEAM_COORDINATION.md
git commit -m "fix: remove CinzelDecorative from Sprout band for legibility

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 3.6 — Fix Navigation Button Consistency for Mature Bands

**Recommended Model:** GPT-5.4 (simple conditional change)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Fix navigation buttons so ALL mature bands get icon-only nav, not just Creator.

## File
`lib/screens/wizard_story_screen.dart`

## Problem
Around lines 345-423, the navigation buttons use this condition:
```dart
if (band.band != AgeBand.creator)
  _LabeledNavButton(...)  // Labeled button
else
  IconButton(...)  // Icon-only button
```

This means only Creator gets icon-only buttons. Adolescent and Adult still get labeled child-style buttons.

## Fix
Change `band.band != AgeBand.creator` to `!band.band.isMature` wherever it controls labeled vs icon-only navigation:

```dart
if (!band.band.isMature)
  _LabeledNavButton(...)  // Labeled for young bands
else
  IconButton(...)  // Icon-only for mature bands
```

There are likely 2-3 occurrences of this pattern in the file (for the Feelings button, Heroes button, and Bedtime button). Fix ALL of them.

Also add tooltip to the IconButtons for first-time discoverability:
```dart
IconButton(
  tooltip: 'Feelings',  // ADD THIS
  icon: const Icon(Icons.favorite, color: Colors.white),
  onPressed: ...,
)
```

## Files to Change
- `lib/screens/wizard_story_screen.dart`

## Verification
- Search for `!= AgeBand.creator` — should return zero results for nav button conditions
- All mature bands (Creator, Adolescent, Adult) should get icon-only nav
- All young bands (Sprout, Explorer, Adventurer) should get labeled nav
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_story_screen.dart TEAM_COORDINATION.md
git commit -m "fix: icon-only nav for all mature bands, not just Creator

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

## PHASE 4: Structural Improvements

---

### Task 4.5 — Swap Emoji Slider Endpoints to Text Labels for Age 9+

**Recommended Model:** GPT-5.4 (simple threshold change)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Change the emoji slider endpoint threshold from age 11 to age 8, so ages 9+ see text labels instead of emoji.

## Files to Check
- `lib/screens/wizard_steps/feeling_selection_step.dart` (around line 149)
- `lib/screens/wizard_steps/hero_creator_step.dart` (search for `isYoung`)

## Problem
The current code sets `final isYoung = age <= 11;` which means 9-11 year olds still see emoji endpoints on personality sliders. Ages 9+ (Adventurer band) should see text labels.

## Fix
In ALL files where `isYoung` is defined for this purpose, change:
```dart
final isYoung = age <= 11;
```
To:
```dart
final isYoung = age <= 8;
```

Then verify that the text label path (the `else` branch when `!isYoung`) actually shows useful labels. If the non-emoji path shows nothing (blank), you'll need to add text labels. The emoji mappings are:
- energy: "Restful" to "Energetic"
- sociability: "Quiet" to "Social"
- creativity: "Practical" to "Creative"
- confidence: "Cautious" to "Bold"
- empathy: "Reserved" to "Caring"
- adventurousness: "Homebody" to "Explorer"

## Files to Change
- `lib/screens/wizard_steps/feeling_selection_step.dart`
- `lib/screens/wizard_steps/hero_creator_step.dart` (if it has the same pattern)

## Verification
- `dart analyze` on changed files should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/feeling_selection_step.dart lib/screens/wizard_steps/hero_creator_step.dart TEAM_COORDINATION.md
git commit -m "fix: show text slider labels for age 9+ instead of emoji endpoints

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

## PHASE 5: Cleanup & Polish

---

### Task 5.1 — Remove Dead Code

**Recommended Model:** GPT-5.4 (simple deletion)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Remove dead code from hero_creator_step.dart.

## File
`lib/screens/wizard_steps/hero_creator_step.dart`

## What to Remove

### A. _sproutHeroChoices (around line 50)
Find `const List<_SproutHeroChoice> _sproutHeroChoices = [` and delete the entire list definition including all its entries until the closing `];`.

### B. _explorerHeroChoices (around line 111)
Find `const List<_SproutHeroChoice> _explorerHeroChoices = [` (or similar) and delete the entire list.

### C. _SproutHeroChoice class
If the class `_SproutHeroChoice` is only used by the two deleted lists, delete it too. Search for `_SproutHeroChoice` in the file — if no other references exist after removing the lists, delete the class definition.

## Important
- Do NOT delete anything that IS referenced elsewhere
- After deleting, search for `_sproutHeroChoices` and `_explorerHeroChoices` — should return zero results
- `dart analyze` should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/hero_creator_step.dart TEAM_COORDINATION.md
git commit -m "chore: remove unused _sproutHeroChoices and _explorerHeroChoices dead code

Co-Authored-By: GPT-5.4 <noreply@openai.com>"
```
```

---

### Task 5.4 — Add Voice Input to "Imagine It" Field for Sprout

**Recommended Model:** Gemini 3 Pro (widget addition with speech_to_text integration)

**Prompt:**
```
You are working on the Story Weaver Flutter app at C:\dev\story-weaver-app.

## Task
Add a microphone button to the "Imagine It" free-text scenario input so Sprout-age children can dictate instead of type.

## File
`lib/screens/wizard_steps/feeling_selection_step.dart`

## Context
The "Imagine It" / "Safe Space" scenario has a free-text TextField where users describe a custom story world. For ages 2-5, typing is impossible without a parent. The bedtime wizard already uses `speech_to_text` for voice input — reuse that pattern.

## Steps

### A. Find the "Imagine It" text field
Search for "imagination" or "imagineBuild" or "safe_space" or "Let your imagination" in feeling_selection_step.dart. Find the TextField widget for custom scenario input.

### B. Add a microphone IconButton
Add a suffix icon to the TextField (or a button next to it):
```dart
suffixIcon: IconButton(
  icon: Icon(
    _isListening ? Icons.mic : Icons.mic_none,
    color: _isListening ? Colors.red : Colors.white70,
  ),
  onPressed: _toggleVoiceInput,
),
```

### C. Add speech_to_text logic
The package `speech_to_text` is already in pubspec.yaml (used by bedtime_wizard_screen.dart). Add similar logic:

```dart
import 'package:speech_to_text/speech_to_text.dart' as stt;

// In state class:
final stt.SpeechToText _speech = stt.SpeechToText();
bool _isListening = false;

Future<void> _toggleVoiceInput() async {
  if (_isListening) {
    _speech.stop();
    setState(() => _isListening = false);
    return;
  }
  final available = await _speech.initialize();
  if (available) {
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _customScenarioController.text = result.recognizedWords;
            _isListening = false;
          });
        }
      },
      listenFor: const Duration(seconds: 15),
    );
  }
}

@override
void dispose() {
  _speech.stop();
  super.dispose();
}
```

### D. Only show for young ages
Wrap the mic button in an age check:
```dart
suffixIcon: widget.wizardData.characterAge <= 8
    ? IconButton(
        icon: Icon(_isListening ? Icons.mic : Icons.mic_none, ...),
        onPressed: _toggleVoiceInput,
      )
    : null,
```

## Files to Change
- `lib/screens/wizard_steps/feeling_selection_step.dart`

## Verification
- The mic icon should appear on the "Imagine It" text field for ages 8 and under
- It should NOT appear for ages 9+
- `dart analyze` on the file should pass

## After completing, update TEAM_COORDINATION.md and commit:
```
git add lib/screens/wizard_steps/feeling_selection_step.dart TEAM_COORDINATION.md
git commit -m "feat: add voice input to 'Imagine It' field for young children

Co-Authored-By: Gemini 3 Pro <noreply@google.com>"
```
```

---

## Summary — Model Assignments

| Task | Model | Effort | Description |
|------|-------|--------|-------------|
| 1.1 BigFeelingsFlowScreen | Gemini 3 Pro | High | Theme isolation, add feelings, use images |
| 1.2 Limerick Laughs | GPT-5.4 | Low | Label string fix |
| 1.4 Bedtime Settings CTA | GPT-5.4 | Low | Navigation fix |
| 1.5 Companion ID/Name | Gemini 3 Pro | Medium | Code analysis + consistency fix |
| 1.6 Emotion Game Assets | GPT-5.4 | Low | Path fix or file removal |
| 2.1 Band CTA Labels | Gemini 3 Pro | Medium | Theme model + multi-widget wiring |
| 2.2 Creative Brief Labels | GPT-5.4 | Low | String replacements |
| 2.3 Archetype Descriptions | GPT-5.4 | Low-Medium | Data field + content |
| 2.4 Welcome Screen | GPT-5.4 | Low | String change |
| 2.5 Bedtime Prompts | Gemini 3 Pro | Medium | Band-aware prompt logic |
| 2.6 Feelings Tabs | GPT-5.4 | Low | Age-conditional labels |
| 2.7 Coping Strategies | Gemini 3 Pro | Medium | Data model + content authoring |
| 3.1 Archetype Images | Gemini 3 Pro | Medium | Asset routing logic |
| 3.4 Story Length Picker | Gemini 3 Pro | High | Widget move between screens |
| 3.5 CinzelDecorative | GPT-5.4 | Low | Threshold change |
| 3.6 Nav Buttons | GPT-5.4 | Low | Conditional fix |
| 4.5 Slider Thresholds | GPT-5.4 | Low | Threshold change |
| 5.1 Dead Code | GPT-5.4 | Low | Deletion |
| 5.4 Voice Input | Gemini 3 Pro | Medium | Speech-to-text integration |

**GPT-5.4 tasks (10 tasks, all low-medium effort):** 1.2, 1.4, 1.6, 2.2, 2.3, 2.4, 2.6, 3.5, 3.6, 4.5, 5.1
**Gemini 3 Pro tasks (8 tasks, medium-high effort):** 1.1, 1.5, 2.1, 2.5, 2.7, 3.1, 3.4, 5.4

**Note:** Task 1.3 (generate 12 missing feelings face PNG assets) requires an AI image generation tool or manual art creation, not a code model. Use Gemini image generation, DALL-E, or similar.
