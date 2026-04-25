import 'reminder.dart';

enum ReminderAction {
  done,
  remindLater,
  ignore,
  shown,
}

class ReminderLog {
  final String id;
  final String reminderId;
  final String patientId;
  final DateTime timestamp;
  final ReminderAction actionTaken;
  final DateTime scheduledTime;
  final DateTime actualResponseTime;
  final ReminderType reminderType;

  ReminderLog({
    required this.id,
    required this.reminderId,
    required this.patientId,
    required this.timestamp,
    required this.actionTaken,
    required this.scheduledTime,
    required this.actualResponseTime,
    required this.reminderType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'patientId': patientId,
      'timestamp': timestamp.toIso8601String(),
      'actionTaken': actionTaken.name,
      'scheduledTime': scheduledTime.toIso8601String(),
      'actualResponseTime': actualResponseTime.toIso8601String(),
      'reminderType': reminderType.name,
    };
  }

  factory ReminderLog.fromMap(Map<String, dynamic> map) {
    return ReminderLog(
      id: map['id'] as String,
      reminderId: map['reminderId'] as String,
      patientId: map['patientId'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      actionTaken: ReminderAction.values.firstWhere(
        (e) => e.name == map['actionTaken'],
        orElse: () => ReminderAction.shown,
      ),
      scheduledTime: DateTime.parse(map['scheduledTime'] as String),
      actualResponseTime: DateTime.parse(map['actualResponseTime'] as String),
      reminderType: ReminderType.values.firstWhere(
        (e) => e.name == map['reminderType'],
        orElse: () => ReminderType.task,
      ),
    );
  }
}
