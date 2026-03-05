import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/subscription_models.dart';
import 'package:story_weaver_app/subscription_service.dart';

void main() {
  const subscriptionKey = 'user_subscription';
  const usageKey = 'usage_stats';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Free tier blocks story creation after daily limit', () async {
    final service = SubscriptionService();
    final prefs = await SharedPreferences.getInstance();

    final freeSubscription = UserSubscription(tier: SubscriptionTier.free);
    await prefs.setString(subscriptionKey, jsonEncode(freeSubscription.toJson()));

    final limits = freeSubscription.limits;
    await prefs.setString(
      usageKey,
      jsonEncode({
        'stories_created_today': limits.maxStoriesPerDay,
        'stories_created_this_month': limits.maxStoriesPerMonth,
        'last_story_date': DateTime.now().toIso8601String(),
        'last_reset_date': DateTime.now().toIso8601String(),
      }),
    );

    final canCreate = await service.canCreateStory();
    expect(canCreate, isFalse);
  });

  test('Recording a story increments usage stats', () async {
    final service = SubscriptionService();
    final prefs = await SharedPreferences.getInstance();

    final freeSubscription = UserSubscription(tier: SubscriptionTier.free);
    await prefs.setString(subscriptionKey, jsonEncode(freeSubscription.toJson()));

    await service.recordStoryCreation();
    await service.recordStoryCreation();

    final raw = prefs.getString(usageKey);
    expect(raw, isNotNull);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['stories_created_today'], 2);
  });
}
