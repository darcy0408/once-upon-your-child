import 'lib/avatar_models.dart';

void main() {
  // Test default avatar
  final defaultAvatar = CharacterAvatar.defaultAvatar;
  print('Default Avatar URL:');
  print(defaultAvatar.toAvataaarsUrl());
  print('');

  // Test with brown hair
  final brownHairAvatar = defaultAvatar.copyWith(hairColor: 'Brown');
  print('Brown Hair Avatar URL:');
  print(brownHairAvatar.toAvataaarsUrl());
  print('');

  // Test with black hair
  final blackHairAvatar = defaultAvatar.copyWith(hairColor: 'Black');
  print('Black Hair Avatar URL:');
  print(blackHairAvatar.toAvataaarsUrl());
}
