import 'package:flutter/material.dart';

import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';

/// A parental-gate dialog presenting a math challenge a young child cannot
/// trivially pass. Required before opening external links / account-creation
/// flows in a Kids-Category app (Apple Guideline 1.3 / 5.1.4).
///
/// This mirrors the multiplication-challenge gate used inline in
/// `parent_controls_screen.dart` (`_buildMathGate`). It is implemented as a
/// self-contained dialog here because `parent_controls_screen.dart` exposes
/// its gate only as an embedded widget, not a reusable dialog, and that file
/// is out of scope for this change.
///
/// Returns `true` from [show] if the parent solved the challenge, `false` or
/// `null` if they cancelled or dismissed it.
class ParentalGateDialog extends StatefulWidget {
  const ParentalGateDialog({super.key, this.message});

  /// Explanation line shown above the math challenge. Defaults to the
  /// external-link wording used by the settings/story-result gates; callers
  /// that gate an IN-APP step (e.g. the consent flow) must pass copy that
  /// doesn't claim an external website is about to open.
  final String? message;

  /// Shows the gate and returns `true` only if the challenge was passed.
  static Future<bool> show(BuildContext context, {String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParentalGateDialog(message: message),
    );
    return result ?? false;
  }

  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<ParentalGateDialog> {
  final _controller = TextEditingController();
  late int _a;
  late int _b;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _a = (now % 7) + 3; // 3–9
    _b = (now % 6) + 4; // 4–9
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    final answer = int.tryParse(_controller.text.trim());
    if (answer == _a * _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // MT-416: seen on a real phone, the explanation, the "a × b =" label and
    // the "Answer" label painted near-white on the dialog's light card.
    // Rendered under all six band themes at phone width, every one showed
    // it: Material 3 paints the dialog on a light container it derives from
    // the seed (not the band surface), and every piece of copy that inherited
    // its colour came out white. Fix: the dialog owns one contrast-audited
    // pair — the band's card colour and its ink (onCard, >= 4.5:1 by
    // contract) — and nothing inherits. The error line gets its own red,
    // chosen for the card: the theme's error red is ~3.3:1 on both.
    final band = Theme.of(context).extension<AgeBandThemeData>() ??
        explorerTheme;
    final ink = band.onCard;
    final card = band.cardColor;
    final cardIsDark = ThemeData.estimateBrightnessForColor(card) ==
        Brightness.dark;
    final errorInk = cardIsDark
        ? const Color(0xFFFF8A80) // light coral on the mature bands' dark cards
        : const Color(0xFFB71C1C); // deep red on the young bands' light cards

    return AlertDialog(
      backgroundColor: card,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      title: Row(
        children: const [
          Icon(Icons.lock_outline_rounded, color: Color(0xFFFFD54F)),
          SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Parents only')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message ??
                'This opens an external website. Solve this to continue '
                    '(keeps little hands from leaving the app).',
            style: TextStyle(fontSize: 13, height: 1.4, color: ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '$_a × $_b = ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ink),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Answer',
                    labelStyle: TextStyle(color: ink),
                    floatingLabelStyle: TextStyle(color: ink),
                    // The theme fills inputs with the band surface, which is
                    // dark on the mature bands and light on the young ones;
                    // on this card a faint wash of the ink reads on both.
                    filled: true,
                    fillColor: ink.withAlpha(18),
                    errorStyle: TextStyle(color: errorInk),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: errorInk),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: errorInk, width: 2),
                    ),
                    errorText: _wrong ? 'Not quite — try again.' : null,
                  ),
                  onSubmitted: (_) => _check(),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: ink),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _check,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
