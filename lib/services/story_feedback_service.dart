import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoryFeedback {
  final String storyId;
  final String title;
  final double rating;
  final String feedback;
  final String? therapeuticFocus;
  final DateTime submittedAt;

  StoryFeedback({
    required this.storyId,
    required this.title,
    required this.rating,
    required this.feedback,
    required this.submittedAt,
    this.therapeuticFocus,
  });

  Map<String, dynamic> toMap() => {
        'storyId': storyId,
        'title': title,
        'rating': rating,
        'feedback': feedback,
        'therapeuticFocus': therapeuticFocus,
        'submittedAt': submittedAt.toIso8601String(),
      };

  static StoryFeedback fromMap(Map<String, dynamic> map) => StoryFeedback(
        storyId: map['storyId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        feedback: map['feedback'] as String? ?? '',
        therapeuticFocus: map['therapeuticFocus'] as String?,
        submittedAt: DateTime.tryParse(map['submittedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class StoryFeedbackService {
  static const _storageKey = 'story_feedback_entries';

  Future<List<StoryFeedback>> loadFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    return raw
        .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
        .map(StoryFeedback.fromMap)
        .toList(growable: false);
  }

  Future<void> submitFeedback(StoryFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_storageKey) ?? <String>[];
    existing.add(jsonEncode(feedback.toMap()));
    await prefs.setStringList(_storageKey, existing);
  }
}
