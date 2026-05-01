import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/patient_session_provider.dart';
import '../../services/patient_records_service.dart';
import '../../services/voice_orientation_service.dart';
import '../../theme/app_colors.dart';

class OrientationSupportScreen extends StatelessWidget {
  const OrientationSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientSessionProvider>().profile;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final timeStr = DateFormat.jm().format(now);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBright,
        title: const Text('Orientation Support'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are safe at ${profile?.homeLabel ?? 'Home'}.',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This is ${profile?.caregiverName ?? 'your caregiver'} (${profile?.caregiverRelationship ?? 'support person'}).',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'It is $timeStr on $dateStr.',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.lastKnownContextSummary ??
                        'Take a slow breath. You are okay.',
                    style: textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final phrase = VoiceOrientationService().getOrientationPhrase(
                  name: profile?.displayName ?? 'Friend',
                  timeOfDay: _timeOfDay(now.hour),
                  location: profile?.homeLabel ?? 'home',
                  dateStr: dateStr,
                );
                await context.read<PatientRecordsService>().logIntervention(
                  patientId: profile?.patientId ?? 'patient_local_demo',
                  triggerType: 'orientation_screen',
                  interventionType: 'orientation_prompt',
                  outcome: 'spoken',
                  notes: 'Spoken orientation support was played.',
                );
                await VoiceOrientationService().speak(phrase);
              },
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Play Orientation Aloud'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await context.read<PatientRecordsService>().logIntervention(
                  patientId: profile?.patientId ?? 'patient_local_demo',
                  triggerType: 'orientation_screen',
                  interventionType: 'support_response',
                  outcome: 'patient_reassured',
                  notes:
                      'The patient confirmed they feel better after orientation support.',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Support update saved for your caregiver.'),
                  ),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('I Feel Better'),
            ),
            const Spacer(),
            Text(
              'Next step: drink some water, sit comfortably, or look at a familiar memory.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _timeOfDay(int hour) {
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}
