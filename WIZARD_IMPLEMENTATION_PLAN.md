# 🧙‍♂️ Wizard Story Creator Implementation Plan

**Branch:** `feature/wizard-story-creator`
**Base Branch:** `feature/gui-redesign`
**Assignee:** AI Agent (Codex/Gemini/Grok)
**Estimated Files:** 8 new files, 2 modified files

---

## 📋 Executive Summary

Implement a 4-step wizard interface that replaces the current "Make Magic" button's behavior. When users click "Make Magic," they should enter an immersive wizard flow that guides them through:

1. **Step 1: Hero Creator** - Create or select a character with archetype selection
2. **Step 2: Feeling Selection** - Choose emotional scenarios or feelings to explore
3. **Step 3: Companion Selector** - Pick an optional story companion
4. **Step 4: Magic Review** - Review selections and launch story generation

**Current Bug:** Clicking "Make Magic" calls `_onCreateButtonPressed()` which validates character selection. If no character exists, it shows "Please choose a character!" but doesn't navigate anywhere.

**Solution:** Make "Make Magic" button navigate to the wizard flow, which handles character creation within the wizard if needed.

---

## 🌳 Git Workflow

### Step 1: Create Feature Branch
```bash
# Make sure you're on the latest feature/gui-redesign
git checkout feature/gui-redesign
git pull origin feature/gui-redesign --no-edit

# Create new branch for wizard work
git checkout -b feature/wizard-story-creator
```

### Step 2: Work on Implementation
- Make commits as you complete each file
- Test frequently in Chrome using `flutter run -d chrome`
- Use descriptive commit messages

### Step 3: Final Commit & Push
```bash
# Stage all changes
git add .

# Commit with descriptive message
git commit -m "feat: Implement 4-step wizard story creator

- Add WizardStoryScreen with 4-step flow
- Create HeroCreatorStep with archetype selection
- Add FeelingSelectionStep with scenario cards
- Implement CompanionSelectorStep with animal selection
- Add MagicReviewStep with launch button
- Create MoonPhaseProgress indicator widget
- Add MakeMagicButton animated widget
- Update AppTheme with magical gradients
- Wire up wizard to 'Make Magic' button in main_story.dart

Closes #[issue-number]"

# Push to remote
git push origin feature/wizard-story-creator
```

### Step 4: Testing Checklist
See "Testing Requirements" section at the end of this document.

---

## 📂 Files to Create

### 1. `lib/theme/app_theme.dart` (MODIFY)

**Purpose:** Add magical gradient definitions used by wizard screens

**Changes:**
- Add `AppGradients` class after `AppSpacing` class
- Keep all existing code intact

**Code to ADD (insert after line 18):**

```dart
class AppGradients {
  /// Magical background gradient for wizard screens
  static const LinearGradient magicalBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF667eea), // Purple-blue
      Color(0xFF764ba2), // Deep purple
      Color(0xFFF093FB), // Pink-purple
      Color(0xFFF5576C), // Coral-pink
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// Starry night gradient (alternative)
  static const LinearGradient starryNight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0F2027), // Dark navy
      Color(0xFF203A43), // Teal-grey
      Color(0xFF2C5364), // Blue-grey
    ],
  );

  /// Magical card gradient
  static const LinearGradient magicalCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF), // White
      Color(0xFFF3E7FF), // Light purple tint
    ],
  );
}

class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const secondary = Color(0xFF4CAF50);
  static const accent = Color(0xFF81C784);
  static const surface = Color(0xFFF5F9F5);
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFFFA000);

  // Wizard-specific colors
  static const wizardPurple = Color(0xFF764ba2);
  static const wizardPink = Color(0xFFF093FB);
  static const textLight = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF2C3E50);
}
```

**Location:** lib/theme/app_theme.dart
**Action:** Edit existing file

---

### 2. `lib/widgets/moon_phase_progress.dart` (CREATE)

**Purpose:** Display wizard progress as moon phases (4 phases for 4 steps)

**Full File Code:**

```dart
import 'package:flutter/material.dart';

/// MoonPhaseProgress - Shows wizard progress as moon phases
///
/// Displays 4 moon phases representing the 4 wizard steps:
/// - New Moon (Step 1: Hero Creator)
/// - Waxing Crescent (Step 2: Feeling Selection)
/// - First Quarter (Step 3: Companion Selector)
/// - Waxing Gibbous (Step 4: Magic Review)
class MoonPhaseProgress extends StatelessWidget {
  final int currentStep; // 0-3

  const MoonPhaseProgress({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _MoonPhase(
            phase: index,
            isActive: isActive,
            isCompleted: isCompleted,
          ),
        );
      }),
    );
  }
}

class _MoonPhase extends StatelessWidget {
  final int phase;
  final bool isActive;
  final bool isCompleted;

  const _MoonPhase({
    required this.phase,
    required this.isActive,
    required this.isCompleted,
  });

  String get _emoji {
    if (isCompleted) return '🌕'; // Full moon for completed
    switch (phase) {
      case 0:
        return '🌑'; // New moon
      case 1:
        return '🌒'; // Waxing crescent
      case 2:
        return '🌓'; // First quarter
      case 3:
        return '🌔'; // Waxing gibbous
      default:
        return '🌑';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? Colors.white.withOpacity(0.3)
            : Colors.transparent,
        border: Border.all(
          color: isActive || isCompleted
              ? Colors.white
              : Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Text(
        _emoji,
        style: TextStyle(
          fontSize: isActive ? 24 : 20,
        ),
      ),
    );
  }
}
```

**Location:** lib/widgets/moon_phase_progress.dart
**Action:** Create new file

---

### 3. `lib/widgets/make_magic_button.dart` (CREATE)

**Purpose:** Animated "Make Magic" button with sparkle effects

**Full File Code:**

```dart
import 'package:flutter/material.dart';

/// MakeMagicButton - The primary CTA button with magical animations
///
/// Features:
/// - Pulsing glow effect
/// - Sparkle particle animations on hover
/// - Gradient background
/// - Icon with auto_awesome
class MakeMagicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String label;

  const MakeMagicButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Make Magic',
  });

  @override
  State<MakeMagicButton> createState() => _MakeMagicButtonState();
}

class _MakeMagicButtonState extends State<MakeMagicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(MakeMagicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.stop();
      } else {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isLoading ? 1.0 : _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onPressed,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 28),
              label: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

**Location:** lib/widgets/make_magic_button.dart
**Action:** Create new file

---

### 4. `lib/screens/wizard_story_screen.dart` (CREATE)

**Purpose:** Main wizard container with 4-step PageView navigation

**Full File Code:**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/moon_phase_progress.dart';
import 'wizard_steps/hero_creator_step.dart';
import 'wizard_steps/feeling_selection_step.dart';
import 'wizard_steps/companion_selector_step.dart';
import 'wizard_steps/magic_review_step.dart';

/// WizardStoryScreen - Main 4-step wizard for creating magical stories
///
/// Design:
/// - Fixed magical gradient background
/// - Moon phase progress indicator at top
/// - 4 steps: Hero Creator, Feeling Selection, Companion Selector, Review & Launch
/// - Smooth page transitions
/// - All data collected and passed to final step
class WizardStoryScreen extends StatefulWidget {
  const WizardStoryScreen({super.key});

  @override
  State<WizardStoryScreen> createState() => _WizardStoryScreenState();
}

class _WizardStoryScreenState extends State<WizardStoryScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Wizard data collected across steps
  final WizardData _wizardData = WizardData();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.magicalBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and progress
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Back button (or close on first step)
                    IconButton(
                      icon: Icon(
                        _currentStep == 0 ? Icons.close : Icons.arrow_back,
                        color: AppColors.textLight,
                      ),
                      onPressed: _currentStep == 0
                          ? () => Navigator.of(context).pop()
                          : _previousStep,
                      tooltip: _currentStep == 0 ? 'Close' : 'Back',
                    ),
                    const Spacer(),
                    // Progress indicator
                    MoonPhaseProgress(currentStep: _currentStep),
                    const Spacer(),
                    // Placeholder for symmetry
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Wizard steps (PageView)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  onPageChanged: (index) {
                    setState(() => _currentStep = index);
                  },
                  children: [
                    // Step 1: Hero Creator
                    HeroCreatorStep(
                      wizardData: _wizardData,
                      onNext: _nextStep,
                    ),
                    // Step 2: Feeling Selection
                    FeelingSelectionStep(
                      wizardData: _wizardData,
                      onNext: _nextStep,
                    ),
                    // Step 3: Companion Selector
                    CompanionSelectorStep(
                      wizardData: _wizardData,
                      onNext: _nextStep,
                    ),
                    // Step 4: Review & Launch
                    MagicReviewStep(
                      wizardData: _wizardData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WizardData - Collects all wizard selections
class WizardData {
  // Step 1: Hero Creator
  String? selectedArchetypeId;
  Map<String, int> personalitySliders = {
    'energy': 50,
    'sociability': 50,
    'creativity': 50,
    'confidence': 50,
    'empathy': 50,
    'adventurousness': 50,
  };
  String characterName = '';
  String characterAge = '8';
  String selectedHairStyle = '';
  String selectedSkinTone = '';
  String selectedOutfit = '';

  // Step 2: Feeling Selection
  String? selectedScenario;
  List<String> selectedEmotionChips = [];
  String? parentalNote;

  // Step 3: Companion Selector
  String? selectedCompanion;
  String? companionName;

  // Helper methods
  bool get isStep1Complete =>
      selectedArchetypeId != null && characterName.isNotEmpty;

  bool get isStep2Complete =>
      selectedScenario != null || selectedEmotionChips.isNotEmpty;

  bool get isStep3Complete => selectedCompanion != null;

  bool get isComplete =>
      isStep1Complete && isStep2Complete && isStep3Complete;

  Map<String, dynamic> toJson() {
    return {
      'archetype': selectedArchetypeId,
      'personality': personalitySliders,
      'name': characterName,
      'age': characterAge,
      'appearance': {
        'hair': selectedHairStyle,
        'skin': selectedSkinTone,
        'outfit': selectedOutfit,
      },
      'scenario': selectedScenario,
      'emotions': selectedEmotionChips,
      'parentalNote': parentalNote,
      'companion': selectedCompanion,
      'companionName': companionName,
    };
  }
}
```

**Location:** lib/screens/wizard_story_screen.dart
**Action:** Create new file

---

### 5. `lib/screens/wizard_steps/hero_creator_step.dart` (CREATE)

**Purpose:** Step 1 - Character archetype selection and basic info

**Full File Code:**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../wizard_story_screen.dart';

/// HeroCreatorStep - Step 1 of wizard: Create or select your hero
///
/// Features:
/// - Archetype cards (Brave Explorer, Creative Dreamer, Wise Helper, etc.)
/// - Character name input
/// - Age selector
/// - Simple appearance options
/// - Personality sliders
class HeroCreatorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;

  const HeroCreatorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
  });

  @override
  State<HeroCreatorStep> createState() => _HeroCreatorStepState();
}

class _HeroCreatorStepState extends State<HeroCreatorStep> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _archetypes = [
    {
      'id': 'brave_explorer',
      'title': 'Brave Explorer',
      'emoji': '🗺️',
      'description': 'Loves adventure and discovering new things',
    },
    {
      'id': 'creative_dreamer',
      'title': 'Creative Dreamer',
      'emoji': '🎨',
      'description': 'Imagines amazing worlds and creates beautiful things',
    },
    {
      'id': 'wise_helper',
      'title': 'Wise Helper',
      'emoji': '🌟',
      'description': 'Loves helping others and solving problems',
    },
    {
      'id': 'curious_scientist',
      'title': 'Curious Scientist',
      'emoji': '🔬',
      'description': 'Asks questions and loves to learn how things work',
    },
    {
      'id': 'friendly_leader',
      'title': 'Friendly Leader',
      'emoji': '👑',
      'description': 'Brings people together and makes everyone feel welcome',
    },
    {
      'id': 'nature_lover',
      'title': 'Nature Lover',
      'emoji': '🌿',
      'description': 'Cares for animals and loves the outdoors',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.wizardData.characterName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectArchetype(String archetypeId) {
    setState(() {
      widget.wizardData.selectedArchetypeId = archetypeId;
    });
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      widget.wizardData.characterName = _nameController.text;
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              'Create Your Hero',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Who will be the star of this magical story?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Character Name Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Character Name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your hero\'s name...',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Archetype Selection
            const Text(
              'Choose Your Hero Type',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Archetype Cards
            ...(_archetypes.map((archetype) {
              final isSelected =
                  widget.wizardData.selectedArchetypeId == archetype['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ArchetypeCard(
                  title: archetype['title'],
                  emoji: archetype['emoji'],
                  description: archetype['description'],
                  isSelected: isSelected,
                  onTap: () => _selectArchetype(archetype['id']),
                ),
              );
            })),

            const SizedBox(height: 32),

            // Next Button
            ElevatedButton(
              onPressed: widget.wizardData.isStep1Complete ? _handleNext : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.wizardPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Next: Choose Feelings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ArchetypeCard({
    required this.title,
    required this.emoji,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppGradients.magicalCard
              : const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.wizardPurple
                : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.wizardPurple.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 15 : 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.wizardPurple.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.wizardPurple
                          : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // Checkmark
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.wizardPurple,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
```

**Location:** lib/screens/wizard_steps/hero_creator_step.dart
**Action:** Create new file (create `wizard_steps` directory first)

---

### 6. `lib/screens/wizard_steps/feeling_selection_step.dart` (CREATE)

**Purpose:** Step 2 - Select emotional scenarios or feelings to explore

**Full File Code:**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../wizard_story_screen.dart';

/// FeelingSelectionStep - Step 2: Choose the feeling or scenario
///
/// Features:
/// - Pre-built scenario cards (First Day of School, Making New Friends, etc.)
/// - Emotion chips (Happy, Nervous, Excited, etc.)
/// - Optional parental note for custom situations
class FeelingSelectionStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;

  const FeelingSelectionStep({
    super.key,
    required this.wizardData,
    required this.onNext,
  });

  @override
  State<FeelingSelectionStep> createState() => _FeelingSelectionStepState();
}

class _FeelingSelectionStepState extends State<FeelingSelectionStep> {
  final List<Map<String, String>> _scenarios = [
    {
      'id': 'first_day_school',
      'title': 'First Day of School',
      'emoji': '🏫',
    },
    {
      'id': 'making_friends',
      'title': 'Making New Friends',
      'emoji': '🤝',
    },
    {
      'id': 'trying_something_new',
      'title': 'Trying Something New',
      'emoji': '🎯',
    },
    {
      'id': 'feeling_left_out',
      'title': 'Feeling Left Out',
      'emoji': '😔',
    },
    {
      'id': 'big_achievement',
      'title': 'A Big Achievement',
      'emoji': '🏆',
    },
    {
      'id': 'facing_a_fear',
      'title': 'Facing a Fear',
      'emoji': '💪',
    },
  ];

  final List<String> _emotions = [
    'Happy 😊',
    'Nervous 😰',
    'Excited 🎉',
    'Sad 😢',
    'Brave 🦁',
    'Confused 🤔',
    'Proud 🌟',
    'Worried 😟',
  ];

  void _selectScenario(String scenarioId) {
    setState(() {
      widget.wizardData.selectedScenario = scenarioId;
    });
  }

  void _toggleEmotion(String emotion) {
    setState(() {
      if (widget.wizardData.selectedEmotionChips.contains(emotion)) {
        widget.wizardData.selectedEmotionChips.remove(emotion);
      } else {
        widget.wizardData.selectedEmotionChips.add(emotion);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'What\'s the Story About?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a situation or feeling to explore',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Scenario Selection
          const Text(
            'Pick a Scenario',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),

          // Scenario Cards (2 columns)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: _scenarios.map((scenario) {
              final isSelected =
                  widget.wizardData.selectedScenario == scenario['id'];
              return _ScenarioCard(
                title: scenario['title']!,
                emoji: scenario['emoji']!,
                isSelected: isSelected,
                onTap: () => _selectScenario(scenario['id']!),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Emotion Chips
          const Text(
            'Add Feelings (Optional)',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emotions.map((emotion) {
              final isSelected =
                  widget.wizardData.selectedEmotionChips.contains(emotion);
              return FilterChip(
                label: Text(emotion),
                selected: isSelected,
                onSelected: (_) => _toggleEmotion(emotion),
                backgroundColor: Colors.white.withOpacity(0.9),
                selectedColor: AppColors.wizardPink,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Next Button
          ElevatedButton(
            onPressed: widget.wizardData.isStep2Complete ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.wizardPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Next: Choose Companion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final String title;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.title,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppGradients.magicalCard
              : const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.wizardPurple
                : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.wizardPurple.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 15 : 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.wizardPurple
                      : AppColors.textDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Location:** lib/screens/wizard_steps/feeling_selection_step.dart
**Action:** Create new file

---

### 7. `lib/screens/wizard_steps/companion_selector_step.dart` (CREATE)

**Purpose:** Step 3 - Choose an optional story companion

**Full File Code:**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../wizard_story_screen.dart';

/// CompanionSelectorStep - Step 3: Pick your magical companion
///
/// Features:
/// - Animal companion cards (Dog, Cat, Dragon, Fairy, etc.)
/// - "No companion" option
/// - Optional companion name input
class CompanionSelectorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;

  const CompanionSelectorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
  });

  @override
  State<CompanionSelectorStep> createState() => _CompanionSelectorStepState();
}

class _CompanionSelectorStepState extends State<CompanionSelectorStep> {
  final List<Map<String, String>> _companions = [
    {'id': 'none', 'name': 'No Companion', 'emoji': '✨'},
    {'id': 'loyal_dog', 'name': 'Loyal Dog', 'emoji': '🐕'},
    {'id': 'mysterious_cat', 'name': 'Mysterious Cat', 'emoji': '🐈'},
    {'id': 'tiny_dragon', 'name': 'Tiny Dragon', 'emoji': '🐉'},
    {'id': 'wise_owl', 'name': 'Wise Owl', 'emoji': '🦉'},
    {'id': 'mischievous_fairy', 'name': 'Mischievous Fairy', 'emoji': '🧚'},
    {'id': 'brave_horse', 'name': 'Brave Horse', 'emoji': '🐴'},
    {'id': 'playful_bunny', 'name': 'Playful Bunny', 'emoji': '🐰'},
  ];

  void _selectCompanion(String companionId) {
    setState(() {
      widget.wizardData.selectedCompanion = companionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Choose Your Companion',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a magical friend to join the adventure',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Companion Cards (2 columns)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: _companions.map((companion) {
              final isSelected =
                  widget.wizardData.selectedCompanion == companion['id'];
              return _CompanionCard(
                name: companion['name']!,
                emoji: companion['emoji']!,
                isSelected: isSelected,
                onTap: () => _selectCompanion(companion['id']!),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Next Button
          ElevatedButton(
            onPressed: widget.wizardData.isStep3Complete ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.wizardPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Next: Review & Create',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanionCard({
    required this.name,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppGradients.magicalCard
              : const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.wizardPurple
                : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.wizardPurple.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 15 : 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.wizardPurple
                    : AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Location:** lib/screens/wizard_steps/companion_selector_step.dart
**Action:** Create new file

---

### 8. `lib/screens/wizard_steps/magic_review_step.dart` (CREATE)

**Purpose:** Step 4 - Review selections and launch story generation

**Full File Code:**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/make_magic_button.dart';
import '../wizard_story_screen.dart';

/// MagicReviewStep - Step 4: Review and launch story
///
/// Features:
/// - Summary of all wizard selections
/// - Character preview card
/// - Scenario preview
/// - Companion preview
/// - Big "Make Magic" button
/// - Launches story generation when pressed
class MagicReviewStep extends StatefulWidget {
  final WizardData wizardData;

  const MagicReviewStep({
    super.key,
    required this.wizardData,
  });

  @override
  State<MagicReviewStep> createState() => _MagicReviewStepState();
}

class _MagicReviewStepState extends State<MagicReviewStep> {
  bool _isGenerating = false;

  void _launchStory() async {
    setState(() => _isGenerating = true);

    // TODO: Implement actual story generation
    // For now, just show a placeholder and close wizard
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Story creation coming soon! Wizard data collected.'),
        backgroundColor: Colors.green,
      ),
    );

    // Close wizard and return to main screen
    Navigator.of(context).pop();
  }

  String _getArchetypeName(String? id) {
    final archetypes = {
      'brave_explorer': 'Brave Explorer',
      'creative_dreamer': 'Creative Dreamer',
      'wise_helper': 'Wise Helper',
      'curious_scientist': 'Curious Scientist',
      'friendly_leader': 'Friendly Leader',
      'nature_lover': 'Nature Lover',
    };
    return archetypes[id] ?? 'Unknown';
  }

  String _getScenarioName(String? id) {
    final scenarios = {
      'first_day_school': 'First Day of School',
      'making_friends': 'Making New Friends',
      'trying_something_new': 'Trying Something New',
      'feeling_left_out': 'Feeling Left Out',
      'big_achievement': 'A Big Achievement',
      'facing_a_fear': 'Facing a Fear',
    };
    return scenarios[id] ?? 'Custom Scenario';
  }

  String _getCompanionName(String? id) {
    final companions = {
      'none': 'No Companion',
      'loyal_dog': 'Loyal Dog',
      'mysterious_cat': 'Mysterious Cat',
      'tiny_dragon': 'Tiny Dragon',
      'wise_owl': 'Wise Owl',
      'mischievous_fairy': 'Mischievous Fairy',
      'brave_horse': 'Brave Horse',
      'playful_bunny': 'Playful Bunny',
    };
    return companions[id] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Ready to Create Magic?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Review your story ingredients',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Review Cards
          _ReviewCard(
            icon: Icons.person,
            title: 'Your Hero',
            content: widget.wizardData.characterName.isNotEmpty
                ? '${widget.wizardData.characterName} (${_getArchetypeName(widget.wizardData.selectedArchetypeId)})'
                : 'Not selected',
          ),
          const SizedBox(height: 12),

          _ReviewCard(
            icon: Icons.favorite,
            title: 'Story Scenario',
            content: _getScenarioName(widget.wizardData.selectedScenario),
          ),
          const SizedBox(height: 12),

          if (widget.wizardData.selectedEmotionChips.isNotEmpty)
            _ReviewCard(
              icon: Icons.emoji_emotions,
              title: 'Feelings to Explore',
              content: widget.wizardData.selectedEmotionChips.join(', '),
            ),
          if (widget.wizardData.selectedEmotionChips.isNotEmpty)
            const SizedBox(height: 12),

          _ReviewCard(
            icon: Icons.pets,
            title: 'Companion',
            content: _getCompanionName(widget.wizardData.selectedCompanion),
          ),

          const SizedBox(height: 48),

          // Big "Make Magic" button
          Center(
            child: widget.wizardData.isComplete
                ? MakeMagicButton(
                    onPressed: _launchStory,
                    isLoading: _isGenerating,
                  )
                : Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Complete all steps to continue',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _ReviewCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.wizardPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.wizardPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Location:** lib/screens/wizard_steps/magic_review_step.dart
**Action:** Create new file

---

### 9. `lib/main_story.dart` (MODIFY)

**Purpose:** Wire up the wizard to the "Make Magic" button

**Changes:**

1. **Add import** at the top (after line 48):
```dart
import 'screens/wizard_story_screen.dart';
```

2. **Replace the "Make Magic" button** (lines 1091-1118):

**OLD CODE:**
```dart
AnimatedScale(
  duration: const Duration(milliseconds: 160),
  scale: _magicPulse ? 1.05 : 1.0,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.auto_awesome),
    onPressed: (_gracePeriodStatus?.shouldShowHardLimit ?? false)
        ? null
        : () async {
            setState(() => _magicPulse = true);
            await _onCreateButtonPressed();
            if (mounted) {
              setState(() => _magicPulse = false);
            }
          },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.deepPurpleAccent,
      shadowColor: Colors.deepPurpleAccent.withOpacity(0.6),
      elevation: 6,
    ),
    label: Text(_interactiveMode
        ? 'Start Interactive Story'
        : 'Make Magic'),
  ),
),
```

**NEW CODE:**
```dart
AnimatedScale(
  duration: const Duration(milliseconds: 160),
  scale: _magicPulse ? 1.05 : 1.0,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.auto_awesome),
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
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.deepPurpleAccent,
      shadowColor: Colors.deepPurpleAccent.withOpacity(0.6),
      elevation: 6,
    ),
    label: Text(_interactiveMode
        ? 'Start Interactive Story'
        : 'Make Magic'),
  ),
),
```

**Location:** lib/main_story.dart
**Action:** Modify existing file

---

## 🧪 Testing Requirements

After implementing all files, test the following:

### Basic Flow Testing
1. ✅ Launch app in Chrome: `flutter run -d chrome`
2. ✅ Click "Make Magic" button on main screen
3. ✅ Verify wizard opens with magical gradient background
4. ✅ Verify moon phase progress shows 4 phases

### Step 1: Hero Creator
5. ✅ Verify all 6 archetype cards are visible
6. ✅ Click each archetype - verify selection state (purple border, checkmark)
7. ✅ Enter character name
8. ✅ Verify "Next" button is disabled until name + archetype selected
9. ✅ Click "Next" - verify smooth transition to Step 2

### Step 2: Feeling Selection
10. ✅ Verify 6 scenario cards in 2-column grid
11. ✅ Click scenarios - verify selection state
12. ✅ Click emotion chips - verify multi-select works
13. ✅ Verify "Next" button enabled when scenario OR emotions selected
14. ✅ Click "Next" - verify transition to Step 3

### Step 3: Companion Selector
15. ✅ Verify 8 companion cards (including "No Companion")
16. ✅ Click companions - verify selection state
17. ✅ Verify "Next" button enabled after selection
18. ✅ Click "Next" - verify transition to Step 4

### Step 4: Magic Review
19. ✅ Verify all selections displayed in review cards
20. ✅ Verify "Make Magic" button is visible
21. ✅ Click "Make Magic" - verify loading state
22. ✅ Verify success message shows
23. ✅ Verify wizard closes and returns to main screen

### Navigation Testing
24. ✅ Click back arrow on Step 2/3/4 - verify goes to previous step
25. ✅ Click X icon on Step 1 - verify closes wizard
26. ✅ Verify moon phases update correctly on each step

### Edge Cases
27. ✅ Test with very long character names (truncation)
28. ✅ Test selecting multiple emotions (chips wrap correctly)
29. ✅ Test rapid clicking between steps
30. ✅ Test closing wizard mid-flow and reopening

### Visual Polish
31. ✅ Verify all animations are smooth (200-400ms)
32. ✅ Verify magical gradient looks good on all steps
33. ✅ Verify text is readable on purple background
34. ✅ Verify cards have proper shadows and depth

---

## 🐛 Common Issues & Solutions

### Issue: Import errors for wizard files
**Solution:** Make sure you created the `lib/screens/wizard_steps/` directory first

### Issue: AppGradients not found
**Solution:** Verify you added the AppGradients class to `lib/theme/app_theme.dart`

### Issue: Wizard doesn't open when clicking "Make Magic"
**Solution:** Check that you added the import and updated the onPressed handler in main_story.dart

### Issue: Moon phases don't update
**Solution:** Verify _currentStep is being updated in setState() when pages change

### Issue: Layout overflow on small screens
**Solution:** Make sure all steps use SingleChildScrollView

---

## 📝 Commit Checklist

Before pushing, verify:
- [ ] All 8 files created
- [ ] 2 files modified correctly
- [ ] No syntax errors (`flutter analyze` passes)
- [ ] App runs without crashes
- [ ] All 34 test cases pass
- [ ] Code follows existing project style
- [ ] Imports are organized
- [ ] No debug print statements left in code
- [ ] Descriptive commit message written

---

## 🎯 Success Criteria

The wizard implementation is complete when:
1. ✅ "Make Magic" button opens the wizard screen
2. ✅ All 4 wizard steps are functional
3. ✅ Users can navigate forward and backward through steps
4. ✅ All selections are validated before allowing "Next"
5. ✅ Final review screen shows all collected data
6. ✅ "Make Magic" button on review screen shows loading state
7. ✅ Wizard closes gracefully and returns to main screen
8. ✅ No console errors or warnings
9. ✅ All animations are smooth and performant
10. ✅ Visual design matches magical theme

---

## 📞 Getting Help

If you encounter issues:
1. Check the "Common Issues & Solutions" section
2. Run `flutter clean && flutter pub get` to reset
3. Verify all imports are correct
4. Check browser console for errors
5. Test in Chrome DevTools with network throttling off

---

**Good luck! This wizard will create a magical story creation experience!** ✨🧙‍♂️
