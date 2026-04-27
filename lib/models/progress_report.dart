class ProgressReport {
  final String id;
  final String patientId;
  final String generatedBy;
  final DateTime generatedAt;
  final String dateRange;
  final Map<String, int> alertSummary;
  final double medicationAdherence;
  final String locationSafety;
  final List<String> recommendedActions;

  const ProgressReport({
    required this.id,
    required this.patientId,
    required this.generatedBy,
    required this.generatedAt,
    required this.dateRange,
    required this.alertSummary,
    required this.medicationAdherence,
    required this.locationSafety,
    required this.recommendedActions,
  });

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    return ProgressReport(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      generatedBy: json['generatedBy'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      dateRange: json['dateRange'] as String,
      alertSummary: Map<String, int>.from(json['alertSummary'] as Map),
      medicationAdherence: (json['medicationAdherence'] as num).toDouble(),
      locationSafety: json['locationSafety'] as String,
      recommendedActions: (json['recommendedActions'] as List).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'generatedBy': generatedBy,
        'generatedAt': generatedAt.toIso8601String(),
        'dateRange': dateRange,
        'alertSummary': alertSummary,
        'medicationAdherence': medicationAdherence,
        'locationSafety': locationSafety,
        'recommendedActions': recommendedActions,
      };
}
