enum ReminderType {
  medicine,
  water,
  task,
  appointment,
}

enum ReminderStatus {
  pending,
  done,
  remindLater,
  ignored,
}

class Reminder {
  final String id;
  final String patientId;
  final String title;
  final String description;
  final DateTime scheduledTime;
  final ReminderType type;
  final ReminderStatus status;

  Reminder({
    required this.id,
    required this.patientId,
    required this.title,
    required this.description,
    required this.scheduledTime,
    required this.type,
    this.status = ReminderStatus.pending,
  });

  Reminder copyWith({
    String? id,
    String? patientId,
    String? title,
    String? description,
    DateTime? scheduledTime,
    ReminderType? type,
    ReminderStatus? status,
  }) {
    return Reminder(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }
}
