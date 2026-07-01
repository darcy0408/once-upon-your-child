import 'package:shared_preferences/shared_preferences.dart';

import 'api_service_manager.dart';

class ParentalConsentService {
  const ParentalConsentService();

  static const _keyAge = 'user_age';
  static const _keyConsent = 'parental_consent_granted';
  static const _keyParentEmail = 'parent_email';
  static const _keyConsentMethod = 'parental_consent_method';
  static const _keyConsentVerified = 'parental_consent_verified';
  static const _keyRecordedAt = 'parental_consent_recorded_at';
  static const _keyAllowPhotoAvatar = 'allow_photo_avatar';
  static const _keyDailyLimitMinutes = 'screen_time_daily_limit';
  static const _keyBedtimeLockoutHour = 'screen_time_bedtime_hour';
  static const _keyBedtimeLockoutMinute = 'screen_time_bedtime_minute';
  static const _keyBedtimeLockoutEnabled = 'screen_time_bedtime_enabled';
  static const _keyBigFeelingsParentHiddenContext =
      'big_feelings_parent_hidden_context';
  static const _keyBigFeelingsRepairGoal = 'big_feelings_repair_goal';

  Future<bool> getAllowPhotoAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllowPhotoAvatar) ?? false;
  }

  Future<void> setAllowPhotoAvatar(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowPhotoAvatar, allow);
  }

  /// Validates an email address well enough for a COPPA verifiable-consent
  /// round trip. This is a syntactic check only — the *real* verification is
  /// the email round trip itself (the parent must receive and act on the code).
  ///
  /// Returns true only for a non-empty, single-`@`, dotted-domain address.
  static bool isValidEmail(String? email) {
    if (email == null) return false;
    final trimmed = email.trim();
    if (trimmed.isEmpty || trimmed.length > 254) return false;
    // local-part@domain with at least one dot in the domain and no whitespace.
    final re = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    return re.hasMatch(trimmed);
  }

  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsent) ?? false;
  }

  /// Returns the recorded consent method (e.g. 'parent', 'self_attested',
  /// 'email_verified', 'email_pending') or null if no consent recorded.
  Future<String?> getConsentMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyConsentMethod);
  }

  /// True only when a COPPA-verifiable consent round trip actually completed.
  /// For under-13 users this MUST be true before the child gets full access.
  Future<bool> isConsentVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsentVerified) ?? false;
  }

  /// Returns true if consent exists but was recorded before [cutoff].
  /// Used to prompt parents to re-consent after a privacy policy update.
  Future<bool> needsReConsent({required DateTime cutoff}) async {
    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getBool(_keyConsent) ?? false;
    if (!granted) return false; // no prior consent — normal onboarding handles it
    final raw = prefs.getString(_keyRecordedAt);
    if (raw == null) return true; // consent exists but no timestamp — re-prompt
    final recorded = DateTime.tryParse(raw);
    if (recorded == null) return true;
    return recorded.isBefore(cutoff);
  }

  /// Clears the consent record so the user is prompted again.
  Future<void> clearConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyConsent);
    await prefs.remove(_keyConsentMethod);
    await prefs.remove(_keyConsentVerified);
    await prefs.remove(_keyRecordedAt);
  }

  Future<int?> getRecordedAge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAge);
  }

  Future<void> saveDeclaredAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
  }

  /// Records a consent decision locally and (best-effort) on the backend.
  ///
  /// IMPORTANT (COPPA §312.5(b)): [method] and [verified] must reflect reality.
  /// For under-13 users, full access requires a completed email round trip;
  /// callers MUST pass [method] = 'email_pending' / [verified] = false until
  /// [verifyEmailConsent] succeeds. Never pass 'email_verified' for under-13
  /// unless an email round trip actually completed.
  ///
  /// 13+ self-attested / parent-attested consent is not COPPA verifiable
  /// consent; callers pass [verified] = false for those and a truthful
  /// [method] ('self_attested' or 'parent').
  Future<void> recordConsent({
    required int age,
    String? parentEmail,
    String method = 'self_attested',
    bool allowPhotoAvatar = false,
    bool verified = false,
    bool syncToServer = true,
  }) async {
    // Guard against a false compliance record: 'email_verified' may only be
    // stored when an actual round trip completed.
    assert(
      method != 'email_verified' || verified,
      "consent_method 'email_verified' requires verified == true",
    );
    final recordedAt = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
    await prefs.setBool(_keyConsent, true);
    await prefs.setString(_keyConsentMethod, method);
    await prefs.setBool(_keyConsentVerified, verified);
    await prefs.setString(_keyRecordedAt, recordedAt);
    await prefs.setBool(_keyAllowPhotoAvatar, allowPhotoAvatar);
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await prefs.setString(_keyParentEmail, parentEmail);
    }

    // Sync the consent record — including the child's declared age — to the
    // backend. This is COPPA-critical and must NOT be best-effort: the server
    // is the enforcement boundary (ENFORCE_RESOLVED_AGE denies generation /
    // data collection until it has a resolved age), so a consent/age record
    // that exists only on-device is not sufficient. The write is retried and
    // then surfaced to the caller (which reverts onboarding and lets the parent
    // retry) rather than silently dropped.
    //
    // [syncToServer] is false only for the pre-record written by
    // [requestEmailVerification], which immediately performs its own durable
    // server write (`/consent/request-verification`, which also persists the
    // declared age) — syncing here as well would be a redundant duplicate POST.
    if (syncToServer) {
      await _syncConsentToBackend(
        age: age,
        method: method,
        verified: verified,
        allowPhotoAvatar: allowPhotoAvatar,
        parentEmail: parentEmail,
      );
    }
  }

  /// POSTs the consent record (and the child's declared age) to the backend,
  /// retrying a bounded number of times on transient failure. Throws if the
  /// record could not be persisted server-side so the caller can surface the
  /// failure — a consent/age record that exists only on-device does not
  /// satisfy COPPA server-side enforcement (`ENFORCE_RESOLVED_AGE`).
  Future<void> _syncConsentToBackend({
    required int age,
    required String method,
    required bool verified,
    required bool allowPhotoAvatar,
    String? parentEmail,
  }) async {
    final api = ApiServiceManager();
    final userId = await api.getUserId();
    if (userId == null) {
      throw StateError(
        'No user id — cannot persist consent/declared age server-side.',
      );
    }
    final body = <String, dynamic>{
      'child_age': age,
      'consent_method': method,
      'verified': verified,
      'allow_photo_avatar': allowPhotoAvatar,
      if (parentEmail != null && parentEmail.isNotEmpty)
        'parent_email': parentEmail,
    };

    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await api.post('/api/user/$userId/consent', body);
        return;
      } catch (error) {
        lastError = error;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    throw Exception('Failed to persist consent to server: $lastError');
  }

  /// Begins the COPPA email round-trip for an under-13 user.
  ///
  /// Asks the backend to send a verification email containing a unique code/
  /// link to [parentEmail], and records consent locally as PENDING (granted
  /// flag set so onboarding can continue to the verification step, but
  /// [method] = 'email_pending' and verified = false). The child does NOT get
  /// full access until [verifyEmailConsent] completes.
  ///
  /// Returns true if the backend accepted the request and an email was queued.
  ///
  /// REQUIRES BACKEND: `POST /api/user/<id>/consent/request-verification`
  /// (see report — endpoint must be built server-side).
  Future<bool> requestEmailVerification({
    required int age,
    required String parentEmail,
    bool allowPhotoAvatar = false,
  }) async {
    final email = parentEmail.trim();
    if (!isValidEmail(email)) {
      throw ArgumentError('A valid parent email is required for verification.');
    }

    // Record locally as PENDING — truthful method, NOT verified. Skip the
    // generic /consent server sync here: the request-verification POST below is
    // the durable server write for the under-13 path (it persists the declared
    // age and the pending consent record), so syncing here too would create a
    // duplicate pending record.
    await recordConsent(
      age: age,
      parentEmail: email,
      method: 'email_pending',
      allowPhotoAvatar: allowPhotoAvatar,
      verified: false,
      syncToServer: false,
    );

    final api = ApiServiceManager();
    final userId = await api.getUserId();
    if (userId == null) {
      throw StateError('No user id — cannot request email verification.');
    }
    final resp = await api.post(
      '/api/user/$userId/consent/request-verification',
      {
        'child_age': age,
        'parent_email': email,
        'allow_photo_avatar': allowPhotoAvatar,
      },
    );
    return resp['success'] == true;
  }

  /// Completes the COPPA email round-trip: submits the [code] the parent
  /// received by email. On success, promotes the local record to verified
  /// consent ([method] = 'email_verified', verified = true).
  ///
  /// Returns true only when the backend confirms the code matched. A false
  /// return MUST leave consent as pending — the caller must not grant the
  /// child full access.
  ///
  /// REQUIRES BACKEND: `POST /api/user/<id>/consent/verify`
  /// (see report — endpoint must be built server-side).
  Future<bool> verifyEmailConsent({required String code}) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    final api = ApiServiceManager();
    final userId = await api.getUserId();
    if (userId == null) {
      throw StateError('No user id — cannot verify email consent.');
    }
    final resp = await api.post(
      '/api/user/$userId/consent/verify',
      {'code': trimmed},
    );
    final verified = resp['verified'] == true || resp['success'] == true;
    if (!verified) return false;

    // Promote local record to verified — only now is 'email_verified' truthful.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConsentMethod, 'email_verified');
    await prefs.setBool(_keyConsentVerified, true);
    await prefs.setBool(_keyConsent, true);
    await prefs.setString(
      _keyRecordedAt,
      DateTime.now().toIso8601String(),
    );
    return true;
  }

  /// Returns daily limit in minutes. null = unlimited (default).
  Future<int?> getDailyLimitMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_keyDailyLimitMinutes);
    return (val == null || val <= 0) ? null : val;
  }

  Future<void> setDailyLimitMinutes(int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes == null || minutes <= 0) {
      await prefs.remove(_keyDailyLimitMinutes);
    } else {
      await prefs.setInt(_keyDailyLimitMinutes, minutes);
    }
  }

  Future<bool> isBedtimeLockoutEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBedtimeLockoutEnabled) ?? false;
  }

  /// Returns bedtime hour and minute. Defaults to 20:00 (8 PM).
  Future<({int hour, int minute})> getBedtimeLockout() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_keyBedtimeLockoutHour) ?? 20,
      minute: prefs.getInt(_keyBedtimeLockoutMinute) ?? 0,
    );
  }

  Future<void> setBedtimeLockout({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBedtimeLockoutEnabled, enabled);
    await prefs.setInt(_keyBedtimeLockoutHour, hour);
    await prefs.setInt(_keyBedtimeLockoutMinute, minute);
  }

  Future<String?> getBigFeelingsParentHiddenContext() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyBigFeelingsParentHiddenContext)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> setBigFeelingsParentHiddenContext(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_keyBigFeelingsParentHiddenContext);
      return;
    }
    await prefs.setString(_keyBigFeelingsParentHiddenContext, trimmed);
  }

  Future<String?> getBigFeelingsRepairGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyBigFeelingsRepairGoal)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> setBigFeelingsRepairGoal(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_keyBigFeelingsRepairGoal);
      return;
    }
    await prefs.setString(_keyBigFeelingsRepairGoal, trimmed);
  }
}
