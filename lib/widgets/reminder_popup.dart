import 'package:flutter/material.dart';
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
        return AppColors.error; // Often red/alert color
      case ReminderType.water:
        return AppColors.secondary; // Blue-ish
      case ReminderType.appointment:
        return AppColors.primary;
      case ReminderType.task:
        return AppColors.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _getColorForType();

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
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(),
                    color: color,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  reminder.title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Description
                Text(
                  reminder.description,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Primary Action: Done
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
                    'Done',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Secondary Action: Remind Later
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
                    'Remind me later',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tertiary Action: Ignore (Subtle)
                TextButton(
                  onPressed: onIgnore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Ignore',
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
