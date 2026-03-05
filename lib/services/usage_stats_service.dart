import 'package:story_weaver_app/config/flavor_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usage_stats.dart';
import 'user_identity_service.dart';

import 'package:flutter/foundation.dart';
class UsageStatsService {
  static String get _baseUrl => FlavorConfig.instance.backendUrl;

  Future<UsageStats> getUsageStats() async {
    try {
      final userId = await UserIdentityService.getOrCreateUserId();
      final response = await http.get(
        Uri.parse('$_baseUrl/usage-stats/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UsageStats.fromJson(data);
      } else {
        // Return default stats if backend fails
        return UsageStats(
          storiesThisMonth: 0,
          storiesLimit: 3,
          charactersCount: 0,
          charactersLimit: 5,
          periodStart: DateTime.now(),
          periodEnd: DateTime.now().add(const Duration(days: 30)),
        );
      }
    } catch (e) {
      debugPrint('Error fetching usage stats: $e');
      // Return default stats on error
      return UsageStats(
        storiesThisMonth: 0,
        storiesLimit: 3,
        charactersCount: 0,
        charactersLimit: 5,
        periodStart: DateTime.now(),
        periodEnd: DateTime.now().add(const Duration(days: 30)),
      );
    }
  }

  Future<bool> canCreateStory() async {
    try {
      final stats = await getUsageStats();
      return stats.storiesThisMonth < stats.storiesLimit;
    } catch (e) {
      debugPrint('Error checking if can create story: $e');
      // Default to true to not block users
      return true;
    }
  }

  void dispose() {
    // No resources to dispose currently
  }
}
