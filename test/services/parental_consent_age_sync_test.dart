// MT-351: covers the client-side wiring for PATCH /api/user/<id>/age.
//
// `ParentalConsentService.saveDeclaredAge` is the single local-write choke
// point for "the declared age changed" (see the onboarding under-13 path in
// welcome_screen.dart). It now also fires a best-effort, fire-and-forget
// sync to the backend via `ApiServiceManager.syncDeclaredAge`, which is the
// only client caller of the previously-unwired PATCH /api/user/<id>/age
// endpoint (backend/routes/user_routes.py, `set_declared_age`).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/parental_consent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiServiceManager.resetAuthForTest();
  });

  tearDown(() async {
    ApiServiceManager.setTestClient(null);
    await ApiServiceManager.resetAuthForTest();
  });

  test(
    'saveDeclaredAge persists locally and PATCHes /api/user/<id>/age for an '
    'authenticated (anon_-prefixed) user',
    () async {
      final requests = <http.Request>[];
      ApiServiceManager.setTestClient(MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.path.contains('/auth/anonymous')) {
          return http.Response(
            jsonEncode({'token': 'mock_token', 'user_id': 'anon_test123'}),
            200,
          );
        }
        if (request.method == 'PATCH' && request.url.path.contains('/age')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'declared_age': 9,
              'is_under_13': true,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }));

      const service = ParentalConsentService();
      await service.saveDeclaredAge(9);
      // Flush the fire-and-forget sync scheduled by `unawaited(...)`.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('user_age'), 9,
          reason: 'the local write must never depend on the network sync');

      final ageRequest = requests.firstWhere(
        (r) => r.method == 'PATCH' && r.url.path.contains('/age'),
        orElse: () =>
            throw StateError('expected a PATCH .../age request, got none'),
      );
      expect(ageRequest.url.path, contains('anon_test123'),
          reason: 'must PATCH the authenticated anon_ user, not skip it');
      expect(jsonDecode(ageRequest.body), {'age': 9});
    },
  );

  test(
    'saveDeclaredAge does not throw when the backend PATCH fails '
    '(non-blocking, matches SubscriptionSyncService failure handling)',
    () async {
      ApiServiceManager.setTestClient(MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.contains('/auth/anonymous')) {
          return http.Response(
            jsonEncode({'token': 'mock_token', 'user_id': 'anon_test456'}),
            200,
          );
        }
        if (request.method == 'PATCH' && request.url.path.contains('/age')) {
          return http.Response(jsonEncode({'error': 'boom'}), 500);
        }
        return http.Response('{}', 200);
      }));

      const service = ParentalConsentService();
      await expectLater(service.saveDeclaredAge(7), completes);
      // Let the retry-then-swallow logic run to completion before asserting.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('user_age'), 7);
    },
  );

  test(
    'ApiServiceManager.syncDeclaredAge is a no-op for an empty user id',
    () async {
      var called = false;
      ApiServiceManager.setTestClient(MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      }));

      await ApiServiceManager.syncDeclaredAge('', 10);

      expect(called, isFalse);
    },
  );
}
