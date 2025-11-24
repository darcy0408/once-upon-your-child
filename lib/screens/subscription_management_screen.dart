import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../models/subscription_status.dart';
import '../models/usage_stats.dart';
import '../services/subscription_sync_service.dart';
import '../services/user_identity_service.dart';
import '../services/stripe_service.dart';

typedef SubscriptionLoader = Future<SubscriptionStatus?> Function(String userId);
typedef SubscriptionSyncer = Future<void> Function(String userId);
typedef UserIdResolver = Future<String> Function();

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({
    super.key,
    this.httpClient,
    this.subscriptionLoader,
    this.subscriptionSyncer,
    this.userIdResolver,
    this.stripeService,
  });

  final http.Client? httpClient;
  final SubscriptionLoader? subscriptionLoader;
  final SubscriptionSyncer? subscriptionSyncer;
  final UserIdResolver? userIdResolver;
  final StripeService? stripeService;

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final SubscriptionSyncService _syncService = SubscriptionSyncService();
  late final http.Client _httpClient;
  late final bool _ownsHttpClient;
  late final SubscriptionLoader _subscriptionLoader;
  late final SubscriptionSyncer _subscriptionSyncer;
  late final UserIdResolver _userIdResolver;
  late final StripeService _stripeService;

  SubscriptionStatus? _subscriptionStatus;
  UsageStats? _usageStats;
  String? _userId;
  bool _isLoading = true;
  String? _error;

  static const Duration _requestTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _httpClient = widget.httpClient ?? http.Client();
    _ownsHttpClient = widget.httpClient == null;
    _subscriptionLoader =
        widget.subscriptionLoader ?? _defaultLoadSubscriptionStatus;
    _subscriptionSyncer =
        widget.subscriptionSyncer ?? _defaultSyncSubscriptionStatus;
    _userIdResolver =
        widget.userIdResolver ?? UserIdentityService.getOrCreateUserId;
    _stripeService = widget.stripeService ?? StripeService();
    _loadData();
  }

  @override
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    super.dispose();
  }

  Future<SubscriptionStatus?> _defaultLoadSubscriptionStatus(
    String userId,
  ) async {
    final payload = await _stripeService.getSubscriptionStatus(userId);
    return SubscriptionStatus.fromBackendPayload(userId, payload);
  }

  Future<void> _defaultSyncSubscriptionStatus(String userId) {
    return _syncService.syncSubscriptionStatus(userId: userId);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await _ensureUserId();
      final results = await Future.wait<dynamic>([
        _subscriptionLoader(userId),
        _fetchUsageStats(userId),
      ]);

      if (!mounted) return;
      setState(() {
        _subscriptionStatus = results[0] as SubscriptionStatus?;
        _usageStats = results[1] as UsageStats;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _usageStats = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<UsageStats> _fetchUsageStats(String userId) async {
    final response = await _httpClient
        .get(
          Uri.parse('${Environment.backendUrl}/api/user/$userId/usage-stats'),
          headers: const {'Content-Type': 'application/json'},
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load usage stats (${response.statusCode})',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return UsageStats.fromJson(data);
  }

  Future<String> _ensureUserId() async {
    if (_userId != null) {
      return _userId!;
    }
    final resolved = await _userIdResolver();
    _userId = resolved;
    return resolved;
  }

  Future<void> _cancelSubscription() async {
    try {
      final userId = await _ensureUserId();
      final success = await _stripeService.cancelSubscription(userId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription will be canceled at period end'),
          ),
        );
        await _loadData();
      } else {
        throw Exception('Failed to cancel');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to cancel subscription right now. Please try again.'),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final userId = await _ensureUserId();
      await _subscriptionSyncer(userId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription refreshed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to restore purchases right now.'),
        ),
      );
    }
  }

  void _showCancelDialog() {
    if (!_canCancelSubscription) return;
    final endDate = _subscriptionStatus!.currentPeriodEnd!;
    final formattedDate = _formatDate(endDate);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Text(
          'Are you sure? Subscription will end on $formattedDate',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelSubscription();
            },
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canCancelSubscription {
    final status = _subscriptionStatus;
    if (status == null || status.currentPeriodEnd == null) {
      return false;
    }
    return status.status != 'canceled';
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final localDate = date.toLocal();
    final month = monthNames[localDate.month - 1];
    return '$month ${localDate.day}, ${localDate.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'trialing':
        return Colors.orange;
      case 'past_due':
        return Colors.red;
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _friendlyStatus(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'trialing':
        return 'Trialing';
      case 'past_due':
        return 'Past Due';
      case 'canceled':
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }

  Widget _buildUsageCard(String title, int used, int limit) {
    final ratio = limit > 0 ? used / limit : 0.0;
    final clamped = ratio.clamp(0.0, 1.0);
    final percent = limit > 0 ? (clamped * 100).round() : 0;
    final progressText = limit > 0 ? '$used / $limit ($percent%)' : '$used used';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(progressText),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: clamped,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                clamped >= 0.9 ? Colors.red : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSection(UsageStats usage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Usage This Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildUsageCard(
              'Stories This Month',
              usage.storiesThisMonth,
              usage.storiesLimit,
            ),
            const SizedBox(height: 12),
            _buildUsageCard(
              'Characters',
              usage.charactersCount,
              usage.charactersLimit,
            ),
            const SizedBox(height: 12),
            Text(
              'Billing cycle: ${_formatDate(usage.periodStart)} - ${_formatDate(usage.periodEnd)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierChip(SubscriptionTier tier) {
    final color = tier.color;
    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      label: Text(
        tier.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      label: Text(
        _friendlyStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUpgradeButton() {
    final tier = _subscriptionStatus?.tier ?? SubscriptionTier.free;
    if (tier == SubscriptionTier.family) {
      return const SizedBox.shrink();
    }

    final label =
        tier == SubscriptionTier.free ? 'Upgrade to Premium' : 'Upgrade to Family';

    return FilledButton(
      onPressed: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label coming soon')),
        );
      },
      child: Text(label),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: _canCancelSubscription ? _showCancelDialog : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
      ),
      child: const Text('Cancel Subscription'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription Management')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'We had trouble loading your subscription.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_error!.isNotEmpty)
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final status = _subscriptionStatus;
    final usage = _usageStats;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Management')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Plan',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTierChip(status?.tier ?? SubscriptionTier.free),
                        _buildStatusChip(status?.status ?? 'active'),
                      ],
                    ),
                    if (status?.currentPeriodEnd != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Renews on ${_formatDate(status!.currentPeriodEnd!)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    if (status?.cancelAtPeriodEnd ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Cancellation scheduled for period end',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildUpgradeButton(),
                        _buildCancelButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (usage != null) ...[
              const SizedBox(height: 16),
              _buildUsageSection(usage),
            ],
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _restorePurchases,
                child: const Text('Restore Purchases'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
