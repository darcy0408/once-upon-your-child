// lib/story_illustration_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StoryIllustration {
  final String id;
  final String prompt;
  final String imageUrl;
  final DateTime generatedAt;
  final int segmentIndex; // Which part of the story this illustrates

  StoryIllustration({
    required this.id,
    required this.prompt,
    required this.imageUrl,
    required this.generatedAt,
    required this.segmentIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'imageUrl': imageUrl,
      'generatedAt': generatedAt.toIso8601String(),
      'segmentIndex': segmentIndex,
    };
  }

  factory StoryIllustration.fromJson(Map<String, dynamic> json) {
    return StoryIllustration(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      imageUrl: json['imageUrl'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      segmentIndex: json['segmentIndex'] as int,
    );
  }
}

class IllustratedStory {
  final String storyId;
  final List<StoryIllustration> illustrations;

  IllustratedStory({
    required this.storyId,
    required this.illustrations,
  });

  Map<String, dynamic> toJson() {
    return {
      'storyId': storyId,
      'illustrations': illustrations.map((i) => i.toJson()).toList(),
    };
  }

  factory IllustratedStory.fromJson(Map<String, dynamic> json) {
    return IllustratedStory(
      storyId: json['storyId'] as String,
      illustrations: (json['illustrations'] as List)
          .map((i) => StoryIllustration.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum IllustrationStyle {
  childrenBook,
  cartoon,
  watercolor,
  digital,
  pencilSketch,
}

extension IllustrationStyleExtension on IllustrationStyle {
  String get displayName {
    switch (this) {
      case IllustrationStyle.childrenBook:
        return "Children's Book";
      case IllustrationStyle.cartoon:
        return "Cartoon";
      case IllustrationStyle.watercolor:
        return "Watercolor";
      case IllustrationStyle.digital:
        return "Digital Art";
      case IllustrationStyle.pencilSketch:
        return "Pencil Sketch";
    }
  }

  String get promptModifier {
    switch (this) {
      case IllustrationStyle.childrenBook:
        return "in the style of a children's book illustration, colorful, friendly, safe for kids";
      case IllustrationStyle.cartoon:
        return "in cartoon style, vibrant colors, playful, child-friendly";
      case IllustrationStyle.watercolor:
        return "in watercolor painting style, soft colors, gentle, artistic";
      case IllustrationStyle.digital:
        return "in digital art style, modern, vibrant, detailed";
      case IllustrationStyle.pencilSketch:
        return "in pencil sketch style, artistic, gentle, hand-drawn";
    }
  }
}

class StoryIllustrationService {
  static const String _cacheKey = 'illustrated_stories';
  final String? openAiApiKey;

  // Note: You'll need to set this in your environment or pass it in
  // For production, store in secure environment variable
  StoryIllustrationService({this.openAiApiKey});

  /// Generate illustrations for a story using DALL-E
  Future<List<StoryIllustration>> generateIllustrations({
    required String storyText,
    required String storyTitle,
    required String characterName,
    String? theme,
    IllustrationStyle style = IllustrationStyle.childrenBook,
    int numberOfImages = 3,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    if (openAiApiKey == null || openAiApiKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Split story into segments for illustration
    final segments = _identifyKeyScenes(storyText, numberOfImages);
    final illustrations = <StoryIllustration>[];

    for (int i = 0; i < segments.length; i++) {
      try {
        final prompt = _generateImagePrompt(
          scene: segments[i],
          characterName: characterName,
          theme: theme,
          style: style,
          age: age,
          therapeuticFocus: therapeuticFocus,
        );

        final imageUrl = await _callDallE(prompt);

        illustrations.add(StoryIllustration(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          prompt: prompt,
          imageUrl: imageUrl,
          generatedAt: DateTime.now(),
          segmentIndex: i,
        ));

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('Error generating illustration $i: $e');
        // Continue with other images even if one fails
      }
    }

    return illustrations;
  }

  /// Call DALL-E API to generate an image
  Future<String> _callDallE(String prompt) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/images/generations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAiApiKey',
      },
      body: jsonEncode({
        'model': 'dall-e-3',
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024',
        'quality': 'standard',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'][0]['url'] as String;
    } else {
      throw Exception(
          'DALL-E API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Generate an appropriate prompt for DALL-E
  String _generateImagePrompt({
    required String scene,
    required String characterName,
    String? theme,
    required IllustrationStyle style,
    required int age,
    String? therapeuticFocus,
  }) {
    // Clean the scene text (limit to key details)
    final cleanScene = scene.length > 200 ? scene.substring(0, 200) : scene;

    return '''
Create a safe, child-friendly illustration ${style.promptModifier}.
Scene: $cleanScene
Main character: $characterName
${theme != null ? 'Theme: $theme' : ''}
The image should be:
- Appropriate for children around age $age
- Colorful and engaging
- Non-scary and positive
- Clear and easy to understand
${therapeuticFocus != null ? '- Support the therapeutic focus: $therapeuticFocus' : ''}
'''
        .trim();
  }

  /// Identify key scenes in the story for illustration
  List<String> _identifyKeyScenes(String storyText, int numberOfImages) {
    // Split story into sentences
    final sentences = storyText
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.isEmpty) return [];

    // Divide story into equal segments
    final segmentSize = sentences.length ~/ numberOfImages;
    final scenes = <String>[];

    for (int i = 0; i < numberOfImages; i++) {
      final startIndex = i * segmentSize;
      final endIndex =
          (i == numberOfImages - 1) ? sentences.length : (i + 1) * segmentSize;

      if (startIndex < sentences.length) {
        // Take 2-3 sentences from each segment as the scene
        final segmentSentences = sentences.sublist(
          startIndex,
          endIndex.clamp(0, sentences.length),
        );

        // Get key sentence from middle of segment
        final keyIndex = segmentSentences.length ~/ 2;
        scenes.add(segmentSentences[keyIndex].trim());
      }
    }

    return scenes;
  }

  /// Cache illustrations for a story
  Future<void> cacheIllustrations({
    required String storyId,
    required List<StoryIllustration> illustrations,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final illustratedStories = await getAllIllustratedStories();

    // Remove existing illustrations for this story
    illustratedStories.removeWhere((s) => s.storyId == storyId);

    // Add new illustrations
    illustratedStories.add(IllustratedStory(
      storyId: storyId,
      illustrations: illustrations,
    ));

    // Limit cache size (keep only 20 most recent illustrated stories)
    if (illustratedStories.length > 20) {
      illustratedStories.removeRange(0, illustratedStories.length - 20);
    }

    final jsonList = illustratedStories.map((s) => s.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Get cached illustrations for a story
  Future<List<StoryIllustration>?> getCachedIllustrations(
      String storyId) async {
    final illustratedStories = await getAllIllustratedStories();

    try {
      final story = illustratedStories.firstWhere((s) => s.storyId == storyId);
      return story.illustrations;
    } catch (e) {
      return null;
    }
  }

  /// Get all illustrated stories
  Future<List<IllustratedStory>> getAllIllustratedStories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map(
              (json) => IllustratedStory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading illustrated stories: $e');
      return [];
    }
  }

  /// Check if a story has cached illustrations
  Future<bool> hasIllustrations(String storyId) async {
    final illustrations = await getCachedIllustrations(storyId);
    return illustrations != null && illustrations.isNotEmpty;
  }

  /// Clear all cached illustrations
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  /// Get cache statistics
  Future<IllustrationCacheStats> getCacheStats() async {
    final stories = await getAllIllustratedStories();
    final totalImages = stories.fold<int>(
      0,
      (sum, story) => sum + story.illustrations.length,
    );

    return IllustrationCacheStats(
      totalStoriesWithIllustrations: stories.length,
      totalImages: totalImages,
      averageImagesPerStory: stories.isEmpty ? 0 : totalImages / stories.length,
    );
  }
}

class IllustrationCacheStats {
  final int totalStoriesWithIllustrations;
  final int totalImages;
  final double averageImagesPerStory;

  IllustrationCacheStats({
    required this.totalStoriesWithIllustrations,
    required this.totalImages,
    required this.averageImagesPerStory,
  });
}

/// Gemini-based illustration service using the backend API
class GeminiIllustrationService extends StoryIllustrationService {
  final String backendUrl;

  GeminiIllustrationService({
    this.backendUrl = 'http://localhost:5000',
  }) : super(openAiApiKey: null);

  @override
  Future<List<StoryIllustration>> generateIllustrations({
    required String storyText,
    required String storyTitle,
    required String characterName,
    String? theme,
    IllustrationStyle style = IllustrationStyle.childrenBook,
    int numberOfImages = 3,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    try {
      // Step 1: Extract scenes from the story using backend
      final scenesResponse = await http
          .post(
            Uri.parse('$backendUrl/extract-story-scenes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'story_text': storyText,
              'character_name': characterName,
              'num_scenes': numberOfImages,
              'age': age,
              'therapeutic_focus': therapeuticFocus,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (scenesResponse.statusCode != 200) {
        throw Exception(
            'Failed to extract scenes: ${scenesResponse.statusCode}');
      }

      final scenesData = jsonDecode(scenesResponse.body);
      final scenes = scenesData['scenes'] as List;

      if (scenes.isEmpty) {
        throw Exception('No scenes extracted from story');
      }

      // Step 2: Generate illustrations for the scenes
      final illustrationsResponse = await http
          .post(
            Uri.parse('$backendUrl/generate-illustrations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'scenes': scenes,
              'character_name': characterName,
              'style': style.promptModifier,
              'age': age,
              'therapeutic_focus': therapeuticFocus,
            }),
          )
          .timeout(const Duration(seconds: 65));

      if (illustrationsResponse.statusCode != 200) {
        throw Exception(
            'Failed to generate illustrations: ${illustrationsResponse.statusCode}');
      }

      final illustrationsData = jsonDecode(illustrationsResponse.body);
      final illustrations = illustrationsData['illustrations'] as List;

      // Convert to StoryIllustration objects with base64 data URLs
      return illustrations.asMap().entries.map((entry) {
        final index = entry.key;
        final illust = entry.value as Map<String, dynamic>;

        // Convert base64 to data URL for display
        final base64Data = illust['image_data'] as String;
        final dataUrl = 'data:image/png;base64,$base64Data';

        return StoryIllustration(
          id: illust['image_id'] as String,
          prompt: illust['scene_description'] as String,
          imageUrl: dataUrl,
          generatedAt: DateTime.now(),
          segmentIndex: index,
        );
      }).toList();
    } catch (e) {
      print('Error generating illustrations with Gemini: $e');
      rethrow;
    }
  }
}

/// Mock service for testing without API key
class MockIllustrationService extends StoryIllustrationService {
  MockIllustrationService() : super(openAiApiKey: 'mock');

  @override
  Future<List<StoryIllustration>> generateIllustrations({
    required String storyText,
    required String storyTitle,
    required String characterName,
    String? theme,
    IllustrationStyle style = IllustrationStyle.childrenBook,
    int numberOfImages = 3,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    // Generate mock illustrations with placeholder images
    final mockIllustrations = <StoryIllustration>[];

    for (int i = 0; i < numberOfImages; i++) {
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      mockIllustrations.add(StoryIllustration(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        prompt: 'Mock illustration $i for $storyTitle',
        imageUrl:
            'https://picsum.photos/seed/$characterName$i/400/400', // Placeholder service
        generatedAt: DateTime.now(),
        segmentIndex: i,
      ));
    }

    return mockIllustrations;
  }
}
