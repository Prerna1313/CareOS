enum InteractionSignalType {
  screenVisit,
  actionStarted,
  actionCompleted,
  actionAbandoned,
  incompleteAction,
  navigationHesitation,
  typingDifficulty,
  inactivityFlag,
}

class InteractionSignal {
  final String id;
  final String patientId;
  final DateTime timestamp;
  final InteractionSignalType type;
  final String screenName;
  final String summary;
  final Map<String, dynamic> metadata;

  const InteractionSignal({
    required this.id,
    required this.patientId,
    required this.timestamp,
    required this.type,
    required this.screenName,
    required this.summary,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'screenName': screenName,
      'summary': summary,
      'metadata': metadata,
    };
  }

  factory InteractionSignal.fromMap(Map<dynamic, dynamic> map) {
    return InteractionSignal(
      id: map['id']?.toString() ?? '',
      patientId: map['patientId']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      type: InteractionSignalType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => InteractionSignalType.screenVisit,
      ),
      screenName: map['screenName']?.toString() ?? 'unknown',
      summary: map['summary']?.toString() ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? const {}),
    );
  }
}
