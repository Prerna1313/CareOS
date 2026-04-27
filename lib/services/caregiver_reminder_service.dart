import 'package:hive_flutter/hive_flutter.dart';

import '../models/medication_reminder.dart' as caregiver;
import '../models/reminder.dart' as patient;
import '../models/reminder_log.dart';

class CaregiverReminderService {
  static const String _boxName = 'caregiver_reminders';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  Future<List<caregiver.MedicationReminder>> getAll(String patientId) async {
    final items = _box.values
        .map(
          (item) => caregiver.MedicationReminder.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where((item) => item.patientId == patientId)
        .toList();
    items.sort((a, b) => _nextOccurrence(a).compareTo(_nextOccurrence(b)));
    return items;
  }

  Future<void> save(caregiver.MedicationReminder reminder) async {
    await _box.put(reminder.id, reminder.toJson());
  }

  Future<void> delete(String reminderId) async {
    await _box.delete(reminderId);
  }

  Future<caregiver.MedicationReminder?> getById(String reminderId) async {
    final raw = _box.get(reminderId);
    if (raw == null) return null;
    return caregiver.MedicationReminder.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<patient.Reminder?> getDueReminder(String patientId) async {
    final reminders = await getAll(patientId);
    final now = DateTime.now();
    final dueCandidates = reminders.where((reminder) {
      if (!reminder.isEnabled) return false;
      if (_completedToday(reminder)) return false;
      final dueAt = _activeDueTime(reminder);
      if (dueAt.isAfter(now)) return false;
      return now.difference(dueAt).inHours <= 3;
    }).toList();

    if (dueCandidates.isEmpty) return null;
    dueCandidates.sort((a, b) => _activeDueTime(a).compareTo(_activeDueTime(b)));
    return _toPatientReminder(dueCandidates.first, _activeDueTime(dueCandidates.first));
  }

  Future<patient.Reminder?> getUpcomingReminder(String patientId) async {
    final reminders = await getAll(patientId);
    if (reminders.isEmpty) return null;

    final active = reminders.where((reminder) {
      if (!reminder.isEnabled) return false;
      return !_completedToday(reminder);
    }).toList();
    if (active.isEmpty) return null;

    active.sort((a, b) => _activeDueTime(a).compareTo(_activeDueTime(b)));
    final next = active.first;
    return _toPatientReminder(next, _activeDueTime(next));
  }

  Future<void> applyResponse(ReminderLog log) async {
    final reminder = await getById(log.reminderId);
    if (reminder == null) return;

    final updated = switch (log.actionTaken) {
      ReminderAction.done => reminder.copyWith(
          responseStatus: caregiver.ReminderResponseStatus.taken,
          lastResponseAt: log.actualResponseTime,
          snoozedUntil: null,
        ),
      ReminderAction.ignore => reminder.copyWith(
          responseStatus: caregiver.ReminderResponseStatus.missed,
          lastResponseAt: log.actualResponseTime,
          snoozedUntil: null,
        ),
      ReminderAction.remindLater => reminder.copyWith(
          responseStatus: caregiver.ReminderResponseStatus.snoozed,
          lastResponseAt: log.actualResponseTime,
          snoozedUntil: log.actualResponseTime.add(const Duration(minutes: 15)),
        ),
      ReminderAction.shown => reminder,
    };

    await save(updated);
  }

  bool _completedToday(caregiver.MedicationReminder reminder) {
    final lastResponse = reminder.lastResponseAt;
    if (lastResponse == null) return false;
    final sameDay = _isSameDay(lastResponse, DateTime.now());
    if (!sameDay) return false;
    return reminder.responseStatus == caregiver.ReminderResponseStatus.taken ||
        reminder.responseStatus == caregiver.ReminderResponseStatus.missed;
  }

  DateTime _nextOccurrence(caregiver.MedicationReminder reminder) {
    final now = DateTime.now();
    final parsed = _parseTime(reminder.time, baseDate: now);
    if (reminder.snoozedUntil != null && reminder.snoozedUntil!.isAfter(now)) {
      return reminder.snoozedUntil!;
    }
    if (_completedToday(reminder) || parsed.isBefore(now)) {
      return parsed.add(const Duration(days: 1));
    }
    return parsed;
  }

  DateTime _activeDueTime(caregiver.MedicationReminder reminder) {
    final now = DateTime.now();
    if (reminder.snoozedUntil != null && reminder.snoozedUntil!.isAfter(now)) {
      return reminder.snoozedUntil!;
    }
    return _parseTime(reminder.time, baseDate: now);
  }

  DateTime _parseTime(String value, {required DateTime baseDate}) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour,
      minute,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  patient.Reminder _toPatientReminder(
    caregiver.MedicationReminder reminder,
    DateTime scheduledTime,
  ) {
    return patient.Reminder(
      id: reminder.id,
      patientId: reminder.patientId,
      title: reminder.title,
      description: reminder.instructions ?? 'Caregiver reminder scheduled for this time.',
      scheduledTime: scheduledTime,
      type: switch (reminder.type) {
        caregiver.ReminderType.medicine => patient.ReminderType.medicine,
        caregiver.ReminderType.water => patient.ReminderType.water,
        caregiver.ReminderType.doctor => patient.ReminderType.appointment,
        _ => patient.ReminderType.task,
      },
      status: switch (reminder.responseStatus) {
        caregiver.ReminderResponseStatus.taken => patient.ReminderStatus.done,
        caregiver.ReminderResponseStatus.snoozed => patient.ReminderStatus.remindLater,
        caregiver.ReminderResponseStatus.missed => patient.ReminderStatus.ignored,
        caregiver.ReminderResponseStatus.pending => patient.ReminderStatus.pending,
      },
    );
  }
}
