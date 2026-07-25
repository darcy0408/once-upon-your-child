// Locks the evening-only screen-free Bedtime banner on WizardStoryScreen's
// landing state (lib/screens/wizard_story_screen.dart): absent during the day,
// present after 18:30 local time, and dismissable for the rest of the screen's
// life. The always-present Bedtime item in the top nav is the daytime entry
// point, so the banner's absence before 18:30 hides nothing.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:story_weaver_app/models/wizard_data.dart';
import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/avatar_generation_state.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarGenerationState().reset();

    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      if (url.contains('/get-characters')) {
        return http.Response(jsonEncode({'characters': []}), 200);
      }
      return http.Response('Not Found', 404);
    });
    ApiServiceManager.setTestClient(mockClient);
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AvatarGenerationState().reset();
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    required DateTime Function() clock,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: WizardStoryScreen(
            availableCharacters: const [],
            initialWizardData: WizardData()..characterName = 'Test Hero',
            clock: clock,
          ),
        ),
      ),
    );
    // MoonPhaseProgress runs a looping animation — pump a fixed duration
    // rather than pumpAndSettle so the test doesn't hang.
    await tester.pump(const Duration(milliseconds: 500));
  }

  final banner = find.byKey(const Key('bedtimeEveningBanner'));
  final dismiss = find.byKey(const Key('bedtimeEveningBannerDismiss'));

  testWidgets('no bedtime banner during the day', (tester) async {
    await pumpWizard(tester, clock: () => DateTime(2026, 7, 18, 10, 0));
    expect(banner, findsNothing);
  });

  testWidgets('banner appears after 18:30', (tester) async {
    await pumpWizard(tester, clock: () => DateTime(2026, 7, 18, 20, 0));
    expect(banner, findsOneWidget);
  });

  testWidgets('18:30 exactly is inside the window', (tester) async {
    // Boundary: the cutoff is inclusive, so 18:29 is still daytime and 18:30
    // is the first promoted minute.
    await pumpWizard(tester, clock: () => DateTime(2026, 7, 18, 18, 29));
    expect(banner, findsNothing);

    await pumpWizard(tester, clock: () => DateTime(2026, 7, 18, 18, 30));
    expect(banner, findsOneWidget);
  });

  testWidgets('banner can be dismissed for the rest of the screen',
      (tester) async {
    await pumpWizard(tester, clock: () => DateTime(2026, 7, 18, 20, 0));
    expect(banner, findsOneWidget);

    await tester.tap(dismiss);
    await tester.pump(const Duration(milliseconds: 300));

    expect(banner, findsNothing);
  });
}
