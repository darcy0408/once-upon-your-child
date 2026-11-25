import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service_manager.dart';
import 'caregiver_service.dart';
import 'logger_service.dart';

class ChildProfile {
  final String id;
  final String name;
  final int age;
  final String avatarEmoji;
  final String colorHex;

  ChildProfile({
    String? id,
    required this.name,
    required this.age,
    this.avatarEmoji = '🧒',
    this.colorHex = '#9C27B0',
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'avatarEmoji': avatarEmoji,
        'colorHex': colorHex,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name'] ?? 'Child',
        age: j['age'] ?? 8,
        avatarEmoji: j['avatarEmoji'] ?? '🧒',
        colorHex: j['colorHex'] ?? '#9C27B0',
      );

  ChildProfile copyWith({
    String? name,
    int? age,
    String? avatarEmoji,
    String? colorHex,
  }) =>
      ChildProfile(
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        colorHex: colorHex ?? this.colorHex,
      );
}

class ChildProfileService {
  static const _profilesKey = 'child_profiles';
  static const _activeKey = 'active_profile_id';

  Future<List<ChildProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_profilesKey) ?? [];
    return raw.map((e) => ChildProfile.fromJson(jsonDecode(e))).toList();
  }

  Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActiveProfile(ChildProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, profile.id);
    // Sync with the existing age band system.
    await prefs.setInt('user_age', profile.age);
  }

  Future<void> saveProfile(ChildProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    await prefs.setStringList(
        _profilesKey, profiles.map((p) => jsonEncode(p.toJson())).toList());
  }

  /// Deletes one child's profile: the profile itself, the grown-up notes saved
  /// for it on the server, and its caregiver names. Saved heroes, stories and
  /// the other children's profiles are left alone. Erasing the whole account
  /// is a separate control in Parent Controls.
  ///
  /// The server step runs first. Returns `false`, with the profile still in
  /// place, when that step fails (offline, 5xx, or the sign-in changed under
  /// us), so the parent can try again. Callers MUST surface a `false` result.
  Future<bool> deleteProfile(String profileId) async {
    try {
      final api = ApiServiceManager();
      // A device that never signed in has no notes on the server, and
      // deleting a profile must not create an account as a side effect.
      final accountId = await api.storedUserId();
      if (accountId != null) {
        await api.delete(
          '/child-profiles/${Uri.encodeComponent(profileId)}'
          '/parent-hidden-context',
        );
        // If the call was answered for a different account, the notes we
        // meant to remove may still be there. Do not report success.
        if (await api.storedUserId() != accountId) {
          throw StateError('account changed during profile delete');
        }
      }
    } catch (e) {
      LoggerService.warning(
        'ChildProfileService.deleteProfile: could not remove the server-side '
        'notes for profile $profileId; profile kept so it can be retried',
        e,
      );
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == profileId);
    await prefs.setStringList(
        _profilesKey, profiles.map((p) => jsonEncode(p.toJson())).toList());
    if (prefs.getString(_activeKey) == profileId) {
      await prefs.remove(_activeKey);
    }
    await CaregiverService().clear(profileId);
    return true;
  }
}
