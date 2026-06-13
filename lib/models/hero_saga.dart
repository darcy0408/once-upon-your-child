// Client-side continuity memory for a returnable "Hero Saga". Serves BOTH the
// Creator band (ages 13-14) and the Adolescent antihero band (ages 15-17).
//
// The backend superhero prompt EMITS a `saga_state` after every Issue (nemesis,
// status, what changed, the dangling hook, plus allies + defining_choice). This
// model is the client memory that ACCUMULATES that state across Issues and
// feeds it back as `prior_saga` so the next Issue has real continuity — the
// "Previously in this saga…" beat. Two halves of one loop:
//   backend prompt_service._build_superhero_prompt_creator  (emit + consume)
//   this model + HeroSagaStore                              (persist + replay)
// Tracked under MT-235 Phase 2 (the returnable saga).
//
// Persisted per child by [HeroSagaStore] (SharedPreferences, mirroring
// hero_profile_provider's one-JSON-key-per-character approach). Plain immutable
// DTO — intentionally no Isar (the saga is a SharedPreferences concern, same as
// HeroProfile today).

/// One persisted Issue in the saga's per-issue history — the data the
/// "Saga Record" screen lists for a past Issue (its number, title, nemesis +
/// status, the cost it carried, and the defining choice made). Immutable;
/// every field except [issueNumber] is nullable so a sparse saga_state still
/// records a chapter.
class HeroSagaChapter {
  const HeroSagaChapter({
    required this.issueNumber,
    this.title,
    this.nemesis,
    this.nemesisStatus,
    this.cost,
    this.choice,
  });

  /// The Issue number this chapter records (1-based).
  final int issueNumber;

  /// The generated story's title for this Issue, if one was captured.
  final String? title;

  /// Nemesis name from this Issue's saga_state.
  final String? nemesis;

  /// Nemesis status from this Issue's saga_state.
  final String? nemesisStatus;

  /// What the edge/choice COST the hero this Issue (saga_state what_it_cost).
  final String? cost;

  /// The defining choice the hero made this Issue (saga_state defining_choice).
  final String? choice;

  Map<String, dynamic> toJson() => {
        'issue_number': issueNumber,
        'title': title,
        'nemesis': nemesis,
        'nemesis_status': nemesisStatus,
        'cost': cost,
        'choice': choice,
      };

  /// Rebuilds a chapter from stored JSON. Type-guarded and tolerant of missing
  /// keys (a partial blob yields nulls rather than throwing).
  factory HeroSagaChapter.fromJson(Map<String, dynamic> map) {
    String? str(dynamic v) => v is String ? v : null;
    final rawIssue = map['issue_number'];
    return HeroSagaChapter(
      issueNumber: rawIssue is num ? rawIssue.toInt() : 0,
      title: str(map['title']),
      nemesis: str(map['nemesis']),
      nemesisStatus: str(map['nemesis_status']),
      cost: str(map['cost']),
      choice: str(map['choice']),
    );
  }
}

/// Immutable per-child Hero Saga continuity (Creator 13-14 + Adolescent 15-17).
class HeroSaga {
  const HeroSaga({
    required this.characterId,
    this.issueNumber = 0,
    this.heroCode,
    this.nemesis,
    this.nemesisStatus,
    this.whatChanged,
    this.whatItCost,
    this.nextHook,
    this.allies = const [],
    this.keyChoices = const [],
    this.chapters = const [],
    this.updatedAt,
  });

  /// FK to the character this saga belongs to.
  final String characterId;

  /// Count of Issues completed. The NEXT Issue is [issueNumber] + 1; a fresh
  /// saga (0) means the upcoming Issue is #1 — a clean origin, no `prior_saga`.
  final int issueNumber;

  /// The hero's personal code (what they refuse to do / what they fight for).
  /// Set when the hero is forged; carried into every Issue as a moral throughline.
  final String? heroCode;

  /// Latest nemesis name, from the most recent Issue's `saga_state`.
  final String? nemesis;

  /// Backend vocabulary: `reconsidered` | `stopped-and-accountable` |
  /// `still-at-large`.
  final String? nemesisStatus;

  /// One-line "what shifted in the city or the hero" from the last Issue.
  final String? whatChanged;

  /// One-line "what the edge/choice COST the hero" from the last Issue — the
  /// consequence ledger, surfaced so the cost carries across chapters.
  final String? whatItCost;

  /// The unresolved thread the last Issue left dangling; the next Issue should
  /// open on it or pay it off.
  final String? nextHook;

  /// Allies established across the saga (deduped, newest last, capped).
  final List<String> allies;

  /// Defining choices the hero has made (deduped, newest last, capped).
  final List<String> keyChoices;

  /// Per-issue history (oldest first, capped at [kSagaChapterCap]) — the source
  /// the "Saga Record" screen lists: each past Issue's number, title, nemesis,
  /// cost, and choice. Old saved sagas predating this field load as `const []`
  /// and simply start accumulating from the next Issue.
  final List<HeroSagaChapter> chapters;

  /// When this saga was last folded forward. Null on a never-saved saga.
  final DateTime? updatedAt;

  /// Cap on the accumulating allies / choices lists, matching the spirit of
  /// hero_profile_provider's `kHeroRecentListCap` — keeps the continuity block
  /// (and the prompt) bounded as a saga runs long.
  static const int kSagaListCap = 8;

  /// Cap on the per-issue [chapters] history — keeps the persisted Saga Record
  /// bounded as a saga runs long (mirrors [kSagaListCap]'s intent, but the
  /// history can afford to be longer than the continuity lists).
  static const int kSagaChapterCap = 30;

  /// True once at least one Issue has been recorded, i.e. there is continuity
  /// to replay into the next Issue.
  bool get hasContinuity => issueNumber > 0;

  HeroSaga copyWith({
    String? characterId,
    int? issueNumber,
    String? heroCode,
    String? nemesis,
    String? nemesisStatus,
    String? whatChanged,
    String? whatItCost,
    String? nextHook,
    List<String>? allies,
    List<String>? keyChoices,
    List<HeroSagaChapter>? chapters,
    DateTime? updatedAt,
  }) {
    return HeroSaga(
      characterId: characterId ?? this.characterId,
      issueNumber: issueNumber ?? this.issueNumber,
      heroCode: heroCode ?? this.heroCode,
      nemesis: nemesis ?? this.nemesis,
      nemesisStatus: nemesisStatus ?? this.nemesisStatus,
      whatChanged: whatChanged ?? this.whatChanged,
      whatItCost: whatItCost ?? this.whatItCost,
      nextHook: nextHook ?? this.nextHook,
      allies: allies ?? this.allies,
      keyChoices: keyChoices ?? this.keyChoices,
      chapters: chapters ?? this.chapters,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Folds a completed Issue's emitted [sagaState] into the saga: bumps the
  /// Issue count and refreshes nemesis / status / what-changed / next-hook from
  /// whatever the prompt returned (blank or missing fields keep their prior
  /// value, so a partial saga_state never erases continuity). Optional
  /// [heroCode] / [newAllies] / [newKeyChoices] let the caller enrich
  /// continuity the prompt doesn't echo back. Returns a new instance.
  ///
  /// The backend saga_state may ALSO carry `allies` (a JSON array of names) and
  /// `defining_choice` (a string); these are auto-captured here and unioned
  /// with the explicit [newAllies] / [newKeyChoices] params (the explicit
  /// params still work for callers who supply continuity out-of-band). All
  /// allies / key-choices remain capped by [kSagaListCap] via [merge].
  HeroSaga recordIssue(
    Map<String, dynamic> sagaState, {
    String? heroCode,
    String? title,
    List<String> newAllies = const [],
    List<String> newKeyChoices = const [],
    DateTime? now,
  }) {
    String? pick(String key, String? fallback) {
      final v = sagaState[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return fallback;
    }

    List<String> merge(List<String> base, List<String> add) {
      final out = List<String>.from(base);
      for (final a in add) {
        final t = a.trim();
        if (t.isEmpty) continue;
        out
          ..remove(t)
          ..add(t);
      }
      if (out.length > kSagaListCap) {
        out.removeRange(0, out.length - kSagaListCap);
      }
      return out;
    }

    final code = (heroCode != null && heroCode.trim().isNotEmpty)
        ? heroCode.trim()
        : this.heroCode;

    // Auto-capture allies the backend echoes in saga_state (a JSON array of
    // names; guard the element type), unioned with any explicit newAllies.
    final rawAllies = sagaState['allies'];
    final emittedAllies =
        rawAllies is List ? rawAllies.whereType<String>().toList() : const <String>[];
    final allAllies = <String>[...newAllies, ...emittedAllies];

    // Auto-capture the Issue's defining_choice into keyChoices when present,
    // unioned with any explicit newKeyChoices.
    final allKeyChoices = <String>[...newKeyChoices];
    final rawChoice = sagaState['defining_choice'];
    if (rawChoice is String && rawChoice.trim().isNotEmpty) {
      allKeyChoices.add(rawChoice.trim());
    }

    final newIssueNumber = issueNumber + 1;

    // Append this Issue to the per-issue history (the Saga Record). Built from
    // the NEW issue number, the optional [title] (trimmed; empty -> null), and
    // the same saga_state fields the continuity block draws from. Capped to the
    // most recent [kSagaChapterCap] entries.
    final trimmedTitle = title?.trim();
    final newChapters = List<HeroSagaChapter>.from(chapters)
      ..add(HeroSagaChapter(
        issueNumber: newIssueNumber,
        title: (trimmedTitle != null && trimmedTitle.isNotEmpty)
            ? trimmedTitle
            : null,
        nemesis: pick('nemesis', null),
        nemesisStatus: pick('nemesis_status', null),
        cost: pick('what_it_cost', null),
        choice: pick('defining_choice', null),
      ));
    if (newChapters.length > kSagaChapterCap) {
      newChapters.removeRange(0, newChapters.length - kSagaChapterCap);
    }

    return copyWith(
      issueNumber: newIssueNumber,
      nemesis: pick('nemesis', nemesis),
      nemesisStatus: pick('nemesis_status', nemesisStatus),
      whatChanged: pick('what_changed', whatChanged),
      whatItCost: pick('what_it_cost', whatItCost),
      nextHook: pick('next_hook', nextHook),
      heroCode: code,
      allies: merge(allies, allAllies),
      keyChoices: merge(keyChoices, allKeyChoices),
      chapters: newChapters,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// The payload sent to the backend as `prior_saga` when generating the NEXT
  /// Issue. Returns null when there is no continuity yet (Issue #1 → a clean
  /// origin), so callers can omit it from the request. Keys match exactly the
  /// set recognised by `_build_superhero_prompt_creator`; `issue_number` is the
  /// upcoming Issue (completed + 1).
  Map<String, dynamic>? toPriorSaga() {
    if (!hasContinuity) return null;
    return {
      'issue_number': issueNumber + 1,
      if (nemesis != null) 'nemesis': nemesis,
      if (nemesisStatus != null) 'nemesis_status': nemesisStatus,
      if (whatChanged != null) 'what_changed': whatChanged,
      if (whatItCost != null) 'what_it_cost': whatItCost,
      if (nextHook != null) 'next_hook': nextHook,
      if (heroCode != null) 'hero_code': heroCode,
      if (allies.isNotEmpty) 'allies': allies,
      if (keyChoices.isNotEmpty) 'key_choices': keyChoices,
    };
  }

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'issue_number': issueNumber,
        'hero_code': heroCode,
        'nemesis': nemesis,
        'nemesis_status': nemesisStatus,
        'what_changed': whatChanged,
        'what_it_cost': whatItCost,
        'next_hook': nextHook,
        'allies': allies,
        'key_choices': keyChoices,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  /// Rebuilds a saga from stored JSON. [characterId] is supplied by the caller
  /// (it is the storage key) rather than trusted from the blob.
  factory HeroSaga.fromJson(String characterId, Map<String, dynamic> map) {
    List<String> strList(dynamic v) =>
        v is List ? v.whereType<String>().toList() : const [];
    List<HeroSagaChapter> chapterList(dynamic v) => v is List
        ? v
            .whereType<Map>()
            .map((m) => HeroSagaChapter.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : const [];
    final rawIssue = map['issue_number'];
    return HeroSaga(
      characterId: characterId,
      issueNumber: rawIssue is num ? rawIssue.toInt() : 0,
      heroCode: map['hero_code'] as String?,
      nemesis: map['nemesis'] as String?,
      nemesisStatus: map['nemesis_status'] as String?,
      whatChanged: map['what_changed'] as String?,
      whatItCost: map['what_it_cost'] as String?,
      nextHook: map['next_hook'] as String?,
      allies: strList(map['allies']),
      keyChoices: strList(map['key_choices']),
      chapters: chapterList(map['chapters']),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
    );
  }
}
