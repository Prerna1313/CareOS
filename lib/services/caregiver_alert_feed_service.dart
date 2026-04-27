import '../models/alert.dart';
import '../models/confusion_detection_result.dart';
import '../models/medication_reminder.dart';
import '../models/patient.dart';
import '../models/patient/backend_processing_models.dart';
import '../models/patient_location_ping.dart';
import '../models/safe_zone.dart';
import 'caregiver_geofence_service.dart';

class CaregiverAlertFeedService {
  final CaregiverGeofenceService _geofenceService = CaregiverGeofenceService();

  List<Alert> buildActiveAlerts({
    required String patientId,
    required List<Alert> storedAlerts,
    required Patient? patient,
    required ConfusionDetectionResult? confusionAssessment,
    required List<MedicationReminder> reminders,
    required List<SafeZone> safeZones,
    required PatientLocationPing? latestLocationPing,
    required BackendVideoProcessingResult? latestVideo,
    required BackendSpeechProcessingResult? latestSpeech,
  }) {
    final alerts = <Alert>[
      ...storedAlerts.where((alert) => alert.status == AlertStatus.active),
    ];

    _addIfMissing(
      alerts,
      _buildConfusionAlert(confusionAssessment),
    );
    _addIfMissing(
      alerts,
      _buildInactivityAlert(patient),
    );
    _addIfMissing(
      alerts,
      _buildMissedMedicationAlert(patientId, reminders),
    );
    _addIfMissing(
      alerts,
      _buildSafeZoneAlert(patient, safeZones, latestLocationPing),
    );
    _addIfMissing(
      alerts,
      _buildBehaviorAlert(patientId, patient, latestVideo, latestSpeech),
    );

    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  List<Alert> buildHistoryAlerts({
    required String patientId,
    required List<Alert> storedAlerts,
    required Patient? patient,
    required ConfusionDetectionResult? confusionAssessment,
    required List<MedicationReminder> reminders,
    required List<SafeZone> safeZones,
    required PatientLocationPing? latestLocationPing,
    required BackendVideoProcessingResult? latestVideo,
    required BackendSpeechProcessingResult? latestSpeech,
  }) {
    final activeIds = buildActiveAlerts(
      patientId: patientId,
      storedAlerts: storedAlerts,
      patient: patient,
      confusionAssessment: confusionAssessment,
      reminders: reminders,
      safeZones: safeZones,
      latestLocationPing: latestLocationPing,
      latestVideo: latestVideo,
      latestSpeech: latestSpeech,
    ).map((alert) => alert.id).toSet();

    final history = <Alert>[
      ...storedAlerts.where((alert) => alert.status != AlertStatus.active),
    ];

    for (final generated in [
      _buildConfusionAlert(confusionAssessment),
      _buildInactivityAlert(patient),
      _buildMissedMedicationAlert(patientId, reminders),
      _buildSafeZoneAlert(patient, safeZones, latestLocationPing),
      _buildBehaviorAlert(patientId, patient, latestVideo, latestSpeech),
    ]) {
      if (generated == null || activeIds.contains(generated.id)) {
        continue;
      }
      history.add(
        generated.copyWith(
          status: AlertStatus.resolved,
          resolvedAt: DateTime.now(),
        ),
      );
    }

    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return history;
  }

  void _addIfMissing(List<Alert> alerts, Alert? alert) {
    if (alert == null) return;
    if (alerts.any((existing) => existing.id == alert.id)) return;
    alerts.add(alert);
  }

  Alert? _buildConfusionAlert(ConfusionDetectionResult? assessment) {
    if (assessment == null ||
        (assessment.riskLevel != ConfusionRiskLevel.high &&
            assessment.riskLevel != ConfusionRiskLevel.moderate)) {
      return null;
    }

    final severity = assessment.riskLevel == ConfusionRiskLevel.high
        ? AlertSeverity.high
        : AlertSeverity.medium;

    return Alert(
      id: 'ai_confusion_${assessment.patientId}_${assessment.timestamp.toIso8601String()}',
      patientId: assessment.patientId,
      type: AlertType.confusion,
      severity: severity,
      timestamp: assessment.timestamp,
      title: 'Confusion detected',
      message: assessment.explanation,
      explanation: assessment.detectedSignals.isEmpty
          ? 'AI confusion assessment flagged meaningful support needs.'
          : 'Detected signals: ${assessment.detectedSignals.join(', ')}.',
      recommendedAction: assessment.memoryCueNeeded
          ? 'Open orientation support and reinforce a familiar memory cue.'
          : 'Check in calmly and simplify the next step.',
    );
  }

  Alert? _buildInactivityAlert(Patient? patient) {
    if (patient == null) return null;
    final idleDuration = DateTime.now().difference(patient.lastActiveAt);
    if (idleDuration.inMinutes < 45) {
      return null;
    }

    final severity = idleDuration.inHours >= 2
        ? AlertSeverity.high
        : AlertSeverity.medium;
    return Alert(
      id: 'idle_${patient.id}_${patient.lastActiveAt.toIso8601String()}',
      patientId: patient.id,
      type: AlertType.inactivity,
      severity: severity,
      timestamp: patient.lastActiveAt,
      title: 'Inactivity / no response',
      message:
          'No strong app interaction has been seen for ${idleDuration.inMinutes} minutes.',
      explanation:
          'This may indicate the patient is resting, disconnected, or not responding to prompts.',
      recommendedAction: 'Check monitoring status and send an orientation or voice cue.',
    );
  }

  Alert? _buildMissedMedicationAlert(
    String patientId,
    List<MedicationReminder> reminders,
  ) {
    final missed = reminders
        .where((item) => item.responseStatus == ReminderResponseStatus.missed)
        .toList();
    if (missed.isEmpty) {
      return null;
    }

    final latest = missed.first;
    return Alert(
      id: 'missed_med_${patientId}_${latest.id}',
      patientId: patientId,
      type: AlertType.missedReminder,
      severity: missed.length >= 2 ? AlertSeverity.high : AlertSeverity.medium,
      timestamp: latest.lastResponseAt ?? DateTime.now(),
      title: 'Missed medication',
      message:
          '${missed.length} caregiver reminder(s) are currently marked missed.',
      explanation: 'Latest missed reminder: ${latest.title} at ${latest.time}.',
      recommendedAction: 'Confirm whether medication was taken and reissue support if needed.',
    );
  }

  Alert? _buildSafeZoneAlert(
    Patient? patient,
    List<SafeZone> safeZones,
    PatientLocationPing? latestLocationPing,
  ) {
    final activeZones = safeZones.where((zone) => zone.isActive).toList();
    if (activeZones.isEmpty) {
      return null;
    }

    if (latestLocationPing != null) {
      final evaluation = _geofenceService.evaluate(
        latestPing: latestLocationPing,
        safeZones: activeZones,
      );
      if (evaluation.insideAnySafeZone) {
        return null;
      }
      return Alert(
        id: 'safe_zone_${latestLocationPing.patientId}_${latestLocationPing.id}',
        patientId: latestLocationPing.patientId,
        type: AlertType.geofence,
        severity: AlertSeverity.high,
        timestamp: latestLocationPing.capturedAt,
        title: 'Patient left safe zone',
        message: evaluation.summary,
        explanation:
            'Tracked location ${latestLocationPing.latitude.toStringAsFixed(5)}, ${latestLocationPing.longitude.toStringAsFixed(5)} from ${latestLocationPing.source}.',
        recommendedAction:
            'Review tracked location immediately and contact the patient if this seems unexpected.',
      );
    }

    if (patient == null) return null;
    final location = patient.currentLocationSummary?.trim().toLowerCase();
    if (location == null || location.isEmpty) {
      return null;
    }

    final insideZone = activeZones.any(
      (zone) =>
          location.contains(zone.name.toLowerCase()) ||
          zone.type.name == 'home' && location.contains('home'),
    );

    if (insideZone) {
      return null;
    }

    return Alert(
      id: 'safe_zone_${patient.id}_${location.replaceAll(' ', '_')}',
      patientId: patient.id,
      type: AlertType.geofence,
      severity: AlertSeverity.high,
      timestamp: patient.lastActiveAt,
      title: 'Patient left safe zone',
      message:
          'Current location "${patient.currentLocationSummary}" does not match any active safe zone.',
      explanation:
          'Safe zones configured: ${activeZones.map((zone) => zone.name).join(', ')}.',
      recommendedAction: 'Review location immediately and contact the patient if this seems unexpected.',
    );
  }

  Alert? _buildBehaviorAlert(
    String patientId,
    Patient? patient,
    BackendVideoProcessingResult? latestVideo,
    BackendSpeechProcessingResult? latestSpeech,
  ) {
    final wandering = patient?.currentStatus.toLowerCase() == 'wandering';
    final videoRisk = latestVideo?.movementAnalysis.movementRiskLevel.toLowerCase();
    final fallRisk = latestVideo?.fallAnalysis.riskLevel.toLowerCase();
    final speechRisk = latestSpeech?.assessment.riskLevel.toLowerCase();

    final shouldTrigger = wandering ||
        videoRisk == 'medium' ||
        videoRisk == 'high' ||
        fallRisk == 'medium' ||
        fallRisk == 'high' ||
        speechRisk == 'medium' ||
        speechRisk == 'high';
    if (!shouldTrigger) {
      return null;
    }

    final severity =
        fallRisk == 'high' || videoRisk == 'high' || speechRisk == 'high'
        ? AlertSeverity.high
        : AlertSeverity.medium;
    final notes = <String>[
      if (wandering) 'Patient status indicates wandering.',
      if (latestVideo != null) latestVideo.movementAnalysis.summary,
      if (latestSpeech != null) latestSpeech.assessment.summary,
    ].where((item) => item.trim().isNotEmpty).toList();

    return Alert(
      id: 'behavior_$patientId',
      patientId: patientId,
      type: AlertType.routineDeviation,
      severity: severity,
      timestamp: latestVideo?.createdAt ?? latestSpeech?.createdAt ?? patient?.lastActiveAt ?? DateTime.now(),
      title: 'Unusual behavior',
      message: notes.isNotEmpty
          ? notes.first
          : 'Recent monitoring signals suggest behavior worth checking.',
      explanation: notes.skip(1).join(' '),
      recommendedAction: 'Open live monitoring and review recent observation context.',
    );
  }
}
