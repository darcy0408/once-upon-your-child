import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> deleteProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == profileId);
    await prefs.setStringList(
        _profilesKey, profiles.map((p) => jsonEncode(p.toJson())).toList());
    final active = await getActiveProfileId();
    if (active == profileId) await prefs.remove(_activeKey);
  }
}
