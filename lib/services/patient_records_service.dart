import '../models/confusion_state.dart';
import '../models/camera_event.dart';
import '../models/patient/patient_contracts.dart';
import '../models/patient/patient_profile.dart';
import '../models/reminder.dart';
import 'camera_event_service.dart';
import 'confusion_event_service.dart';
import 'daily_checkin_service.dart';
import 'event_log_service.dart';
import 'memory_service.dart';
import 'patient_contract_mapper_service.dart';
import 'patient_intervention_service.dart';

class PatientRecordsService {
  final PatientContractMapperService _mapper;
  final EventLogService _eventLogService;
  final ConfusionEventService _confusionEventService;
  final CameraEventService _cameraEventService;
  final MemoryService _memoryService;
  final DailyCheckinService _dailyCheckinService;
  final PatientInterventionService _interventionService;

  PatientRecordsService({
    required PatientContractMapperService mapper,
    required EventLogService eventLogService,
    required ConfusionEventService confusionEventService,
    required CameraEventService cameraEventService,
    required MemoryService memoryService,
    required DailyCheckinService dailyCheckinService,
    required PatientInterventionService interventionService,
  }) : _mapper = mapper,
       _eventLogService = eventLogService,
       _confusionEventService = confusionEventService,
       _cameraEventService = cameraEventService,
       _memoryService = memoryService,
       _dailyCheckinService = dailyCheckinService,
       _interventionService = interventionService;

  PatientStateSnapshot buildStateSnapshot({
    required PatientProfile profile,
    required ConfusionState confusionState,
    Reminder? activeReminder,
  }) {
    return _mapper.buildStateSnapshot(
      profile: profile,
      confusionState: confusionState,
      activeReminder: activeReminder,
      lastInteractionAt: profile.lastActiveAt,
    );
  }

  List<PatientCareEvent> getCareEvents(String patientId) {
    final reminderEvents = _eventLogService
        .getAllEvents()
        .where((event) => event.patientId == patientId)
        .map(_mapper.fromReminderLog);
    final confusionEvents = _confusionEventService
        .getAllEvents()
        .where((event) => event.patientId == patientId)
        .map(_mapper.fromConfusionEvent);
    final observationEvents = _cameraEventService.getAllEvents().map(
      (event) => _mapper.fromCameraEvent(event, patientId),
    );

    final combined = [
      ...reminderEvents,
      ...confusionEvents,
      ...observationEvents,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return combined;
  }

  List<PatientMemoryRecord> getMemoryRecords(String patientId) {
    return _memoryService
        .getAllMemories()
        .where((memory) => memory.patientId == patientId)
        .map(_mapper.fromMemory)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PatientDailySummaryRecord> getDailySummaries(String patientId) {
    return _dailyCheckinService
        .getAllEntries()
        .map((entry) => _mapper.fromDailyCheckin(entry, patientId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<PatientInterventionRecord> getInterventions(String patientId) {
    return _interventionService.getByPatientId(patientId);
  }

  Future<void> logIntervention({
    required String patientId,
    required String triggerType,
    required String interventionType,
    required String outcome,
    required String notes,
  }) {
    final record = _mapper.buildIntervention(
      patientId: patientId,
      triggerType: triggerType,
      interventionType: interventionType,
      outcome: outcome,
      notes: notes,
    );
    return _interventionService.logIntervention(record);
  }

  PatientIntegrationBundle buildBundle({
    required PatientProfile profile,
    required ConfusionState confusionState,
    Reminder? activeReminder,
  }) {
    return PatientIntegrationBundle(
      generatedAt: DateTime.now(),
      stateSnapshot: buildStateSnapshot(
        profile: profile,
        confusionState: confusionState,
        activeReminder: activeReminder,
      ),
      careEvents: getCareEvents(profile.patientId),
      memoryRecords: getMemoryRecords(profile.patientId),
      interventionRecords: getInterventions(profile.patientId),
      dailySummaries: getDailySummaries(profile.patientId),
    );
  }

  CameraEvent? findLatestObjectSighting(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return null;

    final aliases = _queryAliases(normalizedQuery);
    final events = _cameraEventService.getAllEvents()
      ..sort(
        (a, b) => (b.analysisTimestamp ?? b.timestamp).compareTo(
          a.analysisTimestamp ?? a.timestamp,
        ),
      );

    for (final event in events) {
      final haystack = [
        event.note.toLowerCase(),
        event.locationHint.toLowerCase(),
        event.unusualObservation.toLowerCase(),
        ...event.detectedObjects.map((item) => item.toLowerCase()),
      ];
      final matched = aliases.any(
        (alias) => haystack.any((text) => text.contains(alias)),
      );
      if (matched) {
        return event;
      }
    }
    return null;
  }

  Map<String, dynamic> buildObservationDigest() {
    final events = _cameraEventService.getAllEvents();
    final concernCount = events
        .where(
          (event) =>
              event.concernLevel == 'medium' || event.concernLevel == 'high',
        )
        .length;
    final objectCounts = <String, int>{};
    for (final event in events) {
      for (final object in event.detectedObjects) {
        objectCounts.update(object, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final topObjects = objectCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalObservations': events.length,
      'concernCount': concernCount,
      'topObjects': topObjects.take(5).map((entry) => entry.key).toList(),
    };
  }

  Map<String, dynamic> buildBehaviorInsights() {
    final events = _cameraEventService.getAllEvents()
      ..sort(
        (a, b) => (b.analysisTimestamp ?? b.timestamp).compareTo(
          a.analysisTimestamp ?? a.timestamp,
        ),
      );
    if (events.isEmpty) {
      return {
        'riskLevel': 'low',
        'headline': 'No recent visual concerns',
        'patterns': <String>[],
        'shouldAutoSupport': false,
      };
    }

    final recentEvents = events.take(12).toList();
    final concernEvents = recentEvents
        .where(
          (event) =>
              event.concernLevel == 'medium' || event.concernLevel == 'high',
        )
        .toList();
    final unknownLocationCount = recentEvents
        .where((event) => event.locationHint.toLowerCase() == 'unknown')
        .length;
    final repeatedLocationCounts = <String, int>{};
    for (final event in recentEvents) {
      final key = event.locationHint.toLowerCase();
      if (key != 'unknown' && key.trim().isNotEmpty) {
        repeatedLocationCounts.update(
          key,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final patterns = <String>[];
    if (concernEvents.length >= 2) {
      patterns.add('Multiple unusual observations were recorded recently.');
    }
    if (unknownLocationCount >= 4) {
      patterns.add(
        'Several observations had unclear location context, which may suggest disorientation.',
      );
    }
    final repeatedLocation = repeatedLocationCounts.entries
        .where((entry) => entry.value >= 3)
        .map((entry) => entry.key)
        .toList();
    if (repeatedLocation.isNotEmpty) {
      patterns.add(
        'Repeated observations around ${repeatedLocation.first} may need a quick check-in.',
      );
    }

    final riskLevel = concernEvents.any((event) => event.concernLevel == 'high')
        ? 'high'
        : patterns.isNotEmpty
        ? 'medium'
        : 'low';

    return {
      'riskLevel': riskLevel,
      'headline': switch (riskLevel) {
        'high' => 'Visual check-in recommended now',
        'medium' => 'Gentle support may help',
        _ => 'Recent observations look calm',
      },
      'patterns': patterns,
      'shouldAutoSupport': riskLevel != 'low',
    };
  }

  List<PatientTimelineRecord> buildTimeline(String patientId) {
    final careEvents = getCareEvents(patientId)
        .map(
          (event) => PatientTimelineRecord(
            id: event.eventId,
            patientId: event.patientId,
            category: event.type,
            title: _careEventTitle(event),
            summary: event.summary,
            severity: event.severity,
            timestamp: event.timestamp,
            source: event.source,
            evidenceRefs: event.evidenceRefs,
          ),
        )
        .toList();
    final memories = getMemoryRecords(patientId)
        .map(
          (record) => PatientTimelineRecord(
            id: record.memoryId,
            patientId: record.patientId,
            category: 'memory',
            title: record.title,
            summary: record.summary,
            severity: 'info',
            timestamp: record.createdAt,
            source: 'memory_store',
            evidenceRefs: record.mediaRefs,
          ),
        )
        .toList();
    final interventions = getInterventions(patientId)
        .map(
          (record) => PatientTimelineRecord(
            id: record.interventionId,
            patientId: record.patientId,
            category: 'intervention',
            title: _interventionTitle(record),
            summary: record.notes,
            severity: 'support',
            timestamp: record.deliveredAt,
            source: record.interventionType,
            evidenceRefs: const [],
          ),
        )
        .toList();
    final summaries = getDailySummaries(patientId)
        .map(
          (record) => PatientTimelineRecord(
            id: 'daily_${record.date.toIso8601String()}',
            patientId: record.patientId,
            category: 'daily_summary',
            title: 'Daily reflection',
            summary: record.aiSummaryText.isNotEmpty
                ? record.aiSummaryText
                : record.engagementSummary,
            severity: 'info',
            timestamp: record.date,
            source: 'my_day',
            evidenceRefs: const [],
          ),
        )
        .toList();

    final timeline = [
      ...careEvents,
      ...memories,
      ...interventions,
      ...summaries,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return timeline;
  }

  String _careEventTitle(PatientCareEvent event) {
    switch (event.type) {
      case 'confusion':
        return 'Confusion detected';
      case 'observation':
        return 'Observation captured';
      case 'reminder':
        return 'Reminder activity';
      default:
        return 'Patient event';
    }
  }

  String _interventionTitle(PatientInterventionRecord record) {
    switch (record.interventionType) {
      case 'sos':
        return 'SOS support';
      case 'orientation_prompt':
        return 'Orientation support';
      case 'confusion_popup':
        return 'Confusion support shown';
      default:
        return 'Patient intervention';
    }
  }

  List<String> _queryAliases(String query) {
    switch (query) {
      case 'specs':
      case 'glasses':
        return ['specs', 'glasses', 'spectacles', 'eyeglasses'];
      case 'diary':
      case 'notebook':
        return ['diary', 'notebook', 'journal'];
      case 'medicine':
      case 'medicines':
        return ['medicine', 'tablet', 'pill', 'medication'];
      default:
        return [query];
    }
  }
}
