// lib/story_based_coloring_service.dart
// Story-based coloring book service that uses backend to extract scenes

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'coloring_book_service.dart';
import 'character_appearance.dart';

/// Improved Coloring Book Service that uses actual story content via backend
class StoryBasedColoringService extends ColoringBookService {
  final String backendUrl;

  StoryBasedColoringService({
    this.backendUrl = 'http://localhost:5000',
  }) : super(openAiApiKey: 'story-based');

  @override
  Future<List<ColoringPage>> generateColoringPagesFromStory({
    required String storyId,
    required String storyTitle,
    required List<String> scenes,
    CharacterAppearance? characterAppearance,
  }) async {
    final pages = <ColoringPage>[];

    try {
      // Call backend to extract detailed scene descriptions
      final response = await http.post(
        Uri.parse('$backendUrl/extract-story-scenes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'story_text': scenes.join(' '),
          'character_name': characterAppearance?.name ?? 'the hero',
          'num_scenes': scenes.length,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extractedScenes = data['scenes'] as List;

        for (int i = 0; i < extractedScenes.length && i < scenes.length; i++) {
          final sceneData = extractedScenes[i];
          final sceneTitle = sceneData['title'] ?? 'Scene ${i + 1}';
          final sceneDescription = sceneData['description'] ?? scenes[i];

          // Create coloring page with story-based description
          final page = await _generateStoryBasedColoringPage(
            storyId: storyId,
            pageTitle: sceneTitle,
            scene: sceneDescription,
            characterAppearance: characterAppearance,
          );

          pages.add(page);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        // Fallback to scenes without backend
        for (int i = 0; i < scenes.length; i++) {
          final page = await _generateStoryBasedColoringPage(
            storyId: storyId,
            pageTitle: 'Scene ${i + 1}',
            scene: scenes[i],
            characterAppearance: characterAppearance,
          );
          pages.add(page);
        }
      }
    } catch (e) {
      print('Error generating story-based coloring pages: $e');
      // Fallback
      for (int i = 0; i < scenes.length; i++) {
        final page = await _generateStoryBasedColoringPage(
          storyId: storyId,
          pageTitle: 'Scene ${i + 1}',
          scene: scenes[i],
          characterAppearance: characterAppearance,
        );
        pages.add(page);
      }
    }

    return pages;
  }

  Future<ColoringPage> _generateStoryBasedColoringPage({
    required String storyId,
    required String pageTitle,
    required String scene,
    CharacterAppearance? characterAppearance,
  }) async {
    // Generate line art description
    final characterDesc = characterAppearance?.toColoringBookDescription() ?? 'a child character';

    final lineArtPrompt = '''
COLORING BOOK PAGE - BLACK AND WHITE LINE ART ONLY

Scene: $pageTitle
Description: $scene
Character: $characterDesc

Requirements:
- BLACK AND WHITE ONLY (no colors, no shading, no gray)
- Clear, bold outlines suitable for coloring
- Simple shapes with large areas to color
- Child-friendly (ages 4-8)
- High contrast black lines on white background
- Suitable for printing
- Include character prominently
'''.trim();

    // Use scene-specific seed for consistent placeholder
    final seed = '${storyId}_${pageTitle.replaceAll(' ', '_')}_lineart'.hashCode.abs();

    // For now, use grayscale placeholder
    // TODO: Replace with actual line art generation when API key is available
    final mockImageUrl = 'https://picsum.photos/seed/$seed/400/400?grayscale';

    return ColoringPage(
      id: '${DateTime.now().millisecondsSinceEpoch}_${pageTitle.replaceAll(' ', '_')}',
      storyId: storyId,
      pageTitle: pageTitle,
      scene: scene,
      lineArtPrompt: lineArtPrompt,
      imageUrl: mockImageUrl,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<ColoringPage> generateColoringPage({
    required String storyId,
    required String pageTitle,
    required String scene,
    CharacterAppearance? characterAppearance,
    String? originalIllustrationUrl,
  }) async {
    return await _generateStoryBasedColoringPage(
      storyId: storyId,
      pageTitle: pageTitle,
      scene: scene,
      characterAppearance: characterAppearance,
    );
  }
}
