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
import 'package:story_weaver_app/widgets/star_burst_celebration.dart';

/// MT-387 — onboarding asks for AGE before NAME.
///
/// Before the reorder, `_selectedAge` was null for the entire name step on a
/// first run, so `_buildNameStep`'s band check (`ageBandFromAge(_selectedAge ??
/// 0)`) always resolved to the sprout branch. Every first-run user — a 16-year
/// old, an adult — got the toddler speech-bubble UI, the star burst, and
/// kid-rate TTS. The mature variant (`_buildCreatorNameStep`) could only ever
/// render for a RETURNING user whose age had already been persisted through
/// parental consent, which is why no test and no code review caught it.
///
/// These tests pin the order itself, and both sides of the band branch on a
/// first run. The mature cases below are unreachable on the old code.

/// No-op TTS so the welcome screen never hits the (mock-blocked) network.
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

/// Tap an age band and let the name step animate in.
Future<void> _tapAge(WidgetTester tester, String label) async {
  final pill = find.text(label);
  expect(pill, findsOneWidget, reason: 'Age picker should expose "$label"');
  await tester.tap(pill);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Teaser seen, no saved age — i.e. a genuine first run at the age gate.
    SharedPreferences.setMockInitialValues({'welcome_teaser_seen': true});
    ApiServiceManager.setTestClient(_buildClient());
    AppTtsService.instance = _FakeAppTtsService();
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AppTtsService.instance = null;
  });

  testWidgets('first run opens on the age picker, not the name field',
      (tester) async {
    await _pumpWelcomeScreen(tester);

    expect(find.text('How old is the storyteller?'), findsOneWidget,
        reason: 'Age must be the first thing asked (MT-387)');
    expect(find.byType(TextField), findsNothing,
        reason: 'The name field must not exist before the band is known');
  });

  testWidgets('an adolescent gets the mature name step on a FIRST run',
      (tester) async {
    await _pumpWelcomeScreen(tester);
    await _tapAge(tester, '15 – 17');

    expect(find.byKey(const ValueKey('creator-name')), findsOneWidget,
        reason: 'Ages 15-17 must get the profile-setup name step');
    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('name')), findsNothing,
        reason: 'The sprout speech-bubble step must not render for a teen');
    expect(find.byType(StarBurstCelebration), findsNothing,
        reason: 'No toddler star burst for a 16-year-old');
  });

  testWidgets('an adult gets the mature name step on a FIRST run',
      (tester) async {
    await _pumpWelcomeScreen(tester);
    await _tapAge(tester, '18+');

    expect(find.byKey(const ValueKey('creator-name')), findsOneWidget);
    expect(find.byType(StarBurstCelebration), findsNothing);
  });

  testWidgets('a young child still gets the sprout name step', (tester) async {
    await _pumpWelcomeScreen(tester);
    await _tapAge(tester, '5');

    expect(find.byKey(const ValueKey('name')), findsOneWidget,
        reason: 'The young branch must be unchanged by the reorder');
    expect(find.byType(StarBurstCelebration), findsOneWidget,
        reason: 'The burst layer belongs on the young name step');
    expect(find.byKey(const ValueKey('creator-name')), findsNothing);
  });

  testWidgets('back from the name step returns to the age picker',
      (tester) async {
    await _pumpWelcomeScreen(tester);
    await _tapAge(tester, '15 – 17');
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('How old is the storyteller?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
