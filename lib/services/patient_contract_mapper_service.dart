import 'package:uuid/uuid.dart';

import '../models/camera_event.dart';
import '../models/confusion_event.dart';
import '../models/confusion_state.dart';
import '../models/memory_item.dart';
import '../models/my_day/daily_checkin_entry.dart';
import '../models/patient/backend_processing_models.dart';
import '../models/patient/patient_contracts.dart';
import '../models/patient/patient_profile.dart';
import '../models/reminder.dart';
import '../models/reminder_log.dart';

class PatientContractMapperService {
  final Uuid _uuid = const Uuid();

  PatientStateSnapshot buildStateSnapshot({
    required PatientProfile profile,
    required ConfusionState confusionState,
    Reminder? activeReminder,
    DateTime? lastInteractionAt,
  }) {
    return PatientStateSnapshot(
      patientId: profile.patientId,
      timestamp: DateTime.now(),
      confusionLevel: confusionState.level,
      activeReminder: activeReminder?.type,
      currentActivity: profile.currentActivity,
      lastInteractionAt: lastInteractionAt ?? profile.lastActiveAt,
      lastKnownContextSummary: profile.lastKnownContextSummary,
    );
  }

  PatientCareEvent fromCameraEvent(CameraEvent event, String patientId) {
    final hasConcern =
        event.concernLevel == 'medium' || event.concernLevel == 'high';
    final evidenceRefs = <String>[
      event.imagePath,
      ...event.detectedObjects,
      if (event.locationHint.trim().isNotEmpty &&
          event.locationHint.toLowerCase() != 'unknown')
        event.locationHint,
    ];

    return PatientCareEvent(
      eventId: event.id,
      patientId: patientId,
      type: 'observation',
      timestamp: event.analysisTimestamp ?? event.timestamp,
      severity: hasConcern
          ? event.concernLevel
          : event.detectedType == 'person'
          ? 'info'
          : 'low',
      summary: event.unusualObservation.trim().isNotEmpty
          ? '${event.note} ${event.unusualObservation}'.trim()
          : event.note.isNotEmpty
          ? event.note
          : 'Observed a ${event.detectedType} moment.',
      source: event.source,
      evidenceRefs: evidenceRefs,
    );
  }

  PatientCareEvent fromConfusionEvent(ConfusionEvent event) {
    return PatientCareEvent(
      eventId: event.id,
      patientId: event.patientId,
      type: 'confusion',
      timestamp: event.timestamp,
      severity: event.confusionLevel == ConfusionLevel.high ? 'high' : 'medium',
      summary: event.triggerReason,
      source: 'confusion_detection',
      evidenceRefs: [event.recentEventsSnapshot],
    );
  }

  PatientCareEvent fromReminderLog(ReminderLog log) {
    final severity = switch (log.actionTaken) {
      ReminderAction.ignore => 'medium',
      ReminderAction.remindLater => 'low',
      ReminderAction.done => 'info',
      ReminderAction.shown => 'info',
    };

    final summary = switch (log.actionTaken) {
      ReminderAction.ignore =>
        'A ${log.reminderType.name} reminder was ignored.',
      ReminderAction.remindLater =>
        'A ${log.reminderType.name} reminder was postponed.',
      ReminderAction.done =>
        'A ${log.reminderType.name} reminder was completed.',
      ReminderAction.shown => 'A ${log.reminderType.name} reminder was shown.',
    };

    return PatientCareEvent(
      eventId: log.id,
      patientId: log.patientId,
      type: 'reminder',
      timestamp: log.timestamp,
      severity: severity,
      summary: summary,
      source: 'reminder_log',
      evidenceRefs: [log.reminderId, log.reminderType.name],
    );
  }

  PatientMemoryRecord fromMemory(MemoryItem memory) {
    final peopleTags = memory.tags
        .where((tag) => tag.toLowerCase().contains('person'))
        .toList();
    final placeTags = memory.tags
        .where(
          (tag) =>
              tag.toLowerCase().contains('place') ||
              tag.toLowerCase().contains('home') ||
              tag.toLowerCase().contains('room'),
        )
        .toList();
    final mediaRefs = [
      if (memory.localImagePath != null) memory.localImagePath!,
      if (memory.remoteImageUrl != null) memory.remoteImageUrl!,
      if (memory.voiceNotePath != null) memory.voiceNotePath!,
    ];

    return PatientMemoryRecord(
      memoryId: memory.id,
      patientId: memory.patientId,
      memoryType: memory.type.name,
      title: memory.name,
      summary: memory.summary ?? memory.note ?? 'Memory saved for recall.',
      peopleTags: peopleTags,
      placeTags: placeTags,
      mediaRefs: mediaRefs,
      createdAt: memory.createdAt,
    );
  }

  PatientInterventionRecord buildIntervention({
    required String patientId,
    required String triggerType,
    required String interventionType,
    required String outcome,
    required String notes,
  }) {
    return PatientInterventionRecord(
      interventionId: _uuid.v4(),
      patientId: patientId,
      triggerType: triggerType,
      interventionType: interventionType,
      deliveredAt: DateTime.now(),
      outcome: outcome,
      notes: notes,
    );
  }

  PatientDailySummaryRecord fromDailyCheckin(
    DailyCheckinEntry entry,
    String patientId,
  ) {
    final diaryStatus = entry.answers.isEmpty ? 'draft' : 'completed';
    final engagementSummary = entry.socialInteraction
        ? 'Social interaction recorded'
        : entry.wentOut
        ? 'Routine engagement recorded'
        : 'Low external engagement recorded';
    return PatientDailySummaryRecord(
      patientId: patientId,
      date: entry.date,
      diaryStatus: diaryStatus,
      moodSummary: entry.mood,
      engagementSummary: engagementSummary,
      aiSummaryText: entry.summary,
    );
  }

  PatientCareEvent fromBackendVideoResult(BackendVideoProcessingResult result) {
    final severity = switch (result.fallAnalysis.riskLevel) {
      'high' => 'high',
      'medium' => 'medium',
      _ => result.movementAnalysis.movementRiskLevel == 'high'
          ? 'high'
          : result.movementAnalysis.movementRiskLevel == 'medium'
          ? 'medium'
          : 'info',
    };

    return PatientCareEvent(
      eventId: result.clipId,
      patientId: result.patientId,
      type: 'backend_video',
      timestamp: result.createdAt,
      severity: severity,
      summary: result.fallAnalysis.summary.isNotEmpty
          ? result.fallAnalysis.summary
          : result.movementAnalysis.summary,
      source: 'careos_backend_video',
      evidenceRefs: [
        result.gcsUri,
        result.sourceEventId,
        ...result.labels,
      ].where((item) => item.trim().isNotEmpty).toList(),
    );
  }

  PatientCareEvent fromBackendSpeechResult(BackendSpeechProcessingResult result) {
    final severity = switch (result.assessment.riskLevel) {
      'high' => 'high',
      'medium' => 'medium',
      _ => 'info',
    };

    return PatientCareEvent(
      eventId: result.requestId,
      patientId: result.patientId,
      type: 'backend_speech',
      timestamp: result.createdAt,
      severity: severity,
      summary: result.assessment.summary.isNotEmpty
          ? result.assessment.summary
          : 'Speech processing completed.',
      source: 'careos_backend_speech',
      evidenceRefs: [
        result.gcsUri,
        result.source,
        if (result.transcript.trim().isNotEmpty) result.transcript.trim(),
      ].where((item) => item.trim().isNotEmpty).toList(),
    );
  }
}
