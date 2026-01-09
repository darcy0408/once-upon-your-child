import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class CharacterAnalytics {
  CharacterAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackCharacterCreation({
    required String characterName,
    required int age,
    required String gender,
    required List<String> traits,
    String? templateKey,
  }) async {
    await _safeLogEvent('character_created', {
      'age': age,
      'gender': gender,
      'traits_count': traits.length,
      'has_custom_name': characterName.isNotEmpty,
      if (templateKey != null) 'template_key': templateKey,
    });
  }

  static Future<void> trackTemplateSelected({
    required String templateKey,
    required String templateName,
    required bool hasCustomName,
  }) async {
    await _safeLogEvent('character_template_selected', {
      'template_key': templateKey,
      'template_name': templateName,
      'has_custom_name': hasCustomName,
    });
  }

  static Future<void> trackGalleryInteraction({
    required String action,
    required String characterId,
    required String characterName,
    required int age,
    String? gender,
    String? feeling,
  }) async {
    await _safeLogEvent('character_gallery_action', {
      'action': action,
      'character_id': characterId,
      'character_name_length': characterName.length,
      'age': age,
      if (gender != null) 'gender': gender,
      if (feeling != null) 'feeling': feeling,
    });
  }

  static Future<void> _safeLogEvent(
    String name,
    Map<String, Object?> parameters,
  ) async {
    try {
      // Convert to Map<String, Object> and ensure all values are primitive types
      final Map<String, Object> cleanParams = {};
      parameters.forEach((key, value) {
        if (value != null) {
          // Only include primitive types that Firebase Analytics accepts
          if (value is String || value is num || value is bool) {
            cleanParams[key] = value;
          } else {
            cleanParams[key] = value.toString();
          }
        }
      });
      await _analytics.logEvent(
        name: name,
        parameters: cleanParams.cast<String, Object>(),
      );
    } catch (e) {
      debugPrint('Analytics logEvent failed ($name): ${e.toString()}');
    }
  }
}
