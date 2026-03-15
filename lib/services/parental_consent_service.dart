import 'package:shared_preferences/shared_preferences.dart';

import 'api_service_manager.dart';

class ParentalConsentService {
  const ParentalConsentService();

  static const _keyAge = 'user_age';
  static const _keyConsent = 'parental_consent_granted';
  static const _keyParentEmail = 'parent_email';
  static const _keyConsentMethod = 'parental_consent_method';
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
    return prefs.getBool(_keyAllowPhotoAvatar) ?? true;
  }

  Future<void> setAllowPhotoAvatar(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowPhotoAvatar, allow);
  }

  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsent) ?? false;
  }

  Future<int?> getRecordedAge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAge);
  }

  Future<void> saveDeclaredAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
  }

  Future<void> recordConsent({
    required int age,
    String? parentEmail,
    String method = 'email_plus',
    bool allowPhotoAvatar = true,
  }) async {
    final recordedAt = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
    await prefs.setBool(_keyConsent, true);
    await prefs.setString(_keyConsentMethod, method);
    await prefs.setString(_keyRecordedAt, recordedAt);
    await prefs.setBool(_keyAllowPhotoAvatar, allowPhotoAvatar);
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await prefs.setString(_keyParentEmail, parentEmail);
    }

    // Sync consent record to backend (best-effort — local record is source of truth).
    try {
      final api = ApiServiceManager();
      final userId = await api.getUserId();
      if (userId != null) {
        await api.post('/api/user/$userId/consent', {
          'age': age,
          'method': method,
          'allow_photo_avatar': allowPhotoAvatar,
          'recorded_at': recordedAt,
          if (parentEmail != null && parentEmail.isNotEmpty)
            'parent_email': parentEmail,
        });
      }
    } catch (_) {
      // Backend sync failure does not block local consent — will retry on next launch.
    }
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
