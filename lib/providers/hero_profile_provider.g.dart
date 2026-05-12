// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hero_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$heroProfileHash() => r'd0364967ea3ea05b6053f5e2a70662e32fb81404';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Loads the [HeroProfileLocal] for the given [characterId], returning
/// `null` when no profile has ever been saved (distinct from an empty
/// profile with all-null costume slots).
///
/// Copied from [heroProfile].
@ProviderFor(heroProfile)
const heroProfileProvider = HeroProfileFamily();

/// Loads the [HeroProfileLocal] for the given [characterId], returning
/// `null` when no profile has ever been saved (distinct from an empty
/// profile with all-null costume slots).
///
/// Copied from [heroProfile].
class HeroProfileFamily extends Family<AsyncValue<HeroProfileLocal?>> {
  /// Loads the [HeroProfileLocal] for the given [characterId], returning
  /// `null` when no profile has ever been saved (distinct from an empty
  /// profile with all-null costume slots).
  ///
  /// Copied from [heroProfile].
  const HeroProfileFamily();

  /// Loads the [HeroProfileLocal] for the given [characterId], returning
  /// `null` when no profile has ever been saved (distinct from an empty
  /// profile with all-null costume slots).
  ///
  /// Copied from [heroProfile].
  HeroProfileProvider call(
    String characterId,
  ) {
    return HeroProfileProvider(
      characterId,
    );
  }

  @override
  HeroProfileProvider getProviderOverride(
    covariant HeroProfileProvider provider,
  ) {
    return call(
      provider.characterId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'heroProfileProvider';
}

/// Loads the [HeroProfileLocal] for the given [characterId], returning
/// `null` when no profile has ever been saved (distinct from an empty
/// profile with all-null costume slots).
///
/// Copied from [heroProfile].
class HeroProfileProvider extends AutoDisposeFutureProvider<HeroProfileLocal?> {
  /// Loads the [HeroProfileLocal] for the given [characterId], returning
  /// `null` when no profile has ever been saved (distinct from an empty
  /// profile with all-null costume slots).
  ///
  /// Copied from [heroProfile].
  HeroProfileProvider(
    String characterId,
  ) : this._internal(
          (ref) => heroProfile(
            ref as HeroProfileRef,
            characterId,
          ),
          from: heroProfileProvider,
          name: r'heroProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$heroProfileHash,
          dependencies: HeroProfileFamily._dependencies,
          allTransitiveDependencies:
              HeroProfileFamily._allTransitiveDependencies,
          characterId: characterId,
        );

  HeroProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.characterId,
  }) : super.internal();

  final String characterId;

  @override
  Override overrideWith(
    FutureOr<HeroProfileLocal?> Function(HeroProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HeroProfileProvider._internal(
        (ref) => create(ref as HeroProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        characterId: characterId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<HeroProfileLocal?> createElement() {
    return _HeroProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HeroProfileProvider && other.characterId == characterId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, characterId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin HeroProfileRef on AutoDisposeFutureProviderRef<HeroProfileLocal?> {
  /// The parameter `characterId` of this provider.
  String get characterId;
}

class _HeroProfileProviderElement
    extends AutoDisposeFutureProviderElement<HeroProfileLocal?>
    with HeroProfileRef {
  _HeroProfileProviderElement(super.provider);

  @override
  String get characterId => (origin as HeroProfileProvider).characterId;
}

String _$heroProfileControllerHash() =>
    r'c9bdb5c041f0012e487cd2bb266ad0ce289088c4';

/// CRUD controller for hero profiles. Use [HeroProfileController]'s
/// methods rather than touching SharedPreferences directly.
///
/// Copied from [HeroProfileController].
@ProviderFor(HeroProfileController)
final heroProfileControllerProvider =
    AutoDisposeNotifierProvider<HeroProfileController, void>.internal(
  HeroProfileController.new,
  name: r'heroProfileControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$heroProfileControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$HeroProfileController = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
