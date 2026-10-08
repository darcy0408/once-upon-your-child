// The home screen's "story limit reached" state is driven by the backend's
// usage-stats count (there is no on-device story counter any more), so this
// pins both the limit rule and the best-effort fetch behind it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/usage_stats.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/usage_stats_service.dart';

Map<String, dynamic> _payload({required int used, required int limit}) => {
      'stories_this_month': used,
      'stories_limit': limit,
      'characters_count': 1,
      'characters_limit': 2,
      'period_start': '2026-10-01T00:00:00Z',
      'period_end': '2026-11-01T00:00:00Z',
    };

http.Response _authResponse() => http.Response(
      jsonEncode({'access_token': 'tok', 'user_id': 'anon_1'}),
      200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiServiceManager.resetAuthForTest();
    ApiServiceManager.setTestClient(MockClient((_) async => _authResponse()));
  });

  tearDown(() async {
    ApiServiceManager.setTestClient(null);
    await ApiServiceManager.resetAuthForTest();
  });

  group('UsageStats.monthlyStoryLimitReached', () {
    test('false below the limit, true at and above it', () {
      expect(
        UsageStats.fromJson(_payload(used: 4, limit: 5))
            .monthlyStoryLimitReached,
        isFalse,
      );
      expect(
        UsageStats.fromJson(_payload(used: 5, limit: 5))
            .monthlyStoryLimitReached,
        isTrue,
      );
      expect(
        UsageStats.fromJson(_payload(used: 9, limit: 5))
            .monthlyStoryLimitReached,
        isTrue,
      );
    });

    test('a limit of 0 means unlimited', () {
      expect(
        UsageStats.fromJson(_payload(used: 400, limit: 0))
            .monthlyStoryLimitReached,
        isFalse,
      );
    });
  });

  group('UsageStatsService.fetch', () {
    test('reads the backend count for the given user', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(_payload(used: 5, limit: 5)), 200);
      });

      final usage = await UsageStatsService.fetch('anon_1', client: client);

      expect(requested!.path, '/api/user/anon_1/usage-stats');
      expect(usage!.storiesThisMonth, 5);
      expect(usage.monthlyStoryLimitReached, isTrue);
    });

    test('returns null instead of throwing when the backend errors', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      expect(await UsageStatsService.fetch('anon_1', client: client), isNull);
    });

    test('returns null when the request itself fails', () async {
      final client = MockClient((_) async => throw http.ClientException('x'));
      expect(await UsageStatsService.fetch('anon_1', client: client), isNull);
    });

    test('skips the request when there is no user id', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      expect(await UsageStatsService.fetch('', client: client), isNull);
      expect(calls, 0);
    });
  });
}
