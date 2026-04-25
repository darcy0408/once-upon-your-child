import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/welcome_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';

/// Stub HTTP client that 200s every request — keeps the best-effort consent
/// POST inside `ParentalConsentService.recordConsent` from blowing up the test.
MockClient _buildClient() {
  return MockClient((request) async {
    if (request.method == 'POST' &&
        request.url.path.contains('/auth/anonymous')) {
      return http.Response(
        jsonEncode({'token': 'mock_token', 'user_id': 'user-123'}),
        200,
      );
    }
    if (request.method == 'POST' &&
        request.url.path.contains('/consent')) {
      return http.Response(jsonEncode({'ok': true}), 201);
    }
    return http.Response('{}', 200);
  });
}

Future<void> _pumpWelcomeScreen(WidgetTester tester,
    {required VoidCallback onComplete}) async {
  // Big enough to render the whole onboarding flow without overflow asserts.
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: WelcomeScreen(onComplete: onComplete),
      ),
    ),
  );
  // Let _resumeFromSavedAge() and _initVoice() complete.
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// Drive the onboarding flow far enough to land on the age picker, then tap
/// the `15 – 17` band (value 16) and advance through the title splash so
/// `_handleContinue` fires (the path that surfaces the new dialog).
Future<void> _selectAge16(WidgetTester tester) async {
  // Step 0: name input. Type a name then submit via TextInputAction.done,
  // which calls `_advanceFromName` directly — independent of button styling.
  final nameField = find.byType(TextField);
  expect(nameField, findsOneWidget);
  await tester.enterText(nameField, 'QA Tester');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(milliseconds: 300));

  // Step 1: age picker. Tap the `15 – 17` band.
  final agePill = find.text('15 – 17');
  expect(agePill, findsOneWidget,
      reason: 'Age picker should expose the 15-17 band');
  await tester.tap(agePill);
  await tester.pump(const Duration(milliseconds: 300));

  // Step 2: title splash. `_onAgeSelected` schedules a 7s timer that fires
  // `_handleContinue`. Skip the timer by tapping the splash to invoke
  // `_advanceFromTitle` directly. The splash root is a GestureDetector that
  // fills the body — tap somewhere safe inside the screen bounds.
  await tester.tapAt(const Offset(600, 1000));
  // Pump enough frames for the showDialog future to surface.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mark the teaser as seen so the welcome screen lands on the name step.
    SharedPreferences.setMockInitialValues({
      'welcome_teaser_seen': true,
    });
    ApiServiceManager.setTestClient(_buildClient());
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
  });

  testWidgets(
    'tapping age 16 surfaces the "Just so you know" acknowledgement dialog',
    (tester) async {
      var completed = false;
      await _pumpWelcomeScreen(tester, onComplete: () => completed = true);
      await _selectAge16(tester);

      expect(find.text('Just so you know'), findsOneWidget);
      expect(find.text('I understand'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(completed, isFalse,
          reason: 'onComplete must not fire until the user acknowledges');
    },
  );

  testWidgets(
    'tapping "I understand" records self_attested consent for age 16',
    (tester) async {
      var completed = false;
      await _pumpWelcomeScreen(tester, onComplete: () => completed = true);
      await _selectAge16(tester);

      expect(find.text('Just so you know'), findsOneWidget);
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('parental_consent_granted'), isTrue,
          reason: 'recordConsent should have flipped the consent flag');
      expect(prefs.getInt('user_age'), 16);
      expect(prefs.getString('parental_consent_method'), 'self_attested');
      expect(completed, isTrue,
          reason: 'onComplete should fire after acknowledgement');
    },
  );

  testWidgets(
    'tapping "Cancel" leaves consent unrecorded and returns to age picker',
    (tester) async {
      var completed = false;
      await _pumpWelcomeScreen(tester, onComplete: () => completed = true);
      await _selectAge16(tester);

      expect(find.text('Just so you know'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('parental_consent_granted'), isNot(isTrue),
          reason: 'recordConsent must NOT run when user cancels');
      expect(prefs.getString('parental_consent_method'), isNull);
      expect(completed, isFalse,
          reason: 'onComplete must not fire when user cancels');
      // Back on the age picker → the band labels are visible again.
      expect(find.text('15 – 17'), findsOneWidget);
    },
  );
}
