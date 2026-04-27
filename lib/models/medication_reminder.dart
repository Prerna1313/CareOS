enum ReminderType { medicine, water, nutrition, exercise, sleep, doctor, other }
enum ReminderResponseStatus { pending, taken, missed, snoozed }

class MedicationReminder {
  final String id;
  final String patientId;
  final String title;
  final ReminderType type;
  final String time; // HH:mm format
  final String repeatPattern; // e.g. "daily", "weekdays"
  final String? instructions;
  final ReminderResponseStatus responseStatus;
  final DateTime? lastResponseAt;
  final DateTime? snoozedUntil;
  final bool isEnabled;

  const MedicationReminder({
    required this.id,
    required this.patientId,
    required this.title,
    required this.type,
    required this.time,
    required this.repeatPattern,
    this.instructions,
    this.responseStatus = ReminderResponseStatus.pending,
    this.lastResponseAt,
    this.snoozedUntil,
    this.isEnabled = true,
  });

  MedicationReminder copyWith({
    String? id,
    String? patientId,
    String? title,
    ReminderType? type,
    String? time,
    String? repeatPattern,
    String? instructions,
    ReminderResponseStatus? responseStatus,
    DateTime? lastResponseAt,
    DateTime? snoozedUntil,
    bool? isEnabled,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      type: type ?? this.type,
      time: time ?? this.time,
      repeatPattern: repeatPattern ?? this.repeatPattern,
      instructions: instructions ?? this.instructions,
      responseStatus: responseStatus ?? this.responseStatus,
      lastResponseAt: lastResponseAt ?? this.lastResponseAt,
      snoozedUntil: snoozedUntil,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      title: json['title'] as String,
      type: ReminderType.values.byName(json['type'] as String),
      time: json['time'] as String,
      repeatPattern: json['repeatPattern'] as String,
      instructions: json['instructions'] as String?,
      responseStatus: ReminderResponseStatus.values.byName(json['responseStatus'] as String),
      lastResponseAt: json['lastResponseAt'] != null
          ? DateTime.parse(json['lastResponseAt'] as String)
          : null,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : null,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'title': title,
        'type': type.name,
        'time': time,
        'repeatPattern': repeatPattern,
        'instructions': instructions,
        'responseStatus': responseStatus.name,
        'lastResponseAt': lastResponseAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'isEnabled': isEnabled,
      };
}
