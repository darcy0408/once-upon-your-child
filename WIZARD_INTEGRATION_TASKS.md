# 🪄 Wizard Integration Tasks

**Objective:** Connect the new magical wizard flow to the main app so users can access it.

**Estimated Time:** 30-45 minutes
**Difficulty:** Easy (mostly navigation routing)
**Agent:** Codex, Gemini, or Grok

---

## 🌿 IMPORTANT: Branch Setup

**YOU MUST BE ON THE `feature/gui-redesign` BRANCH!**

Before starting any tasks, run these commands:

```bash
git checkout feature/gui-redesign
git pull origin feature/gui-redesign
```

**Verify you're on the right branch:**
```bash
git branch --show-current
```

**Expected output:** `feature/gui-redesign`

If you see `main` or any other branch, **STOP** and checkout the correct branch first.

**Why?** All the wizard files only exist on the `feature/gui-redesign` branch. If you're on `main`, you won't have the necessary files.

---

## ✅ Prerequisites Check

Before starting, verify these files exist:
- [ ] `lib/screens/wizard_story_screen.dart`
- [ ] `lib/screens/wizard_steps/hero_creator_step.dart`
- [ ] `lib/screens/wizard_steps/feeling_selection_step.dart`
- [ ] `lib/screens/wizard_steps/companion_selector_step.dart`
- [ ] `lib/screens/wizard_steps/magic_review_step.dart`
- [ ] `lib/widgets/make_magic_button.dart`
- [ ] `lib/theme/app_theme.dart` (with purple theme)

All files should exist on branch `feature/gui-redesign`.

---

## 📋 Task List

### Task 1: Add Import to Main Story Screen

**File:** `lib/main_story.dart`

**Location:** Add to imports at the top (around line 1-50)

**Add this line:**
```dart
import 'screens/wizard_story_screen.dart';
```

**Why:** This allows the main story screen to navigate to the wizard.

---

### Task 2: Replace Quick Story Button

**File:** `lib/main_story.dart`

**Find:** The button/widget that currently navigates to quick story creation (likely labeled "Create Story" or "New Story")

**Current code will look something like:**
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => QuickStoryScreen() // or similar
    ));
  },
  child: Text('Create Story'),
)
```

**Replace with:**
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => const WizardStoryScreen()
    ));
  },
  child: Text('Create Story ✨'), // Optional: add sparkle emoji
)
```

**Alternative:** If you can't find the exact button, search the file for:
- "QuickStoryScreen"
- "Create Story"
- "Navigator.push"

---

### Task 3: Update Bottom Navigation (Optional)

**File:** `lib/main_story.dart`

**Find:** The bottom navigation bar code (look for `BottomNavigationBar` or similar)

**Optional Change:** Update the "Stories" tab icon or label to indicate the new magical experience:

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.auto_awesome), // Change from current icon
  label: 'Create', // or 'Magic'
)
```

**Why:** Visual hint that there's something new and magical.

---

### Task 4: Add Wizard to Settings Screen (Optional)

**File:** `lib/settings_screen.dart`

**Add:** A toggle or button to switch between old and new story creation flows

**Code to add:**
```dart
// In the settings screen widget
SwitchListTile(
  title: Text('Use New Wizard Flow'),
  subtitle: Text('Magical 4-step story creation'),
  value: _useNewWizard, // Add this state variable
  onChanged: (value) {
    setState(() => _useNewWizard = value);
    // Save to SharedPreferences
  },
)
```

**Why:** Allows users to switch back to old flow if needed (A/B testing).

---

### Task 5: Test Thoroughly

**Run:** `flutter run -d chrome` (or your preferred device)

**Complete Test Checklist:**

**Basic Navigation:**
1. ✅ App launches without errors (no red screen)
2. ✅ Can find and tap button to navigate to wizard from main screen
3. ✅ Wizard shows Step 1 (Hero Creator) with purple/lavender gradient background
4. ✅ Moon phase progress indicator shows at top (4 circles)
5. ✅ Character preview shows at top with sparkle circle

**Step 1: Hero Creator:**
6. ✅ Can see 6 archetype cards in horizontal scroll
7. ✅ Can tap an archetype card
8. ✅ Selected archetype has gold glow/border
9. ✅ Character emoji changes in preview
10. ✅ "Continue" button appears after selection
11. ✅ Tapping "Continue" advances to Step 2

**Step 2: Feeling Selection:**
12. ✅ Progress indicator shows Step 2 active (second circle glowing)
13. ✅ Can see scenario cards in horizontal scroll
14. ✅ Can select a scenario (gets gold border)
15. ✅ Can see emotion chips below scenarios
16. ✅ Can tap emotion chips (they get checkmarks)
17. ✅ Gear icon in top-right for parental settings
18. ✅ "Continue" button appears after selection
19. ✅ Tapping "Continue" advances to Step 3

**Step 3: Companion Selector:**
20. ✅ Progress indicator shows Step 3 active
21. ✅ Can see 6 companion cards in grid (2 columns)
22. ✅ Tapping companion makes it bounce
23. ✅ Greeting bubble appears briefly on tap
24. ✅ Selected companion has gold glow and checkmark
25. ✅ "Continue" button appears after selection
26. ✅ Tapping "Continue" advances to Step 4

**Step 4: Magic Review:**
27. ✅ Progress indicator shows Step 4 active (all circles filled)
28. ✅ Summary cards show all selections
29. ✅ Character preview shows at top
30. ✅ Big purple "Make Magic ✨" button shows
31. ✅ Button has pulse animation
32. ✅ Tapping "Make Magic" shows success message or navigates somewhere
33. ✅ No crashes or errors during any step

**Navigation:**
34. ✅ Can tap back arrow to go to previous step
35. ✅ Can tap close/X button on first step to exit wizard
36. ✅ After completing wizard, can navigate back to main screen

**Console Check:**
37. ✅ No red errors in console
38. ✅ No yellow warnings about missing imports
39. ✅ No "Navigator" errors
40. ✅ No "context" errors

**If you see errors:** Check the console for missing imports or typos. Review the Troubleshooting section below.

---

## 🔧 Troubleshooting

### Error: "Navigator operation requested with a context that does not include a Navigator"

**Fix:** Wrap the button in a `Builder` widget:
```dart
Builder(
  builder: (context) => ElevatedButton(
    onPressed: () {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const WizardStoryScreen()
      ));
    },
    child: Text('Create Story'),
  ),
)
```

### Error: "The method 'WizardStoryScreen' isn't defined"

**Fix:** Check that you added the import: `import 'screens/wizard_story_screen.dart';`

### Error: "AppColors is not defined"

**Fix:** Some files might need this import: `import '../theme/app_theme.dart';`

### Wizard shows but has blank screens

**Fix:** Check that all wizard step files are in the correct location:
- `lib/screens/wizard_steps/` (note the `/wizard_steps/` subfolder)

---

## 🎨 Optional Enhancements

### Add a "Preview Wizard" Button in Settings

Makes it easier to access during testing.

**File:** `lib/settings_screen.dart`

```dart
ListTile(
  leading: Icon(Icons.auto_awesome, color: AppColors.primary),
  title: Text('Preview New Wizard'),
  subtitle: Text('Test the magical story creation flow'),
  trailing: Icon(Icons.arrow_forward),
  onTap: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => const WizardStoryScreen()
    ));
  },
)
```

### Update App Theme Globally

To make the whole app use the new purple theme:

**File:** `lib/main.dart` or wherever `MaterialApp` is defined

**Find:** `theme: ThemeData(...)`

**Replace with:**
```dart
theme: AppTheme.light(),
```

**Add import:** `import 'theme/app_theme.dart';`

---

## 🔌 Next Steps (API Integration)

After navigation is working, the wizard needs to connect to the story generation API.

**File to modify:** `lib/screens/wizard_steps/magic_review_step.dart`

**Find:** The `_launchStoryCreation()` method (around line 20-40)

**Current code:**
```dart
// TODO: Integrate with actual story generation API
await Future.delayed(const Duration(seconds: 2)); // Simulate API call
```

**Replace with:** Actual API call using `ApiServiceManager` or your existing service.

**Example:**
```dart
final apiService = ApiServiceManager();
final story = await apiService.generateStory(
  character: widget.wizardData.characterName,
  scenario: widget.wizardData.selectedScenario,
  companion: widget.wizardData.selectedCompanion,
  // ... other parameters from wizardData.toJson()
);

// Navigate to story result screen
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => StoryResultScreen(story: story),
  ),
);
```

**Note:** This requires understanding the existing API service structure. Don't attempt this yet - focus on navigation first.

---

## ✅ Definition of Done

You're done when:
- [ ] **VERIFIED:** You're on `feature/gui-redesign` branch
- [ ] **ALL 40 TEST ITEMS PASS** (see Task 5 checklist above)
- [ ] User can navigate to the wizard from the main app
- [ ] All 4 wizard steps are accessible
- [ ] Moon phase progress indicator shows correctly
- [ ] Can complete the wizard without crashes
- [ ] Tapping "Make Magic" does something (even if just a message)
- [ ] No console errors during navigation
- [ ] Code is committed to `feature/gui-redesign` branch
- [ ] Changes are pushed to remote: `git push origin feature/gui-redesign`

---

## 🎯 Final Steps: Commit & Push

**ONLY DO THIS IF ALL TESTS PASS!**

If you have any failing tests, fix them first before committing.

### Step 1: Check Git Status

```bash
git status
```

You should see modified files like:
- `lib/main_story.dart` (or wherever you added navigation)
- Possibly `lib/settings_screen.dart` if you added optional features

### Step 2: Stage Your Changes

```bash
git add lib/main_story.dart
# Add any other files you modified
```

Or stage everything:
```bash
git add .
```

### Step 3: Commit with Descriptive Message

```bash
git commit -m "feat: Wire up wizard to main app navigation

- Add WizardStoryScreen import to main story screen
- Update story creation button to launch wizard
- Test all 4 wizard steps - navigation working
- All 40 test items pass successfully
- Moon phase progress indicator displays correctly
- Wizard flows from Step 1 → Step 4 without errors

Tested on: [chrome/Android/iOS - specify what you tested on]
Next: API integration for story generation"
```

### Step 4: Push to Remote

```bash
git push origin feature/gui-redesign
```

### Step 5: Verify Push Success

You should see output like:
```
To https://github.com/darcy0408/story-weaver-app.git
   7f6677b..xxxxxxx  feature/gui-redesign -> feature/gui-redesign
```

### Step 6: Final Verification

```bash
git log -1 --oneline
```

This shows your latest commit. Verify it says something like:
```
xxxxxxx feat: Wire up wizard to main app navigation
```

---

## 🎉 Success Criteria

You've successfully completed the integration when:

1. ✅ **All 40 tests pass**
2. ✅ **Code is committed** with descriptive message
3. ✅ **Changes are pushed** to remote
4. ✅ **You can demonstrate** the full wizard flow working
5. ✅ **No console errors** during operation

---

## 📊 Report Template

After completing, report back with this summary:

```
✅ Wizard Integration Complete

Branch: feature/gui-redesign
Tests Passed: [X/40]
Tested On: [chrome/Android/iOS]

Changes Made:
- File modified: lib/main_story.dart (added import, updated button)
- [Any other changes]

Commit Hash: [from git log]
Pushed: Yes ✓

Issues Encountered: [None / List any issues and how you solved them]

Ready For: API integration / Further testing / Merge to main
```

---

## 🆘 If You Get Stuck

**Don't spend more than 15 minutes stuck on one issue.**

Instead:
1. Document what you tried
2. Note the exact error message
3. Save your work
4. Ask Claude for help with the specific issue

**Remember:** Navigation is straightforward - if something seems complicated, you might be overthinking it!

---

**Good luck! The wizard is already built and beautiful - you just need to add the door to it! 🚪✨**
