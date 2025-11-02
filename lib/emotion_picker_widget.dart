// lib/emotion_picker_widget.dart

import 'package:flutter/material.dart';
import 'emotion_models.dart';

class EmotionPickerWidget extends StatefulWidget {
  final EmotionState? initialEmotion;
  final Function(EmotionState) onEmotionSelected;

  const EmotionPickerWidget({
    super.key,
    this.initialEmotion,
    required this.onEmotionSelected,
  });

  @override
  State<EmotionPickerWidget> createState() => _EmotionPickerWidgetState();
}

class _EmotionPickerWidgetState extends State<EmotionPickerWidget> {
  CoreEmotion? _selectedCore;
  SpecificEmotion? _selectedSpecific;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmotion != null) {
      _selectedCore = widget.initialEmotion!.core;
      final specifics = FeelingsWheel.getSpecificEmotions(widget.initialEmotion!.core);
      _selectedSpecific = specifics.firstWhere(
        (e) => e.name == widget.initialEmotion!.specific,
        orElse: () => specifics.first,
      );
    }
  }

  void _selectCoreEmotion(CoreEmotion core) {
    setState(() {
      _selectedCore = core;
      _selectedSpecific = null; // Reset specific when changing core
    });
  }

  void _selectSpecificEmotion(SpecificEmotion specific) {
    setState(() {
      _selectedSpecific = specific;
    });

    // Notify parent
    if (_selectedCore != null) {
      widget.onEmotionSelected(
        EmotionState(
          core: _selectedCore!,
          specific: specific.name,
          faceKey: specific.faceKey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0f1a12), // Dark green-tinted background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2d5a3d), // Forest green border
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'How do you feel right now?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7fd3a8), // Light green
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          const Text(
            'Tap a face that matches you. There\'s no wrong answer.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFa8d5ba), // Soft green
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Step 1: Core Emotions
          const Text(
            'Pick your main feeling:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7fd3a8),
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: CoreEmotion.values.map((core) {
              final isSelected = _selectedCore == core;
              return _buildCoreEmotionButton(core, isSelected);
            }).toList(),
          ),

          // Step 2: Specific Emotions (shown after core is selected)
          if (_selectedCore != null) ...[
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF2d5a3d), thickness: 1),
            const SizedBox(height: 16),

            const Text(
              'Now pick the feeling that\'s closest:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7fd3a8),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: FeelingsWheel.getSpecificEmotions(_selectedCore!)
                  .map((specific) {
                final isSelected = _selectedSpecific?.name == specific.name;
                return _buildSpecificEmotionButton(specific, isSelected);
              }).toList(),
            ),
          ],

          // Selected emotion display
          if (_selectedSpecific != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2f1f), // Darker green background
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4a9d6a), // Bright green border
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Face emoji
                  Text(
                    _selectedSpecific!.emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 12),

                  // Text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Right now I feel:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFa8d5ba),
                        ),
                      ),
                      Text(
                        _selectedSpecific!.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7fd3a8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoreEmotionButton(CoreEmotion core, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectCoreEmotion(core),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2d5a3d) // Forest green when selected
              : const Color(0xFF1a2f1f), // Dark green background
          borderRadius: BorderRadius.circular(16),
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
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large emoji face
            Text(
              core.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),

            // Label
            Text(
              core.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7fd3a8)
                    : const Color(0xFFa8d5ba),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificEmotionButton(SpecificEmotion specific, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectSpecificEmotion(specific),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2d5a3d)
              : const Color(0xFF1a2f1f),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4a9d6a)
                : const Color(0xFF2d5a3d),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4a9d6a).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji face
            Text(
              specific.emoji,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 6),

            // Name
            Text(
              specific.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7fd3a8)
                    : const Color(0xFFa8d5ba),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
