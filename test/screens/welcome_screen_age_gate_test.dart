import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/welcome_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/app_tts_service.dart';

/// No-op TTS so the welcome screen never hits the (mock-blocked) network.
/// Without this stub, `_speak()` calls fan out to ElevenLabs via
/// `TtsApiService.synthesize`, which 400s in widget tests and leaves
/// pending futures around long enough to time out `pumpAndSettle`.
class _FakeAppTtsService extends AppTtsService {
  _FakeAppTtsService() : super.forTesting();

  @override
  Future<void> init({List<String> warmUpPhrases = const []}) async {}

  @override
  void markInteracted() {}

  @override
  Future<void> speak(
    String text, {
    String? voiceId,
    bool awaitCompletion = false,
    double rateScale = 0.85,
  }) async {}

  @override
  Future<void> stop() async {}
}

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
  // Let _resumeFromSavedAge() and _initVoice() complete. We can't use
  // pumpAndSettle here — the title-step "Tap me!" hint runs an
  // AnimationController.repeat(), which never settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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
    AppTtsService.instance = _FakeAppTtsService();
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AppTtsService.instance = null;
  });

  testWidgets(
    'tapping age 16 surfaces the "Just so you know" acknowledgement dialog',
    (tester) async {
      var completed = false;
      await _pumpWelcomeScreen(tester, onComplete: () => completed = true);
      await _selectAge16(tester);

      // MT-012 (commit 1ec9862): notice-only dialog with a single "Got it"
      // action — it is informational, not a gate. The user cannot cancel.
      expect(find.text('Just so you know'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(completed, isFalse,
          reason: 'onComplete must not fire until the user acknowledges');
    },
  );

  testWidgets(
    'tapping "Got it" records self_attested consent for age 16',
    (tester) async {
      var completed = false;
      await _pumpWelcomeScreen(tester, onComplete: () => completed = true);
      await _selectAge16(tester);

      expect(find.text('Just so you know'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      // No pumpAndSettle — the title-step animation never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
    'dialog is barrier-dismissible-false and exposes no cancel path',
    (tester) async {
      var completed = false;
      await _pumpWelcomeScreen(tester, onComplete: () => completed = true);
      await _selectAge16(tester);

      // Notice-only design: confirm there is no escape hatch besides "Got it".
      // No "Cancel" / "I understand" / close icon — the user must acknowledge.
      expect(find.text('Just so you know'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('I understand'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(completed, isFalse,
          reason: 'onComplete must not fire while the dialog is open');
    },
  );
}
