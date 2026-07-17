// lib/coloring_book_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'character_appearance.dart';
import 'config/environment.dart';
import 'services/api_service_manager.dart';

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
          ? CharacterAppearance.fromJson(
              json['characterAppearance'] as Map<String, dynamic>)
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
    List<dynamic>? companions,
    String? originalIllustrationUrl,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    // Call backend API to generate coloring page
    final imageUrl = await _callBackendColoringAPI(
      sceneDescription: scene,
      characterName: characterAppearance?.characterName ?? 'the character',
      age: age,
      therapeuticFocus: therapeuticFocus,
      characterAppearance: characterAppearance,
      companions: companions,
    );

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

  /// Call backend API to generate coloring page
  Future<String> _callBackendColoringAPI({
    required String sceneDescription,
    required String characterName,
    required int age,
    String? therapeuticFocus,
    CharacterAppearance? characterAppearance,
    List<dynamic>? companions,
  }) async {
    final coloringHeaders = await ApiServiceManager.authHeaders();
    final response = await http.post(
      Uri.parse('${Environment.backendUrl}/generate-coloring-pages'),
      headers: coloringHeaders,
      body: jsonEncode({
        'scene_description': sceneDescription,
        'character_name': characterName,
        'num_images': 1,
        'age': age,
        'therapeutic_focus': therapeuticFocus,
        'character_appearance': characterAppearance?.toJson(),
        'companions': companions,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coloringPages = data['coloring_pages'] as List;
      if (coloringPages.isNotEmpty) {
        final page = coloringPages[0];
        // Check if it's base64 or URL
        if (page['image_data'] != null) {
          // Convert base64 to data URL
          final base64Data = page['image_data'];
          return 'data:image/png;base64,$base64Data';
        } else if (page['image_url'] != null) {
          return page['image_url'];
        }
      }
      throw Exception('No image data in response');
    } else {
      throw Exception(
          'Backend API error: ${response.statusCode} - ${response.body}');
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
          age: age,
          therapeuticFocus: therapeuticFocus,
        );

        pages.add(page);

        // Small delay to avoid rate limiting
        if (i < scenes.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        debugPrint('Error generating coloring page $i: $e');
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
      debugPrint('Error loading coloring pages: $e');
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
    String? backendUrl,
  })  : backendUrl = backendUrl ?? Environment.backendUrl,
        super(openAiApiKey: null);

  @override
  Future<List<ColoringPage>> generateColoringPagesFromStory({
    required String storyId,
    required String storyTitle,
    required List<String> scenes,
    CharacterAppearance? characterAppearance,
    List<dynamic>? companions,
    int age = 7,
    String? therapeuticFocus,
    Map<String, dynamic>? appearancePayload,
  }) async {
    try {
      // Prepare scenes for backend
      final scenesData = scenes.asMap().entries.map((entry) {
        return {
          'title': 'Scene ${entry.key + 1}',
          'description': entry.value,
        };
      }).toList();

      // MT-163: prefer the MT-129 no-fabrication payload when the caller
      // supplies one. `appearancePayload` only contains fields backed by real
      // source data (snake_case keys the backend reads), so the coloring model
      // is never handed an invented hair/skin description. Fall back to the
      // legacy `CharacterAppearance.toJson()` shape only when no payload was
      // provided.
      final characterAppearanceJson =
          appearancePayload ?? characterAppearance?.toJson();
      final characterName = (appearancePayload?['character_name'] as String?) ??
          characterAppearance?.characterName ??
          'the character';

      // Call backend to generate therapeutic coloring pages
      final coloringHeaders = await ApiServiceManager.authHeaders();
      final requestBody = {
        'scenes': scenesData,
        'character_name': characterName,
        'age': age,
        'therapeutic_focus': therapeuticFocus,
        'character_appearance': characterAppearanceJson,
        'companions': companions,
      };
      final response = await http
          .post(
            Uri.parse('$backendUrl/generate-coloring-pages'),
            headers: coloringHeaders,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 65));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to generate coloring pages: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final coloringPagesData = data['coloring_pages'] as List;

      // Convert to ColoringPage objects
      return coloringPagesData.asMap().entries.map((entry) {
        final pageData = entry.value as Map<String, dynamic>;

        // Convert base64 to data URL
        final base64Data = pageData['image_data'] as String;
        final dataUrl = 'data:image/png;base64,$base64Data';

        return ColoringPage(
          id: pageData['image_id'] as String,
          storyId: storyId,
          pageTitle: '$storyTitle - ${pageData['scene_title']}',
          imageUrl: dataUrl,
          createdAt: DateTime.now(),
          characterAppearance: characterAppearance,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error generating coloring pages with Gemini: $e');
      rethrow;
    }
  }

  @override
  Future<ColoringPage> generateColoringPage({
    required String storyId,
    required String pageTitle,
    required String scene,
    CharacterAppearance? characterAppearance,
    List<dynamic>? companions,
    String? originalIllustrationUrl,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    final pages = await generateColoringPagesFromStory(
      storyId: storyId,
      storyTitle: pageTitle,
      scenes: [scene],
      characterAppearance: characterAppearance,
      companions: companions,
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
    List<dynamic>? companions,
    String? originalIllustrationUrl,
    int age = 7,
    String? therapeuticFocus,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Use a placeholder service that provides black and white coloring book style images
    // In production, this would call DALL-E with the coloring book prompt
    final mockImageUrl =
        'https://picsum.photos/seed/coloring${DateTime.now().millisecondsSinceEpoch}/400/400?grayscale';

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
      debugPrint('Error loading user colorings: $e');
      return [];
    }
  }

  /// Clear all colorings
  Future<void> clearAllColorings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
