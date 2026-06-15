/// PERF-01 cancellation polish: thrown by [ApiServiceManager.generateStory]'s
/// poll loop when the backend reports the in-flight task was cancelled
/// (the `/task-status` envelope surfaces `status: "complete"` with an inner
/// `result.status == "cancelled"` and no story body).
///
/// This is a *signal*, not an error: a user-initiated cancel (Cancel button or
/// navigating away mid-generation) must NOT pop an error card or navigate to a
/// story. Callers catch this type first and treat it as a silent no-op —
/// leaving the screen in whatever state the cancel handler already set.
class StoryGenerationCancelled implements Exception {
  const StoryGenerationCancelled();

  @override
  String toString() => 'StoryGenerationCancelled: story generation was cancelled';
}

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

  /// Story Notes (MT-254): the parent-selected focus this story was guided
  /// toward (a Big Feelings trigger value, e.g. `'a limit is set'`). Null when
  /// the story carried no hidden parent context — the client then offers no
  /// "Why this story? 💛" disclosure.
  final String? practiced;

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
    this.practiced,
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

    final dynamic rawPracticed = storyData['practiced'] ?? json['practiced'];
    final String? practiced =
        (rawPracticed is String && rawPracticed.trim().isNotEmpty)
            ? rawPracticed.trim()
            : null;

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
      practiced: practiced,
    );
  }
}
