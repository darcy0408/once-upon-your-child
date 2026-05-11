import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/per_page_illustration_prefetcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
  });

  group('PerPageIllustrationPrefetcher quota handling', () {
    test(
      'ILLUSTRATION_QUOTA_EXCEEDED short-circuits remaining pages',
      () async {
        // Track POSTs to /generate-illustrations so we can assert the
        // prefetcher stops calling once the cap is hit.
        var generateCallCount = 0;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/auth/anonymous')) {
            return http.Response(
              jsonEncode({'token': 'tok', 'user_id': 'u1'}),
              200,
            );
          }
          if (request.url.path.contains('/generate-illustrations')) {
            generateCallCount += 1;
            // First (and only) call returns the quota-exceeded payload.
            return http.Response(
              jsonEncode({
                'illustrations': [],
                'count': 0,
                'code': 'ILLUSTRATION_QUOTA_EXCEEDED',
                'quota_used': 10,
                'quota_limit': 10,
                'message': "You've used all your free illustrations this "
                    'month. Upgrade for more, or wait until next month.',
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });
        ApiServiceManager.setTestClient(mockClient);

        final prefetcher = PerPageIllustrationPrefetcher(
          storyId: 'story-quota-test',
          pageTexts: const [
            'Page one text.',
            'Page two text.',
            'Page three text.',
          ],
          characterName: 'Lila',
          age: 8,
          allowServerKey: true,
          client: mockClient,
        );

        await prefetcher.initialize();

        // Give the serial drain time to run through every page. The
        // prefetcher has a 250ms throttle between fetches, but after the
        // cap hits subsequent pages should short-circuit without a fetch.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (prefetcher.hasQuotaExceeded &&
              prefetcher
                      .stateOf(2)
                      .value
                      .status ==
                  PageIllustrationStatus.quotaExceeded) {
            break;
          }
        }

        expect(prefetcher.hasQuotaExceeded, isTrue,
            reason: 'quota flag should flip after first capped response');
        expect(generateCallCount, 1,
            reason: 'only the first page should hit the network — '
                'subsequent pages must short-circuit locally');
        for (var i = 0; i < 3; i++) {
          expect(
            prefetcher.stateOf(i).value.status,
            PageIllustrationStatus.quotaExceeded,
            reason: 'page $i should be marked quotaExceeded',
          );
        }
        expect(prefetcher.quotaUsed, 10);
        expect(prefetcher.quotaLimit, 10);

        prefetcher.dispose();
      },
    );

    test('successful response leaves quotaExceeded false', () async {
      // 1x1 transparent PNG, base64-encoded — smallest valid image data.
      const tinyPngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/anonymous')) {
          return http.Response(
            jsonEncode({'token': 'tok', 'user_id': 'u1'}),
            200,
          );
        }
        if (request.url.path.contains('/generate-illustrations')) {
          return http.Response(
            jsonEncode({
              'illustrations': [
                {'image_data': tinyPngBase64},
              ],
              'count': 1,
              'provider': 'flux_schnell',
              'quota_used': 3,
              'quota_limit': 10,
              'used_user_key': false,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      ApiServiceManager.setTestClient(mockClient);

      final prefetcher = PerPageIllustrationPrefetcher(
        storyId: 'story-success-test',
        pageTexts: const ['Page one text.'],
        characterName: 'Mo',
        age: 8,
        allowServerKey: true,
        client: mockClient,
      );

      await prefetcher.initialize();

      // Wait for the single fetch to settle.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (prefetcher.stateOf(0).value.status ==
            PageIllustrationStatus.ready) {
          break;
        }
      }

      expect(prefetcher.hasQuotaExceeded, isFalse);
      expect(prefetcher.stateOf(0).value.status,
          PageIllustrationStatus.ready);
      expect(prefetcher.quotaUsed, 3);
      expect(prefetcher.quotaLimit, 10);

      prefetcher.dispose();
    });
  });
}
