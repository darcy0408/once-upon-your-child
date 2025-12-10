import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/character_preview.dart';
import '../../widgets/pill_button.dart';
import '../wizard_story_screen.dart';

/// Step 1: The Hero Creator
///
/// Layout:
/// - Top 50%: Large character preview with sparkles
/// - Bottom 50%: Archetype selection cards in horizontal scroll
/// - Continue button appears when archetype selected
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
  String? _selectedArchetypeId;
  String _characterEmoji = '👧';

  void _selectArchetype(ArchetypeData archetype) {
    setState(() {
      _selectedArchetypeId = archetype.name;
      _characterEmoji = archetype.icon;

      // Auto-fill wizard data with archetype
      widget.wizardData.selectedArchetypeId = archetype.name;
      widget.wizardData.personalitySliders = Map.from(archetype.attributes);
      widget.wizardData.characterName = archetype.name.replaceAll('The ', '');
    });
  }

  bool get _canContinue => _selectedArchetypeId != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top 50%: Character Preview
        Expanded(
          child: CharacterPreview(
            placeholderEmoji: _characterEmoji,
            showSparkles: true,
          ),
        ),

        // Bottom 50%: Archetype Selection
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              children: [
                // Title
                Text(
                  'Create a Character',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'Choose an archetype to start',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textDark.withAlpha(179), // 70% opacity
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Archetype cards (horizontal scroll)
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    itemCount: CharacterArchetypes.all.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final archetype = CharacterArchetypes.all[index];
                      final isSelected = _selectedArchetypeId == archetype.name;

                      return ArchetypeCard(
                        icon: archetype.icon,
                        name: archetype.name,
                        description: archetype.description,
                        traits: archetype.traits,
                        isSelected: isSelected,
                        onUseTemplate: () => _selectArchetype(archetype),
                      );
                    },
                  ),
                ),
                const Spacer(),

                // Continue button (only shown when archetype selected)
                if (_canContinue)
                  AnimatedOpacity(
                    opacity: _canContinue ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: PillButton(
                      emoji: '➡️',
                      label: 'Continue',
                      onTap: widget.onNext,
                      variant: PillButtonVariant.purple,
                      isSelected: true,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
