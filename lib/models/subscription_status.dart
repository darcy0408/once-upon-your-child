import 'package:story_weaver_app/subscription_models.dart' show SubscriptionTier;

export 'package:story_weaver_app/subscription_models.dart' show SubscriptionTier;

class SubscriptionStatus {
  final String userId;
  final SubscriptionTier tier;
  final String status; // "active", "canceled", "past_due", "trialing"
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  bool get isActive => status == 'active' || status == 'trialing';

  SubscriptionStatus({
    required this.userId,
    required this.tier,
    required this.status,
    this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      userId: (json['user_id'] ?? 'unknown') as String,
      tier: _tierFromString(json['tier']),
      status: json['status'],
      currentPeriodEnd: _parsePeriodEnd(json['current_period_end']),
      cancelAtPeriodEnd:
          json['cancel_at_period_end'] ?? json['cancelAtPeriodEnd'] ?? false,
    );
  }

  factory SubscriptionStatus.fromBackendPayload(
    String userId,
    Map<String, dynamic> payload,
  ) {
    final normalized = Map<String, dynamic>.from(payload);
    normalized['user_id'] = normalized['user_id'] ?? userId;
    normalized['tier'] = normalized['tier'] ?? 'free';
    normalized['status'] = normalized['status'] ?? 'inactive';
    normalized['cancel_at_period_end'] =
        normalized['cancel_at_period_end'] ??
            normalized['cancelAtPeriodEnd'] ??
            false;
    return SubscriptionStatus.fromJson(normalized);
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'tier': _tierToString(tier),
      'status': status,
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'cancel_at_period_end': cancelAtPeriodEnd,
    };
  }

  static SubscriptionTier _tierFromString(String? tier) {
    switch (tier) {
      case 'premium':
        return SubscriptionTier.premium;
      case 'family':
        return SubscriptionTier.family;
      default:
        return SubscriptionTier.free;
    }
  }

  static String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.premium:
        return 'premium';
      case SubscriptionTier.family:
        return 'family';
      default:
        return 'free';
    }
  }

  static DateTime? _parsePeriodEnd(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value * 1000,
        isUtc: true,
      );
    }

    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      );
    }

    return null;
  }
}
