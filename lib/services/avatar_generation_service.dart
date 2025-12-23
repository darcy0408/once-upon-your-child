import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/generated_avatar.dart';
import '../config/environment.dart';

/// Service for generating AI-powered avatars using the backend API
class AvatarGenerationService {
  final String baseUrl;

  AvatarGenerationService({String? baseUrl})
      : baseUrl = baseUrl ?? Environment.backendUrl;

  /// Generate a new avatar
  ///
  /// Returns the generated avatar or throws an exception on failure
  Future<GeneratedAvatar> generateAvatar({
    required String characterName,
    required int age,
    required String style, // pixar, watercolor, cartoon, clay
    Map<String, String>? features,
    Map<String, dynamic>? emotionData,
    String? seed, // For regeneration
  }) async {
    final url = Uri.parse('$baseUrl/avatar/generate-avatar');

    final payload = {
      'character_name': characterName,
      'age': age,
      'style': style,
      if (features != null) 'features': features,
      if (emotionData != null) 'emotion_data': emotionData,
      if (seed != null) 'seed': seed,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(
        const Duration(seconds: 60), // Avatar generation can take 10-30 seconds
        onTimeout: () {
          throw TimeoutException('Avatar generation timed out after 60 seconds');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          return GeneratedAvatar.fromJson(data['avatar'] as Map<String, dynamic>);
        } else {
          throw AvatarGenerationException(
            data['message'] as String? ?? 'Avatar generation failed',
            errorCode: data['error_code'] as String?,
          );
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw AvatarValidationException(
          data['message'] as String? ?? 'Invalid avatar parameters',
        );
      } else {
        throw AvatarGenerationException(
          'Server error: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      rethrow;
    } catch (e) {
      if (e is AvatarGenerationException || e is AvatarValidationException) {
        rethrow;
      }
      throw AvatarGenerationException('Failed to generate avatar: $e');
    }
  }

  /// Regenerate an avatar (for "re-roll" functionality)
  Future<GeneratedAvatar> regenerateAvatar({
    required String characterName,
    required int age,
    required String style,
    required Map<String, String> features,
    Map<String, dynamic>? emotionData,
  }) async {
    // Generate with same params but no seed for variation
    return generateAvatar(
      characterName: characterName,
      age: age,
      style: style,
      features: features,
      emotionData: emotionData,
      seed: null, // No seed = new variation
    );
  }

  /// Get fallback preset avatars (if generation fails)
  Future<List<Map<String, String>>> getFallbackAvatars({String? style}) async {
    final url = Uri.parse('$baseUrl/avatar/fallback-avatars${style != null ? '?style=$style' : ''}');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final avatars = data['fallback_avatars'] as List<dynamic>;
        return avatars
            .map((a) => Map<String, String>.from(a as Map))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Failed to get fallback avatars: $e');
      return [];
    }
  }

  /// Check if avatar service is healthy
  Future<bool> checkHealth() async {
    final url = Uri.parse('$baseUrl/avatar/health');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Avatar health check failed: $e');
      return false;
    }
  }
}

/// Exception thrown when avatar generation fails
class AvatarGenerationException implements Exception {
  final String message;
  final String? errorCode;

  AvatarGenerationException(this.message, {this.errorCode});

  @override
  String toString() => 'AvatarGenerationException: $message${errorCode != null ? ' ($errorCode)' : ''}';
}

/// Exception thrown when avatar validation fails
class AvatarValidationException implements Exception {
  final String message;

  AvatarValidationException(this.message);

  @override
  String toString() => 'AvatarValidationException: $message';
}

/// Exception thrown on timeout
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
