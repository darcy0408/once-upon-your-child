import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/services/subscription_service.dart';
import 'package:story_weaver_app/services/subscription_sync_service.dart';
import 'package:story_weaver_app/subscription_models.dart';

/// A stub SubscriptionSyncService that lets tests pin the current
/// subscription tier without doing any network or pref I/O.
class _FakeSubscriptionSyncService implements SubscriptionSyncService {
  _FakeSubscriptionSyncService(this._status);

  final SubscriptionStatus _status;
  final StreamController<SubscriptionStatus> _controller =
      StreamController<SubscriptionStatus>.broadcast();

  @override
  SubscriptionStatus? get currentStatus => _status;

  @override
  Stream<SubscriptionStatus> get subscriptionStream => _controller.stream;

  @override
  Future<void> initialize({String? userId}) async {}

  @override
  Future<void> syncSubscriptionStatus({String? userId}) async {}

  @override
  void dispose() {
    _controller.close();
  }

  // The members below are unused by SubscriptionService — implement them as
  // no-ops / dynamic so this fake compiles against any future internal
  // additions without forcing the test to track them.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const usageKey = 'usage_stats';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Free tier blocks story creation after daily limit', () async {
    final freeStatus = SubscriptionStatus(
      userId: 'test_user',
      tier: SubscriptionTier.free,
      status: 'inactive',
      cancelAtPeriodEnd: false,
    );
    final service = SubscriptionService(
      syncService: _FakeSubscriptionSyncService(freeStatus),
    );

    final freeLimits = TierLimits.forTier(SubscriptionTier.free);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      usageKey,
      jsonEncode({
        'stories_created_today': freeLimits.maxStoriesPerDay,
        'stories_created_this_month': freeLimits.maxStoriesPerMonth,
        'last_story_date': DateTime.now().toIso8601String(),
        'last_reset_date': DateTime.now().toIso8601String(),
      }),
    );

    final canCreate = await service.canCreateStory();
    expect(canCreate, isFalse);
  });

  test('Recording a story increments usage stats', () async {
    final freeStatus = SubscriptionStatus(
      userId: 'test_user',
      tier: SubscriptionTier.free,
      status: 'inactive',
      cancelAtPeriodEnd: false,
    );
    final service = SubscriptionService(
      syncService: _FakeSubscriptionSyncService(freeStatus),
    );

    await service.recordStoryCreation();
    await service.recordStoryCreation();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(usageKey);
    expect(raw, isNotNull);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['stories_created_today'], 2);
  });
}
