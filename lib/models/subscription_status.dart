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
      userId: json['user_id'],
      tier: _tierFromString(json['tier']),
      status: json['status'],
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'])
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] ?? false,
    );
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
}
