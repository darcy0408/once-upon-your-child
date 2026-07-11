// MT-353 — "Report this content" affordance on the story result screen.
//
// Coverage:
//  - the affordance is parent-gated (ParentalGateDialog) before any report
//    reaches the backend, so a child tapping around can't misfire a
//    moderation report;
//  - a correct gate answer + reason submits to POST /report-story and shows
//    the "a grown-up will review this" confirmation;
//  - a wrong gate answer never lets the report dialog (or the network call)
//    through.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/offline_story_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';

class _FakeOfflineStoryService extends Fake implements OfflineStoryService {
  @override
  Future<StoryLocal?> getStory(String storyId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> requestedPaths;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiServiceManager.resetAuthForTest();
    requestedPaths = <String>[];

    final mockClient = MockClient((request) async {
      final path = request.url.path;
      requestedPaths.add(path);

      if (path.contains('auth/anonymous')) {
        return http.Response(
          jsonEncode({
            // ApiServiceManager validates the auth token as a 3-segment JWT
            // and discards anything else; use a JWT-shaped token (no `exp`).
            'token': 'eyJhbGciOiAibm9uZSJ9.eyJzdWIiOiAidXNlcl8xMjMifQ.sig',
            'user_id': 'mock_user_123',
          }),
          200,
        );
      }
      if (path.contains('report-story')) {
        return http.Response(
          jsonEncode({
            'status': 'reported',
            'message': 'Thank you for your report',
          }),
          200,
        );
      }
      return http.Response('Not Found', 404);
    });
    ApiServiceManager.setTestClient(mockClient);
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
  });

  int productFromGatePrompt(WidgetTester tester) {
    final prompt = tester.widget<Text>(find.textContaining('×')).data!;
    final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(prompt)!;
    return int.parse(m.group(1)!) * int.parse(m.group(2)!);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StoryResultScreen(
            title: 'Report Test Story',
            storyText: 'Once upon a time in report-land...',
            wisdomGem: '',
            characterName: 'Ava',
            storyId: 'story_report_test',
            trackStoryCreation: false,
            trackAnalytics: false,
            offlineService: _FakeOfflineStoryService(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('report-land').evaluate().isNotEmpty) break;
    }
  }

  Future<void> openReportSheet(WidgetTester tester) async {
    await tester.tap(find.text('Created with AI'));
    await tester.pumpAndSettle();
    expect(find.text('Report this content'), findsOneWidget);
    await tester.tap(find.text('Report this content'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'correct gate answer + reason posts to /report-story and confirms',
      (tester) async {
    await pumpScreen(tester);
    await openReportSheet(tester);

    // Parent gate is up; nothing has been sent yet.
    expect(find.textContaining('×'), findsOneWidget);
    expect(requestedPaths.any((p) => p.contains('report-story')), isFalse);

    final product = productFromGatePrompt(tester);
    await tester.enterText(find.byType(TextField).first, '$product');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Reason dialog now shown.
    expect(find.text('Report this content'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'This part scared my kid',
    );
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(requestedPaths.any((p) => p.contains('report-story')), isTrue);
    expect(
      find.textContaining('a grown-up will review this'),
      findsOneWidget,
    );
  });

  testWidgets('wrong gate answer blocks the reason dialog and the network call',
      (tester) async {
    await pumpScreen(tester);
    await openReportSheet(tester);

    final product = productFromGatePrompt(tester);
    await tester.enterText(find.byType(TextField).first, '${product + 1}');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Still on the gate — reason dialog never appears, no request fired.
    expect(find.textContaining('×'), findsOneWidget);
    expect(find.text('Report'), findsNothing);
    expect(requestedPaths.any((p) => p.contains('report-story')), isFalse);
  });
}
