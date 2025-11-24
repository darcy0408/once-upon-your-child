class StoryGenerationResult {
  final String storyText;
  final String? title;
  final String? wisdomGem;
  final bool usedUserKey;
  final List<Map<String, dynamic>> illustrations;

  const StoryGenerationResult({
    required this.storyText,
    this.title,
    this.wisdomGem,
    this.usedUserKey = false,
    this.illustrations = const [],
  });

  factory StoryGenerationResult.fromBackend(Map<String, dynamic> json) {
    final rawIllustrations = (json['illustrations'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];

    final story = (json['story'] ?? json['story_text'] ?? '') as String;

    return StoryGenerationResult(
      storyText: story,
      title: json['title'] as String?,
      wisdomGem: json['wisdom_gem'] as String?,
      usedUserKey: json['used_user_key'] as bool? ?? false,
      illustrations: rawIllustrations,
    );
  }
}
