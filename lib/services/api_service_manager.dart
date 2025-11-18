// lib/services/api_service_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/environment.dart';

import '../character_traits_data.dart';
import 'story_complexity_service.dart';

/// Manages API calls - routes to either local backend or direct Gemini API
/// based on user's API key configuration
class ApiServiceManager {
  static String get _localBackendUrl => Environment.backendUrl;
  static http.Client? _testClient;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    try {
      final response = await httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);
      return _decodeJsonResponse(response, uri);
    } finally {
      if (client == null && _testClient == null) {
        httpClient.close();
      }
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    try {
      final response =
          await httpClient.get(uri).timeout(timeout);
      return _decodeJsonResponse(response, uri);
    } finally {
      if (client == null && _testClient == null) {
        httpClient.close();
      }
    }
  }

  /// Allow tests to inject a mock HTTP client.
  static void setTestClient(http.Client? client) {
    _testClient = client;
  }

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
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    Map<String, dynamic>? currentFeeling,
    Map<String, dynamic>? characterEvolution,
    http.Client? client,
    int maxAttempts = 3,
    Duration retryInitialDelay = const Duration(seconds: 2),
    Duration requestTimeout = const Duration(seconds: 30),
  }) async {
    final useOwnKey = await isUsingOwnApiKey();
    final http.Client? effectiveClient = client ?? _testClient;

    if (useOwnKey) {
      // Use direct Gemini API
      return await _generateStoryWithGemini(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
        rhymeTimeMode: rhymeTimeMode,
        learningToReadMode: learningToReadMode,
        currentFeeling: currentFeeling,
        characterEvolution: characterEvolution,
      );
    } else {
      // Use local Flask backend
      return await _generateStoryWithBackendRetry(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
        rhymeTimeMode: rhymeTimeMode,
        learningToReadMode: learningToReadMode,
        currentFeeling: currentFeeling,
        characterEvolution: characterEvolution,
        client: effectiveClient,
        maxAttempts: maxAttempts,
        initialDelay: retryInitialDelay,
        requestTimeout: requestTimeout,
      );
    }
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response,
    Uri uri,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Request failed (${response.statusCode})',
        uri: uri,
      );
    }

    if (response.body.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  }

  /// Generate story using direct Gemini API
  static Future<String> _generateStoryWithGemini({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    Map<String, dynamic>? currentFeeling,
    Map<String, dynamic>? characterEvolution,
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
      learningToReadMode: learningToReadMode,
      currentFeeling: currentFeeling,
      characterEvolution: characterEvolution,
    );

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  static Future<String> _generateStoryWithBackendRetry({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    Map<String, dynamic>? currentFeeling,
    Map<String, dynamic>? characterEvolution,
    http.Client? client,
    required int maxAttempts,
    required Duration initialDelay,
    required Duration requestTimeout,
  }) async {
    var attempts = 0;
    var delay = initialDelay;

    while (attempts < maxAttempts) {
      try {
        return await _generateStoryWithBackend(
          characterName: characterName,
          theme: theme,
          age: age,
          companion: companion,
          characterDetails: characterDetails,
          additionalCharacters: additionalCharacters,
          rhymeTimeMode: rhymeTimeMode,
          learningToReadMode: learningToReadMode,
          currentFeeling: currentFeeling,
          characterEvolution: characterEvolution,
          client: client,
          requestTimeout: requestTimeout,
        );
      } catch (error) {
        attempts++;
        debugPrint('Story generation attempt $attempts failed: $error');
        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw Exception('Story generation retry handler exhausted unexpectedly');
  }

  /// Generate story using local backend
  static Future<String> _generateStoryWithBackend({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    Map<String, dynamic>? currentFeeling,
    Map<String, dynamic>? characterEvolution,
    http.Client? client,
    required Duration requestTimeout,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final generateUri = Uri.parse('$_localBackendUrl/generate-story');

    final body = {
      'character': characterName,
      'theme': theme,
      'companion': companion,
      'character_age': age,
      'character_details': characterDetails,
      'rhyme_time_mode': rhymeTimeMode,
      'learning_to_read_mode': learningToReadMode,
      'current_feeling': currentFeeling,
      'character_evolution': characterEvolution,
      'additional_characters': additionalCharacters,
    };

    try {
      // 1. Start the task
      final generateResponse = await httpClient.post(
        generateUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(requestTimeout);

      if (generateResponse.statusCode == 200) {
        final payload = jsonDecode(generateResponse.body) as Map<String, dynamic>;
        final story = payload['story'] ?? payload['story_text'];
        if (story is String && story.isNotEmpty) {
          return story;
        }
        throw HttpException(
          'Backend returned 200 without story content',
          uri: generateUri,
        );
      }

      if (generateResponse.statusCode != 202) {
        throw HttpException(
          'Failed to start story generation task: ${generateResponse.statusCode}',
          uri: generateUri,
        );
      }

      final generateData = jsonDecode(generateResponse.body) as Map<String, dynamic>;
      final taskId = generateData['task_id'] as String;

      // 2. Poll for the result
      final statusUri = Uri.parse('$_localBackendUrl/task-status/$taskId');
      const pollInterval = Duration(seconds: 2);
      final stopwatch = Stopwatch()..start();

      while (stopwatch.elapsed < requestTimeout) {
        await Future.delayed(pollInterval);

        final statusResponse = await httpClient.get(statusUri);

        if (statusResponse.statusCode != 200) {
          // Continue polling on server error, but throw if it's a client error
          if (statusResponse.statusCode >= 400 && statusResponse.statusCode < 500) {
            throw HttpException(
              'Failed to get task status: ${statusResponse.statusCode}',
              uri: statusUri,
            );
          }
          // Otherwise, just wait and retry
          continue;
        }

        final statusData = jsonDecode(statusResponse.body);
        final status = statusData['status'] as String;

        if (status == 'complete') {
          final result = statusData['result'];
          return result as String;
        } else if (status == 'failure') {
          throw Exception('Story generation task failed: ${statusData['result']}');
        }
        // If status is 'pending', continue polling
      }

      throw TimeoutException('Story generation polling timed out');

    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Build the story generation prompt (matching backend logic)
  static String _buildTherapeuticPrompt({
    required String characterName,
    required String theme,
    required int age,
    required String lengthGuideline,
    required Map<String, dynamic> currentFeeling,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    Map<String, dynamic>? characterEvolution,
  }) {
    final ageInstructions = StoryComplexityService.buildAgeInstructions(age);
    // Build FEELINGS-CENTERED opening (PRIORITY #1)
    String feelingsSection = '';
    final emotionName = currentFeeling['emotion_name'] as String?;
    final emotionEmoji = currentFeeling['emotion_emoji'] as String?;
    final emotionDescription = currentFeeling['emotion_description'] as String?;
    final intensity = currentFeeling['intensity'] as int?;
    final whatHappened = currentFeeling['what_happened'] as String?;
    final physicalSigns = currentFeeling['physical_signs'] as String?;
    final copingStrategies = currentFeeling['coping_strategies'] as List<dynamic>?;

    String intensityText = '';
    if (intensity != null) {
      if (intensity <= 2) {
        intensityText = 'a little bit ';
      } else if (intensity == 3) {
        intensityText = '';
      } else if (intensity == 4) {
        intensityText = 'quite ';
      } else {
        intensityText = 'very strongly ';
      }
    }

    feelingsSection = '''

🌟 === CURRENT EMOTIONAL STATE (MOST IMPORTANT) === 🌟

$characterName is feeling ${intensityText}$emotionEmoji $emotionName right now.
$emotionName means: $emotionDescription

${whatHappened != null ? "Context: $whatHappened\n" : ""}
Physical signs: $physicalSigns

CRITICAL THERAPEUTIC REQUIREMENTS:
1. START the story by acknowledging this feeling: "$characterName woke up feeling $emotionName today..." or "$characterName was feeling $emotionName because..."
2. The story MUST help $characterName understand and work through this EXACT feeling
3. Show $characterName experiencing the physical sensations: $physicalSigns
4. Have $characterName use these coping strategies naturally in the story:
${copingStrategies?.map((s) => '   - $s').join('\n') ?? ''}
5. By the end, $characterName should feel better about the $emotionName feeling - not making it disappear, but learning to work with it
6. Validate the emotion: "$emotionName is a normal, okay feeling to have"
7. Show that feelings come and go, and we can handle them

This is a FEELINGS-FIRST story. The emotion is the main character's journey.
''';

    // Build character integration if available (SECONDARY to feelings)
    String characterIntegration = '';
    if (characterDetails != null) {
      final fears = characterDetails['fears'] as List<String>?;
      final strengths = characterDetails['strengths'] as List<String>?;
      final likes = characterDetails['likes'] as List<String>?;
      final dislikes = characterDetails['dislikes'] as List<String>?;
      final comfortItem = characterDetails['comfort_item'] as String?;

      if (fears != null && fears.isNotEmpty) {
        characterIntegration += '\n\nCHARACTER FEARS: ${fears.join(", ")}';
        characterIntegration +=
            '\nIf relevant to the current feeling, you may weave in how the feeling relates to these fears.';
      }

      if (strengths != null && strengths.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER STRENGTHS: ${strengths.join(", ")}. Show $characterName using these strengths to cope with the feeling.';
      }

      if (likes != null && likes.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER LIKES: ${likes.join(", ")}. These can be calming or comforting activities in the story.';
      }

      if (dislikes != null && dislikes.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER DISLIKES: ${dislikes.join(", ")}. These can be sources of discomfort connected to the feeling.';
      }

      if (comfortItem != null && comfortItem.isNotEmpty) {
        characterIntegration +=
            '\n\nCOMFORT ITEM: $comfortItem. This item can help $characterName feel safe while processing the emotion.';
      }

      Map<String, dynamic>? sliderMap;
      final rawSliderMap = characterDetails['personality_sliders'];
      if (rawSliderMap is Map<String, dynamic>) {
        sliderMap = rawSliderMap;
      } else if (rawSliderMap is Map) {
        sliderMap = rawSliderMap.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      final sliderText = _buildSliderSummary(sliderMap);
      if (sliderText.isNotEmpty) {
        characterIntegration += sliderText;
      }
    }

    String companionText = '';
    if (companion != null && companion.isNotEmpty) {
      companionText =
          '\n\nCOMPANION: Include $companion as an empathetic friend who helps $characterName understand and cope with their feelings.';
    }

    String multiCharacterText = '';
    if (additionalCharacters != null && additionalCharacters.isNotEmpty) {
      multiCharacterText =
          '\n\nADDITIONAL CHARACTERS: ${additionalCharacters.join(", ")}. These characters can support $characterName emotionally.';
    }

    // Build character evolution context
    String evolutionContext = '';
    if (characterEvolution != null) {
      final developmentStage = characterEvolution['development_stage'] as String?;
      final therapeuticProgress = characterEvolution['therapeutic_progress'] as Map<String, dynamic>?;
      final emotionMastery = characterEvolution['emotion_mastery'] as Map<String, dynamic>?;
      final evolvedTraits = characterEvolution['evolved_traits'] as Map<String, dynamic>?;
      if (developmentStage != null) {
        evolutionContext += '\n\nCHARACTER DEVELOPMENT STAGE: $characterName is at the "$developmentStage" stage of emotional development.';

        // Adapt story complexity based on development stage
        switch (developmentStage.toLowerCase()) {
          case 'novice':
          case 'beginner':
            evolutionContext += '\nCreate a simpler story with basic emotional learning. Focus on naming feelings and simple coping strategies.';
            break;
          case 'intermediate':
            evolutionContext += '\nCreate a moderately complex story. Include emotional regulation techniques and some problem-solving.';
            break;
          case 'advanced':
            evolutionContext += '\nCreate a complex story with deeper emotional processing. Include perspective-taking and helping others.';
            break;
          case 'master':
            evolutionContext += '\nCreate an advanced story focused on emotional leadership. Include teaching others and complex emotional situations.';
            break;
        }
      }

      if (therapeuticProgress != null && therapeuticProgress.isNotEmpty) {
        evolutionContext += '\n\nTHERAPEUTIC STRENGTHS: $characterName has experience with: ${therapeuticProgress.keys.join(", ")}.';
        evolutionContext += '\nBuild upon these existing therapeutic skills in the story.';
      }

      if (emotionMastery != null && emotionMastery.isNotEmpty) {
        final masteredEmotions = emotionMastery.entries
            .where((e) => (e.value as int) >= 50)
            .map((e) => e.key)
            .toList();
        if (masteredEmotions.isNotEmpty) {
          evolutionContext += '\n\nEMOTION MASTERY: $characterName is skilled with these emotions: ${masteredEmotions.join(", ")}.';
          evolutionContext += '\nChallenge them with new emotional experiences or reinforce their mastery.';
        }
      }

      if (evolvedTraits != null) {
        final confidence = evolvedTraits['confidence'] as int?;
        final empathy = evolvedTraits['empathy'] as int?;
        final emotionalIntelligence = evolvedTraits['emotional_intelligence'] as int?;

        if (confidence != null && confidence > 50) {
          evolutionContext += '\n\nCHARACTER TRAIT: $characterName has grown confident (${confidence}%). Show them taking brave actions.';
        }
        if (empathy != null && empathy > 50) {
          evolutionContext += '\n\nCHARACTER TRAIT: $characterName has developed empathy (${empathy}%). Include opportunities to understand others\' feelings.';
        }
        if (emotionalIntelligence != null && emotionalIntelligence > 50) {
          evolutionContext += '\n\nCHARACTER TRAIT: $characterName has strong emotional intelligence (${emotionalIntelligence}%). Create nuanced emotional challenges.';
        }
      }
    }

    return '''
You are a therapeutic storyteller specializing in EMOTION-FOCUSED stories for children and young people.

Create a $lengthGuideline FEELINGS-CENTERED story about $characterName (age $age) with a $theme theme.$companionText$multiCharacterText$feelingsSection$characterIntegration$evolutionContext

$ageInstructions
FEELINGS-FIRST STORY STRUCTURE:
1. FEELING ACKNOWLEDGMENT: Begin by showing $characterName experiencing their current emotion. "Today $characterName felt..." or "$characterName woke up feeling..."
2. PHYSICAL AWARENESS: Show how the emotion feels in their body
3. SITUATION: What's happening in their life that connects to this feeling
4. COPING JOURNEY: Show $characterName trying healthy ways to cope (from the list above)
5. EMOTIONAL PROCESSING: $characterName talks about the feeling, understands it better
6. RESOLUTION: The feeling softens (not disappears) as $characterName learns they can handle it
7. WISDOM: End with validation that all feelings are okay and temporary

CRITICAL WRITING GUIDELINES:
✓ The emotion IS the story - make it central, not background
✓ Use the child's actual current feeling, don't change it
✓ Show physical sensations of emotions vividly
✓ Validate the emotion: "It's okay to feel [emotion]"
✓ Include self-talk: "$characterName thought to themselves..."
✓ Show emotions as temporary: "After a while, the feeling started to feel smaller..."
✓ End with empowerment: "$characterName felt proud for handling their feelings"
✓ Age-appropriate language for a $age-year-old
✓ Sensory details and vivid imagery
✓ Natural, realistic dialogue

Remember: This is a story about FEELINGS, not just adventure. The emotional journey is the plot.

Create the feelings-focused therapeutic story now:
''';
  }

  static String _buildAdventurePrompt({
    required String characterName,
    required String theme,
    required int age,
    required String lengthGuideline,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    Map<String, dynamic>? characterEvolution,
  }) {
    final ageInstructions = StoryComplexityService.buildAgeInstructions(age);
    // Build character integration
    String characterIntegration = '';
    if (characterDetails != null) {
      final fears = characterDetails['fears'] as List<String>?;
      final strengths = characterDetails['strengths'] as List<String>?;
      final likes = characterDetails['likes'] as List<String>?;
      final dislikes = characterDetails['dislikes'] as List<String>?;
      final comfortItem = characterDetails['comfort_item'] as String?;

      if (fears != null && fears.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER FEARS: ${fears.join(", ")}. The story can involve $characterName facing or learning about these fears.';
      }
      if (strengths != null && strengths.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER STRENGTHS: ${strengths.join(", ")}. Show $characterName using these strengths in the adventure.';
      }
      if (likes != null && likes.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER LIKES: ${likes.join(", ")}. Weave these interests into the story naturally.';
      }
      if (dislikes != null && dislikes.isNotEmpty) {
        characterIntegration +=
            '\n\nCHARACTER DISLIKES: ${dislikes.join(", ")}. These can appear as challenges to overcome with support.';
      }
      if (comfortItem != null && comfortItem.isNotEmpty) {
        characterIntegration +=
            '\n\nCOMFORT ITEM: $comfortItem. This special item can be part of the adventure.';
      }
    }

    String companionText = '';
    if (companion != null && companion.isNotEmpty) {
      companionText =
          '\n\nCOMPANION: Include $companion as $characterName\'s friend and adventure partner.';
    }

    String multiCharacterText = '';
    if (additionalCharacters != null && additionalCharacters.isNotEmpty) {
      multiCharacterText =
          '\n\nADDITIONAL CHARACTERS: ${additionalCharacters.join(", ")}. These characters join the adventure.';
    }

    // Build character evolution context for adventure stories
    String evolutionContext = '';
    if (characterEvolution != null) {
      final developmentStage = characterEvolution['development_stage'] as String?;
      final therapeuticProgress = characterEvolution['therapeutic_progress'] as Map<String, dynamic>?;
      final emotionMastery = characterEvolution['emotion_mastery'] as Map<String, dynamic>?;
      final evolvedTraits = characterEvolution['evolved_traits'] as Map<String, dynamic>?;

      if (developmentStage != null) {
        evolutionContext += '\n\nCHARACTER DEVELOPMENT STAGE: $characterName is at the "$developmentStage" stage of emotional development.';

        // Adapt adventure complexity based on development stage
        switch (developmentStage.toLowerCase()) {
          case 'novice':
          case 'beginner':
            evolutionContext += '\nCreate a simple adventure with clear emotional lessons. Focus on basic feelings and simple friendships.';
            break;
          case 'intermediate':
            evolutionContext += '\nCreate a moderately challenging adventure. Include teamwork, emotional awareness, and helping others.';
            break;
          case 'advanced':
            evolutionContext += '\nCreate a complex adventure with emotional depth. Include leadership, empathy, and complex social situations.';
            break;
          case 'master':
            evolutionContext += '\nCreate an epic adventure focused on emotional wisdom. Include mentoring others and profound emotional insights.';
            break;
        }
      }

      if (therapeuticProgress != null && therapeuticProgress.isNotEmpty) {
        evolutionContext += '\n\nTHERAPEUTIC STRENGTHS: $characterName has experience with: ${therapeuticProgress.keys.join(", ")}.';
        evolutionContext += '\nIncorporate these therapeutic themes naturally into the adventure.';
      }

      if (evolvedTraits != null) {
        final confidence = evolvedTraits['confidence'] as int?;
        final empathy = evolvedTraits['empathy'] as int?;

        if (confidence != null && confidence > 50) {
          evolutionContext += '\n\nCHARACTER TRAIT: $characterName has grown confident (${confidence}%). Show them taking leadership in the adventure.';
        }
        if (empathy != null && empathy > 50) {
          evolutionContext += '\n\nCHARACTER TRAIT: $characterName has developed empathy (${empathy}%). Include moments where they understand and help others emotionally.';
        }
      }
    }

    return '''
You are an engaging storyteller creating fun, age-appropriate adventure stories for children.

Create a $lengthGuideline adventure story about $characterName (age $age) with a $theme theme.$companionText$multiCharacterText$characterIntegration$evolutionContext

$ageInstructions
ADVENTURE STORY GUIDELINES:
✓ Focus on exciting plot and engaging adventure
✓ Include problem-solving and creative thinking
✓ Show characters working together and supporting each other
✓ Weave in emotional awareness naturally (characters notice feelings, support each other)
✓ Positive messages about friendship, courage, kindness
✓ Age-appropriate challenges and victories
✓ Vivid sensory details and imagery
✓ Natural, realistic dialogue
✓ Fun and entertaining while being meaningful

STORY STRUCTURE:
1. EXCITING OPENING: Hook the reader with an interesting situation or discovery
2. ADVENTURE BEGINS: $characterName faces a challenge or embarks on a quest
3. OBSTACLES: Show creative problem-solving and teamwork
4. EMOTIONAL MOMENTS: Characters naturally notice and support each other's feelings
5. CLIMAX: The main challenge is overcome through effort and cooperation
6. RESOLUTION: Satisfying ending that shows growth and friendship
7. CLOSING: End with a sense of accomplishment and possibility

Remember: This is primarily an ADVENTURE story. Make it fun, exciting, and engaging while including natural emotional intelligence.

Create the adventure story now:
''';
   }

   static String _buildLearningToReadPrompt({
     required String characterName,
     required String theme,
     required int age,
     String? companion,
     Map<String, dynamic>? characterDetails,
     List<String>? additionalCharacters,
   }) {
     String detailSection = '';
    List<String>? extractStringList(dynamic raw) {
      if (raw is List) {
        return raw.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return null;
    }

    String formatDetail(String label, List<String>? values) {
      if (values == null || values.isEmpty) return '';
      return '\n$label: ${values.take(5).join(", ")}';
    }

    if (characterDetails != null) {
      final likes = extractStringList(characterDetails['likes']);
      final strengths = extractStringList(characterDetails['strengths']);
      final comfortItem = characterDetails['comfort_item'] as String?;

      detailSection += formatDetail('LIKES', likes);
      detailSection += formatDetail('STRENGTHS', strengths);
      if (comfortItem != null && comfortItem.isNotEmpty) {
        detailSection += '\nCOMFORT ITEM: $comfortItem';
      }
    }

    if (additionalCharacters != null && additionalCharacters.isNotEmpty) {
      detailSection +=
          '\nFRIENDS IN STORY: ${additionalCharacters.join(", ")}';
    }

    String companionText = '';
    if (companion != null && companion.isNotEmpty && companion != 'None') {
      companionText = '\nCOMPANION: Include $companion as a gentle helper.';
    }

    return '''
You are creating a LEARNING TO READ rhyming story for a ${age}-year-old named $characterName.

STRICT REQUIREMENTS (NO EXCEPTIONS):
1. TOTAL LENGTH: 50-100 words (stop inside this range).
2. RHYME PATTERN: Simple AABB scheme (line 1 rhymes with 2, line 3 rhymes with 4, etc.).
3. LINE LENGTH: 4-6 short words per line (keep it punchy).
4. VOCABULARY: Only CVC words (cat, dog, hop, sun) and common sight words (the, and, can, see, like, play). No tricky spellings, blends, or silent letters.
5. STRUCTURE: Repetition helps reading. Use predictable frames like "Can $characterName ___? Yes! $characterName can ___!".
6. TONE: Encouraging, musical, and confidence-building.
7. FORMAT: Each sentence or phrase on its own line for easy finger-tracking.

THEME: $theme$companionText$detailSection

Create the rhyming learning-to-read story about $characterName now:
''';
   }

  static String _buildStoryPrompt({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool learningToReadMode = false,
    Map<String, dynamic>? currentFeeling,
    Map<String, dynamic>? characterEvolution,
  }) {
    final guidelines = StoryComplexityService.getAgeGuidelines(age);
    final lengthGuideline =
        (guidelines['length_guideline'] as String?) ?? '200-300 words';

    if (learningToReadMode) {
      return _buildLearningToReadPrompt(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
      );
    }

    if (currentFeeling != null) {
      return _buildTherapeuticPrompt(
        characterName: characterName,
        theme: theme,
        age: age,
        lengthGuideline: lengthGuideline,
        currentFeeling: currentFeeling,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
      );
    } else {
      return _buildAdventurePrompt(
        characterName: characterName,
        theme: theme,
        age: age,
        lengthGuideline: lengthGuideline,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
      );
    }
  }

  static String _buildSliderSummary(Map<String, dynamic>? sliderValues) {
    if (sliderValues == null || sliderValues.isEmpty) {
      return '';
    }
    final buffer = StringBuffer('\n\nPERSONALITY STYLE INSIGHTS:\n');
    var hasData = false;
    for (final slider in CharacterTraitsData.personalitySliders) {
      final parsedValue = _parseSliderValue(sliderValues[slider.key]);
      if (parsedValue == null) {
        continue;
      }
      hasData = true;
      final towardLabel =
          parsedValue > 50 ? slider.rightLabel : slider.leftLabel;
      buffer.writeln(
        '- ${slider.label}: ${slider.describeValue(parsedValue)} '
        '(${parsedValue}/100 toward ${towardLabel.toLowerCase()})',
      );
    }
    return hasData ? buffer.toString() : '';
  }

  static int? _parseSliderValue(dynamic value) {
    if (value is num) {
      return value.clamp(0, 100).round();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(0, 100).round();
      }
    }
    return null;
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
