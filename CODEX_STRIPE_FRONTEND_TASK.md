# Codex Frontend Task: Stripe Checkout Integration

## Priority: HIGH
**Assigned to:** Codex
**Estimated time:** 30-45 minutes
**Dependencies:** None - can work in parallel with Gemini's backend task

---

## Objective
Complete the Flutter frontend integration for Stripe checkout. The UI exists but needs proper API connection and state management for subscription flows.

---

## Task 1: Create Stripe Service Layer

### Create: `lib/services/stripe_service.dart`

This service will handle all Stripe-related API calls:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/flavor_config.dart';

class StripeService {
  final String _baseUrl;

  StripeService() : _baseUrl = FlavorConfig.instance.backendUrl;

  /// Create a Stripe Checkout Session and return the checkout URL
  Future<Map<String, dynamic>> createCheckoutSession({
    required String tier,
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/stripe/create-checkout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tier': tier,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create checkout session: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error creating checkout session: $e');
    }
  }

  /// Get subscription status for a user
  Future<Map<String, dynamic>> getSubscriptionStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/stripe/subscription-status/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // User not found, return free tier
        return {'status': 'inactive', 'tier': 'free'};
      } else {
        throw Exception('Failed to get subscription status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error getting subscription status: $e');
    }
  }

  /// Cancel a subscription at the end of the billing period
  Future<bool> cancelSubscription(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/stripe/cancel-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

---

## Task 2: Update SubscribeButton Widget

### File: Find the subscribe button widget (likely in `lib/` directory)

Update the button to use the new StripeService:

```dart
import 'package:url_launcher/url_launcher.dart';
import 'services/stripe_service.dart';

class SubscribeButton extends StatefulWidget {
  final String tier; // 'premium' or 'family'
  final String? userId;

  const SubscribeButton({
    super.key,
    required this.tier,
    this.userId,
  });

  @override
  State<SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<SubscribeButton> {
  final _stripeService = StripeService();
  bool _isLoading = false;

  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);

    try {
      // Create checkout session
      final result = await _stripeService.createCheckoutSession(
        tier: widget.tier,
        userId: widget.userId,
      );

      final checkoutUrl = result['checkout_url'];

      if (checkoutUrl != null) {
        // Launch Stripe Checkout in browser/webview
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw Exception('Could not launch checkout URL');
        }
      }
    } catch (e) {
      if (!mounted) return;

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Subscription Error'),
          content: Text('Failed to start checkout: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSubscribe,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text('Subscribe - ${widget.tier == 'premium' ? 'Premium' : 'Family'}'),
    );
  }
}
```

---

## Task 3: Update Subscription Management Screen

### File: `lib/screens/subscription_management_screen.dart` (or wherever subscription UI lives)

Add real-time subscription status checking:

```dart
import '../services/stripe_service.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final String userId;

  const SubscriptionManagementScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final _stripeService = StripeService();
  Map<String, dynamic>? _subscriptionStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    setState(() => _isLoading = true);

    try {
      final status = await _stripeService.getSubscriptionStatus(widget.userId);
      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subscription: $e')),
        );
      }
    }
  }

  Future<void> _handleCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your subscription will remain active until the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _stripeService.cancelSubscription(widget.userId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription will be canceled at period end'),
          ),
        );
        _loadSubscriptionStatus(); // Refresh status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel subscription'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _subscriptionStatus?['status'] ?? 'inactive';
    final tier = _subscriptionStatus?['tier'] ?? 'free';
    final isActive = status == 'active';

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Plan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tier.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!isActive) ...[
              const Text('Upgrade to unlock unlimited stories!'),
              const SizedBox(height: 16),
              SubscribeButton(tier: 'premium', userId: widget.userId),
              const SizedBox(height: 8),
              SubscribeButton(tier: 'family', userId: widget.userId),
            ] else ...[
              const Text('You have full access to all features!'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _handleCancelSubscription,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Cancel Subscription'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## Task 4: Add url_launcher Dependency

### File: `pubspec.yaml`

Add the url_launcher package if not already present:

```yaml
dependencies:
  url_launcher: ^6.2.0  # For launching Stripe Checkout URLs
```

Run:
```bash
flutter pub get
```

---

## Task 5: Update Premium Upgrade Screen

### File: `lib/premium_upgrade_screen.dart`

If this screen exists, update it to use the new SubscribeButton widget with proper tier selection.

---

## Task 6: Handle Subscription Success Callback

### File: `lib/screens/subscription_success_screen.dart`

Verify this screen exists and handles the redirect from Stripe Checkout:

```dart
import 'package:flutter/material.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Confirmed'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Premium!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your subscription is now active. Enjoy unlimited stories!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Navigate back to main screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Start Creating Stories'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Ensure the route is registered in `main.dart`:
```dart
routes: {
  '/subscription-success': (context) => const SubscriptionSuccessScreen(),
},
```

---

## Task 7: Test Frontend Flow

After completing the above:

1. **Test Subscribe Button:**
   - Click subscribe button
   - Verify loading state shows
   - Check console for API call
   - Verify error handling if backend not ready

2. **Test Subscription Management:**
   - Navigate to subscription management screen
   - Verify free tier shows correctly
   - Test upgrade buttons

3. **Test Success Flow:**
   - Navigate to `/subscription-success` route
   - Verify UI displays correctly

---

## Verification Checklist

Before marking complete, verify:

- [ ] StripeService created with all methods
- [ ] SubscribeButton uses StripeService
- [ ] Subscription management screen updated
- [ ] url_launcher dependency added
- [ ] Subscription success screen exists and is routed
- [ ] Error handling in all async operations
- [ ] Loading states for all API calls
- [ ] Code compiles without errors (`flutter analyze`)
- [ ] No breaking changes to existing screens

---

## Git Commit Message Template

```
Feat: Complete Stripe frontend integration

Integrated Stripe Checkout flow with proper service layer, state management,
and user feedback.

Changes:
- Created StripeService for all Stripe API calls
- Updated SubscribeButton to launch Stripe Checkout URLs
- Enhanced subscription management screen with real-time status
- Added subscription cancellation flow
- Added url_launcher dependency for external checkout
- Verified subscription success screen routing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Notes for Codex

- **DO NOT** worry about Stripe API keys - focus on the frontend integration
- Follow Flutter best practices: proper state management, error handling, loading states
- Use existing patterns from the codebase (FlavorConfig, etc.)
- The backend endpoints will be ready once Gemini completes their task
- Test with mock responses if backend isn't ready yet

---

## After Completion

Update TEAM_COORDINATION.md with:
```
- 2025-11-23 · Codex → Team: STRIPE FRONTEND INTEGRATION COMPLETED ✅
  - Created StripeService for Stripe API integration
  - Updated SubscribeButton with proper checkout flow
  - Enhanced subscription management screen with real-time status
  - Added subscription cancellation UI
  - Verified success/cancel screen routing
  - All code compiles and ready for backend integration
  - Repository synced to main
```
