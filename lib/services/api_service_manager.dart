// lib/services/api_service_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/secure_storage_service.dart';

import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/environment.dart';

import '../character_traits_data.dart';
import '../models/api_error.dart';
import '../models/story_generation_result.dart';
import 'story_complexity_service.dart';
import 'user_identity_service.dart';

/// Manages API calls - routes to either local backend or direct Gemini API
/// based on user's API key configuration
class ApiServiceManager {
  static String get _localBackendUrl => Environment.backendUrl;
  static http.Client? _testClient;
  static String? _authToken;
  static String? _refreshToken;
  static String? _userId;
  static Future<void>? _authInFlight;
  static const String _tokenKey = 'story_weaver_auth_token';
  static const String _refreshTokenKey = 'story_weaver_refresh_token';
  static const String _userIdKey = 'story_weaver_user_id';

  static bool get _isLocalBackend {
    return _localBackendUrl.contains('127.0.0.1') ||
        _localBackendUrl.contains('localhost') ||
        _localBackendUrl.contains('10.0.2.2');
  }

  static String _buildConnectionErrorMessage() {
    if (_isLocalBackend) {
      return 'Cannot reach the local backend at $_localBackendUrl.\n\n'
          'Start it with: python backend/app.py\n'
          'Then retry.';
    }
    return 'Cannot connect to server. Please check your internet connection and try again.\n\n'
        'Server: $_localBackendUrl';
  }

  static String _buildClientErrorMessage(http.ClientException error) {
    final normalized = error.message.toLowerCase();
    if (_isLocalBackend &&
        (normalized.contains('failed to fetch') ||
            normalized.contains('connection refused') ||
            normalized.contains('networkerror'))) {
      return _buildConnectionErrorMessage();
    }
    return 'Request failed: ${error.message}\n\nPlease try again.';
  }

  /// Get auth headers including the JWT token
  Future<Map<String, String>> _getAuthHeaders() async {
    await _ensureAuthenticated();
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// Static helper — ensures auth then returns JSON headers with Bearer token.
  /// Use this from services that don't own an ApiServiceManager instance.
  static Future<Map<String, String>> authHeaders() async {
    final mgr = ApiServiceManager();
    await mgr._ensureAuthenticated();
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// Clears any cached auth tokens and immediately re-authenticates.
  /// Useful for one-off retry flows (e.g., multipart uploads) that receive 401.
  static Future<void> resetAndReauthenticate() async {
    final mgr = ApiServiceManager();
    await mgr._clearAuthState();
    await mgr._ensureAuthenticated();
  }

  /// Ensure we have a valid auth token (get anonymous token if needed)
  Future<void> _ensureAuthenticated() async {
    if (_authInFlight != null) {
      await _authInFlight;
      return;
    }

    final current = _doEnsureAuthenticated();
    _authInFlight = current;
    try {
      await current;
    } finally {
      if (identical(_authInFlight, current)) {
        _authInFlight = null;
      }
    }
  }

  Future<void> _doEnsureAuthenticated() async {
    if (_authToken != null) return;

    // Try to load from storage
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _userId = prefs.getString(_userIdKey);

    if (_authToken != null) {
      debugPrint('✅ Loaded auth token from storage');
      return;
    }

    // Get new anonymous token
    debugPrint('🔐 Getting anonymous auth token...');
    try {
      final client = _testClient ?? http.Client();
      final uri = Uri.parse('$_localBackendUrl/auth/anonymous');
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_id': _userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user_id'];

        // Save to storage
        await prefs.setString(_tokenKey, _authToken!);
        if (_refreshToken != null && _refreshToken!.isNotEmpty) {
          await prefs.setString(_refreshTokenKey, _refreshToken!);
        }
        await prefs.setString(_userIdKey, _userId!);
        debugPrint('✅ Got anonymous auth token for user: $_userId');
      } else {
        debugPrint('⚠️ Failed to get anonymous token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Error getting anonymous token: $e');
    }
  }

  Future<void> _clearAuthState() async {
    _authToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<bool> _tryRefreshAccessToken({
    required http.Client httpClient,
    required Duration timeout,
  }) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }

    try {
      final response = await httpClient.post(
        Uri.parse('$_localBackendUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_refreshToken',
        },
      ).timeout(timeout);

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = data['token']?.toString();
      if (newToken == null || newToken.isEmpty) {
        return false;
      }

      _authToken = newToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the current user ID
  Future<String?> getUserId() async {
    await _ensureAuthenticated();
    return _userId;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    final headers = await _getAuthHeaders();
    try {
      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      // Handle 401 Unauthorized - Retry logic
      if (response.statusCode == 401) {
        debugPrint('⚠️ 401 Unauthorized from $uri. Refreshing token...');
        final refreshed = await _tryRefreshAccessToken(
          httpClient: httpClient,
          timeout: timeout,
        );
        if (!refreshed) {
          await _clearAuthState();
          await _ensureAuthenticated();
        }

        final newHeaders = await _getAuthHeaders();
        final retryResponse = await httpClient
            .post(
              uri,
              headers: newHeaders,
              body: jsonEncode(payload),
            )
            .timeout(timeout);
        return _decodeJsonResponse(retryResponse, uri);
      }

      return _decodeJsonResponse(response, uri);
    } on TimeoutException catch (error) {
      debugPrint('POST $uri timed out after ${timeout.inSeconds}s: $error');
      throw TimeoutException(
        'Request to ${uri.path} timed out. Please try again.',
        timeout,
      );
    } on SocketException catch (error) {
      debugPrint('❌ Network error while calling $uri');
      debugPrint('   Error details: $error');
      debugPrint('   Backend URL: $_localBackendUrl');
      throw Exception(
        _buildConnectionErrorMessage(),
      );
    } on HandshakeException catch (error) {
      debugPrint('❌ SSL/TLS error while calling $uri: $error');
      throw Exception(
        'Secure connection failed. This might be a certificate issue.\n\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      debugPrint('❌ HTTP Client error while calling $uri: $error');
      throw Exception(
        _buildClientErrorMessage(error),
      );
    }
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    final headers = await _getAuthHeaders();
    try {
      final response = await httpClient
          .put(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      // Handle 401 Unauthorized - Retry logic
      if (response.statusCode == 401) {
        debugPrint('⚠️ 401 Unauthorized from $uri. Refreshing token...');
        final refreshed = await _tryRefreshAccessToken(
          httpClient: httpClient,
          timeout: timeout,
        );
        if (!refreshed) {
          await _clearAuthState();
          await _ensureAuthenticated();
        }

        final newHeaders = await _getAuthHeaders();
        final retryResponse = await httpClient
            .put(
              uri,
              headers: newHeaders,
              body: jsonEncode(payload),
            )
            .timeout(timeout);
        return _decodeJsonResponse(retryResponse, uri);
      }

      return _decodeJsonResponse(response, uri);
    } on TimeoutException catch (error) {
      debugPrint('PUT $uri timed out after ${timeout.inSeconds}s: $error');
      throw TimeoutException(
        'Request to ${uri.path} timed out. Please try again.',
        timeout,
      );
    } on SocketException {
      debugPrint('❌ Network error while calling $uri');
      throw Exception(
        _buildConnectionErrorMessage(),
      );
    } on HandshakeException catch (error) {
      debugPrint('❌ SSL/TLS error while calling $uri: $error');
      throw Exception(
        'Secure connection failed. This might be a certificate issue.',
      );
    } on http.ClientException catch (error) {
      debugPrint('❌ HTTP Client error while calling $uri: $error');
      throw Exception(
        _buildClientErrorMessage(error),
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    final headers = await _getAuthHeaders();
    try {
      final response = await httpClient
          .patch(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      // Handle 401 Unauthorized - Retry logic
      if (response.statusCode == 401) {
        debugPrint('⚠️ 401 Unauthorized from $uri. Refreshing token...');
        final refreshed = await _tryRefreshAccessToken(
          httpClient: httpClient,
          timeout: timeout,
        );
        if (!refreshed) {
          await _clearAuthState();
          await _ensureAuthenticated();
        }

        final newHeaders = await _getAuthHeaders();
        final retryResponse = await httpClient
            .patch(
              uri,
              headers: newHeaders,
              body: jsonEncode(payload),
            )
            .timeout(timeout);
        return _decodeJsonResponse(retryResponse, uri);
      }

      return _decodeJsonResponse(response, uri);
    } on TimeoutException catch (error) {
      debugPrint('PATCH $uri timed out after ${timeout.inSeconds}s: $error');
      throw TimeoutException(
        'Request to ${uri.path} timed out. Please try again.',
        timeout,
      );
    } on SocketException {
      debugPrint('❌ Network error while calling $uri');
      throw Exception(
        _buildConnectionErrorMessage(),
      );
    } on HandshakeException catch (error) {
      debugPrint('❌ SSL/TLS error while calling $uri: $error');
      throw Exception(
        'Secure connection failed. This might be a certificate issue.',
      );
    } on http.ClientException catch (error) {
      debugPrint('❌ HTTP Client error while calling $uri: $error');
      throw Exception(
        _buildClientErrorMessage(error),
      );
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    final headers = await _getAuthHeaders();
    try {
      final response =
          await httpClient.get(uri, headers: headers).timeout(timeout);

      // Handle 401 Unauthorized - Retry logic
      if (response.statusCode == 401) {
        debugPrint('⚠️ 401 Unauthorized from $uri. Refreshing token...');
        final refreshed = await _tryRefreshAccessToken(
          httpClient: httpClient,
          timeout: timeout,
        );
        if (!refreshed) {
          await _clearAuthState();
          await _ensureAuthenticated();
        }

        final newHeaders = await _getAuthHeaders();
        final retryResponse =
            await httpClient.get(uri, headers: newHeaders).timeout(timeout);
        return _decodeJsonResponse(retryResponse, uri);
      }

      return _decodeJsonResponse(response, uri);
    } on TimeoutException catch (error) {
      debugPrint('GET $uri timed out after ${timeout.inSeconds}s: $error');
      throw TimeoutException(
        'Request to ${uri.path} timed out. Please try again.',
        timeout,
      );
    } on SocketException catch (error) {
      debugPrint('❌ Network error while calling $uri');
      debugPrint('   Error details: $error');
      debugPrint('   Backend URL: $_localBackendUrl');
      throw Exception(
        _buildConnectionErrorMessage(),
      );
    } on HandshakeException catch (error) {
      debugPrint('❌ SSL/TLS error while calling $uri: $error');
      throw Exception(
        'Secure connection failed. This might be a certificate issue.\n\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      debugPrint('❌ HTTP Client error while calling $uri: $error');
      throw Exception(
        _buildClientErrorMessage(error),
      );
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Duration timeout = const Duration(seconds: 15),
    http.Client? client,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl$path');
    final headers = await _getAuthHeaders();
    try {
      final response =
          await httpClient.delete(uri, headers: headers).timeout(timeout);

      // Handle 401 Unauthorized - Retry logic
      if (response.statusCode == 401) {
        debugPrint('⚠️ 401 Unauthorized from $uri. Refreshing token...');
        final refreshed = await _tryRefreshAccessToken(
          httpClient: httpClient,
          timeout: timeout,
        );
        if (!refreshed) {
          await _clearAuthState();
          await _ensureAuthenticated();
        }

        final newHeaders = await _getAuthHeaders();
        final retryResponse =
            await httpClient.delete(uri, headers: newHeaders).timeout(timeout);
        return _decodeJsonResponse(retryResponse, uri);
      }

      return _decodeJsonResponse(response, uri);
    } on TimeoutException catch (error) {
      debugPrint('DELETE $uri timed out after ${timeout.inSeconds}s: $error');
      throw TimeoutException(
        'Request to ${uri.path} timed out. Please try again.',
        timeout,
      );
    } on SocketException catch (error) {
      debugPrint('❌ Network error while calling $uri');
      debugPrint('   Error details: $error');
      throw Exception(
        _buildConnectionErrorMessage(),
      );
    } on http.ClientException catch (error) {
      debugPrint('❌ HTTP Client error while calling $uri: $error');
      throw Exception(
        _buildClientErrorMessage(error),
      );
    }
  }

  /// Allow tests to inject a mock HTTP client.
  static void setTestClient(http.Client? client) {
    _testClient = client;
  }

  /// Check if user has configured their own API key
  static Future<bool> isUsingOwnApiKey() async {
    final apiKey = await SecureStorageService.getApiKey('gemini');
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Get user's API key (if configured)
  static Future<String?> getUserApiKey() async {
    return SecureStorageService.getApiKey('gemini');
  }

  /// Check if user has premium access (either BYOK or paid)
  static Future<bool> hasPremiumAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final byokPremium = prefs.getBool('is_premium_byok') ?? false;
    final paidPremium = prefs.getBool('is_paid_premium') ?? false;
    return byokPremium || paidPremium;
  }

  /// Generate a story using appropriate method (backend or direct API)
  static Future<StoryGenerationResult> generateStory({
    required String characterName,
    required String theme,
    required int age,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    bool includeIllustrations = false,
    String subscriptionTier = 'free',
    Map<String, dynamic>? currentFeeling,
    String? feelingTrigger,
    String? bodySignal,
    String? copingTool,
    String? repairGoal,
    String? parentHiddenContext,
    Map<String, dynamic>? characterEvolution,
    http.Client? client,
    int maxAttempts = 3,
    Duration retryInitialDelay = const Duration(seconds: 2),
    Duration requestTimeout = const Duration(seconds: 90),
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    String storyLength = 'standard',
    String customElements = '', // NEW: Custom elements
    bool bedtimeMode = false,
    String bedtimeMood = 'calming',
    void Function(String)? onProgress,
  }) async {
    final useOwnKey = await isUsingOwnApiKey();
    final userId = await UserIdentityService.getOrCreateUserId();
    final String normalizedTier =
        (subscriptionTier.isEmpty ? 'free' : subscriptionTier).toLowerCase();
    final http.Client? effectiveClient = client ?? _testClient;

    final bool needsBackendForFeatures = includeIllustrations ||
        learningToReadMode ||
        currentFeeling != null ||
        (childProfileId != null && childProfileId.trim().isNotEmpty);

    if (!useOwnKey || needsBackendForFeatures) {
      final userApiKey = useOwnKey ? await getUserApiKey() : null;
      return await _generateStoryWithBackendRetry(
        characterName: characterName,
        theme: theme,
        age: age,
        childProfileId: childProfileId,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
        rhymeTimeMode: rhymeTimeMode,
        learningToReadMode: learningToReadMode,
        includeIllustrations: includeIllustrations,
        subscriptionTier: normalizedTier,
        userId: userId,
        userApiKey: userApiKey,
        currentFeeling: currentFeeling,
        feelingTrigger: feelingTrigger,
        bodySignal: bodySignal,
        copingTool: copingTool,
        repairGoal: repairGoal,
        parentHiddenContext: parentHiddenContext,
        characterEvolution: characterEvolution,
        client: effectiveClient,
        maxAttempts: maxAttempts,
        initialDelay: retryInitialDelay,
        requestTimeout: requestTimeout,
        companionPets: companionPets,
        companionCharacters: companionCharacters,
        storyLength: storyLength,
        customElements: customElements,
        bedtimeMode: bedtimeMode,
        bedtimeMood: bedtimeMood,
        onProgress: onProgress,
      );
    }

    return await _generateStoryWithGemini(
      characterName: characterName,
      theme: theme,
      age: age,
      childProfileId: childProfileId,
      companion: companion,
      characterDetails: characterDetails,
      additionalCharacters: additionalCharacters,
      rhymeTimeMode: rhymeTimeMode,
      learningToReadMode: learningToReadMode,
      includeIllustrations: includeIllustrations,
      currentFeeling: currentFeeling,
      feelingTrigger: feelingTrigger,
      bodySignal: bodySignal,
      copingTool: copingTool,
      repairGoal: repairGoal,
      parentHiddenContext: parentHiddenContext,
      characterEvolution: characterEvolution,
      companionPets: companionPets,
      companionCharacters: companionCharacters,
      storyLength: storyLength,
      customElements: customElements,
      bedtimeMode: bedtimeMode,
      bedtimeMood: bedtimeMood,
    );
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response,
    Uri uri,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final preview = _truncateForLog(response.body);
      debugPrint(
        'Request to $uri failed with ${response.statusCode}. Body preview: $preview',
      );

      // Try to parse structured error response from backend
      if (response.body.isNotEmpty) {
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map<String, dynamic> &&
              (errorJson.containsKey('error_code') ||
                  errorJson.containsKey('error') ||
                  errorJson.containsKey('message'))) {
            throw ApiError.fromJson(errorJson);
          }
        } catch (e) {
          if (e is ApiError) rethrow;
          // Fall through to generic error if JSON parsing fails
        }
      }

      throw HttpException(
        'Request to ${uri.path} failed with status ${response.statusCode}',
        uri: uri,
      );
    }

    if (response.body.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        // Check if success response contains an error field
        if (decoded.containsKey('error_code') &&
            decoded['error_code'] != null) {
          throw ApiError.fromJson(decoded);
        }
        return decoded;
      }
      return {'data': decoded};
    } on FormatException catch (error) {
      debugPrint('Failed to parse JSON from $uri: ${error.message}');
      throw const FormatException('Unexpected response format from server');
    } on ApiError {
      rethrow;
    }
  }

  static String _truncateForLog(String body, {int maxLength = 200}) {
    if (body.length <= maxLength) return body;
    return '${body.substring(0, maxLength)}...';
  }

  /// Generate story using direct Gemini API
  static Future<StoryGenerationResult> _generateStoryWithGemini({
    required String characterName,
    required String theme,
    required int age,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    bool includeIllustrations = false,
    Map<String, dynamic>? currentFeeling,
    String? feelingTrigger,
    String? bodySignal,
    String? copingTool,
    String? repairGoal,
    String? parentHiddenContext,
    Map<String, dynamic>? characterEvolution,
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    String storyLength = 'standard',
    String customElements = '',
    bool bedtimeMode = false,
    String bedtimeMood = 'calming',
  }) async {
    final apiKey = await getUserApiKey();
    if (apiKey == null) {
      throw Exception(
        'No API key configured. Add your Gemini key in Settings to generate stories directly.',
      );
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    // Build the prompt — use bedtime-specific builder when in bedtime mode.
    final prompt = bedtimeMode
        ? _buildBedtimePrompt(
            characterName: characterName,
            theme: theme,
            age: age,
            mood: bedtimeMood,
            companion: companion,
            additionalCharacters: additionalCharacters,
            companionPets: companionPets,
            companionCharacters: companionCharacters,
            storyLength: storyLength,
          )
        : _buildStoryPrompt(
            characterName: characterName,
            theme: theme,
            age: age,
            companion: companion,
            characterDetails: characterDetails,
            additionalCharacters: additionalCharacters,
            learningToReadMode: learningToReadMode,
            currentFeeling: currentFeeling,
            feelingTrigger: feelingTrigger,
            bodySignal: bodySignal,
            copingTool: copingTool,
            repairGoal: repairGoal,
            parentHiddenContext: parentHiddenContext,
            characterEvolution: characterEvolution,
            companionPets: companionPets,
            companionCharacters: companionCharacters,
            storyLength: storyLength,
            customElements: customElements,
          );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final storyText = response.text ?? '';

      if (storyText.isEmpty) {
        throw StateError(
            'Gemini returned an empty response for story content.');
      }

      // Try to parse as JSON if it looks like JSON
      final trimmed = storyText.trim();
      if (trimmed.startsWith('{') || trimmed.contains('"pages":')) {
        try {
          // Clean potential markdown fences
          var cleanText = trimmed;
          if (cleanText.startsWith('```')) {
            cleanText = cleanText.replaceAll(
                RegExp(r'^```(?:json)?\s*', multiLine: true), '');
            cleanText =
                cleanText.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
          }
          final data = jsonDecode(cleanText);
          return StoryGenerationResult.fromBackend(
              {'story': data, 'used_user_key': true});
        } catch (e) {
          debugPrint('Failed to parse Gemini JSON: $e');
          // Fallback to legacy parsing if JSON fails
        }
      }

      return StoryGenerationResult(
        storyText: storyText,
        title: null,
        wisdomGem: null,
        usedUserKey: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Gemini story generation failed: $error');
      Error.throwWithStackTrace(
        Exception(
          'Could not generate story with Gemini at this time. Please try again shortly.',
        ),
        stackTrace,
      );
    }
  }

  static Future<StoryGenerationResult> _generateStoryWithBackendRetry({
    required String characterName,
    required String theme,
    required int age,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    bool includeIllustrations = false,
    required String subscriptionTier,
    required String userId,
    String? userApiKey,
    Map<String, dynamic>? currentFeeling,
    String? feelingTrigger,
    String? bodySignal,
    String? copingTool,
    String? repairGoal,
    String? parentHiddenContext,
    Map<String, dynamic>? characterEvolution,
    http.Client? client,
    required int maxAttempts,
    required Duration initialDelay,
    required Duration requestTimeout,
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    required String storyLength,
    String customElements = '',
    bool bedtimeMode = false,
    String bedtimeMood = 'calming',
    void Function(String)? onProgress,
  }) async {
    var attempts = 0;
    var delay = initialDelay;

    while (attempts < maxAttempts) {
      try {
        return await _generateStoryWithBackend(
          characterName: characterName,
          theme: theme,
          age: age,
          childProfileId: childProfileId,
          companion: companion,
          characterDetails: characterDetails,
          additionalCharacters: additionalCharacters,
          rhymeTimeMode: rhymeTimeMode,
          learningToReadMode: learningToReadMode,
          includeIllustrations: includeIllustrations,
          subscriptionTier: subscriptionTier,
          userId: userId,
          userApiKey: userApiKey,
          currentFeeling: currentFeeling,
          feelingTrigger: feelingTrigger,
          bodySignal: bodySignal,
          copingTool: copingTool,
          repairGoal: repairGoal,
          parentHiddenContext: parentHiddenContext,
          characterEvolution: characterEvolution,
          client: client,
          requestTimeout: requestTimeout,
          companionPets: companionPets,
          companionCharacters: companionCharacters,
          storyLength: storyLength,
          customElements: customElements,
          bedtimeMode: bedtimeMode,
          bedtimeMood: bedtimeMood,
          onProgress: onProgress,
        );
      } catch (error, stackTrace) {
        attempts++;
        debugPrint('Story generation attempt $attempts failed: $error');
        try {
          if (!Platform.environment.containsKey('FLUTTER_TEST')) {
            if (kDebugMode &&
                !Platform.environment.containsKey('FLUTTER_TEST')) {
              debugPrintStack(stackTrace: stackTrace);
            }
          }
        } catch (_) {}
        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw Exception('Story generation retry handler exhausted unexpectedly');
  }

  /// Generate story using local backend
  static Future<StoryGenerationResult> _generateStoryWithBackend({
    required String characterName,
    required String theme,
    required int age,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    bool includeIllustrations = false,
    required String subscriptionTier,
    required String userId,
    String? userApiKey,
    Map<String, dynamic>? currentFeeling,
    String? feelingTrigger,
    String? bodySignal,
    String? copingTool,
    String? repairGoal,
    String? parentHiddenContext,
    Map<String, dynamic>? characterEvolution,
    http.Client? client,
    required Duration requestTimeout,
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    required String storyLength,
    String customElements = '',
    bool bedtimeMode = false,
    String bedtimeMood = 'calming',
    void Function(String)? onProgress,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final generateUri = Uri.parse('$_localBackendUrl/generate-story');

    final body = {
      'character': characterName.isNotEmpty ? characterName : 'Hero',
      'theme': theme,
      'child_profile_id': childProfileId,
      'companion': companion,
      'character_age': age,
      'character_details': characterDetails,
      'rhyme_time_mode': rhymeTimeMode,
      'learning_to_read_mode': learningToReadMode,
      'current_feeling': currentFeeling,
      'feelingTrigger': feelingTrigger,
      'bodySignal': bodySignal,
      'copingTool': copingTool,
      'repairGoal': repairGoal,
      'parentHiddenContext': parentHiddenContext,
      'character_evolution': characterEvolution,
      'additional_characters': additionalCharacters,
      'include_illustrations': includeIllustrations,
      'subscription_tier': subscriptionTier,
      'user_id': userId,
      'companion_pets': companionPets,
      'companion_characters': companionCharacters,
      'story_length': storyLength,
      'customElements': customElements,
      'bedtime_mode': bedtimeMode,
      'bedtime_mood': bedtimeMood,
    };
    if (userApiKey != null && userApiKey.isNotEmpty) {
      body['user_api_key'] = userApiKey;
    }

    try {
      // 1. Start the task
      final generateHeaders = await authHeaders();
      final generateResponse = await httpClient
          .post(
            generateUri,
            headers: generateHeaders,
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (generateResponse.statusCode == 200) {
        final payload =
            jsonDecode(generateResponse.body) as Map<String, dynamic>;
        final story = payload['story'] ?? payload['story_text'];
        if ((story is String && story.isNotEmpty) ||
            (story is Map && story.isNotEmpty)) {
          return StoryGenerationResult.fromBackend(payload);
        }
        throw HttpException(
          'Backend returned 200 without story content',
          uri: generateUri,
        );
      }

      if (generateResponse.statusCode != 202) {
        debugPrint(
          'Failed to start story generation. Status ${generateResponse.statusCode}, body: ${_truncateForLog(generateResponse.body)}',
        );
        throw HttpException(
          'Failed to start story generation task: ${generateResponse.statusCode}',
          uri: generateUri,
        );
      }

      final generateData =
          jsonDecode(generateResponse.body) as Map<String, dynamic>;
      final taskId = generateData['task_id'] as String;

      // 2. Poll for the result
      final statusUri = Uri.parse('$_localBackendUrl/task-status/$taskId');
      const pollInterval = Duration(seconds: 2);
      final stopwatch = Stopwatch()..start();

      while (stopwatch.elapsed < requestTimeout) {
        // Progress feedback
        if (onProgress != null) {
          final elapsedSec = stopwatch.elapsed.inSeconds;
          if (elapsedSec < 3) {
            onProgress('Gathering stardust...');
          } else if (elapsedSec < 8) {
            onProgress('Summoning characters...');
          } else if (elapsedSec < 15) {
            onProgress('Weaving magic words...');
          } else if (elapsedSec < 25) {
            onProgress('Adding sparkle...');
          } else {
            onProgress('Almost ready...');
          }
        }

        await Future.delayed(pollInterval);

        final statusResponse = await httpClient.get(statusUri);

        if (statusResponse.statusCode != 200) {
          // Continue polling on server error, but throw if it's a client error
          if (statusResponse.statusCode >= 400 &&
              statusResponse.statusCode < 500) {
            debugPrint(
              'Status check failed for task $taskId with ${statusResponse.statusCode}: ${_truncateForLog(statusResponse.body)}',
            );
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
          if (result is Map<String, dynamic>) {
            return StoryGenerationResult.fromBackend(result);
          }
          return StoryGenerationResult(
            storyText: result as String,
          );
        } else if (status == 'failure') {
          throw Exception(
              'Story generation task failed: ${statusData['result']}');
        }
        // If status is 'pending', continue polling
      }

      throw TimeoutException('Story generation polling timed out');
    } on TimeoutException catch (error) {
      debugPrint(
        'Story generation timed out after ${requestTimeout.inSeconds}s: $error',
      );
      throw TimeoutException(
        'Story generation took too long. Please try again.',
        requestTimeout,
      );
    } on SocketException catch (error) {
      debugPrint('Network error during story generation: $error');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Story generation failed unexpectedly: $error');
      try {
        if (!Platform.environment.containsKey('FLUTTER_TEST')) {
          if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      } catch (_) {}
      rethrow;
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
    String? feelingTrigger,
    String? bodySignal,
    String? copingTool,
    String? repairGoal,
    String? parentHiddenContext,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    Map<String, dynamic>? characterEvolution,
    String customElements = '',
  }) {
    final ageInstructions = StoryComplexityService.buildAgeInstructions(age);

    final bool useSecondPerson = age <= 5;
    final String perspectiveInstruction = useSecondPerson
        ? 'SECOND PERSON ("You"). Address the child directly as "You". Do NOT use the name "$characterName" to refer to the protagonist.'
        : 'THIRD PERSON ("$characterName").';

    // Extract emotion data first (needed for examples below)
    final emotionName = currentFeeling['emotion_name'] as String?;
    final emotionEmoji = currentFeeling['emotion_emoji'] as String?;
    final emotionDescription = currentFeeling['emotion_description'] as String?;
    final intensity = currentFeeling['intensity'] as int?;
    final whatHappened = ((currentFeeling['what_happened'] ??
            currentFeeling['trigger']) as String?) ??
        feelingTrigger;
    final physicalSigns =
        (currentFeeling['physical_signs'] as String?) ?? bodySignal;
    final copingStrategies =
        currentFeeling['coping_strategies'] as List<dynamic>?;
    final resolvedCopingStrategies = <String>[
      if (copingTool != null && copingTool.trim().isNotEmpty) copingTool.trim(),
      ...?copingStrategies
          ?.map((s) => s.toString())
          .where((s) => s.trim().isNotEmpty),
    ];
    final resolvedRepairGoal =
        (currentFeeling['repair_goal'] as String?) ?? repairGoal;

    final String directFeeling = emotionName?.toLowerCase() ?? 'big';
    final String startExample1 =
        whatHappened != null && whatHappened.trim().isNotEmpty
            ? (useSecondPerson
                ? '"You felt so $directFeeling when $whatHappened."'
                : '"$characterName felt so $directFeeling when $whatHappened."')
            : (useSecondPerson
                ? '"You felt so $directFeeling."'
                : '"$characterName felt so $directFeeling."');
    final String startExample2 = useSecondPerson
        ? '"Your body could feel it right away."'
        : '"$characterName could feel it in their body right away."';

    // Build FEELINGS-CENTERED opening (PRIORITY #1)
    String feelingsSection = '';

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

$characterName is feeling $intensityText$emotionEmoji $emotionName right now.
$emotionName means: $emotionDescription

${whatHappened != null ? "Context: $whatHappened\n" : ""}
Physical signs: $physicalSigns

CRITICAL THERAPEUTIC REQUIREMENTS:
1. START the story by acknowledging this feeling: $startExample1 or $startExample2
2. The story MUST help $characterName understand and work through this EXACT feeling
3. Show $characterName experiencing the physical sensations: $physicalSigns
4. Have $characterName use these coping strategies naturally in the story:
${resolvedCopingStrategies.map((s) => '   - $s').join('\n')}
5. By the end, $characterName should feel better about the $emotionName feeling - not making it disappear, but learning to work with it
6. Validate the emotion: "$emotionName is a normal, okay feeling to have"
7. Show that feelings come and go, and we can handle them
${resolvedRepairGoal != null && resolvedRepairGoal.trim().isNotEmpty ? "8. If the feeling causes a social bump, include this repair beat: $resolvedRepairGoal\n" : ""}${age <= 5 ? '9. For ages 5 and under, use very simple words like mad, sad, and scared. Keep the trigger child-sized and concrete.\n' : ''}

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
    String customRequestsText = '';
    if (customElements.isNotEmpty) {
      customRequestsText =
          '\n\nCUSTOM REQUESTS: $customElements (Use the exact words from this request at least once each, verbatim, in the story).';
    }

    if (characterEvolution != null) {
      final developmentStage =
          characterEvolution['development_stage'] as String?;
      final therapeuticProgress =
          characterEvolution['therapeutic_progress'] as Map<String, dynamic>?;
      final evolvedTraits =
          characterEvolution['evolved_traits'] as Map<String, dynamic>?;
      if (developmentStage != null) {
        evolutionContext +=
            '\n\nCHARACTER DEVELOPMENT STAGE: $characterName is at the "$developmentStage" stage of emotional development.';

        // Adapt story complexity based on development stage
        switch (developmentStage.toLowerCase()) {
          case 'novice':
          case 'beginner':
            evolutionContext +=
                '\nCreate a simpler story with basic emotional learning. Focus on naming feelings and simple coping strategies.';
            break;
          case 'intermediate':
            evolutionContext +=
                '\nCreate a moderately complex story. Include emotional regulation techniques and some problem-solving.';
            break;
          case 'advanced':
            evolutionContext +=
                '\nCreate a complex story with deeper emotional processing. Include perspective-taking and helping others.';
            break;
          case 'master':
            evolutionContext +=
                '\nCreate an advanced story focused on emotional leadership. Include teaching others and complex emotional situations.';
            break;
        }
      }

      if (therapeuticProgress != null && therapeuticProgress.isNotEmpty) {
        evolutionContext +=
            '\n\nTHERAPEUTIC STRENGTHS: $characterName has experience with: ${therapeuticProgress.keys.join(", ")}.';
        evolutionContext +=
            '\nBuild upon these existing therapeutic skills in the story.';
      }

      if (evolvedTraits != null) {
        final confidence = evolvedTraits['confidence'] as int?;
        final empathy = evolvedTraits['empathy'] as int?;
        final emotionalIntelligence =
            evolvedTraits['emotional_intelligence'] as int?;

        if (confidence != null && confidence > 50) {
          evolutionContext +=
              '\n\nCHARACTER TRAIT: $characterName has grown confident ($confidence%). Show them taking brave actions.';
        }
        if (empathy != null && empathy > 50) {
          evolutionContext +=
              '\n\nCHARACTER TRAIT: $characterName has developed empathy ($empathy%). Include opportunities to understand others\' feelings.';
        }
        if (emotionalIntelligence != null && emotionalIntelligence > 50) {
          evolutionContext +=
              '\n\nCHARACTER TRAIT: $characterName has strong emotional intelligence ($emotionalIntelligence%). Create nuanced emotional challenges.';
        }
      }
    }

    return '''
You are an experienced children's author running the Engaging Storycraft v9.0 engine for a feelings-first story.

REQUEST SUMMARY
- Child/Character: $characterName (age $age)
- Theme: $theme
- Perspective: $perspectiveInstruction
- Mode: Linear story, feelings-centered
- Length target: $lengthGuideline (Short default)
- Companion: ${companion ?? 'None'}
$companionText$multiCharacterText$feelingsSection$characterIntegration$evolutionContext$customRequestsText

STORY
STORY START
Write immersive, age-appropriate prose (no code fences) that leads with the current emotion, names body sensations, and sets a clear, kid-repeatable problem. Include at least two rising steps ("and then...") before resolving. Show coping skills in action.
STORY END

WISDOM GEM: A 5-10 word heart lesson in kid language.

ADVENTURE REPORT
- PLOT BEATS: 3-6 bullets summarizing arc
- CHARACTER SNAPSHOT: who they are + how they changed
- EMOTION NOTES: how feelings showed and shifted
- RE-READABILITY HOOKS: patterns, echoes, questions, Easter eggs

9-POINT STORYCRAFT CHECK (ensure output reflects):
1) Main character kids can mirror (want/quirk/feeling).
2) One-sentence kid-repeatable problem appears early.
3) At least two rising steps before resolution.
4) Embodied emotion (body cues).
5) Age-appropriate rhythm and repetition.
6) Small heart lesson, not preachy.
7) Playful delight: surprise + giggle + gentle wonder.
8) Ending echoes an opening image/line with inner shift.
9) Re-read hooks present.

$ageInstructions
SAFETY: Keep content gentle, avoid violence/scares; keep tone warm and supportive.
Maintain plain text (no markdown fences).''';
  }

  static const _bedtimeSettingDescriptions = <String, String>{
    'Rainbow World':
        'a shimmering realm where the sky holds soft arcs of rose and gold, gentle streams of liquid light wind between velvet hills, and cloud creatures drift on warm honeysuckle breezes',
    'Cave of Crystals':
        'a vast underground grotto lit by glowing crystals of rose, blue, and amber whose walls hum a low peaceful note — every echo returns as a soft musical chord',
    'Cave Full of Crystals':
        'a vast underground grotto lit by glowing crystals of rose, blue, and amber whose walls hum a low peaceful note — every echo returns as a soft musical chord',
    'Friendly Dragons':
        'a warm valley where gentle dragons curl in cosy nests, their slow steady breath filling the air with the scent of cinnamon and sending up wisps of soft golden smoke',
    'Making a New Friend':
        'a sun-warmed village at the edge of a silvery wood, where doorways glow with warm lamplight and the cobblestones stay warm even after sunset',
    'Big Feelings':
        'a quiet hilltop garden where the wind is always gentle and a great ancient tree spreads wide warm branches that seem to listen without saying a word',
    'Magical Forest':
        'a moonlit forest where silver-leafed trees hum a low steady song, fireflies trace slow spirals through the air, and the moss underfoot is deep and impossibly soft',
    'Enchanted Ocean':
        'a calm warm sea under a sky full of stars, where bioluminescent creatures drift like living lanterns and the waves make a slow rhythmic shushing sound',
    'Dreamy Clouds':
        'soft billowy cloudscapes high above the sleeping world, where cloud creatures make homes from moonlight and every step springs gently underfoot like the best pillow imaginable',
  };

  static String _buildBedtimePrompt({
    required String characterName,
    required String theme,
    required int age,
    String mood = 'calming',
    String? companion,
    List<String>? additionalCharacters,
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    String storyLength = 'standard',
  }) {
    // Word count targets for bedtime — shorter than adventure stories.
    final (int minWords, int maxWords) = switch (age) {
      <= 4  => storyLength == 'short' ? (180, 260)  : (260, 380),
      <= 7  => storyLength == 'short' ? (300, 420)  : (420, 580),
      <= 10 => storyLength == 'short' ? (480, 650)  : (650, 900),
      <= 13 => storyLength == 'short' ? (650, 850)  : (850, 1100),
      _     => storyLength == 'short' ? (750, 950)  : (950, 1250),
    };

    final worldDesc = _bedtimeSettingDescriptions[theme] ?? theme;

    // All heroes — protagonist + siblings/friends listening.
    final allHeroes = <String>[characterName, ...?additionalCharacters];
    final heroesStr = allHeroes.length == 1
        ? allHeroes.first
        : '${allHeroes.sublist(0, allHeroes.length - 1).join(', ')} and ${allHeroes.last}';

    // Companions (magical creatures / friends).
    final compParts = <String>[];
    for (final p in companionPets ?? []) {
      final name = p['name'] as String?;
      final species = p['species'] as String?;
      if (name != null) compParts.add(species != null ? '$name the $species' : name);
    }
    for (final c in companionCharacters ?? []) {
      final name = c is Map ? c['name'] as String? : c?.toString();
      if (name != null && name.isNotEmpty) compParts.add(name);
    }
    if (compParts.isEmpty && companion != null && companion.isNotEmpty) {
      compParts.add(companion);
    }
    final compStr = compParts.isEmpty ? 'None' : compParts.join(', ');

    final allMandatory = [...allHeroes, ...compParts];
    final mandatoryStr = allMandatory.join(', ');

    final moodHint = switch (mood.toLowerCase()) {
      'brave'      => 'gently brave — the challenge is real but never frightening, resolved with warmth and quiet confidence',
      'funny'      => 'softly funny — gentle wordplay and cosy silliness, nothing rowdy or over-stimulating',
      'friendship' => 'warm and connective — the bond between the heroes is the heart of every scene',
      _            => 'deeply peaceful and soothing — every sentence should slow the listener\'s breathing',
    };

    return '''You are a master bedtime storyteller. Create a magical, soothing bedtime story.

HEROES (ALL MUST APPEAR BY NAME): $heroesStr
Every hero listed above MUST have at least one warm, meaningful moment in the story. Use their names naturally and often.

MAGICAL COMPANIONS: $compStr
(Mandatory — every name here MUST appear: $mandatoryStr)

SETTING: $worldDesc

MOOD: $moodHint

AUDIENCE AGE: $age years old

WORD COUNT: $minWords–$maxWords words total.

━━━ BEDTIME STORY RULES (MANDATORY) ━━━

1. SOOTHING PACING — each scene lingers on soft textures, gentle sounds, and warmth. No rushed action.
2. ALL HEROES PRESENT — $mandatoryStr must all appear and do something meaningful.
3. COZY EMOTIONAL LANDING — ends with everyone safe, snug, drifting toward sleep. No cliffhangers.
4. AUDIO-FIRST PROSE — no bold text, no bullet points, no markdown. Rich sensory language beautiful when read aloud.
5. REDUCED STIMULATION — no chases, battles, or scary moments. Gentle challenges, gentle resolutions.
6. CALM MAGIC — things glow softly, float gently, hum quietly. Nothing explodes, races, or shocks.
7. SLEEP TRANSITION — weave in natural sleep cues: sky deepening to indigo, stars appearing, characters yawning and finding a perfect warm place to rest.
8. WISDOM GEM — end with one short warm phrase the child can carry into sleep.

OUTPUT FORMAT — return ONLY valid JSON, no prose outside it:
{
  "title": "Story Title",
  "wisdom_gem": "One short warm phrase for the child to carry into sleep.",
  "pages": [
    {"text": "First page prose..."},
    {"text": "Second page prose..."},
    ...
  ]
}

Each page should be 2–4 sentences. Do NOT include page numbers inside the text.
No extra keys. No prose outside the JSON.''';
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
    String customElements = '',
  }) {
    final ageInstructions = StoryComplexityService.buildAgeInstructions(age);
    String pageGuideline = '10-12 pages';
    String wordsPerPageGuideline = 'about 60-80 words per page';
    if (lengthGuideline.contains('300-400')) {
      pageGuideline = '6-7 pages';
      wordsPerPageGuideline = 'about 45-60 words per page';
    } else if (lengthGuideline.contains('1000-1200')) {
      pageGuideline = '12-14 pages';
      wordsPerPageGuideline = 'about 85-110 words per page';
    }

    final bool useSecondPerson = age <= 5;
    final String perspectiveInstruction = useSecondPerson
        ? 'SECOND PERSON ("You"). Address the child directly as "You". Do NOT use the name "$characterName" to refer to the protagonist.'
        : 'THIRD PERSON ("$characterName").';

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

    String customRequestsText = '';
    if (customElements.isNotEmpty) {
      customRequestsText =
          '\n\nCUSTOM REQUESTS: $customElements (Use the exact words from this request at least once each, verbatim, in the story).';
    }

    // Build character evolution context for adventure stories
    String evolutionContext = '';
    if (characterEvolution != null) {
      final developmentStage =
          characterEvolution['development_stage'] as String?;
      final therapeuticProgress =
          characterEvolution['therapeutic_progress'] as Map<String, dynamic>?;
      final evolvedTraits =
          characterEvolution['evolved_traits'] as Map<String, dynamic>?;

      if (developmentStage != null) {
        evolutionContext +=
            '\n\nCHARACTER DEVELOPMENT STAGE: $characterName is at the "$developmentStage" stage of emotional development.';

        // Adapt adventure complexity based on development stage
        switch (developmentStage.toLowerCase()) {
          case 'novice':
          case 'beginner':
            evolutionContext +=
                '\nCreate a simple adventure with clear emotional lessons. Focus on basic feelings and simple friendships.';
            break;
          case 'intermediate':
            evolutionContext +=
                '\nCreate a moderately challenging adventure. Include teamwork, emotional awareness, and helping others.';
            break;
          case 'advanced':
            evolutionContext +=
                '\nCreate a complex adventure with emotional depth. Include leadership, empathy, and complex social situations.';
            break;
          case 'master':
            evolutionContext +=
                '\nCreate an epic adventure focused on emotional wisdom. Include mentoring others and profound emotional insights.';
            break;
        }
      }

      if (therapeuticProgress != null && therapeuticProgress.isNotEmpty) {
        evolutionContext +=
            '\n\nTHERAPEUTIC STRENGTHS: $characterName has experience with: ${therapeuticProgress.keys.join(", ")}.';
        evolutionContext +=
            '\nIncorporate these therapeutic themes naturally into the adventure.';
      }

      if (evolvedTraits != null) {
        final confidence = evolvedTraits['confidence'] as int?;
        final empathy = evolvedTraits['empathy'] as int?;

        if (confidence != null && confidence > 50) {
          evolutionContext +=
              '\n\nCHARACTER TRAIT: $characterName has grown confident ($confidence%). Show them taking leadership in the adventure.';
        }
        if (empathy != null && empathy > 50) {
          evolutionContext +=
              '\n\nCHARACTER TRAIT: $characterName has developed empathy ($empathy%). Include moments where they understand and help others emotionally.';
        }
      }
    }

    return '''
You are a MASTER STORYTELLER for children. Create a magical, adventurous, and vivid story.

Child profile:
- Name: $characterName
- Age: $age
- Theme: $theme
- Perspective: $perspectiveInstruction
- Companion: ${companion ?? 'None'}
$companionText$multiCharacterText$characterIntegration$evolutionContext$customRequestsText

OUTPUT FORMAT:
You MUST return a STRICT JSON object. No prose outside the JSON. No markdown formatting.

JSON SCHEMA:
{
  "title": "A Catchy Adventure Title",
  "pages": [
    "Page 1 text...",
    "Page 2 text...",
    "..."
  ],
  "post_story": {
    "wisdom_gem": "A short, meaningful heart lesson",
    "adventure_report": {
      "plot_beats": ["string"],
      "character_snapshot": "string",
      "emotion_notes": ["string"],
      "rereadability_hooks": ["string"]
    }
  }
}

STORY REQUIREMENTS:
- TARGET LENGTH: $lengthGuideline total.
- PAGES: Split into $pageGuideline.
- PAGE DENSITY: Keep $wordsPerPageGuideline.
- TONE: For an 8-year-old, make it magical, adventurous, funny, and vivid.
- NO META: Do NOT include "PAGE X", "REQUEST SUMMARY", or any internal labels inside the page text.
- READABILITY: Use double newlines (\\n\\n) for paragraph breaks inside pages.
- SENSORY: Include rich sensory details.

$ageInstructions
SAFETY: Keep content gentle, avoid violence/scares; keep tone warm and supportive.
''';
  }

  static String _buildLearningToReadPrompt({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<String>? additionalCharacters,
    String customElements = '',
  }) {
    String detailSection = '';
    List<String>? extractStringList(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
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
      detailSection += '\nFRIENDS IN STORY: ${additionalCharacters.join(", ")}';
    }

    String companionText = '';
    if (companion != null && companion.isNotEmpty && companion != 'None') {
      companionText = '\nCOMPANION: Include $companion as a gentle helper.';
    }

    String customRequestsText = '';
    if (customElements.isNotEmpty) {
      customRequestsText = '\nCUSTOM REQUESTS: $customElements';
    }

    return '''
You are creating a LEARNING TO READ rhyming story for a $age-year-old named $characterName.

STRICT REQUIREMENTS (NO EXCEPTIONS):
1. TOTAL LENGTH: 50-100 words (stop inside this range).
2. RHYME PATTERN: Simple AABB scheme (line 1 rhymes with 2, line 3 rhymes with 4, etc.).
3. LINE LENGTH: 4-6 short words per line (keep it punchy).
4. VOCABULARY: Only CVC words (cat, dog, hop, sun) and common sight words (the, and, can, see, like, play). No tricky spellings, blends, or silent letters.
5. STRUCTURE: Repetition helps reading. Use predictable frames like "Can $characterName ___? Yes! $characterName can ___!".
6. TONE: Encouraging, musical, and confidence-building.
7. FORMAT: Each sentence or phrase on its own line for easy finger-tracking.

THEME: $theme$companionText$detailSection$customRequestsText

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
    String? feelingTrigger,
    String? bodySignal,
    String? copingTool,
    String? repairGoal,
    String? parentHiddenContext,
    Map<String, dynamic>? characterEvolution,
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    String storyLength = 'standard',
    String customElements = '',
  }) {
    // Map story length to word count targets (matching backend).
    String lengthGuideline;
    switch (storyLength) {
      case 'quick':
        lengthGuideline = '300-400 words';
        break;
      case 'epic':
        lengthGuideline = '1000-1200 words';
        break;
      case 'standard':
      default:
        lengthGuideline = '600-800 words';
        break;
    }

    // Merge companions for prompt building
    final effectiveAdditionalChars = additionalCharacters != null
        ? List<String>.from(additionalCharacters)
        : <String>[];

    if (companionCharacters != null) {
      for (final char in companionCharacters) {
        if (char is String) {
          effectiveAdditionalChars.add(char);
        } else if (char is Map) {
          final name = char['name'] ?? 'Friend';
          final desc = char['description'] ?? char['role'] ?? '';
          final power = char['signaturePower'];

          String entry = name;
          if (desc.isNotEmpty) entry += ' ($desc)';
          if (power != null) entry += ' [Magic: $power]';

          effectiveAdditionalChars.add(entry);
        }
      }
    }
    if (companionPets != null) {
      for (final p in companionPets) {
        effectiveAdditionalChars.add('${p['name']} (a ${p['species']})');
      }
    }

    if (learningToReadMode) {
      return _buildLearningToReadPrompt(
        characterName: characterName,
        theme: theme,
        age: age,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: effectiveAdditionalChars,
        customElements: customElements,
      );
    }

    if (currentFeeling != null) {
      return _buildTherapeuticPrompt(
        characterName: characterName,
        theme: theme,
        age: age,
        lengthGuideline: lengthGuideline,
        currentFeeling: currentFeeling,
        feelingTrigger: feelingTrigger,
        bodySignal: bodySignal,
        copingTool: copingTool,
        repairGoal: repairGoal,
        parentHiddenContext: parentHiddenContext,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: effectiveAdditionalChars,
        characterEvolution: characterEvolution,
        customElements: customElements,
      );
    } else {
      return _buildAdventurePrompt(
        characterName: characterName,
        theme: theme,
        age: age,
        lengthGuideline: lengthGuideline,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: effectiveAdditionalChars,
        characterEvolution: characterEvolution,
        customElements: customElements,
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
        '($parsedValue/100 toward ${towardLabel.toLowerCase()})',
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
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    final bool useSecondPerson = age <= 5;
    final String perspectiveInstruction = useSecondPerson
        ? 'SECOND PERSON ("You"). Address the child directly.'
        : 'THIRD PERSON ("$characterName").';

    final prompt = '''
You are an experienced children's author running the Engaging Storycraft v9.0 engine for an interactive story.

Child profile:
- Name: $characterName
- Age: $age
- Perspective: $perspectiveInstruction
- Theme: $theme
- Companion: ${companion != null && companion.isNotEmpty ? companion : 'None'}
- Mode: Interactive

OUTPUT: Return STRICT JSON with keys "text" and "choices" (and optional "can_conclude": false).
- "text": Narrative formatted with these labels (plain text, no code fences):
  REQUEST SUMMARY
  STORY START (2-3 lively paragraphs ending at a clear decision point)
  CHOICE 1:
    A) ... (seeking_support)
    B) ... (self_reliance)
    C) ... (teamwork)
  Keep story prose around 220-320 words. No markdown fences.
- "choices": Mirror the options above with ids and emotional_skill fields.

CHOICE RULES:
- Exactly 3 options mapping to seeking_support, self_reliance, and teamwork.
- Each option should feel different and drive the plot/emotions meaningfully.
- No color/door/left-right filler.

Ensure text is vivid, age-tuned, playful, with a strong hook/problem and embodied feelings. Do NOT wrap JSON in backticks.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text ?? '';

    // Extract JSON from response (robustly)
    final jsonText = cleanJsonForTesting(responseText);

    return jsonDecode(jsonText) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _generateInteractiveStoryWithBackend({
    required String characterName,
    required String theme,
    required int age,
    String? companion,
  }) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$_localBackendUrl/generate-interactive-story'),
      headers: headers,
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
      throw Exception(
          'Failed to generate interactive story: ${response.statusCode}');
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
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    final shouldEnd = choicesMade.length >= 3;

    final prompt = '''
You are continuing an interactive children's story using Engaging Storycraft v9.0.

STORY SO FAR:
$storySoFar

$characterName chose: "$choice"

${shouldEnd ? 'This should be the ENDING. Wrap up the story positively (200-280 words) and include STORY END, WISDOM GEM, and ADVENTURE REPORT in text.' : 'Write the next segment (200-280 words) and provide 2-3 new choices. Keep text labeled as below.'}

OUTPUT: Return STRICT JSON with keys "text", "choices", and "is_ending".
- "text": Plain prose with labels (no code fences):
  STORY CONTINUES (reflect last choice)
  If is_ending is true, append STORY END, WISDOM GEM (5-10 words), and ADVENTURE REPORT bullets (plot beats, character snapshot, emotion notes, re-readability hooks).
- "choices": 2-3 meaningful next options. If ending, include an "end_story" option and keep list short.
- "is_ending": ${shouldEnd ? 'true' : 'false'}

CHOICE RULES:
- Options must be specific actions tied to emotional skills; no color/door/left-right filler.
- Keep each option under 14 words.
Do NOT wrap JSON in backticks.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text ?? '';

    // Extract JSON from response (robustly)
    final jsonText = cleanJsonForTesting(responseText);

    return jsonDecode(jsonText) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _continueInteractiveStoryWithBackend({
    required String characterName,
    required String theme,
    required String choice,
    required String storySoFar,
    required List<String> choicesMade,
  }) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$_localBackendUrl/continue-interactive-story'),
      headers: headers,
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

  /// Tweak a curated gallery avatar by changing hair length or eye colour.
  ///
  /// Loads the Flutter asset at [assetPath], posts it multipart to the backend,
  /// and returns a `data:image/png;base64,...` string (or null on failure).
  static Future<String?> tweakGalleryAvatar({
    required String assetPath,
    String? hairLength,
    String? eyeColor,
  }) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final imageBytes = byteData.buffer.asUint8List();

      final uri = Uri.parse('$_localBackendUrl/avatars/tweak-gallery-avatar');
      final headers = await authHeaders();

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers)
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: assetPath.split('/').last,
        ));

      if (hairLength != null && hairLength.isNotEmpty) {
        request.fields['hair_length'] = hairLength;
      }
      if (eyeColor != null && eyeColor.isNotEmpty) {
        request.fields['eye_color'] = eyeColor;
      }

      final streamed =
          await request.send().timeout(const Duration(seconds: 120));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final b64 = data['tweaked_image_base64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          return 'data:image/png;base64,$b64';
        }
      }
      debugPrint('tweakGalleryAvatar failed: ${streamed.statusCode} $body');
      return null;
    } catch (e) {
      debugPrint('tweakGalleryAvatar error: $e');
      return null;
    }
  }

  // Helper for rigorous JSON extraction
  // Visible for testing
  static String cleanJsonForTesting(String text) {
    text = text.trim();

    // 1. Try to find JSON inside code blocks
    // Matches ```json {...} ``` or ``` {...} ```
    final codeBlockRegex =
        RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false);
    final codeBlockMatch = codeBlockRegex.firstMatch(text);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)!;
    }

    // 2. Try to find the first '{' and last '}' to extract the outermost JSON object
    // This handles cases where Gemini replies "Here is the JSON: {...}" without code blocks
    final int start = text.indexOf('{');
    final int end = text.lastIndexOf('}');

    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }

    // 3. Fallback: return original text if no structure found (will likely fail parse, but we tried)
    return text;
  }
}
