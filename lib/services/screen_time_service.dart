import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'parental_consent_service.dart';

/// Tracks daily app usage and emits warnings for screen-time limits.
class ScreenTimeService {
  ScreenTimeService._();

  static final ScreenTimeService instance = ScreenTimeService._();

  final _consentService = const ParentalConsentService();
  final StreamController<int> _windDownController =
      StreamController<int>.broadcast();
  final StreamController<int> _limitReachedController =
      StreamController<int>.broadcast();
  final StreamController<void> _bedtimeController =
      StreamController<void>.broadcast();

  Timer? _ticker;
  bool _windDownFired = false;
  bool _limitFired = false;
  String? _lastTickDate;

  Stream<int> get onWindDown => _windDownController.stream;
  Stream<int> get onLimitReached => _limitReachedController.stream;
  Stream<void> get onBedtimeLockout => _bedtimeController.stream;

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  String get _todayKey => 'screen_time_$_todayDate';

  void start() {
    _ticker?.cancel();
    _lastTickDate = _todayDate;
    _windDownFired = false;
    _limitFired = false;
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_tick());
    });
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _tick() async {
    final today = _todayDate;
    if (_lastTickDate != today) {
      _lastTickDate = today;
      _windDownFired = false;
      _limitFired = false;
    }

    final prefs = await SharedPreferences.getInstance();
    final used = (prefs.getInt(_todayKey) ?? 0) + 1;
    await prefs.setInt(_todayKey, used);

    final bedtimeEnabled = await _consentService.isBedtimeLockoutEnabled();
    if (bedtimeEnabled) {
      final bedtime = await _consentService.getBedtimeLockout();
      final now = DateTime.now();
      final bedtimeToday = DateTime(
        now.year,
        now.month,
        now.day,
        bedtime.hour,
        bedtime.minute,
      );
      if (!now.isBefore(bedtimeToday)) {
        _bedtimeController.add(null);
        return;
      }
    }

    final limit = await _consentService.getDailyLimitMinutes();
    if (limit == null) {
      return;
    }

    final remaining = limit - used;
    if (remaining <= 5 && remaining > 0 && !_windDownFired) {
      _windDownFired = true;
      _windDownController.add(remaining);
    }

    if (remaining <= 0 && !_limitFired) {
      _limitFired = true;
      _limitReachedController.add(limit);
    }
  }

  Future<int> getTodayUsageMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_todayKey) ?? 0;
  }

  Future<int?> getRemainingMinutes() async {
    final limit = await _consentService.getDailyLimitMinutes();
    if (limit == null) {
      return null;
    }
    final used = await getTodayUsageMinutes();
    return (limit - used).clamp(0, limit);
  }

  Future<void> grantExtraTime(int extraMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_todayKey) ?? 0;
    await prefs.setInt(_todayKey, (used - extraMinutes).clamp(0, 9999));
    _limitFired = false;
    _windDownFired = false;
  }
}
