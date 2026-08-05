import 'package:flutter/material.dart';

import '../theme/age_band_theme.dart';

/// App bar for the Pick-a-Path reader.
///
/// Extracted from `PickAPathAdventureScreen` so its phone-width layout can be
/// regression-tested without booting the screen (whose `initState` starts a
/// network story generation).
///
/// The layout decision this encodes: the storybook progress indicator sits on
/// its own row *below* the title rather than in the app bar's `actions` slot.
/// With six page icons the indicator is ~215px wide, which on a 360px bar left
/// the title roughly 57px — enough for "The …" and nothing more (MT-393 F12).
class PickAPathAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PickAPathAppBar({
    super.key,
    required this.title,
    required this.band,
    required this.isSprout,
    this.progress,
  });

  final String title;
  final AgeBandThemeData band;

  /// Sprouts get a larger title, and so need a taller bar to hold two lines.
  final bool isSprout;

  /// The progress row, or null while loading / on a session break.
  final Widget? progress;

  double get _toolbarHeight => isSprout ? 76 : 68;

  static const double _progressRowHeight = 42;

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (progress != null ? _progressRowHeight : 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: band.gradientStart,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: _toolbarHeight,
      title: Text(
        title,
        // AppBar wraps its title in a DefaultTextStyle carrying softWrap:false
        // and ellipsis, so both must be set here for the title to wrap at all.
        softWrap: true,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: band.uiFontFamily,
          fontSize: isSprout ? 20 : 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottom: progress == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(_progressRowHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: progress,
                ),
              ),
            ),
    );
  }
}
