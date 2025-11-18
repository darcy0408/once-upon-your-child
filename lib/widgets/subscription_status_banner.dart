import 'package:flutter/material.dart';

import '../models/subscription_status.dart';
import '../services/subscription_service.dart';

class SubscriptionStatusBanner extends StatelessWidget {
  final Stream<SubscriptionStatus>? statusStream;
  final SubscriptionStatus? initialStatus;
  final SubscriptionService? subscriptionService;

  const SubscriptionStatusBanner({
    super.key,
    this.statusStream,
    this.initialStatus,
    this.subscriptionService,
  });

  @override
  Widget build(BuildContext context) {
    final service = subscriptionService ?? SubscriptionService();
    final stream = statusStream ?? service.statusStream;
    final seed = initialStatus ?? service.currentStatus;

    return StreamBuilder<SubscriptionStatus>(
      stream: stream,
      initialData: seed,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) {
          return _buildPlaceholder(context);
        }
        return _buildBanner(context, status);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Card(
      color: Colors.grey.shade100,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 12),
            Text('Syncing subscription status...'),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, SubscriptionStatus status) {
    final tierColor = status.tier.color;
    final textTheme = Theme.of(context).textTheme;
    final periodLabel = status.cancelAtPeriodEnd
        ? 'Cancels on ${_formatDate(status.currentPeriodEnd)}'
        : 'Renews on ${_formatDate(status.currentPeriodEnd)}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 60,
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current plan: ${status.tier.displayName}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${_formatStatus(status.status)}',
                    style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    periodLabel,
                    style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String raw) {
    if (raw.isEmpty) return 'Unknown';
    final parts = raw.split('_');
    return parts
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'TBD';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
