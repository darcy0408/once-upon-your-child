// lib/services/usage_stats_service.dart
// Reads the server's story usage for the signed-in user.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../models/usage_stats.dart';
import 'api_service_manager.dart';

class UsageStatsService {
  UsageStatsService._();

  /// Best-effort read of `/api/user/<id>/usage-stats`. Returns null on any
  /// failure: the count only drives UI hints, and the backend rejects an
  /// over-limit generation regardless of what the client believes.
  static Future<UsageStats?> fetch(String userId, {http.Client? client}) async {
    if (userId.isEmpty) return null;
    final httpClient = client ?? http.Client();
    try {
      final headers = await ApiServiceManager.authHeaders();
      final response = await httpClient
          .get(
            Uri.parse('${Environment.backendUrl}/api/user/$userId/usage-stats'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return UsageStats.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('UsageStatsService.fetch failed (best-effort): $e');
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
