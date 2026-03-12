import 'package:shared_preferences/shared_preferences.dart';

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
    String method = 'parent',
    bool allowPhotoAvatar = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
    await prefs.setBool(_keyConsent, true);
    await prefs.setString(_keyConsentMethod, method);
    await prefs.setString(_keyRecordedAt, DateTime.now().toIso8601String());
    await prefs.setBool(_keyAllowPhotoAvatar, allowPhotoAvatar);
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await prefs.setString(_keyParentEmail, parentEmail);
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
}
