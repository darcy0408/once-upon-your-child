import 'package:flutter/material.dart';
import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';

/// Wraps paywall dialogs to protect minors from reaching a purchase flow.
///
/// Every minor band — Sprout / Explorer / Adventurer / Creator / Adolescent —
/// must clear a parent gate (a multiplication challenge) before the real
/// paywall is shown. Only an explicit Adult band opens the paywall directly.
/// A null band (a screen lacking the [AgeBandThemeData] theme extension) is
/// treated as a minor and gated too — we must never assume an unknown context
/// is an adult. Minors cannot consent to a purchase contract, so the 13–17
/// bands are gated as well (P1#4: closes the prior Creator/null no-gate path).
Future<T?> showPaywallGated<T>({
  required BuildContext context,
  required Future<T?> Function() showActualPaywall,
}) async {
  final band = Theme.of(context).extension<AgeBandThemeData>();

  // Only an explicit adult context may open the paywall without a gate.
  if (band != null && band.band == AgeBand.adult) {
    return showActualPaywall();
  }

  // Minor (or indeterminate) band: require the parent gate first.
  final passed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AskGrownUpDialog(band: band),
  );

  if (passed == true && context.mounted) {
    return showActualPaywall();
  }
  return null;
}

class _AskGrownUpDialog extends StatefulWidget {
  final AgeBandThemeData? band;
  const _AskGrownUpDialog({required this.band});
  @override
  State<_AskGrownUpDialog> createState() => _AskGrownUpDialogState();
}

class _AskGrownUpDialogState extends State<_AskGrownUpDialog> {
  late final int _a;
  late final int _b;
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final rng = DateTime.now().millisecondsSinceEpoch;
    // Multiplication (not addition) so the gate is not trivially solved by the
    // 6–12-year-olds it protects. Operands stay single-digit so a parent
    // answers instantly. Mirrors ParentalGateDialog (widgets/parental_gate_dialog.dart).
    _a = 3 + (rng % 7); // 3-9
    _b = 4 + ((rng ~/ 100) % 6); // 4-9
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final answer = int.tryParse(_controller.text.trim());
    if (answer == _a * _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Try again!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSprout = widget.band?.band == AgeBand.sprout;
    return AlertDialog(
      backgroundColor: const Color(0xFF2C1B47),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.band?.cardRadiusBase ?? 16),
      ),
      title: Text(
        isSprout ? 'Get a Grown-Up!' : 'Ask a Parent',
        style: TextStyle(
          fontFamily: widget.band?.uiFontFamily,
          color: const Color(0xFFFFD700),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSprout
                ? 'This part is for grown-ups. Can you find one to help?'
                : 'A parent or guardian needs to unlock this section.',
            style: TextStyle(
              fontFamily: widget.band?.uiFontFamily,
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Parent: solve to continue',
            style: TextStyle(
              fontFamily: widget.band?.uiFontFamily,
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_a × $_b = ?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              labelText: 'Answer',
              hintText: '?',
              hintStyle: const TextStyle(color: AppColors.hintOnDark),
              errorText: _error,
              errorStyle: const TextStyle(color: Colors.orangeAccent),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            isSprout ? 'Go Back' : 'Cancel',
            style: TextStyle(
              fontFamily: widget.band?.uiFontFamily,
              color: Colors.white54,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A1B9A),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(widget.band?.buttonRadiusBase ?? 12),
            ),
          ),
          child: Text(
            'Unlock',
            style: TextStyle(
              fontFamily: widget.band?.uiFontFamily,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
