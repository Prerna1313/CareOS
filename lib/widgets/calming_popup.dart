import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/voice_orientation_service.dart';

class CalmingPopup extends StatefulWidget {
  final VoidCallback onDismiss;
  final String patientName;
  final String caregiverName;
  final String caregiverRelationship;
  final String locationLabel;
  final List<String> familiarPeople;

  const CalmingPopup({
    super.key,
    required this.onDismiss,
    this.patientName = 'Friend',
    this.caregiverName = 'Rahul',
    this.caregiverRelationship = 'daughter',
    this.locationLabel = 'home',
    this.familiarPeople = const [],
  });

  @override
  State<CalmingPopup> createState() => _CalmingPopupState();
}

class _CalmingPopupState extends State<CalmingPopup> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final timeString = DateFormat.jm().format(now);
    final dayString = DateFormat('EEEE, MMMM d').format(now);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 24),
                Text(
                  timeString,
                  style: textTheme.displayMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  dayString,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Caregiver Reassurance Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isPlaying)
                            const SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.outlineVariant,
                            child: Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hi ${widget.patientName}, it\'s ${widget.caregiverName}.',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You are at ${widget.locationLabel}. You are safe and your ${widget.caregiverRelationship} is here to support you.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                      if (widget.familiarPeople.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: widget.familiarPeople
                              .map(
                                (person) => Chip(
                                  label: Text(person),
                                  avatar: CircleAvatar(
                                    child: Text(
                                      person.isNotEmpty
                                          ? person.substring(0, 1).toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Simple steps',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. Sit down and breathe slowly.\n2. Look around your room.\n3. Tap the memory or help button if you need support.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.onPrimaryContainer,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _isPlaying = !_isPlaying);
                          if (_isPlaying) {
                            VoiceOrientationService().speak(
                              "Hi ${widget.patientName}, it's ${widget.caregiverName}. You are at ${widget.locationLabel}. You are safe and your ${widget.caregiverRelationship} is here with you.",
                            );
                          } else {
                            VoiceOrientationService().stop();
                          }
                        },
                        icon: Icon(
                          _isPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_fill_rounded,
                        ),
                        label: Text(
                          _isPlaying ? 'Stop Listening' : 'Listen to Rahul',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isPlaying
                              ? AppColors.error
                              : AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      VoiceOrientationService().stop();
                      widget.onDismiss();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Okay',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
