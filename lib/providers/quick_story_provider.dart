import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/api_service_manager.dart';

part 'quick_story_provider.g.dart';

/// State for quick story generation
class QuickStoryState {
  final bool isGenerating;
  final String? storyText;
  final String? error;

  const QuickStoryState({
    this.isGenerating = false,
    this.storyText,
    this.error,
  });

  QuickStoryState copyWith({
    bool? isGenerating,
    String? storyText,
    String? error,
  }) {
    return QuickStoryState(
      isGenerating: isGenerating ?? this.isGenerating,
      storyText: storyText ?? this.storyText,
      error: error ?? this.error,
    );
  }
}

@riverpod
class QuickStory extends _$QuickStory {
  @override
  QuickStoryState build() {
    return const QuickStoryState();
  }

  Future<void> generateStory({
    required String characterName,
    required int characterAge,
    required String theme,
    String? emotion,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);

    try {
      final apiService = ApiServiceManager();
      final result = await apiService.generateStory(
        params: {
          'character_name': characterName,
          'character_age': characterAge,
          'theme': theme,
          if (emotion != null) 'emotion': emotion,
        },
      );

      state = state.copyWith(
        isGenerating: false,
        storyText: result['story_text'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const QuickStoryState();
  }
}
