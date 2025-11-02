// lib/avatar_preset_selector.dart

import 'package:flutter/material.dart';

class AvatarPreset {
  final String name;
  final String skinTone;
  final String hairStyle;
  final String hairColor;
  final String description;
  final String emoji; // Temporary visual representation

  const AvatarPreset({
    required this.name,
    required this.skinTone,
    required this.hairStyle,
    required this.hairColor,
    required this.description,
    required this.emoji,
  });
}

class AvatarPresets {
  static const List<AvatarPreset> presets = [
    AvatarPreset(
      name: 'Sunny',
      skinTone: 'fair',
      hairStyle: 'Long Straight',
      hairColor: 'Blonde',
      description: 'Light skin, long blonde hair',
      emoji: '👱‍♀️',
    ),
    AvatarPreset(
      name: 'Riley',
      skinTone: 'mediumWarm',
      hairStyle: 'Curly',
      hairColor: 'Dark Brown',
      description: 'Medium brown skin, curly hair',
      emoji: '🧑🏽',
    ),
    AvatarPreset(
      name: 'Sam',
      skinTone: 'deepBrown',
      hairStyle: 'Short Locs',
      hairColor: 'Black',
      description: 'Dark skin, short locs',
      emoji: '👦🏿',
    ),
    AvatarPreset(
      name: 'Alex',
      skinTone: 'lightWarm',
      hairStyle: 'Short Spiky',
      hairColor: 'Red',
      description: 'Light skin with freckles, red hair',
      emoji: '👦🏻',
    ),
    AvatarPreset(
      name: 'Mei',
      skinTone: 'lightNeutral',
      hairStyle: 'Bob',
      hairColor: 'Black',
      description: 'East Asian features, straight black hair',
      emoji: '👧',
    ),
    AvatarPreset(
      name: 'Jordan',
      skinTone: 'mediumGolden',
      hairStyle: 'Short Fade',
      hairColor: 'Black',
      description: 'Uses wheelchair, medium skin',
      emoji: '🧑🏽‍🦽',
    ),
  ];
}

class AvatarPresetSelector extends StatelessWidget {
  final AvatarPreset? selectedPreset;
  final Function(AvatarPreset) onPresetSelected;

  const AvatarPresetSelector({
    super.key,
    this.selectedPreset,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2f1f), // Dark green background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2d5a3d), // Forest green border
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start with a preset:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7fd3a8), // Light green
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick someone that looks like you, then customize!',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFa8d5ba), // Soft green
            ),
          ),
          const SizedBox(height: 16),

          // Horizontal scrollable row of presets
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: AvatarPresets.presets.length,
              itemBuilder: (context, index) {
                final preset = AvatarPresets.presets[index];
                final isSelected = selectedPreset?.name == preset.name;
                return _buildPresetCard(preset, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(AvatarPreset preset, bool isSelected) {
    return GestureDetector(
      onTap: () => onPresetSelected(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2d5a3d) // Forest green when selected
              : const Color(0xFF0f1a12), // Darker background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4a9d6a) // Bright green border
                : const Color(0xFF2d5a3d), // Subtle green border
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4a9d6a).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji avatar
            Text(
              preset.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),

            // Name
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF7fd3a8)
                    : const Color(0xFFa8d5ba),
              ),
            ),

            // Small description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                preset.description,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected
                      ? const Color(0xFFa8d5ba)
                      : const Color(0xFF6b8f7a),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
