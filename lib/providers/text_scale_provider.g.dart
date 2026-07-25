// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_scale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$textScaleNotifierHash() => r'a28b753fe6b2a6ed591bff5f7413ed559a4f7b6f';

/// Riverpod notifier that manages the user's app-wide text size preference.
///
/// This is separate from the OS/browser font-size setting — Flutter web does
/// not read that — and separate from the per-band theme. It lets a parent
/// bump body text up for readability regardless of age band.
///
/// Copied from [TextScaleNotifier].
@ProviderFor(TextScaleNotifier)
final textScaleNotifierProvider =
    AutoDisposeNotifierProvider<TextScaleNotifier, double>.internal(
  TextScaleNotifier.new,
  name: r'textScaleNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$textScaleNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TextScaleNotifier = AutoDisposeNotifier<double>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
