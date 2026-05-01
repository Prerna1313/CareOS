import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../theme/app_colors.dart';
import 'severity_badge.dart';
import 'package:intl/intl.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onTap;

  const AlertCard({
    super.key,
    required this.alert,
    this.onAcknowledge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = alert.status == AlertStatus.active;
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? AppColors.errorColor.withValues(alpha: 0.5) : Colors.grey[200]!,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SeverityBadge(severity: alert.severity),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      DateFormat('MMM d, h:mm a').format(alert.timestamp),
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                alert.message,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              if (isActive && onAcknowledge != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onAcknowledge,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Acknowledge'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
