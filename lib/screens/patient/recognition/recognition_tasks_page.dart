import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/memory_item.dart';
import '../../../models/recognition/recognition_task.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/patient_session_provider.dart';
import '../../../providers/recognition_provider.dart';
import '../../../theme/app_colors.dart';
import 'recognition_activity_screen.dart';

const _taskBackground = Color(0xFFFFF4E8);
const _taskSurface = Color(0xFFFFFCF7);
const _taskAccent = Color(0xFFC98942);
const _taskAccentSoft = Color(0xFFF6E1C7);
const _taskTextSoft = Color(0xFF7A654B);

class RecognitionTasksPage extends StatelessWidget {
  const RecognitionTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recognitionProvider = context.watch<RecognitionProvider>();
    final profile = context.watch<PatientSessionProvider>().profile;
    final digest = recognitionProvider.buildRecognitionDigest(
      profile?.patientId ?? 'patient_local_demo',
    );
    final dailyTasks = recognitionProvider.todayTasks
        .where(
          (task) => task.deliveryMode == RecognitionDeliveryMode.dailyPrompt,
        )
        .toList();
    final optionalTasks = recognitionProvider.optionalTasks
        .where(
          (task) =>
              task.deliveryMode != RecognitionDeliveryMode.confusionSupport,
        )
        .toList();

    return Scaffold(
      backgroundColor: _taskBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Recognition Tasks',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hello ${profile?.displayName ?? 'Friend'}, let\'s gently practice remembering familiar people and places.',
              style: textTheme.bodyLarge?.copyWith(
                color: _taskTextSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _ModeCard(
              title: 'Daily Memory Task',
              subtitle:
                  'A gentle daily prompt to help recognize family members or important places.',
              icon: Icons.today_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            _ModeCard(
              title: 'Confusion Support Task',
              subtitle:
                  'These appear during moments of confusion to show a familiar face or place.',
              icon: Icons.psychology_alt_rounded,
              color: AppColors.tertiary,
            ),
            const SizedBox(height: 14),
            _ModeCard(
              title: 'Optional Practice',
              subtitle:
                  'You can also open extra recognition activities anytime from this page.',
              icon: Icons.extension_rounded,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DigestChip(
                  label: 'Answers',
                  value: '${digest['totalAnswers'] ?? 0}',
                ),
                _DigestChip(
                  label: 'Correct',
                  value: '${digest['correctAnswers'] ?? 0}',
                ),
                _DigestChip(
                  label: 'Avg time',
                  value: '${digest['averageResponseTime'] ?? 0}s',
                ),
                _DigestChip(
                  label: 'Support tasks',
                  value: '${digest['confusionSupportCount'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TaskSection(title: 'Today\'s task', tasks: dailyTasks),
            const SizedBox(height: 20),
            _TaskSection(title: 'Optional practice', tasks: optionalTasks),
          ],
        ),
      ),
    );
  }
}

class _DigestChip extends StatelessWidget {
  final String label;
  final String value;

  const _DigestChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _taskSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _taskAccentSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: _taskTextSoft,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _taskTextSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  final String title;
  final List<RecognitionTask> tasks;

  const _TaskSection({required this.title, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _taskSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _taskAccentSoft),
            ),
            child: Text(
              'No tasks here right now. New recognition practice will appear as memories are added.',
              style: textTheme.bodyMedium?.copyWith(
                color: _taskTextSoft,
              ),
            ),
          )
        else
          ...tasks.map((task) => _RecognitionTaskCard(task: task)),
      ],
    );
  }
}

class _RecognitionTaskCard extends StatelessWidget {
  final RecognitionTask task;

  const _RecognitionTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final matches = context.read<MemoryProvider>().memories.where(
      (item) => item.id == task.memoryItemId,
    );
    final MemoryItem? memoryItem = matches.isEmpty ? null : matches.first;

    if (memoryItem == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _taskSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _taskAccentSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.questionText,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Practice type: ${task.deliveryMode.name}',
            style: textTheme.bodySmall?.copyWith(
              color: _taskTextSoft,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecognitionActivityScreen(task: task),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _taskAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start task'),
          ),
        ],
      ),
    );
  }
}
