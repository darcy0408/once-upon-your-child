import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/subscription_service.dart';

part 'subscription_provider.g.dart';

/// Subscription status state
class SubscriptionState {
  final String status;
  final String tier;
  final int storiesRemaining;
  final int dailyLimit;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.status = 'inactive',
    this.tier = 'free',
    this.storiesRemaining = 0,
    this.dailyLimit = 3,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    String? status,
    String? tier,
    int? storiesRemaining,
    int? dailyLimit,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      tier: tier ?? this.tier,
      storiesRemaining: storiesRemaining ?? this.storiesRemaining,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get canCreateStory => storiesRemaining > 0;
  bool get isFreeTier => tier == 'free';
  bool get isPremium => tier == 'premium';
}

@riverpod
class Subscription extends _$Subscription {
  @override
  SubscriptionState build() {
    _loadSubscriptionStatus();
    return const SubscriptionState(isLoading: true);
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final service = SubscriptionService();
      final data = await service.getSubscriptionStatus();

      state = state.copyWith(
        status: data['status'] as String? ?? 'inactive',
        tier: data['tier'] as String? ?? 'free',
        storiesRemaining: data['stories_remaining'] as int? ?? 3,
        dailyLimit: data['daily_limit'] as int? ?? 3,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadSubscriptionStatus();
  }

  void decrementStoriesRemaining() {
    if (state.storiesRemaining > 0) {
      state = state.copyWith(
        storiesRemaining: state.storiesRemaining - 1,
      );
    }
  }
}
