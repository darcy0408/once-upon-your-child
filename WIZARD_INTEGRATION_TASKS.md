# 🪄 Wizard Integration Tasks

**Objective:** Connect the new magical wizard flow to the main app so users can access it.

**Estimated Time:** 30-45 minutes
**Difficulty:** Easy (mostly navigation routing)
**Agent:** Codex, Gemini, or Grok

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

### Task 5: Test Basic Navigation

**Run:** `flutter run -d chrome` (or your preferred device)

**Test Steps:**
1. ✅ App launches without errors
2. ✅ Can navigate to wizard from main screen
3. ✅ Wizard shows Step 1 (Hero Creator) with purple gradient
4. ✅ Can select an archetype
5. ✅ "Continue" button appears
6. ✅ Can navigate to Step 2
7. ✅ Can navigate to Step 3
8. ✅ Can navigate to Step 4
9. ✅ "Make Magic" button shows
10. ✅ Tapping "Make Magic" shows success message or closes wizard

**If you see errors:** Check the console for missing imports or typos.

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
- [ ] User can navigate to the wizard from the main app
- [ ] All 4 wizard steps are accessible
- [ ] Moon phase progress indicator shows correctly
- [ ] Can complete the wizard without crashes
- [ ] Tapping "Make Magic" does something (even if just a message)
- [ ] No console errors during navigation
- [ ] Code is committed to `feature/gui-redesign` branch

---

## 📝 Commit Message Template

When done, commit with:

```
feat: Wire up wizard to main app navigation

- Add navigation from main story screen to wizard
- Update button to launch WizardStoryScreen
- Test all 4 wizard steps accessible
- Wizard flows from Step 1 → Step 4 without errors

Next: API integration for story generation
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
