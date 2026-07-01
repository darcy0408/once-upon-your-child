// Standalone, fire-and-forget funnel-telemetry client (MT-249).
//
// Posts paywall/upsell funnel events to the backend `/analytics/event` sink so
// the freemium conversion funnel can be measured server-side. Every method is
// best-effort: any failure (network, auth, timeout, non-2xx) is swallowed and
// never surfaces to the UI. Analytics must never block or break a user flow.
//
// This is deliberately a small self-contained helper with its own http POST —
// it does NOT add a method to ApiServiceManager (only reads its auth headers).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import 'api_service_manager.dart';

class AnalyticsService {
  AnalyticsService._();

  /// Fire the `paywall_viewed` event when the paywall / upsell is shown.
  static void paywallViewed({String? requiredFeature}) {
    _fire(
      'paywall_viewed',
      metadata: {
        if (requiredFeature != null) 'required_feature': requiredFeature,
      },
    );
  }

  /// Record an allowlisted funnel event. Fire-and-forget: returns immediately
  /// and the network call runs unawaited; all errors are swallowed.
  static void track(String eventName, {Map<String, dynamic>? metadata}) {
    _fire(eventName, metadata: metadata);
  }

  static void _fire(String eventName, {Map<String, dynamic>? metadata}) {
    // Intentionally not awaited — the caller must never be blocked by telemetry.
    unawaited(_send(eventName, metadata));
  }

  static Future<void> _send(
    String eventName,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      final url = Uri.parse('${Environment.backendUrl}/analytics/event');
      // authHeaders() supplies Content-Type + (when available) a bearer token
      // so the backend can resolve tier/user_id server-side. Auth is optional
      // on the endpoint, so a missing token is fine.
      final headers = await ApiServiceManager.authHeaders();
      await http
          .post(
            url,
            headers: headers,
            body: json.encode({
              'event_name': eventName,
              if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnalyticsService error (non-critical): $e');
      }
    }
  }
}
