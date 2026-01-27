import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/expanding_feelings_wheel.dart';
import '../wizard_story_screen.dart';
import '../../data/scenario_data.dart';
import '../../feelings_wheel_data.dart';

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
  SelectedFeeling? _selectedFeeling;
  bool _showParentalInput = false;
  final TextEditingController _parentalNoteController = TextEditingController();

  final List<ScenarioCard> _scenarios = ScenarioData.all;

  void _selectScenario(String scenarioId) {
    setState(() {
      _selectedScenario = scenarioId;
      widget.wizardData.selectedScenario = scenarioId;
    });
  }

  void _selectFeeling(SelectedFeeling feeling) {
    setState(() {
      _selectedFeeling = feeling;
      widget.wizardData.selectedEmotionChips = [feeling.tertiary];
    });
  }

  bool get _canContinue =>
      _selectedScenario != null || _selectedFeeling != null;

  Widget _buildSlider(String leftLabel, String rightLabel, String key, Map<String, int> sliders) {
    final value = sliders[key]?.toDouble() ?? 50.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel, style: const TextStyle(fontSize: 12)),
            Text(rightLabel, style: const TextStyle(fontSize: 12)),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 10,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.primary.withAlpha(50),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final age = widget.wizardData.characterAge <= 0 ? 5 : widget.wizardData.characterAge;
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
                          fontFamily: 'Outfit', // Ensure nice font
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Parental override gear icon
                IconButton(
                  icon: Icon(
                    _showParentalInput ? Icons.close : Icons.settings,
                    color: AppColors.textDark.withAlpha(128), // 50% opacity
                  ),
                  onPressed: () {
                    setState(() => _showParentalInput = !_showParentalInput);
                  },
                  tooltip: 'Parent settings',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            Text(
              'Where shall we go today?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark.withAlpha(179), // 70% opacity
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Parental input (if shown)
            if (_showParentalInput) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Guardian Mode',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    // 1. Life Challenges
                    Text(
                      'Life Challenge (Therapeutic Focus)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
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
                      ].map((challenge) {
                        final isSelected = widget.wizardData.lifeChallenge == challenge;
                        return ChoiceChip(
                          label: Text(challenge),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              widget.wizardData.lifeChallenge = selected ? challenge : null;
                            });
                          },
                          selectedColor: AppColors.gold,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.textDark : AppColors.textDark.withAlpha(200),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 2. Personality Sliders
                    Text(
                      'Hero Personality',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildSlider(
                      'Cautious', 'Adventurous', 
                      'adventurousness', 
                      widget.wizardData.personalitySliders,
                    ),
                    _buildSlider(
                      'Serious', 'Silly', 
                      'creativity', // Using creativity as proxy for silly/serious for now
                      widget.wizardData.personalitySliders,
                    ),
                    _buildSlider(
                      'Shy', 'Social', 
                      'sociability', 
                      widget.wizardData.personalitySliders,
                    ),
                    _buildSlider(
                      'Calm', 'Energetic', 
                      'energy', 
                      widget.wizardData.personalitySliders,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 3. Custom Note
                    Text(
                      'Additional Notes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _parentalNoteController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Help with nail-biting habit',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        widget.wizardData.parentalNote = value;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Scenario carousel
            SizedBox(
              height: 320, // Increased height to prevent overflow
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                itemCount: _scenarios.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final scenario = _scenarios[index];
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
            const SizedBox(height: AppSpacing.xl),

            // Full therapeutic feelings wheel (Progressive Disclosure)
            Text(
              'How are you feeling?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap a feeling to explore deeper emotions.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxSize = constraints.maxWidth.clamp(280.0, 400.0);
                return Center(
                  child: SizedBox.square(
                    dimension: maxSize,
                    child: ExpandingFeelingsWheel(
                      onFeelingSelected: _selectFeeling,
                      backgroundColor: AppColors.cream,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (_selectedFeeling != null)
              Text(
                'Feeling: ${_selectedFeeling!.tertiary}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _selectedFeeling!.color,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: AppSpacing.xxl),

            // Continue button
            if (_canContinue)
              Center(
                child: PillButton(
                  emoji: '✨',
                  label: 'Start Adventure!',
                  onTap: widget.onNext,
                  variant: PillButtonVariant.purple,
                  isSelected: true,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
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
              color: isSelected ? AppColors.gold : AppColors.primary.withValues(alpha: 0.3),
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
                      color: isSelected ? Colors.white.withValues(alpha: 0.5) : AppColors.secondaryLight.withValues(alpha: 0.2),
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
