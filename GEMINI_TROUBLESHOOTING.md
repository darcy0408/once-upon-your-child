# Gemini Troubleshooting Guide

## Common Errors and Solutions

### Error 404: "Requested entity was not found"

**Cause:** Gemini API configuration issue or model not available

**Solutions:**

1. **Check your Gemini API key:**
   ```bash
   echo $GEMINI_API_KEY  # Should show your API key
   ```

2. **Try a different model:**
   - If using `gemini-1.5-pro`, try `gemini-1.5-flash` instead
   - Some regions don't have access to all models

3. **Check API quota:**
   - Visit https://aistudio.google.com/app/apikey
   - Verify your API key is active and has quota remaining

4. **Regenerate your API key:**
   - Go to https://aistudio.google.com/app/apikey
   - Create a new API key
   - Update your environment variable

---

## Recommended Approach for Gemini Tasks

### Instead of Using Gemini CLI Directly

**Option 1: Just use your regular code editor**
- The tasks are fully documented with exact line numbers
- You don't need AI assistance - just follow the instructions manually
- Faster and more reliable

**Option 2: Use a different AI model**
- Claude via Anthropic API
- ChatGPT via OpenAI API
- Or any local LLM

**Option 3: Do it step-by-step yourself**
The GEMINI_CODEX_TASKS.md file has:
- Exact file paths
- Exact line numbers
- Code snippets to find and replace
- It's like a recipe - no AI needed!

---

## GEMINI TASK 1 - Manual Instructions (No AI Needed)

If Gemini keeps erroring, just do this yourself:

### Step 1: Edit `lib/interest_options.dart`

**Find lines 44-60** (the two separate lists):
```dart
const List<InterestOption> commonGoalOptions = [
  InterestOption('Make New Friends', Icons.group_add),
  InterestOption('Be Brave', Icons.shield_outlined),
  InterestOption('Try New Foods', Icons.restaurant),
  InterestOption('Sleep Alone', Icons.bedtime),
  InterestOption('Learn to Swim', Icons.pool),
  InterestOption('Share More', Icons.share),
];

const List<InterestOption> commonChallengeOptions = [
  InterestOption('Taking Turns', Icons.loop),
  InterestOption('New Routines', Icons.schedule),
  InterestOption('Being Patient', Icons.hourglass_bottom),
  InterestOption('Losing Games', Icons.videogame_asset),
  InterestOption('Going to School', Icons.school),
  InterestOption('Trying Again After Failing', Icons.restart_alt),
];
```

**Replace with this single list:**
```dart
// Combined goals and challenges - what the child is working on
const List<InterestOption> commonGoalOptions = [
  InterestOption('Make New Friends', Icons.group_add),
  InterestOption('Be Brave', Icons.shield_outlined),
  InterestOption('Try New Foods', Icons.restaurant),
  InterestOption('Sleep Alone', Icons.bedtime),
  InterestOption('Learn to Share', Icons.share),
  InterestOption('Taking Turns', Icons.loop),
  InterestOption('Be Patient', Icons.hourglass_bottom),
  InterestOption('Handle Losing Well', Icons.videogame_asset),
  InterestOption('New School/Routines', Icons.school),
  InterestOption('Keep Trying', Icons.restart_alt),
];

// Delete commonChallengeOptions entirely
```

### Step 2: Edit `lib/character_creation_screen_enhanced.dart`

**2a. Around line 71-72, change:**
```dart
final _goalsController = TextEditingController();
final _challengesController = TextEditingController();
```
**To:**
```dart
final _goalsChallengesController = TextEditingController(); // Combined
```

**2b. Around line 61-62, change:**
```dart
final Set<String> _selectedGoalOptions = <String>{};
String? _selectedChallengeOption;
```
**To:**
```dart
final Set<String> _selectedGoalChallengeOptions = <String>{}; // Combined
```

**2c. Around line 149-155, DELETE this entire method:**
```dart
String? _resolveChallengeValue() {
  if (_selectedChallengeOption != null) {
    return _selectedChallengeOption;
  }
  final text = _challengesController.text.trim();
  return text.isEmpty ? null : text;
}
```

**2d. Around line 296-297, change:**
```dart
'goals': _combinedGrowthSelections(_selectedGoalOptions, _goalsController),
if (challengeValue != null) 'challenge': challengeValue,
```
**To:**
```dart
'goals': _combinedGrowthSelections(_selectedGoalChallengeOptions, _goalsChallengesController),
```

**2e. Around line 360-361, change:**
```dart
_goalsController.dispose();
_challengesController.dispose();
```
**To:**
```dart
_goalsChallengesController.dispose();
```

**2f. Around lines 1073-1114, FIND this big block:**
```dart
const SizedBox(height: 20),
_buildInterestChipGroup(
  title: 'Goals or things they're working on',
  subtitle: 'Helps the story cheer them on',
  options: commonGoalOptions,
  selections: _selectedGoalOptions,
),
const SizedBox(height: 12),
TextFormField(
  controller: _goalsController,
  decoration: InputDecoration(
    labelText: 'Other goals',
    hintText: 'e.g., be braver at night',
    helperText: 'Separate with commas',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
    fillColor: Colors.amber[50],
    prefixIcon: const Icon(Icons.flag_outlined),
  ),
  maxLines: 2,
),
const SizedBox(height: 20),
_buildSingleChoiceChipGroup(
  title: 'Current challenge',
  subtitle: 'Pick the one that fits best',
  options: commonChallengeOptions,
  selectedValue: _selectedChallengeOption,
  onSelected: (value) {
    setState(() => _selectedChallengeOption = value);
  },
),
const SizedBox(height: 12),
TextFormField(
  controller: _challengesController,
  decoration: InputDecoration(
    labelText: 'Describe their current challenge',
    hintText: 'e.g., getting ready on time',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
    fillColor: Colors.pink[50],
    prefixIcon: const Icon(Icons.trending_up),
  ),
),
```

**REPLACE entire block with:**
```dart
const SizedBox(height: 20),
_buildInterestChipGroup(
  title: 'What they\'re working on (goals or challenges)',
  subtitle: 'Stories can help them grow and cheer them on',
  options: commonGoalOptions,
  selections: _selectedGoalChallengeOptions,
),
const SizedBox(height: 12),
TextFormField(
  controller: _goalsChallengesController,
  decoration: InputDecoration(
    labelText: 'Other goals or challenges',
    hintText: 'e.g., being braver, making new friends, learning to share',
    helperText: 'Separate with commas',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
    fillColor: Colors.amber[50],
    prefixIcon: const Icon(Icons.emoji_events),
  ),
  maxLines: 2,
),
```

### Step 3: Apply SAME changes to `lib/character_edit_screen.dart`

It has the same structure. Use your code editor's find/replace:

1. Find: `_goalsController` → Replace: `_goalsChallengesController`
2. Find: `_challengesController` → Replace: `_goalsChallengesController`
3. Find: `_selectedGoalOptions` → Replace: `_selectedGoalChallengeOptions`
4. Find: `_selectedChallengeOption` → Replace: (delete this variable)
5. Find: `commonChallengeOptions` → Replace: `commonGoalOptions`

### Step 4: Test the build

```bash
cd /mnt/c/dev/story-weaver-app
flutter pub get
flutter build web --release
```

If it builds successfully:
```bash
git checkout -b gemini/simplify-form
git add lib/character_creation_screen_enhanced.dart lib/character_edit_screen.dart lib/interest_options.dart
git commit -m "[Simplify] Merge goals and challenges into single section"
git push origin gemini/simplify-form
```

---

## Alternative: Skip Gemini Task Entirely

If Gemini keeps failing:
1. I (Claude) can do the task in ~10 minutes
2. Or you can do it manually following the instructions above
3. Or wait until Codex finishes their task and have them do it

The task isn't critical - it's just making the form shorter and easier to use.

---

## For Ubuntu/WSL Users

If working in Ubuntu, make sure:

```bash
# Navigate to the correct directory
cd /mnt/c/dev/story-weaver-app

# OR if you have a separate codex-dev directory:
cd /mnt/c/dev/story-weaver-app-codex-dev

# Make sure you're on main branch
git checkout main
git pull origin main

# Create your feature branch
git checkout -b gemini/simplify-form

# Make the changes above
# Then build and test
flutter pub get
flutter build web --release
```

---

## Debug Gemini API Issues

If you want to debug the Gemini API error:

```bash
# Test your API key
curl -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}' \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY"
```

Replace `YOUR_API_KEY` with your actual key.

If this works → Gemini CLI has a bug
If this fails → API key issue

---

**Bottom line:** Don't waste time debugging Gemini errors. Just edit the files manually following the instructions above. It's faster!
