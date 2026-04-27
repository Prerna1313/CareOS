enum ActivityEventType { appInteraction, notificationResponse, movement, diaryEntry, speechActivity }

class PatientActivityEvent {
  final String id;
  final ActivityEventType type;
  final DateTime timestamp;
  final String? metadata; // JSON string with specific context

  const PatientActivityEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  factory PatientActivityEvent.fromJson(Map<String, dynamic> json) {
    return PatientActivityEvent(
      id: json['id'] as String,
      type: ActivityEventType.values.byName(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}
