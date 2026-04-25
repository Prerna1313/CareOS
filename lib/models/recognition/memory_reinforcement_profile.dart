import 'recognition_task.dart';

class MemoryReinforcementProfile {
  final String memoryItemId;
  final RecognitionImportance importance;
  final int totalTimesAsked;
  final DateTime? lastAskedAt;
  final int consecutiveCorrectAnswers;
  final DateTime nextScheduledAt;

  MemoryReinforcementProfile({
    required this.memoryItemId,
    this.importance = RecognitionImportance.medium,
    this.totalTimesAsked = 0,
    this.lastAskedAt,
    this.consecutiveCorrectAnswers = 0,
    required this.nextScheduledAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'memoryItemId': memoryItemId,
      'importance': importance.index,
      'totalTimesAsked': totalTimesAsked,
      'lastAskedAt': lastAskedAt?.toIso8601String(),
      'consecutiveCorrectAnswers': consecutiveCorrectAnswers,
      'nextScheduledAt': nextScheduledAt.toIso8601String(),
    };
  }

  factory MemoryReinforcementProfile.fromMap(Map<dynamic, dynamic> map) {
    return MemoryReinforcementProfile(
      memoryItemId: map['memoryItemId'] ?? '',
      importance: RecognitionImportance.values[map['importance'] ?? 1],
      totalTimesAsked: map['totalTimesAsked'] ?? 0,
      lastAskedAt: map['lastAskedAt'] != null ? DateTime.parse(map['lastAskedAt']) : null,
      consecutiveCorrectAnswers: map['consecutiveCorrectAnswers'] ?? 0,
      nextScheduledAt: DateTime.parse(map['nextScheduledAt']),
    );
  }

  MemoryReinforcementProfile copyWith({
    int? totalTimesAsked,
    DateTime? lastAskedAt,
    int? consecutiveCorrectAnswers,
    DateTime? nextScheduledAt,
  }) {
    return MemoryReinforcementProfile(
      memoryItemId: memoryItemId,
      importance: importance,
      totalTimesAsked: totalTimesAsked ?? this.totalTimesAsked,
      lastAskedAt: lastAskedAt ?? this.lastAskedAt,
      consecutiveCorrectAnswers: consecutiveCorrectAnswers ?? this.consecutiveCorrectAnswers,
      nextScheduledAt: nextScheduledAt ?? this.nextScheduledAt,
    );
  }
}
