import 'package:flutter/foundation.dart';
import 'caregiver_reminder_service.dart';
import '../models/reminder.dart';
import '../models/reminder_log.dart';

abstract class ReminderService {
  Future<Reminder?> fetchPendingReminder(String patientId);
  Future<Reminder?> fetchUpcomingReminder(String patientId);
  Future<void> logResponse(ReminderLog log);
}

class MockReminderService implements ReminderService {
  @override
  Future<Reminder?> fetchPendingReminder(String patientId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    return null;
  }

  @override
  Future<Reminder?> fetchUpcomingReminder(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return null;
  }

  @override
  Future<void> logResponse(ReminderLog log) async {
    // Simulate network delay and logging
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('MockReminderService: Logged response -> ${log.actionTaken.name} for reminder ${log.reminderId}');
  }

  /// Only for testing: generate a mock reminder
  Reminder generateMockReminder(String patientId) {
    return Reminder(
      id: 'mock_reminder_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      title: 'Time for medicine',
      description: 'Take one blue pill with a glass of water.',
      scheduledTime: DateTime.now(),
      type: ReminderType.medicine,
    );
  }
}

class SharedCaregiverReminderService implements ReminderService {
  final CaregiverReminderService _store;

  SharedCaregiverReminderService(this._store);

  @override
  Future<Reminder?> fetchPendingReminder(String patientId) {
    return _store.getDueReminder(patientId);
  }

  @override
  Future<Reminder?> fetchUpcomingReminder(String patientId) {
    return _store.getUpcomingReminder(patientId);
  }

  @override
  Future<void> logResponse(ReminderLog log) async {
    await _store.applyResponse(log);
    debugPrint(
      'SharedCaregiverReminderService: synced ${log.actionTaken.name} for reminder ${log.reminderId}',
    );
  }
}
