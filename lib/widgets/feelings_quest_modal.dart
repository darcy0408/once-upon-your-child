// lib/widgets/feelings_quest_modal.dart
//
// Thin full-screen wrapper around FeelingsCloudPicker.
// Opens as a page route; pops with a List<String> of selected feeling ids.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feelings_cloud_picker.dart';
import 'feelings_badge_grid.dart';
import '../theme/age_band_theme.dart';

class FeelingsQuestModal {
  /// Returns ['happy'], ['happy','playful'], or ['happy','playful','silly'].
  /// Returns null if dismissed without selecting.
  static Future<List<String>?> show(
    BuildContext context, {
    required int childAge,
  }) {
    return Navigator.of(context, rootNavigator: true).push<List<String>>(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) =>
            _FeelingsQuestScreen(childAge: childAge),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

class _FeelingsQuestScreen extends StatefulWidget {
  final int childAge;
  const _FeelingsQuestScreen({required this.childAge});

  @override
  State<_FeelingsQuestScreen> createState() => _FeelingsQuestScreenState();
}

class _FeelingsQuestScreenState extends State<_FeelingsQuestScreen> {
  final _pickerKey = GlobalKey<FeelingsCloudPickerState>();

  // Track level for header title
  int _level = 0;

  bool get _useBadgeGrid =>
      ageBandFromAge(widget.childAge) == AgeBand.adventurer;

  bool get _isSproutBand =>
      ageBandFromAge(widget.childAge) == AgeBand.sprout;

  static const _titles = [
    "What's going on?",
    'Tell me more…',
    'Even more specific?',
  ];

  /// Sprout (ages ≤5) only ever sees level 0 (4 core clouds, no drill-down),
  /// and their title should mirror BigFeelingsFlowScreen: "How do you feel?".
  String _titleForLevel(int level) {
    if (_isSproutBand) return 'How do you feel?';
    return _titles[level.clamp(0, 2)];
  }

  void _onLevelChanged(int level) {
    if (mounted) setState(() => _level = level);
  }

  @override
  Widget build(BuildContext context) {
    final bandTheme = Theme.of(context).extension<AgeBandThemeData>();
    return Scaffold(
      backgroundColor: bandTheme?.gradientStart ?? const Color(0xFF1A0E3A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: _useBadgeGrid || _level == 0
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white60, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                            onPressed: () {
                              final wentBack =
                                  _pickerKey.currentState?.goBack() ?? false;
                              if (!wentBack) Navigator.of(context).pop();
                            },
                          ),
                  ),
                  Expanded(
                    child: Text(
                      _useBadgeGrid
                          ? "What's going on?"
                          : _titleForLevel(_level),
                      textAlign: TextAlign.center,
                      style: (Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false)
                          ? GoogleFonts.sourceSans3(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            )
                          : GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Picker — badge grid for Adventurer band, cloud picker otherwise
            Expanded(
              child: _useBadgeGrid
                  ? FeelingsBadgeGrid(
                      onSelected: (ids) => Navigator.of(context).pop(ids),
                    )
                  : FeelingsCloudPicker(
                      key: _pickerKey,
                      childAge: widget.childAge,
                      onLevelChanged: _onLevelChanged,
                      onSelected: (sel) =>
                          Navigator.of(context).pop(sel.ids),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
