import 'package:flutter/material.dart';
import '../models.dart'; // Import Character model
import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/moon_phase_progress.dart';
import '../widgets/avatar_generation_banner.dart';
import 'character_library_screen.dart';
import 'feelings_garden_screen.dart';
import 'wizard_steps/hero_creator_step.dart';
import 'wizard_steps/magic_review_step.dart';
import '../services/api_service_manager.dart';

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
  final int initialStep;
  // SEL Story Packs: optional seed data to pre-fill wizard fields
  final WizardData? initialWizardData;

  const WizardStoryScreen({
    super.key,
    this.initialCharacter,
    this.availableCharacters = const [],
    this.initialStep = 0,
    this.initialWizardData,
  });

  @override
  State<WizardStoryScreen> createState() => _WizardStoryScreenState();
}

class _WizardStoryScreenState extends State<WizardStoryScreen> {
  late final PageController _pageController; // Late init
  int _currentStep = 0;

  // Wizard data collected across steps
  late final WizardData _wizardData;

  // Loaded data
  List<Character> _savedCharacters = [];

  @override
  void initState() {
    super.initState();
    
    _wizardData = widget.initialWizardData ?? WizardData();
    if (widget.initialCharacter != null) {
      _initializeFromCharacter(widget.initialCharacter!);
      // If we have an initial character, skip Step 1 (Creation)
      _currentStep = (widget.initialStep == 0) ? 1 : widget.initialStep;
    } else {
      _currentStep = widget.initialStep;
    }
    _pageController = PageController(initialPage: _currentStep);
    
    _loadSavedCharacters();
  }

  Future<void> _loadSavedCharacters() async {
    try {
      final api = ApiServiceManager();
      final response = await api.get('/get-characters');
      // Backend returns a list directly, not wrapped in {'characters': [...]}
      final List<dynamic> characterList = response['data'] is List
          ? response['data'] as List<dynamic>
          : (response['characters'] as List<dynamic>? ?? const []);
      debugPrint('🔍 _loadSavedCharacters: Fetched ${characterList.length} raw items from backend');
      final characters = characterList
          .map((data) => Character.fromJson(data as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _savedCharacters = characters;
        });
        debugPrint('✅ Loaded ${characters.length} saved characters from backend');
        for (var c in characters) {
          debugPrint('   - Character: ${c.name}, Role: ${c.role}, ID: ${c.id}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading characters: $e');
      if (mounted) {
        setState(() {
          _savedCharacters = [];
        });
      }
    }
  }

  void _initializeFromCharacter(Character character) {
    _wizardData.characterName = character.name;
    _wizardData.characterAge = character.age;
    _wizardData.selectedArchetypeId = character.role; // Best guess mapping
    _wizardData.characterId = character.id;
    _wizardData.generatedAvatar = character.generatedAvatar;
    _wizardData.characterGender = character.gender ?? 'Girl';
    
    // Map personality if available
    if (character.personalitySliders != null) {
      _wizardData.personalitySliders = Map<String, int>.from(character.personalitySliders!);
    }

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
    if (_currentStep < 1) {
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
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Avatar generation banner (shows when generating in background)
              const AvatarGenerationBanner(),

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
                          ? () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            }
                          : _previousStep,
                      tooltip: _currentStep == 0 ? 'Close' : 'Back',
                    ),
                    // Progress indicator (responsive)
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Builder(
                            builder: (context) {
                              return MoonPhaseProgress(
                                currentStep: _currentStep,
                                totalSteps: 2,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Feelings Garden button
                    IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: AppColors.textDark,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FeelingsGardenScreen(
                              childAge: _wizardData.characterAge <= 0 ? 8 : _wizardData.characterAge,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Feelings Garden',
                    ),
                    // Character Library button
                    IconButton(
                      icon: const Icon(
                        Icons.people,
                        color: AppColors.textDark,
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CharacterLibraryScreen(),
                          ),
                        );
                        // Reload characters after returning
                        _loadSavedCharacters();
                      },
                      tooltip: 'My Characters',
                    ),
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
                    // Step 1: Hero Creator (includes companions + scene selection)
                    HeroCreatorStep(
                      wizardData: _wizardData,
                      onNext: _nextStep,
                      availableCharacters: _savedCharacters,
                    ),
                    // Step 2: Review & Launch
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

