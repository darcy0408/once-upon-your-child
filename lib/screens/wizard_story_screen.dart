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
                        color: AppColors.textDark,
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
