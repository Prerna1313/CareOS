import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/camera_event.dart';
import '../../models/memory_item.dart';
import '../../providers/memory_provider.dart';
import '../../providers/patient_session_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/camera_event_service.dart';
import '../../services/patient_records_service.dart';
import '../../theme/app_colors.dart';

class ObservationHistoryScreen extends StatelessWidget {
  const ObservationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final events = context.watch<CameraEventService>().getAllEvents();
    final profile = context.watch<PatientSessionProvider>().profile;
    final textScale = profile?.textScaleFactor ?? 1.0;
    final highContrast = profile?.highContrastEnabled ?? false;
    final grouped = _groupEvents(events);
    final visualDigest = context.watch<PatientRecordsService>().buildVisualBehaviorDigest();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceBright,
          title: Text(
            'Observation History',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Find an item',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.patientFindItem),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ),
        body: events.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No observations yet. Capture a moment from Observe to review it here later.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ObservationSummaryCard(
                    events: events,
                    highContrast: highContrast,
                    visualDigest: visualDigest,
                  ),
                  const SizedBox(height: 18),
                  ...grouped.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...entry.value.map(
                            (event) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ObservationCard(
                                event: event,
                                highContrast: highContrast,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Map<String, List<CameraEvent>> _groupEvents(List<CameraEvent> events) {
    final today = <CameraEvent>[];
    final earlier = <CameraEvent>[];
    final now = DateTime.now();

    for (final event in events) {
      final timestamp = event.analysisTimestamp ?? event.timestamp;
      final isToday =
          timestamp.year == now.year &&
          timestamp.month == now.month &&
          timestamp.day == now.day;
      if (isToday) {
        today.add(event);
      } else {
        earlier.add(event);
      }
    }

    final grouped = <String, List<CameraEvent>>{};
    if (today.isNotEmpty) grouped['Today'] = today;
    if (earlier.isNotEmpty) grouped['Earlier'] = earlier;
    return grouped;
  }
}

class _ObservationCard extends StatelessWidget {
  final CameraEvent event;
  final bool highContrast;

  const _ObservationCard({required this.event, required this.highContrast});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detectedLabel = switch (event.detectedType) {
      'person' => 'Person detected',
      'place' => 'Place detected',
      _ => 'Observed event',
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highContrast
              ? AppColors.onSurface
              : AppColors.outlineVariant.withValues(alpha: 0.2),
          width: highContrast ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (File(event.imagePath).existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.file(
                File(event.imagePath),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _typeColor(
                          event.detectedType,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        detectedLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: _typeColor(event.detectedType),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (event.hasFace)
                      Text(
                        '${event.faceCount} face${event.faceCount == 1 ? '' : 's'}',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.note.isNotEmpty
                      ? event.note
                      : 'A captured observation is ready to review.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurface,
                    height: 1.45,
                  ),
                ),
                if (event.locationHint.toLowerCase() != 'unknown') ...[
                  const SizedBox(height: 10),
                  Text(
                    'Likely location: ${event.locationHint}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (event.detectedObjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: event.detectedObjects
                        .map((object) => _TagChip(label: object))
                        .toList(),
                  ),
                ],
                if (event.unusualObservation.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Attention note: ${event.unusualObservation}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _saveToMemories(context),
                  icon: const Icon(Icons.bookmark_added_rounded),
                  label: const Text('Save as memory'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToMemories(BuildContext context) async {
    final memoryProvider = context.read<MemoryProvider>();
    final sessionProvider = context.read<PatientSessionProvider>();
    final title = switch (event.detectedType) {
      'person' => 'Observed familiar person',
      'place' => 'Observed place',
      _ => 'Observed moment',
    };

    await memoryProvider.addMemory(
      name: title,
      note: event.note.isNotEmpty
          ? event.note
          : 'Saved from observation history.',
      type: switch (event.detectedType) {
        'person' => MemoryType.person,
        'place' => MemoryType.place,
        _ => MemoryType.event,
      },
      localImagePath: event.imagePath,
      tags: [
        event.detectedType,
        'observation_history',
        ...event.detectedObjects,
      ],
      location: event.locationHint.toLowerCase() != 'unknown'
          ? event.locationHint
          : sessionProvider.profile?.homeLabel,
      summary: event.note,
      confidence: event.concernLevel == 'high'
          ? 0.98
          : event.hasFace
          ? 0.95
          : 0.8,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Observation saved to memories.')),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'person':
        return AppColors.secondary;
      case 'place':
        return AppColors.primary;
      default:
        return AppColors.tertiary;
    }
  }
}

class _ObservationSummaryCard extends StatelessWidget {
  final List<CameraEvent> events;
  final bool highContrast;
  final Map<String, dynamic> visualDigest;

  const _ObservationSummaryCard({
    required this.events,
    required this.highContrast,
    required this.visualDigest,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final concernCount = events
        .where((event) => event.concernLevel == 'high' || event.concernLevel == 'medium')
        .length;
    final latestObjects = <String>{};
    for (final event in events.take(5)) {
      latestObjects.addAll(event.detectedObjects.take(2));
    }

    final visualRisk = visualDigest['riskLevel'] as String? ?? 'low';
    final visualColor = switch (visualRisk) {
      'high' => AppColors.error,
      'medium' => const Color(0xFFE67E22),
      _ => AppColors.secondary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: highContrast
              ? AppColors.onSurface
              : AppColors.outlineVariant.withValues(alpha: 0.16),
          width: highContrast ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observation timeline',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            concernCount > 0
                ? '$concernCount recent observations may need extra attention.'
                : 'Recent observations look calm and organized.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: visualColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: visualColor.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visualDigest['statusLabel'] as String? ?? 'Calm',
                  style: textTheme.titleMedium?.copyWith(
                    color: visualColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  visualDigest['headline'] as String? ??
                      'Recent visual patterns look steady.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                    height: 1.4,
                  ),
                ),
                if ((visualDigest['wanderingHeadline'] as String?)?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 10),
                  Text(
                    visualDigest['wanderingHeadline'] as String,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TimelineStatChip(
                label: 'Total',
                value: '${events.length}',
                icon: Icons.history_rounded,
              ),
              _TimelineStatChip(
                label: 'Attention',
                value: '$concernCount',
                icon: Icons.warning_amber_rounded,
              ),
              _TimelineStatChip(
                label: 'Switches',
                value: '${visualDigest['locationSwitches'] ?? 0}',
                icon: Icons.swap_horiz_rounded,
              ),
              if ((visualDigest['shortIntervalSwitches'] as int? ?? 0) > 0)
                _TimelineStatChip(
                  label: 'Quick moves',
                  value: '${visualDigest['shortIntervalSwitches']}',
                  icon: Icons.directions_walk_rounded,
                ),
              if ((visualDigest['repeatedLoopCount'] as int? ?? 0) > 0)
                _TimelineStatChip(
                  label: 'Loops',
                  value: '${visualDigest['repeatedLoopCount']}',
                  icon: Icons.sync_alt_rounded,
                ),
              if ((visualDigest['possibleFallCount'] as int? ?? 0) > 0)
                _TimelineStatChip(
                  label: 'Possible falls',
                  value: '${visualDigest['possibleFallCount']}',
                  icon: Icons.personal_injury_rounded,
                ),
              if ((visualDigest['riskySceneCount'] as int? ?? 0) > 0)
                _TimelineStatChip(
                  label: 'Risky scenes',
                  value: '${visualDigest['riskySceneCount']}',
                  icon: Icons.report_problem_rounded,
                ),
              if (latestObjects.isNotEmpty)
                _TimelineStatChip(
                  label: 'Seen often',
                  value: latestObjects.first,
                  icon: Icons.search_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TimelineStatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
