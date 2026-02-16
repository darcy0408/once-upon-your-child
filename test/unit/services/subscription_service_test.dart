import 'dart:collection';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/services/subscription_sync_service.dart';
import 'package:story_weaver_app/services/stripe_service.dart';
import 'package:story_weaver_app/subscription_models.dart';

class _FakeStripeService extends StripeService {
  _FakeStripeService({required List<Object> results})
      : _results = Queue<Object>.from(results),
        super();

  final Queue<Object> _results;
  final List<String> requestedUserIds = <String>[];

  @override
  Future<Map<String, dynamic>> getSubscriptionStatus(String userId) async {
    requestedUserIds.add(userId);
    if (_results.isEmpty) {
      throw Exception('No fake response configured');
    }

    final next = _results.removeFirst();
    if (next is Exception) {
      throw next;
    }
    if (next is Error) {
      throw next;
    }
    return Map<String, dynamic>.from(next as Map);
  }
}

Map<String, dynamic> _freeStatusFixture() {
  return <String, dynamic>{
    'tier': 'free',
    'status': 'active',
    'story_limit': 3,
    'stories_used': 2,
  };
}

Map<String, dynamic> _premiumStatusFixture() {
  return <String, dynamic>{
    'tier': 'premium',
    'status': 'active',
    'story_limit': -1,
    'stories_used': 42,
  };
}

void main() {
  SubscriptionSyncService? service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    service?.dispose();
    service = null;
    SubscriptionSyncService.resetInstance();
  });

  group('SubscriptionSyncService', () {
    group('State Management', () {
      test('test_initial_state_is_free_tier', () async {
        final singletonA = SubscriptionSyncService();
        final singletonB = SubscriptionSyncService();
        expect(identical(singletonA, singletonB), isTrue);
        expect(
            singletonA.subscriptionStream, isA<Stream<SubscriptionStatus>>());
        singletonA.dispose();
        SubscriptionSyncService.resetInstance();

        final fakeStripe =
            _FakeStripeService(results: <Object>[_freeStatusFixture()]);
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-free');

        expect(service!.currentStatus, isNotNull);
        expect(service!.currentStatus!.tier, SubscriptionTier.free);
        expect(service!.currentStatus!.status, 'active');
      });

      test('test_premium_state_loading', () async {
        final defaultForTest = SubscriptionSyncService.forTest();
        expect(defaultForTest.currentStatus, isNull);
        defaultForTest.dispose();

        final fakeStripe = _FakeStripeService(
          results: <Object>[_premiumStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-premium');

        expect(service!.currentStatus, isNotNull);
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
        expect(service!.currentStatus!.isActive, isTrue);
      });

      test('test_state_transition_free_to_premium', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            _freeStatusFixture(),
            _premiumStatusFixture(),
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-123');
        expect(service!.currentStatus!.tier, SubscriptionTier.free);

        await service!.syncSubscriptionStatus(userId: 'user-123');
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
      });

      test('test_state_transition_premium_to_free', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            _premiumStatusFixture(),
            _freeStatusFixture(),
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-123');
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);

        await service!.syncSubscriptionStatus(userId: 'user-123');
        expect(service!.currentStatus!.tier, SubscriptionTier.free);
      });
    });

    group('Tier Detection', () {
      test('test_free_tier_detection', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            <String, Object>{
              'tier': 'unknown-tier',
              'status': 'active',
            },
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-123');

        expect(service!.currentStatus!.tier, SubscriptionTier.free);
      });

      test('test_premium_tier_detection', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            <String, Object>{
              'tier': 'premium',
              'status': 'active',
            },
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-123');

        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
      });

      test('test_expired_subscription_handling', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            <String, Object>{
              'tier': 'premium',
              'status': 'past_due',
              'current_period_end': DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            },
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-123');

        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
        expect(service!.currentStatus!.isActive, isFalse);
        expect(service!.currentStatus!.status, 'past_due');
      });
    });

    group('Usage Tracking', () {
      test('test_story_count_increment', () {
        final usage = UsageStats(
          storiesCreatedToday: 0,
          storiesCreatedThisMonth: 0,
        );

        final incremented = usage.incrementStory();
        expect(incremented.storiesCreatedToday, 1);
        expect(incremented.storiesCreatedThisMonth, 1);
      });

      test('test_usage_limit_enforcement_free_tier', () async {
        final fakeStripe =
            _FakeStripeService(results: <Object>[_freeStatusFixture()]);
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-free');

        final freeLimitFromFixture = _freeStatusFixture()['story_limit'] as int;
        expect(freeLimitFromFixture, 3);
        expect(service!.currentStatus!.tier, SubscriptionTier.free);
        expect(TierLimits.forTier(SubscriptionTier.free).unlimitedStories,
            isFalse);
      });

      test('test_unlimited_usage_premium_tier', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[_premiumStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-premium');

        final premiumLimitFromFixture =
            _premiumStatusFixture()['story_limit'] as int;
        expect(premiumLimitFromFixture, -1);
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
      });
    });

    group('API Synchronization', () {
      test('test_sync_caches_subscription_payload_for_offline_use', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[_premiumStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-cache-write');

        final prefs = await SharedPreferences.getInstance();
        final cachedRaw = prefs.getString('subscription_status');
        expect(cachedRaw, isNotNull);

        final cached = jsonDecode(cachedRaw!) as Map<String, dynamic>;
        expect(cached['user_id'], 'user-cache-write');
        expect(cached['tier'], 'premium');
      });

      test('test_sync_uses_explicit_user_id_when_provided', () async {
        SharedPreferences.setMockInitialValues(
          <String, Object>{'story_weaver_user_id': 'stored-user'},
        );

        final fakeStripe = _FakeStripeService(
          results: <Object>[_freeStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'override-user');

        expect(fakeStripe.requestedUserIds, <String>['override-user']);
      });

      test('test_initialize_hydrates_cache_before_network_refresh', () async {
        final cached = SubscriptionStatus(
          userId: 'user-cache',
          tier: SubscriptionTier.free,
          status: 'active',
          currentPeriodEnd: null,
          cancelAtPeriodEnd: false,
        );
        SharedPreferences.setMockInitialValues(
          <String, Object>{'subscription_status': jsonEncode(cached.toJson())},
        );

        final fakeStripe = _FakeStripeService(
          results: <Object>[_premiumStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        final emitted = <SubscriptionStatus>[];
        final sub = service!.subscriptionStream.listen(emitted.add);

        await service!.initialize(userId: 'user-cache');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(emitted.length, 2);
        expect(emitted.first.tier, SubscriptionTier.free);
        expect(emitted.last.tier, SubscriptionTier.premium);
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
      });

      test('test_sync_from_backend_api', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[_premiumStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        SharedPreferences.setMockInitialValues(
          <String, Object>{'story_weaver_user_id': 'user-api'},
        );
        await service!.syncSubscriptionStatus();

        expect(fakeStripe.requestedUserIds, <String>['user-api']);
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
      });

      test('test_successful_sync_overwrites_cached_status', () async {
        final cached = SubscriptionStatus(
          userId: 'user-cache',
          tier: SubscriptionTier.free,
          status: 'active',
          currentPeriodEnd: null,
          cancelAtPeriodEnd: false,
        );
        SharedPreferences.setMockInitialValues(
          <String, Object>{'subscription_status': jsonEncode(cached.toJson())},
        );
        final fakeStripe = _FakeStripeService(
          results: <Object>[_premiumStatusFixture()],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-cache');

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('subscription_status');
        expect(raw, isNotNull);
        final decoded = jsonDecode(raw!) as Map<String, dynamic>;
        expect(decoded['tier'], 'premium');
        expect(service!.currentStatus!.tier, SubscriptionTier.premium);
      });

      test('test_stream_emits_for_repeated_identical_payloads', () async {
        final payload = _premiumStatusFixture();
        final fakeStripe = _FakeStripeService(
          results: <Object>[payload, payload],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        final emitted = <SubscriptionStatus>[];
        final sub = service!.subscriptionStream.listen(emitted.add);

        await service!.syncSubscriptionStatus(userId: 'user-repeat');
        await service!.syncSubscriptionStatus(userId: 'user-repeat');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(emitted.length, 2);
        expect(emitted[0].tier, SubscriptionTier.premium);
        expect(emitted[1].tier, SubscriptionTier.premium);
      });

      test('test_sync_error_handling', () {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            ArgumentError('network down'),
            ArgumentError('network down'),
            ArgumentError('network down'),
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        fakeAsync((async) {
          var completed = false;
          service!
              .syncSubscriptionStatus(userId: 'user-err')
              .then((_) => completed = true);

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 8));
          async.flushMicrotasks();

          expect(completed, isTrue);
          expect(service!.currentStatus, isNull);
        });
      });

      test('test_offline_mode', () async {
        final cached = SubscriptionStatus(
          userId: 'cached-user',
          tier: SubscriptionTier.free,
          status: 'active',
          currentPeriodEnd: null,
          cancelAtPeriodEnd: false,
        );
        SharedPreferences.setMockInitialValues(
          <String, Object>{'subscription_status': jsonEncode(cached.toJson())},
        );

        final fakeStripe = _FakeStripeService(
          results: <Object>[
            Exception('offline'),
            Exception('offline'),
            Exception('offline'),
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        fakeAsync((async) {
          var completed = false;
          service!
              .initialize(userId: 'cached-user')
              .then((_) => completed = true);

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 8));
          async.flushMicrotasks();

          expect(completed, isTrue);
          expect(service!.currentStatus, isNotNull);
          expect(service!.currentStatus!.tier, SubscriptionTier.free);
        });
      });
    });

    group('Edge Cases', () {
      test('test_null_subscription_data', () async {
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            <String, dynamic>{
              'tier': '',
              'status': '',
              'current_period_end': null,
            },
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        await service!.syncSubscriptionStatus(userId: 'user-null');

        expect(service!.currentStatus, isNotNull);
        expect(service!.currentStatus!.tier, SubscriptionTier.free);
      });

      test('test_malformed_api_responses', () {
        SharedPreferences.setMockInitialValues(
          <String, Object>{'subscription_status': '{not-json'},
        );
        final fakeStripe = _FakeStripeService(
          results: <Object>[
            Exception('bad payload'),
            Exception('bad payload'),
            Exception('bad payload'),
          ],
        );
        service = SubscriptionSyncService.forTest(stripeService: fakeStripe);

        fakeAsync((async) {
          var completed = false;
          service!
              .initialize(userId: 'user-malformed')
              .then((_) => completed = true);

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 8));
          async.flushMicrotasks();

          expect(completed, isTrue);
          expect(service!.currentStatus, isNull);
        });
      });
    });
  });
}
