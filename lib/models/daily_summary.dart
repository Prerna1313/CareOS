class DailySummary {
  final String patientId;
  final DateTime date;
  final double confusionFrequency; // 0.0 to 1.0 (percent of day confused)
  final int alertCount;
  final double medicineAdherence; // 0.0 to 1.0
  final int memoryCueEngagement; // count of interacted cues
  final String moodSummary; // e.g. "Calm and cooperative"
  final double routineAdherence; // 0.0 to 1.0
  final String activityLevel; // e.g. "High", "Normal", "Low"
  final int stepsToday;

  const DailySummary({
    required this.patientId,
    required this.date,
    required this.confusionFrequency,
    required this.alertCount,
    required this.medicineAdherence,
    required this.memoryCueEngagement,
    required this.moodSummary,
    required this.routineAdherence,
    required this.activityLevel,
    required this.stepsToday,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      patientId: json['patientId'] as String,
      date: DateTime.parse(json['date'] as String),
      confusionFrequency: (json['confusionFrequency'] as num).toDouble(),
      alertCount: json['alertCount'] as int,
      medicineAdherence: (json['medicineAdherence'] as num).toDouble(),
      memoryCueEngagement: json['memoryCueEngagement'] as int,
      moodSummary: json['moodSummary'] as String,
      routineAdherence: (json['routineAdherence'] as num).toDouble(),
      activityLevel: json['activityLevel'] as String,
      stepsToday: json['stepsToday'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'date': date.toIso8601String(),
        'confusionFrequency': confusionFrequency,
        'alertCount': alertCount,
        'medicineAdherence': medicineAdherence,
        'memoryCueEngagement': memoryCueEngagement,
        'moodSummary': moodSummary,
        'routineAdherence': routineAdherence,
        'activityLevel': activityLevel,
        'stepsToday': stepsToday,
      };
}
