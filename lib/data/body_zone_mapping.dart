/// Maps body zone IDs (from [BodyOutlineWidget]) to the body-signal option
/// values used by [BigFeelingsFlowScreen]'s `_bodyOptions` map.
///
/// Each zone ID can match multiple feeling-agnostic body signal values.
/// The mapping is intentionally broad: the same zone can correspond to
/// different sensations depending on the active feeling (e.g., "chest" maps
/// to "Warm chest" for Happy but "Hollow chest" for Grief). At runtime,
/// [bodyZoneToSignal] resolves the best match given the active feeling's
/// available options.
/// Returns the best-matching body-signal value for a tapped [zoneId], given
/// the list of [availableOptions] for the active feeling.
///
/// Falls back to the first available option if no zone match is found.
String bodyZoneToSignal(String zoneId, List<String> availableOptions) {
  if (availableOptions.isEmpty) return '';

  final keywords = _zoneKeywords[zoneId] ?? const [];
  for (final option in availableOptions) {
    final lower = option.toLowerCase();
    for (final kw in keywords) {
      if (lower.contains(kw)) return option;
    }
  }
  // No keyword match — return first option
  return availableOptions.first;
}

/// Keywords to search for in body-signal option values, keyed by zone ID.
const Map<String, List<String>> _zoneKeywords = {
  'head': [
    'head', 'eye', 'brow', 'face', 'mouth', 'gaze', 'look', 'wide eyes',
    'big eyes', 'droopy eyes', 'distant gaze',
  ],
  'face': [
    'face', 'cheek', 'mouth', 'eye', 'brow', 'jaw', 'nose', 'lip',
    'flushed', 'grumpy', 'soft face',
  ],
  'throat': [
    'throat', 'voice', 'talking', 'breath', 'sigh', 'exhale',
    'tight throat', 'shaky voice', 'firm voice', 'loud voice', 'quiet voice',
  ],
  'neck': [
    'throat', 'neck', 'voice', 'tight throat',
  ],
  'shoulders': [
    'shoulder', 'relax', 'shrug', 'posture', 'upright', 'withdrawn',
  ],
  'chest': [
    'chest', 'heart', 'breath', 'breathing', 'warm', 'hollow', 'heavy',
    'lighter', 'steady', 'weighted', 'heat in chest',
  ],
  'heart': [
    'heart', 'chest', 'warm', 'fast heart', 'steady heart', 'slow heart',
  ],
  'stomach': [
    'tummy', 'stomach', 'belly', 'butterflies', 'flutter', 'sinking',
    'tight tummy', 'heavy tummy',
  ],
  'tummy': [
    'tummy', 'stomach', 'butterfly', 'flutter', 'heavy tummy',
  ],
  'lower_back': [
    'back', 'posture', 'upright', 'slow',
  ],
  'arms': [
    'arm', 'wiggle arms', 'holding', 'withdrawn',
  ],
  'hands': [
    'hand', 'fist', 'fidget', 'restless hands', 'shaky hands',
    'clenched', 'holding self',
  ],
  'upper_legs': [
    'leg', 'feet', 'stompy', 'tapping', 'slow walking',
  ],
  'lower_legs': [
    'feet', 'leg', 'tapping feet', 'stompy feet', 'bouncy feet', 'slow',
  ],
  'legs': [
    'feet', 'leg', 'jumping', 'stompy', 'bouncy', 'tapping',
  ],
  'feet': [
    'feet', 'foot', 'jumping', 'stompy feet', 'bouncy feet', 'tapping feet',
  ],
};
