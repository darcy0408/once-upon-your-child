import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/image_continue_button.dart';
import '../../data/scenario_data.dart';

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

  final List<ScenarioCard> _scenarios = ScenarioData.all;

  @override
  void initState() {
    super.initState();
    _selectedScenario = widget.wizardData.selectedScenario;
    widget.wizardData.selectedEmotionChips = [];
    _safeSpaceController.text = widget.wizardData.customElements;
    _parentalNoteController.text = widget.wizardData.parentalNote ?? '';
  }

  void _selectScenario(String scenarioId) {
    setState(() {
      _selectedScenario = scenarioId;
      widget.wizardData.selectedScenario = scenarioId;

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

  Widget _buildSlider(String leftLabel, String rightLabel, String key,
      Map<String, int> sliders) {
    final value = sliders[key]?.toDouble() ?? 50.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(rightLabel,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        Slider(
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
      ],
    );
  }

  @override
  void dispose() {
    _parentalNoteController.dispose();
    _safeSpaceController.dispose();
    super.dispose();
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
                IconButton(
                  icon: Icon(
                    _showParentalInput ? Icons.close : Icons.shield_outlined,
                    color: _showParentalInput
                        ? AppColors.primary
                        : AppColors.textDark.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    setState(() => _showParentalInput = !_showParentalInput);
                  },
                  tooltip: 'Guardian Mode',
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
                child: ImageContinueButton(onTap: widget.onNext),
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
                'The Whisperer is Listening...',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Whisper a secret, a worry, or anything you\'re thinking about. We\'ll turn it into a magical adventure!',
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
                  'e.g., I\'m a little nervous about my first day of school...',
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
              return ChoiceChip(
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
          _buildSlider(
            'Cautious',
            'Adventurous',
            'adventurousness',
            widget.wizardData.personalitySliders,
          ),
          _buildSlider(
            'Quiet',
            'Social',
            'sociability',
            widget.wizardData.personalitySliders,
          ),
          _buildSlider(
            'Calm',
            'Energetic',
            'energy',
            widget.wizardData.personalitySliders,
          ),
          _buildSlider(
            'Serious',
            'Silly',
            'creativity',
            widget.wizardData.personalitySliders,
          ),

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
          TextField(
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
                borderSide:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 2,
            onChanged: (value) {
              widget.wizardData.parentalNote = value;
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScenarioSections(int age) {
    final Map<String, List<ScenarioCard>> grouped = {};
    for (var scenario in _scenarios) {
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
                      onTap: () => _selectScenario(scenario.id),
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
                            color: AppColors.textDark,
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
                      color: AppColors.textDark.withValues(alpha: 0.7),
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
