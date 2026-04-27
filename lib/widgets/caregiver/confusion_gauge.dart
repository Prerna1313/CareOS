import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class ConfusionGauge extends StatelessWidget {
  final double score; // 0 to 100
  final double size;

  const ConfusionGauge({
    super.key,
    required this.score,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    Color getRiskColor() {
      if (score <= 20) return AppColors.secondaryColor; // Stable
      if (score <= 45) return Colors.orange; // Mild
      if (score <= 75) return Colors.deepOrange; // Moderate
      return AppColors.errorColor; // High
    }

    String getRiskLabel() {
      if (score <= 20) return 'Stable';
      if (score <= 45) return 'Mild';
      if (score <= 75) return 'Moderate';
      return 'High Risk';
    }

    final color = getRiskColor();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toInt()}',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                getRiskLabel(),
                style: TextStyle(
                  fontSize: size * 0.1,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
