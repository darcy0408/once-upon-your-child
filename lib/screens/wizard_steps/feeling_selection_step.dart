import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models.dart';
import '../../services/app_tts_service.dart';
import '../../services/audio_ambience_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/age_band_theme.dart';
import '../../widgets/image_continue_button.dart';
import '../../widgets/feelings_quest_modal.dart';
import '../../data/scenario_data.dart';
import '../../character_traits_data.dart';
import '../../widgets/magic_ear_button.dart';
import '../../widgets/imagine_it_input.dart';
import '../../widgets/age_band_badge.dart';
import '../../widgets/parallax_tilt_card.dart';
import '../../services/onboarding_service.dart';
import '../big_feelings_flow_screen.dart';
import '../../widgets/safe_asset_image.dart';

const double _settingCardWidth = 220;

/// Step 2: The Feeling Selection
///
/// Layout:
/// - Scenario carousel (swipeable cards)
/// - Emoji focus chips (multi-select)
/// - Parental override (discrete gear icon)
/// - Continue button
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

// Map scenario IDs to existing ambient sound assets for Sprout previews.
const _sproutScenarioSfx = <String, String>{
  'volcano_dragons':  'sounds/adventure_wind.mp3',
  'neon_jungle':      'sounds/forest_crickets.mp3',
  'storm_chaser_sky': 'sounds/adventure_wind.mp3',
  'crystal_cavern':   'sounds/ocean_waves.mp3',
};

class _FeelingSelectionStepState extends State<FeelingSelectionStep> {
  String? _selectedScenario;
  bool _showParentalInput = false;
  final TextEditingController _parentalNoteController = TextEditingController();
  final TextEditingController _safeSpaceController = TextEditingController();
  final TextEditingController _mathController = TextEditingController();
  final TextEditingController _avoidController = TextEditingController();

  // Sprout tap-to-hear state: first tap previews (TTS + SFX), second tap selects.
  String? _previewedScenarioId;
  Timer? _previewTimer;

  // Carousel swipe-hint state (first-use only, non-sprout bands)
  final Map<String, ScrollController> _carouselControllers = {};
  final Map<String, int> _carouselActiveDot = {};
  bool _swipeHintShown = true; // default true = no hint until prefs loaded
  Timer? _swipeHintTimer;

  // "New!" badge — scenario IDs the user has already tapped
  final Set<String> _visitedScenarioIds = {};

  // Voice input for Imagine It field (young children only)

  // Math gate state
  late int _mathA;
  late int _mathB;
  bool _mathGatePassed = false;
  bool _mathWrong = false;

  final List<ScenarioCard> _scenarios = ScenarioData.all;

  @override
  void initState() {
    super.initState();
    _selectedScenario = widget.wizardData.selectedScenario;
    widget.wizardData.selectedEmotionChips = [];
    _safeSpaceController.text = widget.wizardData.customElements;
    _parentalNoteController.text = widget.wizardData.parentalNote ?? '';
    _avoidController.text = widget.wizardData.storyDnaAvoid ?? '';
    // Generate a fresh math challenge each time Guardian Mode opens
    _resetMathGate();
    _loadSwipeHintPref();
    _loadVisitedScenarios();
  }

  Future<void> _loadSwipeHintPref() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('scenario_swipe_hint_shown') ?? false;
    if (mounted) {
      setState(() => _swipeHintShown = shown);
      if (!shown) {
        // Auto-dismiss hint after 3 s regardless of interaction
        _swipeHintTimer = Timer(const Duration(seconds: 3), _dismissSwipeHint);
      }
    }
  }

  void _dismissSwipeHint() async {
    _swipeHintTimer?.cancel();
    if (!mounted) return;
    setState(() => _swipeHintShown = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scenario_swipe_hint_shown', true);
  }

  Future<void> _loadVisitedScenarios() async {
    const onboarding = OnboardingService();
    final ids = <String>[];
    for (final scenario in ScenarioData.all) {
      if (await onboarding.hasVisitedScenario(scenario.id)) {
        ids.add(scenario.id);
      }
    }
    if (mounted && ids.isNotEmpty) {
      setState(() => _visitedScenarioIds.addAll(ids));
    }
  }

  void _resetMathGate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _mathA = (now % 7) + 2; // 2–8
    _mathB = (now % 9) + 1; // 1–9
    _mathController.clear();
    _mathGatePassed = false;
    _mathWrong = false;
  }

  void _checkMathAnswer() {
    final answer = int.tryParse(_mathController.text.trim());
    setState(() {
      if (answer == _mathA + _mathB) {
        _mathGatePassed = true;
        _mathWrong = false;
      } else {
        _mathWrong = true;
      }
    });
  }

  void _selectScenario(String scenarioId) {
    // Mark as visited for "New!" badge tracking
    if (!_visitedScenarioIds.contains(scenarioId)) {
      setState(() => _visitedScenarioIds.add(scenarioId));
      const OnboardingService().markScenarioVisited(scenarioId);
    }
    setState(() {
      _selectedScenario = scenarioId;
      widget.wizardData.selectedScenario = scenarioId;
      if (scenarioId != 'big_feelings_quest') {
        widget.wizardData.selectedFeeling = null;
        widget.wizardData.selectedTrigger = null;
        widget.wizardData.selectedBodySignal = null;
        widget.wizardData.selectedCopingTool = null;
        widget.wizardData.selectedEmotionChips = [];
      }

      // Auto-map therapeutic scenarios to life challenges
      final challengeMap = {
        'brave_friend': 'Making New Friends',
        'standing_tall': 'Building Confidence',
        'big_feelings_quest': 'Handling Big Feelings',
        'change_is_coming': 'Dealing with Change',
      };

      if (challengeMap.containsKey(scenarioId)) {
        widget.wizardData.lifeChallenge = challengeMap[scenarioId];
        debugPrint(
            '🪄 Auto-mapped scenario $scenarioId to challenge: ${widget.wizardData.lifeChallenge}');
      }
    });
  }

  bool get _canContinue => _selectedScenario != null;

  /// True when Big Feelings Quest is selected but no feeling data has been
  /// gathered yet — triggers the flow on Continue rather than on card tap.
  bool get _needsFeelingsFlow =>
      _selectedScenario == 'big_feelings_quest' &&
      (widget.wizardData.selectedFeeling == null &&
          widget.wizardData.selectedEmotionChips.isEmpty);

  /// Continue handler — runs the feelings flow first if needed, then advances.
  Future<void> _handleContinue() async {
    if (_needsFeelingsFlow) {
      await _openFeelingsQuest();
      if (!mounted) return;
      // Only advance if the user completed the feelings flow (not cancelled).
      final completed = widget.wizardData.selectedFeeling != null ||
          widget.wizardData.selectedEmotionChips.isNotEmpty;
      if (!completed) return;
    }
    widget.wizardData.interactiveMode = true;
    widget.onNext();
  }

  /// Opens the Feelings Quest cloud picker, then auto-selects the scenario.
  Future<void> _openFeelingsQuest() async {
    final age = widget.wizardData.characterAge <= 0
        ? 8
        : widget.wizardData.characterAge;
    final usesAges6To8Vocabulary = age >= 6 && age <= 8;
    if (age <= 5) {
      final result = await BigFeelingsFlowScreen.show(
        context,
        childAge: age,
        gender: widget.wizardData.characterGender,
      );
      if (result != null && mounted) {
        setState(() {
          widget.wizardData.selectedFeeling = result.feeling;
          widget.wizardData.selectedTrigger = result.trigger;
          widget.wizardData.selectedBodySignal = result.bodySignal;
          widget.wizardData.selectedCopingTool = result.copingTool;
          widget.wizardData.selectedEmotionChips = [result.feeling];
        });
        _selectScenario('big_feelings_quest');
      }
      return;
    }
    final result = await FeelingsQuestModal.show(context, childAge: age);
    if (result != null && mounted) {
      setState(() {
        widget.wizardData.selectedEmotionChips = result;
        if (usesAges6To8Vocabulary && result.isNotEmpty) {
          widget.wizardData.selectedFeeling = result.last;
        }
      });
      _selectScenario('big_feelings_quest');
    }
  }

  Widget _buildSlider(String leftLabel, String rightLabel, String key,
      Map<String, int> sliders) {
    final value = sliders[key]?.toDouble() ?? 50.0;
    final age = widget.wizardData.characterAge;
    final isYoung = age <= 8;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel,
                style: TextStyle(
                    fontSize: isYoung ? 13 : 12,
                    fontWeight: isYoung ? FontWeight.bold : FontWeight.w500,
                    color: isYoung ? AppColors.textDark : Colors.black87)),
            Text(rightLabel,
                style: TextStyle(
                    fontSize: isYoung ? 13 : 12,
                    fontWeight: isYoung ? FontWeight.bold : FontWeight.w500,
                    color: isYoung ? AppColors.textDark : Colors.black87)),
          ],
        ),
        Row(
          children: [
            if (isYoung) ...[
              Text(_sliderStartEmoji(key),
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Semantics(
                slider: true,
                label: '$leftLabel to $rightLabel',
                value: '${value.round()} percent',
                child: Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                  onChanged: (newValue) {
                    setState(() {
                      sliders[key] = newValue.round();
                    });
                  },
                ),
              ),
            ),
            if (isYoung) ...[
              const SizedBox(width: 8),
              Text(_sliderEndEmoji(key), style: const TextStyle(fontSize: 22)),
            ],
          ],
        ),
      ],
    );
  }

  String _sliderStartEmoji(String traitKey) {
    const map = {
      'energy': '😴',
      'sociability': '🙈',
      'creativity': '📖',
      'confidence': '🤫',
      'empathy': '🤐',
      'adventurousness': '🛋️',
      'adventure': '🛋️',
      'expressiveness': '😴',
    };
    return map[traitKey.toLowerCase()] ?? '😐';
  }

  String _sliderEndEmoji(String traitKey) {
    const map = {
      'energy': '⚡',
      'sociability': '🎉',
      'creativity': '🎨',
      'confidence': '🦁',
      'empathy': '💖',
      'adventurousness': '🚀',
      'adventure': '🚀',
      'expressiveness': '⚡',
    };
    return map[traitKey.toLowerCase()] ?? '😊';
  }

  /// Returns the user's avatar image data (base64 data URI or asset path) for
  /// overlaying on scenario cards, or null if no avatar is set.
  String? get _avatarImageData {
    final avatar = widget.wizardData.generatedAvatar;
    if (avatar != null && avatar.imageBase64.isNotEmpty) {
      return avatar.imageBase64;
    }
    return widget.wizardData.selectedCharacterAssetPath;
  }

  String _buildScenarioSpokenText() {
    final scenarioNames = _scenarios
        .map((s) => s.titleForAge(
              widget.wizardData.characterAge <= 0
                  ? 5
                  : widget.wizardData.characterAge,
            ))
        .join(', ');
    final age = widget.wizardData.characterAge <= 0 ? 5 : widget.wizardData.characterAge;
    final currentBand = ageBandFromAge(age);
    if (age <= 5) {
      return 'Pick a place for your story. You can choose $scenarioNames. Swipe through the pictures and tap the one you want!';
    }
    if (currentBand == AgeBand.adolescent || currentBand == AgeBand.adult) {
      return 'Choose a story premise. Options include: $scenarioNames.';
    }
    return 'Choose your adventure! Where shall we go today? You can pick $scenarioNames. Swipe through the cards and tap the one you like!';
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _swipeHintTimer?.cancel();
    for (final c in _carouselControllers.values) {
      c.dispose();
    }
    _parentalNoteController.dispose();
    _safeSpaceController.dispose();
    _mathController.dispose();
    _avoidController.dispose();
    super.dispose();
  }

  // ── Sprout tap-to-hear / tap-to-select ────────────────────────────────────

  void _previewScenario(ScenarioCard scenario, int age) {
    _previewTimer?.cancel();
    setState(() => _previewedScenarioId = scenario.id);
    // Speak the title and play an ambient sound preview.
    AppTtsService.instance.speak(scenario.titleForAge(age), rateScale: 0.8);
    final sfx = _sproutScenarioSfx[scenario.id];
    if (sfx != null) {
      AudioAmbienceService().playSfx(sfx);
    }
    // Auto-clear after 4 s so a second tap elsewhere still works.
    _previewTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _previewedScenarioId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final age = widget.wizardData.characterAge <= 0
        ? 5
        : widget.wizardData.characterAge;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title with parental gear icon
            Row(
              children: [
                MagicEarButton(
                  spokenText: _buildScenarioSpokenText(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    themeForAge(age).scenarioPageTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Parental override gear icon
                Semantics(
                  button: true,
                  toggled: _showParentalInput,
                  label:
                      'Guardian Mode. ${_showParentalInput ? "Open. Double tap to close" : "Closed. Double tap to open"}',
                  child: IconButton(
                    icon: Icon(
                      _showParentalInput ? Icons.close : Icons.shield_outlined,
                      color: _showParentalInput
                          ? AppColors.primary
                          : AppColors.textDark.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      // FR-03 (Audit 14): only ask the parent check the first
                      // time on this screen. Re-opening Guardian Mode after it
                      // was already passed should not re-interrogate the parent.
                      // The barrier still gates the first open of each new wizard
                      // session (fresh screen = fresh gate).
                      if (!_showParentalInput && !_mathGatePassed) {
                        _resetMathGate();
                      }
                      setState(() => _showParentalInput = !_showParentalInput);
                    },
                    tooltip: 'Guardian Mode',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            Text(
              themeForAge(age).scenarioPageSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Parental input (if shown)
            if (_showParentalInput) ...[
              _buildGuardianModeContainer(age),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Scenario carousels grouped by category
            ..._buildScenarioSections(age),

            // Safe Space Input (Conditional)
            if (_selectedScenario == 'safe_space') ...[
              const SizedBox(height: AppSpacing.md),
              BandAdaptiveImagineIt(wizardData: widget.wizardData),
              const SizedBox(height: AppSpacing.lg),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // Continue button
            if (_canContinue)
              Center(
                key: const Key('wizard_continue_scenario'),
                child: ImageContinueButton(
                  onTap: _handleContinue,
                  ageBand: ageBandFromAge(widget.wizardData.characterAge),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String _guardianModeDescription(int age) {
    final band = ageBandFromAge(age);
    switch (band) {
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
        return 'Personalize the adventure to support your child\'s growth.';
      case AgeBand.creator:
      case AgeBand.adolescent:
        return 'Shape the adventure around what feels real, supportive, or useful tonight.';
      case AgeBand.adult:
        return 'Tune the adventure around the tone, challenge, or reflection you want tonight.';
    }
  }

  String _guardianFocusTitle(int age) {
    final band = ageBandFromAge(age);
    switch (band) {
      case AgeBand.adult:
        return 'Tonight\'s Story Focus';
      case AgeBand.creator:
      case AgeBand.adolescent:
        return 'Tonight\'s Focus';
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
        return 'Today\'s Heart Focus';
    }
  }

  List<String> _guardianFocusOptions(int age) {
    final band = ageBandFromAge(age);
    switch (band) {
      case AgeBand.creator:
      case AgeBand.adolescent:
        return const [
          'Building Confidence',
          'Dealing with Change',
          'Finding Your Voice',
          'Handling Big Feelings',
          'Friendship Tension',
          'Belonging',
          'Trusting Yourself',
          'Patience & Waiting',
        ];
      case AgeBand.adult:
        return const [
          'Dealing with Change',
          'Finding Your Voice',
          'Burnout & Rest',
          'Belonging',
          'Trusting Yourself',
          'Setting Boundaries',
          'Starting Over',
          'Handling Big Feelings',
        ];
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
        return const [
          'Making New Friends',
          'Starting School',
          'Sibling Rivalry',
          'Handling Big Feelings',
          'Trying New Foods',
          'Sharing Toys',
          'Being Brave at Night',
          'Patience & Waiting',
          'Building Confidence',
          'Dealing with Change',
        ];
    }
  }

  String _guardianNoteTitle(int age) {
    final band = ageBandFromAge(age);
    switch (band) {
      case AgeBand.adult:
      case AgeBand.creator:
      case AgeBand.adolescent:
        return 'Story Note';
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
        return 'Parental Note';
    }
  }

  String _guardianNoteHint(int age) {
    final band = ageBandFromAge(age);
    switch (band) {
      case AgeBand.adult:
        return 'e.g., Keep it calm, reflective, and focused on starting over';
      case AgeBand.creator:
        return 'e.g., Keep it grounded and focused on confidence at school';
      case AgeBand.adolescent:
        return 'e.g., Keep it honest and focused on starting over after a hard week';
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
        return 'e.g., Help with sharing during playdates';
    }
  }

  Widget _buildGuardianModeContainer(int age) {
    final focusOptions = _guardianFocusOptions(age);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Guardian Mode',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _guardianModeDescription(age),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textDark.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
          ),
          const Divider(height: 32, thickness: 1.5),

          // 1. Life Challenges
          Row(
            children: [
              const Text('❤️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                _guardianFocusTitle(age),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: focusOptions.map((challenge) {
              final isSelected = widget.wizardData.lifeChallenge == challenge;
              return Semantics(
                button: true,
                selected: isSelected,
                label:
                    "$challenge. ${isSelected ? 'Selected' : 'Double tap to select'}",
                child: ChoiceChip(
                  label: Text(challenge),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      widget.wizardData.lifeChallenge =
                          selected ? challenge : null;
                    });
                  },
                  selectedColor: AppColors.gold,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.textDark
                        : AppColors.textDark.withValues(alpha: 0.8),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Personality Sliders
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Hero Personality',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final age = widget.wizardData.characterAge;
            final isExplorer = age >= 5 && age <= 7;

            // Unified definitions
            PersonalitySliderDefinition def(String key) =>
                CharacterTraitsData.personalitySliders
                    .firstWhere((s) => s.key == key);

            final dAdventure = def('adventure');
            final dSociability = def('sociability');
            final dExpressiveness = def('expressiveness');
            final dCreativity = def('problem_solving');

            return Column(
              children: [
                _buildSlider(
                  dAdventure.leftLabelForAge(age),
                  dAdventure.rightLabelForAge(age),
                  'adventure',
                  widget.wizardData.personalitySliders,
                ),
                _buildSlider(
                  dSociability.leftLabelForAge(age),
                  dSociability.rightLabelForAge(age),
                  'sociability',
                  widget.wizardData.personalitySliders,
                ),
                _buildSlider(
                  dExpressiveness.leftLabelForAge(age),
                  dExpressiveness.rightLabelForAge(age),
                  'expressiveness',
                  widget.wizardData.personalitySliders,
                ),
                // Only show 4th slider if older than Explorer band
                if (!isExplorer)
                  _buildSlider(
                    dCreativity.leftLabelForAge(age),
                    dCreativity.rightLabelForAge(age),
                    'problem_solving',
                    widget.wizardData.personalitySliders,
                  ),
              ],
            );
          }),

          const SizedBox(height: AppSpacing.lg),

          // 3. Custom Note
          Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                _guardianNoteTitle(age),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: "${_guardianNoteTitle(age)} for story guidance",
            textField: true,
            child: TextField(
              controller: _parentalNoteController,
              // Explicit dark text: the field has a white fill but the app's
              // dark theme would otherwise render typed text white-on-white
              // (invisible). hintStyle was already dark; the input style was not.
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: _guardianNoteHint(age),
                hintStyle: TextStyle(
                    color: AppColors.textDark.withValues(alpha: 0.4),
                    fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
              onChanged: (value) {
                widget.wizardData.parentalNote = value;
              },
            ),
          ),

          const Divider(height: 32, thickness: 1.5),

          // 4. Story DNA — Math Gate
          _buildStoryDnaSection(),
        ],
      ),
    );
  }

  Widget _buildStoryDnaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🧬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Story DNA',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Answer a quick question to unlock deeper story customisation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textDark.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 16),
        if (!_mathGatePassed) ...[
          // Math gate
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick parent check: What is $_mathA + $_mathB?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: "Answer: what is $_mathA plus $_mathB",
                        textField: true,
                        child: TextField(
                          controller: _mathController,
                          keyboardType: TextInputType.number,
                          // Dark text on the cream fill (theme default is
                          // white, which would be invisible here).
                          style: const TextStyle(
                              color: AppColors.textDark, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Your answer…',
                            hintStyle: TextStyle(
                                color:
                                    AppColors.textDark.withValues(alpha: 0.4),
                                fontSize: 14),
                            filled: true,
                            fillColor: AppColors.cream,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(
                                  color: _mathWrong
                                      ? Colors.red
                                      : AppColors.primary
                                          .withValues(alpha: 0.3)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _checkMathAnswer(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _checkMathAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      child: const Text('Unlock'),
                    ),
                  ],
                ),
                if (_mathWrong) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Not quite — try again!',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          // Story DNA questions (unlocked)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_open,
                        size: 16, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text('Story DNA Unlocked ✨',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),

                // Q1: What's on their mind?
                Text(
                  "What's in ${widget.wizardData.characterName.isEmpty ? 'their' : widget.wizardData.characterName}'s world right now?",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'First day at school',
                    'Starting new class',
                    'Moving house',
                    'New sibling',
                    'Lost something',
                    'Feeling left out',
                    'Friend trouble',
                    'Big test coming',
                  ].map((ctx) {
                    final sel = widget.wizardData.storyDnaContext == ctx;
                    return Semantics(
                      button: true,
                      selected: sel,
                      label:
                          "$ctx. ${sel ? 'Selected' : 'Double tap to select'}",
                      child: ChoiceChip(
                        label: Text(ctx),
                        selected: sel,
                        onSelected: (v) => setState(() =>
                            widget.wizardData.storyDnaContext = v ? ctx : null),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Q2: What magic would help?
                Text(
                  'What outcome would feel magical?',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Feel braver',
                    'Make new friends',
                    'Calm big feelings',
                    'Try something new',
                    'Feel understood',
                    'Stand up for myself',
                  ].map((outcome) {
                    final sel = widget.wizardData.storyDnaOutcome == outcome;
                    return Semantics(
                      button: true,
                      selected: sel,
                      label:
                          "$outcome. ${sel ? 'Selected' : 'Double tap to select'}",
                      child: ChoiceChip(
                        label: Text(outcome),
                        selected: sel,
                        onSelected: (v) => setState(() => widget
                            .wizardData.storyDnaOutcome = v ? outcome : null),
                        selectedColor: AppColors.gold.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Q3: Topics to avoid
                Text(
                  'Any words or topics to skip? (optional)',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: "Topics to avoid in the story",
                  textField: true,
                  child: TextField(
                    controller: _avoidController,
                    // Dark text on the cream fill (theme default is white,
                    // which would be invisible here).
                    style: const TextStyle(
                        color: AppColors.textDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g., spiders, loud noises, clowns',
                      hintStyle: TextStyle(
                          color: AppColors.textDark.withValues(alpha: 0.4),
                          fontSize: 13),
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    maxLines: 2,
                    onChanged: (v) => widget.wizardData.storyDnaAvoid = v,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // The 4 scenarios shown to sprouts (ages ≤5), in display order.
  // Chosen for maximum 3-5 year old appeal: dinosaurs, forest, castle, ocean.
  static const _sproutScenarioIds = [
    'volcano_dragons',  // Stomp with the Dinosaurs!
    'neon_jungle',      // The Magical Forest
    'storm_chaser_sky', // The Fluffy Cloud Castle
    'crystal_cavern',   // Under the Sea!
  ];

  /// Full-screen 2×2 grid for sprout band — no scroll, no category headers,
  /// no "Imagine It" card. Everything visible at once.
  ///
  /// Tap-to-hear pattern: first tap speaks the title + plays a sound preview;
  /// second tap (or a tap on an already-previewing card) confirms selection.
  List<Widget> _buildSproutGrid(int age) {
    final sproutScenarios = _scenarios
        .where((s) => _sproutScenarioIds.contains(s.id))
        .toList()
      ..sort((a, b) => _sproutScenarioIds.indexOf(a.id)
          .compareTo(_sproutScenarioIds.indexOf(b.id)));

    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.88,
        children: sproutScenarios.map((scenario) {
          final isSelected = _selectedScenario == scenario.id;
          final isPreviewing = _previewedScenarioId == scenario.id;
          return _ScenarioCardWidget(
            scenario: scenario,
            isSelected: isSelected,
            isPreviewing: isPreviewing,
            childAge: age,
            avatarImageData: _avatarImageData,
            onTap: () {
              if (isPreviewing || isSelected) {
                // Second tap — confirm selection.
                _previewTimer?.cancel();
                setState(() => _previewedScenarioId = null);
                _selectScenario(scenario.id);
              } else {
                // First tap — speak title and play SFX preview.
                _previewScenario(scenario, age);
              }
            },
          );
        }).toList(),
      ),
    ];
  }

  /// Maps a raw scenario category string to the band-appropriate display label.
  String _categoryLabel(String category, AgeBandThemeData bandTheme) {
    if (category == 'Magical Worlds') return bandTheme.scenarioCategoryFantasyLabel;
    if (category == 'Real-Life Heroes') return bandTheme.scenarioCategoryRealLabel;
    return category;
  }

  List<Widget> _buildScenarioSections(int age) {
    final currentBand = ageBandFromAge(age);

    // Sprout band gets its own simplified 2×2 grid — no carousel, no featured card.
    if (currentBand == AgeBand.sprout) return _buildSproutGrid(age);

    // Sprout (≤5) and Explorer (6-8) only see Magical Worlds — Real-Life Heroes
    // are too abstract/heavy for under-9s.
    // Adults skip the Big Feelings Quest — it's designed for children.
    // All bands: filter out scenarios with a minBand above the current band;
    // for young bands (≤8) keep them as aspirational locked teasers.
    final lockedScenarios = (age <= 8)
        ? _scenarios.where((s) =>
            s.minBand != null && s.minBand!.index > currentBand.index).toList()
        : <ScenarioCard>[];

    final visibleScenarios = _scenarios.where((s) {
      // Featured scenarios (e.g. "Imagine It") are always visible regardless of category.
      if (age <= 8 && s.category == 'Real-Life Heroes' && !s.featured) return false;
      if (currentBand == AgeBand.adult && s.id == 'big_feelings_quest') return false;
      if (s.minBand != null && s.minBand!.index > currentBand.index) return false;
      return true;
    }).toList();

    // Separate featured scenarios (pinned at top) from regular ones.
    final featured = visibleScenarios.where((s) => s.featured).toList();
    var regular = visibleScenarios.where((s) => !s.featured).toList();

    // For adolescent/adult bands: sort so band-exclusive scenarios appear first
    // within each category, surfacing the most mature/relevant content.
    if (currentBand == AgeBand.adolescent || currentBand == AgeBand.adult) {
      regular = [
        ...regular.where((s) =>
            s.minBand != null && s.minBand!.index >= AgeBand.creator.index),
        ...regular.where((s) =>
            s.minBand == null || s.minBand!.index < AgeBand.creator.index),
      ];
    }

    final Map<String, List<ScenarioCard>> grouped = {};
    for (var scenario in regular) {
      grouped.putIfAbsent(scenario.category, () => []).add(scenario);
    }

    final List<Widget> sections = [];

    // Featured scenarios — rendered as a prominent full-width card at the top.
    for (final scenario in featured) {
      final isSelected = _selectedScenario == scenario.id;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ScenarioCardWidget(
            scenario: scenario,
            isSelected: isSelected,
            childAge: age,
            isFeatured: true,
            avatarImageData: _avatarImageData,
            onTap: () => _selectScenario(scenario.id),
          ),
        ),
      );
    }

    grouped.forEach((category, scenarios) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _categoryLabel(category, themeForAge(age)),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildCarouselWithHint(
                key: category,
                count: scenarios.length,
                itemBuilder: (index) {
                  final scenario = scenarios[index];
                  final isSelected = _selectedScenario == scenario.id;
                  return _ScenarioCardWidget(
                    scenario: scenario,
                    isSelected: isSelected,
                    childAge: age,
                    avatarImageData: _avatarImageData,
                    showAdventurerBadge: scenario.minBand != null &&
                        currentBand.index >= scenario.minBand!.index,
                    showMissionHook:
                        currentBand.index >= AgeBand.adventurer.index,
                    isNew: !_visitedScenarioIds.contains(scenario.id),
                    useParallax: true,
                    onTap: () => _selectScenario(scenario.id),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });

    // Locked scenario teasers — aspirational pull for young bands (≤8).
    if (lockedScenarios.isNotEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coming Soon For You',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildCarouselWithHint(
                key: '__locked__',
                count: lockedScenarios.length,
                itemBuilder: (index) => _ScenarioCardWidget(
                  scenario: lockedScenarios[index],
                  isSelected: false,
                  childAge: age,
                  isLocked: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      );
    }

    return sections;
  }

  /// Wraps a horizontal carousel with right-edge peek and a first-use swipe hint.
  /// Sprout band uses a grid, not a carousel, so this is never called for sprout.
  Widget _buildCarouselWithHint({
    required String key,
    required int count,
    required Widget Function(int index) itemBuilder,
  }) {
    final controller = _carouselControllers.putIfAbsent(
      key,
      () {
        final c = ScrollController();
        c.addListener(() {
          if (!c.hasClients) return;
          final cardStep = _settingCardWidth + AppSpacing.md;
          final dot = (c.offset / cardStep).round().clamp(0, count - 1);
          if (_carouselActiveDot[key] != dot) {
            setState(() => _carouselActiveDot[key] = dot);
          }
          // First scroll interaction dismisses the hint permanently
          if (!_swipeHintShown) _dismissSwipeHint();
        });
        return c;
      },
    );
    final activeDot = _carouselActiveDot[key] ?? 0;

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            // Right padding exposes ~40 px of the next card as a peek affordance
            padding: const EdgeInsets.only(left: 4, right: 48, top: 10, bottom: 10),
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, index) => itemBuilder(index),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 6),
          AnimatedOpacity(
            opacity: _swipeHintShown ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chevron_left, size: 16, color: Colors.white38),
                const SizedBox(width: 4),
                for (int i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: activeDot == i ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeDot == i
                          ? Colors.white70
                          : Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.white38),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ScenarioCardWidget extends StatelessWidget {
  final ScenarioCard scenario;
  final bool isSelected;
  final bool isPreviewing;
  final int childAge;
  final VoidCallback onTap;
  final bool isFeatured;
  /// Scenario is above the user's band — show as a greyed-out teaser.
  final bool isLocked;
  /// User is in the qualifying band — show the "Adventurer Exclusive" badge.
  final bool showAdventurerBadge;
  /// User is Adventurer+; show the one-line conflict hook below the description.
  final bool showMissionHook;
  /// Scenario has never been tapped — show a "New!" sparkle badge.
  final bool isNew;
  /// Wrap in ParallaxTiltCard for 3-D movie-poster effect (carousel only).
  final bool useParallax;
  /// User's character avatar image data (base64 or asset path) to overlay on scene.
  final String? avatarImageData;

  const _ScenarioCardWidget({
    required this.scenario,
    required this.isSelected,
    required this.childAge,
    required this.onTap,
    this.isPreviewing = false,
    this.isFeatured = false,
    this.isLocked = false,
    this.showAdventurerBadge = false,
    this.showMissionHook = false,
    this.isNew = false,
    this.useParallax = false,
    this.avatarImageData,
  });

  @override
  Widget build(BuildContext context) {
    final title = scenario.titleForAge(childAge);
    final description = scenario.descriptionForAge(childAge);
    final isSprout = childAge <= 5 && !isFeatured;
    final illustrationPath = scenario.illustrationForAge(childAge);
    final resolvedPath = illustrationPath.startsWith('assets/')
        ? illustrationPath
        : 'assets/$illustrationPath';

    Widget imageWidget(double? width, double? height) {
      final sceneImage = SafeAssetImage(
        resolvedPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.5)
                : AppColors.secondaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              scenario.emoji,
              style: TextStyle(fontSize: isSprout ? 52 : 48),
            ),
          ),
        ),
      );

      if (avatarImageData == null) return sceneImage;

      // Overlay the user's character on the scene
      final avatarHeight = (height ?? 140) * 0.6;
      ImageProvider avatarProvider;
      if (avatarImageData!.startsWith('data:') || avatarImageData!.contains('base64')) {
        final b64 = avatarImageData!.contains(',')
            ? avatarImageData!.split(',').last
            : avatarImageData!;
        avatarProvider = MemoryImage(base64Decode(b64));
      } else if (avatarImageData!.startsWith('assets/')) {
        avatarProvider = AssetImage(avatarImageData!);
      } else {
        return sceneImage;
      }

      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            sceneImage,
            // Character silhouette with subtle glow
            Positioned(
              bottom: 4,
              right: isSprout ? null : 8,
              left: isSprout ? 0 : null,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image(
                  image: avatarProvider,
                  height: avatarHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget card = Semantics(
      button: !isLocked,
      selected: isSelected,
      label: isLocked
          ? '$title — unlocks at age 9'
          : isSprout
              ? title
              : '$title, $description',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: (isFeatured || isSprout) ? double.infinity : _settingCardWidth,
          padding: EdgeInsets.symmetric(
            horizontal: isSprout ? AppSpacing.xs : AppSpacing.sm,
            vertical: isSprout ? AppSpacing.xs : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.gold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : isPreviewing
                    ? LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.25),
                          AppColors.gradientMid,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientMid],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : isPreviewing
                      ? AppColors.gold.withValues(alpha: 0.8)
                      : AppColors.primary.withValues(alpha: 0.3),
              width: isSelected || isPreviewing ? 3 : 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 3,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: isSprout
              // ── Sprout tile: big image fills the card, bold title below ──
              ? Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imageWidget(double.infinity, null),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected
                                      ? AppColors.textDark
                                      : Colors.white,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Speaker icon overlay during preview (tap-to-hear state).
                    if (isPreviewing && !isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                )
              // ── Standard tile: image + emoji + title + description ──
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageWidget(200, 140),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(scenario.emoji),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppColors.textDark
                                      : Colors.white,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? AppColors.textDark.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showMissionHook) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        scenario.conflictHookForAge(childAge),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? AppColors.textDark.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.65),
                              fontStyle: FontStyle.italic,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );

    // Adventurer Exclusive badge — overlay on top-right corner.
    if (showAdventurerBadge && scenario.minBand != null) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: 8,
            right: 8,
            child: AgeBandBadge(minBand: scenario.minBand!),
          ),
        ],
      );
    }

    // Locked teaser — greyed out with lock icon overlay.
    if (isLocked) {
      card = Stack(
        children: [
          Opacity(opacity: 0.45, child: card),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 32, color: Colors.white70),
                  const SizedBox(height: 6),
                  Text(
                    'Unlock at age 9+',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // "New!" badge — shown when the scenario has never been tapped, not locked.
    if (isNew && !isLocked && !isFeatured) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: -6,
            left: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Text(
                'New!',
                style: TextStyle(
                  color: Color(0xFF3E2723),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (useParallax) {
      card = ParallaxTiltCard(maxTiltDegrees: 6, child: card);
    }

    return card;
  }
}
