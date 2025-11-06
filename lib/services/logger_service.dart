// lib/services/logger_service.dart
// Simple logging service for production-ready debugging

import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggerService {
  static const String _tag = '[StoryWeaver]';

  // Log debug messages (only in debug mode)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log(LogLevel.debug, message, error, stackTrace);
    }
  }

  // Log informational messages
  static void info(String message) {
    _log(LogLevel.info, message);
  }

  // Log warnings
  static void warning(String message, [Object? error]) {
    _log(LogLevel.warning, message, error);
  }

  // Log errors
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(LogLevel level, String message,
      [Object? error, StackTrace? stackTrace]) {
    final levelStr = level.name.toUpperCase().padRight(7);
    final timestamp = DateTime.now().toIso8601String();

    // Basic console logging
    if (kDebugMode) {
      debugPrint('$_tag [$levelStr] [$timestamp] $message');
      if (error != null) {
        debugPrint('$_tag [$levelStr] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_tag [$levelStr] StackTrace:\n$stackTrace');
      }
    } else {
      // In production, only log warnings and errors
      if (level == LogLevel.warning || level == LogLevel.error) {
        debugPrint('$_tag [$levelStr] $message');
      }
    }

    // TODO: In production, you could send errors to a service like Sentry or Firebase Crashlytics
    // if (level == LogLevel.error && error != null) {
    //   FirebaseCrashlytics.instance.recordError(error, stackTrace);
    // }
  }
}
