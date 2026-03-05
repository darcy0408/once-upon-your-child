import 'package:flutter/foundation.dart';
import '../models/generated_avatar.dart';

/// Service to track background avatar generation state
class AvatarGenerationState extends ChangeNotifier {
  static final AvatarGenerationState _instance = AvatarGenerationState._internal();

  factory AvatarGenerationState() => _instance;

  AvatarGenerationState._internal();

  bool _isGenerating = false;
  GeneratedAvatar? _completedAvatar;
  String? _error;
  DateTime? _startTime;

  bool get isGenerating => _isGenerating;
  GeneratedAvatar? get completedAvatar => _completedAvatar;
  String? get error => _error;
  DateTime? get startTime => _startTime;

  int get elapsedSeconds {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }

  void startGeneration() {
    _isGenerating = true;
    _completedAvatar = null;
    _error = null;
    _startTime = DateTime.now();
    notifyListeners();
    debugPrint('🎨 Avatar generation started in background');
  }

  void completeGeneration(GeneratedAvatar avatar) {
    _isGenerating = false;
    _completedAvatar = avatar;
    _error = null;
    final duration = DateTime.now().difference(_startTime ?? DateTime.now());
    debugPrint('✅ Avatar generation completed in ${duration.inSeconds}s');
    notifyListeners();
  }

  void failGeneration(String errorMessage) {
    _isGenerating = false;
    _error = errorMessage;
    debugPrint('❌ Avatar generation failed: $errorMessage');
    notifyListeners();
  }

  void reset() {
    _isGenerating = false;
    _completedAvatar = null;
    _error = null;
    _startTime = null;
    notifyListeners();
  }

  void consumeAvatar() {
    // Mark avatar as consumed (used in wizard)
    _completedAvatar = null;
    notifyListeners();
  }
}
