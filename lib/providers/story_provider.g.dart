// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineStoryServiceHash() =>
    r'6fcb7237ad62e8feab5c70bc3120242c2ea69f9f';

/// See also [offlineStoryService].
@ProviderFor(offlineStoryService)
final offlineStoryServiceProvider =
    AutoDisposeProvider<OfflineStoryService>.internal(
  offlineStoryService,
  name: r'offlineStoryServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlineStoryServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OfflineStoryServiceRef = AutoDisposeProviderRef<OfflineStoryService>;
String _$storyListHash() => r'2dc1d47d2504ca0394c16302206d3125e8077f60';

/// See also [StoryList].
@ProviderFor(StoryList)
final storyListProvider =
    AutoDisposeAsyncNotifierProvider<StoryList, List<StoryLocal>>.internal(
  StoryList.new,
  name: r'storyListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$storyListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StoryList = AutoDisposeAsyncNotifier<List<StoryLocal>>;
String _$favoriteStoriesHash() => r'dc8063c02fa4464d3289eab930948b3c16585bd7';

/// See also [FavoriteStories].
@ProviderFor(FavoriteStories)
final favoriteStoriesProvider = AutoDisposeAsyncNotifierProvider<
    FavoriteStories, List<StoryLocal>>.internal(
  FavoriteStories.new,
  name: r'favoriteStoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$favoriteStoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FavoriteStories = AutoDisposeAsyncNotifier<List<StoryLocal>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
