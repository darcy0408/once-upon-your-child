// lib/services/api_service_manager.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Manages API calls - routes to either local backend or direct Gemini API
/// based on user's API key configuration
class ApiServiceManager {
  static const String _localBackendUrl = 'http://127.0.0.1:5000';

  /// Check if user has configured their own API key
  static Future<bool> isUsingOwnApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final useOwnKey = prefs.getBool('use_own_api_key') ?? false;
    final apiKey = prefs.getString('gemini_api_key') ?? '';
    return useOwnKey && apiKey.isNotEmpty;
  }

  /// Get user's API key (if configured)
  static Future<String?> getUserApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }

  /// Check if user has premium access (either BYOK or paid)
  static Future<bool> hasPremiumAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final byokPremium = prefs.getBool('is_premium_byok') ?? false;
    final paidPremium = prefs.getBool('is_paid_premium') ?? false;
    return byokPremium || paidPremium;
  }

  /// Generate a story using appropriate method (backend or direct API)
  static Future<String> generateStory({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
  }) async {
    final useOwnKey = await isUsingOwnApiKey();

    if (useOwnKey) {
      // Use direct Gemini API
      return await _generateStoryWithGemini(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
      );
    } else {
      // Use local Flask backend
      return await _generateStoryWithBackend(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
      );
    }
  }

  /// Generate story using direct Gemini API
  static Future<String> _generateStoryWithGemini({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
  }) async {
    final apiKey = await getUserApiKey();
    if (apiKey == null) throw Exception('No API key configured');

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    // Build the prompt (matching backend logic)
    final prompt = _buildStoryPrompt(
      characterName: characterName,
      theme: theme,
      age: age,
      companion: companion,
      characterDetails: characterDetails,
      additionalCharacters: additionalCharacters,
    );

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  /// Generate story using local backend
  static Future<String> _generateStoryWithBackend({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
  }) async {
    final endpoint = (additionalCharacters == null || additionalCharacters.isEmpty)
        ? '$_localBackendUrl/generate-story'
        : '$_localBackendUrl/generate-multi-character-story';

    final body = (additionalCharacters == null || additionalCharacters.isEmpty)
        ? {
            'character': characterName,
            'theme': theme,
            'companion': companion,
            'character_age': age,
            'character_details': characterDetails,
          }
        : {
            'main_character': characterName,
            'characters': additionalCharacters,
            'theme': theme,
            'character_age': age,
          };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['story'] as String;
    } else {
      throw Exception('Failed to generate story: ${response.statusCode}');
    }
  }

  /// Build the story generation prompt (matching backend logic)
  static String _buildStoryPrompt({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
  }) {
    // Determine story length based on age
    String lengthGuideline;
    if (age <= 5) {
      lengthGuideline = '200-300 words';
    } else if (age <= 8) {
      lengthGuideline = '300-500 words';
    } else if (age <= 12) {
      lengthGuideline = '500-700 words';
    } else if (age <= 17) {
      lengthGuideline = '700-900 words';
    } else {
      lengthGuideline = '800-1000 words';
    }

    // Build character integration if available
    String characterIntegration = '';
    if (characterDetails != null) {
      final fears = characterDetails['fears'] as List<String>?;
      final strengths = characterDetails['strengths'] as List<String>?;
      final likes = characterDetails['likes'] as List<String>?;
      final dislikes = characterDetails['dislikes'] as List<String>?;
      final comfortItem = characterDetails['comfort_item'] as String?;

      if (fears != null && fears.isNotEmpty) {
        characterIntegration += '\n\nFEARS TO ADDRESS: ${fears.join(", ")}';
        characterIntegration +=
            '\nIMPORTANT: The story MUST help the character face and overcome one of these fears.';
      }

      if (strengths != null && strengths.isNotEmpty) {
        characterIntegration +=
            '\n\nSTRENGTHS: ${strengths.join(", ")}. Show the character using these strengths to overcome challenges.';
      }

      if (likes != null && likes.isNotEmpty) {
        characterIntegration +=
            '\n\nLIKES: ${likes.join(", ")}. Incorporate these interests naturally into the story.';
      }

      if (dislikes != null && dislikes.isNotEmpty) {
        characterIntegration +=
            '\n\nDISLIKES: ${dislikes.join(", ")}. The character may need to face or work around these.';
      }

      if (comfortItem != null && comfortItem.isNotEmpty) {
        characterIntegration +=
            '\n\nCOMFORT ITEM: $comfortItem. This item provides emotional security and can help in difficult moments.';
      }
    }

    String companionText = '';
    if (companion != null && companion.isNotEmpty) {
      companionText = '\n\nCOMPANION: Include $companion as a helpful friend/guide in the story.';
    }

    String multiCharacterText = '';
    if (additionalCharacters != null && additionalCharacters.isNotEmpty) {
      multiCharacterText =
          '\n\nADDITIONAL CHARACTERS: ${additionalCharacters.join(", ")}. Include these characters in meaningful ways throughout the story.';
    }

    return '''
You are a therapeutic storyteller creating personalized stories for children and adults.

Create a $lengthGuideline therapeutic story about a character named $characterName (age $age) with the theme: $theme.$companionText$multiCharacterText$characterIntegration

STORY STRUCTURE:
1. BEGINNING: Introduce $characterName in their normal world
2. CHALLENGE: Present a situation that involves growth or facing fears
3. STRUGGLE: Show realistic difficulty and emotion
4. DISCOVERY: Character realizes their inner strength or learns something important
5. RESOLUTION: Character overcomes the challenge using their strengths
6. REFLECTION: Character feels proud, confident, and has grown

WRITING STYLE:
- Use sensory-rich, vivid descriptions
- Show emotions, don't just tell
- Include internal thoughts and feelings
- Make it age-appropriate for a $age-year-old
- End with a positive, empowering message
- Natural dialogue if characters interact

Create an engaging, therapeutic story now:
''';
  }

  /// Generate interactive story opening
  static Future<Map<String, dynamic>> generateInteractiveStory({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
  }) async {
    final useOwnKey = await isUsingOwnApiKey();

    if (useOwnKey) {
      return await _generateInteractiveStoryWithGemini(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
      );
    } else {
      return await _generateInteractiveStoryWithBackend(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
      );
    }
  }

  static Future<Map<String, dynamic>> _generateInteractiveStoryWithGemini({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
  }) async {
    final apiKey = await getUserApiKey();
    if (apiKey == null) throw Exception('No API key configured');

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final companionText = companion != null && companion.isNotEmpty
        ? 'Include $companion as a friend/companion who can help with choices.'
        : '';

    final prompt = '''
You are creating an interactive choose-your-own-adventure story for children.

Create the OPENING segment (150-200 words) of an engaging story about $characterName (age $age) with the theme: $theme. $companionText

Set the scene and introduce a situation where the character must make a choice.

Return ONLY valid JSON in this exact format:
{
  "text": "The story opening text here...",
  "choices": [
    {"id": "choice1", "text": "First option (short)", "description": "What happens if they choose this"},
    {"id": "choice2", "text": "Second option (short)", "description": "What happens if they choose this"},
    {"id": "choice3", "text": "Third option (short)", "description": "What happens if they choose this"}
  ]
}
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text ?? '';

    // Extract JSON from response (it might have markdown code blocks)
    String jsonText = responseText;
    if (jsonText.contains('```json')) {
      jsonText = jsonText.split('```json')[1].split('```')[0].trim();
    } else if (jsonText.contains('```')) {
      jsonText = jsonText.split('```')[1].split('```')[0].trim();
    }

    return jsonDecode(jsonText) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _generateInteractiveStoryWithBackend({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
  }) async {
    final response = await http.post(
      Uri.parse('$_localBackendUrl/generate-interactive-story'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'character': characterName,
        'theme': theme,
        'age': age,
        'companion': companion,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to generate interactive story: ${response.statusCode}');
    }
  }

  /// Continue interactive story based on choice
  static Future<Map<String, dynamic>> continueInteractiveStory({
    required String characterName,
    required String theme,
    required String choice,
    required String storySoFar,
    required List<String> choicesMade,
  }) async {
    final useOwnKey = await isUsingOwnApiKey();

    if (useOwnKey) {
      return await _continueInteractiveStoryWithGemini(
        characterName: characterName,
        theme: theme,
        choice: choice,
        storySoFar: storySoFar,
        choicesMade: choicesMade,
      );
    } else {
      return await _continueInteractiveStoryWithBackend(
        characterName: characterName,
        theme: theme,
        choice: choice,
        storySoFar: storySoFar,
        choicesMade: choicesMade,
      );
    }
  }

  static Future<Map<String, dynamic>> _continueInteractiveStoryWithGemini({
    required String characterName,
    required String theme,
    required String choice,
    required String storySoFar,
    required List<String> choicesMade,
  }) async {
    final apiKey = await getUserApiKey();
    if (apiKey == null) throw Exception('No API key configured');

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final shouldEnd = choicesMade.length >= 3;

    final prompt = '''
You are continuing an interactive choose-your-own-adventure story.

STORY SO FAR:
$storySoFar

$characterName chose: "$choice"

${shouldEnd ? 'This should be the ENDING. Wrap up the story positively (150-200 words).' : 'Write the next segment (150-200 words) and provide 3 new choices.'}

Return ONLY valid JSON in this exact format:
{
  "text": "The next story segment here...",
  "is_ending": ${shouldEnd ? 'true' : 'false'},
  ${!shouldEnd ? '"choices": [{"id": "choice1", "text": "Option", "description": "What happens"}, {"id": "choice2", "text": "Option", "description": "What happens"}, {"id": "choice3", "text": "Option", "description": "What happens"}]' : '"choices": []'}
}
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text ?? '';

    // Extract JSON from response
    String jsonText = responseText;
    if (jsonText.contains('```json')) {
      jsonText = jsonText.split('```json')[1].split('```')[0].trim();
    } else if (jsonText.contains('```')) {
      jsonText = jsonText.split('```')[1].split('```')[0].trim();
    }

    return jsonDecode(jsonText) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _continueInteractiveStoryWithBackend({
    required String characterName,
    required String theme,
    required String choice,
    required String storySoFar,
    required List<String> choicesMade,
  }) async {
    final response = await http.post(
      Uri.parse('$_localBackendUrl/continue-interactive-story'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'character': characterName,
        'theme': theme,
        'choice': choice,
        'story_so_far': storySoFar,
        'choices_made': choicesMade,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Failed to continue interactive story: ${response.statusCode}');
    }
  }
}
