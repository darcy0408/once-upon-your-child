import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../theme/age_band_theme.dart';
import '../../widgets/image_continue_button.dart';
import '../../widgets/feelings_quest_modal.dart';
import '../../data/scenario_data.dart';
import '../../character_traits_data.dart';
import '../../widgets/magic_ear_button.dart';
import '../big_feelings_flow_screen.dart';

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

class _FeelingSelectionStepState extends State<FeelingSelectionStep> {
  String? _selectedScenario;
  bool _showParentalInput = false;
  final TextEditingController _parentalNoteController = TextEditingController();
  final TextEditingController _safeSpaceController = TextEditingController();
  final TextEditingController _mathController = TextEditingController();
  final TextEditingController _avoidController = TextEditingController();

  // Voice input for Imagine It field (young children only)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

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

  /// Opens the Feelings Quest cloud picker, then auto-selects the scenario.
  Future<void> _openFeelingsQuest() async {
    final age = widget.wizardData.characterAge <= 0
        ? 8
        : widget.wizardData.characterAge;
    final usesAges6To8Vocabulary = age >= 6 && age <= 8;
    if (age <= 5) {
      final result = await BigFeelingsFlowScreen.show(context, childAge: age);
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

  String _buildScenarioSpokenText() {
    final scenarioNames = _scenarios
        .map((s) => s.titleForAge(
              widget.wizardData.characterAge <= 0
                  ? 5
                  : widget.wizardData.characterAge,
            ))
        .join(', ');
    if (widget.wizardData.characterAge <= 5) {
      return 'Pick a place for your story. You can choose $scenarioNames. Swipe through the pictures and tap the one you want!';
    }
    return 'Choose your adventure! Where shall we go today? You can pick $scenarioNames. Swipe through the cards and tap the one you like!';
  }

  @override
  void dispose() {
    _speech.stop();
    _parentalNoteController.dispose();
    _safeSpaceController.dispose();
    _mathController.dispose();
    _avoidController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            setState(() {
              _safeSpaceController.text = result.recognizedWords;
              widget.wizardData.customElements = result.recognizedWords;
              _isListening = false;
            });
          }
        },
        listenFor: const Duration(seconds: 15),
      );
    }
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
                    'Choose Your Adventure!',
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
                      if (!_showParentalInput) _resetMathGate();
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
              'Where shall we go today?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Parental input (if shown)
            if (_showParentalInput) ...[
              _buildGuardianModeContainer(),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Scenario carousels grouped by category
            ..._buildScenarioSections(age),

            // Safe Space Input (Conditional)
            if (_selectedScenario == 'safe_space') ...[
              const SizedBox(height: AppSpacing.md),
              _buildSafeSpaceInput(),
              const SizedBox(height: AppSpacing.lg),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // Continue button
            if (_canContinue)
              Center(
                key: const Key('wizard_continue_scenario'),
                child: ImageContinueButton(
                  onTap: widget.onNext,
                  ageBand: ageBandFromAge(widget.wizardData.characterAge),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeSpaceInput() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤫', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Let your imagination go wild...',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Picture any place you can imagine — a world, a feeling, an adventure. Tell us and we\'ll make a story just for you!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textDark.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _safeSpaceController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g., A enchanted forest, outer space, under the ocean...',
              hintStyle: TextStyle(
                color: AppColors.textDark.withValues(alpha: 0.4),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.primary.withValues(alpha: 0.05),
              suffixIcon: widget.wizardData.characterAge <= 8
                  ? IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : AppColors.primary,
                      ),
                      tooltip: _isListening ? 'Stop listening' : 'Speak your answer',
                      onPressed: _toggleVoiceInput,
                    )
                  : null,
            ),
            onChanged: (value) {
              widget.wizardData.customElements = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianModeContainer() {
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
            'Personalize the adventure to support your child\'s growth.',
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
                'Today\'s Heart Focus',
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
            children: [
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
            ].map((challenge) {
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
                'Parental Note',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: "Parental note for story guidance",
            textField: true,
            child: TextField(
              controller: _parentalNoteController,
              decoration: InputDecoration(
                hintText: 'e.g., Help with sharing during playdates',
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

  List<Widget> _buildScenarioSections(int age) {
    // Sprout (≤5) only sees Magical Worlds — Real-Life Heroes are too abstract
    final visibleScenarios = age <= 5
        ? _scenarios.where((s) => s.category == 'Magical Worlds').toList()
        : _scenarios;

    final Map<String, List<ScenarioCard>> grouped = {};
    for (var scenario in visibleScenarios) {
      grouped.putIfAbsent(scenario.category, () => []).add(scenario);
    }

    final List<Widget> sections = [];
    grouped.forEach((category, scenarios) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 320, // Increased height to prevent overflow
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: scenarios.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    final isSelected = _selectedScenario == scenario.id;

                    return _ScenarioCardWidget(
                      scenario: scenario,
                      isSelected: isSelected,
                      childAge: age,
                      onTap: scenario.id == 'big_feelings_quest'
                          ? _openFeelingsQuest
                          : () => _selectScenario(scenario.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
    return sections;
  }
}

class _ScenarioCardWidget extends StatelessWidget {
  final ScenarioCard scenario;
  final bool isSelected;
  final int childAge;
  final VoidCallback onTap;

  const _ScenarioCardWidget({
    required this.scenario,
    required this.isSelected,
    required this.childAge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = scenario.titleForAge(childAge);
    final description = scenario.descriptionForAge(childAge);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, $description',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _settingCardWidth, // Slightly wider to accommodate text
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.gold],
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
                  : AppColors.primary.withValues(alpha: 0.3),
              width: isSelected ? 3 : 2,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Wrap content
            children: [
              // Scenario illustration image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  scenario.illustration,
                  width: 200,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 200,
                    height: 140,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.secondaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        scenario.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                ),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected ? AppColors.textDark : Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}
