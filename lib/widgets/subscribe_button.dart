import 'package:flutter/material.dart';

import '../subscription_models.dart';
import '../theme/app_theme.dart';
import '../services/user_identity_service.dart';
import '../services/payment/payment_channel.dart';

/// Subscribe button that initiates a subscription purchase.
///
/// STORE-1 (MT-143): this no longer calls Stripe directly. It goes through the
/// [PaymentChannel] abstraction, which is platform-dispatched at compile time:
///   - Web build  -> Stripe Checkout (unchanged behaviour).
///   - iOS/Android -> StoreKit / Play Billing.
/// The web path is preserved exactly; only the indirection changed.
class SubscribeButton extends StatefulWidget {
  final SubscriptionTier tier;
  final VoidCallback? onSuccess;
  final String? userId;

  /// Monthly (default) or annual billing. Annual is only meaningful for the
  /// premium tier — see [BillingPeriod].
  final BillingPeriod billingPeriod;

  /// Optional injected channel for testing. Production builds let the widget
  /// create the platform-appropriate channel via [createPaymentChannel].
  final PaymentChannel? paymentChannel;

  const SubscribeButton({
    super.key,
    required this.tier,
    this.onSuccess,
    this.userId,
    this.billingPeriod = BillingPeriod.monthly,
    this.paymentChannel,
  });

  @override
  State<SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<SubscribeButton> {
  late final PaymentChannel _channel;
  bool _ownsChannel = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.paymentChannel != null) {
      _channel = widget.paymentChannel!;
    } else {
      _channel = createPaymentChannel();
      _ownsChannel = true;
    }
  }

  @override
  void dispose() {
    if (_ownsChannel) {
      _channel.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubscribe() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId =
          widget.userId ?? await UserIdentityService.getOrCreateUserId();

      await _channel.initialize();
      final result = await _channel.purchase(
        tier: widget.tier,
        userId: userId,
        billingPeriod: widget.billingPeriod,
      );

      if (!mounted) return;

      switch (result.outcome) {
        case PurchaseOutcome.success:
        case PurchaseOutcome.pending:
          widget.onSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_successMessage(result.outcome)),
              backgroundColor: AppColors.primary,
            ),
          );
          break;
        case PurchaseOutcome.cancelled:
          // User backed out of the store / checkout sheet — no error surface.
          break;
        case PurchaseOutcome.error:
          setState(() => _error = result.message ?? 'Payment failed');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment error: $_error'),
              backgroundColor: AppColors.error,
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $_error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _successMessage(PurchaseOutcome outcome) {
    if (_channel.isStoreChannel) {
      return outcome == PurchaseOutcome.success
          ? 'Subscription active — enjoy ${widget.tier.displayName}!'
          : 'Processing your ${widget.tier.displayName} subscription...';
    }
    return 'Redirected to checkout for ${widget.tier.displayName}.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getTierColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: _isLoading ? 0 : 4,
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Processing...'),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.tier.icon,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Subscribe to ${widget.tier.displayName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Color _getTierColor() => widget.tier.color;
}
