import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/environment.dart';
import '../models/local/chapter_memory_local.dart';
import '../models/local/chronicle_local.dart';
import 'api_service_manager.dart';
import 'isar_service.dart';

/// Orchestrates the Living Story Chronicle: persistence, history assembly,
/// chapter summarization, and arc compression.
class ChronicleService {
  static const _uuid = Uuid();

  // -------------------------------------------------------------------------
  // ISAR READ HELPERS
  // -------------------------------------------------------------------------

  /// Return all chronicles for a given characterId, newest-last-played first.
  static Future<List<ChronicleLocal>> getChroniclesForCharacter(
      String characterId) async {
    final isar = await IsarService.getInstance();
    return isar.chronicleLocals
        .filter()
        .characterIdEqualTo(characterId)
        .and()
        .isActiveEqualTo(true)
        .sortByLastPlayedAtDesc()
        .findAll();
  }

  /// Return a single chronicle by chronicleId string.
  static Future<ChronicleLocal?> getChronicle(String chronicleId) async {
    final isar = await IsarService.getInstance();
    return isar.chronicleLocals
        .filter()
        .chronicleIdEqualTo(chronicleId)
        .findFirst();
  }

  /// Return all chapter memories for a chronicle, sorted by chapterNumber asc.
  static Future<List<ChapterMemoryLocal>> getChapterMemories(
      String chronicleId) async {
    final isar = await IsarService.getInstance();
    return isar.chapterMemoryLocals
        .filter()
        .chronicleIdEqualTo(chronicleId)
        .sortByChapterNumber()
        .findAll();
  }

  // -------------------------------------------------------------------------
  // CREATE / UPDATE CHRONICLE
  // -------------------------------------------------------------------------

  /// Create a brand-new ChronicleLocal and persist it. Returns the new chronicle.
  static Future<ChronicleLocal> createChronicle({
    required String characterId,
    required String characterName,
    required int characterAge,
    required String title,
    required String genre,
  }) async {
    final isar = await IsarService.getInstance();
    final chronicle = ChronicleLocal()
      ..chronicleId = _uuid.v4()
      ..characterId = characterId
      ..characterName = characterName
      ..characterAge = characterAge
      ..title = title
      ..genre = genre
      ..createdAt = DateTime.now()
      ..lastPlayedAt = DateTime.now()
      ..chapterCount = 0
      ..isActive = true;

    await isar.writeTxn(() async {
      await isar.chronicleLocals.put(chronicle);
    });
    return chronicle;
  }

  /// Update the chronicle after a chapter completes. Merges new world facts,
  /// updates recentMemories (keep last 3), updates characterState,
  /// merges unresolved threads, and bumps chapterCount.
  static Future<void> updateChronicleAfterChapter({
    required String chronicleId,
    required ChapterMemoryLocal memory,
    required Map<String, dynamic> characterStateUpdate,
    required String lastChapterEnding,
    required String choiceMade,
  }) async {
    final isar = await IsarService.getInstance();
    final chronicle = await getChronicle(chronicleId);
    if (chronicle == null) return;

    // Decode existing data
    final existingFacts =
        _decodeStringList(chronicle.worldFactsJson);
    final existingThreads =
        _decodeStringList(chronicle.unresolvedThreadsJson);
    final existingMemories =
        _decodeMemoryList(chronicle.recentMemoriesJson);

    // Merge new world facts (deduplicate)
    final newFacts = _decodeStringList(memory.newWorldFactsJson);
    final mergedFacts = {...existingFacts, ...newFacts}.toList();

    // Merge threads: remove resolved, add new
    final resolvedThreads = _decodeStringList(memory.resolvedThreadsJson);
    final newThreads = _decodeStringList(memory.newThreadsJson);
    final mergedThreads = existingThreads
        .where((t) => !resolvedThreads.contains(t))
        .toList()
      ..addAll(newThreads);

    // Build compact memory entry for recentMemories list
    final memEntry = {
      'chapter_number': memory.chapterNumber,
      'summary_bullets': _decodeStringList(memory.summaryBulletsJson),
      'cliffhanger': memory.cliffhanger ?? '',
    };
    final updatedMemories = [...existingMemories, memEntry];
    // Keep last 3 only
    final trimmedMemories = updatedMemories.length > 3
        ? updatedMemories.sublist(updatedMemories.length - 3)
        : updatedMemories;

    // Build characterState string
    final growth = characterStateUpdate['growth'] as String? ?? '';
    final items =
        (characterStateUpdate['items_gained'] as List?)?.cast<String>() ?? [];
    final relationships =
        (characterStateUpdate['relationships'] as List?)?.cast<String>() ?? [];
    final characterStateMap = {
      'growth': growth,
      'items': items,
      'relationships': relationships,
    };

    await isar.writeTxn(() async {
      chronicle
        ..chapterCount = chronicle.chapterCount + 1
        ..lastPlayedAt = DateTime.now()
        ..lastChoiceMade = choiceMade
        ..lastChapterEnding = lastChapterEnding
        ..worldFactsJson = jsonEncode(mergedFacts)
        ..unresolvedThreadsJson = jsonEncode(mergedThreads)
        ..recentMemoriesJson = jsonEncode(trimmedMemories)
        ..characterStateJson = jsonEncode(characterStateMap);
      await isar.chronicleLocals.put(chronicle);
    });
  }

  /// Append an arc summary to the chronicle's arcSummariesJson list.
  static Future<void> appendArcSummary({
    required String chronicleId,
    required String arcSummary,
  }) async {
    final isar = await IsarService.getInstance();
    final chronicle = await getChronicle(chronicleId);
    if (chronicle == null) return;

    final existing = _decodeStringList(chronicle.arcSummariesJson);
    existing.add(arcSummary);

    await isar.writeTxn(() async {
      chronicle.arcSummariesJson = jsonEncode(existing);
      await isar.chronicleLocals.put(chronicle);
    });
  }

  // -------------------------------------------------------------------------
  // CHAPTER MEMORY PERSISTENCE
  // -------------------------------------------------------------------------

  /// Persist a ChapterMemoryLocal to Isar.
  static Future<void> saveChapterMemory(ChapterMemoryLocal memory) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.chapterMemoryLocals.put(memory);
    });
  }

  // -------------------------------------------------------------------------
  // PAYLOAD BUILDER — used by PickAPathAdventureScreen before /generate-interactive-story
  // -------------------------------------------------------------------------

  /// Assemble the chronicle_context dict to inject into the
  /// POST /generate-interactive-story payload.
  static Future<Map<String, dynamic>?> buildChapterStartPayload(
      String chronicleId) async {
    final chronicle = await getChronicle(chronicleId);
    if (chronicle == null) return null;

    final worldFacts = _decodeStringList(chronicle.worldFactsJson);
    final arcSummaries = _decodeStringList(chronicle.arcSummariesJson);
    final recentMemories = _decodeMemoryList(chronicle.recentMemoriesJson);
    final unresolvedThreads =
        _decodeStringList(chronicle.unresolvedThreadsJson);
    final characterState = _decodeMap(chronicle.characterStateJson);

    final characterStateStr = characterState.isNotEmpty
        ? 'Growth: ${characterState['growth'] ?? ''} | '
            'Items: ${(characterState['items'] as List?)?.join(', ') ?? 'none'} | '
            'Allies: ${(characterState['relationships'] as List?)?.join(', ') ?? 'none'}'
        : 'No state recorded yet.';

    return {
      'chapter_count': chronicle.chapterCount,
      'character_state': characterStateStr,
      'world_facts': worldFacts,
      'arc_summaries': arcSummaries,
      'recent_memories': recentMemories,
      'unresolved_threads': unresolvedThreads,
      'last_chapter_ending': chronicle.lastChapterEnding ?? '',
    };
  }

  // -------------------------------------------------------------------------
  // BACKEND CALLS
  // -------------------------------------------------------------------------

  /// POST /chronicle/summarize-chapter. Returns the parsed JSON map.
  static Future<Map<String, dynamic>> callSummarizeChapter({
    required int chapterNumber,
    required String chapterText,
    required String characterName,
    String? choiceMadeToStart,
    List<String> existingWorldFacts = const [],
    List<String> existingUnresolvedThreads = const [],
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse(Environment.summarizeChapterUrl);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'chapter_number': chapterNumber,
            'chapter_text': chapterText,
            'character_name': characterName,
            if (choiceMadeToStart != null)
              'choice_made_to_start': choiceMadeToStart,
            'existing_world_facts': existingWorldFacts,
            'existing_unresolved_threads': existingUnresolvedThreads,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(
          'summarize-chapter failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// POST /chronicle/compress-arc. Returns {"arc_summary": "..."}.
  static Future<Map<String, dynamic>> callCompressArc({
    required int arcNumber,
    required int chapterStart,
    required int chapterEnd,
    required List<Map<String, dynamic>> chapterSummaries,
    required String characterName,
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse(Environment.compressArcUrl);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'arc_number': arcNumber,
            'chapter_start': chapterStart,
            'chapter_end': chapterEnd,
            'chapter_summaries': chapterSummaries,
            'character_name': characterName,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          'compress-arc failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------------
  // FULL CHAPTER COMPLETION HANDLER
  // Called by PickAPathAdventureScreen after _isCompleted becomes true.
  // -------------------------------------------------------------------------

  /// Runs the full post-chapter pipeline in the background:
  /// 1. Calls /chronicle/summarize-chapter
  /// 2. Saves ChapterMemoryLocal to Isar
  /// 3. Updates ChronicleLocal (merges facts, state, threads)
  /// 4. If chapterCount (after increment) % 5 == 0, calls /chronicle/compress-arc
  ///    and appends the arc summary
  ///
  /// This method never throws — errors are logged and swallowed so they don't
  /// interrupt the UI. Call with unawaited() from the screen.
  static Future<void> handleChapterComplete({
    required String chronicleId,
    required int chapterNumber,
    required String chapterText,
    required String characterName,
    required String lastChapterEnding,
    required String choiceMadeToStart,
  }) async {
    try {
      final chronicle = await getChronicle(chronicleId);
      if (chronicle == null) return;

      final existingFacts = _decodeStringList(chronicle.worldFactsJson);
      final existingThreads = _decodeStringList(chronicle.unresolvedThreadsJson);

      // Step 1: Summarize chapter
      final summaryResult = await callSummarizeChapter(
        chapterNumber: chapterNumber,
        chapterText: chapterText,
        characterName: characterName,
        choiceMadeToStart: choiceMadeToStart.isNotEmpty ? choiceMadeToStart : null,
        existingWorldFacts: existingFacts,
        existingUnresolvedThreads: existingThreads,
      );

      // Step 2: Build and save ChapterMemoryLocal
      final memory = ChapterMemoryLocal()
        ..chronicleId = chronicleId
        ..chapterNumber = chapterNumber
        ..createdAt = DateTime.now()
        ..choiceMadeToStartChapter =
            choiceMadeToStart.isNotEmpty ? choiceMadeToStart : null
        ..summaryBulletsJson =
            jsonEncode(summaryResult['summary_bullets'] ?? [])
        ..newWorldFactsJson =
            jsonEncode(summaryResult['new_world_facts'] ?? [])
        ..characterGrowthNote =
            summaryResult['character_growth'] as String?
        ..cliffhanger = summaryResult['cliffhanger'] as String?
        ..newThreadsJson =
            jsonEncode(summaryResult['new_unresolved_threads'] ?? [])
        ..resolvedThreadsJson =
            jsonEncode(summaryResult['resolved_threads'] ?? [])
        ..fullChapterText = chapterText;

      await saveChapterMemory(memory);

      // Step 3: Update ChronicleLocal
      final stateUpdate = (summaryResult['character_state_update']
              as Map<String, dynamic>?) ??
          {};
      await updateChronicleAfterChapter(
        chronicleId: chronicleId,
        memory: memory,
        characterStateUpdate: stateUpdate,
        lastChapterEnding: lastChapterEnding,
        choiceMade: choiceMadeToStart,
      );

      // Step 4: Arc compression every 5 chapters
      final newChapterCount = chronicle.chapterCount + 1;
      if (newChapterCount % 5 == 0) {
        final arcNumber = newChapterCount ~/ 5;
        final chapterStart = (arcNumber - 1) * 5 + 1;
        final chapterEnd = arcNumber * 5;
        final allMemories = await getChapterMemories(chronicleId);
        final arcMemories = allMemories
            .where((m) =>
                m.chapterNumber >= chapterStart &&
                m.chapterNumber <= chapterEnd)
            .toList();

        if (arcMemories.length == 5) {
          final compressResult = await callCompressArc(
            arcNumber: arcNumber,
            chapterStart: chapterStart,
            chapterEnd: chapterEnd,
            chapterSummaries: arcMemories
                .map((m) => {
                      'summary_bullets':
                          _decodeStringList(m.summaryBulletsJson),
                    })
                .toList(),
            characterName: characterName,
          );
          final arcSummary =
              compressResult['arc_summary'] as String? ?? '';
          if (arcSummary.isNotEmpty) {
            await appendArcSummary(
                chronicleId: chronicleId, arcSummary: arcSummary);
          }
        }
      }
    } catch (e) {
      // Swallow errors so the UI is never blocked
      // ignore: avoid_print
      print('[ChronicleService] handleChapterComplete error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // PRIVATE HELPERS
  // -------------------------------------------------------------------------

  static List<String> _decodeStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }

  static List<Map<String, dynamic>> _decodeMemoryList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  static Map<String, dynamic> _decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}
