import 'package:firebase_analytics/firebase_analytics.dart';

class CharacterAnalytics {
  CharacterAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackCharacterCreation({
    required String characterName,
    required int age,
    required String gender,
    required List<String> traits,
  }) async {
    await _analytics.logEvent(
      name: 'character_created',
      parameters: {
        'age': age,
        'gender': gender,
        'traits_count': traits.length,
        'has_custom_name': characterName.isNotEmpty,
      },
    );
  }

  static Future<void> trackGalleryInteraction({
    required String action,
    required String characterId,
    required String characterName,
    int? age,
    String? gender,
    String? feeling,
  }) async {
    final parameters = <String, Object?>{
      'action': action,
      'character_id': characterId,
      'name_length': characterName.length,
      if (age != null) 'age': age,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (feeling != null && feeling.isNotEmpty) 'feeling': feeling,
    }..removeWhere((_, value) => value == null);

    await _analytics.logEvent(
      name: 'character_gallery_action',
      parameters: parameters,
    );
  }
}
