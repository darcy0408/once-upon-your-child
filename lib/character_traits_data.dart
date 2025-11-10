import 'package:flutter/material.dart';

/// Shared character trait presets used across creation and edit flows.
class CharacterTraitsData {
  /// Suggested strengths that highlight how a character shines.
  static const List<String> strengths = [
    'Brave',
    'Kind',
    'Creative',
    'Smart',
    'Funny',
    'Helpful',
    'Patient',
    'Determined',
    'Caring',
    'Loyal',
  ];

  /// Suggested personality traits that influence story tone.
  static const List<String> personalityTraits = [
    'Shy',
    'Outgoing',
    'Curious',
    'Thoughtful',
    'Energetic',
    'Calm',
    'Playful',
    'Serious',
    'Confident',
    'Gentle',
  ];

  /// Slider-based personality dimensions that capture nuance.
  static const List<PersonalitySliderDefinition> personalitySliders = [
    PersonalitySliderDefinition(
      key: 'organization_planning',
      label: 'Organization & Planning',
      leftLabel: 'Tidy Planner',
      rightLabel: 'Messy Freestyle',
      helperText:
          'Do they love organizing and checklists, or go with the flow?',
      leftIcon: Icons.checklist,
      rightIcon: Icons.auto_awesome,
    ),
    PersonalitySliderDefinition(
      key: 'assertiveness',
      label: 'Voice Style',
      leftLabel: 'Bold Voice',
      rightLabel: 'Soft Voice',
      helperText:
          'Do they speak up loudly or use gentle whispers?',
      leftIcon: Icons.campaign,
      rightIcon: Icons.self_improvement,
    ),
    PersonalitySliderDefinition(
      key: 'sociability',
      label: 'Social Energy',
      leftLabel: 'Jump-Right-In',
      rightLabel: 'Warm-Up-First',
      helperText:
          'Do they dive into new friends or take time to feel comfy?',
      leftIcon: Icons.groups,
      rightIcon: Icons.emoji_people,
    ),
    PersonalitySliderDefinition(
      key: 'adventure',
      label: 'Adventure Level',
      leftLabel: 'Let’s Explore!',
      rightLabel: 'Careful Steps',
      helperText:
          'Do they chase big quests or prefer safe paths?',
      leftIcon: Icons.explore,
      rightIcon: Icons.shield_moon,
    ),
    PersonalitySliderDefinition(
      key: 'expressiveness',
      label: 'Energy Level',
      leftLabel: 'Mega Energy',
      rightLabel: 'Calm Breeze',
      helperText:
          'Do they bounce like a rocket or move like a quiet cloud?',
      leftIcon: Icons.bolt,
      rightIcon: Icons.air,
    ),
    PersonalitySliderDefinition(
      key: 'feelings_sharing',
      label: 'Feelings Expression',
      leftLabel: 'Heart-On-Sleeve',
      rightLabel: 'Quiet Feelings',
      helperText:
          'Do they share feelings right away or keep them cozy inside?',
      leftIcon: Icons.favorite_border,
      rightIcon: Icons.nights_stay,
    ),
    PersonalitySliderDefinition(
      key: 'problem_solving',
      label: 'Problem-Solving Style',
      leftLabel: 'Brainy Builder',
      rightLabel: 'Imagination Wiz',
      helperText:
          'Do they use logic blocks or big imagination sparks?',
      leftIcon: Icons.extension,
      rightIcon: Icons.auto_fix_high,
    ),
    PersonalitySliderDefinition(
      key: 'play_preference',
      label: 'Play Preference',
      leftLabel: 'Caring & Nurturing',
      rightLabel: 'Building & Action',
      helperText:
          'Do they love caring play or building and action adventures?',
      leftIcon: Icons.favorite,
      rightIcon: Icons.build_circle,
    ),
  ];

  /// Default slider values used when creating a new character.
  static Map<String, double> defaultSliderValues() {
    final values = <String, double>{};
    for (final slider in personalitySliders) {
      values[slider.key] = 50;
    }
    return values;
  }
}

class PersonalitySliderDefinition {
  final String key;
  final String label;
  final String leftLabel;
  final String rightLabel;
  final String helperText;
  final IconData leftIcon;
  final IconData rightIcon;

  const PersonalitySliderDefinition({
    required this.key,
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.helperText,
    required this.leftIcon,
    required this.rightIcon,
  });

  /// Human-friendly description of a slider's current leaning.
  String describeValue(num rawValue) {
    final value = rawValue.clamp(0, 100).toDouble();
    final delta = (value - 50).abs();
    if (delta <= 5) {
      return 'A mix of both styles';
    }
    final direction = value > 50 ? rightLabel : leftLabel;
    String qualifier;
    if (delta >= 30) {
      qualifier = 'Totally loves';
    } else if (delta >= 15) {
      qualifier = 'Leans toward';
    } else {
      qualifier = 'Slightly prefers';
    }
    return '$qualifier $direction';
  }
}
