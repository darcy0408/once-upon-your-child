// lib/services/therapist_auth_service.dart
//
// Simple PIN-based gate for the Therapist Portal.
// The PIN is set on first use and stored in SharedPreferences.
// This keeps the portal out of reach of children while remaining
// accessible to therapists who share a device with families.

import 'package:shared_preferences/shared_preferences.dart';

class TherapistAuthService {
  static const _pinKey = 'therapist_portal_pin';

  /// Returns true if a PIN has been set.
  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    return pin != null && pin.length == 4;
  }

  /// Sets the PIN. Must be exactly 4 digits.
  Future<void> setPin(String pin) async {
    assert(pin.length == 4 && int.tryParse(pin) != null,
        'PIN must be 4 digits');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  /// Returns true if [pin] matches the stored PIN.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) == pin;
  }

  /// Removes the PIN (for testing / reset flow).
  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }
}
