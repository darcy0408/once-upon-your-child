// lib/services/api_service_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/secure_storage_service.dart';

import '../config/environment.dart';

import '../models/antihero_crux_result.dart';
import '../models/api_error.dart';
import '../models/story_generation_result.dart';
import 'logger_service.dart';
import 'story_scaffold_fallback.dart';
import 'user_identity_service.dart';

/// Manages API calls to the Story Weaver backend.
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
  // GDPR Art. 8: coarse country (ISO alpha-2) from the backend's CF-IPCountry
  // read, used only to resolve the digital-consent age. Persisted so the
  // consent gate can read it synchronously without an extra round trip.
  static const String _countryKey = 'story_weaver_country';

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

  /// Returns true if [token] is a JWT whose `exp` claim is in the past.
  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return true;
    }
  }

  /// One-time migration: tokens used to live in plaintext SharedPreferences
  /// (CWE-922). If a value is still there but absent from secure storage, move
  /// it across and delete the plaintext copy so existing users are not logged
  /// out by the upgrade.
  static Future<String?> _migrateTokenToSecureStorage({
    required SharedPreferences prefs,
    required String prefsKey,
    required Future<String?> Function() secureRead,
    required Future<void> Function(String) secureWrite,
  }) async {
    final secure = await secureRead();
    if (secure != null && secure.isNotEmpty) {
      // Already migrated — make sure no stale plaintext copy lingers.
      if (prefs.getString(prefsKey) != null) {
        await prefs.remove(prefsKey);
      }
      return secure;
    }
    final legacy = prefs.getString(prefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await secureWrite(legacy);
      await prefs.remove(prefsKey);
      LoggerService.info('Migrated $prefsKey to secure storage');
      return legacy;
    }
    return null;
  }

  Future<void> _doEnsureAuthenticated() async {
    if (_authToken != null && !_isTokenExpired(_authToken!)) return;
    _authToken = null; // clear any expired in-memory token

    // Try to load from storage. The access + refresh tokens are credentials
    // and live in flutter_secure_storage; only the non-sensitive user id stays
    // in SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final stored = await _migrateTokenToSecureStorage(
      prefs: prefs,
      prefsKey: _tokenKey,
      secureRead: SecureStorageService.getUserToken,
      secureWrite: SecureStorageService.saveUserToken,
    );
    _refreshToken = await _migrateTokenToSecureStorage(
      prefs: prefs,
      prefsKey: _refreshTokenKey,
      secureRead: SecureStorageService.getRefreshToken,
      secureWrite: SecureStorageService.saveRefreshToken,
    );
    _userId = prefs.getString(_userIdKey);

    if (stored != null && !_isTokenExpired(stored)) {
      _authToken = stored;
      LoggerService.debug('Loaded auth token from secure storage');
      return;
    }
    // Stored token absent or expired — remove it and get a fresh one.
    await SecureStorageService.deleteUserToken();

    // Get new anonymous token
    LoggerService.debug('Getting anonymous auth token...');
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

        // Save credentials to secure storage; only the user id (non-sensitive)
        // stays in SharedPreferences.
        await SecureStorageService.saveUserToken(_authToken!);
        if (_refreshToken != null && _refreshToken!.isNotEmpty) {
          await SecureStorageService.saveRefreshToken(_refreshToken!);
        }
        await prefs.setString(_userIdKey, _userId!);
        // GDPR Art. 8: persist the coarse country the backend resolved from
        // CF-IPCountry so the consent gate can pick the right digital-consent
        // age. Absent in local/dev (no Cloudflare edge) — left unset then.
        final country = data['country'];
        if (country is String && country.isNotEmpty) {
          await prefs.setString(_countryKey, country);
        }
        LoggerService.debug(
            'Got anonymous auth token for user ${LoggerService.redact(_userId)}');
      } else {
        LoggerService.warning(
            'Failed to get anonymous token: HTTP ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.warning('Error getting anonymous token', e);
    }
  }

  Future<void> _clearAuthState() async {
    _authToken = null;
    _refreshToken = null;
    await SecureStorageService.deleteUserToken();
    await SecureStorageService.deleteRefreshToken();
    // Defensively clear any legacy plaintext copies that pre-date the
    // secure-storage migration.
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
      await SecureStorageService.saveUserToken(newToken);

      // Persist the rotated refresh token returned by the server.
      final newRefreshToken = data['refresh_token']?.toString();
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        _refreshToken = newRefreshToken;
        await SecureStorageService.saveRefreshToken(newRefreshToken);
      }
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

  /// The coarse country (ISO alpha-2) the backend resolved from CF-IPCountry on
  /// the last anonymous-auth call, or null if unknown (e.g. local/dev with no
  /// Cloudflare edge). Used only to resolve the GDPR Art. 8 digital-consent age.
  Future<String?> getCountry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_countryKey);
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
        LoggerService.debug('401 Unauthorized from $uri. Refreshing token...');
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
        LoggerService.debug('401 Unauthorized from $uri. Refreshing token...');
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
        LoggerService.debug('401 Unauthorized from $uri. Refreshing token...');
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
        LoggerService.debug('401 Unauthorized from $uri. Refreshing token...');
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
        LoggerService.debug('401 Unauthorized from $uri. Refreshing token...');
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

  /// MT-353 — content-report affordance required by app-store review and
  /// kidSAFE. POSTs to the existing `/report-story` endpoint
  /// (backend/routes/story_routes.py), which just logs the report for
  /// manual review and returns 200. Callers only care whether the call
  /// succeeded; this throws on failure, mirroring [post]'s error handling.
  Future<void> reportStory({
    required String storyId,
    required String reason,
    String? storyPreview,
    http.Client? client,
  }) async {
    await post(
      '/report-story',
      {
        'story_id': storyId,
        'reason': reason,
        if (storyPreview != null && storyPreview.isNotEmpty)
          'story_preview': storyPreview,
      },
      client: client,
    );
  }

  /// Allow tests to inject a mock HTTP client.
  static void setTestClient(http.Client? client) {
    _testClient = client;
  }

  /// Clears cached auth state so each test starts from a clean slate.
  ///
  /// The auth token is cached in a static field and survives between tests in
  /// the same suite run; without this reset a token loaded by an earlier test
  /// would leak into a later one. Tests that exercise auth-header behaviour
  /// should call this in `setUp`.
  @visibleForTesting
  static Future<void> resetAuthForTest() async {
    _authToken = null;
    _refreshToken = null;
    _userId = null;
    _authInFlight = null;
    await SecureStorageService.deleteUserToken();
    await SecureStorageService.deleteRefreshToken();
  }

  /// COSMETIC premium check — drives UI affordances ONLY (M-8, client half).
  ///
  /// `is_paid_premium` is a plain SharedPreferences bool and therefore
  /// editable on a rooted device or via a backup round-trip. It is NOT a
  /// security boundary: every premium-gated capability is enforced
  /// server-side off `User.subscription_tier`, so a tampered-up value buys
  /// a misleading UI and nothing more. `is_paid_premium` is kept in sync
  /// with the backend by `SubscriptionSyncService`, which overwrites it
  /// (including downgrades) on every sync — the local cache can never
  /// override the backend's entitlement.
  ///
  /// Do NOT use this result to authorize a paid action; rely on the backend
  /// to reject unentitled requests.
  static Future<bool> hasPremiumAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_paid_premium') ?? false;
  }

  /// PERF-04: best-effort cancellation of an in-flight story-generation task.
  /// Fire-and-forget — the backend sets a Redis flag the Celery worker checks
  /// between phases (before each (re)generation and before moderation). Errors
  /// are swallowed: a failed cancel just lets the generation finish (cost = one
  /// story), which is strictly better than blocking the UI on a cancel call.
  static Future<void> cancelTask(String taskId) async {
    if (taskId.isEmpty) return;
    try {
      final headers = await authHeaders();
      await http
          .post(
            Uri.parse('$_localBackendUrl/cancel-task/$taskId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('cancelTask($taskId) failed (best-effort): $e');
    }
  }

  /// MT-351: PATCHes `/api/user/<id>/age` so the server's `declared_age`
  /// (what `ENFORCE_RESOLVED_AGE` checks — see backend/middleware/auth.py)
  /// tracks the client's locally-declared age. Best-effort with a couple of
  /// quick retries: a failed sync is logged and swallowed, never thrown —
  /// syncing the age must not block a child's onboarding/story flow (mirrors
  /// SubscriptionSyncService's non-blocking sync pattern). Requires an
  /// authenticated [userId]; callers should skip invoking this if one isn't
  /// available yet.
  static Future<void> syncDeclaredAge(String userId, int age) async {
    if (userId.isEmpty) return;
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final mgr = ApiServiceManager();
        await mgr.patch('/api/user/$userId/age', {'age': age});
        return;
      } catch (e) {
        if (attempt >= maxAttempts) {
          debugPrint('syncDeclaredAge($userId, $age) failed (best-effort): $e');
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  /// Generate a story via the backend.
  static Future<StoryGenerationResult> generateStory({
    required String characterName,
    required String theme,
    required int age,
    String? characterId,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<dynamic>? additionalCharacters,
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
    // Backend SYNC_STORY_TIMEOUT_SECONDS allows generation up to 120s; a
    // Sprout story that hits a validation/word-cap regen can run close to
    // that. Keep the client timeout above the backend ceiling so a slow but
    // successful generation still lands instead of being abandoned.
    Duration requestTimeout = const Duration(seconds: 150),
    List<Map<String, dynamic>>? companionPets,
    List<dynamic>? companionCharacters,
    String storyLength = 'standard',
    String customElements = '',
    bool bedtimeMode = false,
    String bedtimeMood = 'calming',
    int? bedtimeDurationMinutes,
    void Function(String)? onProgress,
    // PERF-01 slice 4: optional consumer of accumulated streamed story
    // text from /task-status. Called whenever a poll returns `partial_text`;
    // each call is a fresh snapshot of the full accumulated story so far.
    // Existing callers that don't pass this are unaffected.
    void Function(String)? onPartial,
    // PERF-04: fired once with the backend Celery task id as soon as
    // /generate-story returns it, so the caller can later abandon the
    // generation via cancelTask(). No-op on the synchronous (200) path.
    void Function(String)? onTaskId,
    List<String>? progressPhases,
    // Age-appropriate story parameters
    String? therapeuticPrompt,
    String? conflictHook,
    String? sensoryPalette,
    String? worldBible,
    Map<String, dynamic>? moodPhysics,
    String? lifeChallenge,
    // Superhero Mode (ages 3-5). All four costume/power fields are required
    // when theme == 'superhero'; otherwise they are ignored.
    String? heroCostumeColor,
    String? heroCapeStyle,
    String? heroEmblem,
    String? heroPower,
    String? heroMode,
    String? heroCatchphrase,
    String? heroAlias,
    String? heroSecret,
    String? heroTell,
    String? heroLine,
    String? heroSeenBy,
    String? heroNemesisId,
    List<String>? recentVillains,
    List<String>? recentProblems,
    // MT-235 Phase 2 (the returnable saga): a returning Creator hero's
    // HeroSaga.toPriorSaga() continuity payload, attached as `prior_saga` on the
    // backend path. Null for Issue #1 / non-Creator stories.
    Map<String, dynamic>? priorSaga,
  }) async {
    final userId = await UserIdentityService.getOrCreateUserId();
    final String normalizedTier =
        (subscriptionTier.isEmpty ? 'free' : subscriptionTier).toLowerCase();
    final http.Client? effectiveClient = client ?? _testClient;

    // Pull the bits the offline scaffold fallback needs out of the
    // (potentially nested) characterDetails / currentFeeling maps, so we
    // can hand them to runWithScaffoldFallback. See
    // lib/services/story_scaffold_fallback.dart for the policy.
    final String? archetypeId = characterDetails?['archetype'] as String?;
    final String? genderField = characterDetails?['gender'] as String?;
    final String? feelingId = (currentFeeling?['emotion_name'] as String? ??
            currentFeeling?['feeling_id'] as String?)
        ?.toLowerCase();

    // Companion-aware request timeout. Companions enlarge the prompt and add
    // mandatory validation names on the backend, which routinely forces an
    // extra full-story regeneration — and the backend correspondingly grants
    // itself extra sync head-room per companion (see _sync_timeout_for in
    // backend/routes/story_routes.py). The client must wait at least as long,
    // or the POST aborts first and we needlessly fall back to a canned
    // scaffold story. We only ever EXTEND the timeout (never shrink an
    // explicit caller override) and cap the extension so it stays bounded.
    final int companionCount =
        (companionPets?.length ?? 0) + (companionCharacters?.length ?? 0);
    final Duration effectiveRequestTimeout = companionCount <= 0
        ? requestTimeout
        : Duration(
            seconds:
                requestTimeout.inSeconds + (companionCount * 30).clamp(0, 120),
          );

    return await runWithScaffoldFallback(
      scenarioId: theme,
      age: age,
      name: characterName,
      companion: companion ?? '',
      gender: genderField,
      archetypeId: archetypeId,
      currentFeelingId: feelingId,
      bedtime: bedtimeMode,
      attempt: () => _generateStoryWithBackendRetry(
        characterName: characterName,
        theme: theme,
        age: age,
        characterId: characterId,
        childProfileId: childProfileId,
        companion: companion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacters,
        rhymeTimeMode: rhymeTimeMode,
        learningToReadMode: learningToReadMode,
        includeIllustrations: includeIllustrations,
        subscriptionTier: normalizedTier,
        userId: userId,
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
        requestTimeout: effectiveRequestTimeout,
        companionPets: companionPets,
        companionCharacters: companionCharacters,
        storyLength: storyLength,
        customElements: customElements,
        bedtimeMode: bedtimeMode,
        bedtimeMood: bedtimeMood,
        bedtimeDurationMinutes: bedtimeDurationMinutes,
        onProgress: onProgress,
        onPartial: onPartial,
        onTaskId: onTaskId,
        progressPhases: progressPhases,
        therapeuticPrompt: therapeuticPrompt,
        conflictHook: conflictHook,
        sensoryPalette: sensoryPalette,
        worldBible: worldBible,
        moodPhysics: moodPhysics,
        lifeChallenge: lifeChallenge,
        heroCostumeColor: heroCostumeColor,
        heroCapeStyle: heroCapeStyle,
        heroEmblem: heroEmblem,
        heroPower: heroPower,
        heroMode: heroMode,
        heroCatchphrase: heroCatchphrase,
        heroAlias: heroAlias,
        heroSecret: heroSecret,
        heroTell: heroTell,
        heroLine: heroLine,
        heroSeenBy: heroSeenBy,
        heroNemesisId: heroNemesisId,
        recentVillains: recentVillains,
        recentProblems: recentProblems,
        priorSaga: priorSaga,
      ),
    );
  }

  /// MT-258 — Part 1 of the Adolescent (15-17) interactive Crux Choice flow.
  ///
  /// POSTs `/generate-antihero-crux`, which generates Beats 1-4 + the two-sided
  /// choice and caches its continuation context on the backend. Returns the
  /// setup beats + the pending choice; the reader screen renders them, then
  /// calls [generateAntiheroResolution] with the chosen [CruxChoice.id].
  ///
  /// This path is single-shot (no scaffold fallback / no 202 poll): the crux
  /// endpoint always answers synchronously. On a non-200 it throws [ApiError]
  /// (parental-consent / quota, mirroring the /generate-story error shape) or
  /// [HttpException], so callers can reuse their existing catch handling.
  static Future<AntiheroCruxResult> generateAntiheroCrux({
    required String characterName,
    required int age,
    String? characterId,
    String subscriptionTier = 'free',
    String? heroPower,
    String? heroCostumeColor,
    String? heroEmblem,
    String? heroCatchphrase,
    String? heroSecret,
    String? heroTell,
    String? heroLine,
    String? heroSeenBy,
    String customElements = '',
    Map<String, dynamic>? priorSaga,
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 150),
  }) async {
    final userId = await UserIdentityService.getOrCreateUserId();
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl/generate-antihero-crux');

    final body = <String, dynamic>{
      'character': characterName.isNotEmpty ? characterName : 'Hero',
      'theme': 'superhero',
      'hero_mode': 'antihero',
      'age': age,
      'character_age': age,
      'user_id': userId,
      'subscription_tier':
          subscriptionTier.isEmpty ? 'free' : subscriptionTier.toLowerCase(),
      if (characterId != null && characterId.isNotEmpty)
        'character_id': characterId,
      if (heroPower != null && heroPower.trim().isNotEmpty)
        'hero_power': heroPower.trim(),
      if (heroCostumeColor != null && heroCostumeColor.trim().isNotEmpty)
        'hero_costume_color': heroCostumeColor.trim(),
      if (heroEmblem != null && heroEmblem.trim().isNotEmpty)
        'hero_emblem': heroEmblem.trim(),
      if (heroCatchphrase != null && heroCatchphrase.trim().isNotEmpty)
        'hero_catchphrase': heroCatchphrase.trim(),
      if (heroSecret != null && heroSecret.trim().isNotEmpty)
        'hero_secret': heroSecret.trim(),
      if (heroTell != null && heroTell.trim().isNotEmpty)
        'hero_tell': heroTell.trim(),
      if (heroLine != null && heroLine.trim().isNotEmpty)
        'hero_line': heroLine.trim(),
      if (heroSeenBy != null && heroSeenBy.trim().isNotEmpty)
        'hero_seen_by': heroSeenBy.trim(),
      if (customElements.trim().isNotEmpty)
        'customElements': customElements.trim(),
      if (priorSaga != null && priorSaga.isNotEmpty) 'prior_saga': priorSaga,
    };

    final headers = await authHeaders();
    final response = await httpClient
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(requestTimeout);

    final payload = _decodeAntiheroResponse(response, uri);
    final result = AntiheroCruxResult.fromBackend(payload);
    if (!result.isValid) {
      throw HttpException(
        'Antihero crux response missing token/pages/choices',
        uri: uri,
      );
    }
    return result;
  }

  /// MT-258 — Part 2 of the Crux Choice flow.
  ///
  /// POSTs `/generate-antihero-resolution` with the opaque [continuationToken]
  /// from part 1 and the reader's [choiceId]. The backend writes Beats 5-7
  /// conditioned on that choice, assembles the full 7-beat story (with
  /// `superhero_meta.saga_state`), persists it, and returns the same envelope
  /// shape as `/generate-story` — so it parses through
  /// [StoryGenerationResult.fromBackend] unchanged. A 410 (expired token) or
  /// 400 (bad choice) surfaces as [ApiError]/[HttpException].
  static Future<StoryGenerationResult> generateAntiheroResolution({
    required String continuationToken,
    required String choiceId,
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 150),
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final uri = Uri.parse('$_localBackendUrl/generate-antihero-resolution');
    final body = <String, dynamic>{
      'continuation_token': continuationToken,
      'choice_id': choiceId,
    };

    final headers = await authHeaders();
    final response = await httpClient
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(requestTimeout);

    final payload = _decodeAntiheroResponse(response, uri);
    final story = payload['story'] ?? payload['story_text'];
    if ((story is String && story.isNotEmpty) ||
        (story is Map && story.isNotEmpty)) {
      return StoryGenerationResult.fromBackend(payload);
    }
    throw HttpException(
      'Antihero resolution returned 200 without story content',
      uri: uri,
    );
  }

  /// Decode a crux/resolution response, raising [ApiError] for a structured
  /// backend error (so parental-consent / quota flow through the existing
  /// handlers) and [HttpException] otherwise. Mirrors [_decodeJsonResponse]
  /// but is static (the crux entry points are static like [generateStory]).
  static Map<String, dynamic> _decodeAntiheroResponse(
    http.Response response,
    Uri uri,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.body.isNotEmpty) {
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map<String, dynamic> &&
              (errorJson.containsKey('error_code') ||
                  errorJson.containsKey('error') ||
                  errorJson.containsKey('message'))) {
            throw ApiError.fromJson(errorJson,
                statusCode: response.statusCode);
          }
        } catch (e) {
          if (e is ApiError) rethrow;
          // Fall through to a generic HTTP error if the body isn't JSON.
        }
      }
      throw HttpException(
        'Request to ${uri.path} failed with status ${response.statusCode}',
        uri: uri,
      );
    }
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
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
            throw ApiError.fromJson(errorJson,
                statusCode: response.statusCode);
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

  static Future<StoryGenerationResult> _generateStoryWithBackendRetry({
    required String characterName,
    required String theme,
    required int age,
    String? characterId,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<dynamic>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    bool includeIllustrations = false,
    required String subscriptionTier,
    required String userId,
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
    int? bedtimeDurationMinutes,
    void Function(String)? onProgress,
    // PERF-01 slice 4: optional consumer of accumulated streamed story
    // text from /task-status. Called whenever a poll returns `partial_text`;
    // each call is a fresh snapshot of the full accumulated story so far.
    // Existing callers that don't pass this are unaffected.
    void Function(String)? onPartial,
    // PERF-04: fired once with the backend Celery task id as soon as
    // /generate-story returns it, so the caller can later abandon the
    // generation via cancelTask(). No-op on the synchronous (200) path.
    void Function(String)? onTaskId,
    List<String>? progressPhases,
    String? therapeuticPrompt,
    String? conflictHook,
    String? sensoryPalette,
    String? worldBible,
    Map<String, dynamic>? moodPhysics,
    String? lifeChallenge,
    String? heroCostumeColor,
    String? heroCapeStyle,
    String? heroEmblem,
    String? heroPower,
    String? heroMode,
    String? heroCatchphrase,
    String? heroAlias,
    String? heroSecret,
    String? heroTell,
    String? heroLine,
    String? heroSeenBy,
    String? heroNemesisId,
    List<String>? recentVillains,
    List<String>? recentProblems,
    Map<String, dynamic>? priorSaga,
  }) async {
    var attempts = 0;
    var delay = initialDelay;

    // MT-408 (client half): the task id of the generation currently in flight,
    // captured as soon as /generate-story hands it over. When an attempt gives
    // up waiting, the NEXT attempt resumes polling this id instead of starting
    // a fresh generation.
    //
    // This is the whole point of the fix. Before it, a story that outran the
    // client's 150-270s ceiling cost the user THREE paid generations (one per
    // attempt) and then served a canned scaffold story — while the story they
    // actually paid for sat finished and unreachable in the database.
    String? inFlightTaskId;
    // Each task id may be resumed AT MOST ONCE. Resuming without limit looks
    // tidier but is a regression: a task that is genuinely lost keeps
    // answering `pending`, so every attempt would re-poll the same dead id and
    // the user would end up with no story at all — whereas the old re-generate
    // behaviour at least gave them a second chance at one. One resume claims
    // the finished-late story (the common case); after that we fall back to
    // generating, so the safety net survives.
    final resumedTaskIds = <String>{};
    var resumeNext = false;

    while (attempts < maxAttempts) {
      final candidateId = inFlightTaskId;
      final resumeTaskId = (resumeNext &&
              candidateId != null &&
              !resumedTaskIds.contains(candidateId))
          ? candidateId
          : null;
      if (resumeTaskId != null) resumedTaskIds.add(resumeTaskId);
      try {
        return await _generateStoryWithBackend(
          resumeTaskId: resumeTaskId,
          characterName: characterName,
          theme: theme,
          age: age,
          characterId: characterId,
          childProfileId: childProfileId,
          companion: companion,
          characterDetails: characterDetails,
          additionalCharacters: additionalCharacters,
          rhymeTimeMode: rhymeTimeMode,
          learningToReadMode: learningToReadMode,
          includeIllustrations: includeIllustrations,
          subscriptionTier: subscriptionTier,
          userId: userId,
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
          bedtimeDurationMinutes: bedtimeDurationMinutes,
          onProgress: onProgress,
          onPartial: onPartial,
          // MT-408: remember the id ourselves as well as handing it to the
          // caller, so a timed-out attempt can be resumed rather than re-run.
          onTaskId: (id) {
            inFlightTaskId = id;
            onTaskId?.call(id);
          },
          progressPhases: progressPhases,
          therapeuticPrompt: therapeuticPrompt,
          conflictHook: conflictHook,
          sensoryPalette: sensoryPalette,
          worldBible: worldBible,
          moodPhysics: moodPhysics,
          lifeChallenge: lifeChallenge,
          heroCostumeColor: heroCostumeColor,
          heroCapeStyle: heroCapeStyle,
          heroEmblem: heroEmblem,
          heroPower: heroPower,
          heroMode: heroMode,
          heroCatchphrase: heroCatchphrase,
          heroAlias: heroAlias,
          heroSecret: heroSecret,
          heroTell: heroTell,
          heroLine: heroLine,
          heroSeenBy: heroSeenBy,
          heroNemesisId: heroNemesisId,
          recentVillains: recentVillains,
          recentProblems: recentProblems,
          priorSaga: priorSaga,
        );
      } on StoryGenerationCancelled {
        // PERF-01 cancellation polish: a user-initiated cancel is terminal —
        // never retry it (that would re-launch a task the user abandoned).
        // Propagate the signal straight to the caller for silent handling.
        rethrow;
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

        // MT-408: decide whether the next attempt resumes or starts fresh.
        //
        // Resume only on a TIMEOUT, and only when a task actually started. A
        // timeout is precisely the case where the work is probably still
        // running (or has already finished) server-side, so re-POSTing would
        // pay for it twice. Every other failure — 4xx, malformed body, socket
        // error — says something is wrong with the request or the task itself,
        // and retrying that same id would just fail the same way.
        if (error is TimeoutException && inFlightTaskId != null) {
          resumeNext = true;
        } else {
          // A resume that failed for any non-timeout reason means the id is no
          // longer usable (expired result, unknown owner → 404). Drop it so the
          // next attempt generates normally instead of re-polling a dead task.
          if (resumeTaskId != null) inFlightTaskId = null;
          resumeNext = false;
        }

        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw Exception('Story generation retry handler exhausted unexpectedly');
  }

  /// POST /generate-story and classify what came back.
  ///
  /// The endpoint answers one of two ways and both are normal:
  ///   * **200** — the story itself, generated synchronously. No task exists,
  ///     so there is nothing to poll and nothing to resume.
  ///   * **202** — a Celery `task_id` to poll via /task-status.
  ///
  /// Split out of [_generateStoryWithBackend] for MT-408 so the polling loop
  /// can be entered without starting a new generation.
  static Future<({StoryGenerationResult? result, String? taskId})>
      _startStoryTask({
    required http.Client httpClient,
    required Uri generateUri,
    required Map<String, dynamic> body,
    required Duration requestTimeout,
  }) async {
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
        return (
          result: StoryGenerationResult.fromBackend(payload),
          taskId: null,
        );
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
    return (
      result: null,
      taskId: generateData['task_id'] as String,
    );
  }

  /// Generate story using local backend
  static Future<StoryGenerationResult> _generateStoryWithBackend({
    required String characterName,
    required String theme,
    required int age,
    String? characterId,
    String? childProfileId,
    String? companion,
    Map<String, dynamic>? characterDetails,
    List<dynamic>? additionalCharacters,
    bool rhymeTimeMode = false,
    bool learningToReadMode = false,
    bool includeIllustrations = false,
    required String subscriptionTier,
    required String userId,
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
    int? bedtimeDurationMinutes,
    void Function(String)? onProgress,
    // PERF-01 slice 4: optional consumer of accumulated streamed story
    // text from /task-status. Called whenever a poll returns `partial_text`;
    // each call is a fresh snapshot of the full accumulated story so far.
    // Existing callers that don't pass this are unaffected.
    void Function(String)? onPartial,
    // PERF-04: fired once with the backend Celery task id as soon as
    // /generate-story returns it, so the caller can later abandon the
    // generation via cancelTask(). No-op on the synchronous (200) path.
    void Function(String)? onTaskId,
    List<String>? progressPhases,
    String? therapeuticPrompt,
    String? conflictHook,
    String? sensoryPalette,
    String? worldBible,
    Map<String, dynamic>? moodPhysics,
    String? lifeChallenge,
    String? heroCostumeColor,
    String? heroCapeStyle,
    String? heroEmblem,
    String? heroPower,
    String? heroMode,
    String? heroCatchphrase,
    String? heroAlias,
    String? heroSecret,
    String? heroTell,
    String? heroLine,
    String? heroSeenBy,
    String? heroNemesisId,
    List<String>? recentVillains,
    List<String>? recentProblems,
    // MT-235 Phase 2 (the returnable saga): a returning Creator hero's
    // persisted continuity, HeroSaga.toPriorSaga(). Sent as `prior_saga` so the
    // T9 Creator prompt can weave a "Previously…" block. Null on Issue #1 / non-
    // Creator stories — the backend treats a missing block as a clean origin.
    Map<String, dynamic>? priorSaga,
    // MT-408 (client half): resume polling an EXISTING task instead of starting
    // a new one. When set, /generate-story is not called at all — we go straight
    // to /task-status for this id. The retry wrapper passes the previous
    // attempt's task id here after a polling timeout, so a generation that
    // outlives the client's ceiling is claimed rather than paid for twice.
    String? resumeTaskId,
  }) async {
    final httpClient = client ?? _testClient ?? http.Client();
    final generateUri = Uri.parse('$_localBackendUrl/generate-story');

    final body = {
      'character': characterName.isNotEmpty ? characterName : 'Hero',
      'theme': theme,
      if (characterId != null && characterId.isNotEmpty)
        'character_id': characterId,
      'child_profile_id': childProfileId,
      'companion': companion,
      'age': age,
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
      'bedtime_duration_minutes': bedtimeDurationMinutes,
      if (therapeuticPrompt != null && therapeuticPrompt.isNotEmpty)
        'therapeutic_prompt': therapeuticPrompt,
      if (conflictHook != null && conflictHook.isNotEmpty)
        'conflictHook': conflictHook,
      if (sensoryPalette != null && sensoryPalette.isNotEmpty)
        'sensoryPalette': sensoryPalette,
      if (worldBible != null && worldBible.isNotEmpty) 'worldBible': worldBible,
      if (moodPhysics != null) 'moodPhysics': moodPhysics,
      if (lifeChallenge != null && lifeChallenge.isNotEmpty)
        'lifeChallenge': lifeChallenge,
    };

    // Superhero Mode — only attach the costume/power + no-repeat hints when
    // the wizard selected that scenario. Backend route is gated on theme.
    if (theme == 'superhero') {
      if (heroCostumeColor != null) {
        body['hero_costume_color'] = heroCostumeColor;
      }
      if (heroCapeStyle != null) body['hero_cape_style'] = heroCapeStyle;
      if (heroEmblem != null) body['hero_emblem'] = heroEmblem;
      if (heroPower != null) body['hero_power'] = heroPower;
      // Chunk 2 (MT-303): the up-front vibe — 'classic' (fun-heroic) vs
      // 'antihero' (noir double-life). The backend prompt branches tone on it; a
      // null/absent value is treated as antihero downstream, so today's behavior
      // is unchanged for stories that don't send it.
      if (heroMode != null && heroMode.trim().isNotEmpty) {
        body['hero_mode'] = heroMode.trim();
      }
      if (heroCatchphrase != null && heroCatchphrase.trim().isNotEmpty) {
        body['hero_catchphrase'] = heroCatchphrase.trim();
      }
      // MT-305: the Creator child's chosen hero codename, sent as a dedicated
      // field so the backend prompt uses it as the hero alias instead of
      // hardcoding the power name. Mirrors hero_catchphrase on the wire.
      if (heroAlias != null && heroAlias.trim().isNotEmpty) {
        body['hero_alias'] = heroAlias.trim();
      }
      if (heroSecret != null && heroSecret.trim().isNotEmpty) {
        body['hero_secret'] = heroSecret.trim();
      }
      if (heroTell != null && heroTell.trim().isNotEmpty) {
        body['hero_tell'] = heroTell.trim();
      }
      if (heroLine != null && heroLine.trim().isNotEmpty) {
        body['hero_line'] = heroLine.trim();
      }
      if (heroSeenBy != null && heroSeenBy.trim().isNotEmpty) {
        body['hero_seen_by'] = heroSeenBy.trim();
      }
      if (heroNemesisId != null && heroNemesisId.trim().isNotEmpty) {
        body['hero_nemesis_id'] = heroNemesisId.trim();
      }
      if (recentVillains != null && recentVillains.isNotEmpty) {
        body['recent_villains'] = recentVillains;
      }
      if (recentProblems != null && recentProblems.isNotEmpty) {
        body['recent_problems'] = recentProblems;
      }
      // MT-235 Phase 2: a returning Creator hero's saga continuity. The backend
      // reads kwargs['prior_saga'] and weaves a "Previously…" block for the
      // T9 Creator tier; absent on Issue #1 / younger bands → a clean origin.
      if (priorSaga != null && priorSaga.isNotEmpty) {
        body['prior_saga'] = priorSaga;
      }
    }

    try {
      // 1. Start the task — unless we are resuming one that is already running.
      // MT-408: on a resume we deliberately skip /generate-story entirely. The
      // prior attempt's task may well have finished during the gap; re-POSTing
      // would bill a second generation and orphan the first.
      final String taskId;
      if (resumeTaskId != null && resumeTaskId.isNotEmpty) {
        taskId = resumeTaskId;
        debugPrint('Resuming poll for existing story task $taskId (MT-408).');
      } else {
        final started = await _startStoryTask(
          httpClient: httpClient,
          generateUri: generateUri,
          body: body,
          requestTimeout: requestTimeout,
        );
        // Synchronous path: the backend answered 200 with the whole story and
        // no task was ever created, so there is nothing to poll.
        final syncResult = started.result;
        if (syncResult != null) return syncResult;
        taskId = started.taskId!;
      }
      // PERF-04: hand the task id to the caller so a user who abandons the
      // wait can cancel the in-flight generation via cancelTask(taskId).
      onTaskId?.call(taskId);

      // 2. Poll for the result
      final statusUri = Uri.parse('$_localBackendUrl/task-status/$taskId');
      const pollInterval = Duration(seconds: 2);
      final stopwatch = Stopwatch()..start();

      while (stopwatch.elapsed < requestTimeout) {
        // Progress feedback
        if (onProgress != null) {
          final elapsedSec = stopwatch.elapsed.inSeconds;
          final phases = progressPhases ??
              const [
                'Gathering stardust...',
                'Summoning characters...',
                'Weaving magic words...',
                'Adding sparkle...',
                'Almost ready...',
              ];
          if (elapsedSec < 3) {
            onProgress(phases[0]);
          } else if (elapsedSec < 8) {
            onProgress(phases[1]);
          } else if (elapsedSec < 15) {
            onProgress(phases[2]);
          } else if (elapsedSec < 25) {
            onProgress(phases[3]);
          } else {
            onProgress(phases[4]);
          }
        }

        await Future.delayed(pollInterval);

        // Bound each individual status poll: every other http call in this
        // file passes .timeout(...), but this one did not — a silent server
        // could stall the await forever, so the outer
        // `while (stopwatch.elapsed < requestTimeout)` guard never re-checked.
        // Treat a single-poll timeout as a retryable hiccup and keep looping;
        // the outer elapsed-time guard still fires the real
        // TimeoutException('Story generation polling timed out') below.
        final http.Response statusResponse;
        try {
          // /task-status requires the same JWT as /generate-story (the authz
          // hardening sweep gated it); polling without headers 401s forever,
          // so the async 202 path could never complete on prod (2026-07-15
          // walkthrough: adult Medium story spun until timeout while the
          // client re-submitted duplicate generations).
          statusResponse = await httpClient
              .get(statusUri, headers: await authHeaders())
              .timeout(
                pollInterval * 2,
              );
        } on TimeoutException {
          debugPrint('Status poll for task $taskId timed out — retrying.');
          continue;
        }

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

        // PERF-01 slice 4: surface accumulated streamed text to the optional
        // onPartial callback. Each emit is a fresh snapshot of the full
        // story so far (not a delta), so the consumer can just replace its
        // displayed text. No-op when the caller didn't supply a consumer or
        // when the backend isn't streaming this generation.
        final partialText = statusData['partial_text'];
        if (onPartial != null &&
            partialText is String &&
            partialText.isNotEmpty) {
          onPartial(partialText);
        }

        if (status == 'complete') {
          final result = statusData['result'];
          // PERF-01 cancellation polish: a user-initiated cancel surfaces as a
          // *completed* task whose inner result is `{"status": "cancelled"}`
          // with no story body. Detect it and throw a dedicated signal so we
          // stop polling immediately instead of treating the empty result as a
          // story (or polling on to a TimeoutException → error card). Callers
          // catch StoryGenerationCancelled and treat it as a silent no-op.
          if (result is Map<String, dynamic> &&
              result['status'] == 'cancelled') {
            throw const StoryGenerationCancelled();
          }
          if (result is Map<String, dynamic>) {
            final parsed = StoryGenerationResult.fromBackend(result);
            // Mirror the sync path's guard (~line 1413): a completed task whose
            // story body is empty/whitespace must not render as a blank story.
            // Throw so the scaffold-fallback/error path engages instead.
            if (parsed.storyText.trim().isEmpty) {
              throw HttpException(
                'Backend returned 200 without story content',
                uri: statusUri,
              );
            }
            return parsed;
          }
          final storyText = result as String;
          if (storyText.trim().isEmpty) {
            throw HttpException(
              'Backend returned 200 without story content',
              uri: statusUri,
            );
          }
          return StoryGenerationResult(
            storyText: storyText,
          );
        } else if (status == 'cancelled') {
          // Defensive: if a future backend surfaces cancellation directly on the
          // envelope status (rather than nested in result), honor it the same way.
          throw const StoryGenerationCancelled();
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

      final uri = Uri.parse('$_localBackendUrl/avatar/tweak-gallery-avatar');
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
