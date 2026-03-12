import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../config/environment.dart';
import 'api_service_manager.dart';

/// Response from starting a new interactive adventure story
class StartStoryResponse {
  final String storyId;
  final String title;
  final StorySegmentData segment;
  final List<InventoryItemData> inventory;
  final StoryStateData state;
  final bool isCompleted;

  StartStoryResponse({
    required this.storyId,
    required this.title,
    required this.segment,
    required this.inventory,
    required this.state,
    required this.isCompleted,
  });

  factory StartStoryResponse.fromJson(Map<String, dynamic> json) {
    return StartStoryResponse(
      storyId: json['story_id'] ?? '',
      title: json['title'] ?? '',
      segment: StorySegmentData.fromJson(json['segment'] ?? {}),
      inventory: (json['inventory'] as List<dynamic>?)
              ?.map((i) => InventoryItemData.fromJson(i))
              .toList() ??
          [],
      state: json['state'] != null
          ? StoryStateData.fromJson(json['state'])
          : StoryStateData.empty(),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

/// Response from continuing an interactive story
class ContinueStoryResponse {
  final String storyId;
  final StorySegmentData segment;
  final List<InventoryItemData> inventory;
  final StoryStateData state;
  final bool isCompleted;

  ContinueStoryResponse({
    required this.storyId,
    required this.segment,
    required this.inventory,
    required this.state,
    required this.isCompleted,
  });

  factory ContinueStoryResponse.fromJson(Map<String, dynamic> json) {
    return ContinueStoryResponse(
      storyId: json['story_id'] ?? '',
      segment: StorySegmentData.fromJson(json['segment'] ?? {}),
      inventory: (json['inventory'] as List<dynamic>?)
              ?.map((i) => InventoryItemData.fromJson(i))
              .toList() ??
          [],
      state: json['state'] != null
          ? StoryStateData.fromJson(json['state'])
          : StoryStateData.empty(),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

/// Client for interactive adventure story API
class InteractiveStoryService {
  const InteractiveStoryService();

  static String get _baseUrl => Environment.backendUrl;

  /// Test client for mocking HTTP requests in tests
  static http.Client? _testClient;

  /// Allow tests to inject a mock HTTP client
  static void setTestClient(http.Client? client) {
    _testClient = client;
  }

  /// Get the HTTP client to use (test client if set, otherwise default)
  http.Client get _httpClient => _testClient ?? http.Client();

  /// Start a new interactive adventure story
  Future<StartStoryResponse> startInteractiveStory({
    required String userId,
    required String characterId,
    required String theme,
    String tone = 'whimsical',
    String length = 'medium',
    int? age,
    List<String>? interests,
    List<String>? mustInclude,
    List<String>? avoid,
    String? lifeChallenge,
    Map<String, int>? personalitySliders,
    Map<String, dynamic>? chronicleContext,
    Map<String, dynamic>? bigFeelingsContext,
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse('$_baseUrl/generate-interactive-story');
    final response = await _httpClient
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'character_id': characterId,
            'theme': theme,
            'tone': tone,
            'length': length,
            if (age != null) 'age': age,
            if (interests != null && interests.isNotEmpty)
              'interests': interests,
            if (mustInclude != null && mustInclude.isNotEmpty)
              'must_include': mustInclude,
            if (avoid != null && avoid.isNotEmpty) 'avoid': avoid,
            if (lifeChallenge != null) 'life_challenge': lifeChallenge,
            if (personalitySliders != null)
              'personality_sliders': personalitySliders,
            if (chronicleContext != null) 'chronicle_context': chronicleContext,
            if (bigFeelingsContext != null && bigFeelingsContext.isNotEmpty)
              'big_feelings_context': bigFeelingsContext,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final error = _parseError(response);
      throw InteractiveStoryException(
        'Unable to start story (code ${response.statusCode}): $error',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return StartStoryResponse.fromJson(data);
  }

  /// Continue story based on choice selection
  Future<ContinueStoryResponse> continueInteractiveStory({
    required String storyId,
    required String choiceId,
    String? customText,
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse('$_baseUrl/continue-interactive-story');
    final body = <String, dynamic>{
      'story_id': storyId,
      'choice_id': choiceId,
    };
    if (choiceId == 'custom' && customText != null) {
      body['custom_text'] = customText;
    }
    final response = await _httpClient
        .post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final error = _parseError(response);
      throw InteractiveStoryException(
        'Unable to continue story (code ${response.statusCode}): $error',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ContinueStoryResponse.fromJson(data);
  }

  /// Get full story with all segments
  Future<InteractiveStoryData> getStory(String storyId) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse('$_baseUrl/interactive-story/$storyId');
    final response = await _httpClient
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final error = _parseError(response);
      throw InteractiveStoryException(
        'Unable to get story (code ${response.statusCode}): $error',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return InteractiveStoryData.fromJson(data);
  }

  /// Resume an in-progress story from current segment
  Future<ContinueStoryResponse> resumeStory(String storyId) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse('$_baseUrl/interactive-story/$storyId/resume');
    final response = await _httpClient
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final error = _parseError(response);
      throw InteractiveStoryException(
        'Unable to resume story (code ${response.statusCode}): $error',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ContinueStoryResponse.fromJson(data);
  }

  /// Legacy method: Request the opening segment (old API - deprecated)
  @Deprecated('Use startInteractiveStory instead')
  Future<StorySegment> fetchOpeningSegment({
    required Character character,
    required String theme,
    String? companion,
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse('$_baseUrl/generate-interactive-story');
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'character': character.name,
            'theme': theme,
            'age': character.age,
            if (companion != null &&
                companion.isNotEmpty &&
                companion.toLowerCase() != 'none')
              'companion': companion,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw InteractiveStoryException(
        'Unable to start story (code ${response.statusCode}).',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (data.isEmpty) {
      throw const InteractiveStoryException('Story opening was empty.');
    }

    return StorySegment.fromJson(data);
  }

  /// Legacy method: Continue story (old API - deprecated)
  @Deprecated('Use continueInteractiveStory instead')
  Future<StorySegment> continueStory({
    required Character character,
    required String theme,
    required StoryChoice choice,
    required List<StorySegment> previousSegments,
    required List<String> choiceIds,
    String? companion,
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse('$_baseUrl/continue-interactive-story');
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'character': character.name,
            'theme': theme,
            if (companion != null &&
                companion.isNotEmpty &&
                companion.toLowerCase() != 'none')
              'companion': companion,
            'choice': choice.text,
            'story_so_far': _buildStorySoFar(previousSegments),
            'choices_made': [...choiceIds, choice.id],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw InteractiveStoryException(
        'Unable to continue story (code ${response.statusCode}).',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (data.isEmpty) {
      throw const InteractiveStoryException('Story response was empty.');
    }

    return StorySegment.fromJson(data);
  }

  String _buildStorySoFar(List<StorySegment> segments) {
    return segments.map((segment) => segment.text.trim()).join('\n\n');
  }

  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['error'] ?? data['hint'] ?? 'Unknown error';
    } catch (_) {
      return response.body;
    }
  }
}

class InteractiveStoryException implements Exception {
  const InteractiveStoryException(this.message);

  final String message;

  @override
  String toString() => 'InteractiveStoryException: $message';
}
