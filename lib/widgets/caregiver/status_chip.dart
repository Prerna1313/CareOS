import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool isPositive;
  final bool isNeutral;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.isPositive = true,
    this.isNeutral = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNeutral 
        ? Colors.grey 
        : (isPositive ? AppColors.secondaryColor : AppColors.errorColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
