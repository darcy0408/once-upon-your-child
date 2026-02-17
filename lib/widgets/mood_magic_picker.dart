// lib/widgets/mood_magic_picker.dart
// Mood Magic - A lightweight mood picker to replace the heavy feelings wheel.
//
// Features:
// - 6 base moods in a simple grid/row layout
// - Single-tap selection (no drilling down)
// - Age-appropriate synonyms shown as hints
// - Smooth animations and visual feedback
// - Much lighter than the 3-tier CustomPainter feelings wheel

import 'package:flutter/material.dart';
import '../data/mood_vocab.dart';

/// Selected mood result from Mood Magic picker.
class MoodSelection {
  final String moodId;
  final String moodName;
  final Color color;
  final String emoji;

  const MoodSelection({
    required this.moodId,
    required this.moodName,
    required this.color,
    required this.emoji,
  });

  Map<String, dynamic> toJson() => {
        'mood_id': moodId,
        'mood_name': moodName,
        'emoji': emoji,
        'color': '#${color.value.toRadixString(16).substring(2)}',
      };

  factory MoodSelection.fromMoodEntry(MoodEntry entry) => MoodSelection(
        moodId: entry.id,
        moodName: entry.baseName,
        color: entry.color,
        emoji: entry.emoji,
      );
}

/// Lightweight mood picker widget.
class MoodMagicPicker extends StatefulWidget {
  final ValueChanged<MoodSelection>? onMoodSelected;
  final int childAge;
  final String? initialMoodId;

  const MoodMagicPicker({
    super.key,
    this.onMoodSelected,
    this.childAge = 8,
    this.initialMoodId,
  });

  @override
  State<MoodMagicPicker> createState() => _MoodMagicPickerState();
}

class _MoodMagicPickerState extends State<MoodMagicPicker>
    with SingleTickerProviderStateMixin {
  String? _selectedMoodId;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _selectedMoodId = widget.initialMoodId;
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectMood(MoodEntry mood) {
    setState(() {
      _selectedMoodId = mood.id;
    });
    final selection = MoodSelection.fromMoodEntry(mood);
    widget.onMoodSelected?.call(selection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          'How are you feeling?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: moodVocabulary.map((mood) {
            final isSelected = _selectedMoodId == mood.id;
            return _MoodTile(
              mood: mood,
              isSelected: isSelected,
              childAge: widget.childAge,
              pulseAnimation: isSelected ? _pulseAnimation : null,
              onTap: () => _selectMood(mood),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_selectedMoodId != null)
          _buildSynonymHint(context),
      ],
    );
  }

  Widget _buildSynonymHint(BuildContext context) {
    final mood = getMoodById(_selectedMoodId!);
    if (mood == null) return const SizedBox.shrink();

    final synonyms = mood.synonymsForAge(widget.childAge);
    final synonymText = synonyms.take(3).join(', ');

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: mood.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: mood.color.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Like: $synonymText',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mood.color,
                fontStyle: FontStyle.italic,
              ),
        ),
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final MoodEntry mood;
  final bool isSelected;
  final int childAge;
  final Animation<double>? pulseAnimation;
  final VoidCallback onTap;

  const _MoodTile({
    required this.mood,
    required this.isSelected,
    required this.childAge,
    required this.onTap,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? mood.color : mood.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? mood.color : mood.color.withValues(alpha: 0.5),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: mood.color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mood.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 4),
            Text(
              mood.baseName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : mood.color,
              ),
            ),
          ],
        ),
      ),
    );

    if (pulseAnimation != null) {
      return ScaleTransition(
        scale: pulseAnimation!,
        child: tile,
      );
    }
    return tile;
  }
}
