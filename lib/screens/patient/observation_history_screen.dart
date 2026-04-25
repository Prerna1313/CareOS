import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/camera_event.dart';
import '../../models/memory_item.dart';
import '../../providers/memory_provider.dart';
import '../../providers/patient_session_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/camera_event_service.dart';
import '../../theme/app_colors.dart';

class ObservationHistoryScreen extends StatelessWidget {
  const ObservationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final events = context.watch<CameraEventService>().getAllEvents();

    return Scaffold(
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
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final event = events[index];
                return _ObservationCard(event: event);
              },
              separatorBuilder: (_, index) => const SizedBox(height: 14),
              itemCount: events.length,
            ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  final CameraEvent event;

  const _ObservationCard({required this.event});

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
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
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
