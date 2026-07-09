// lib/services/bedtime_replay_service.dart
//
// MT-361(b): "Play last night's story again". Bedtime stories are narrated
// once and never routed through the usual save-to-library flow (the wizard
// is screen-free and never visits story_result_screen.dart), so without this
// there is no way to replay one without paying for a fresh generation.
//
// This is a deliberately lightweight, local-only cache of the single most
// recent COMPLETED, non-interactive bedtime story per hero — enough to offer
// an instant, zero-generation-cost replay. It is not a general story library;
// see chronicles/StoryLocal for that.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A previously-narrated bedtime story, saved locally so it can be replayed
/// with no AI call.
class BedtimeReplayStory {
  final String title;
  final String storyText;
  final DateTime createdAt;

  const BedtimeReplayStory({
    required this.title,
    required this.storyText,
    required this.createdAt,
  });

  Map<String, dynamic> _toJson() => {
        'title': title,
        'storyText': storyText,
        'createdAt': createdAt.toIso8601String(),
      };

  static BedtimeReplayStory? _fromJson(Map<String, dynamic> json) {
    final storyText = (json['storyText'] as String?)?.trim() ?? '';
    if (storyText.isEmpty) return null;
    final title = (json['title'] as String?)?.trim();
    return BedtimeReplayStory(
      title: (title != null && title.isNotEmpty) ? title : 'Your Bedtime Story',
      storyText: storyText,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Persists and recalls the most recent completed bedtime story per hero.
class BedtimeReplayService {
  BedtimeReplayService._();

  static const _keyPrefix = 'bedtime_last_story_';

  /// Derives the same per-hero storage key BedtimeWizardScreen resolves via
  /// `SuperheroEntryScreen.resolveCharacterId` (`name_` + a slug, or
  /// `temp_hero` when the name is blank). Duplicated here — rather than
  /// importing the superhero wizard step — to keep this a lightweight leaf
  /// service with no riverpod/provider dependencies. Keep in sync if that
  /// logic ever changes.
  static String characterIdForName(String name) {
    final slug = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return slug.isNotEmpty ? 'name_$slug' : 'temp_hero';
  }

  /// Saves [storyText] under [characterId] as tonight's story. Best-effort:
  /// a failed save must never interrupt the story actually being read aloud.
  static Future<void> save({
    required String characterId,
    required String title,
    required String storyText,
  }) async {
    final trimmedText = storyText.trim();
    if (trimmedText.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final story = BedtimeReplayStory(
        title: title.trim(),
        storyText: trimmedText,
        createdAt: DateTime.now(),
      );
      await prefs.setString(
        '$_keyPrefix$characterId',
        jsonEncode(story._toJson()),
      );
    } catch (e) {
      debugPrint('BedtimeReplayService.save failed: $e');
    }
  }

  /// Returns the saved story for [characterId], or null if none exists yet
  /// (first-ever bedtime session for this hero) or the saved record is
  /// malformed/unreadable.
  static Future<BedtimeReplayStory?> load(String characterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$characterId');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BedtimeReplayStory._fromJson(decoded);
      }
    } catch (e) {
      debugPrint('BedtimeReplayService.load failed: $e');
    }
    return null;
  }
}
