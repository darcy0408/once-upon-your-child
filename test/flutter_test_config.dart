import 'dart:async';

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _TestFirebasePlatform extends FirebasePlatform {
  _TestFirebasePlatform() {
    _defaultApp = _TestFirebaseAppPlatform();
  }

  late final FirebaseAppPlatform _defaultApp;

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[_defaultApp];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return _defaultApp;
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _defaultApp;
  }
}

class _TestFirebaseAppPlatform extends FirebaseAppPlatform {
  _TestFirebaseAppPlatform()
      : super(
          defaultFirebaseAppName,
          const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: 'test-app-id',
            messagingSenderId: 'test-sender',
            projectId: 'test-project',
          ),
        );

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> delete() async {}

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}
}

class _TestFirebaseAnalyticsPlatform extends FirebaseAnalyticsPlatform {
  _TestFirebaseAnalyticsPlatform({FirebaseApp? appInstance})
      : super(appInstance: appInstance);

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) {
    return _TestFirebaseAnalyticsPlatform(appInstance: app);
  }

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<String?> getAppInstanceId() async => 'test-app-instance-id';

  @override
  Future<int?> getSessionId() async => 1;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserId({
    String? id,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> setCurrentScreen({
    String? screenName,
    String? screenClassOverride,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {}

  @override
  Future<void> resetAnalyticsData() async {}

  @override
  Future<void> setSessionTimeoutDuration(Duration timeout) async {}

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {}

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?>? defaultParameters,
  ) async {}

  @override
  Future<void> initiateOnDeviceConversionMeasurement({
    String? emailAddress,
    String? phoneNumber,
    String? hashedEmailAddress,
    String? hashedPhoneNumber,
  }) async {}
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Disable Google Fonts runtime fetching in tests to prevent network calls
  GoogleFonts.config.allowRuntimeFetching = false;

  // Suppress the ink_sparkle.frag shader error that fires whenever a tap
  // triggers a Navigator.push with InkSparkle effects in the test environment.
  // This is a Flutter test infra limitation, not a real app bug.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('ink_sparkle.frag') ||
        msg.contains('Unable to load asset: "assets/images/ui/clean/')) {
      return; // benign test-env-only errors — swallow silently
    }
    originalOnError?.call(details);
  };

  // Mock flutter_secure_storage method channel so tests don't throw
  // MissingPluginException when SecureStorageService is called.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final storage = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'read':
        final key = methodCall.arguments['key'] as String;
        return storage[key];
      case 'write':
        final key = methodCall.arguments['key'] as String;
        final value = methodCall.arguments['value'] as String;
        storage[key] = value;
        return null;
      case 'delete':
        final key = methodCall.arguments['key'] as String;
        storage.remove(key);
        return null;
      case 'deleteAll':
        storage.clear();
        return null;
      case 'readAll':
        return storage;
      default:
        return null;
    }
  });

  FirebasePlatform.instance = _TestFirebasePlatform();
  FirebaseAnalyticsPlatform.instance = _TestFirebaseAnalyticsPlatform();
  await testMain();
}
