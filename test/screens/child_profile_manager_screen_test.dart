import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/child_profile_manager_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/child_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAtPhoneWidth(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ChildProfileManagerScreen()),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'story_weaver_user_id': 'u1'});
    await ApiServiceManager.resetAuthForTest();
    final service = ChildProfileService();
    await service.saveProfile(
        ChildProfile(id: 'a', name: 'Alexandria', age: 5));
    await service.saveProfile(ChildProfile(id: 'b', name: 'Ben', age: 9));
  });

  tearDown(() => ApiServiceManager.setTestClient(null));

  testWidgets('the delete dialog says what goes and what stays',
      (tester) async {
    await pumpAtPhoneWidth(tester);

    await tester.tap(find.byTooltip('Delete profile').first);
    await tester.pumpAndSettle();

    expect(find.textContaining("Alexandria's profile"), findsOneWidget);
    expect(find.textContaining('Saved heroes and stories are kept'),
        findsOneWidget);
    expect(find.textContaining('Parent Controls'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed delete leaves the child in the list and says so',
      (tester) async {
    ApiServiceManager.setTestClient(MockClient((request) async {
      if (request.url.path.contains('/auth/')) {
        return http.Response(
            jsonEncode({'token': 'mock', 'user_id': 'u1'}), 200);
      }
      return http.Response('{}', 500);
    }));
    await pumpAtPhoneWidth(tester);

    await tester.tap(find.byTooltip('Delete profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Alexandria'), findsOneWidget);
    expect(find.textContaining('was not deleted'), findsOneWidget);
  });
}
