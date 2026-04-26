import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../theme/app_colors.dart';

class ReminderPopup extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onDone;
  final VoidCallback onRemindLater;
  final VoidCallback onIgnore;

  const ReminderPopup({
    super.key,
    required this.reminder,
    required this.onDone,
    required this.onRemindLater,
    required this.onIgnore,
  });

  IconData _getIconForType() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return Icons.medication_rounded;
      case ReminderType.water:
        return Icons.water_drop_rounded;
      case ReminderType.task:
        return Icons.check_circle_outline_rounded;
      case ReminderType.appointment:
        return Icons.event_rounded;
    }
  }

  Color _getColorForType() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return const Color(0xFFB85C38);
      case ReminderType.water:
        return const Color(0xFF2C7FB8);
      case ReminderType.appointment:
        return AppColors.primary;
      case ReminderType.task:
        return const Color(0xFF5F8F2D);
    }
  }

  String _titleLabel() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return 'Medicine time';
      case ReminderType.water:
        return 'Hydration reminder';
      case ReminderType.appointment:
        return 'Upcoming appointment';
      case ReminderType.task:
        return 'Gentle task reminder';
    }
  }

  String _supportLine() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return 'Take one calm step now. Your medicine routine helps the day stay steady.';
      case ReminderType.water:
        return 'A small sip of water can help you feel refreshed and comfortable.';
      case ReminderType.appointment:
        return 'You only need to focus on the next small step for this appointment.';
      case ReminderType.task:
        return 'One simple task at a time can help the day feel clearer.';
    }
  }

  String _primaryLabel() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return 'Medicine taken';
      case ReminderType.water:
        return 'I had water';
      case ReminderType.appointment:
        return 'I am ready';
      case ReminderType.task:
        return 'Done now';
    }
  }

  String _secondaryLabel() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return 'Take it in a little while';
      case ReminderType.water:
        return 'Remind me again soon';
      case ReminderType.appointment:
        return 'Remind me a bit later';
      case ReminderType.task:
        return 'Do it a little later';
    }
  }

  String _helperTitle() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return 'Helpful steps';
      case ReminderType.water:
        return 'Quick support';
      case ReminderType.appointment:
        return 'Next step';
      case ReminderType.task:
        return 'Simple plan';
    }
  }

  List<String> _helperSteps() {
    switch (reminder.type) {
      case ReminderType.medicine:
        return const [
          'Sit comfortably and take a slow breath.',
          'Keep water nearby before taking the medicine.',
          'Tap the button when you are done.',
        ];
      case ReminderType.water:
        return const [
          'Take a small sip first.',
          'Pause for a moment if you need to.',
          'Tap the button after you finish.',
        ];
      case ReminderType.appointment:
        return const [
          'Look at the time first.',
          'Focus only on getting ready for this one plan.',
          'Use the reminder again if you need more time.',
        ];
      case ReminderType.task:
        return const [
          'Start with the first small step.',
          'You do not need to rush.',
          'Tap done when the task is finished.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _getColorForType();
    final scheduledLabel = DateFormat('h:mm a').format(reminder.scheduledTime);
    final helperSteps = _helperSteps();

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
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForType(),
                        color: color,
                        size: 42,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleLabel(),
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Scheduled for $scheduledLabel',
                              style: textTheme.labelLarge?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  reminder.title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  reminder.description,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    _supportLine(),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurface,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _helperTitle(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...helperSteps.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.circle_rounded,
                                color: color,
                                size: 10,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  step,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.4,
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
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _primaryLabel(),
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                OutlinedButton(
                  onPressed: onRemindLater,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: BorderSide(color: AppColors.outlineVariant, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    _secondaryLabel(),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: onIgnore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Skip for now',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
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
