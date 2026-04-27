class PatientLocationPing {
  final String id;
  final String patientId;
  final String label;
  final double latitude;
  final double longitude;
  final String source;
  final DateTime capturedAt;

  const PatientLocationPing({
    required this.id,
    required this.patientId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.capturedAt,
  });

  factory PatientLocationPing.fromJson(Map<String, dynamic> json) {
    return PatientLocationPing(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      label: json['label'] as String? ?? 'Unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      source: json['source'] as String? ?? 'manual',
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
        'capturedAt': capturedAt.toIso8601String(),
      };
}
