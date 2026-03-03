// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'age_band_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ageBandNotifierHash() => r'952bf6685e6e115db228a68f5dae82da2f59a306';

/// Riverpod notifier that manages the current age band.
///
/// On startup it reads the user's age (set at the age gate) from
/// SharedPreferences and resolves the appropriate [AgeBand].
/// Parents can override the band to move a child up or down.
///
/// Copied from [AgeBandNotifier].
@ProviderFor(AgeBandNotifier)
final ageBandNotifierProvider =
    AutoDisposeNotifierProvider<AgeBandNotifier, AgeBandThemeData>.internal(
  AgeBandNotifier.new,
  name: r'ageBandNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ageBandNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AgeBandNotifier = AutoDisposeNotifier<AgeBandThemeData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
