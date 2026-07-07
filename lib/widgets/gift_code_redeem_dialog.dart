import 'package:flutter/material.dart';

import '../services/stripe_service.dart';
import '../services/subscription_sync_service.dart';
import '../theme/app_theme.dart';

/// "Have a gift code?" entry point — shows a modest dialog with a code
/// field, redeems it via [StripeService.redeemGiftCode], refreshes
/// [SubscriptionSyncService] on success, and shows a celebratory
/// confirmation SnackBar.
void showGiftCodeRedeemDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _GiftCodeRedeemDialog(),
  );
}

class _GiftCodeRedeemDialog extends StatefulWidget {
  const _GiftCodeRedeemDialog();

  @override
  State<_GiftCodeRedeemDialog> createState() => _GiftCodeRedeemDialogState();
}

class _GiftCodeRedeemDialogState extends State<_GiftCodeRedeemDialog> {
  final _controller = TextEditingController();
  final _stripeService = StripeService();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter your gift code');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _stripeService.redeemGiftCode(code);
      await SubscriptionSyncService().syncSubscriptionStatus();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Gift redeemed — enjoy Premium!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on GiftRedeemException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not redeem this code. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A1B4E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Redeem a Gift Code',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the code from your gift email to unlock Premium.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF2A1B4E),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A1B4E)),
                  ),
                )
              : const Text('Redeem'),
        ),
      ],
    );
  }
}
