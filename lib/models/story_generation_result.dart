class StoryGenerationResult {
  final String storyText;
  final String? title;
  final String? wisdomGem;
  final bool usedUserKey;
  final List<Map<String, dynamic>> illustrations;
  final bool asyncIllustrations; // True if illustrations will be loaded asynchronously
  final List<String> pages;
  final List<String> adventureSteps;

  /// Superhero Mode metadata returned by the backend.
  /// Shape: `{villain_id, problem_id, hero_power}`. Null when theme != 'superhero'.
  /// Callers should feed `villain_id`/`problem_id` into the hero-profile
  /// recents lists so the backend can avoid repeats on the next story.
  final Map<String, dynamic>? superheroMeta;

  const StoryGenerationResult({
    required this.storyText,
    this.title,
    this.wisdomGem,
    this.usedUserKey = false,
    this.illustrations = const [],
    this.asyncIllustrations = false,
    this.pages = const [],
    this.adventureSteps = const [],
    this.superheroMeta,
  });

  factory StoryGenerationResult.fromBackend(Map<String, dynamic> json) {
    // Backend nested 'story' object
    final dynamic rawStory = json['story'];
    final Map<String, dynamic> storyData = (rawStory is Map<String, dynamic>) ? rawStory : {};
    
    final rawIllustrations = (storyData['illustrations'] as List? ?? json['illustrations'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const [];

    final storyText = (storyData['story_text'] ?? 
                      json['story_text'] ?? 
                      (rawStory is String ? rawStory : '') ?? 
                      '') as String;
    
    final rawPages = (storyData['pages'] as List?)?.whereType<String>().toList() ?? 
                     (json['pages'] as List?)?.whereType<String>().toList() ?? [];
                     
    final rawSteps = (storyData['adventure_steps'] as List?)?.whereType<String>().toList() ?? 
                     (json['adventure_steps'] as List?)?.whereType<String>().toList() ?? [];

    final dynamic rawMeta = storyData['superhero_meta'] ?? json['superhero_meta'];
    final Map<String, dynamic>? superheroMeta =
        rawMeta is Map<String, dynamic> ? rawMeta : null;

    return StoryGenerationResult(
      storyText: storyText,
      title: (storyData['title'] ?? json['title']) as String?,
      wisdomGem: (storyData['wisdom_gem'] ?? json['wisdom_gem']) as String?,
      usedUserKey: json['used_user_key'] as bool? ?? false,
      illustrations: rawIllustrations,
      asyncIllustrations: json['async_illustrations'] as bool? ?? false,
      pages: rawPages,
      adventureSteps: rawSteps,
      superheroMeta: superheroMeta,
    );
  }
}
