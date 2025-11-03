// lib/coloring_book_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'character_appearance.dart';

/// Model for a coloring book page
class ColoringPage {
  final String id;
  final String storyId;
  final String pageTitle;
  final String imageUrl; // URL to the line art image
  final String? originalIllustrationUrl; // Original colored illustration
  final DateTime createdAt;
  final CharacterAppearance? characterAppearance;

  ColoringPage({
    required this.id,
    required this.storyId,
    required this.pageTitle,
    required this.imageUrl,
    this.originalIllustrationUrl,
    required this.createdAt,
    this.characterAppearance,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storyId': storyId,
      'pageTitle': pageTitle,
      'imageUrl': imageUrl,
      'originalIllustrationUrl': originalIllustrationUrl,
      'createdAt': createdAt.toIso8601String(),
      'characterAppearance': characterAppearance?.toJson(),
    };
  }

  factory ColoringPage.fromJson(Map<String, dynamic> json) {
    return ColoringPage(
      id: json['id'] as String,
      storyId: json['storyId'] as String,
      pageTitle: json['pageTitle'] as String,
      imageUrl: json['imageUrl'] as String,
      originalIllustrationUrl: json['originalIllustrationUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      characterAppearance: json['characterAppearance'] != null
          ? CharacterAppearance.fromJson(json['characterAppearance'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Service to generate and manage coloring book pages
class ColoringBookService {
  static const String _cacheKey = 'coloring_pages';
  final String? openAiApiKey;

  ColoringBookService({this.openAiApiKey});

  /// Generate a coloring book page from an illustration
  /// This creates a line art version suitable for coloring
  Future<ColoringPage> generateColoringPage({
    required String storyId,
    required String pageTitle,
    required String scene,
    CharacterAppearance? characterAppearance,
    String? originalIllustrationUrl,
  }) async {
    if (openAiApiKey == null || openAiApiKey!.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Generate line art prompt
    final prompt = _generateLineArtPrompt(
      scene: scene,
      characterAppearance: characterAppearance,
    );

    // Call DALL-E to generate line art
    final imageUrl = await _callDallE(prompt);

    return ColoringPage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      storyId: storyId,
      pageTitle: pageTitle,
      imageUrl: imageUrl,
      originalIllustrationUrl: originalIllustrationUrl,
      createdAt: DateTime.now(),
      characterAppearance: characterAppearance,
    );
  }

  /// Generate line art prompt for DALL-E
  String _generateLineArtPrompt({
    required String scene,
    CharacterAppearance? characterAppearance,
  }) {
    final characterDesc = characterAppearance?.toColoringBookDescription() ?? 'a child character';

    return '''
Create a coloring book page (black and white line art only) for children ages 4-8.

Scene: $scene

Character: $characterDesc

Requirements:
- BLACK AND WHITE ONLY - no colors, no shading, no gray tones
- Clear, bold outlines suitable for coloring
- Simple shapes and forms
- Large areas for coloring
- Child-friendly and engaging
- No text or words
- High contrast (black lines on white background)
- Suitable for printing
- Similar to classic children's coloring books
- Include the character prominently in the scene

Style: Clean line art, coloring book page, black outlines on white background
'''.trim();
  }

  /// Call DALL-E API to generate image
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
      throw Exception('DALL-E API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Generate multiple coloring pages from a story's illustrations
  Future<List<ColoringPage>> generateColoringPagesFromStory({
    required String storyId,
    required String storyTitle,
    required List<String> scenes,
    CharacterAppearance? characterAppearance,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    final pages = <ColoringPage>[];

    for (int i = 0; i < scenes.length; i++) {
      try {
        final page = await generateColoringPage(
          storyId: storyId,
          pageTitle: '$storyTitle - Page ${i + 1}',
          scene: scenes[i],
          characterAppearance: characterAppearance,
        );

        pages.add(page);

        // Small delay to avoid rate limiting
        if (i < scenes.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('Error generating coloring page $i: $e');
        // Continue with other pages even if one fails
      }
    }

    return pages;
  }

  /// Cache coloring pages
  Future<void> cacheColoringPages(List<ColoringPage> pages) async {
    final prefs = await SharedPreferences.getInstance();
    final existingPages = await getAllColoringPages();

    // Add new pages
    existingPages.addAll(pages);

    // Limit cache size (keep only 50 most recent pages)
    if (existingPages.length > 50) {
      existingPages.removeRange(0, existingPages.length - 50);
    }

    final jsonList = existingPages.map((p) => p.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Get all cached coloring pages
  Future<List<ColoringPage>> getAllColoringPages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => ColoringPage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading coloring pages: $e');
      return [];
    }
  }

  /// Get coloring pages for a specific story
  Future<List<ColoringPage>> getColoringPagesForStory(String storyId) async {
    final allPages = await getAllColoringPages();
    return allPages.where((p) => p.storyId == storyId).toList();
  }

  /// Delete a coloring page
  Future<void> deleteColoringPage(String pageId) async {
    final pages = await getAllColoringPages();
    pages.removeWhere((p) => p.id == pageId);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = pages.map((p) => p.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Clear all coloring pages
  Future<void> clearAllPages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}

/// Gemini-based therapeutic coloring book service
class GeminiColoringBookService extends ColoringBookService {
  final String backendUrl;

  GeminiColoringBookService({
    this.backendUrl = 'http://localhost:5000',
  }) : super(openAiApiKey: null);

  @override
  Future<List<ColoringPage>> generateColoringPagesFromStory({
    required String storyId,
    required String storyTitle,
    required List<String> scenes,
    CharacterAppearance? characterAppearance,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    try {
      // Prepare scenes for backend
      final scenesData = scenes.asMap().entries.map((entry) {
        return {
          'title': 'Scene ${entry.key + 1}',
          'description': entry.value,
        };
      }).toList();

      // Call backend to generate therapeutic coloring pages
      final response = await http.post(
        Uri.parse('$backendUrl/generate-coloring-pages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'scenes': scenesData,
          'character_name': characterAppearance?.name ?? 'the character',
          'age': age,
          'therapeutic_focus': therapeuticFocus,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate coloring pages: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final coloringPagesData = data['coloring_pages'] as List;

      // Convert to ColoringPage objects
      return coloringPagesData.asMap().entries.map((entry) {
        final index = entry.key;
        final pageData = entry.value as Map<String, dynamic>;

        // Convert base64 to data URL
        final base64Data = pageData['image_data'] as String;
        final dataUrl = 'data:image/png;base64,$base64Data';

        return ColoringPage(
          id: pageData['image_id'] as String,
          storyId: storyId,
          pageTitle: '${storyTitle} - ${pageData['scene_title']}',
          imageUrl: dataUrl,
          createdAt: DateTime.now(),
          characterAppearance: characterAppearance,
        );
      }).toList();
    } catch (e) {
      print('Error generating coloring pages with Gemini: $e');
      rethrow;
    }
  }

  @override
  Future<ColoringPage> generateColoringPage({
    required String storyId,
    required String pageTitle,
    required String scene,
    CharacterAppearance? characterAppearance,
    String? originalIllustrationUrl,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    final pages = await generateColoringPagesFromStory(
      storyId: storyId,
      storyTitle: pageTitle,
      scenes: [scene],
      characterAppearance: characterAppearance,
      age: age,
      therapeuticFocus: therapeuticFocus,
    );

    if (pages.isEmpty) {
      throw Exception('Failed to generate coloring page');
    }

    return pages.first;
  }
}

/// Mock service for testing without API key
class MockColoringBookService extends ColoringBookService {
  MockColoringBookService() : super(openAiApiKey: 'mock');

  @override
  Future<ColoringPage> generateColoringPage({
    required String storyId,
    required String pageTitle,
    required String scene,
    CharacterAppearance? characterAppearance,
    String? originalIllustrationUrl,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Use a placeholder service that provides black and white coloring book style images
    // In production, this would call DALL-E with the coloring book prompt
    final mockImageUrl = 'https://picsum.photos/seed/coloring${DateTime.now().millisecondsSinceEpoch}/400/400?grayscale';

    return ColoringPage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      storyId: storyId,
      pageTitle: pageTitle,
      imageUrl: mockImageUrl,
      originalIllustrationUrl: originalIllustrationUrl,
      createdAt: DateTime.now(),
      characterAppearance: characterAppearance,
    );
  }
}

/// User coloring data (tracks which colors were used where)
class UserColoring {
  final String coloringPageId;
  final Map<String, String> coloredAreas; // area_id -> color_hex
  final DateTime lastModified;
  final bool isCompleted;

  UserColoring({
    required this.coloringPageId,
    required this.coloredAreas,
    required this.lastModified,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'coloringPageId': coloringPageId,
      'coloredAreas': coloredAreas,
      'lastModified': lastModified.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory UserColoring.fromJson(Map<String, dynamic> json) {
    return UserColoring(
      coloringPageId: json['coloringPageId'] as String,
      coloredAreas: Map<String, String>.from(json['coloredAreas'] as Map),
      lastModified: DateTime.parse(json['lastModified'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

/// Service to manage user's coloring progress
class UserColoringService {
  static const String _cacheKey = 'user_colorings';

  /// Save user's coloring progress
  Future<void> saveColoring(UserColoring coloring) async {
    final prefs = await SharedPreferences.getInstance();
    final colorings = await getAllColorings();

    // Remove existing coloring for this page
    colorings.removeWhere((c) => c.coloringPageId == coloring.coloringPageId);

    // Add new coloring
    colorings.add(coloring);

    // Limit cache size
    if (colorings.length > 100) {
      colorings.removeRange(0, colorings.length - 100);
    }

    final jsonList = colorings.map((c) => c.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Get user's coloring for a specific page
  Future<UserColoring?> getColoring(String coloringPageId) async {
    final colorings = await getAllColorings();
    try {
      return colorings.firstWhere((c) => c.coloringPageId == coloringPageId);
    } catch (e) {
      return null;
    }
  }

  /// Get all user colorings
  Future<List<UserColoring>> getAllColorings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => UserColoring.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading user colorings: $e');
      return [];
    }
  }

  /// Clear all colorings
  Future<void> clearAllColorings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
