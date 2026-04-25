import 'confusion_state.dart';

class ConfusionEvent {
  final String id;
  final String patientId;
  final DateTime timestamp;
  final ConfusionLevel confusionLevel;
  final int confusionScore;
  final String triggerReason;
  final String recentEventsSnapshot; // JSON representation of the recent events

  ConfusionEvent({
    required this.id,
    required this.patientId,
    required this.timestamp,
    required this.confusionLevel,
    required this.confusionScore,
    required this.triggerReason,
    required this.recentEventsSnapshot,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'timestamp': timestamp.toIso8601String(),
      'confusionLevel': confusionLevel.name,
      'confusionScore': confusionScore,
      'triggerReason': triggerReason,
      'recentEventsSnapshot': recentEventsSnapshot,
    };
  }

  factory ConfusionEvent.fromMap(Map<String, dynamic> map) {
    return ConfusionEvent(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      confusionLevel: ConfusionLevel.values.firstWhere(
        (e) => e.name == map['confusionLevel'],
        orElse: () => ConfusionLevel.mild,
      ),
      confusionScore: map['confusionScore'] as int,
      triggerReason: map['triggerReason'] as String,
      recentEventsSnapshot: map['recentEventsSnapshot'] as String,
    );
  }
}
