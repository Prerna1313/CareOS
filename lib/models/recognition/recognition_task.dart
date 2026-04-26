enum RecognitionTaskStatus { pending, completed, skipped }

enum RecognitionImportance { low, medium, high }

enum RecognitionDeliveryMode { dailyPrompt, confusionSupport, optionalPractice }

class RecognitionTask {
  final String id;
  final String patientId;
  final String memoryItemId;
  final String questionType; // e.g., 'who', 'where', 'when'
  final String questionText;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final RecognitionImportance importance;
  final RecognitionDeliveryMode deliveryMode;
  final RecognitionTaskStatus status;

  RecognitionTask({
    required this.id,
    required this.patientId,
    required this.memoryItemId,
    required this.questionType,
    required this.questionText,
    required this.scheduledFor,
    required this.createdAt,
    this.importance = RecognitionImportance.medium,
    this.deliveryMode = RecognitionDeliveryMode.dailyPrompt,
    this.status = RecognitionTaskStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'memoryItemId': memoryItemId,
      'questionType': questionType,
      'questionText': questionText,
      'scheduledFor': scheduledFor.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'importance': importance.index,
      'deliveryMode': deliveryMode.index,
      'status': status.index,
    };
  }

  factory RecognitionTask.fromMap(Map<dynamic, dynamic> map) {
    return RecognitionTask(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      memoryItemId: map['memoryItemId'] ?? '',
      questionType: map['questionType'] ?? '',
      questionText: map['questionText'] ?? '',
      scheduledFor: DateTime.parse(map['scheduledFor']),
      createdAt: DateTime.parse(map['createdAt']),
      importance: RecognitionImportance.values[map['importance'] ?? 1],
      deliveryMode: RecognitionDeliveryMode.values[map['deliveryMode'] ?? 0],
      status: RecognitionTaskStatus.values[map['status'] ?? 0],
    );
  }

  RecognitionTask copyWith({
    RecognitionTaskStatus? status,
    RecognitionDeliveryMode? deliveryMode,
  }) {
    return RecognitionTask(
      id: id,
      patientId: patientId,
      memoryItemId: memoryItemId,
      questionType: questionType,
      questionText: questionText,
      scheduledFor: scheduledFor,
      createdAt: createdAt,
      importance: importance,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      status: status ?? this.status,
    );
  }
}
