// lib/pre_story_feelings_dialog.dart
// Dialog to check in on child's feelings before creating a story

import 'package:flutter/material.dart';
import 'emotions_learning_system.dart';

class CurrentFeeling {
  final Emotion emotion;
  final int intensity;
  final String? whatHappened;

  CurrentFeeling({
    required this.emotion,
    required this.intensity,
    this.whatHappened,
  });

  Map<String, dynamic> toJson() => {
        'emotion_id': emotion.id,
        'emotion_name': emotion.name,
        'emotion_emoji': emotion.emoji,
        'emotion_description': emotion.description,
        'intensity': intensity,
        'what_happened': whatHappened,
        'physical_signs': emotion.physicalSigns,
        'coping_strategies': emotion.copingStrategies,
      };
}

class PreStoryFeelingsDialog extends StatefulWidget {
  final String characterName;

  const PreStoryFeelingsDialog({
    super.key,
    required this.characterName,
  });

  @override
  State<PreStoryFeelingsDialog> createState() => _PreStoryFeelingsDialogState();

  /// Show the dialog and return the selected feeling
  static Future<CurrentFeeling?> show({
    required BuildContext context,
    required String characterName,
  }) async {
    return await showDialog<CurrentFeeling>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PreStoryFeelingsDialog(characterName: characterName),
    );
  }
}

class _PreStoryFeelingsDialogState extends State<PreStoryFeelingsDialog> {
  final _service = EmotionsLearningService();
  Emotion? _selectedEmotion;
  int _intensity = 3;
  final TextEditingController _whatHappenedController = TextEditingController();

  @override
  void dispose() {
    _whatHappenedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.purple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How is ${widget.characterName} feeling?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Let\'s create a story about this feeling',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Emotion Selection
                const Text(
                  'Choose the feeling:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _service.getAllEmotions().map((emotion) {
                      final isSelected = _selectedEmotion?.id == emotion.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedEmotion = emotion);
                        },
                        child: Container(
                          width: 85,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? emotion.color.withOpacity(0.3)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? emotion.color : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emotion.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                emotion.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Emotion Details
                if (_selectedEmotion != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedEmotion!.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedEmotion!.color,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedEmotion!.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedEmotion!.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedEmotion!.description,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Body might feel: ${_selectedEmotion!.physicalSigns}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Intensity Slider
                  const SizedBox(height: 20),
                  const Text(
                    'How strong is this feeling?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Mild', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _intensity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _getIntensityLabel(_intensity),
                          activeColor: _selectedEmotion!.color,
                          onChanged: (value) {
                            setState(() => _intensity = value.toInt());
                          },
                        ),
                      ),
                      const Text('Very Strong', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Center(
                    child: Text(
                      _getIntensityLabel(_intensity),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedEmotion!.color,
                      ),
                    ),
                  ),

                  // What Happened (Optional)
                  const SizedBox(height: 20),
                  const Text(
                    'What happened? (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _whatHappenedController,
                    decoration: InputDecoration(
                      hintText: 'Tell us what happened that made you feel this way...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Skip Check-In'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedEmotion == null
                            ? null
                            : () {
                                final feeling = CurrentFeeling(
                                  emotion: _selectedEmotion!,
                                  intensity: _intensity,
                                  whatHappened: _whatHappenedController.text.trim().isEmpty
                                      ? null
                                      : _whatHappenedController.text.trim(),
                                );
                                Navigator.of(context).pop(feeling);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedEmotion?.color ?? Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create Story',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getIntensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return 'A little';
      case 2:
        return 'Some';
      case 3:
        return 'Medium';
      case 4:
        return 'Strong';
      case 5:
        return 'Very strong';
      default:
        return 'Medium';
    }
  }
}
