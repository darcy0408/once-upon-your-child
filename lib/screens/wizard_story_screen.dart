import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models.dart'; // Import Character model
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
/// - Loads saved characters automatically on init
class WizardStoryScreen extends StatefulWidget {
  final Character? initialCharacter;
  final List<Character> availableCharacters;

  const WizardStoryScreen({
    super.key,
    this.initialCharacter,
    this.availableCharacters = const [],
  });

  @override
  State<WizardStoryScreen> createState() => _WizardStoryScreenState();
}

class _WizardStoryScreenState extends State<WizardStoryScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Wizard data collected across steps
  late final WizardData _wizardData;

  // Loaded data
  List<Character> _savedCharacters = [];
  bool _isLoadingCharacters = true;

  @override
  void initState() {
    super.initState();
    _wizardData = WizardData();
    if (widget.initialCharacter != null) {
      _initializeFromCharacter(widget.initialCharacter!);
    }
    _loadSavedCharacters();
  }

  Future<void> _loadSavedCharacters() async {
    final url = Uri.parse('${Environment.backendUrl}/get-characters');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> characterList = decoded['characters'] ?? [];
        final characters = characterList
            .map((data) => Character.fromJson(data))
            .toList();

        if (mounted) {
          setState(() {
            _savedCharacters = characters;
            _isLoadingCharacters = false;
          });
          debugPrint('✅ Loaded ${characters.length} saved characters from backend');
        }
      } else {
        debugPrint('⚠️ Failed to load characters: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _savedCharacters = [];
            _isLoadingCharacters = false;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading characters: $e');
      if (mounted) {
        setState(() {
          _savedCharacters = [];
          _isLoadingCharacters = false;
        });
      }
    }
  }

  void _initializeFromCharacter(Character character) {
    _wizardData.characterName = character.name;
    _wizardData.characterAge = character.age;
    _wizardData.selectedArchetypeId = character.role; // Best guess mapping
    
    // Map appearance if available
    if (character.avatar != null) {
        // Simple mapping for now, more detailed one could be added
        // _wizardData.selectedHairStyle = character.avatarConfig!['hairStyle'] ?? '';
    }
  }


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
                      availableCharacters: _savedCharacters,
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
                      savedCharacters: _savedCharacters,
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
  String? characterId; // To link to existing or saved character
  String characterGender = 'Girl'; // Default, toggleable in Step 1
  Map<String, int> personalitySliders = {
    'energy': 50,
    'sociability': 50,
    'creativity': 50,
    'confidence': 50,
    'empathy': 50,
    'adventurousness': 50,
  };
  String characterName = '';
  int characterAge = 8;
  String selectedHairStyle = '';
  String selectedSkinTone = '';
  String selectedOutfit = '';

  // Advanced character features
  List<String> fears = [];
  List<String> strengths = [];
  String? comfortItem;

  // Custom Pets & Additional Characters
  List<Map<String, String>> pets = [];
  List<String> additionalCharacters = [];

  // Step 2: Feeling Selection
  String? selectedScenario;
  List<String> selectedEmotionChips = [];
  String? parentalNote;

  // Step 3: Companion Selector
  List<String> selectedCompanions = [];
  List<String> companionNames = [];

  // Step 4: Story Settings
  bool rhymeTimeMode = false;
  bool learningToReadMode = false;
  bool interactiveMode = false;
  bool includeIllustrations = true; // Default to true

  // Helper methods
  bool get isStep1Complete =>
      selectedArchetypeId != null && characterName.isNotEmpty;

  bool get isStep2Complete =>
      selectedScenario != null || selectedEmotionChips.isNotEmpty;

  bool get isStep3Complete => selectedCompanions.isNotEmpty;

  bool get isComplete =>
      isStep1Complete && isStep2Complete && isStep3Complete;

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'gender': characterGender,
      'archetype': selectedArchetypeId,
      'personality': personalitySliders,
      'name': characterName,
      'age': characterAge,
      'appearance': {
        'hair': selectedHairStyle,
        'skin': selectedSkinTone,
        'outfit': selectedOutfit,
      },
      'fears': fears,
      'strengths': strengths,
      'comfortItem': comfortItem,
      'pets': pets,
      'additionalCharacters': additionalCharacters,
      'scenario': selectedScenario,
      'emotions': selectedEmotionChips,
      'parentalNote': parentalNote,
      'companions': selectedCompanions,
      'companionNames': companionNames,
      'rhymeTimeMode': rhymeTimeMode,
      'learningToReadMode': learningToReadMode,
      'interactiveMode': interactiveMode,
      'includeIllustrations': includeIllustrations,
    };
  }
}
