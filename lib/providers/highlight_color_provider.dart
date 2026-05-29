import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// A selectable word-highlight color for the Learning-to-read story reader.
class HighlightColorOption {
  const HighlightColorOption(this.label, this.color);
  final String label;
  final Color color;
}

/// Preset highlight colors. A11Y-LTR-03: a non-gold highlight is easier for
/// some readers, and a few children have specific color sensitivities.
/// Presets keep the choice simple, safe, and high-contrast on the page.
const kHighlightColorOptions = <HighlightColorOption>[
  HighlightColorOption('Gold', AppColors.gold),
  HighlightColorOption('Sky blue', Color(0xFF4FC3F7)),
  HighlightColorOption('Mint green', Color(0xFF81C784)),
  HighlightColorOption('Soft pink', Color(0xFFF48FB1)),
];

/// Persists and exposes the reader word-highlight color.
///
/// App-wide, mirroring the voice-preference pattern; defaults to
/// [AppColors.gold]. A manual [NotifierProvider] (not riverpod codegen) so the
/// accessibility setting stays self-contained and needs no build_runner step.
class HighlightColorNotifier extends Notifier<Color> {
  static const _prefsKey = 'reader_highlight_color';

  @override
  Color build() {
    _load();
    return AppColors.gold;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefsKey);
    if (saved != null) state = Color(saved);
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, color.toARGB32());
  }
}

final highlightColorProvider =
    NotifierProvider<HighlightColorNotifier, Color>(HighlightColorNotifier.new);
