class UsageStats {
  final int storiesThisMonth;
  final int storiesLimit;
  final int charactersCount;
  final int charactersLimit;
  final DateTime periodStart;
  final DateTime periodEnd;

  UsageStats({
    required this.storiesThisMonth,
    required this.storiesLimit,
    required this.charactersCount,
    required this.charactersLimit,
    required this.periodStart,
    required this.periodEnd,
  });

  /// True once the server-side monthly story cap is used up. A limit of 0
  /// means the tier is unlimited.
  bool get monthlyStoryLimitReached =>
      storiesLimit > 0 && storiesThisMonth >= storiesLimit;

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      storiesThisMonth: json['stories_this_month'],
      storiesLimit: json['stories_limit'],
      charactersCount: json['characters_count'],
      charactersLimit: json['characters_limit'],
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
    );
  }
}
