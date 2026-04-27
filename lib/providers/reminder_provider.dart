import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import '../models/reminder_log.dart';
import '../services/reminder_service.dart';
import '../services/event_log_service.dart';
import '../models/confusion_state.dart';
import '../models/confusion_event.dart';
import '../models/confusion_detection_result.dart';
import '../services/confusion_detection_service.dart';
import '../services/confusion_ai_assessment_service.dart';
import '../services/confusion_event_service.dart';
import '../services/confusion_detection_result_service.dart';
import '../services/firestore/firestore_event_service.dart';
import 'package:uuid/uuid.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderService _service;
  final EventLogService _eventLogService;
  final ConfusionDetectionService _confusionService;
  final ConfusionAiAssessmentService? _confusionAiAssessmentService;
  final ConfusionEventService _confusionEventService;
  final ConfusionDetectionResultService? _confusionDetectionResultService;
  final FirestoreEventService? _firestoreEventService;
  final String _patientId;
  final String _patientName;
  final Uuid _uuid = const Uuid();
  Timer? _refreshTimer;

  Reminder? _currentReminder;
  Reminder? _upcomingReminder;
  ConfusionState _currentConfusionState = const ConfusionState();

  ReminderProvider(
    this._service,
    this._eventLogService,
    this._confusionService,
    this._confusionEventService,
    this._patientId, {
    String patientName = 'Patient',
    ConfusionAiAssessmentService? confusionAiAssessmentService,
    ConfusionDetectionResultService? confusionDetectionResultService,
    FirestoreEventService? firestoreEventService,
  }) : _patientName = patientName,
       _confusionAiAssessmentService = confusionAiAssessmentService,
       _confusionDetectionResultService = confusionDetectionResultService,
       _firestoreEventService = firestoreEventService {
    _init();
  }

  Reminder? get currentReminder => _currentReminder;
  Reminder? get upcomingReminder => _upcomingReminder;
  Reminder? get displayReminder => _currentReminder ?? _upcomingReminder;
  ConfusionState get currentConfusionState => _currentConfusionState;

  Future<void> _init() async {
    await _refreshReminders();
    await _evaluateConfusionState();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshReminders(notify: true);
    });
    notifyListeners();
  }

  /// Only for testing: inject a mock reminder
  void triggerMockReminder() {
    if (_service is MockReminderService) {
      _currentReminder = _service.generateMockReminder(_patientId);
      _upcomingReminder = _currentReminder;
      
      // Log that it was shown
      _logAction(ReminderAction.shown, _currentReminder!);
      notifyListeners();
    }
  }

  Future<void> handleResponse(ReminderAction action) async {
    if (_currentReminder == null) return;

    final reminder = _currentReminder!;
    _currentReminder = null; // Hide the popup immediately
    notifyListeners();

    await _logAction(action, reminder);
  }

  Future<void> _logAction(ReminderAction action, Reminder reminder) async {
    final log = ReminderLog(
      id: _uuid.v4(),
      reminderId: reminder.id,
      patientId: reminder.patientId,
      timestamp: DateTime.now(),
      actionTaken: action,
      scheduledTime: reminder.scheduledTime,
      actualResponseTime: DateTime.now(),
      reminderType: reminder.type,
    );

    // Save to the actual local event log box
    await _eventLogService.logEvent(log);
    
    // Sync to Firestore
    await _firestoreEventService?.syncReminderLog(log);
    await _service.logResponse(log);

    // Re-evaluate confusion state
    await _refreshReminders();
    await _evaluateConfusionState();
  }

  Future<void> _refreshReminders({bool notify = false}) async {
    _currentReminder = await _service.fetchPendingReminder(_patientId);
    _upcomingReminder = await _service.fetchUpcomingReminder(_patientId);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _evaluateConfusionState() async {
    final recentLogs = _eventLogService
        .getAllEvents()
        .where((log) => log.patientId == _patientId)
        .toList();
    final localState = _confusionService.analyze(recentLogs);
    final shouldUseAiAssessment =
        recentLogs.length >= 3 || localState.level != ConfusionLevel.normal;
    ConfusionDetectionResult? aiResult;

    if (shouldUseAiAssessment) {
      aiResult = await _confusionAiAssessmentService?.assessReminderPattern(
        patientId: _patientId,
        patientName: _patientName,
        logs: recentLogs,
        localState: localState,
      );
      if (aiResult != null) {
        await _confusionDetectionResultService?.saveResult(aiResult);
        await _firestoreEventService?.syncConfusionAssessment(aiResult);
      }
    }

    final newState = _buildUnifiedState(localState, aiResult);

    if (newState.level == ConfusionLevel.high) {
      // Check cooldown (10 minutes)
      final lastTrigger = _confusionEventService.getLastTriggerTime(_patientId);
      final now = DateTime.now();
      
      if (lastTrigger == null || now.difference(lastTrigger).inMinutes >= 10) {
        // Cooldown passed or first time -> Trigger and Log
        _currentConfusionState = newState;

        // Take snapshot of recent events for logging
        final snapshotEvents = recentLogs.take(5).map((e) => e.toMap()).toList();

        final event = ConfusionEvent(
          id: _uuid.v4(),
          patientId: _patientId,
          timestamp: now,
          confusionLevel: newState.level,
          confusionScore: newState.score,
          triggerReason: _buildTriggerReason(newState, aiResult),
          recentEventsSnapshot: jsonEncode(snapshotEvents),
        );
        
        await _confusionEventService.logEvent(event);
        await _firestoreEventService?.syncConfusionEvent(event);
        notifyListeners();
      } else {
        // Cooldown active, ignore the high state trigger
        // We might want to keep the current state normal or mild so popup doesn't show
        _currentConfusionState = const ConfusionState(level: ConfusionLevel.mild);
        notifyListeners();
      }
    } else {
      _currentConfusionState = newState;
      notifyListeners();
    }
  }

  void dismissConfusion() {
    _currentConfusionState = const ConfusionState();
    notifyListeners();
  }

  Future<void> refreshReminders() async {
    await _refreshReminders(notify: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Manually triggers a high confusion state for testing or direct patient request
  void triggerMockConfusion() {
    _currentConfusionState = const ConfusionState(
      level: ConfusionLevel.high,
      score: 100,
      reasons: ['User requested help'],
    );
    notifyListeners();
  }

  ConfusionState _buildUnifiedState(
    ConfusionState localState,
    ConfusionDetectionResult? aiResult,
  ) {
    if (aiResult == null) {
      return localState;
    }

    final reasons = {
      ...localState.reasons,
      if (aiResult.explanation.trim().isNotEmpty) aiResult.explanation.trim(),
      ...aiResult.detectedSignals.map((signal) => signal.replaceAll('_', ' ')),
    }.toList();

    final aiLevel = switch (aiResult.riskLevel) {
      ConfusionRiskLevel.high => ConfusionLevel.high,
      ConfusionRiskLevel.moderate => ConfusionLevel.mild,
      ConfusionRiskLevel.mild => ConfusionLevel.mild,
      ConfusionRiskLevel.stable => ConfusionLevel.normal,
    };

    final resolvedLevel = switch ((localState.level, aiLevel)) {
      (ConfusionLevel.high, _) || (_, ConfusionLevel.high) => ConfusionLevel.high,
      (ConfusionLevel.mild, _) || (_, ConfusionLevel.mild) => ConfusionLevel.mild,
      _ => ConfusionLevel.normal,
    };

    return ConfusionState(
      level: resolvedLevel,
      score: aiResult.score.round(),
      reasons: reasons,
    );
  }

  String _buildTriggerReason(
    ConfusionState state,
    ConfusionDetectionResult? aiResult,
  ) {
    if (aiResult == null) {
      return state.reasons.join(' | ');
    }

    final riskLabel = aiResult.riskLevel.name.toUpperCase();
    final signals = aiResult.detectedSignals.isEmpty
        ? ''
        : ' Signals: ${aiResult.detectedSignals.join(', ')}.';
    final cueSuggestion = aiResult.memoryCueNeeded
        ? ' Memory cue support suggested.'
        : '';
    return 'AI confusion assessment [$riskLabel, ${aiResult.score.round()}/100]: '
        '${aiResult.explanation}$signals$cueSuggestion';
  }
}
