import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../models/daily_summary.dart';
import '../../../models/medication_reminder.dart';
import '../../../repositories/patient_monitoring_repository.dart';
import '../../../repositories/reminder_repository.dart';
import '../../../services/confusion_detection_result_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/section_header.dart';

class PatientSummaryScreen extends StatefulWidget {
  const PatientSummaryScreen({super.key});

  @override
  State<PatientSummaryScreen> createState() => _PatientSummaryScreenState();
}

class _PatientSummaryScreenState extends State<PatientSummaryScreen> {
  final _repository = PatientMonitoringRepository();
  final _reminderRepository = ReminderRepository();
  CaregiverSession? _session;
  bool _isLoading = true;
  DailySummary? _summary;
  List<ConfusionDetectionResult> _confusionAssessments = [];
  List<MedicationReminder> _reminders = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CaregiverSessionScope.of(context);
    if (_session?.patientId == session.patientId) {
      return;
    }
    _session = session;
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final session = _session ?? CaregiverSession.fallback();
    final confusionAssessments = context
        .read<ConfusionDetectionResultService>()
        .getByPatientId(session.patientId);
    final summary = await _repository.getDailySummary(
      session.patientId,
      fallbackPatientName: session.patientName,
    );
    final reminders = await _reminderRepository.getAll(session.patientId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _confusionAssessments = confusionAssessments;
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(title: const Text('Daily Summary'), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartSection(),
            const SizedBox(height: 24),
            _buildAdherenceSection(),
            const SizedBox(height: 24),
            _buildReminderSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    final chartSpots = _buildConfusionSpots();
    final latestAssessment =
        _confusionAssessments.isNotEmpty ? _confusionAssessments.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Confusion Trend (7 Days)'),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0, maxX: 6, minY: 0, maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: chartSpots,
                  isCurved: true,
                  color: AppColors.primaryColor,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.primaryColor.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
        ),
        if (latestAssessment != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest AI assessment: ${latestAssessment.riskLevel.name.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(latestAssessment.explanation),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdherenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Adherence & Mood'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _AdherenceRow(label: 'Medication', value: _summary!.medicineAdherence, color: AppColors.secondaryColor),
                const SizedBox(height: 12),
                _AdherenceRow(label: 'Routine', value: _summary!.routineAdherence, color: AppColors.primaryColor),
                const SizedBox(height: 16),
                const Divider(),
                if (_confusionAssessments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('AI Confusion Score', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${_confusionAssessments.first.score.round()}%',
                        style: const TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _confusionAssessments.first.memoryCueNeeded
                        ? 'Memory cue support is currently recommended.'
                        : 'No additional memory cue support is currently suggested.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overall Mood', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        _summary!.moodSummary,
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildReminderSection() {
    final nextReminder = _reminders.isNotEmpty ? _reminders.first : null;
    final takenCount = _reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.taken)
        .length;
    final pendingCount = _reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.pending)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Reminder Snapshot'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nextReminder != null
                      ? 'Next caregiver reminder: ${nextReminder.title}'
                      : 'No caregiver reminders scheduled yet.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nextReminder != null
                      ? '${nextReminder.time} • ${nextReminder.repeatPattern}'
                      : 'Add reminders from the caregiver reminder manager to show them here.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryChip(
                      label: '$takenCount taken',
                      color: AppColors.secondaryColor,
                    ),
                    _SummaryChip(
                      label: '$pendingCount pending',
                      color: AppColors.primaryColor,
                    ),
                    _SummaryChip(
                      label: '${_reminders.length} total',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _buildConfusionSpots() {
    if (_confusionAssessments.isEmpty) {
      final baseline = (_summary?.confusionFrequency ?? 0.3) * 100;
      return List.generate(7, (index) => FlSpot(index.toDouble(), baseline));
    }

    final ordered = _confusionAssessments.take(7).toList().reversed.toList();
    final padded = <double>[
      for (final assessment in ordered) assessment.score,
    ];
    while (padded.length < 7) {
      padded.insert(0, padded.isNotEmpty ? padded.first : (_summary?.confusionFrequency ?? 0.3) * 100);
    }

    return List.generate(
      7,
      (index) => FlSpot(index.toDouble(), padded[index].clamp(0, 100).toDouble()),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdherenceRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AdherenceRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 8,
        ),
      ],
    );
  }
}
