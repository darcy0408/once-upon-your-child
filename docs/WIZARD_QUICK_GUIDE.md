# 🧙‍♂️ Wizard Implementation - Quick Guide for Grok

**Branch:** `feature/wizard-story-creator` (create from `feature/gui-redesign`)
**Goal:** Fix "Make Magic" button to open 4-step wizard instead of requiring pre-existing character

## Current Bug
Clicking "Make Magic" with no character shows error "Please choose a character!" but doesn't help user create one.

## Solution
Create wizard flow: Hero Creator → Feeling Selection → Companion → Review & Launch

---

## 🎯 Implementation Steps

### Step 1: Branch Setup
```bash
git checkout feature/gui-redesign
git pull origin feature/gui-redesign --no-edit
git checkout -b feature/wizard-story-creator
```

### Step 2: Add Gradients to Theme (MODIFY EXISTING)

**File:** `lib/theme/app_theme.dart`
**Action:** Add this class after line 18 (after `AppSpacing`):

```dart
class AppGradients {
  static const LinearGradient magicalBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFF093FB), Color(0xFFF5576C)],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static const LinearGradient magicalCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF3E7FF)],
  );
}
```

Also add wizard colors to `AppColors` class:
```dart
static const wizardPurple = Color(0xFF764ba2);
static const wizardPink = Color(0xFFF093FB);
static const textLight = Color(0xFFFFFFFF);
static const textDark = Color(0xFF2C3E50);
```

### Step 3: Create Moon Progress Widget (NEW FILE)

**File:** `lib/widgets/moon_phase_progress.dart`

Shows 4 moon phases (🌑🌒🌓🌔) for progress. Create a widget that:
- Takes `currentStep` (0-3)
- Shows 4 moon emoji in a Row
- Highlights current step with white circle border
- Shows 🌕 for completed steps

### Step 4: Create Magic Button Widget (NEW FILE)

**File:** `lib/widgets/make_magic_button.dart`

Animated button with:
- Pulsing animation (scale 1.0 to 1.05)
- Purple gradient background
- `Icons.auto_awesome` icon
- `isLoading` parameter shows CircularProgressIndicator
- `onPressed` callback

### Step 5: Create Wizard Container (NEW FILE)

**File:** `lib/screens/wizard_story_screen.dart`

Main wizard with:
- `PageController` for 4 steps
- `WizardData` class to collect selections
- Top bar: back button, moon progress, close button
- PageView with 4 steps (no swipe)
- Magical gradient background

WizardData fields:
- Step 1: `selectedArchetypeId`, `characterName`, `characterAge`
- Step 2: `selectedScenario`, `selectedEmotionChips[]`
- Step 3: `selectedCompanion`
- Validation helpers: `isStep1Complete`, `isStep2Complete`, etc.

### Step 6: Create Hero Creator Step (NEW FILE)

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

Step 1 features:
- 6 archetype cards (Brave Explorer, Creative Dreamer, Wise Helper, Curious Scientist, Friendly Leader, Nature Lover)
- Each card: emoji, title, description
- Character name TextFormField (required)
- Next button (disabled until valid)

### Step 7: Create Feeling Selection Step (NEW FILE)

**File:** `lib/screens/wizard_steps/feeling_selection_step.dart`

Step 2 features:
- 6 scenario cards in 2-column grid (First Day of School, Making Friends, Trying Something New, etc.)
- Emotion chips (Happy, Nervous, Excited, Sad, Brave, Confused, Proud, Worried)
- Multi-select chips
- Next enabled when scenario OR emotions selected

### Step 8: Create Companion Selector Step (NEW FILE)

**File:** `lib/screens/wizard_steps/companion_selector_step.dart`

Step 3 features:
- 8 companion cards in 2-column grid
- Options: None, Loyal Dog, Mysterious Cat, Tiny Dragon, Wise Owl, Mischievous Fairy, Brave Horse, Playful Bunny
- Single selection
- Next enabled when selected

### Step 9: Create Review Step (NEW FILE)

**File:** `lib/screens/wizard_steps/magic_review_step.dart`

Step 4 features:
- Review cards showing all selections
- MakeMagicButton (from step 4)
- On button press: TODO comment for story generation, close wizard
- Shows "Complete all steps" message if not complete

### Step 10: Wire Up to Main Screen (MODIFY EXISTING)

**File:** `lib/main_story.dart`

Add import:
```dart
import 'screens/wizard_story_screen.dart';
```

Replace "Make Magic" button onPressed (around line 1098):
```dart
onPressed: (_gracePeriodStatus?.shouldShowHardLimit ?? false)
    ? null
    : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WizardStoryScreen(),
          ),
        );
      },
```

---

## 🧪 Quick Test (3 minutes)

1. `flutter run -d chrome`
2. Click "Make Magic" → wizard opens
3. Select archetype, enter name → Next
4. Select scenario → Next
5. Select companion → Next
6. Click "Make Magic" → closes wizard
7. Back button works on steps 2-4
8. X closes wizard on step 1

---

## 📝 Commit & Push

```bash
git add .
git commit -m "feat: Implement 4-step wizard story creator

- Add WizardStoryScreen with 4-step PageView
- Create hero creator, feeling selection, companion selector steps
- Add magic review step with launch button
- Wire wizard to Make Magic button
- Add magical gradients to theme"

git push origin feature/wizard-story-creator
```

---

## 💡 Design Notes

**Visual Style:**
- Purple gradient background (`AppGradients.magicalBackground`)
- White cards with subtle purple tint
- Selected items: purple border + checkmark
- All text white on gradient, dark on cards

**Validation:**
- Step 1: Name + archetype required
- Step 2: Scenario OR emotions required
- Step 3: Companion required
- Review: All steps complete

**Navigation:**
- PageController animates between steps
- Back arrow on steps 2-4 goes to previous
- X icon on step 1 closes wizard
- No swipe navigation (disable physics)

---

## 🔗 Full Details

For complete code examples, see:
`WIZARD_IMPLEMENTATION_PLAN.md` (in repo root, but very large)

Or reference existing character creation screen:
`lib/character_creation_screen_enhanced.dart`

---

That's it! Should take ~2 hours to implement all 8 files.
