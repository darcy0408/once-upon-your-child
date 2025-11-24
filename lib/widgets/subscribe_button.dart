import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription_tier.dart';
import '../theme/app_theme.dart';
import '../services/user_identity_service.dart';
import '../services/stripe_service.dart';

/// Subscribe button that initiates Stripe Checkout for subscription tiers
class SubscribeButton extends StatefulWidget {
  final SubscriptionTier tier;
  final VoidCallback? onSuccess;
  final String? userId;
  final StripeService? stripeService;

  const SubscribeButton({
    super.key,
    required this.tier,
    this.onSuccess,
    this.userId,
    this.stripeService,
  });

  @override
  State<SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<SubscribeButton> {
  late final StripeService _stripeService;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stripeService = widget.stripeService ?? StripeService();
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

      final session = await _stripeService.createCheckoutSession(
        tier: widget.tier.name,
        userId: userId,
      );
      final checkoutUrl = session['checkout_url'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL received');
      }

      final checkoutUri = Uri.tryParse(checkoutUrl);
      if (checkoutUri == null) {
        throw Exception('Invalid checkout URL');
      }

      final launched = await launchUrl(
        checkoutUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open payment page');
      }

      if (!mounted) return;

      widget.onSuccess?.call();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Redirected to Stripe Checkout for ${widget.tier.name}.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $_error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                        _getTierIcon(),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                       Text(
                         'Subscribe to ${widget.tier.name[0].toUpperCase()}${widget.tier.name.substring(1)}',
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

  Color _getTierColor() {
    switch (widget.tier) {
      case SubscriptionTier.premium:
        return Colors.deepPurple;
      case SubscriptionTier.family:
        return Colors.green;
      case SubscriptionTier.free:
        return Colors.grey;
    }
  }

  IconData _getTierIcon() {
    switch (widget.tier) {
      case SubscriptionTier.premium:
        return Icons.star;
      case SubscriptionTier.family:
        return Icons.family_restroom;
      case SubscriptionTier.free:
        return Icons.person;
    }
  }
}
