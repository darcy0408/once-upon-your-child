// Isar-backed implementation for mobile/desktop platforms.
// The companion `hero_profile_local_io.g.dart` is produced by
// `dart run build_runner build` — do not hand-edit.
import 'package:isar/isar.dart';

part 'hero_profile_local_io.g.dart';

/// Persistent hero-mode profile keyed by [characterId] (FK to
/// [CharacterLocal.characterId]). Stores the child's last costume +
/// chosen superpower, plus rolling "no-repeat" lists of villains and
/// problems the backend has already used so the next story can avoid them.
///
/// Cap on the recent lists is enforced by the provider, not the schema —
/// keep this class a dumb DTO.
@collection
class HeroProfileLocal {
  Id id = Isar.autoIncrement;

  /// FK to [CharacterLocal.characterId]. Indexed for fast lookup.
  @Index(unique: true, replace: true)
  late String characterId;

  /// Costume customization — mirrors WizardData fields.
  /// Allowed values: 'red' | 'blue' | 'green' | 'yellow' | 'purple' | 'pink'.
  String? costumeColor;

  /// Allowed values: 'none' | 'matching' | 'rainbow'.
  String? capeStyle;

  /// Allowed values: 'star' | 'lightning' | 'heart' | 'moon' | 'paw' | 'rainbow'.
  String? emblem;

  /// One of 8 power IDs: super_speed | flying | super_strength | super_hearing |
  /// super_smile | super_hugs | super_whisper | super_sharing.
  String? power;

  /// Optional computed display name (e.g. "Super Hug Mia"). Built at save time
  /// by the UI; UI is free to leave null.
  String? heroName;

  late DateTime createdAt;
  late DateTime updatedAt;

  /// Most recent villain IDs returned by the backend (`superhero_meta.villain_id`).
  /// Trimmed by the provider to the last 8.
  List<String> recentVillains = [];

  /// Most recent problem IDs returned by the backend (`superhero_meta.problem_id`).
  /// Trimmed by the provider to the last 8.
  List<String> recentProblems = [];
}
