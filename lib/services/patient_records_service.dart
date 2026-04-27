import '../models/confusion_state.dart';
import '../models/camera_event.dart';
import '../models/patient/patient_contracts.dart';
import '../models/patient/patient_profile.dart';
import '../models/reminder.dart';
import '../models/reminder_log.dart';
import '../models/interaction_signal.dart';
import 'camera_event_service.dart';
import 'backend_speech_result_service.dart';
import 'backend_video_result_service.dart';
import 'confusion_detection_result_service.dart';
import 'confusion_event_service.dart';
import 'daily_checkin_service.dart';
import 'event_log_service.dart';
import 'interaction_signal_service.dart';
import 'memory_service.dart';
import 'patient_contract_mapper_service.dart';
import 'patient_intervention_service.dart';
import 'speech_signal_service.dart';

class PatientRecordsService {
  final PatientContractMapperService _mapper;
  final EventLogService _eventLogService;
  final ConfusionEventService _confusionEventService;
  final ConfusionDetectionResultService _confusionDetectionResultService;
  final CameraEventService _cameraEventService;
  final MemoryService _memoryService;
  final DailyCheckinService _dailyCheckinService;
  final PatientInterventionService _interventionService;
  final InteractionSignalService _interactionSignalService;
  final SpeechSignalService _speechSignalService;
  final BackendVideoResultService _backendVideoResultService;
  final BackendSpeechResultService _backendSpeechResultService;

  PatientRecordsService({
    required PatientContractMapperService mapper,
    required EventLogService eventLogService,
    required ConfusionEventService confusionEventService,
    required ConfusionDetectionResultService confusionDetectionResultService,
    required CameraEventService cameraEventService,
    required MemoryService memoryService,
    required DailyCheckinService dailyCheckinService,
    required PatientInterventionService interventionService,
    required InteractionSignalService interactionSignalService,
    required SpeechSignalService speechSignalService,
    required BackendVideoResultService backendVideoResultService,
    required BackendSpeechResultService backendSpeechResultService,
  }) : _mapper = mapper,
       _eventLogService = eventLogService,
       _confusionEventService = confusionEventService,
       _confusionDetectionResultService = confusionDetectionResultService,
       _cameraEventService = cameraEventService,
       _memoryService = memoryService,
       _dailyCheckinService = dailyCheckinService,
       _interventionService = interventionService,
       _interactionSignalService = interactionSignalService,
       _speechSignalService = speechSignalService,
       _backendVideoResultService = backendVideoResultService,
       _backendSpeechResultService = backendSpeechResultService;

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
    final confusionAssessments = _confusionDetectionResultService
        .getByPatientId(patientId)
        .map(_mapper.fromConfusionAssessment);
    final observationEvents = _cameraEventService.getAllEvents().map(
      (event) => _mapper.fromCameraEvent(event, patientId),
    );
    final backendVideoEvents = _backendVideoResultService
        .getByPatientId(patientId)
        .map(_mapper.fromBackendVideoResult);
    final backendSpeechEvents = _backendSpeechResultService
        .getByPatientId(patientId)
        .map(_mapper.fromBackendSpeechResult);

    final combined = [
      ...reminderEvents,
      ...confusionEvents,
      ...confusionAssessments,
      ...observationEvents,
      ...backendVideoEvents,
      ...backendSpeechEvents,
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
      final normalizedObjects = event.detectedObjects
          .map(_normalizedObjectLabel)
          .toSet()
          .toList();
      final haystack = [
        event.note.toLowerCase(),
        _normalizedLocationHint(event.locationHint),
        event.unusualObservation.toLowerCase(),
        ...event.detectedObjects.map((item) => item.toLowerCase()),
        ...normalizedObjects,
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
        final normalized = _normalizedObjectLabel(object);
        objectCounts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final topObjects = objectCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalObservations': events.length,
      'concernCount': concernCount,
      'topObjects': topObjects.take(5).map((entry) => entry.key).toList(),
      'latestLocationHint': events.isNotEmpty
          ? _normalizedLocationHint(events.first.locationHint)
          : '',
      'stableItemSightings': buildObjectLocationDigest().take(5).toList(),
    };
  }

  List<Map<String, dynamic>> buildObjectLocationDigest() {
    final events = _cameraEventService.getAllEvents()
      ..sort(
        (a, b) => (b.analysisTimestamp ?? b.timestamp).compareTo(
          a.analysisTimestamp ?? a.timestamp,
        ),
      );
    final latestByObject = <String, Map<String, dynamic>>{};

    for (final event in events) {
      final normalizedLocation = _normalizedLocationHint(event.locationHint);
      for (final rawObject in event.detectedObjects) {
        final normalizedObject = _normalizedObjectLabel(rawObject);
        if (normalizedObject.isEmpty || latestByObject.containsKey(normalizedObject)) {
          continue;
        }
        latestByObject[normalizedObject] = {
          'object': normalizedObject,
          'location': normalizedLocation,
          'timestamp': event.analysisTimestamp ?? event.timestamp,
          'imagePath': event.imagePath,
          'note': event.note,
        };
      }
    }

    final digest = latestByObject.values.toList()
      ..sort(
        (a, b) => (b['timestamp'] as DateTime).compareTo(
          a['timestamp'] as DateTime,
        ),
      );
    return digest;
  }

  Map<String, dynamic> buildVisualBehaviorDigest() {
    final events = _cameraEventService.getAllEvents()
      ..sort(
        (a, b) => (b.analysisTimestamp ?? b.timestamp).compareTo(
          a.analysisTimestamp ?? a.timestamp,
        ),
      );
    if (events.isEmpty) {
      return {
        'riskLevel': 'low',
        'statusLabel': 'Calm',
        'headline': 'No recent visual concerns',
        'guidance': 'Recent observations are not showing unusual visual patterns.',
        'patterns': <String>[],
        'locationSwitches': 0,
        'unknownLocationCount': 0,
        'highConcernCount': 0,
        'possibleWandering': false,
      };
    }

    final recentEvents = events.take(16).toList();
    final locationSwitches = _countLocationSwitches(recentEvents);
    final unknownLocationCount = recentEvents
        .where((event) => _normalizedLocationHint(event.locationHint) == 'unknown')
        .length;
    final highConcernCount = recentEvents
        .where((event) => event.concernLevel == 'high')
        .length;
    final mediumConcernCount = recentEvents
        .where((event) => event.concernLevel == 'medium')
        .length;
    final repeatedConcernNotes = recentEvents
        .where((event) => event.unusualObservation.trim().isNotEmpty)
        .length;
    final personHeavyMoments = recentEvents
        .where((event) => event.detectedType == 'person' && event.faceCount > 0)
        .length;
    final possibleFallEvents = recentEvents
        .where(_looksLikePossibleFall)
        .toList();
    final riskySceneEvents = recentEvents
        .where(_looksLikeRiskyScene)
        .toList();
    final wanderingDigest = _buildWanderingDigest(recentEvents);

    final possibleWandering =
        locationSwitches >= 4 && unknownLocationCount >= 2;
    final possibleWanderingTrend =
        possibleWandering ||
        (wanderingDigest['possibleWandering'] as bool? ?? false);
    String riskLevel = 'low';
    if (possibleFallEvents.isNotEmpty ||
        riskySceneEvents.length >= 2 ||
        highConcernCount >= 2 ||
        possibleWanderingTrend ||
        (locationSwitches >= 5 && repeatedConcernNotes >= 2)) {
      riskLevel = 'high';
    } else if (mediumConcernCount >= 2 ||
        riskySceneEvents.isNotEmpty ||
        locationSwitches >= 3 ||
        unknownLocationCount >= 3 ||
        (wanderingDigest['shortIntervalSwitches'] as int? ?? 0) >= 2 ||
        repeatedConcernNotes >= 2) {
      riskLevel = 'medium';
    }

    final patterns = <String>[];
    if (possibleFallEvents.isNotEmpty) {
      patterns.add(
        'One or more recent observations may suggest a fall or collapse-like posture.',
      );
    }
    if (riskySceneEvents.isNotEmpty) {
      patterns.add(
        'Recent observations include possible environmental safety risks.',
      );
    }
    if (possibleWanderingTrend) {
      patterns.add(
        'Frequent location switching with unclear context may suggest wandering-like movement.',
      );
    }
    if ((wanderingDigest['repeatedLoopCount'] as int? ?? 0) > 0) {
      patterns.add(
        'Recent observations suggest a repeated movement loop between places.',
      );
    }
    if ((wanderingDigest['shortIntervalSwitches'] as int? ?? 0) >= 2) {
      patterns.add(
        'Several location changes happened within short time gaps.',
      );
    }
    if (unknownLocationCount >= 3) {
      patterns.add(
        'Several recent observations could not be grounded to a clear place.',
      );
    }
    if (highConcernCount >= 1 || mediumConcernCount >= 2) {
      patterns.add(
        'Visual concern notes appeared repeatedly in recent observations.',
      );
    }
    if (personHeavyMoments >= 4) {
      patterns.add(
        'Many recent observations involved people, which may be useful for familiar-face cueing.',
      );
    }

    return {
      'riskLevel': riskLevel,
      'statusLabel': switch (riskLevel) {
        'high' => 'Safety review suggested',
        'medium' => 'Attention needed',
        _ => 'Calm',
      },
      'headline': switch (riskLevel) {
        'high' => 'Recent visual patterns may need an immediate safety check.',
        'medium' => 'Some visual patterns may need extra attention.',
        _ => 'Recent visual patterns look steady.',
      },
      'guidance': switch (riskLevel) {
        'high' =>
          'A quick orientation cue and a safety review could help with these recent observation patterns.',
        'medium' =>
          'Review a recent observation or use a familiar memory cue to stay grounded.',
        _ => 'Recent observations show a steady pattern without strong concern.',
      },
      'patterns': patterns,
      'locationSwitches': locationSwitches,
      'unknownLocationCount': unknownLocationCount,
      'highConcernCount': highConcernCount,
      'mediumConcernCount': mediumConcernCount,
      'possibleWandering': possibleWanderingTrend,
      'possibleFallCount': possibleFallEvents.length,
      'riskySceneCount': riskySceneEvents.length,
      'wanderingStatusLabel': wanderingDigest['statusLabel'],
      'wanderingHeadline': wanderingDigest['headline'],
      'shortIntervalSwitches': wanderingDigest['shortIntervalSwitches'],
      'repeatedLoopCount': wanderingDigest['repeatedLoopCount'],
      'distinctVisitedLocations': wanderingDigest['distinctVisitedLocations'],
    };
  }

  Map<String, dynamic> buildDailyDigest({
    required String patientId,
    required ConfusionState confusionState,
    Reminder? activeReminder,
  }) {
    final reminderLogs = _eventLogService
        .getAllEvents()
        .where((event) => event.patientId == patientId)
        .toList();
    final completedReminders = reminderLogs
        .where((event) => event.actionTaken == ReminderAction.done)
        .length;
    final ignoredReminders = reminderLogs
        .where((event) => event.actionTaken == ReminderAction.ignore)
        .length;
    final confusionEvents = _confusionEventService
        .getAllEvents()
        .where((event) => event.patientId == patientId)
        .length;
    final observations = _cameraEventService.getAllEvents();
    final recentItems = <String>{};
    for (final event in observations.take(5)) {
      recentItems.addAll(event.detectedObjects.take(2));
    }
    final dailyEntries = _dailyCheckinService.getAllEntries();
    final latestEntry = dailyEntries.isNotEmpty ? dailyEntries.first : null;

    return {
      'completedReminders': completedReminders,
      'ignoredReminders': ignoredReminders,
      'confusionMoments': confusionEvents,
      'confusionAssessments': _confusionDetectionResultService.getByPatientId(patientId).length,
      'capturedObservations': observations.length,
      'backendVideoAnalyses': _backendVideoResultService.getByPatientId(patientId).length,
      'backendSpeechAnalyses': _backendSpeechResultService.getByPatientId(patientId).length,
      'todayMood': latestEntry?.mood ?? 'Not set',
      'reflectionDone': latestEntry?.summary.isNotEmpty == true,
      'recentItems': recentItems.take(3).toList(),
      'activeReminder': activeReminder?.title,
      'currentConfusionLevel': confusionState.level.name,
    };
  }

  Map<String, dynamic> buildRoutineDigest({
    required String patientId,
    Reminder? activeReminder,
    PatientProfile? profile,
  }) {
    final reminderLogs = _eventLogService
        .getAllEvents()
        .where((event) => event.patientId == patientId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentLogs = reminderLogs.take(4).toList();

    final completed = reminderLogs
        .where((event) => event.actionTaken == ReminderAction.done)
        .length;
    final remindLater = reminderLogs
        .where((event) => event.actionTaken == ReminderAction.remindLater)
        .length;
    final ignored = reminderLogs
        .where((event) => event.actionTaken == ReminderAction.ignore)
        .length;
    final recentIgnored = recentLogs
        .where((event) => event.actionTaken == ReminderAction.ignore)
        .length;
    final recentLater = recentLogs
        .where((event) => event.actionTaken == ReminderAction.remindLater)
        .length;

    final latestResponse = reminderLogs.isNotEmpty ? reminderLogs.first : null;
    final inactivityMinutes = profile == null
        ? 0
        : DateTime.now().difference(profile.lastActiveAt).inMinutes;
    final inactivityLevel = inactivityMinutes >= 180
        ? 'high'
        : inactivityMinutes >= 75
            ? 'medium'
            : 'low';
    final timeMismatchLevel = _routineMismatchLevel(
      profile: profile,
      activeReminder: activeReminder,
    );
    final nonResponsePatternCount =
        recentIgnored + recentLater + (inactivityLevel == 'high' ? 1 : 0);
    final adherenceTone = ignored >= 2
        ? 'A calm check-in may help with today\'s routine.'
        : remindLater >= 2
        ? 'Your routine may need gentler pacing today.'
        : completed > 0
        ? 'You are making progress with today\'s routine.'
        : 'A simple routine can make the day feel steadier.';
    final frictionLevel = recentIgnored >= 2 ||
            (activeReminder != null && recentIgnored >= 1) ||
            inactivityLevel == 'high' ||
            timeMismatchLevel == 'high'
        ? 'high'
        : recentLater >= 1 ||
                recentIgnored == 1 ||
                inactivityLevel == 'medium' ||
                timeMismatchLevel == 'medium'
        ? 'medium'
        : 'low';
    final shouldAutoSupport = frictionLevel != 'low';
    final supportHeadline = switch (frictionLevel) {
      'high' => 'A calm routine check-in may help right now.',
      'medium' => 'A gentle routine nudge could help.',
      _ => activeReminder != null
          ? 'One next step is ready now.'
          : 'Today\'s routine is calm and manageable.',
    };
    final supportGuidance = switch (frictionLevel) {
      'high' =>
        'Let\'s slow down and focus on one simple step. Orientation or Sprout support may help before the next task.',
      'medium' =>
        'It looks like today\'s reminders may need gentler pacing. Sprout can help you decide the next step.',
      _ => activeReminder != null
          ? 'Focus on just one step: ${activeReminder.title}.'
          : adherenceTone,
    };
    final suggestedActionType = switch (frictionLevel) {
      'high' => 'orientation',
      'medium' => 'companion',
      _ => activeReminder != null ? 'tasks' : 'companion',
    };

    return {
      'completed': completed,
      'remindLater': remindLater,
      'ignored': ignored,
      'recentIgnored': recentIgnored,
      'recentRemindLater': recentLater,
      'nonResponsePatternCount': nonResponsePatternCount,
      'inactivityMinutes': inactivityMinutes,
      'inactivityLevel': inactivityLevel,
      'timeMismatchLevel': timeMismatchLevel,
      'frictionLevel': frictionLevel,
      'shouldAutoSupport': shouldAutoSupport,
      'activeReminder': activeReminder,
      'latestResponse': latestResponse,
      'recentLogs': recentLogs,
      'headline': activeReminder != null
          ? 'One next step is ready now.'
          : 'Today\'s routine is calm and manageable.',
      'guidance': activeReminder != null
          ? 'Focus on just one step: ${activeReminder.title}.'
          : adherenceTone,
      'supportHeadline': supportHeadline,
      'supportGuidance': supportGuidance,
      'suggestedActionType': suggestedActionType,
    };
  }

  Map<String, dynamic> buildContextSupportSuggestion({
    required PatientProfile profile,
    required ConfusionState confusionState,
    Reminder? activeReminder,
  }) {
    final behaviorInsights = buildBehaviorInsights();
    final observationDigest = buildObservationDigest();
    final visualDigest = buildVisualBehaviorDigest();
    final routineDigest = buildRoutineDigest(
      patientId: profile.patientId,
      activeReminder: activeReminder,
      profile: profile,
    );
    final interactionDigest = buildInteractionDigest(profile);
    final speechDigest = buildSpeechDigest(profile.patientId);
    final latestObject = (observationDigest['topObjects'] as List?)?.cast<String>();
    final topSeenItem = latestObject != null && latestObject.isNotEmpty
        ? latestObject.first
        : null;

    String headline = 'You are safe at ${profile.homeLabel}.';
    String guidance =
        'Take one calm step at a time. Sprout can help with orientation, memory, or finding an item.';
    String actionLabel = 'Open Sprout';
    String actionType = 'companion';

    if (confusionState.level == ConfusionLevel.high) {
      headline = 'Calm orientation support is recommended now.';
      guidance =
          '${profile.caregiverName} is your ${profile.caregiverRelationship}. Open orientation support and focus on one familiar cue.';
      actionLabel = 'Open Orientation';
      actionType = 'orientation';
    } else if ((visualDigest['riskLevel'] as String? ?? 'low') == 'high') {
      headline = visualDigest['headline'] as String? ??
          'Recent visual patterns may need a calmer check-in.';
      guidance = visualDigest['guidance'] as String? ??
          'A quick orientation cue could help with recent observation patterns.';
      actionLabel = 'Open Orientation';
      actionType = 'orientation';
    } else if ((visualDigest['riskLevel'] as String? ?? 'low') == 'medium') {
      headline = visualDigest['headline'] as String? ??
          'Some visual patterns may need extra attention.';
      guidance = visualDigest['guidance'] as String? ??
          'Review a recent observation or use a familiar memory cue.';
      actionLabel = 'View Observations';
      actionType = 'find_item';
    } else if ((speechDigest['riskLevel'] as String? ?? 'low') == 'high') {
      headline = speechDigest['headline'] as String? ??
          'Recent speech suggests support is needed.';
      guidance = speechDigest['guidance'] as String? ??
          'A calm orientation cue or Sprout support may help right now.';
      actionLabel = 'Open Orientation';
      actionType = 'orientation';
    } else if ((speechDigest['riskLevel'] as String? ?? 'low') == 'medium') {
      headline = speechDigest['headline'] as String? ??
          'A gentle speech check-in may help.';
      guidance = speechDigest['guidance'] as String? ??
          'Sprout can help with one calm question at a time.';
      actionLabel = 'Open Sprout';
      actionType = 'companion';
    } else if ((interactionDigest['riskLevel'] as String? ?? 'low') == 'high') {
      headline = interactionDigest['headline'] as String? ??
          'A support check-in is recommended now.';
      guidance = interactionDigest['guidance'] as String? ??
          'Recent activity suggests a calmer, simpler next step could help.';
      actionLabel = 'Open Orientation';
      actionType = 'orientation';
    } else if ((interactionDigest['riskLevel'] as String? ?? 'low') == 'medium') {
      headline = interactionDigest['headline'] as String? ??
          'A gentle support prompt may help.';
      guidance = interactionDigest['guidance'] as String? ??
          'Sprout can help with one step at a time.';
      actionLabel = 'Open Sprout';
      actionType = 'companion';
    } else if ((routineDigest['frictionLevel'] as String? ?? 'low') == 'high') {
      headline = routineDigest['supportHeadline'] as String? ??
          'A calm routine check-in may help right now.';
      guidance = routineDigest['supportGuidance'] as String? ??
          'Let\'s slow down and focus on one simple step.';
      actionLabel = 'Open Orientation';
      actionType = 'orientation';
    } else if ((routineDigest['frictionLevel'] as String? ?? 'low') == 'medium') {
      headline = routineDigest['supportHeadline'] as String? ??
          'A gentle routine nudge could help.';
      guidance = routineDigest['supportGuidance'] as String? ??
          'Sprout can help you decide the next step calmly.';
      actionLabel = 'Open Sprout';
      actionType = 'companion';
    } else if (activeReminder != null) {
      headline = 'A gentle task is waiting.';
      guidance =
          'Your next step is "${activeReminder.title}". Completing it may help keep the day clear and calm.';
      actionLabel = 'Focus on Today';
      actionType = 'tasks';
    } else if ((behaviorInsights['riskLevel'] as String? ?? 'low') != 'low') {
      headline = 'A short support check-in may help.';
      guidance = behaviorInsights['headline'] as String? ??
          'Recent patterns suggest a little extra grounding could help.';
      actionLabel = 'Open Orientation';
      actionType = 'orientation';
    } else if (topSeenItem != null) {
      headline = 'A familiar detail was seen recently.';
      guidance =
          'I recently noticed $topSeenItem in your observation history. You can check memories or find an item quickly.';
      actionLabel = 'Find an Item';
      actionType = 'find_item';
    }

    return {
      'headline': headline,
      'guidance': guidance,
      'actionLabel': actionLabel,
      'actionType': actionType,
    };
  }

  Map<String, dynamic> buildSpeechDigest(String patientId) {
    final signals = _speechSignalService.getByPatientId(patientId);
    final recentSignals = signals.take(8).toList();
    if (recentSignals.isEmpty) {
      return {
        'riskLevel': 'low',
        'headline': 'Recent speech sounds steady.',
        'guidance': 'Voice interactions have looked calm so far.',
        'patterns': <String>[],
      };
    }

    final repeatedQueries =
        recentSignals.where((signal) => signal.repeatedQuery).length;
    final hesitations = recentSignals.fold<int>(
      0,
      (total, signal) => total + signal.hesitancyCount,
    );
    final distressMarkers = recentSignals.fold<int>(
      0,
      (total, signal) => total + signal.distressMarkerCount,
    );
    final repetitions = recentSignals.fold<int>(
      0,
      (total, signal) => total + signal.repetitionCount,
    );
    final pauses = recentSignals.fold<int>(
      0,
      (total, signal) => total + signal.estimatedPauseCount,
    );

    String riskLevel = 'low';
    if (distressMarkers >= 2 || repeatedQueries >= 2 || hesitations >= 3) {
      riskLevel = 'high';
    } else if (distressMarkers > 0 ||
        repeatedQueries > 0 ||
        hesitations > 0 ||
        repetitions > 0 ||
        pauses >= 3) {
      riskLevel = 'medium';
    }

    final patterns = <String>[];
    if (repeatedQueries > 0) {
      patterns.add('Similar spoken questions were repeated recently.');
    }
    if (hesitations > 0) {
      patterns.add('Speech included hesitation markers.');
    }
    if (repetitions > 0) {
      patterns.add('Some words or short phrases were repeated.');
    }
    if (pauses >= 3) {
      patterns.add('Long pauses were estimated in recent speech.');
    }
    if (distressMarkers > 0) {
      patterns.add('Recent speech included words suggesting distress.');
    }

    return {
      'riskLevel': riskLevel,
      'headline': switch (riskLevel) {
        'high' => 'Recent speech suggests extra support may be needed.',
        'medium' => 'A gentle speech check-in may help.',
        _ => 'Recent speech sounds steady.',
      },
      'guidance': switch (riskLevel) {
        'high' =>
          'Orientation support or a calm Sprout prompt may help reduce confusion.',
        'medium' =>
          'Try one short question at a time or use a familiar memory cue.',
        _ => 'Voice interactions have looked calm so far.',
      },
      'patterns': patterns,
      'repeatedQueries': repeatedQueries,
      'hesitations': hesitations,
      'distressMarkers': distressMarkers,
      'repetitions': repetitions,
      'estimatedPauses': pauses,
    };
  }

  Map<String, dynamic> buildInteractionDigest(PatientProfile profile) {
    final signals = _interactionSignalService.getByPatientId(profile.patientId);
    final recentSignals = signals.take(16).toList();
    final screenVisits = recentSignals
        .where((signal) => signal.type == InteractionSignalType.screenVisit)
        .toList();
    final abandonedActions = recentSignals
        .where((signal) => signal.type == InteractionSignalType.actionAbandoned)
        .toList();
    final incompleteActions = recentSignals
        .where((signal) => signal.type == InteractionSignalType.incompleteAction)
        .toList();
    final hesitationSignals = recentSignals
        .where(
          (signal) => signal.type == InteractionSignalType.navigationHesitation,
        )
        .toList();
    final typingDifficultySignals = recentSignals
        .where((signal) => signal.type == InteractionSignalType.typingDifficulty)
        .toList();
    final screenCounts = <String, int>{};
    for (final signal in screenVisits) {
      screenCounts.update(signal.screenName, (value) => value + 1,
          ifAbsent: () => 1);
    }
    final repeatedVisit = screenCounts.entries
        .where((entry) => entry.value >= 3)
        .map((entry) => entry.key)
        .cast<String?>()
        .firstWhere((entry) => entry != null, orElse: () => null);

    final inactivityMinutes = DateTime.now()
        .difference(profile.lastActiveAt)
        .inMinutes;
    final inactivityRisk = inactivityMinutes >= 180
        ? 'high'
        : inactivityMinutes >= 75
            ? 'medium'
            : 'low';
    String riskLevel = 'low';
    if (inactivityRisk == 'high' ||
        hesitationSignals.length >= 2 ||
        abandonedActions.length >= 2 ||
        incompleteActions.length >= 2 ||
        typingDifficultySignals.length >= 2) {
      riskLevel = 'high';
    } else if (inactivityRisk == 'medium' ||
        hesitationSignals.isNotEmpty ||
        abandonedActions.isNotEmpty ||
        incompleteActions.isNotEmpty ||
        typingDifficultySignals.isNotEmpty ||
        repeatedVisit != null) {
      riskLevel = 'medium';
    }

    final patterns = <String>[];
    if (repeatedVisit != null) {
      patterns.add(
        'The patient revisited $repeatedVisit several times recently.',
      );
    }
    if (hesitationSignals.isNotEmpty) {
      patterns.add(
        'Navigation changed quickly a few times, which may suggest hesitation.',
      );
    }
    if (abandonedActions.isNotEmpty) {
      patterns.add(
        'A few support actions were started but not completed.',
      );
    }
    if (incompleteActions.isNotEmpty) {
      patterns.add(
        'Some guided tasks or help actions were left incomplete.',
      );
    }
    if (typingDifficultySignals.isNotEmpty) {
      patterns.add(
        'Recent typing showed correction or hesitation patterns.',
      );
    }
    if (inactivityMinutes >= 75) {
      patterns.add(
        'There has been limited interaction for about $inactivityMinutes minutes.',
      );
    }

    final headline = switch (riskLevel) {
      'high' => 'Recent interaction patterns suggest support is needed.',
      'medium' => 'A gentle interaction check-in may help.',
      _ => 'Recent interaction looks steady.',
    };
    final guidance = switch (riskLevel) {
      'high' =>
        'Try a calming orientation cue or one simple guided step before continuing.',
      'medium' =>
        'Sprout can help with a calm next action or a familiar memory cue.',
      _ => 'The current pace looks steady and manageable.',
    };

    return {
      'riskLevel': riskLevel,
      'headline': headline,
      'guidance': guidance,
      'patterns': patterns,
      'repeatedScreen': repeatedVisit,
      'inactivityMinutes': inactivityMinutes,
      'hesitationCount': hesitationSignals.length,
      'abandonedCount': abandonedActions.length,
      'incompleteCount': incompleteActions.length,
      'typingDifficultyCount': typingDifficultySignals.length,
    };
  }

  Map<String, dynamic> buildBehaviorInsights() {
    final visualDigest = buildVisualBehaviorDigest();
    return {
      'riskLevel': visualDigest['riskLevel'],
      'headline': visualDigest['headline'],
      'patterns': visualDigest['patterns'],
      'shouldAutoSupport': (visualDigest['riskLevel'] as String? ?? 'low') != 'low',
      'statusLabel': visualDigest['statusLabel'],
      'possibleWandering': visualDigest['possibleWandering'],
      'wanderingHeadline': visualDigest['wanderingHeadline'],
      'wanderingStatusLabel': visualDigest['wanderingStatusLabel'],
    };
  }

  int _countLocationSwitches(List<CameraEvent> events) {
    if (events.length < 2) return 0;
    var switches = 0;
    String? previous;
    for (final event in events.reversed) {
      final current = event.locationHint.trim().toLowerCase();
      final normalizedCurrent = _normalizedLocationHint(current);
      if (previous != null &&
          normalizedCurrent.isNotEmpty &&
          normalizedCurrent != 'unknown' &&
          previous != 'unknown' &&
          normalizedCurrent != previous) {
        switches++;
      }
      previous = normalizedCurrent;
    }
    return switches;
  }

  Map<String, dynamic> _buildWanderingDigest(List<CameraEvent> events) {
    final ordered = [...events]
      ..sort(
        (a, b) => (a.analysisTimestamp ?? a.timestamp).compareTo(
          b.analysisTimestamp ?? b.timestamp,
        ),
      );
    final stableLocations = ordered
        .map((event) => _normalizedLocationHint(event.locationHint))
        .where((location) => location.isNotEmpty && location != 'unknown')
        .toList();
    final distinctVisitedLocations = stableLocations.toSet().length;

    var shortIntervalSwitches = 0;
    var repeatedLoopCount = 0;
    for (var index = 1; index < ordered.length; index++) {
      final previous = ordered[index - 1];
      final current = ordered[index];
      final previousLocation = _normalizedLocationHint(previous.locationHint);
      final currentLocation = _normalizedLocationHint(current.locationHint);
      if (previousLocation.isEmpty ||
          currentLocation.isEmpty ||
          previousLocation == 'unknown' ||
          currentLocation == 'unknown' ||
          previousLocation == currentLocation) {
        continue;
      }

      final minutesApart = (current.analysisTimestamp ?? current.timestamp)
          .difference(previous.analysisTimestamp ?? previous.timestamp)
          .inMinutes;
      if (minutesApart <= 20) {
        shortIntervalSwitches++;
      }

      if (index >= 2) {
        final twoBackLocation = _normalizedLocationHint(
          ordered[index - 2].locationHint,
        );
        if (twoBackLocation.isNotEmpty &&
            twoBackLocation != 'unknown' &&
            twoBackLocation == currentLocation &&
            previousLocation != currentLocation) {
          repeatedLoopCount++;
        }
      }
    }

    final possibleWandering =
        shortIntervalSwitches >= 3 ||
        repeatedLoopCount >= 2 ||
        (shortIntervalSwitches >= 2 && distinctVisitedLocations >= 3);

    final riskLevel = possibleWandering
        ? 'high'
        : shortIntervalSwitches >= 2 || repeatedLoopCount >= 1
        ? 'medium'
        : 'low';

    return {
      'riskLevel': riskLevel,
      'possibleWandering': possibleWandering,
      'statusLabel': switch (riskLevel) {
        'high' => 'Movement pattern needs review',
        'medium' => 'Movement pattern to watch',
        _ => 'Movement looks steady',
      },
      'headline': switch (riskLevel) {
        'high' =>
          'Recent observations suggest repeated short-interval movement between places.',
        'medium' =>
          'Some recent location changes happened quickly and may need attention.',
        _ => 'Recent movement between observed places looks steady.',
      },
      'shortIntervalSwitches': shortIntervalSwitches,
      'repeatedLoopCount': repeatedLoopCount,
      'distinctVisitedLocations': distinctVisitedLocations,
    };
  }

  String _normalizedLocationHint(String rawHint) {
    final value = rawHint.trim().toLowerCase();
    if (value.isEmpty) return 'unknown';

    const mappings = <String, String>{
      'bedroom': 'bedroom',
      'bedside': 'bedside table',
      'next to bed': 'bedside table',
      'bed side': 'bedside table',
      'nightstand': 'bedside table',
      'bed table': 'bedside table',
      'living room': 'living room',
      'lounge': 'living room',
      'sofa': 'sofa area',
      'couch': 'sofa area',
      'sofa area': 'sofa area',
      'kitchen': 'kitchen',
      'counter': 'kitchen counter',
      'kitchen counter': 'kitchen counter',
      'dining': 'dining table',
      'dining table': 'dining table',
      'bathroom': 'bathroom',
      'washroom': 'bathroom',
      'toilet': 'bathroom',
      'sink': 'bathroom sink',
      'wash basin': 'bathroom sink',
      'bathroom sink': 'bathroom sink',
      'entry': 'entryway',
      'door': 'entryway',
      'entryway': 'entryway',
      'entrance': 'entryway',
      'entry shelf': 'entry shelf',
      'hall': 'hallway',
      'hallway': 'hallway',
      'corridor': 'hallway',
      'desk': 'study desk',
      'study': 'study desk',
      'study desk': 'study desk',
      'unknown': 'unknown',
    };

    for (final entry in mappings.entries) {
      if (value.contains(entry.key)) {
        return entry.value;
      }
    }
    return value;
  }

  String _normalizedObjectLabel(String rawObject) {
    final value = rawObject.trim().toLowerCase();
    if (value.isEmpty) return value;

    const mappings = <String, String>{
      'specs': 'glasses',
      'glasses': 'glasses',
      'spectacles': 'glasses',
      'eyeglasses': 'glasses',
      'sun glasses': 'glasses',
      'diary': 'diary',
      'journal': 'diary',
      'notebook': 'diary',
      'planner': 'diary',
      'medicine': 'medicine',
      'medication': 'medicine',
      'pill': 'medicine',
      'tablet': 'medicine',
      'medicine box': 'medicine',
      'keys': 'keys',
      'key': 'keys',
      'keychain': 'keys',
      'phone': 'phone',
      'mobile': 'phone',
      'mobile phone': 'phone',
      'smartphone': 'phone',
      'water bottle': 'water bottle',
      'bottle': 'water bottle',
      'bag': 'bag',
      'handbag': 'bag',
      'purse': 'bag',
      'wallet': 'wallet',
      'shoes': 'shoes',
      'shoe': 'shoes',
      'slippers': 'shoes',
      'book': 'book',
      'remote': 'remote',
      'tv remote': 'remote',
    };

    for (final entry in mappings.entries) {
      if (value.contains(entry.key)) {
        return entry.value;
      }
    }
    return value;
  }

  String _routineMismatchLevel({
    required PatientProfile? profile,
    required Reminder? activeReminder,
  }) {
    if (profile == null) return 'low';
    final currentHour = DateTime.now().hour;
    final activity = profile.currentActivity.toLowerCase();
    final expectedWindow = _expectedRoutineWindow(currentHour);

    final activityMatchesWindow = switch (expectedWindow) {
      'morning' => activity.contains('morning') ||
          activity.contains('breakfast') ||
          activity.contains('medicine') ||
          activity.contains('my day') ||
          activity.contains('settling'),
      'afternoon' => activity.contains('walk') ||
          activity.contains('observe') ||
          activity.contains('memory') ||
          activity.contains('task') ||
          activity.contains('lunch'),
      'evening' => activity.contains('dinner') ||
          activity.contains('calm') ||
          activity.contains('memory') ||
          activity.contains('support') ||
          activity.contains('routine'),
      _ => true,
    };

    var mismatchScore = 0;
    if (!activityMatchesWindow) mismatchScore++;
    if (activeReminder != null && !_reminderFitsCurrentWindow(activeReminder.type, currentHour)) {
      mismatchScore++;
    }
    if (DateTime.now().difference(profile.lastActiveAt).inMinutes >= 120) {
      mismatchScore++;
    }

    if (mismatchScore >= 2) return 'high';
    if (mismatchScore == 1) return 'medium';
    return 'low';
  }

  String _expectedRoutineWindow(int hour) {
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }

  bool _reminderFitsCurrentWindow(ReminderType type, int hour) {
    switch (type) {
      case ReminderType.medicine:
        return hour >= 6 && hour <= 22;
      case ReminderType.water:
        return hour >= 7 && hour <= 21;
      case ReminderType.appointment:
        return hour >= 8 && hour <= 18;
      case ReminderType.task:
        return true;
    }
  }

  bool _looksLikePossibleFall(CameraEvent event) {
    final text = '${event.note} ${event.unusualObservation}'.toLowerCase();
    final objects = event.detectedObjects.map((item) => item.toLowerCase()).toList();
    final hasFloorCue = text.contains('floor') || text.contains('ground');
    final hasPostureCue = text.contains('fall') ||
        text.contains('collapsed') ||
        text.contains('lying down') ||
        text.contains('lying on') ||
        text.contains('slumped');
    final objectCue = objects.any(
      (item) =>
          item.contains('floor') ||
          item.contains('ground') ||
          item.contains('spill'),
    );
    return event.concernLevel == 'high' && (hasPostureCue || (hasFloorCue && objectCue));
  }

  bool _looksLikeRiskyScene(CameraEvent event) {
    final text = '${event.note} ${event.unusualObservation}'.toLowerCase();
    final objects = event.detectedObjects.map((item) => item.toLowerCase()).toList();
    const riskWords = [
      'spill',
      'wet floor',
      'clutter',
      'sharp',
      'knife',
      'stove',
      'open flame',
      'trip hazard',
      'blocked path',
      'unstable',
      'fallen object',
    ];

    final textRisk = riskWords.any(text.contains);
    final objectRisk = objects.any((item) => riskWords.any(item.contains));
    return event.concernLevel == 'high' || (event.concernLevel == 'medium' && (textRisk || objectRisk));
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
      case 'confusion_ai':
        return 'AI confusion assessment';
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
    final normalized = _normalizedObjectLabel(query);
    switch (normalized) {
      case 'glasses':
        return ['glasses', 'specs', 'spectacles', 'eyeglasses'];
      case 'diary':
        return ['diary', 'notebook', 'journal', 'planner'];
      case 'medicine':
        return ['medicine', 'medication', 'tablet', 'pill', 'medicine box'];
      case 'keys':
        return ['keys', 'key', 'keychain'];
      case 'phone':
        return ['phone', 'mobile', 'mobile phone', 'smartphone'];
      case 'water bottle':
        return ['water bottle', 'bottle'];
      case 'bag':
        return ['bag', 'handbag', 'purse'];
      default:
        return [normalized, query];
    }
  }
}
