import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import '../models/reminder_log.dart';
import '../services/reminder_service.dart';
import '../services/event_log_service.dart';
import '../models/confusion_state.dart';
import '../models/confusion_event.dart';
import '../services/confusion_detection_service.dart';
import '../services/confusion_event_service.dart';
import '../services/firestore/firestore_event_service.dart';
import 'package:uuid/uuid.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderService _service;
  final EventLogService _eventLogService;
  final ConfusionDetectionService _confusionService;
  final ConfusionEventService _confusionEventService;
  final FirestoreEventService? _firestoreEventService;
  final String _patientId;
  final Uuid _uuid = const Uuid();

  Reminder? _currentReminder;
  ConfusionState _currentConfusionState = const ConfusionState();

  ReminderProvider(
    this._service,
    this._eventLogService,
    this._confusionService,
    this._confusionEventService,
    this._patientId, {
    FirestoreEventService? firestoreEventService,
  }) : _firestoreEventService = firestoreEventService {
    _init();
  }

  Reminder? get currentReminder => _currentReminder;
  ConfusionState get currentConfusionState => _currentConfusionState;

  Future<void> _init() async {
    // Check for any pending reminder on start
    _currentReminder = await _service.fetchPendingReminder(_patientId);
    await _evaluateConfusionState();
    notifyListeners();
  }

  /// Only for testing: inject a mock reminder
  void triggerMockReminder() {
    if (_service is MockReminderService) {
      _currentReminder = _service.generateMockReminder(_patientId);
      
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

    // Re-evaluate confusion state
    await _evaluateConfusionState();
  }

  Future<void> _evaluateConfusionState() async {
    final recentLogs = _eventLogService.getAllEvents();
    final newState = _confusionService.analyze(recentLogs);

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
          triggerReason: newState.reasons.join(' | '),
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

  /// Manually triggers a high confusion state for testing or direct patient request
  void triggerMockConfusion() {
    _currentConfusionState = const ConfusionState(
      level: ConfusionLevel.high,
      score: 100,
      reasons: ['User requested help'],
    );
    notifyListeners();
  }
}
