/// Sanitizes user-entered text before it reaches AI prompts.
///
/// Defends against prompt injection, inappropriate content, and
/// excessively long inputs that could degrade story quality.
class InputSanitizer {
  InputSanitizer._();

  /// Maximum character limits per field.
  static const int maxCharacterName = 50;
  static const int maxCustomElements = 500;
  static const int maxParentalNote = 300;
  static const int maxLifeChallenge = 300;
  static const int maxSuperpower = 100;
  static const int maxQuest = 200;
  static const int maxAvoidWords = 200;
  static const int maxDnaContext = 200;

  /// Strips HTML tags, null bytes, and excessive whitespace.
  static String sanitizeText(String input, {int maxLength = 500}) {
    if (input.isEmpty) return input;

    var result = input
        // Remove HTML tags
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Remove null bytes
        .replaceAll('\x00', '')
        // Collapse multiple whitespace into single spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Cap length
    if (result.length > maxLength) {
      result = result.substring(0, maxLength).trim();
    }

    return result;
  }

  /// Additional prompt-injection defenses on top of sanitizeText.
  ///
  /// Strips patterns that attempt to override AI system instructions.
  static String sanitizeForPrompt(String input, {int maxLength = 500}) {
    if (input.isEmpty) return input;

    var result = sanitizeText(input, maxLength: maxLength);

    // Strip common prompt injection patterns (case-insensitive).
    final injectionPatterns = [
      // Direct instruction overrides
      RegExp(r'ignore\s+(all\s+)?(previous|prior|above)\s+(instructions?|prompts?|rules?)', caseSensitive: false),
      RegExp(r'disregard\s+(all\s+)?(previous|prior|above)', caseSensitive: false),
      RegExp(r'forget\s+(everything|all)\s+(above|before|previous)', caseSensitive: false),
      RegExp(r'override\s+(all\s+)?(instructions?|rules?|constraints?)', caseSensitive: false),
      // Role/persona injection
      RegExp(r'you\s+are\s+now\s+', caseSensitive: false),
      RegExp(r'act\s+as\s+(a\s+|an\s+)?(?:different|new|unrestricted)', caseSensitive: false),
      RegExp(r'pretend\s+(to\s+be|you\s+are)', caseSensitive: false),
      // System/assistant message spoofing
      RegExp(r'^\s*system\s*:', caseSensitive: false),
      RegExp(r'^\s*assistant\s*:', caseSensitive: false),
      RegExp(r'^\s*\[INST\]', caseSensitive: false),
      RegExp(r'^\s*<\|im_start\|>', caseSensitive: false),
      // Markdown/code injection attempting to embed instructions
      RegExp(r'```\s*(system|instruction|prompt)', caseSensitive: false),
    ];

    for (final pattern in injectionPatterns) {
      result = result.replaceAll(pattern, '');
    }

    return result.trim();
  }

  /// Checks whether input contains content inappropriate for children's stories.
  ///
  /// Returns a non-null warning message if inappropriate content is detected,
  /// or null if the content is acceptable.
  static String? checkInappropriateContent(String input) {
    if (input.isEmpty) return null;

    final lower = input.toLowerCase();

    // Explicit violence
    final violencePatterns = [
      'kill', 'murder', 'suicide', 'self-harm', 'self harm',
      'torture', 'rape', 'molest', 'abuse',
      'shoot', 'stab', 'decapitate', 'dismember',
    ];

    // Sexual content
    final sexualPatterns = [
      'sex', 'naked', 'nude', 'porn', 'erotic',
      'genitals', 'intercourse',
    ];

    // Hate/discrimination
    final hatePatterns = [
      'racial slur', 'hate crime', 'genocide',
    ];

    // Substance abuse (for child context)
    final substancePatterns = [
      'cocaine', 'heroin', 'meth', 'crack pipe',
      'overdose', 'drug dealer',
    ];

    for (final term in [...violencePatterns, ...sexualPatterns, ...hatePatterns, ...substancePatterns]) {
      // Use word boundary matching to avoid false positives
      // (e.g., "skilled" shouldn't match "kill")
      if (RegExp('\\b${RegExp.escape(term)}\\b', caseSensitive: false).hasMatch(lower)) {
        return "Let's keep our stories magical and kind! Please try a different description.";
      }
    }

    return null;
  }

  /// Self-directed self-harm / suicide phrasing. Mirrors the authoritative
  /// server-side detector in backend/utils/crisis_detection.py. Targets
  /// first-person phrasing ("kill myself", "want to die") so ordinary
  /// third-person story violence ("the villain attacks") does not match.
  static final List<RegExp> _crisisPatterns = [
    RegExp(r'\bsuicid(e|al)\b', caseSensitive: false),
    RegExp(r'\bself[\s-]?harm(ing)?\b', caseSensitive: false),
    RegExp(r'\bkill(ing)?\s+my\s?self\b', caseSensitive: false),
    RegExp(r'\bhurt(ing)?\s+my\s?self\b', caseSensitive: false),
    RegExp(r'\bharm(ing)?\s+my\s?self\b', caseSensitive: false),
    RegExp(r'\bcut(ting)?\s+my\s?self\b', caseSensitive: false),
    RegExp(r'\bend(ing)?\s+my\s+life\b', caseSensitive: false),
    RegExp(r'\btake\s+my\s+own\s+life\b', caseSensitive: false),
    RegExp(r'\b(want|wanna)\s+to\s+die\b', caseSensitive: false),
    RegExp(r"\b(do\s*n'?t|do\s+not)\s+want\s+to\s+(live|be\s+alive|be\s+here)\b",
        caseSensitive: false),
    RegExp(r'\bbetter\s+off\s+dead\b', caseSensitive: false),
    RegExp(r'\bwish\s+i\s+(was|were)\s+(dead|not\s+alive)\b',
        caseSensitive: false),
    RegExp(r'\bno\s+reason\s+to\s+live\b', caseSensitive: false),
    RegExp(r'\bend\s+it\s+all\b', caseSensitive: false),
    RegExp(r'\bwant\s+to\s+disappear\s+forever\b', caseSensitive: false),
    // Youth euphemisms (red-team 2026-07-17 MEDIUM-2) — mirrors the server
    // block so the panel surfaces instantly, without the round-trip.
    RegExp(r'\bunaliv(e|ed|ing)\b', caseSensitive: false),
    // "kms" the abbreviation, not "5 kms" the metric distance.
    RegExp(r'(?<!\d)(?<!\d\s)\bkms\b', caseSensitive: false),
    RegExp(r'\bkys\b', caseSensitive: false),
    RegExp(r'\bsewer\s*slide\b', caseSensitive: false),
    RegExp(r'\boff(ing)?\s+my\s?self\b', caseSensitive: false),
    RegExp(r"\b(do\s*n'?t|do\s+not)\s+want\s+to\s+wake\s+up\b",
        caseSensitive: false),
    RegExp(r'\bdelete\s+my\s?self\b', caseSensitive: false),
    RegExp(r'\bend\s+my\s?self\b', caseSensitive: false),
  ];

  /// Detects a self-harm / suicide disclosure in child free-text.
  ///
  /// This is a fast first-line check; the server re-checks authoritatively. On
  /// a true result the caller MUST surface crisis resources
  /// (CrisisResourcesPanel) with warmth — NOT the [checkInappropriateContent]
  /// "keep stories magical" rejection, and NOT a generated story.
  static bool detectCrisis(String input) {
    if (input.isEmpty) return false;
    for (final pattern in _crisisPatterns) {
      if (pattern.hasMatch(input)) return true;
    }
    return false;
  }

  /// Sanitize a character name.
  static String sanitizeName(String name) {
    return sanitizeText(name, maxLength: maxCharacterName);
  }

  /// Sanitize the "Imagine It" / custom elements field.
  static String sanitizeCustomElements(String input) {
    return sanitizeForPrompt(input, maxLength: maxCustomElements);
  }

  /// Sanitize the parental note field.
  static String sanitizeParentalNote(String input) {
    return sanitizeForPrompt(input, maxLength: maxParentalNote);
  }

  /// Sanitize the life challenge field.
  static String sanitizeLifeChallenge(String input) {
    return sanitizeForPrompt(input, maxLength: maxLifeChallenge);
  }

  /// Sanitize the hero superpower field.
  static String sanitizeSuperpower(String input) {
    return sanitizeForPrompt(input, maxLength: maxSuperpower);
  }

  /// Sanitize the hero quest field.
  static String sanitizeQuest(String input) {
    return sanitizeForPrompt(input, maxLength: maxQuest);
  }

  /// Sanitize the "avoid" field from Story DNA.
  static String sanitizeAvoid(String input) {
    return sanitizeText(input, maxLength: maxAvoidWords);
  }
}
