/// Spoken follow-up for a Pick-a-Path segment: the choices as one question
/// that always ends with the open door.
///
/// Readers over 8 hear the story text but not the choice buttons (young bands
/// get "What will you choose? Choice 1: …"). An adult play-through on
/// 2026-09-13 asked for the story to reach "would you like to do this, or
/// this, or something else?" so the listener can pick one or say their own —
/// the "✨ Do something else..." field under the buttons already takes free
/// text. The model was asked to say this line itself and dropped the
/// "something else" tail every time, so the app says it.
String choiceQuestion(List<String> choiceTexts) {
  final parts = choiceTexts.map(_asVerbPhrase).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return 'What would you like to do?';
  return 'Would you like to ${parts.join(', or ')}, or something else?';
}

/// "Follow the light." -> "follow the light", so it reads after "Would you
/// like to".
String _asVerbPhrase(String text) {
  final trimmed = text.trim().replaceAll(RegExp(r'[.!]+$'), '').trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toLowerCase() + trimmed.substring(1);
}
