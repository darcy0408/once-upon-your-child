// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hero_saga_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$heroSagaHash() => r'2345b2cf2d53b8c48ccefaa19ec272de2fa90ca1';

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

/// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
/// ever been recorded for this hero (a fresh hero → a clean origin, no
/// `prior_saga`). Returns null for an empty id rather than throwing.
///
/// Copied from [heroSaga].
@ProviderFor(heroSaga)
const heroSagaProvider = HeroSagaFamily();

/// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
/// ever been recorded for this hero (a fresh hero → a clean origin, no
/// `prior_saga`). Returns null for an empty id rather than throwing.
///
/// Copied from [heroSaga].
class HeroSagaFamily extends Family<AsyncValue<HeroSaga?>> {
  /// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
  /// ever been recorded for this hero (a fresh hero → a clean origin, no
  /// `prior_saga`). Returns null for an empty id rather than throwing.
  ///
  /// Copied from [heroSaga].
  const HeroSagaFamily();

  /// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
  /// ever been recorded for this hero (a fresh hero → a clean origin, no
  /// `prior_saga`). Returns null for an empty id rather than throwing.
  ///
  /// Copied from [heroSaga].
  HeroSagaProvider call(
    String characterId,
  ) {
    return HeroSagaProvider(
      characterId,
    );
  }

  @override
  HeroSagaProvider getProviderOverride(
    covariant HeroSagaProvider provider,
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
  String? get name => r'heroSagaProvider';
}

/// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
/// ever been recorded for this hero (a fresh hero → a clean origin, no
/// `prior_saga`). Returns null for an empty id rather than throwing.
///
/// Copied from [heroSaga].
class HeroSagaProvider extends AutoDisposeFutureProvider<HeroSaga?> {
  /// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
  /// ever been recorded for this hero (a fresh hero → a clean origin, no
  /// `prior_saga`). Returns null for an empty id rather than throwing.
  ///
  /// Copied from [heroSaga].
  HeroSagaProvider(
    String characterId,
  ) : this._internal(
          (ref) => heroSaga(
            ref as HeroSagaRef,
            characterId,
          ),
          from: heroSagaProvider,
          name: r'heroSagaProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$heroSagaHash,
          dependencies: HeroSagaFamily._dependencies,
          allTransitiveDependencies: HeroSagaFamily._allTransitiveDependencies,
          characterId: characterId,
        );

  HeroSagaProvider._internal(
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
    FutureOr<HeroSaga?> Function(HeroSagaRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HeroSagaProvider._internal(
        (ref) => create(ref as HeroSagaRef),
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
  AutoDisposeFutureProviderElement<HeroSaga?> createElement() {
    return _HeroSagaProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HeroSagaProvider && other.characterId == characterId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, characterId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin HeroSagaRef on AutoDisposeFutureProviderRef<HeroSaga?> {
  /// The parameter `characterId` of this provider.
  String get characterId;
}

class _HeroSagaProviderElement
    extends AutoDisposeFutureProviderElement<HeroSaga?> with HeroSagaRef {
  _HeroSagaProviderElement(super.provider);

  @override
  String get characterId => (origin as HeroSagaProvider).characterId;
}

String _$heroSagaControllerHash() =>
    r'9126d1e8555af73e9823730ca25748eb32881c2a';

/// Controller exposing the saga mutations a Creator superhero story-result
/// handler needs. Prefer these over touching [HeroSagaStore] directly so the
/// matching [heroSagaProvider] watcher is invalidated and any visible recap
/// rebuilds.
///
/// Copied from [HeroSagaController].
@ProviderFor(HeroSagaController)
final heroSagaControllerProvider =
    AutoDisposeNotifierProvider<HeroSagaController, void>.internal(
  HeroSagaController.new,
  name: r'heroSagaControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$heroSagaControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$HeroSagaController = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
