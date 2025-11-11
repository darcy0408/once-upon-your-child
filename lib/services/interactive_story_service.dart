import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../config/environment.dart';

/// Simple client for fetching interactive story segments from the backend.
class InteractiveStoryService {
  const InteractiveStoryService();

  static String get _baseUrl => Environment.backendUrl;

  /// Request the opening segment and choices.
  Future<StorySegment> fetchOpeningSegment({
    required Character character,
    required String theme,
    String? companion,
  }) async {
    final uri = Uri.parse('$_baseUrl/generate-interactive-story');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
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

  /// Continue the story with the given choice.
  Future<StorySegment> continueStory({
    required Character character,
    required String theme,
    required StoryChoice choice,
    required List<StorySegment> previousSegments,
    required List<String> choiceIds,
    String? companion,
  }) async {
    final uri = Uri.parse('$_baseUrl/continue-interactive-story');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
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
}

class InteractiveStoryException implements Exception {
  const InteractiveStoryException(this.message);

  final String message;

  @override
  String toString() => 'InteractiveStoryException: $message';
}
