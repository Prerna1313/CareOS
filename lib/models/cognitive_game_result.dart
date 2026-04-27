class CognitiveGameResult {
  final String id;
  final String patientId;
  final String gameName;
  final int score;
  final int maxScore;
  final DateTime playedAt;

  const CognitiveGameResult({
    required this.id,
    required this.patientId,
    required this.gameName,
    required this.score,
    required this.maxScore,
    required this.playedAt,
  });

  factory CognitiveGameResult.fromJson(Map<String, dynamic> json) {
    return CognitiveGameResult(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      gameName: json['gameName'] as String,
      score: json['score'] as int,
      maxScore: json['maxScore'] as int,
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'gameName': gameName,
        'score': score,
        'maxScore': maxScore,
        'playedAt': playedAt.toIso8601String(),
      };
}
