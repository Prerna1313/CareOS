import 'package:flutter/material.dart';
import '../../../models/caregiver_session.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/section_header.dart';

class CognitiveEngagementScreen extends StatelessWidget {
  const CognitiveEngagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = CaregiverSessionScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(title: const Text('Cognitive Engagement'), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Recent Game Scores'),
            _buildGameCard('Face Matching', 80, AppColors.primaryColor),
            _buildGameCard('Recall & Arrange', 65, Colors.orange),
            _buildGameCard('Daily Diary', 100, AppColors.secondaryColor),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Memory Posts Review'),
            _buildMemoryPostPreview(session.patientName),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(String name, int score, Color color) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Played 2 hours ago'),
        trailing: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: score / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryPostPreview(String patientName) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Center(
              child: Icon(
                Icons.photo_library_outlined,
                size: 40,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$patientName\'s favorite recall moment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Prepared as a gentle recall prompt', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('Use as Recall Prompt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
