// lib/illustration_settings_dialog.dart

import 'package:flutter/material.dart';
import 'story_illustration_service.dart';

class IllustrationSettingsDialog extends StatefulWidget {
  const IllustrationSettingsDialog({super.key});

  @override
  State<IllustrationSettingsDialog> createState() => _IllustrationSettingsDialogState();
}

class _IllustrationSettingsDialogState extends State<IllustrationSettingsDialog> {
  IllustrationStyle _selectedStyle = IllustrationStyle.childrenBook;
  int _numberOfImages = 3;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.image, color: Colors.deepPurple),
          const SizedBox(width: 8),
          const Text('Illustration Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose illustration style:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Style selector
            ...IllustrationStyle.values.map((style) {
              return RadioListTile<IllustrationStyle>(
                title: Text(style.displayName),
                value: style,
                groupValue: _selectedStyle,
                onChanged: (value) {
                  setState(() {
                    _selectedStyle = value!;
                  });
                },
                activeColor: Colors.deepPurple,
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Number of images selector
            const Text(
              'Number of illustrations:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _numberOfImages.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _numberOfImages.toString(),
                    onChanged: (value) {
                      setState(() {
                        _numberOfImages = value.toInt();
                      });
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _numberOfImages.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              'More illustrations = longer generation time',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Illustrations are generated with AI and may take 30-60 seconds',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context, {
              'style': _selectedStyle,
              'numberOfImages': _numberOfImages,
            });
          },
          icon: const Icon(Icons.check),
          label: const Text('Generate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
        ),
      ],
    );
  }
}

/// Progress dialog for illustration generation
class IllustrationGenerationDialog extends StatelessWidget {
  final int totalImages;
  final int currentImage;

  const IllustrationGenerationDialog({
    super.key,
    required this.totalImages,
    required this.currentImage,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentImage / totalImages;

    return AlertDialog(
      title: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          const Text('Generating Illustrations...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          Text(
            'Creating image $currentImage of $totalImages',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a minute...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, int totalImages, int currentImage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IllustrationGenerationDialog(
        totalImages: totalImages,
        currentImage: currentImage,
      ),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
