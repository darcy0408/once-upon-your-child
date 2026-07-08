// lib/services/feelings_ambient_service.dart
//
// Reads the most recent Feelings Garden journal entry (if within 24 h) and
// constructs a CurrentFeeling so story generation can silently weave in the
// child's emotional context.  No dialog, no confirmation — fully transparent.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feelings_wheel_data.dart';

/// A child's recent emotional context, assembled from the feelings journal
/// for story generation. Relocated from the retired pre_story_feelings_dialog
/// (2026-07-07 dead-code sweep) — this model is live; the dialog was not.
class CurrentFeeling {
  final SelectedFeeling selectedFeeling;
  final int intensity;
  final String? whatHappened;
  final List<String>? physicalSigns;
  final List<String>? copingStrategies;

  CurrentFeeling({
    required this.selectedFeeling,
    required this.intensity,
    this.whatHappened,
    this.physicalSigns,
    this.copingStrategies,
  });

  Map<String, dynamic> toJson() => {
        'emotion_name': selectedFeeling.tertiary,
        'emotion_description':
            '${selectedFeeling.core} → ${selectedFeeling.secondary}',
        'emotion_emoji': selectedFeeling.emoji,
        'core_emotion': selectedFeeling.core,
        'secondary_emotion': selectedFeeling.secondary,
        'tertiary_emotion': selectedFeeling.tertiary,
        'intensity': intensity,
        'what_happened': whatHappened,
        'physical_signs': physicalSigns?.join(', '),
        'coping_strategies': copingStrategies ?? const [],
      };
}

class FeelingsAmbientService {
  static const _journalKey = 'feelings_journal';
  static const _maxAgeHours = 24;

  /// Returns the most recent journal feeling if it was saved within the last
  /// [_maxAgeHours] hours, otherwise null.  Never throws.
  static Future<CurrentFeeling?> getRecentFeeling() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_journalKey) ?? [];
      if (raw.isEmpty) return null;

      // Entries are stored oldest-first; last entry is most recent
      final lastJson = jsonDecode(raw.last) as Map<String, dynamic>;
      final timestampStr = lastJson['timestamp'] as String?;
      if (timestampStr == null) return null;

      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp == null) return null;

      final age = DateTime.now().difference(timestamp);
      if (age.inHours > _maxAgeHours) return null;

      return _buildCurrentFeeling(lastJson);
    } catch (_) {
      // Never break story generation because of a feelings read failure
      return null;
    }
  }

  static CurrentFeeling? _buildCurrentFeeling(Map<String, dynamic> j) {
    final coreName = j['coreName'] as String? ?? '';
    final secondaryName = j['secondaryName'] as String? ?? '';
    final tertiaryName = j['tertiaryName'] as String? ?? '';
    final coreEmoji = j['coreEmoji'] as String? ?? '😐';
    final intensity = (j['intensity'] as num?)?.toInt() ?? 3;

    if (coreName.isEmpty) return null;

    // Look up the core emotion to get its color
    final coreEmotion = FeelingsWheelData.coreEmotions
        .where((c) => c.name.toLowerCase() == coreName.toLowerCase())
        .firstOrNull;
    final color = coreEmotion?.color ?? Colors.purple;

    final selected = SelectedFeeling(
      core: coreName,
      secondary: secondaryName,
      tertiary: tertiaryName,
      emoji: coreEmoji,
      eyeType: coreName == 'Happy' ? 'Happy' : 'Neutral',
      mouthType: coreName == 'Happy' ? 'Smile' : 'Neutral',
      color: color,
    );

    return CurrentFeeling(
      selectedFeeling: selected,
      intensity: intensity,
    );
  }
}
