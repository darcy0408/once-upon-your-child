// lib/story_based_illustration_service.dart
// Story-based illustration service that uses backend to extract scenes

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'story_illustration_service.dart';

/// Improved Mock Service that uses actual story content via backend
class StoryBasedIllustrationService extends StoryIllustrationService {
  final String backendUrl;

  StoryBasedIllustrationService({
    this.backendUrl = 'http://localhost:5000',
  }) : super(openAiApiKey: 'story-based');

  @override
  Future<List<StoryIllustration>> generateIllustrations({
    required String storyText,
    required String storyTitle,
    required String characterName,
    String? theme,
    IllustrationStyle style = IllustrationStyle.childrenBook,
    int numberOfImages = 3,
  }) async {
    try {
      // Call backend to extract story scenes
      final response = await http.post(
        Uri.parse('$backendUrl/extract-story-scenes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'story_text': storyText,
          'character_name': characterName,
          'num_scenes': numberOfImages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scenes = data['scenes'] as List;

        final illustrations = <StoryIllustration>[];
        for (int i = 0; i < scenes.length; i++) {
          final scene = scenes[i];
          final sceneTitle = scene['title'] ?? 'Scene ${i + 1}';
          final sceneDescription = scene['description'] ?? '';

          // For now, still use placeholders but with scene-specific seeds
          // This will make images consistent with the scene content
          final seed = '${storyTitle}_${sceneTitle.replaceAll(' ', '_')}'.hashCode.abs();

          illustrations.add(StoryIllustration(
            id: '${DateTime.now().millisecondsSinceEpoch}_$i',
            prompt: '$sceneTitle: $sceneDescription',
            imageUrl: 'https://picsum.photos/seed/$seed/400/400',
            generatedAt: DateTime.now(),
            segmentIndex: i,
          ));

          await Future.delayed(const Duration(milliseconds: 500));
        }

        return illustrations;
      } else {
        throw Exception('Failed to extract scenes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating story-based illustrations: $e');
      // Fallback to simple mock if backend fails
      return _generateFallbackIllustrations(
        storyTitle: storyTitle,
        characterName: characterName,
        numberOfImages: numberOfImages,
      );
    }
  }

  List<StoryIllustration> _generateFallbackIllustrations({
    required String storyTitle,
    required String characterName,
    required int numberOfImages,
  }) {
    final illustrations = <StoryIllustration>[];
    for (int i = 0; i < numberOfImages; i++) {
      illustrations.add(StoryIllustration(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        prompt: 'Scene $i from $storyTitle with $characterName',
        imageUrl: 'https://picsum.photos/seed/${storyTitle}$i/400/400',
        generatedAt: DateTime.now(),
        segmentIndex: i,
      ));
    }
    return illustrations;
  }
}
