// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$characterListHash() => r'0b71ae6e3d77109aaa0da7364e05b68fcdd02498';

/// See also [CharacterList].
@ProviderFor(CharacterList)
final characterListProvider = AutoDisposeAsyncNotifierProvider<CharacterList,
    List<CharacterLocal>>.internal(
  CharacterList.new,
  name: r'characterListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CharacterList = AutoDisposeAsyncNotifier<List<CharacterLocal>>;
String _$selectedCharacterHash() => r'c4f05e4bfebff14d57f2f8c4109274d25174d67e';

/// Provider for the currently selected character
///
/// Copied from [SelectedCharacter].
@ProviderFor(SelectedCharacter)
final selectedCharacterProvider =
    AutoDisposeNotifierProvider<SelectedCharacter, CharacterLocal?>.internal(
  SelectedCharacter.new,
  name: r'selectedCharacterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedCharacterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedCharacter = AutoDisposeNotifier<CharacterLocal?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
