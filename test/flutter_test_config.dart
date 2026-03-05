import 'dart:async';

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
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

  FirebasePlatform.instance = _TestFirebasePlatform();
  FirebaseAnalyticsPlatform.instance = _TestFirebaseAnalyticsPlatform();
  await testMain();
}
