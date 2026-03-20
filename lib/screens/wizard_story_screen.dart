import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart'; // Import Character model
import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/moon_phase_progress.dart';
import '../widgets/avatar_generation_banner.dart';
import '../providers/age_band_provider.dart';
import 'character_library_screen.dart';
import 'feelings_garden_screen.dart';
import 'wizard_steps/hero_creator_step.dart';
import 'wizard_steps/magic_review_step.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service_manager.dart';
import 'bedtime_wizard_screen.dart';

/// WizardStoryScreen - Main 4-step wizard for creating magical stories
///
/// Design:
/// - Fixed magical gradient background
/// - Moon phase progress indicator at top
/// - 4 steps: Hero Creator, Feeling Selection, Companion Selector, Review & Launch
/// - Smooth page transitions
/// - All data collected and passed to final step
/// - Loads saved characters automatically on init
class WizardStoryScreen extends ConsumerStatefulWidget {
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
  ConsumerState<WizardStoryScreen> createState() => _WizardStoryScreenState();
}

class _WizardStoryScreenState extends ConsumerState<WizardStoryScreen> {
  late final PageController _pageController; // Late init
  int _currentStep = 0;
  int _progressStep = 0;
  int? _requestedSubStep;
  int _subStepRequestNonce = 0;

  // Wizard data collected across steps
  late final WizardData _wizardData;

  // Loaded data
  List<Character> _savedCharacters = [];

  @override
  void initState() {
    super.initState();

    _wizardData = widget.initialWizardData ?? WizardData();
    _loadOnboardingName();
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

  Future<void> _loadOnboardingName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (name != null && name.isNotEmpty && _wizardData.characterName.isEmpty) {
      if (mounted) {
        setState(() {
          _wizardData.characterName = name;
        });
      }
    }
  }

  Future<void> _loadSavedCharacters() async {
    try {
      final api = ApiServiceManager();
      final response = await api.get('/get-characters');
      // Backend returns a list directly, not wrapped in {'characters': [...]}
      final List<dynamic> characterList = response['data'] is List
          ? response['data'] as List<dynamic>
          : (response['characters'] as List<dynamic>? ?? const []);
      debugPrint(
          '🔍 _loadSavedCharacters: Fetched ${characterList.length} raw items from backend');
      final characters = characterList
          .map((data) => Character.fromJson(data as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _savedCharacters = characters;
        });
        debugPrint(
            '✅ Loaded ${characters.length} saved characters from backend');
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
      _wizardData.personalitySliders =
          Map<String, int>.from(character.personalitySliders!);
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

  void _showBedtimeSettingsDialog(BuildContext context) {
    bool isInteractive = false;
    double timerMinutes = 0; // 0 means off

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A1B4E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Bedtime Settings',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Interactive Story', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Child answers questions to shape the story.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: isInteractive,
                    activeThumbColor: const Color(0xFFFFD700),
                    onChanged: (val) => setDialogState(() => isInteractive = val),
                  ),
                  const Divider(color: Colors.white24),
                  const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
                  Slider(
                    value: timerMinutes,
                    min: 0,
                    max: 60,
                    divisions: 6,
                    activeColor: const Color(0xFFFFD700),
                    inactiveColor: Colors.white24,
                    label: timerMinutes == 0 ? 'Off' : '${timerMinutes.round()} min',
                    onChanged: (val) => setDialogState(() => timerMinutes = val),
                  ),
                  Text(
                    timerMinutes == 0 ? 'Timer is Off' : 'Story ends in ${timerMinutes.round()} minutes',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF2A1B4E),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BedtimeWizardScreen(
                          childName: _wizardData.characterName,
                          childAge: _wizardData.characterAge,
                          isInteractive: isInteractive,
                          timerMinutes: timerMinutes.round(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
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
                        color: Colors.white,
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
                              final stepLabels = band.band == AgeBand.sprout
                                  ? <String>[
                                      'My Hero!',
                                      'My Buddies!',
                                      'My World!',
                                      band.launchStoryLabel
                                    ]
                                  : band.band == AgeBand.adventurer
                                      ? <String>[
                                          'My Character',
                                          'My Companions',
                                          'My Setting',
                                          band.launchStoryLabel
                                        ]
                                      : band.band == AgeBand.creator
                                          ? <String>[
                                              'Character',
                                              'Companions',
                                              'Setting',
                                              band.launchStoryLabel
                                            ]
                                          : <String>[
                                              'Pick Hero',
                                              'Pick Team',
                                              'Pick Place',
                                              band.launchStoryLabel
                                            ];
                              return Transform.scale(
                                scale: band.spacingScale,
                                child: MoonPhaseProgress(
                                  currentStep: _progressStep,
                                  totalSteps: 4,
                                  stepLabels: stepLabels,
                                  onStepTap: (step) {
                                    if (_currentStep == 0) {
                                      setState(() {
                                        _requestedSubStep = step;
                                        _progressStep = step;
                                        _subStepRequestNonce++;
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Feelings Garden button — labeled for all child bands
                    if (band.band != AgeBand.creator)
                      _LabeledNavButton(
                        icon: Icons.favorite,
                        label: 'Feelings',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FeelingsGardenScreen(
                              childAge: _wizardData.characterAge <= 0
                                  ? 8
                                  : _wizardData.characterAge,
                            ),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.white),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FeelingsGardenScreen(
                              childAge: _wizardData.characterAge <= 0
                                  ? 8
                                  : _wizardData.characterAge,
                            ),
                          ),
                        ),
                        tooltip: 'Feelings Garden',
                      ),
                    // Character Library button — labeled for all child bands
                    if (band.band != AgeBand.creator)
                      _LabeledNavButton(
                        icon: Icons.people,
                        label: 'Heroes',
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CharacterLibraryScreen(),
                            ),
                          );
                          _loadSavedCharacters();
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.people, color: Colors.white),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CharacterLibraryScreen(),
                            ),
                          );
                          _loadSavedCharacters();
                        },
                        tooltip: 'My Characters',
                      ),
                    // Bedtime Mode button
                    if (band.band != AgeBand.creator)
                      Semantics(
                        button: true,
                        label: 'Start bedtime story mode. Voice only, no screen needed.',
                        child: _LabeledNavButton(
                          icon: Icons.bedtime_outlined,
                          label: 'Bedtime',
                          onPressed: () => _showBedtimeSettingsDialog(context),
                        ),
                      )
                    else
                      Semantics(
                        button: true,
                        label: 'Start bedtime story mode. Voice only, no screen needed.',
                        child: IconButton(
                          icon: const Icon(Icons.bedtime_outlined, color: Colors.white),
                          onPressed: () => _showBedtimeSettingsDialog(context),
                          tooltip: 'Bedtime Story Mode',
                        ),
                      ),
                  ],
                ),
              ),

              // Wizard steps (PageView)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable swipe
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                      if (index == 1) _progressStep = 3;
                    });
                  },
                  children: [
                    // Step 1: Hero Creator (includes companions + scene selection)
                    HeroCreatorStep(
                      wizardData: _wizardData,
                      onNext: _nextStep,
                      availableCharacters: _savedCharacters,
                      requestedSubStep: _requestedSubStep,
                      subStepRequestNonce: _subStepRequestNonce,
                      onSubStepChange: (s) => setState(() => _progressStep = s),
                      onAgeChanged: (age) => ref
                          .read(ageBandNotifierProvider.notifier)
                          .setAge(age),
                    ),
                    // Step 2: Review & Launch
                    MagicReviewStep(
                      wizardData: _wizardData,
                      onGoBack: _previousStep,
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

/// Icon button with a small text label underneath — used for young age bands
/// so children know what each button does without needing to read a tooltip.
class _LabeledNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _LabeledNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
