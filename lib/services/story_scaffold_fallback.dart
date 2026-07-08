// lib/services/story_scaffold_fallback.dart
//
// Offline fallback that turns a `StoryScaffold` into a `StoryGenerationResult`
// the existing rendering pipeline already knows how to display. This file
// owns the policy ("when do we fall back?") and the kid-data plumbing
// ("which scaffold matches and how do we fill the slots?"). The actual
// scaffold content lives in lib/data/story_scaffolds.dart.
//
// USAGE
// -----
//   final result = await runWithScaffoldFallback(
//     attempt: () => _generateStoryWithBackendRetry(...),
//     scenarioId: theme,
//     age: age,
//     name: characterName,
//     companion: companion ?? '',
//     gender: characterDetails?['gender'] as String?,
//     currentFeelingId: (currentFeeling?['emotion_name'] as String?)?.toLowerCase(),
//     archetypeId: characterDetails?['archetype_id'] as String?,
//   );
//
// Why a separate file: keeps api_service_manager.dart additions minimal
// (one wrap call) and keeps the fallback testable in isolation.

import 'dart:async';
import 'dart:io' show HttpException, SocketException;

import 'package:flutter/foundation.dart';

import '../data/story_scaffolds.dart';
import '../models/story_generation_result.dart';
import '../theme/age_band_theme.dart' show ageBandFromAge;

/// Classifies an exception as "user-recoverable via fallback" vs. fatal.
/// We treat as fallback-eligible:
///   - Any [TimeoutException] (the backend took too long)
///   - Any [SocketException] (network down / DNS failure / connection refused)
///   - Any [HttpException] whose message indicates 5xx, 429, or quota
///   - Any error whose `toString()` mentions quota/rate-limit/exhaust
///   - Any other [Exception] when [aggressive] is true (treat as offline)
///
/// We do NOT fall back for client errors (4xx other than 429) or
/// authentication errors — those are configuration problems the kid's
/// parent/guardian needs to address, and silently swapping in canned
/// content would hide the issue.
bool isFallbackEligible(Object error, {bool aggressive = true}) {
  // PERF-01 cancellation polish: a user-initiated cancel is NOT a failure —
  // never substitute a fallback story for it. Let the signal propagate so the
  // caller handles it silently (no error card, no story nav).
  if (error is StoryGenerationCancelled) return false;
  if (error is TimeoutException) return true;
  if (error is SocketException) return true;

  final msg = error.toString().toLowerCase();

  // Quota / rate-limit signals from any provider (Gemini, OpenRouter, our backend).
  if (msg.contains('quota') ||
      msg.contains('rate limit') ||
      msg.contains('rate-limit') ||
      msg.contains('rate_limit') ||
      msg.contains('exhaust') ||
      msg.contains('429')) {
    return true;
  }

  // Server errors → backend is sick, fall back gracefully.
  if (msg.contains('500') ||
      msg.contains('502') ||
      msg.contains('503') ||
      msg.contains('504') ||
      msg.contains('status 5')) {
    return true;
  }

  // Generic "failed to fetch" / "connection refused" / "network" strings
  // that http.ClientException can throw on web and mobile.
  if (msg.contains('failed to fetch') ||
      msg.contains('connection refused') ||
      msg.contains('connection closed') ||
      msg.contains('networkerror') ||
      msg.contains('network is unreachable') ||
      msg.contains('no address associated with hostname')) {
    return true;
  }

  if (error is HttpException && aggressive) return true;

  // 4xx client errors and auth errors propagate up — those are not
  // network-y problems and silent fallback would hide a real bug.
  return false;
}

/// Maps a `gender` field (typically 'Boy' / 'Girl' / null / 'they') to the
/// pronoun triple the interpolation engine expects.
({String pronoun, String pronounCap, String possessive}) pronounsForGender(
    String? gender) {
  switch ((gender ?? '').trim().toLowerCase()) {
    case 'boy':
    case 'male':
    case 'he':
      return (pronoun: 'he', pronounCap: 'He', possessive: 'his');
    case 'girl':
    case 'female':
    case 'she':
      return (pronoun: 'she', pronounCap: 'She', possessive: 'her');
    default:
      return (pronoun: 'they', pronounCap: 'They', possessive: 'their');
  }
}

/// Build a `StoryGenerationResult` from a scaffold + kid data. Public so
/// tests can call it directly without going through the network path.
StoryGenerationResult buildScaffoldResult({
  required StoryScaffold scaffold,
  required String name,
  String companion = '',
  String? gender,
}) {
  final p = pronounsForGender(gender);
  final storyText = flattenAndInterpolateScaffold(
    scaffold,
    name: name.isNotEmpty ? name : 'Friend',
    companion: companion,
    pronoun: p.pronoun,
    pronounCap: p.pronounCap,
    possessive: p.possessive,
  );
  final title = interpolateScaffoldTitle(
    scaffold,
    name: name.isNotEmpty ? name : 'Friend',
    companion: companion,
    pronoun: p.pronoun,
    pronounCap: p.pronounCap,
    possessive: p.possessive,
  );
  return StoryGenerationResult(
    storyText: storyText,
    title: title,
    wisdomGem: scaffold.grownupTip,
    // No illustrations in the offline path — the rendering pipeline
    // accepts an empty list and just shows the text. Adding pre-bundled
    // art is a future content session.
    illustrations: const [],
    asyncIllustrations: false,
    pages: const [],
    adventureSteps: const [],
  );
}

/// Wraps an AI story-generation attempt and falls back to a hand-written
/// scaffold when the attempt throws a fallback-eligible error.
///
/// Call sequence on the happy path:
///   wizard → ApiServiceManager.generateStory → attempt() succeeds → return.
///
/// Call sequence on the fallback path:
///   wizard → ApiServiceManager.generateStory → attempt() throws
///     → isFallbackEligible == true
///     → pickScaffoldFor(scenarioId, band, archetype, feeling)
///     → buildScaffoldResult(name, companion, gender)
///     → return synthesized StoryGenerationResult.
///
/// If no scaffold matches AT ALL (library empty for the band), the
/// original error is rethrown so callers still see the failure and can
/// surface it normally.
Future<StoryGenerationResult> runWithScaffoldFallback({
  required Future<StoryGenerationResult> Function() attempt,
  required String scenarioId,
  required int age,
  required String name,
  String companion = '',
  String? gender,
  String? archetypeId,
  String? currentFeelingId,
  // Bedtime requests must fall back to a CALM scaffold (wind-down pacing,
  // sleep-transition ending) — serving an energetic daytime adventure at
  // lights-out defeats the mode. See pickScaffoldFor's bedtime handling.
  bool bedtime = false,
}) async {
  try {
    return await attempt();
  } catch (error, stackTrace) {
    if (!isFallbackEligible(error)) {
      rethrow;
    }

    final band = ageBandFromAge(age);
    final scaffold = pickScaffoldFor(
      scenarioId: scenarioId,
      band: band,
      archetypeId: archetypeId,
      feelingId: currentFeelingId,
      bedtime: bedtime,
    );

    if (scaffold == null) {
      debugPrint(
        '[story-fallback] no scaffold available for band=$band scenario=$scenarioId; '
        'rethrowing original error: $error',
      );
      Error.throwWithStackTrace(error, stackTrace);
    }

    debugPrint(
      '[story-fallback] AI generation failed (${error.runtimeType}); '
      'using scaffold "${scaffold.id}" for scenario="$scenarioId" '
      'band=$band archetype=$archetypeId feeling=$currentFeelingId. '
      'Original error: $error',
    );

    return buildScaffoldResult(
      scaffold: scaffold,
      name: name,
      companion: companion,
      gender: gender,
    );
  }
}
