import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_identity_service.dart';

class UsageStats {
  final int storiesCreated;
  final int storiesRemaining;
  final bool isSubscribed;
  final String tier;

  UsageStats({
    required this.storiesCreated,
    required this.storiesRemaining,
    required this.isSubscribed,
    required this.tier,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      storiesCreated: json['stories_created'] ?? 0,
      storiesRemaining: json['stories_remaining'] ?? 3,
      isSubscribed: json['is_subscribed'] ?? false,
      tier: json['tier'] ?? 'free',
    );
  }
}

class UsageStatsService {
  static const String _baseUrl = 'http://127.0.0.1:5000';

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
          storiesCreated: 0,
          storiesRemaining: 3,
          isSubscribed: false,
          tier: 'free',
        );
      }
    } catch (e) {
      print('Error fetching usage stats: $e');
      // Return default stats on error
      return UsageStats(
        storiesCreated: 0,
        storiesRemaining: 3,
        isSubscribed: false,
        tier: 'free',
      );
    }
  }

  Future<bool> canCreateStory() async {
    try {
      final stats = await getUsageStats();
      return stats.isSubscribed || stats.storiesRemaining > 0;
    } catch (e) {
      print('Error checking if can create story: $e');
      // Default to true to not block users
      return true;
    }
  }

  void dispose() {
    // No resources to dispose currently
  }
}
