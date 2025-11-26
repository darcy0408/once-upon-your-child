import 'package:shared_preferences/shared_preferences.dart';

class ParentalConsentService {
  const ParentalConsentService();

  static const _keyAge = 'user_age';
  static const _keyConsent = 'parental_consent_granted';
  static const _keyParentEmail = 'parent_email';
  static const _keyConsentMethod = 'parental_consent_method';
  static const _keyRecordedAt = 'parental_consent_recorded_at';

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAge, age);
    await prefs.setBool(_keyConsent, true);
    await prefs.setString(_keyConsentMethod, method);
    await prefs.setString(_keyRecordedAt, DateTime.now().toIso8601String());
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await prefs.setString(_keyParentEmail, parentEmail);
    }
  }
}
