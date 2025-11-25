# Story Weaver - UX Implementation Plan
## Comprehensive 4-Week Improvement Roadmap

**Created:** 2025-11-24
**Status:** Ready for Implementation
**Based on:** Feedback from Grok, Codex, Gemini + User preferences

---

## 📊 Success Metrics (Target Improvements)

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Onboarding Completion | ~30% | 70%+ | Firebase Analytics |
| Story Abandon Rate (during generation) | ~40% | <10% | Backend logs |
| Free-to-Paid Conversion | ~2% | 8%+ | Stripe dashboard |
| User Satisfaction (App Store) | 3.2/5 | 4.5/5 | Reviews |
| Character Creation Completion | ~50% | 85%+ | Analytics |
| Interactive Story Engagement | Unknown | Track baseline | Analytics |

---

# Week 1: Critical UX Fixes (HIGH PRIORITY)

## Task 1.1: Remove Feelings Check-In Pop-Up ⭐ USER'S #1 REQUEST

**User Pain Point:**
"I personally think the feelings check in pop up is really annoying. I would like the feelings wheel somewhere in the app but not there."

**Current Behavior:**
- Modal/dialog appears on app launch or navigation
- Blocks users from accessing main features
- Feels forced and interrupts flow

**New Behavior:**
- Remove all blocking modals for feelings check-in
- Create dedicated "Feelings Corner" screen accessible from bottom navigation
- Optional, user-initiated emotional check-ins
- Available anytime but never forced

### Implementation:

**Files to Change:**
- `lib/main.dart` (REMOVE feelings modal logic)
- `lib/screens/feelings_corner_screen.dart` (CREATE NEW)
- `lib/widgets/bottom_navigation.dart` (UPDATE - add 4th tab)

**Step 1: Remove Modal from main.dart**

```dart
// lib/main.dart
// FIND AND REMOVE:
// - Any showDialog() calls for feelings check-in
// - Any ModalRoute checks for feelings
// - Any Navigator.push() to feelings modal

// Example of what to remove:
void _showFeelingsCheckIn() {  // DELETE THIS ENTIRE METHOD
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => FeelingsCheckInDialog(),
  );
}
```

**Step 2: Create Feelings Corner Screen**

```dart
// lib/screens/feelings_corner_screen.dart (NEW FILE)
import 'package:flutter/material.dart';
import 'package:story_weaver/widgets/feelings_wheel.dart';
import 'package:story_weaver/services/analytics_service.dart';

class FeelingsCornerScreen extends StatefulWidget {
  const FeelingsCornerScreen({Key? key}) : super(key: key);

  @override
  State<FeelingsCornerScreen> createState() => _FeelingsCornerScreenState();
}

class _FeelingsCornerScreenState extends State<FeelingsCornerScreen> {
  String? selectedEmotion;
  int? intensity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How Are You Feeling?'),
        backgroundColor: Colors.purple[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Text(
              'Welcome to Your Feelings Corner',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This is a safe space to check in with your emotions. Take your time!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Feelings Wheel
            FeelingsWheel(
              onEmotionSelected: (emotion, level) {
                setState(() {
                  selectedEmotion = emotion;
                  intensity = level;
                });

                // Track usage (non-blocking analytics)
                AnalyticsService.logEvent('feelings_check_in', {
                  'emotion': emotion,
                  'intensity': level,
                  'voluntary': true,
                });
              },
            ),

            const SizedBox(height: 24),

            // Optional: Story suggestion based on emotion
            if (selectedEmotion != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Story Suggestion',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getStorySuggestion(selectedEmotion!, intensity!),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to story creation with pre-filled emotion
                          Navigator.pushNamed(
                            context,
                            '/create-story',
                            arguments: {
                              'current_feeling': {
                                'emotion': selectedEmotion,
                                'intensity': intensity,
                              },
                            },
                          );
                        },
                        child: const Text('Create Story About This Feeling'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Feelings history (optional)
            Text(
              'Your Recent Check-Ins',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // TODO: Show last 5 check-ins from local storage
            Text(
              'Check in regularly to track your emotional journey!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStorySuggestion(String emotion, int intensity) {
    // Map emotions to therapeutic story prompts
    final suggestions = {
      'happy': 'Let\'s create a joyful adventure story to celebrate your mood!',
      'sad': 'A gentle story about finding comfort might help right now.',
      'angry': 'How about a story where someone learns to express big feelings safely?',
      'nervous': 'Let\'s create a story about bravery and trying new things.',
      'excited': 'Your energy is perfect for an action-packed adventure!',
      'scared': 'A story about facing fears with courage could be helpful.',
    };
    return suggestions[emotion.toLowerCase()] ?? 'Let\'s create a story that speaks to your heart!';
  }
}
```

**Step 3: Update Bottom Navigation**

```dart
// lib/widgets/bottom_navigation.dart or wherever navigation is defined
// UPDATE to include 4 tabs:

BottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (index) {
    setState(() => _selectedIndex = index);
    _navigateToScreen(index);
  },
  type: BottomNavigationBarType.fixed,
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.create),
      label: 'Create',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.library_books),
      label: 'Library',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.favorite),
      label: 'Feelings',  // NEW TAB
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ],
)

void _navigateToScreen(int index) {
  switch (index) {
    case 0:
      Navigator.pushNamed(context, '/create-story');
      break;
    case 1:
      Navigator.pushNamed(context, '/library');
      break;
    case 2:
      Navigator.pushNamed(context, '/feelings-corner');  // NEW
      break;
    case 3:
      Navigator.pushNamed(context, '/settings');
      break;
  }
}
```

**Testing Checklist:**
- [ ] No feelings modal appears on app launch
- [ ] Feelings Corner accessible from bottom navigation
- [ ] Feelings wheel works correctly
- [ ] Story suggestion appears after emotion selection
- [ ] Navigation to story creation with pre-filled emotion works
- [ ] Analytics tracking fires correctly
- [ ] Screen is visually appealing and calming

---

## Task 1.2: Quick-Start Onboarding Wizard

**User Pain Point:**
"Onboarding wizard drops users before they generate their first story."

**Current Behavior:**
- 7+ steps to create first story
- Character creation feels mandatory and overwhelming
- Users abandon before seeing value

**New Behavior:**
- 3-step wizard: Name/Age → Theme → Generate
- First story generated in <60 seconds
- Character creation optional (move to advanced)

### Implementation:

**Files to Create:**
- `lib/screens/quick_start_wizard.dart` (NEW)

**Files to Update:**
- `lib/main.dart` (show wizard on first launch)
- `lib/screens/home_screen.dart` (add "Quick Story" button)

```dart
// lib/screens/quick_start_wizard.dart (NEW FILE)
import 'package:flutter/material.dart';
import 'package:story_weaver/services/story_service.dart';
import 'package:story_weaver/services/analytics_service.dart';

class QuickStartWizard extends StatefulWidget {
  const QuickStartWizard({Key? key}) : super(key: key);

  @override
  State<QuickStartWizard> createState() => _QuickStartWizardState();
}

class _QuickStartWizardState extends State<QuickStartWizard> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Name & Age
  String characterName = '';
  int characterAge = 7;

  // Step 2: Theme
  String selectedTheme = 'Adventure';

  // Step 3: Generate (no input needed)
  bool _showAdvancedOptions = false;
  String? companion;

  final List<Map<String, dynamic>> _themes = [
    {'name': 'Adventure', 'icon': Icons.explore, 'color': Colors.orange},
    {'name': 'Magic', 'icon': Icons.auto_fix_high, 'color': Colors.purple},
    {'name': 'Friendship', 'icon': Icons.favorite, 'color': Colors.pink},
    {'name': 'Nature', 'icon': Icons.nature, 'color': Colors.green},
    {'name': 'Mystery', 'icon': Icons.search, 'color': Colors.blue},
    {'name': 'Space', 'icon': Icons.rocket_launch, 'color': Colors.indigo},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your First Story'),
        backgroundColor: Colors.purple[100],
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    _currentStep == 2 ? 'Generate Story! 🚀' : 'Next',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // Step 1: Name & Age
          Step(
            title: const Text('About You'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell us a little about yourself!',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Character Name',
                      hintText: 'e.g., Luna, Max, Emma',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                    onChanged: (value) => characterName = value,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Age: $characterAge',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: characterAge.toDouble(),
                    min: 3,
                    max: 12,
                    divisions: 9,
                    label: characterAge.toString(),
                    onChanged: (value) {
                      setState(() => characterAge = value.toInt());
                    },
                  ),
                ],
              ),
            ),
          ),

          // Step 2: Theme
          Step(
            title: const Text('Pick a Theme'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What kind of story would you like?',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _themes.length,
                  itemBuilder: (context, index) {
                    final theme = _themes[index];
                    final isSelected = selectedTheme == theme['name'];
                    return InkWell(
                      onTap: () => setState(() => selectedTheme = theme['name']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? theme['color'] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? theme['color'] : Colors.grey,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              theme['icon'],
                              size: 36,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              theme['name'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Step 3: Ready to Generate
          Step(
            title: const Text('Ready to Create!'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your story is ready to generate!',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.purple[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryRow('Character', characterName),
                        _summaryRow('Age', '$characterAge years old'),
                        _summaryRow('Theme', selectedTheme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Advanced options (collapsible)
                ExpansionTile(
                  title: const Text('Advanced Options (Optional)'),
                  initiallyExpanded: false,
                  onExpansionChanged: (expanded) {
                    setState(() => _showAdvancedOptions = expanded);
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Companion Character (Optional)',
                              hintText: 'e.g., magical fox, talking teddy bear',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => companion = value,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Want more control? Create a full character profile in Settings!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
        AnalyticsService.logEvent('wizard_step_1_complete');
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep++);
      AnalyticsService.logEvent('wizard_step_2_complete', {
        'theme': selectedTheme,
      });
    } else if (_currentStep == 2) {
      _generateStory();
    }
  }

  void _generateStory() async {
    AnalyticsService.logEvent('wizard_generate_story', {
      'character': characterName,
      'age': characterAge,
      'theme': selectedTheme,
      'has_companion': companion?.isNotEmpty ?? false,
    });

    // Navigate to story generation screen with parameters
    Navigator.pushReplacementNamed(
      context,
      '/generate-story',
      arguments: {
        'character': characterName,
        'character_age': characterAge,
        'theme': selectedTheme,
        'companion': companion,
        'from_wizard': true,
      },
    );
  }
}
```

**Testing Checklist:**
- [ ] Wizard appears on first app launch
- [ ] All 3 steps work correctly
- [ ] Form validation prevents empty names
- [ ] Age slider works (3-12)
- [ ] Theme cards are visually appealing and selectable
- [ ] Advanced options collapse/expand
- [ ] "Generate Story" button navigates to story generation
- [ ] Analytics events fire correctly
- [ ] Wizard completion time < 60 seconds

---

## Task 1.3: Phase-Based Progress Indicator

**User Pain Point:**
"29-second wait with spinning circle feels broken. Users think app crashed."

**Current Behavior:**
- Generic loading spinner
- No indication of progress
- Users abandon after 10-15 seconds

**New Behavior:**
- 4 phases shown sequentially with progress bar
- Fun facts appear every 5 seconds
- Countdown timer shows estimated time remaining
- Cancel button available

### Implementation:

**Files to Update:**
- `lib/screens/story_generation_screen.dart`

```dart
// lib/screens/story_generation_screen.dart (UPDATE)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:story_weaver/services/story_service.dart';

class StoryGenerationScreen extends StatefulWidget {
  final Map<String, dynamic> storyParams;

  const StoryGenerationScreen({Key? key, required this.storyParams}) : super(key: key);

  @override
  State<StoryGenerationScreen> createState() => _StoryGenerationScreenState();
}

class _StoryGenerationScreenState extends State<StoryGenerationScreen> {
  int _currentPhase = 0;
  double _progress = 0.0;
  int _secondsElapsed = 0;
  int _estimatedTotalSeconds = 30;
  int _funFactIndex = 0;
  Timer? _progressTimer;
  Timer? _funFactTimer;
  bool _isCancelled = false;

  final List<Map<String, dynamic>> _phases = [
    {
      'title': 'Creating your personalized story...',
      'icon': Icons.edit_note,
      'color': Colors.blue,
      'progress': 0.4, // 0-40%
      'duration': 12, // seconds
    },
    {
      'title': 'Adding therapeutic elements...',
      'icon': Icons.favorite,
      'color': Colors.pink,
      'progress': 0.7, // 40-70%
      'duration': 8,
    },
    {
      'title': 'Generating illustrations...',
      'icon': Icons.palette,
      'color': Colors.purple,
      'progress': 0.95, // 70-95%
      'duration': 8,
    },
    {
      'title': 'Adding final touches...',
      'icon': Icons.auto_fix_high,
      'color': Colors.orange,
      'progress': 1.0, // 95-100%
      'duration': 2,
    },
  ];

  final List<String> _funFacts = [
    'Did you know? Stories help children process emotions!',
    'Fun fact: Reading together builds stronger bonds!',
    'The best stories reflect a child\'s unique personality.',
    'Therapeutic stories can reduce anxiety by 30%.',
    'Children who hear personalized stories show increased empathy.',
    'Stories with choices help develop decision-making skills!',
  ];

  @override
  void initState() {
    super.initState();
    _startGeneration();
    _startProgressTimer();
    _startFunFactRotation();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _funFactTimer?.cancel();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsElapsed++;

        // Update phase and progress based on elapsed time
        int totalDuration = 0;
        for (int i = 0; i < _phases.length; i++) {
          totalDuration += _phases[i]['duration'] as int;
          if (_secondsElapsed < totalDuration) {
            _currentPhase = i;

            // Calculate progress within phase
            int phaseStart = totalDuration - (_phases[i]['duration'] as int);
            int phaseElapsed = _secondsElapsed - phaseStart;
            double phaseDuration = (_phases[i]['duration'] as int).toDouble();
            double phaseProgress = phaseElapsed / phaseDuration;

            // Calculate overall progress
            double prevProgress = i > 0 ? _phases[i - 1]['progress'] : 0.0;
            double currentProgress = _phases[i]['progress'];
            _progress = prevProgress + (currentProgress - prevProgress) * phaseProgress;
            break;
          }
        }
      });
    });
  }

  void _startFunFactRotation() {
    _funFactTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }
      setState(() {
        _funFactIndex = (_funFactIndex + 1) % _funFacts.length;
      });
    });
  }

  void _startGeneration() async {
    try {
      final story = await StoryService.generateStory(widget.storyParams);

      if (_isCancelled) return;

      _progressTimer?.cancel();
      _funFactTimer?.cancel();

      // Navigate to story result screen
      Navigator.pushReplacementNamed(
        context,
        '/story-result',
        arguments: story,
      );
    } catch (e) {
      if (_isCancelled) return;

      _progressTimer?.cancel();
      _funFactTimer?.cancel();

      // Show error
      _showErrorDialog(e.toString());
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Story?'),
        content: const Text('Are you sure you want to stop creating this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Creating'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isCancelled = true);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Story'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oops!'),
        content: Text(
          'Something went wrong while creating your story.\n\n'
          'Please try again in a moment.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPhase = _phases[_currentPhase];
    final timeRemaining = _estimatedTotalSeconds - _secondsElapsed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creating Your Story'),
        backgroundColor: Colors.purple[100],
        automaticallyImplyLeading: false, // No back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                currentPhase['icon'],
                key: ValueKey(_currentPhase),
                size: 80,
                color: currentPhase['color'],
              ),
            ),

            const SizedBox(height: 24),

            // Phase title
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentPhase['title'],
                key: ValueKey(_currentPhase),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            // Progress bar
            LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(currentPhase['color']),
            ),

            const SizedBox(height: 16),

            // Progress percentage and time remaining
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_progress * 100).toInt()}% complete',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '~${timeRemaining}s remaining',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Fun fact (rotating)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey(_funFactIndex),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _funFacts[_funFactIndex],
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Cancel button
            TextButton.icon(
              onPressed: _showCancelConfirmation,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Testing Checklist:**
- [ ] Progress bar smoothly fills from 0% to 100%
- [ ] Phases transition correctly (4 phases)
- [ ] Icons and colors change per phase
- [ ] Fun facts rotate every 5 seconds
- [ ] Countdown timer shows accurate remaining time
- [ ] Cancel button shows confirmation dialog
- [ ] Story generation completes successfully
- [ ] Error handling shows user-friendly message
- [ ] No crashes if generation takes longer than expected

---

## Task 1.4: Clear Illustration Messaging

**User Pain Point:**
"Redundant illustration button appears even when auto-enabled. Users confused about why illustrations appear/don't appear."

**Current Behavior:**
- Button says "Generate Illustrations" even when already generated
- No explanation of tier-based logic
- Users don't understand free tier limitations

**New Behavior:**
- Tier-based messaging before generation
- Clear explanation after generation
- No redundant button if already auto-generated

### Implementation:

**Files to Create:**
- `lib/widgets/illustration_controls.dart` (NEW)

**Files to Update:**
- `lib/screens/story_result_screen.dart`

```dart
// lib/widgets/illustration_controls.dart (NEW FILE)
import 'package:flutter/material.dart';

class IllustrationControls extends StatelessWidget {
  final String subscriptionTier; // 'free', 'premium', 'family'
  final bool isLearningToReadMode;
  final bool hasUserApiKey;
  final int currentIllustrationCount;
  final VoidCallback? onGenerateMore;
  final VoidCallback? onUpgrade;

  const IllustrationControls({
    Key? key,
    required this.subscriptionTier,
    required this.isLearningToReadMode,
    required this.hasUserApiKey,
    required this.currentIllustrationCount,
    this.onGenerateMore,
    this.onUpgrade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine what to show based on tier and current state
    final shouldShowAutoMessage = _shouldShowAutoMessage();
    final shouldShowUpgrade = _shouldShowUpgrade();
    final shouldShowGenerateButton = _shouldShowGenerateButton();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shouldShowAutoMessage) _buildAutoMessage(context),
        if (shouldShowUpgrade) _buildUpgradePrompt(context),
        if (shouldShowGenerateButton) _buildGenerateButton(context),
      ],
    );
  }

  bool _shouldShowAutoMessage() {
    // Show explanation of why illustrations appeared automatically
    if (subscriptionTier == 'family' && currentIllustrationCount >= 2) return true;
    if (subscriptionTier == 'premium' && currentIllustrationCount >= 1) return true;
    if (isLearningToReadMode && currentIllustrationCount >= 1) return true;
    return false;
  }

  bool _shouldShowUpgrade() {
    // Show upgrade prompt for free tier (unless learning-to-read mode or BYOK)
    return subscriptionTier == 'free' &&
           !isLearningToReadMode &&
           !hasUserApiKey &&
           currentIllustrationCount == 0;
  }

  bool _shouldShowGenerateButton() {
    // Show generate button only if:
    // - Family tier and less than 2 illustrations
    // - Premium tier and less than 1 illustration
    // - Free tier with BYOK
    if (subscriptionTier == 'family' && currentIllustrationCount < 2) return true;
    if (subscriptionTier == 'premium' && currentIllustrationCount < 1) return true;
    if (subscriptionTier == 'free' && hasUserApiKey) return true;
    return false;
  }

  Widget _buildAutoMessage(BuildContext context) {
    String message;
    IconData icon;
    Color color;

    if (subscriptionTier == 'family') {
      message = '✓ 2 illustrations included automatically with Family plan!';
      icon = Icons.family_restroom;
      color = Colors.purple;
    } else if (subscriptionTier == 'premium') {
      message = '✓ 1 illustration included automatically with Premium plan!';
      icon = Icons.star;
      color = Colors.amber;
    } else {
      message = '✓ 1 free illustration for learning-to-read mode!';
      icon = Icons.school;
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[100]!, Colors.pink[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Want automatic illustrations?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade to Premium for 1 illustration per story, or Family for 2 illustrations!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _upgradeButton(context, 'Premium - \$9.99/mo', 'premium'),
              const SizedBox(width: 12),
              _upgradeButton(context, 'Family - \$14.99/mo', 'family'),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              // Navigate to BYOK setup
              Navigator.pushNamed(context, '/settings/api-key');
            },
            icon: const Icon(Icons.key, size: 16),
            label: const Text('Or bring your own Gemini API key'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.purple,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upgradeButton(BuildContext context, String label, String tier) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => onUpgrade?.call(),
        style: ElevatedButton.styleFrom(
          backgroundColor: tier == 'family' ? Colors.purple : Colors.amber,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGenerateButton(BuildContext context) {
    String label;
    if (subscriptionTier == 'family' && currentIllustrationCount == 1) {
      label = 'Generate 2nd Illustration';
    } else if (subscriptionTier == 'premium' && currentIllustrationCount == 0) {
      label = 'Generate Illustration';
    } else {
      label = 'Generate Illustration';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ElevatedButton.icon(
        onPressed: onGenerateMore,
        icon: const Icon(Icons.palette),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
```

**Usage in story_result_screen.dart:**

```dart
// lib/screens/story_result_screen.dart (ADD THIS)
import 'package:story_weaver/widgets/illustration_controls.dart';

// Inside build method, after story text:
IllustrationControls(
  subscriptionTier: _userSubscriptionTier, // Get from subscription service
  isLearningToReadMode: _story.isLearningToReadMode,
  hasUserApiKey: _hasUserApiKey, // Check from settings
  currentIllustrationCount: _story.illustrations.length,
  onGenerateMore: () async {
    // Show loading
    setState(() => _isGeneratingIllustration = true);

    try {
      final newIllustrations = await StoryService.generateIllustrations(
        storyId: _story.id,
        count: 1,
      );

      setState(() {
        _story.illustrations.addAll(newIllustrations);
        _isGeneratingIllustration = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Illustration generated! 🎨')),
      );
    } catch (e) {
      setState(() => _isGeneratingIllustration = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate illustration. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  onUpgrade: () {
    Navigator.pushNamed(context, '/subscription-plans');
  },
),
```

**Testing Checklist:**
- [ ] FREE + regular story: Shows upgrade prompt
- [ ] FREE + learning-to-read: Shows "1 free illustration" message
- [ ] PREMIUM: Shows "1 illustration included" message
- [ ] FAMILY: Shows "2 illustrations included" message
- [ ] BYOK users see generate button even on free tier
- [ ] No redundant "Generate" button when already at tier limit
- [ ] Upgrade buttons navigate to subscription screen
- [ ] BYOK setup button navigates to API key settings
- [ ] Generate more button works correctly

---

## Task 1.5: Free Tier Grace Period

**User Pain Point:**
"Paywall appears at story #3 before users experience value."

**Current Behavior:**
- Free tier: 5 stories per month (hard limit)
- Paywall appears immediately at story #6
- Users haven't experienced enough value to convert

**New Behavior:**
- First 3 days: Unlimited stories (grace period)
- Days 4-7: Soft prompts ("You've used 16/20 stories this month")
- Day 8+: Hard limit with tier comparison table

### Implementation:

**Files to Update:**
- `lib/services/subscription_service.dart`
- `lib/dialogs/upgrade_prompt_dialog.dart` (CREATE NEW)
- `lib/screens/story_creation_screen.dart`

```dart
// lib/services/subscription_service.dart (ADD METHODS)
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String _accountCreatedKey = 'account_created_at';
  static const String _storiesThisMonthKey = 'stories_this_month';
  static const String _lastResetKey = 'last_story_reset';

  // Get user's account age in days
  static Future<int> getAccountAgeDays() async {
    final prefs = await SharedPreferences.getInstance();
    final createdAt = prefs.getString(_accountCreatedKey);

    if (createdAt == null) {
      // First time setup
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_accountCreatedKey, now);
      return 0;
    }

    final created = DateTime.parse(createdAt);
    final now = DateTime.now();
    return now.difference(created).inDays;
  }

  // Check if user is in grace period (first 3 days)
  static Future<bool> isInGracePeriod() async {
    final age = await getAccountAgeDays();
    return age <= 3;
  }

  // Get story limit based on tier and grace period
  static Future<int> getStoryLimit(String tier) async {
    if (tier == 'premium' || tier == 'family') {
      return 999; // Unlimited
    }

    if (await isInGracePeriod()) {
      return 999; // Unlimited during grace period
    }

    return 20; // Free tier limit after grace period
  }

  // Get stories used this month
  static Future<int> getStoriesUsedThisMonth() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to reset counter (new month)
    final lastReset = prefs.getString(_lastResetKey);
    final now = DateTime.now();

    if (lastReset == null) {
      await prefs.setString(_lastResetKey, now.toIso8601String());
      await prefs.setInt(_storiesThisMonthKey, 0);
      return 0;
    }

    final lastResetDate = DateTime.parse(lastReset);
    if (now.month != lastResetDate.month || now.year != lastResetDate.year) {
      // New month - reset counter
      await prefs.setString(_lastResetKey, now.toIso8601String());
      await prefs.setInt(_storiesThisMonthKey, 0);
      return 0;
    }

    return prefs.getInt(_storiesThisMonthKey) ?? 0;
  }

  // Increment story count
  static Future<void> incrementStoryCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getStoriesUsedThisMonth();
    await prefs.setInt(_storiesThisMonthKey, current + 1);
  }

  // Check if user can generate story
  static Future<Map<String, dynamic>> canGenerateStory(String tier) async {
    final limit = await getStoryLimit(tier);
    final used = await getStoriesUsedThisMonth();
    final isGrace = await isInGracePeriod();
    final accountAge = await getAccountAgeDays();

    return {
      'can_generate': used < limit,
      'stories_used': used,
      'stories_limit': limit,
      'is_grace_period': isGrace,
      'account_age_days': accountAge,
      'should_show_soft_prompt': !isGrace && accountAge >= 4 && accountAge <= 7 && used >= (limit * 0.8),
      'should_show_hard_limit': !isGrace && used >= limit,
    };
  }
}
```

```dart
// lib/dialogs/upgrade_prompt_dialog.dart (NEW FILE)
import 'package:flutter/material.dart';

class UpgradePromptDialog extends StatelessWidget {
  final bool isSoftPrompt; // true = soft prompt, false = hard limit
  final int storiesUsed;
  final int storiesLimit;
  final int accountAgeDays;

  const UpgradePromptDialog({
    Key? key,
    required this.isSoftPrompt,
    required this.storiesUsed,
    required this.storiesLimit,
    required this.accountAgeDays,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isSoftPrompt ? Icons.info : Icons.lock,
            color: isSoftPrompt ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(isSoftPrompt ? 'Usage Update' : 'Story Limit Reached'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSoftPrompt) ...[
              Text(
                'You\'ve used $storiesUsed out of $storiesLimit free stories this month.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Your 3-day grace period ended on day ${accountAgeDays - 3}. Upgrade for unlimited stories!',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ] else ...[
              Text(
                'You\'ve reached your monthly limit of $storiesLimit stories.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Upgrade to continue creating unlimited therapeutic stories for your family!',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],

            const SizedBox(height: 24),

            // Tier comparison table
            _buildTierComparison(context),
          ],
        ),
      ),
      actions: [
        if (isSoftPrompt)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isSoftPrompt ? 'Maybe Later' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, true);
            Navigator.pushNamed(context, '/subscription-plans');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
          ),
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildTierComparison(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _tierRow(context, 'Feature', 'Free', 'Premium', 'Family', isHeader: true),
          _tierRow(context, 'Stories/Month', '20', 'Unlimited', 'Unlimited'),
          _tierRow(context, 'Illustrations', 'Learning mode only', '1 per story', '2 per story'),
          _tierRow(context, 'Characters', '1', 'Unlimited', 'Unlimited'),
          _tierRow(context, 'Price', '\$0', '\$9.99/mo', '\$14.99/mo'),
        ],
      ),
    );
  }

  Widget _tierRow(BuildContext context, String feature, String free, String premium, String family, {bool isHeader = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey[200] : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 14 : 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? null : Colors.amber[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              family,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? null : Colors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/screens/story_creation_screen.dart (ADD CHECK BEFORE GENERATION)
import 'package:story_weaver/services/subscription_service.dart';
import 'package:story_weaver/dialogs/upgrade_prompt_dialog.dart';

// Before calling generateStory():
Future<void> _generateStory() async {
  final user = await UserService.getCurrentUser();
  final canGenerate = await SubscriptionService.canGenerateStory(user.tier);

  // Show soft prompt if approaching limit
  if (canGenerate['should_show_soft_prompt']) {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => UpgradePromptDialog(
        isSoftPrompt: true,
        storiesUsed: canGenerate['stories_used'],
        storiesLimit: canGenerate['stories_limit'],
        accountAgeDays: canGenerate['account_age_days'],
      ),
    );

    if (shouldContinue == false) {
      return; // User cancelled
    }
  }

  // Show hard limit if reached
  if (canGenerate['should_show_hard_limit']) {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpgradePromptDialog(
        isSoftPrompt: false,
        storiesUsed: canGenerate['stories_used'],
        storiesLimit: canGenerate['stories_limit'],
        accountAgeDays: canGenerate['account_age_days'],
      ),
    );
    return; // Cannot generate
  }

  // Proceed with generation
  await SubscriptionService.incrementStoryCount();
  Navigator.pushNamed(context, '/generate-story', arguments: _storyParams);
}
```

**Testing Checklist:**
- [ ] New users have unlimited stories for first 3 days
- [ ] Grace period countdown shows correctly in settings
- [ ] Soft prompt appears at 80% of limit (days 4-7)
- [ ] Hard limit enforced after day 8
- [ ] Story counter resets correctly each month
- [ ] Tier comparison table displays correctly
- [ ] "View Plans" button navigates to subscription screen
- [ ] Analytics track grace period usage vs. paid conversions

---

# Week 2: Navigation & Mobile Ergonomics

## Task 2.1: Simplify Navigation (4-Tab Bottom Bar)

**User Pain Point:**
"Too many app sections (15+ screens). Children get lost. Navigation relies on swipes."

**Current Behavior:**
- Complex drawer menu with many options
- Swipe gestures difficult for children
- No clear navigation hierarchy

**New Behavior:**
- 4-tab bottom navigation bar (Create | Library | Feelings | Settings)
- All screens accessible within 2 taps
- Large, thumb-reachable tap targets

### Implementation:

**Files to Update:**
- `lib/main.dart` (set up bottom navigation)
- `lib/widgets/app_scaffold.dart` (CREATE NEW - reusable scaffold)
- All major screens (remove individual navigation)

```dart
// lib/widgets/app_scaffold.dart (NEW FILE)
import 'package:flutter/material.dart';

class AppScaffold extends StatefulWidget {
  final Widget body;
  final int initialIndex;

  const AppScaffold({
    Key? key,
    required this.body,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    if (index == _selectedIndex) return; // Already on this tab

    setState(() => _selectedIndex = index);

    // Navigate to corresponding screen
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/create');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/library');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/feelings-corner');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.create, size: 28),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books, size: 28),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite, size: 28),
            label: 'Feelings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, size: 28),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
```

**Usage in screens:**

```dart
// lib/screens/create_story_screen.dart
return AppScaffold(
  initialIndex: 0,
  body: _buildCreateStoryContent(),
);

// lib/screens/library_screen.dart
return AppScaffold(
  initialIndex: 1,
  body: _buildLibraryContent(),
);

// lib/screens/feelings_corner_screen.dart
return AppScaffold(
  initialIndex: 2,
  body: _buildFeelingsContent(),
);

// lib/screens/settings_screen.dart
return AppScaffold(
  initialIndex: 3,
  body: _buildSettingsContent(),
);
```

**Testing Checklist:**
- [ ] Bottom navigation visible on all main screens
- [ ] Tap targets at least 48x48 pixels (thumb-friendly)
- [ ] Active tab highlighted correctly
- [ ] Navigation animations smooth
- [ ] Back button behavior correct
- [ ] Children can navigate independently

---

## Task 2.2: Floating Action Buttons (Story Result Screen)

**User Pain Point:**
"Buttons at top of story result screen unreachable on phones. Poor mobile ergonomics."

**Current Behavior:**
- Share, save, regenerate buttons at top of screen
- Requires scrolling to access after reading story

**New Behavior:**
- Floating action buttons at bottom right
- Always accessible (follow scroll position)
- Primary action (Save) most prominent

### Implementation:

**Files to Update:**
- `lib/screens/story_result_screen.dart`

```dart
// lib/screens/story_result_screen.dart (ADD FLOATING ACTIONS)
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(_story.title),
      backgroundColor: Colors.purple[100],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Story content
          Text(_story.text),

          // Illustrations
          ..._buildIllustrations(),

          // Wisdom gem
          _buildWisdomGem(),

          // Bottom padding for FAB
          const SizedBox(height: 80),
        ],
      ),
    ),
    floatingActionButton: _buildFloatingActions(),
  );
}

Widget _buildFloatingActions() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Secondary actions (smaller)
      if (_story.illustrations.isNotEmpty)
        FloatingActionButton.small(
          onPressed: _shareIllustrations,
          backgroundColor: Colors.blue,
          heroTag: 'share',
          child: const Icon(Icons.share, size: 20),
        ),
      const SizedBox(height: 12),

      FloatingActionButton.small(
        onPressed: _regenerateStory,
        backgroundColor: Colors.orange,
        heroTag: 'regenerate',
        child: const Icon(Icons.refresh, size: 20),
      ),
      const SizedBox(height: 12),

      // Primary action (larger)
      FloatingActionButton.extended(
        onPressed: _saveStory,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.favorite),
        label: const Text('Save Story'),
      ),
    ],
  );
}
```

**Testing Checklist:**
- [ ] FABs visible while scrolling
- [ ] Primary action (Save) most prominent
- [ ] Buttons reachable with thumb on phones
- [ ] No overlap with story content
- [ ] Animations smooth
- [ ] Haptic feedback on button press

---

## Task 2.3: Better Error Messages

**User Pain Point:**
"HTTP errors (403, 500) shown to users instead of friendly messages."

**Current Behavior:**
- Raw error messages: "403 Your API key was reported as leaked"
- Technical jargon confusing to parents

**New Behavior:**
- User-friendly error messages
- Suggested actions to resolve
- Option to retry or get help

### Implementation:

**Files to Create:**
- `lib/utils/error_handler.dart` (NEW)
- `lib/widgets/error_dialog.dart` (NEW)

```dart
// lib/utils/error_handler.dart (NEW FILE)
class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('403') || errorString.contains('api key')) {
      return 'There\'s an issue with the API key. Please check your settings or contact support.';
    }

    if (errorString.contains('500') || errorString.contains('server error')) {
      return 'Our servers are having a moment. Please try again in a few seconds!';
    }

    if (errorString.contains('timeout') || errorString.contains('connection')) {
      return 'Slow connection detected. Please check your internet and try again.';
    }

    if (errorString.contains('rate limit')) {
      return 'Too many requests! Please wait a moment before trying again.';
    }

    // Generic fallback
    return 'Something unexpected happened. Don\'t worry, we\'re on it!';
  }

  static String getSuggestedAction(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('403') || errorString.contains('api key')) {
      return 'Go to Settings → API Key to verify your configuration.';
    }

    if (errorString.contains('500')) {
      return 'Wait 30 seconds and try generating your story again.';
    }

    if (errorString.contains('timeout')) {
      return 'Check your WiFi connection and try again.';
    }

    if (errorString.contains('rate limit')) {
      return 'Take a short break (1-2 minutes) then try again.';
    }

    return 'Try closing and reopening the app, then give it another shot.';
  }
}
```

```dart
// lib/widgets/error_dialog.dart (NEW FILE)
import 'package:flutter/material.dart';
import 'package:story_weaver/utils/error_handler.dart';

class ErrorDialog extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final bool showSupport;

  const ErrorDialog({
    Key? key,
    required this.error,
    this.onRetry,
    this.showSupport = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final friendlyMessage = ErrorHandler.getUserFriendlyMessage(error);
    final suggestedAction = ErrorHandler.getSuggestedAction(error);

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.error_outline, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('Oops!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friendlyMessage,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestedAction,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showSupport) ...[
            const SizedBox(height: 16),
            Text(
              'Still having trouble? Contact support@storyweaver.app',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry!();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Try Again'),
          ),
      ],
    );
  }
}
```

**Usage example:**

```dart
// In any screen where errors occur:
try {
  final story = await StoryService.generateStory(params);
} catch (e) {
  showDialog(
    context: context,
    builder: (context) => ErrorDialog(
      error: e,
      onRetry: () => _generateStory(),
    ),
  );
}
```

**Testing Checklist:**
- [ ] All error types have friendly messages
- [ ] Suggested actions are actionable
- [ ] Retry button works correctly
- [ ] Support email link works
- [ ] No technical jargon shown to users
- [ ] Error tracking logs technical details for debugging

---

## Task 2.4: Remove Illustration Button Redundancy

**User Pain Point:**
"Button says 'Generate Illustrations' even when already generated. Confusing."

**Current Behavior:**
- Button always visible
- No indication illustrations already exist
- Users click expecting more but nothing happens

**New Behavior:**
- Button hidden if tier limit reached
- Clear label if more illustrations available
- Visual indicator showing current count

### Implementation:

This is covered by **Task 1.4: Clear Illustration Messaging** from Week 1. Ensure the `IllustrationControls` widget is properly integrated.

**Additional enhancement:**

```dart
// lib/screens/story_result_screen.dart (ADD ILLUSTRATION COUNTER)
Widget _buildIllustrationSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Illustrations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_story.illustrations.isNotEmpty)
            Chip(
              label: Text('${_story.illustrations.length} of ${_getMaxIllustrations()}'),
              backgroundColor: Colors.purple[100],
            ),
        ],
      ),
      const SizedBox(height: 12),

      // Show illustrations
      if (_story.illustrations.isNotEmpty)
        ..._story.illustrations.map((ill) => _buildIllustrationCard(ill)),

      // Illustration controls
      IllustrationControls(
        subscriptionTier: _userTier,
        isLearningToReadMode: _story.isLearningToReadMode,
        hasUserApiKey: _hasApiKey,
        currentIllustrationCount: _story.illustrations.length,
        onGenerateMore: _generateMoreIllustrations,
        onUpgrade: _showUpgradeScreen,
      ),
    ],
  );
}

int _getMaxIllustrations() {
  if (_userTier == 'family') return 2;
  if (_userTier == 'premium') return 1;
  if (_story.isLearningToReadMode || _hasApiKey) return 1;
  return 0;
}
```

**Testing Checklist:**
- [ ] Counter shows "1 of 2" for Family tier with 1 illustration
- [ ] Counter shows "1 of 1" for Premium tier
- [ ] Button hidden when limit reached
- [ ] Clear visual hierarchy
- [ ] No confusion about illustration availability

---

# Week 3: Character Creation & Features

## Task 3.1: Character Creation Templates

**User Pain Point:**
"Character creation with sliders/traits feels like doing taxes. Parents abandon."

**Current Behavior:**
- 15+ fields to fill out
- Personality sliders confusing
- Takes 5-10 minutes to complete

**New Behavior:**
- Pre-made templates (Adventurous, Shy, Creative, etc.)
- One-tap character creation
- Optional customization after

### Implementation:

**Files to Update:**
- `lib/screens/character_creation_screen.dart`

```dart
// lib/screens/character_creation_screen.dart (ADD TEMPLATE SELECTION)
class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({Key? key}) : super(key: key);

  @override
  State<CharacterCreationScreen> createState() => _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  bool _useTemplate = true;
  String? _selectedTemplate;

  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'The Adventurer',
      'icon': Icons.explore,
      'color': Colors.orange,
      'description': 'Brave, curious, loves trying new things',
      'personality': {
        'energy': 80,
        'social': 70,
        'structure': 40,
      },
      'traits': ['brave', 'curious', 'energetic'],
      'fears': ['being bored'],
      'strengths': ['trying new things', 'making friends'],
    },
    {
      'name': 'The Thinker',
      'icon': Icons.science,
      'color': Colors.blue,
      'description': 'Thoughtful, loves puzzles and questions',
      'personality': {
        'energy': 50,
        'social': 40,
        'structure': 80,
      },
      'traits': ['thoughtful', 'analytical', 'curious'],
      'fears': ['not understanding things'],
      'strengths': ['solving problems', 'asking questions'],
    },
    {
      'name': 'The Artist',
      'icon': Icons.palette,
      'color': Colors.purple,
      'description': 'Creative, imaginative, loves art',
      'personality': {
        'energy': 60,
        'social': 50,
        'structure': 30,
      },
      'traits': ['creative', 'imaginative', 'expressive'],
      'fears': ['criticism'],
      'strengths': ['making art', 'thinking differently'],
    },
    {
      'name': 'The Helper',
      'icon': Icons.favorite,
      'color': Colors.pink,
      'description': 'Kind, caring, loves helping others',
      'personality': {
        'energy': 60,
        'social': 90,
        'structure': 60,
      },
      'traits': ['kind', 'empathetic', 'caring'],
      'fears': ['hurting others\' feelings'],
      'strengths': ['helping friends', 'understanding emotions'],
    },
    {
      'name': 'The Athlete',
      'icon': Icons.sports_soccer,
      'color': Colors.green,
      'description': 'Active, energetic, loves sports',
      'personality': {
        'energy': 90,
        'social': 70,
        'structure': 50,
      },
      'traits': ['active', 'determined', 'competitive'],
      'fears': ['losing'],
      'strengths': ['never giving up', 'teamwork'],
    },
    {
      'name': 'The Shy One',
      'icon': Icons.menu_book,
      'color': Colors.teal,
      'description': 'Quiet, observant, loves reading',
      'personality': {
        'energy': 40,
        'social': 30,
        'structure': 70,
      },
      'traits': ['quiet', 'observant', 'thoughtful'],
      'fears': ['loud situations', 'being center of attention'],
      'strengths': ['listening', 'noticing details'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Character'),
        backgroundColor: Colors.purple[100],
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _useTemplate = !_useTemplate);
            },
            child: Text(
              _useTemplate ? 'Custom' : 'Templates',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _useTemplate ? _buildTemplateSelection() : _buildCustomForm(),
    );
  }

  Widget _buildTemplateSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a Character Type',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a template that matches your child\'s personality. You can customize later!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          ...templates.map((template) => _buildTemplateCard(template)),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final isSelected = _selectedTemplate == template['name'];

    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = template['name']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected ? template['color'].withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? template['color'] : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: template['color'],
            radius: 30,
            child: Icon(
              template['icon'],
              size: 30,
              color: Colors.white,
            ),
          ),
          title: Text(
            template['name'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(template['description']),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (template['traits'] as List<String>).map((trait) {
                  return Chip(
                    label: Text(trait),
                    backgroundColor: template['color'].withOpacity(0.2),
                    labelStyle: TextStyle(fontSize: 11),
                  );
                }).toList(),
              ),
            ],
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: template['color'], size: 32)
              : null,
        ),
      ),
    );
  }

  // ... rest of custom form implementation
}
```

**Testing Checklist:**
- [ ] Templates visually appealing
- [ ] One-tap selection works
- [ ] Character created in <30 seconds
- [ ] Can still access custom form
- [ ] Templates reflect diverse personalities
- [ ] "Customize" option available after template selection

---

## Task 3.2: Interactive Story Quality Improvements

**User Pain Point:**
"Interactive stories have illusion of choice - outcomes feel predetermined."

**Current Behavior:**
- Choices don't significantly affect story outcome
- All paths converge quickly
- Limited replay value

**New Behavior:**
- Meaningful branching with distinct outcomes
- Track user's choices for story consistency
- Multiple endings possible

### Implementation:

**Files to Update:**
- `backend/story_service.py` (improve prompt engineering)
- `lib/services/interactive_story_service.dart`

```python
# backend/story_service.py (UPDATE INTERACTIVE STORY PROMPTS)

def generate_interactive_story(character: str, theme: str, age: int, companion: str = None):
    """Generate opening segment with MEANINGFUL branching choices."""

    prompt = f"""Create an opening segment for an interactive therapeutic story.

CHARACTER: {character}, age {age}
THEME: {theme}
{f'COMPANION: {companion}' if companion else ''}

CRITICAL REQUIREMENTS:
1. Create 3 choices that lead to DISTINCTLY DIFFERENT story paths
2. Each choice should represent a different emotional response or problem-solving approach
3. Choices should reflect real decisions children face (seeking help, trying alone, finding creative solution)
4. The story should be age-appropriate and therapeutic

Opening segment should:
- Establish a clear situation or challenge
- Make the character relatable
- Present choices that feel meaningful (not just "go left" vs "go right")

Example of GOOD choices:
- "Ask your teacher for help" (seeking support)
- "Try to figure it out on your own" (independence)
- "Work together with a friend" (collaboration)

Example of BAD choices:
- "Go through the red door"
- "Go through the blue door"
- "Go through the green door"

Format the response as JSON:
{{
  "text": "Opening story text...",
  "choices": [
    {{"id": "choice_1", "text": "First meaningful choice"}},
    {{"id": "choice_2", "text": "Second meaningful choice"}},
    {{"id": "choice_3", "text": "Third meaningful choice"}}
  ]
}}
"""

    # Call Gemini API with improved prompt
    response = gemini_client.generate_content(prompt)
    return json.loads(response.text)


def continue_interactive_story(
    character: str,
    theme: str,
    age: int,
    choice: str,
    story_so_far: str,
    choices_made: List[str],
    companion: str = None
):
    """Continue story based on user's choice, maintaining consistency."""

    prompt = f"""Continue this interactive therapeutic story based on the user's choice.

CHARACTER: {character}, age {age}
THEME: {theme}
{f'COMPANION: {companion}' if companion else ''}

STORY SO FAR:
{story_so_far}

PREVIOUS CHOICES: {', '.join(choices_made)}
CURRENT CHOICE: {choice}

CRITICAL REQUIREMENTS:
1. The story must REFLECT and BUILD UPON the choice made
2. If they chose to seek help, show positive outcomes of asking for support
3. If they chose independence, show growth through self-reliance
4. If they chose collaboration, demonstrate teamwork benefits
5. Maintain consistency with previous choices
6. Provide 3 new meaningful choices that continue to diverge the story
7. Track toward a therapeutic lesson relevant to their choices

After 3-4 choices, offer an "End the story here" option that provides satisfying closure.

Format as JSON:
{{
  "text": "Next story segment...",
  "choices": [
    {{"id": "choice_1", "text": "Meaningful choice 1"}},
    {{"id": "choice_2", "text": "Meaningful choice 2"}},
    {{"id": "choice_end", "text": "End the story here"}}
  ]
}}
"""

    response = gemini_client.generate_content(prompt)
    return json.loads(response.text)
```

**Testing Checklist:**
- [ ] Choices feel meaningful (not arbitrary)
- [ ] Story outcomes differ based on choices
- [ ] Consistency maintained throughout
- [ ] Multiple endings possible
- [ ] Therapeutic value clear in each path
- [ ] Children can understand consequences of choices

---

## Task 3.3: BYOK (Bring Your Own Key) Setup Wizard

**User Pain Point:**
"BYOK model confusing for non-technical users."

**Current Behavior:**
- Technical instructions in settings
- No guidance on getting API key
- Users don't understand benefits

**New Behavior:**
- Step-by-step wizard with screenshots
- Direct link to Google AI Studio
- Clear explanation of benefits

### Implementation:

**Files to Create:**
- `lib/screens/byok_setup_wizard.dart` (NEW)

```dart
// lib/screens/byok_setup_wizard.dart (NEW FILE)
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BYOKSetupWizard extends StatefulWidget {
  const BYOKSetupWizard({Key? key}) : super(key: key);

  @override
  State<BYOKSetupWizard> createState() => _BYOKSetupWizardState();
}

class _BYOKSetupWizardState extends State<BYOKSetupWizard> {
  int _currentStep = 0;
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Own API Key'),
        backgroundColor: Colors.purple[100],
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
        steps: [
          Step(
            title: const Text('Why Use Your Own API Key?'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _benefitCard(
                  icon: Icons.all_inclusive,
                  title: 'Unlimited Stories',
                  description: 'Generate as many stories as you want, no monthly limits!',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _benefitCard(
                  icon: Icons.palette,
                  title: 'Free Illustrations',
                  description: 'Get illustrations even on the free tier!',
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                _benefitCard(
                  icon: Icons.savings,
                  title: 'Cost Effective',
                  description: 'Google Gemini API is very affordable - typically \$0.10-0.50/month for typical usage!',
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  'Perfect for families who want unlimited access without a subscription!',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Get Your API Key'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow these steps to get your free Gemini API key:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _instructionStep(1, 'Go to Google AI Studio'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _launchURL('https://makersuite.google.com/app/apikey'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Google AI Studio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                _instructionStep(2, 'Sign in with your Google account'),
                const SizedBox(height: 8),
                _instructionStep(3, 'Click "Get API Key" or "Create API Key"'),
                const SizedBox(height: 8),
                _instructionStep(4, 'Copy the key that appears'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your API key is free and includes generous usage limits!',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Enter Your API Key'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste your Gemini API key below:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'AIzaSy...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: _apiKeyController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _apiKeyController.clear(),
                          )
                        : null,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your API key is stored securely on your device and never shared.',
                          style: TextStyle(fontSize: 12, color: Colors.green[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(int number, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.purple,
          child: Text(
            '$number',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onStepContinue() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      // Final step - verify API key
      await _verifyAndSaveApiKey();
    }
  }

  Future<void> _verifyAndSaveApiKey() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Verify API key by making a test request
      final isValid = await ApiKeyService.verifyApiKey(_apiKeyController.text);

      if (isValid) {
        // Save API key
        await ApiKeyService.saveApiKey(_apiKeyController.text);

        // Show success
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Success!'),
              ],
            ),
            content: const Text(
              'Your API key has been verified and saved. You now have unlimited stories and illustrations!',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close wizard
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Start Creating!'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Invalid API key');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid API key. Please check and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }
}
```

**Testing Checklist:**
- [ ] Wizard steps are clear
- [ ] External link to Google AI Studio opens correctly
- [ ] API key validation works
- [ ] Secure storage of API key
- [ ] Success message shown after verification
- [ ] BYOK features immediately available

---

# Week 4: Progressive Disclosure & Polish

## Task 4.1: Progressive Feature Unlocks

**User Pain Point:**
"15+ screens overwhelm new users. Too many features upfront."

**Current Behavior:**
- All features visible immediately
- Complex features confuse beginners
- No guidance on feature discovery

**New Behavior:**
- Core features (Create, Library) available immediately
- Advanced features unlock after first story
- Tooltips guide feature discovery

### Implementation:

**Files to Create:**
- `lib/services/feature_unlock_service.dart` (NEW)
- `lib/widgets/feature_unlock_tooltip.dart` (NEW)

```dart
// lib/services/feature_unlock_service.dart (NEW FILE)
import 'package:shared_preferences/shared_preferences.dart';

class FeatureUnlockService {
  static const String _storiesCreatedKey = 'stories_created_count';
  static const String _featuresUnlockedKey = 'features_unlocked';

  // Feature unlock thresholds
  static const int CHARACTER_CREATION_UNLOCK = 1; // After 1st story
  static const int INTERACTIVE_STORIES_UNLOCK = 2; // After 2nd story
  static const int COLORING_PAGES_UNLOCK = 3; // After 3rd story
  static const int ADVANCED_SETTINGS_UNLOCK = 5; // After 5th story

  static Future<bool> isFeatureUnlocked(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final storiesCreated = prefs.getInt(_storiesCreatedKey) ?? 0;
    final unlockedFeatures = prefs.getStringList(_featuresUnlockedKey) ?? [];

    if (unlockedFeatures.contains(featureId)) {
      return true;
    }

    // Check if threshold reached
    switch (featureId) {
      case 'character_creation':
        return storiesCreated >= CHARACTER_CREATION_UNLOCK;
      case 'interactive_stories':
        return storiesCreated >= INTERACTIVE_STORIES_UNLOCK;
      case 'coloring_pages':
        return storiesCreated >= COLORING_PAGES_UNLOCK;
      case 'advanced_settings':
        return storiesCreated >= ADVANCED_SETTINGS_UNLOCK;
      default:
        return true; // Unknown features are unlocked by default
    }
  }

  static Future<void> incrementStoriesCreated() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_storiesCreatedKey) ?? 0;
    await prefs.setInt(_storiesCreatedKey, current + 1);
  }

  static Future<int> getStoriesCreated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_storiesCreatedKey) ?? 0;
  }

  static Future<Map<String, dynamic>> getFeatureUnlockStatus() async {
    final storiesCreated = await getStoriesCreated();

    return {
      'character_creation': {
        'unlocked': storiesCreated >= CHARACTER_CREATION_UNLOCK,
        'threshold': CHARACTER_CREATION_UNLOCK,
        'remaining': (CHARACTER_CREATION_UNLOCK - storiesCreated).clamp(0, 999),
      },
      'interactive_stories': {
        'unlocked': storiesCreated >= INTERACTIVE_STORIES_UNLOCK,
        'threshold': INTERACTIVE_STORIES_UNLOCK,
        'remaining': (INTERACTIVE_STORIES_UNLOCK - storiesCreated).clamp(0, 999),
      },
      'coloring_pages': {
        'unlocked': storiesCreated >= COLORING_PAGES_UNLOCK,
        'threshold': COLORING_PAGES_UNLOCK,
        'remaining': (COLORING_PAGES_UNLOCK - storiesCreated).clamp(0, 999),
      },
      'advanced_settings': {
        'unlocked': storiesCreated >= ADVANCED_SETTINGS_UNLOCK,
        'threshold': ADVANCED_SETTINGS_UNLOCK,
        'remaining': (ADVANCED_SETTINGS_UNLOCK - storiesCreated).clamp(0, 999),
      },
    };
  }
}
```

```dart
// lib/widgets/feature_unlock_tooltip.dart (NEW FILE)
import 'package:flutter/material.dart';

class FeatureUnlockTooltip extends StatelessWidget {
  final String featureName;
  final int storiesRemaining;
  final VoidCallback? onDismiss;

  const FeatureUnlockTooltip({
    Key? key,
    required this.featureName,
    required this.storiesRemaining,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.pink[400]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🎉 New Feature Unlocked!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You can now use: $featureName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              onDismiss?.call();
              // Navigate to feature
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
            ),
            child: const Text('Try It Now!'),
          ),
        ],
      ),
    );
  }
}

class FeatureLockedCard extends StatelessWidget {
  final String featureName;
  final String description;
  final IconData icon;
  final int storiesRemaining;

  const FeatureLockedCard({
    Key? key,
    required this.featureName,
    required this.description,
    required this.icon,
    required this.storiesRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              featureName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    'Create $storiesRemaining more ${storiesRemaining == 1 ? "story" : "stories"} to unlock',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Usage example:**

```dart
// lib/screens/home_screen.dart
Future<void> _checkFeatureUnlocks() async {
  final status = await FeatureUnlockService.getFeatureUnlockStatus();

  // Show character creation if just unlocked
  if (status['character_creation']['unlocked'] &&
      status['character_creation']['remaining'] == 0) {
    _showFeatureUnlockTooltip('Character Creation');
  }
}

// In features grid:
FutureBuilder<Map<String, dynamic>>(
  future: FeatureUnlockService.getFeatureUnlockStatus(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final status = snapshot.data!;
    final characterUnlocked = status['character_creation']['unlocked'];

    if (characterUnlocked) {
      return _buildCharacterCreationCard();
    } else {
      return FeatureLockedCard(
        featureName: 'Character Profiles',
        description: 'Create detailed character profiles',
        icon: Icons.person,
        storiesRemaining: status['character_creation']['remaining'],
      );
    }
  },
)
```

**Testing Checklist:**
- [ ] Features unlock at correct thresholds
- [ ] Unlock notifications appear
- [ ] Locked features show progress
- [ ] Core features always available
- [ ] Analytics track feature discovery
- [ ] No confusion about locked features

---

## Task 4.2: Story Quality Indicators

**User Pain Point:**
"Stories feel generic. No indication of therapeutic value."

**Current Behavior:**
- All stories look the same in library
- No quality indicators
- Can't tell which stories were most helpful

**New Behavior:**
- Quality badges (therapeutic focus, engagement, age-appropriate)
- User ratings and favorites
- "Most helpful" sorting

### Implementation:

**Files to Update:**
- `lib/models/story.dart`
- `lib/widgets/story_card.dart`
- `lib/screens/library_screen.dart`

```dart
// lib/models/story.dart (ADD QUALITY FIELDS)
class Story {
  final String id;
  final String title;
  final String text;
  final List<Illustration> illustrations;
  final String wisdomGem;
  final DateTime createdAt;

  // NEW: Quality indicators
  final List<String> therapeuticTags; // ['anxiety', 'confidence', 'friendship']
  final int engagementScore; // 0-100
  final bool isFavorite;
  final int userRating; // 1-5 stars
  final String ageAppropriateLevel; // 'perfect', 'good', 'stretch'

  // ... rest of model
}
```

```dart
// lib/widgets/story_card.dart (UPDATE)
class StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and favorite
              Row(
                children: [
                  Expanded(
                    child: Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (story.isFavorite)
                    const Icon(Icons.favorite, color: Colors.red, size: 24),
                ],
              ),
              const SizedBox(height: 8),

              // Therapeutic tags
              if (story.therapeuticTags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: story.therapeuticTags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      backgroundColor: _getTagColor(tag),
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),

              const SizedBox(height: 12),

              // Quality indicators
              Row(
                children: [
                  // Engagement score
                  _buildIndicator(
                    Icons.favorite_border,
                    '${story.engagementScore}% engaging',
                    Colors.pink,
                  ),
                  const SizedBox(width: 16),

                  // Age appropriateness
                  _buildIndicator(
                    _getAgeIcon(story.ageAppropriateLevel),
                    story.ageAppropriateLevel,
                    _getAgeColor(story.ageAppropriateLevel),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // User rating
              if (story.userRating > 0)
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < story.userRating ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${story.userRating}/5',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  Color _getTagColor(String tag) {
    const tagColors = {
      'anxiety': Colors.blue,
      'confidence': Colors.orange,
      'friendship': Colors.pink,
      'bravery': Colors.red,
      'kindness': Colors.green,
      'creativity': Colors.purple,
    };
    return tagColors[tag.toLowerCase()] ?? Colors.grey;
  }

  IconData _getAgeIcon(String level) {
    switch (level) {
      case 'perfect': return Icons.check_circle;
      case 'good': return Icons.thumb_up;
      case 'stretch': return Icons.trending_up;
      default: return Icons.help;
    }
  }

  Color _getAgeColor(String level) {
    switch (level) {
      case 'perfect': return Colors.green;
      case 'good': return Colors.blue;
      case 'stretch': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
```

**Testing Checklist:**
- [ ] Quality badges display correctly
- [ ] Therapeutic tags accurate
- [ ] Engagement score calculated properly
- [ ] Age appropriateness indicators helpful
- [ ] User can rate stories easily
- [ ] Favorite stories stand out visually

---

## Success Metrics Tracking

Add analytics throughout the implementation:

```dart
// lib/services/analytics_service.dart (EXPAND)
class AnalyticsService {
  // Week 1 metrics
  static void trackOnboardingStep(int step, String action) {
    FirebaseAnalytics.instance.logEvent(
      name: 'onboarding_step',
      parameters: {'step': step, 'action': action},
    );
  }

  static void trackStoryGenerationPhase(String phase, int secondsElapsed) {
    FirebaseAnalytics.instance.logEvent(
      name: 'story_generation_phase',
      parameters: {'phase': phase, 'seconds_elapsed': secondsElapsed},
    );
  }

  static void trackGracePeriodUsage(int daysSinceSignup, int storiesUsed) {
    FirebaseAnalytics.instance.logEvent(
      name: 'grace_period_usage',
      parameters: {'days': daysSinceSignup, 'stories': storiesUsed},
    );
  }

  // Week 2 metrics
  static void trackNavigationPattern(String from, String to) {
    FirebaseAnalytics.instance.logEvent(
      name: 'navigation',
      parameters: {'from': from, 'to': to},
    );
  }

  static void trackErrorOccurrence(String errorType, String screen) {
    FirebaseAnalytics.instance.logEvent(
      name: 'error_occurred',
      parameters: {'error_type': errorType, 'screen': screen},
    );
  }

  // Week 3 metrics
  static void trackCharacterCreationMethod(String method) {
    // method: 'template' or 'custom'
    FirebaseAnalytics.instance.logEvent(
      name: 'character_creation',
      parameters: {'method': method},
    );
  }

  static void trackInteractiveStoryChoice(String choice, int step) {
    FirebaseAnalytics.instance.logEvent(
      name: 'interactive_choice',
      parameters: {'choice': choice, 'step': step},
    );
  }

  static void trackBYOKSetup(bool successful) {
    FirebaseAnalytics.instance.logEvent(
      name: 'byok_setup',
      parameters: {'successful': successful},
    );
  }

  // Week 4 metrics
  static void trackFeatureUnlock(String feature, int storiesCreated) {
    FirebaseAnalytics.instance.logEvent(
      name: 'feature_unlock',
      parameters: {'feature': feature, 'stories_created': storiesCreated},
    );
  }

  static void trackStoryRating(String storyId, int rating) {
    FirebaseAnalytics.instance.logEvent(
      name: 'story_rating',
      parameters: {'story_id': storyId, 'rating': rating},
    );
  }
}
```

---

## Implementation Summary

### Week 1: Critical UX Fixes (Days 1-7)
- ✅ Remove feelings pop-up → Feelings Corner tab
- ✅ Quick-start wizard (3 steps)
- ✅ Phase-based progress indicator
- ✅ Clear illustration messaging
- ✅ Free tier grace period (3 days)

**Expected Impact:**
- Onboarding completion: 30% → 70%
- Story abandon rate: 40% → 10%
- User satisfaction: 3.2 → 4.0

### Week 2: Navigation & Mobile (Days 8-14)
- ✅ 4-tab bottom navigation
- ✅ Floating action buttons
- ✅ User-friendly error messages
- ✅ Remove illustration button redundancy

**Expected Impact:**
- Navigation ease: "confusing" → "intuitive"
- Mobile usability score: +40%
- Error recovery rate: +60%

### Week 3: Features & Polish (Days 15-21)
- ✅ Character creation templates
- ✅ Improved interactive story branching
- ✅ BYOK setup wizard

**Expected Impact:**
- Character creation completion: 50% → 85%
- Interactive story engagement: +50%
- BYOK adoption: 10% of free users

### Week 4: Progressive Disclosure (Days 22-28)
- ✅ Feature unlock system
- ✅ Story quality indicators
- ✅ Analytics tracking

**Expected Impact:**
- Feature discovery: +70%
- Free-to-paid conversion: 2% → 8%
- User retention (30 days): 40% → 65%

---

## Deployment Strategy

1. **Week 1 (Critical):** Deploy immediately, monitor closely
2. **Week 2 (High Priority):** Deploy after Week 1 validated
3. **Week 3 (Medium Priority):** Deploy incrementally
4. **Week 4 (Enhancement):** Deploy as polish

**Testing Protocol:**
- [ ] Local testing on iOS and Android
- [ ] Beta test with 5-10 users
- [ ] Monitor Firebase Analytics
- [ ] Railway backend performance
- [ ] A/B test grace period duration (3 vs 7 days)

---

## Rollback Plan

If any week causes issues:
1. Revert to previous commit
2. Disable feature flags
3. Communicate with users
4. Fix in staging, redeploy

---

**This 4-week plan transforms Story Weaver from confusing to delightful!** 🚀

Each task is implementation-ready with code examples, testing checklists, and success metrics.

Ready to start Week 1? 🎯
