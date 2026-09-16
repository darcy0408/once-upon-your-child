import 'dart:async';
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

/// MT-431: submitting the name synthesises a greeting that carries the name
/// (always a cache miss) and waits for it to play before onboarding moves on.
/// On a cold backend that ran to ~20 s with no feedback at all — the screen
/// read as a broken app. The submit button must show a spinner and refuse a
/// second press for the duration, and a stalled greeting must not hold
/// onboarding hostage.

/// TTS whose awaited greeting never completes unless the test says so.
class _StallingTts extends AppTtsService {
  _StallingTts() : super.forTesting();

  /// Greetings requested so far ("Hi, <name>."); other prompts the screen
  /// awaits (the age-tap prompt) complete at once and are not counted.
  int awaitedSpeaks = 0;
  final Completer<void> greeting = Completer<void>();

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
  }) {
    if (!awaitCompletion || !text.startsWith('Hi, ')) return Future.value();
    awaitedSpeaks++;
    return greeting.future;
  }

  @override
  Future<void> stop() async {}
}

MockClient _buildClient() {
  return MockClient((request) async {
    if (request.method == 'POST' &&
        request.url.path.contains('/auth/anonymous')) {
      return http.Response(
        jsonEncode({'token': 'mock_token', 'user_id': 'user-123'}),
        200,
      );
    }
    return http.Response('{}', 200);
  });
}

const _spinner = ValueKey('name-submit-spinner');

Future<void> _pumpWelcomeScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: WelcomeScreen(onComplete: () {})),
    ),
  );
  // No pumpAndSettle — the teaser's "Tap me!" hint runs repeat() and never
  // settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _reachNameStep(WidgetTester tester) async {
  await _pumpWelcomeScreen(tester);
  await tester.tap(find.text('18+'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.enterText(find.byType(TextField), 'Darcy');
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StallingTts tts;

  setUp(() {
    SharedPreferences.setMockInitialValues({'welcome_teaser_seen': true});
    ApiServiceManager.setTestClient(_buildClient());
    tts = _StallingTts();
    AppTtsService.instance = tts;
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AppTtsService.instance = null;
  });

  testWidgets('submitting the name shows a spinner while the greeting plays',
      (tester) async {
    await _reachNameStep(tester);
    expect(find.byKey(_spinner), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.byKey(_spinner), findsOneWidget,
        reason: 'The wait for the greeting must be visible on the button');
    expect(tts.awaitedSpeaks, 1);

    // Let the greeting finish and the flow move on; drain the timers.
    tts.greeting.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('a second press during the greeting is ignored', (tester) async {
    await _reachNameStep(tester);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(tts.awaitedSpeaks, 1,
        reason: 'The button is disabled for the duration of the greeting');

    tts.greeting.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('a stalled greeting releases the screen after the cap',
      (tester) async {
    await _reachNameStep(tester);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.byKey(_spinner), findsOneWidget);

    // Never complete the greeting: the 10 s cap must clear the spinner.
    await tester.pump(const Duration(seconds: 11));

    expect(find.byKey(_spinner), findsNothing,
        reason: 'Onboarding must not freeze on a stalled synthesis request');
    await tester.pump(const Duration(seconds: 2));
  });
}
