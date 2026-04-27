import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../theme/app_colors.dart';

class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (severity) {
      case AlertSeverity.low:
        color = Colors.blue;
        text = 'LOW';
        break;
      case AlertSeverity.medium:
        color = Colors.orange;
        text = 'MEDIUM';
        break;
      case AlertSeverity.high:
        color = AppColors.errorColor;
        text = 'HIGH';
        break;
      case AlertSeverity.critical:
        color = Colors.red[900]!;
        text = 'CRITICAL';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
