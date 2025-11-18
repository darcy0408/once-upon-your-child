import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/environment.dart';
import '../models/subscription_tier.dart';
import '../theme/app_theme.dart';
import '../services/user_identity_service.dart';

/// Subscribe button that initiates Stripe Checkout for subscription tiers
class SubscribeButton extends StatefulWidget {
  final SubscriptionTier tier;
  final VoidCallback? onSuccess;
  final String? userId;

  const SubscribeButton({
    super.key,
    required this.tier,
    this.onSuccess,
    this.userId,
  });

  @override
  State<SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<SubscribeButton> {
  bool _isLoading = false;
  String? _error;

  Future<void> _handleSubscribe() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId =
          widget.userId ?? await UserIdentityService.getOrCreateUserId();
      
      final response = await http.post(
        Uri.parse('${Environment.backendUrl}/api/create-checkout-session'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tier': widget.tier.name,
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final checkoutUrl = data['checkout_url'] as String?;
        
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

        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redirected to Stripe Checkout for ${widget.tier.name}.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to create checkout session');
      }
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
