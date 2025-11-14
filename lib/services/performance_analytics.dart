import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PerformanceAnalytics {
  PerformanceAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackAppStart() async {
    final info = await PackageInfo.fromPlatform();
    await _analytics.logEvent(
      name: 'app_start',
      parameters: {
        'platform': Platform.operatingSystem,
        'version': info.version,
        'build_number': info.buildNumber,
      },
    );
  }

  static Future<void> trackError(String errorType, String errorMessage) async {
    final truncated = errorMessage.length > 100
        ? errorMessage.substring(0, 100)
        : errorMessage;
    await _analytics.logEvent(
      name: 'error_occurred',
      parameters: {
        'error_type': errorType,
        'error_message': truncated,
      },
    );
  }
}
