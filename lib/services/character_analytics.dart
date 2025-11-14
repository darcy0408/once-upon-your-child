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
}
