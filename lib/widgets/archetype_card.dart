import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ArchetypeCard - Displays character archetype templates
///
/// Design specs:
/// - Icon + name + trait chips
/// - "Use Template" button for quick character creation
/// - Tap to auto-fill character attributes
/// - Accessible with screen reader support
/// - Parent hover shows description (for parents, not kids)
class ArchetypeCard extends StatelessWidget {
  final String icon;
  final String name;
  final String description; // For parent tooltips only
  final List<String> traits;
  final VoidCallback onUseTemplate;
  final bool isSelected;

  const ArchetypeCard({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    required this.traits,
    required this.onUseTemplate,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name archetype, $description',
      hint: 'Tap to use this character template',
      child: Tooltip(
        message: description, // Shows on hover for parents
        waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          onTap: onUseTemplate,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 160, // Fixed width for horizontal scroll
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight.withAlpha(51) : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.goldLight.withAlpha(77), // 30% opacity
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(), // Prevent bounce effect on cards
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon/Emoji
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Archetype name
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Trait chips
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: traits.map((trait) => _TraitChip(label: trait)).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // "Use Template" button
                  ElevatedButton(
                    onPressed: onUseTemplate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'Use Template',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small trait chip for archetypes
class _TraitChip extends StatelessWidget {
  final String label;

  const _TraitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(51), // 20% opacity
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.gold.withAlpha(128), // 50% opacity
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

/// Predefined character archetypes
class CharacterArchetypes {
  static const adventurer = ArchetypeData(
    icon: '🗺️',
    name: 'The Adventurer',
    description: 'Brave, curious, and loves exploration',
    traits: ['Brave', 'Curious', 'Determined'],
    attributes: {
      'energy': 80,
      'sociability': 70,
      'creativity': 60,
      'confidence': 85,
      'empathy': 50,
      'adventurousness': 95,
    },
  );

  static const thinker = ArchetypeData(
    icon: '💭',
    name: 'The Thinker',
    description: 'Thoughtful, analytical, loves to learn',
    traits: ['Smart', 'Modest', 'Curious'],
    attributes: {
      'energy': 40,
      'sociability': 30,
      'creativity': 75,
      'confidence': 60,
      'empathy': 70,
      'adventurousness': 40,
    },
  );

  static const artist = ArchetypeData(
    icon: '🎨',
    name: 'The Artist',
    description: 'Creative, imaginative, loves colors',
    traits: ['Creative', 'Expressive', 'Hint'],
    attributes: {
      'energy': 60,
      'sociability': 50,
      'creativity': 95,
      'confidence': 70,
      'empathy': 80,
      'adventurousness': 55,
    },
  );

  static const helper = ArchetypeData(
    icon: '🤝',
    name: 'The Helper',
    description: 'Kind, empathetic, loves to support',
    traits: ['Caring', 'Patient', 'Loyal'],
    attributes: {
      'energy': 50,
      'sociability': 85,
      'creativity': 50,
      'confidence': 60,
      'empathy': 95,
      'adventurousness': 45,
    },
  );

  static const athlete = ArchetypeData(
    icon: '⚡',
    name: 'The Athlete',
    description: 'Energetic, competitive, loves team play',
    traits: ['Energetic', 'Empathy', 'Determined'],
    attributes: {
      'energy': 95,
      'sociability': 75,
      'creativity': 40,
      'confidence': 85,
      'empathy': 60,
      'adventurousness': 70,
    },
  );

  static const shyOne = ArchetypeData(
    icon: '😊',
    name: 'The Shy One',
    description: 'Quiet, observant, meaningful',
    traits: ['Thoughtful', 'Quirks', 'Observant'],
    attributes: {
      'energy': 35,
      'sociability': 25,
      'creativity': 70,
      'confidence': 40,
      'empathy': 85,
      'adventurousness': 30,
    },
  );

  static List<ArchetypeData> get all => [
        adventurer,
        thinker,
        artist,
        helper,
        athlete,
        shyOne,
      ];
}

class ArchetypeData {
  final String icon;
  final String name;
  final String description;
  final List<String> traits;
  final Map<String, int> attributes;

  const ArchetypeData({
    required this.icon,
    required this.name,
    required this.description,
    required this.traits,
    required this.attributes,
  });
}
