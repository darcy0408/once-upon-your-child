import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../wizard_story_screen.dart';

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
  final Set<String> _selectedEmotions = {};
  bool _showParentalInput = false;
  final TextEditingController _parentalNoteController = TextEditingController();

  final List<ScenarioCard> _scenarios = [
    ScenarioCard(
      id: 'school_jitters',
      emoji: '🎒',
      title: 'The First Day Quest',
      illustration: '🏫',
      description: 'A brave journey to a new place',
    ),
    ScenarioCard(
      id: 'big_feelings',
      emoji: '🐉',
      title: 'The Dragon Inside',
      illustration: '🔥',
      description: 'Taming the roars within',
    ),
    ScenarioCard(
      id: 'making_friends',
      emoji: '🤝',
      title: 'The Friendly Forest',
      illustration: '🌲',
      description: 'Finding new companions',
    ),
    ScenarioCard(
      id: 'being_brave',
      emoji: '🛡️',
      title: 'The Cave of Courage',
      illustration: '🦁',
      description: 'Facing the shadows',
    ),
    ScenarioCard(
      id: 'calm_moments',
      emoji: '☁️',
      title: 'The Cloud Castle',
      illustration: '🏰',
      description: 'Floating in peaceful skies',
    ),
    ScenarioCard(
      id: 'creative_ideas',
      emoji: '🎨',
      title: 'The Paintbrush Kingdom',
      illustration: '🌈',
      description: 'Coloring the world',
    ),
  ];

  final List<EmotionChip> _emotions = [
    EmotionChip(emoji: '✨', label: 'Shining Bright'),
    EmotionChip(emoji: '🦁', label: 'Brave Heart'),
    EmotionChip(emoji: '🤝', label: 'Friendly'),
    EmotionChip(emoji: '🌊', label: 'Peaceful'),
    EmotionChip(emoji: '🎨', label: 'Creative'),
    EmotionChip(emoji: '😊', label: 'Joyful'),
    EmotionChip(emoji: '😢', label: 'Blue'),
    EmotionChip(emoji: '😠', label: 'Stormy'),
  ];

  void _selectScenario(String scenarioId) {
    setState(() {
      _selectedScenario = scenarioId;
      widget.wizardData.selectedScenario = scenarioId;
    });
  }

  void _toggleEmotion(String emotion) {
    setState(() {
      if (_selectedEmotions.contains(emotion)) {
        _selectedEmotions.remove(emotion);
      } else {
        _selectedEmotions.add(emotion);
      }
      widget.wizardData.selectedEmotionChips = _selectedEmotions.toList();
    });
  }

  bool get _canContinue =>
      _selectedScenario != null || _selectedEmotions.isNotEmpty;

  @override
  void dispose() {
    _parentalNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Parent Note (Private)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                    onTap: () => _selectScenario(scenario.id),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Emotion chips
            Text(
              'Or how are you feeling?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _emotions.map((emotion) {
                final isSelected = _selectedEmotions.contains(emotion.label);
                return _EmotionChipWidget(
                  emotion: emotion,
                  isSelected: isSelected,
                  onTap: () => _toggleEmotion(emotion.label),
                );
              }).toList(),
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

class ScenarioCard {
  final String id;
  final String emoji;
  final String title;
  final String illustration;
  final String description;

  ScenarioCard({
    required this.id,
    required this.emoji,
    required this.title,
    required this.illustration,
    required this.description,
  });
}

class _ScenarioCardWidget extends StatelessWidget {
  final ScenarioCard scenario;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScenarioCardWidget({
    required this.scenario,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${scenario.title}, ${scenario.description}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 220, // Slightly wider to accommodate text
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Colors.white, Color(0xFFF8F9FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isSelected ? AppColors.gold : Colors.grey.shade200,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Wrap content
            children: [
              Container(
                padding: const EdgeInsets.all(8), // Reduced padding
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.5) : AppColors.secondaryLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  scenario.illustration,
                  style: const TextStyle(fontSize: 40), // Reduced font size
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
                      scenario.title,
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
                scenario.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textDark.withOpacity(0.7),
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

class EmotionChip {
  final String emoji;
  final String label;

  EmotionChip({required this.emoji, required this.label});
}

class _EmotionChipWidget extends StatelessWidget {
  final EmotionChip emotion;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmotionChipWidget({
    required this.emotion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${emotion.label} emotion chip',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                     BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emotion.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                emotion.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (isSelected) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.star_rounded, // Star instead of check
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
