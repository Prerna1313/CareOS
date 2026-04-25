import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient/patient_contracts.dart';
import '../../providers/patient_session_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../services/patient_records_service.dart';
import '../../theme/app_colors.dart';

class PatientEventHistoryScreen extends StatelessWidget {
  const PatientEventHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final patientProfile = context.watch<PatientSessionProvider>().profile;

    if (patientProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceBright,
          title: const Text('Patient Records'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Open the patient dashboard first so local records can be loaded.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final recordsService = context.watch<PatientRecordsService>();
    final bundle = recordsService.buildBundle(
      profile: patientProfile,
      confusionState: context.watch<ReminderProvider>().currentConfusionState,
      activeReminder: context.watch<ReminderProvider>().currentReminder,
    );
    final observationDigest = recordsService.buildObservationDigest();
    final timeline = recordsService.buildTimeline(patientProfile.patientId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBright,
        title: Text(
          'Patient Records',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: timeline.isEmpty
          ? Center(
              child: Text(
                'No local patient records yet.',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BundleSummaryCard(
                  bundle: bundle,
                  observationDigest: observationDigest,
                ),
                const SizedBox(height: 18),
                ...timeline.map(
                  (record) =>
                      _TimelineCard(record: record, textTheme: textTheme),
                ),
              ],
            ),
    );
  }
}

class _BundleSummaryCard extends StatelessWidget {
  final PatientIntegrationBundle bundle;
  final Map<String, dynamic> observationDigest;

  const _BundleSummaryCard({
    required this.bundle,
    required this.observationDigest,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Integration Summary',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'This local bundle is what the caregiver and doctor modules can later consume.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(
                label: 'State',
                value: bundle.stateSnapshot.confusionLevel.name,
              ),
              _SummaryChip(
                label: 'Care Events',
                value: '${bundle.careEvents.length}',
              ),
              _SummaryChip(
                label: 'Memories',
                value: '${bundle.memoryRecords.length}',
              ),
              _SummaryChip(
                label: 'Interventions',
                value: '${bundle.interventionRecords.length}',
              ),
              _SummaryChip(
                label: 'Daily Summaries',
                value: '${bundle.dailySummaries.length}',
              ),
              _SummaryChip(
                label: 'Observations',
                value: '${observationDigest['totalObservations'] ?? 0}',
              ),
              _SummaryChip(
                label: 'Visual Concerns',
                value: '${observationDigest['concernCount'] ?? 0}',
              ),
            ],
          ),
          if ((observationDigest['topObjects'] as List<dynamic>? ?? const [])
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Frequent observed items',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (observationDigest['topObjects'] as List<dynamic>)
                  .map((item) => _MetaPill(label: item.toString()))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final PatientTimelineRecord record;
  final TextTheme textTheme;

  const _TimelineCard({required this.record, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final color = _colorForSeverity(record.severity);
    final timestamp = DateFormat('dd MMM, h:mm a').format(record.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForCategory(record.category), color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      timestamp,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  record.summary,
                  style: textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(label: record.category.toUpperCase()),
                    _MetaPill(label: record.source),
                    if (record.evidenceRefs.isNotEmpty)
                      _MetaPill(
                        label: '${record.evidenceRefs.length} evidence',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return const Color(0xFFE67E22);
      case 'low':
        return AppColors.secondary;
      case 'support':
        return AppColors.tertiary;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'confusion':
        return Icons.psychology_alt_rounded;
      case 'observation':
        return Icons.visibility_rounded;
      case 'reminder':
        return Icons.notifications_active_rounded;
      case 'memory':
        return Icons.photo_library_rounded;
      case 'intervention':
        return Icons.support_rounded;
      case 'daily_summary':
        return Icons.event_note_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}

class _MetaPill extends StatelessWidget {
  final String label;

  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
