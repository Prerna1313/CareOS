import '../models/caregiver_report.dart';
import '../models/alert.dart';
import '../models/confusion_detection_result.dart';
import '../models/medication_reminder.dart';
import '../models/progress_report.dart';
import '../models/safe_zone.dart';
import '../services/caregiver_report_service.dart';
import '../services/confusion_detection_result_service.dart';
import '../services/firestore/firestore_caregiver_service.dart';
import '../services/mock_data_provider.dart';
import '../services/patient_session_service.dart';
import 'alert_repository.dart';
import 'reminder_repository.dart';
import 'safe_zone_repository.dart';
import 'base_repository.dart';

class ReportRepository implements BaseRepository<CaregiverReport> {
  final _service = CaregiverReportService();
  final _firestoreService = FirestoreCaregiverService();
  final _alertRepository = AlertRepository();
  final _reminderRepository = ReminderRepository();
  final _safeZoneRepository = SafeZoneRepository();
  final _confusionResultService = ConfusionDetectionResultService();
  final _patientSessionService = PatientSessionService();

  @override
  Future<void> create(CaregiverReport item) async {
    await _service.save(item);
    await _firestoreService.syncCaregiverReport(item);
  }

  @override
  Future<void> delete(String id) async {
    await _service.delete(id);
    await _firestoreService.deleteCaregiverReport(id);
  }

  @override
  Future<List<CaregiverReport>> getAll(String patientId) async {
    var reports = await _service.getAll(patientId);
    if (reports.isNotEmpty) {
      return reports;
    }
    final remoteReports = (await _firestoreService.getAllCaregiverReports())
        .where((report) => report.patientId == patientId)
        .toList();
    if (remoteReports.isNotEmpty) {
      for (final report in remoteReports) {
        await _service.save(report);
      }
      reports = remoteReports;
      return reports;
    }
    return MockDataProvider.getMockCaregiverReports(patientId: patientId);
  }

  @override
  Future<CaregiverReport?> getById(String id) => _service.getById(id);

  @override
  Future<void> update(CaregiverReport item) async {
    await _service.save(item);
    await _firestoreService.syncCaregiverReport(item);
  }

  Future<ProgressReport> generateProgressReport(
    String patientId,
    String caregiverId,
  ) async {
    final alerts = await _alertRepository.getAlertHistory(patientId);
    final activeAlerts = await _alertRepository.getActiveAlerts(patientId);
    final reminders = await _reminderRepository.getAll(patientId);
    final safeZones = await _safeZoneRepository.getAll(patientId);
    final confusionAssessments = _confusionResultService.getByPatientId(patientId);
    final profile = _patientSessionService.getProfileById(patientId);

    final highAlerts =
        activeAlerts.where((alert) => alert.severity == AlertSeverity.high).length +
        alerts.where((alert) => alert.severity == AlertSeverity.high).length;
    final mediumAlerts =
        activeAlerts.where((alert) => alert.severity == AlertSeverity.medium).length +
        alerts.where((alert) => alert.severity == AlertSeverity.medium).length;
    final lowAlerts =
        activeAlerts.where((alert) => alert.severity == AlertSeverity.low).length +
        alerts.where((alert) => alert.severity == AlertSeverity.low).length;

    final takenCount = reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.taken)
        .length;
    final medicationAdherence = reminders.isEmpty
        ? 0.0
        : takenCount / reminders.length;
    final activeSafeZones = safeZones.where((zone) => zone.isActive).length;
    final latestConfusion = confusionAssessments.isNotEmpty
        ? confusionAssessments.first
        : null;

    final recommendations = _buildRecommendations(
      latestConfusion: latestConfusion,
      reminders: reminders,
      safeZones: safeZones,
      patientName: profile?.displayName,
    );

    return ProgressReport(
      id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      generatedBy: caregiverId,
      generatedAt: DateTime.now(),
      dateRange: 'Past 7 Days',
      alertSummary: {'high': highAlerts, 'medium': mediumAlerts, 'low': lowAlerts},
      medicationAdherence: medicationAdherence,
      locationSafety: activeSafeZones == 0
          ? 'No active safe zones configured yet.'
          : '$activeSafeZones safe zone(s) active for monitoring.',
      recommendedActions: recommendations,
    );
  }

  List<String> _buildRecommendations({
    required ConfusionDetectionResult? latestConfusion,
    required List<MedicationReminder> reminders,
    required List<SafeZone> safeZones,
    required String? patientName,
  }) {
    final results = <String>[];

    final missedCount = reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.missed)
        .length;
    if (missedCount > 0) {
      results.add(
        'Review medication routine for ${patientName ?? 'the patient'}: $missedCount reminder(s) are marked missed.',
      );
    }

    if (latestConfusion != null &&
        (latestConfusion.riskLevel == ConfusionRiskLevel.high ||
            latestConfusion.riskLevel == ConfusionRiskLevel.moderate)) {
      results.add(
        'Follow up on recent confusion assessment and reinforce orientation cues for ${patientName ?? 'the patient'}.',
      );
    }

    if (safeZones.where((zone) => zone.isActive == true).isEmpty) {
      results.add('Add at least one active safe zone for wandering alerts.');
    }

    if (results.isEmpty) {
      results.add(
        'Continue the current routine and keep monitoring reminders, confusion trends, and observation notes.',
      );
    }

    return results;
  }
}
