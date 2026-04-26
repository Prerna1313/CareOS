enum EvaluationStatus {
  correct,
  partiallyCorrect,
  incorrect,
  manualReview,
  notEvaluated,
}

class RecognitionResponse {
  final String id;
  final String taskId;
  final String patientId;
  final String memoryItemId;
  final String responseText;
  final bool isSkipped;
  final bool? isCorrect; // Added for cognitive tracking
  final int responseTimeSeconds;
  final DateTime answeredAt; // Renamed from completedAt
  final EvaluationStatus evaluationStatus;
  final String taskMode;

  RecognitionResponse({
    required this.id,
    required this.taskId,
    required this.patientId,
    required this.memoryItemId,
    required this.responseText,
    this.isSkipped = false,
    this.isCorrect,
    required this.responseTimeSeconds,
    required this.answeredAt,
    this.evaluationStatus = EvaluationStatus.notEvaluated,
    this.taskMode = 'dailyPrompt',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'patientId': patientId,
      'memoryItemId': memoryItemId,
      'responseText': responseText,
      'isSkipped': isSkipped,
      'isCorrect': isCorrect,
      'responseTimeSeconds': responseTimeSeconds,
      'answeredAt': answeredAt.toIso8601String(),
      'evaluationStatus': evaluationStatus.index,
      'taskMode': taskMode,
    };
  }

  factory RecognitionResponse.fromMap(Map<dynamic, dynamic> map) {
    return RecognitionResponse(
      id: map['id'] ?? '',
      taskId: map['taskId'] ?? '',
      patientId: map['patientId'] ?? '',
      memoryItemId: map['memoryItemId'] ?? '',
      responseText: map['responseText'] ?? '',
      isSkipped: map['isSkipped'] ?? false,
      isCorrect: map['isCorrect'],
      responseTimeSeconds: map['responseTimeSeconds'] ?? 0,
      answeredAt: DateTime.parse(
        map['answeredAt'] ??
            map['completedAt'] ??
            DateTime.now().toIso8601String(),
      ),
      evaluationStatus: EvaluationStatus.values[map['evaluationStatus'] ?? 4],
      taskMode: map['taskMode'] ?? 'dailyPrompt',
    );
  }
}
