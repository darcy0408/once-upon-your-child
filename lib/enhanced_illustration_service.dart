// lib/enhanced_illustration_service.dart
// Enhanced illustration service that uses actual character appearance

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'character_appearance_converter.dart';
import 'story_illustration_service.dart';

class EnhancedIllustrationService {
  final String? openAiApiKey;
  static const String _cacheKey = 'enhanced_illustrated_stories';

  EnhancedIllustrationService({this.openAiApiKey});

  /// Generate story illustrations using the character's actual appearance
  Future<List<StoryIllustration>> generateStoryIllustrations({
    required String storyText,
    required String storyTitle,
    required Character character,
    String? theme,
    IllustrationStyle style = IllustrationStyle.childrenBook,
    int numberOfImages = 3,
  }) async {
    if (openAiApiKey == null || openAiApiKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Split story into key scenes
    final scenes = _identifyKeyScenes(storyText, numberOfImages);
    final illustrations = <StoryIllustration>[];

    for (int i = 0; i < scenes.length; i++) {
      try {
        // Use the character appearance converter to create detailed prompt
        final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
          character,
          scenes[i],
          theme: theme,
          style: style,
        );

        final imageUrl = await _callDallE(prompt);

        illustrations.add(StoryIllustration(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          prompt: prompt,
          imageUrl: imageUrl,
          generatedAt: DateTime.now(),
          segmentIndex: i,
        ));

        // Delay to avoid rate limiting
        if (i < scenes.length - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Error generating illustration $i: $e');
      }
    }

    return illustrations;
  }

  /// Generate a character portrait
  Future<String> generateCharacterPortrait(Character character) async {
    if (openAiApiKey == null || openAiApiKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    final prompt = CharacterAppearanceConverter.createPortraitPrompt(character);
    return await _callDallE(prompt);
  }

  /// Generate a coloring book page with character appearance
  Future<String> generateColoringPage({
    required Character character,
    required String scene,
  }) async {
    if (openAiApiKey == null || openAiApiKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    final prompt = CharacterAppearanceConverter.createColoringBookPrompt(character, scene);
    return await _callDallE(prompt);
  }

  /// Call DALL-E API
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
        'quality': 'hd', // Use HD quality for better images
        'style': 'vivid', // Vivid style for more vibrant children's illustrations
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'][0]['url'] as String;
    } else {
      throw Exception('DALL-E API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Identify key scenes from story text
  List<String> _identifyKeyScenes(String storyText, int numberOfImages) {
    final sentences = storyText.split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.isEmpty) return [];

    final scenes = <String>[];

    // Beginning scene
    if (sentences.isNotEmpty) {
      scenes.add(sentences.first.trim());
    }

    // Middle scenes
    if (numberOfImages > 2 && sentences.length > 2) {
      final middleCount = numberOfImages - 2;
      for (int i = 0; i < middleCount; i++) {
        final index = ((i + 1) * sentences.length) ~/ (numberOfImages);
        if (index < sentences.length) {
          scenes.add(sentences[index].trim());
        }
      }
    }

    // Ending scene
    if (numberOfImages > 1 && sentences.length > 1) {
      scenes.add(sentences.last.trim());
    }

    return scenes.take(numberOfImages).toList();
  }

  /// Cache illustrations
  Future<void> cacheIllustrations({
    required String storyId,
    required List<StoryIllustration> illustrations,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = await getAllCachedIllustrations();

    cached.removeWhere((item) => item['storyId'] == storyId);
    cached.add({
      'storyId': storyId,
      'illustrations': illustrations.map((i) => i.toJson()).toList(),
      'cachedAt': DateTime.now().toIso8601String(),
    });

    if (cached.length > 20) {
      cached.removeRange(0, cached.length - 20);
    }

    await prefs.setString(_cacheKey, jsonEncode(cached));
  }

  /// Get cached illustrations
  Future<List<StoryIllustration>?> getCachedIllustrations(String storyId) async {
    final cached = await getAllCachedIllustrations();

    try {
      final story = cached.firstWhere((item) => item['storyId'] == storyId);
      final illustList = story['illustrations'] as List;
      return illustList
          .map((json) => StoryIllustration.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  /// Get all cached illustrations
  Future<List<Map<String, dynamic>>> getAllCachedIllustrations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}

/// Batch illustration generator for multiple characters
class BatchIllustrationService {
  final EnhancedIllustrationService _service;

  BatchIllustrationService(String? apiKey)
      : _service = EnhancedIllustrationService(openAiApiKey: apiKey);

  /// Generate character portraits for multiple characters
  Future<Map<String, String>> generateCharacterPortraits(
    List<Character> characters,
  ) async {
    final portraits = <String, String>{};

    for (final character in characters) {
      try {
        final portraitUrl = await _service.generateCharacterPortrait(character);
        portraits[character.id] = portraitUrl;

        // Delay between requests
        if (characters.indexOf(character) < characters.length - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print('Error generating portrait for ${character.name}: $e');
      }
    }

    return portraits;
  }

  /// Generate group illustration with multiple characters
  Future<String?> generateGroupIllustration({
    required List<Character> characters,
    required String scene,
    String? theme,
  }) async {
    if (characters.isEmpty) return null;

    // Create a combined prompt with all characters
    final characterDescriptions = characters.map((c) {
      return CharacterAppearanceConverter.createDetailedPrompt(c);
    }).join('\n\n');

    final prompt = '''
Create a beautiful children's story illustration showing multiple characters together.

CHARACTERS:
$characterDescriptions

SCENE: $scene
${theme != null ? 'THEME: $theme' : ''}

REQUIREMENTS:
- Show ALL characters clearly in the scene
- Each character should be recognizable
- Characters interact naturally
- Child-friendly and safe
- Warm, engaging, colorful
- Professional children's book quality
- No scary elements
- Ages 4-8 appropriate

STYLE: Children's book illustration, vibrant and heartwarming
'''.trim();

    try {
      return await _service._callDallE(prompt);
    } catch (e) {
      print('Error generating group illustration: $e');
      return null;
    }
  }
}
