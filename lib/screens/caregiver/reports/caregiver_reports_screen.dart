import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/caregiver_report.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../models/medication_reminder.dart';
import '../../../repositories/report_repository.dart';
import '../../../repositories/reminder_repository.dart';
import '../../../services/confusion_detection_result_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/empty_state.dart';

class CaregiverReportsScreen extends StatefulWidget {
  const CaregiverReportsScreen({super.key});

  @override
  State<CaregiverReportsScreen> createState() => _CaregiverReportsScreenState();
}

class _CaregiverReportsScreenState extends State<CaregiverReportsScreen> {
  final _repository = ReportRepository();
  final _reminderRepository = ReminderRepository();
  final _uuid = const Uuid();
  CaregiverSession? _session;
  bool _isLoading = true;
  List<CaregiverReport> _reports = [];
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
    _loadReports();
  }

  Future<void> _loadReports() async {
    final session = _session ?? CaregiverSession.fallback();
    setState(() => _isLoading = true);
    final confusionAssessments = context
        .read<ConfusionDetectionResultService>()
        .getByPatientId(session.patientId);
    final reports = await _repository.getAll(session.patientId);
    final reminders = await _reminderRepository.getAll(session.patientId);
    if (mounted) {
      setState(() {
        _reports = reports;
        _confusionAssessments = confusionAssessments;
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Observation Log'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty && _confusionAssessments.isEmpty
              ? EmptyState(
                  title: 'No Logs Yet',
                  message:
                      'Record observations about ${(_session ?? CaregiverSession.fallback()).patientName}\'s mood, behavior, or incidents.',
                  icon: Icons.note_add_outlined,
                  actionLabel: 'Log Observation',
                  onAction: _showCreateReportDialog,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_confusionAssessments.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'AI Confusion Assessments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),
                      ..._confusionAssessments.take(5).map(_buildAssessmentCard),
                      const SizedBox(height: 12),
                    ],
                    if (_reminders.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Reminder Activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),
                      ..._reminders.take(4).map(_buildReminderCard),
                      const SizedBox(height: 12),
                    ],
                    ..._reports.map(_buildReportCard),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateReportDialog,
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Observation', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAssessmentCard(ConfusionDetectionResult result) {
    final riskColor = switch (result.riskLevel) {
      ConfusionRiskLevel.high => AppColors.errorColor,
      ConfusionRiskLevel.moderate => Colors.orange,
      ConfusionRiskLevel.mild => AppColors.primaryColor,
      ConfusionRiskLevel.stable => AppColors.secondaryColor,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    'AI ${result.riskLevel.name.toUpperCase()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: riskColor.withValues(alpha: 0.12),
                ),
                Text(
                  '${result.timestamp.month}/${result.timestamp.day} ${result.timestamp.hour}:${result.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.explanation,
              style: const TextStyle(fontSize: 14),
            ),
            if (result.detectedSignals.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Signals: ${result.detectedSignals.join(', ')}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(CaregiverReport report) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(report.category.displayName, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                ),
                Text(
                  '${report.timestamp.month}/${report.timestamp.day} ${report.timestamp.hour}:${report.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(report.note, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(MedicationReminder reminder) {
    final statusColor = switch (reminder.responseStatus) {
      ReminderResponseStatus.taken => AppColors.secondaryColor,
      ReminderResponseStatus.pending => AppColors.primaryColor,
      ReminderResponseStatus.snoozed => Colors.orange,
      ReminderResponseStatus.missed => AppColors.errorColor,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(
                    reminder.responseStatus.name.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                ),
                Text(
                  reminder.time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reminder.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              reminder.instructions ??
                  'Caregiver reminder scheduled on a ${reminder.repeatPattern} pattern.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateReportDialog() async {
    final session = _session ?? CaregiverSession.fallback();
    final noteController = TextEditingController();
    var category = ReportCategory.other;
    var visibleToDoctor = true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log Caregiver Observation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ReportCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ReportCategory.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observation note',
                      hintText: 'Describe what you noticed and what support may help.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: visibleToDoctor,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible to doctor later'),
                    onChanged: (value) {
                      setModalState(() => visibleToDoctor = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final note = noteController.text.trim();
                        if (note.isEmpty) {
                          return;
                        }

                        await _repository.create(
                          CaregiverReport(
                            id: _uuid.v4(),
                            patientId: session.patientId,
                            caregiverId: session.caregiverId,
                            category: category,
                            note: note,
                            timestamp: DateTime.now(),
                            visibleToDoctor: visibleToDoctor,
                          ),
                        );
                        if (mounted) {
                          Navigator.of(this.context).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Observation'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved == true) {
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Observation saved for ${session.patientName}.')),
        );
      }
    }
  }
}
