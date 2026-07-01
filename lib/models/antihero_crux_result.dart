/// Models for the Adolescent (15-17) interactive "Crux Choice" antihero flow
/// (MT-258, design: `docs/ADOLESCENT_CRUX_CHOICE_DESIGN.md`).
///
/// The backend generates the chapter in two calls:
///   1. `POST /generate-antihero-crux`  -> Beats 1-4 + the two-sided choice,
///      returning `{status:"awaiting_choice", continuation_token, story:{...}}`.
///   2. `POST /generate-antihero-resolution` -> Beats 5-7 conditioned on the
///      chosen option, returning `{status:"complete", story:{...}}` (parsed by
///      the existing [StoryGenerationResult.fromBackend]).
///
/// [AntiheroCruxResult] is the client view of the part-1 response; the reader
/// screen renders Beats 1-4, pauses on the two [CruxChoice] cards, then calls
/// the resolution endpoint with the chosen [CruxChoice.id].
library;

/// One of the two genuinely two-sided options offered at the moral apex.
class CruxChoice {
  /// Stable identifier the backend keyed the cached choices by (e.g. "a"/"b").
  /// Sent back verbatim to `/generate-antihero-resolution` as `choice_id`.
  final String id;

  /// The in-voice option text shown on the noir choice card.
  final String text;

  const CruxChoice({required this.id, required this.text});

  factory CruxChoice.fromJson(Map<String, dynamic> json) => CruxChoice(
        id: (json['id'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// The client view of the part-1 (`/generate-antihero-crux`) response: the
/// setup beats plus the pending choice. The [continuationToken] is opaque and
/// is handed straight back to the resolution endpoint.
class AntiheroCruxResult {
  /// Opaque token identifying the cached part-1 context on the backend
  /// (~30-min TTL). Required to fetch the resolution.
  final String continuationToken;

  /// The chapter title chosen in part 1 (persisted with the assembled story).
  final String? title;

  /// Beats 1-4 — the setup pages rendered before the choice.
  final List<String> pages;

  /// The one-line framing of the moral crux, shown above the choice cards.
  final String crux;

  /// The two two-sided options (typically ids "a" and "b").
  final List<CruxChoice> choices;

  const AntiheroCruxResult({
    required this.continuationToken,
    required this.pages,
    required this.crux,
    required this.choices,
    this.title,
  });

  factory AntiheroCruxResult.fromBackend(Map<String, dynamic> json) {
    final dynamic rawStory = json['story'];
    final Map<String, dynamic> story =
        rawStory is Map<String, dynamic> ? rawStory : const {};

    final pages =
        (story['pages'] as List?)?.whereType<String>().toList() ?? const [];

    final rawChoices = (story['choices'] as List?) ?? const [];
    final choices = rawChoices
        .whereType<Map>()
        .map((c) => CruxChoice.fromJson(Map<String, dynamic>.from(c)))
        .where((c) => c.id.isNotEmpty && c.text.isNotEmpty)
        .toList();

    return AntiheroCruxResult(
      continuationToken: (json['continuation_token'] ?? '').toString(),
      title: (story['title'] as String?)?.trim().isNotEmpty == true
          ? (story['title'] as String).trim()
          : null,
      pages: pages,
      crux: (story['crux'] ?? '').toString(),
      choices: choices,
    );
  }

  /// A crux payload is only playable when the backend returned a usable token
  /// and at least two choices to pick between.
  bool get isValid =>
      continuationToken.isNotEmpty && pages.isNotEmpty && choices.length >= 2;
}
