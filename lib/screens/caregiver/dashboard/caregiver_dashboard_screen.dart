import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/alert.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../models/safe_zone.dart';
import '../../../models/medication_reminder.dart';
import '../../../models/patient.dart';
import '../../../models/daily_summary.dart';
import '../../../repositories/patient_monitoring_repository.dart';
import '../../../repositories/reminder_repository.dart';
import '../../../repositories/safe_zone_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../services/backend_speech_result_service.dart';
import '../../../services/backend_video_result_service.dart';
import '../../../services/caregiver_alert_feed_service.dart';
import '../../../services/confusion_detection_result_service.dart';
import '../../../services/patient_location_service.dart';
import '../../../services/patient_records_service.dart';
import '../../../services/voice_orientation_service.dart';
import '../alerts/alerts_screen.dart';
import '../memory/memory_cue_management_screen.dart';
import '../team/care_team_screen.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/confusion_gauge.dart';
import '../../../widgets/caregiver/metric_card.dart';
import '../../../widgets/caregiver/section_header.dart';
import '../../../widgets/caregiver/status_chip.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  final _repository = PatientMonitoringRepository();
  final _reminderRepository = ReminderRepository();
  final _safeZoneRepository = SafeZoneRepository();
  final _locationService = PatientLocationService();
  final _alertFeedService = CaregiverAlertFeedService();
  Patient? _patient;
  DailySummary? _summary;

  @override
  Widget build(BuildContext context) {
    final session = CaregiverSessionScope.of(context);
    final confusionAssessment = context
        .read<ConfusionDetectionResultService>()
        .getLatestForPatient(session.patientId);
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      body: SafeArea(
        child: StreamBuilder<Patient?>(
          stream: _repository.getPatientStatusStream(
            session.patientId,
            fallbackName: session.patientName,
            fallbackCondition: session.condition,
            fallbackLocation: session.location,
          ),
          builder: (context, patientSnapshot) {
            return StreamBuilder<DailySummary?>(
              stream: _repository.getDailySummaryStream(
                session.patientId,
                fallbackPatientName: session.patientName,
              ),
              builder: (context, summarySnapshot) {
                if (patientSnapshot.connectionState == ConnectionState.waiting ||
                    summarySnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
                }

                _patient = patientSnapshot.data;
                _summary = summarySnapshot.data;

                if (_patient == null || _summary == null) {
                  return const Center(child: Text("Waiting for patient data...", style: TextStyle(color: Colors.grey)));
                }

                return FutureBuilder<List<MedicationReminder>>(
                  future: _reminderRepository.getAll(session.patientId),
                  builder: (context, reminderSnapshot) {
                    final reminders =
                        reminderSnapshot.data ?? const <MedicationReminder>[];
                    final safeZonesFuture = _safeZoneRepository.getAll(
                      session.patientId,
                    );
                    return FutureBuilder<List<SafeZone>>(
                      future: safeZonesFuture,
                      builder: (context, safeZoneSnapshot) {
                        final safeZones =
                            safeZoneSnapshot.data ?? const <SafeZone>[];
                        return FutureBuilder(
                          future: _locationService.getLatest(session.patientId),
                          builder: (context, locationSnapshot) {
                            final alerts = _alertFeedService.buildActiveAlerts(
                              patientId: session.patientId,
                              storedAlerts: const <Alert>[],
                              patient: _patient,
                              confusionAssessment: confusionAssessment,
                              reminders: reminders,
                              safeZones: safeZones,
                              latestLocationPing: locationSnapshot.data,
                              latestVideo: context
                                  .read<BackendVideoResultService>()
                                  .getLatestForPatient(session.patientId),
                              latestSpeech: context
                                  .read<BackendSpeechResultService>()
                                  .getLatestForPatient(session.patientId),
                            );
                            return _buildDashboardContent(
                              context,
                              confusionAssessment,
                              reminders,
                              alerts,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    ConfusionDetectionResult? confusionAssessment,
    List<MedicationReminder> reminders,
    List<Alert> alerts,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // Streams automatically refresh, but we keep this for manual sync requests if needed
      },
      color: AppColors.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildRiskGauge(confusionAssessment),
            const SizedBox(height: 24),
            _buildMetricsGrid(reminders),
            const SizedBox(height: 24),
            _buildAlertHighlights(alerts),
            const SizedBox(height: 24),
            _buildReminderOverview(reminders),
            const SizedBox(height: 24),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          child: const Icon(Icons.person, size: 30, color: AppColors.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _patient!.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  StatusChip(
                    label: _patient!.currentStatus.toUpperCase(),
                    icon: Icons.circle,
                    isPositive: _patient!.currentStatus == 'active',
                    isNeutral: false,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_patient!.age} yrs • ${_patient!.condition}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            final session = CaregiverSessionScope.of(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CaregiverSessionScope(
                  session: session,
                  child: const CareTeamScreen(),
                ),
              ),
            );
          },
          icon: const Icon(Icons.settings_outlined),
          color: AppColors.textColor,
        )
      ],
    );
  }

  Widget _buildRiskGauge(ConfusionDetectionResult? confusionAssessment) {
    final gaugeScore = confusionAssessment?.score ?? _summary!.confusionFrequency * 100;
    final subtitle = confusionAssessment?.explanation ??
        'Score based on recent activity, text, and routines.';
    final riskLabel = confusionAssessment?.riskLevel.name.toUpperCase() ?? 'ROUTINE';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confusion Risk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  riskLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          ConfusionGauge(score: gaugeScore, size: 100),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(List<MedicationReminder> reminders) {
    final nextReminder = _nextReminder(reminders);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Today\'s Summary'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            MetricCard(
              title: 'Medication',
              value: '${(_summary!.medicineAdherence * 100).toInt()}%',
              subtitle: nextReminder != null
                  ? 'Next ${nextReminder.time}'
                  : 'No upcoming reminder',
              icon: Icons.medication_outlined,
            ),
            MetricCard(
              title: 'Activity',
              value: _summary!.activityLevel,
              subtitle: '${_summary!.stepsToday} steps',
              icon: Icons.directions_walk,
              color: AppColors.secondaryColor,
            ),
            MetricCard(
              title: 'Engagement',
              value: '${_summary!.memoryCueEngagement} cues',
              subtitle: 'Interactions today',
              icon: Icons.touch_app_outlined,
              color: Colors.orange,
            ),
            MetricCard(
              title: 'Active Alerts',
              value: _summary!.alertCount.toString(),
              icon: Icons.notifications_active_outlined,
              color: AppColors.errorColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertHighlights(List<Alert> alerts) {
    final topAlerts = alerts.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alert Highlights',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (topAlerts.isEmpty)
            Text(
              'No high-priority caregiver alerts right now.',
              style: TextStyle(color: Colors.grey[700]),
            )
          else
            ...topAlerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notification_important_outlined,
                      size: 18,
                      color: alert.severity == AlertSeverity.high
                          ? AppColors.errorColor
                          : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert.message,
                            style: TextStyle(color: Colors.grey[700], height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final session = CaregiverSessionScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ActionBtn(
                icon: Icons.record_voice_over,
                label: 'Voice Cue',
                color: AppColors.primaryColor,
                onTap: () => _sendVoiceCue(context, session),
              ),
              _ActionBtn(
                icon: Icons.support_agent,
                label: 'Orientation',
                color: AppColors.secondaryColor,
                onTap: () => _triggerOrientationSupport(context, session),
              ),
              _ActionBtn(
                icon: Icons.add_photo_alternate,
                label: 'Add Memory',
                color: AppColors.tertiaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CaregiverSessionScope(
                        session: session,
                        child: const MemoryCueManagementScreen(),
                      ),
                    ),
                  );
                },
              ),
              _ActionBtn(
                icon: Icons.notifications_active,
                label: 'Alerts',
                color: AppColors.errorColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CaregiverSessionScope(
                        session: session,
                        child: const AlertsScreen(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderOverview(List<MedicationReminder> reminders) {
    final nextReminder = _nextReminder(reminders);
    final missedCount = reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.missed)
        .length;
    final snoozedCount = reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.snoozed)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reminder Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            nextReminder != null
                ? 'Next reminder: ${nextReminder.title} at ${nextReminder.time}'
                : 'No caregiver reminders scheduled yet.',
            style: TextStyle(color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReminderStatusChip(
                label: '${reminders.length} total',
                color: AppColors.primaryColor,
              ),
              _ReminderStatusChip(
                label: '$missedCount missed',
                color: AppColors.errorColor,
              ),
              _ReminderStatusChip(
                label: '$snoozedCount snoozed',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  MedicationReminder? _nextReminder(List<MedicationReminder> reminders) {
    if (reminders.isEmpty) return null;
    return reminders.firstWhere(
      (item) => item.isEnabled,
      orElse: () => reminders.first,
    );
  }

  Future<void> _sendVoiceCue(
    BuildContext context,
    CaregiverSession session,
  ) async {
    final recordsService = context.read<PatientRecordsService>();
    final now = DateTime.now();
    final phrase = VoiceOrientationService().getOrientationPhrase(
      name: session.patientName,
      timeOfDay: now.hour < 12 ? 'morning' : now.hour < 17 ? 'afternoon' : 'evening',
      location: session.location,
      dateStr: '${now.day}/${now.month}/${now.year}',
    );
    await recordsService.logIntervention(
      patientId: session.patientId,
      triggerType: 'caregiver_quick_action',
      interventionType: 'voice_cue',
      outcome: 'requested',
      notes: phrase,
    );
    await VoiceOrientationService().speak(phrase);
    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Voice cue sent to ${session.patientName}.')),
      );
    }
  }

  Future<void> _triggerOrientationSupport(
    BuildContext context,
    CaregiverSession session,
  ) async {
    final recordsService = context.read<PatientRecordsService>();
    await recordsService.logIntervention(
      patientId: session.patientId,
      triggerType: 'caregiver_quick_action',
      interventionType: 'orientation_prompt',
      outcome: 'requested',
      notes: 'Caregiver triggered orientation support remotely.',
    );
    if (!mounted) return;
    Navigator.pushNamed(this.context, AppRoutes.patientOrientationSupport);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ReminderStatusChip({required this.label, required this.color});

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
