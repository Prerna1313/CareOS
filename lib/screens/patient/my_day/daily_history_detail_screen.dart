import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_colors.dart';
import '../../../../models/my_day/daily_checkin_entry.dart';

class DailyHistoryDetailScreen extends StatelessWidget {
  final DailyCheckinEntry entry;

  const DailyHistoryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(entry.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(dateStr, style: textTheme.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cognitive Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DAILY SUMMARY",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.summary.isNotEmpty ? entry.summary : "No summary generated for this day.",
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Signals Section
            _SectionTitle(title: "Insights"),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InsightChip(
                  label: "Mood: ${entry.mood}",
                  icon: Icons.face_rounded,
                  color: AppColors.tertiary,
                ),
                _InsightChip(
                  label: entry.wentOut ? "Went Out" : "Stayed In",
                  icon: entry.wentOut ? Icons.directions_walk_rounded : Icons.home_rounded,
                  color: AppColors.primary,
                ),
                _InsightChip(
                  label: entry.socialInteraction ? "Socially Active" : "Quiet Day",
                  icon: Icons.people_rounded,
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Detailed Answers
            _SectionTitle(title: "Your Conversation"),
            const SizedBox(height: 16),
            ...entry.answers.map((resp) => _ResponseTile(resp: resp, textTheme: textTheme)),

            const SizedBox(height: 32),

            // Journal Notes
            if (entry.textField1.isNotEmpty || entry.textField2.isNotEmpty) ...[
              _SectionTitle(title: "Journal Notes"),
              const SizedBox(height: 16),
              if (entry.textField1.isNotEmpty)
                _NoteBox(title: "Extra Thoughts", content: entry.textField1),
              if (entry.textField2.isNotEmpty)
                const SizedBox(height: 12),
              if (entry.textField2.isNotEmpty)
                _NoteBox(title: "Important Notes", content: entry.textField2),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InsightChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ResponseTile extends StatelessWidget {
  final dynamic resp;
  final TextTheme textTheme;

  const _ResponseTile({required this.resp, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resp.question,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            resp.isSkipped ? "Skipped" : resp.answer,
            style: textTheme.bodyLarge?.copyWith(
              color: resp.isSkipped ? AppColors.onSurfaceVariant.withValues(alpha: 0.5) : AppColors.onSurface,
              fontStyle: resp.isSkipped ? FontStyle.italic : FontStyle.normal,
              fontSize: 17,
            ),
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String title;
  final String content;

  const _NoteBox({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(height: 1.5, fontSize: 16)),
        ],
      ),
    );
  }
}
