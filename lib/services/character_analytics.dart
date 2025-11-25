import 'package:firebase_analytics/firebase_analytics.dart';

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
    await _analytics.logEvent(
      name: 'character_created',
      parameters: {
        'age': age,
        'gender': gender,
        'traits_count': traits.length,
        'has_custom_name': characterName.isNotEmpty,
        if (templateKey != null) 'template_key': templateKey,
      },
    );
  }

  static Future<void> trackTemplateSelected({
    required String templateKey,
    required String templateName,
    required bool hasCustomName,
  }) async {
    await _analytics.logEvent(
      name: 'character_template_selected',
      parameters: {
        'template_key': templateKey,
        'template_name': templateName,
        'has_custom_name': hasCustomName,
      },
    );
  }

  static Future<void> trackGalleryInteraction({
    required String action,
    required String characterId,
    required String characterName,
    required int age,
    String? gender,
    String? feeling,
  }) async {
    await _analytics.logEvent(
      name: 'character_gallery_action',
      parameters: {
        'action': action,
        'character_id': characterId,
        'character_name_length': characterName.length,
        'age': age,
        if (gender != null) 'gender': gender,
        if (feeling != null) 'feeling': feeling,
      },
    );
  }
}
