import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-profile family/caregiver labels used by Sprout-band quests so prose
/// can read "Mommy puts on their shoes" instead of the generic "your grown-up".
///
/// Stored locally only. Never uploaded — same COPPA stance as on-device avatars.
class CaregiverInfo {
  final String? primary;
  final List<String> extended;

  const CaregiverInfo({this.primary, this.extended = const []});

  Map<String, dynamic> toJson() => {
        'primary': primary,
        'extended': extended,
      };

  factory CaregiverInfo.fromJson(Map<String, dynamic> j) => CaregiverInfo(
        primary: (j['primary'] as String?)?.trim().isEmpty == true
            ? null
            : j['primary'] as String?,
        extended: (j['extended'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            const [],
      );

  CaregiverInfo copyWith({
    String? primary,
    bool clearPrimary = false,
    List<String>? extended,
  }) =>
      CaregiverInfo(
        primary: clearPrimary ? null : (primary ?? this.primary),
        extended: extended ?? this.extended,
      );

  static const empty = CaregiverInfo();
}

class CaregiverService {
  static String _key(String profileId) => 'caregivers_$profileId';

  Future<CaregiverInfo> load(String? profileId) async {
    if (profileId == null || profileId.isEmpty) return CaregiverInfo.empty;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return CaregiverInfo.empty;
    try {
      return CaregiverInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return CaregiverInfo.empty;
    }
  }

  Future<void> save(String profileId, CaregiverInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), jsonEncode(info.toJson()));
  }

  Future<void> clear(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(profileId));
  }

  /// Convenience for quest text interpolation. Returns the primary caregiver
  /// label if set, otherwise the generic fallback used by `interpolateQuest`.
  Future<String> grownupLabelOrDefault(String? profileId) async {
    if (profileId == null || profileId.isEmpty) return 'your grown-up';
    final info = await load(profileId);
    final primary = info.primary?.trim();
    if (primary == null || primary.isEmpty) return 'your grown-up';
    return primary;
  }
}
