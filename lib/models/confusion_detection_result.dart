enum ConfusionRiskLevel { stable, mild, moderate, high }

class ConfusionDetectionResult {
  final String patientId;
  final double score; // 0.0 to 100.0
  final ConfusionRiskLevel riskLevel;
  final List<String> detectedSignals; // e.g. ["delayed_response", "repeated_words"]
  final String explanation;
  final bool memoryCueNeeded;
  final DateTime timestamp;
  final String source;

  const ConfusionDetectionResult({
    required this.patientId,
    required this.score,
    required this.riskLevel,
    required this.detectedSignals,
    required this.explanation,
    required this.memoryCueNeeded,
    required this.timestamp,
    this.source = 'gemini_confusion_assessment',
  });

  factory ConfusionDetectionResult.fromJson(Map<String, dynamic> json) {
    return ConfusionDetectionResult(
      patientId: json['patientId'] as String? ?? 'unknown_patient',
      score: (json['score'] as num).toDouble(),
      riskLevel: ConfusionRiskLevel.values.byName(json['riskLevel'] as String),
      detectedSignals:
          (json['detectedSignals'] as List).map((e) => e.toString()).toList(),
      explanation: json['explanation'] as String,
      memoryCueNeeded: json['memoryCueNeeded'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source:
          json['source'] as String? ?? 'gemini_confusion_assessment',
    );
  }

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'score': score,
        'riskLevel': riskLevel.name,
        'detectedSignals': detectedSignals,
        'explanation': explanation,
        'memoryCueNeeded': memoryCueNeeded,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
      };
}
