import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PerformanceAnalytics {
  PerformanceAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackAppStart() async {
    try {
      final info = await PackageInfo.fromPlatform();
      await _analytics.logEvent(
        name: 'app_start',
        parameters: <String, dynamic>{
          'platform': Platform.operatingSystem,
          'version': info.version,
          'build_number': info.buildNumber,
        },
      );
    } catch (e) {
      // Swallow analytics failures so startup never crashes.
      // ignore: avoid_print
      // ignore: avoid_print
      debugPrint('Analytics logEvent failed (app_start): ${e.toString()}');
    }
  }

  static Future<void> trackError(
    String errorType,
    String errorMessage,
  ) async {
    try {
      await _analytics.logEvent(
        name: 'error_occurred',
        parameters: <String, dynamic>{
          'error_type': errorType,
          'error_message': errorMessage.length > 100
              ? errorMessage.substring(0, 100)
              : errorMessage,
        },
      );
    } catch (e) {
      // ignore: avoid_print
      // ignore: avoid_print
      debugPrint('Analytics logEvent failed (error_occurred): ${e.toString()}');
    }
  }
}
