// lib/screens/weekly_recap_screen.dart
//
// Weekly Parent Recap: parent-facing 7-day summary of feeling check-ins,
// stories created, and Life Quests completed — all computed on-device by
// ParentRecapService. Lives behind the parent gate in Settings, next to the
// Parent Dashboard. The in-app view is free; the printable clinician handout
// shares the PDF-export premium gate (TierLimits.exportStories), mirroring
// the story-library export: free users see the action, tapping routes
// through the parent-gated paywall.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../providers/story_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/clinician_handout_pdf_service.dart';
import '../services/parent_recap_service.dart';
import '../subscription_screen.dart';
import '../theme/app_theme.dart';
import '../utils/paywall_gate.dart';
import '../widgets/app_card.dart';

class WeeklyRecapScreen extends ConsumerStatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  ConsumerState<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends ConsumerState<WeeklyRecapScreen> {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late Future<WeeklyRecapData> _recapFuture;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _recapFuture = _loadRecap();
  }

  Future<WeeklyRecapData> _loadRecap() async {
    final stories = await ref.read(storyListProvider.future);
    return ParentRecapService.buildWeeklyRecap(allStories: stories);
  }

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  String _fileStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Mirrors SavedStoriesScreen._exportPdf: free users are routed through
  /// the parent-gated paywall instead of the action silently doing nothing.
  Future<void> _exportHandout() async {
    final canExport = ref.read(subscriptionProvider).canExportStories;
    if (!canExport) {
      await showPaywallGated<void>(
        context: context,
        showActualPaywall: () async {
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
              fullscreenDialog: true,
            ),
          );
        },
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final recap = await _recapFuture;
      final bytes =
          await const ClinicianHandoutPdfService().buildHandout(recap: recap);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'weekly_recap_${_fileStamp(recap.weekEnd)}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not build the handout PDF.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canExport = ref.watch(subscriptionProvider).canExportStories;

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Recap')),
      body: FutureBuilder<WeeklyRecapData>(
        future: _recapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final recap = snapshot.data;
          if (recap == null) {
            return const Center(
              child: Text('Could not load this week\'s activity.'),
            );
          }
          return _buildRecap(context, recap, canExport);
        },
      ),
    );
  }

  Widget _buildRecap(
      BuildContext context, WeeklyRecapData recap, bool canExport) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '${_fmtDate(recap.weekStart)} – ${_fmtDate(recap.weekEnd)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _StatCard(
                count: recap.stories.length,
                label: recap.stories.length == 1 ? 'Story' : 'Stories'),
            const SizedBox(width: AppSpacing.md),
            _StatCard(
                count: recap.checkIns.length,
                label:
                    recap.checkIns.length == 1 ? 'Check-in' : 'Check-ins'),
            const SizedBox(width: AppSpacing.md),
            _StatCard(
                count: recap.questCompletions.length,
                label:
                    recap.questCompletions.length == 1 ? 'Quest' : 'Quests'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionHeader(context, 'Feelings this week'),
        AppCard(
          child: recap.topFeelings.isEmpty
              ? const _EmptySection(
                  'No check-ins yet. Feelings save automatically when your '
                  'child picks one while making a story, or saves one in the '
                  'Feelings Garden.')
              : Column(
                  children: [
                    for (final feeling in recap.topFeelings)
                      ListTile(
                        dense: true,
                        leading: Text(feeling.emoji,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(feeling.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Typical intensity ${feeling.avgIntensity.toStringAsFixed(1)} of 5'),
                        trailing: Text('×${feeling.count}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionHeader(context, 'Stories created'),
        AppCard(
          child: recap.stories.isEmpty
              ? const _EmptySection('No stories were created this week.')
              : Column(
                  children: [
                    for (final story in recap.stories)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.auto_stories_rounded,
                            color: AppColors.primary),
                        title: Text(
                            story.title.isNotEmpty
                                ? story.title
                                : 'Untitled story',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text([
                          if (story.theme.isNotEmpty) story.theme,
                          _fmtDate(story.createdAt),
                          if (story.practiced != null &&
                              story.practiced!.trim().isNotEmpty)
                            'practiced: ${story.practiced!.trim()}',
                        ].join(' · ')),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionHeader(context, 'Life Quests completed'),
        AppCard(
          child: recap.questCompletions.isEmpty
              ? const _EmptySection('No Life Quests were completed this week.')
              : Column(
                  children: [
                    for (final quest in recap.questCompletions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.flag_rounded,
                            color: AppColors.primary),
                        title: Text(
                            quest.title.isNotEmpty
                                ? quest.title
                                : quest.questId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(_fmtDate(quest.timestamp)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _exporting ? null : _exportHandout,
          icon: Icon(canExport ? Icons.print_rounded : Icons.lock_outline),
          label: Text(_exporting
              ? 'Building PDF…'
              : 'Share clinician handout (PDF)'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A one-page printable summary for a therapist, counselor, or '
          'teacher. Calculated on this device just now — nothing on this '
          'page is uploaded or shared by the app.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int count;
  final String label;

  const _StatCard({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              Text('$count',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey),
      ),
    );
  }
}
