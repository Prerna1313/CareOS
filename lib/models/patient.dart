class Patient {
  final String id;
  final String name;
  final int age;
  final String condition; // e.g. "Alzheimer's Early Stage"
  final String currentStatus; // e.g. "active", "resting", "wandering"
  final DateTime lastActiveAt;
  final String? currentLocationSummary;
  final double latestConfusionScore; // 0.0 to 100.0
  final bool hasEmergency;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.condition,
    required this.currentStatus,
    required this.lastActiveAt,
    this.currentLocationSummary,
    required this.latestConfusionScore,
    this.hasEmergency = false,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      condition: json['condition'] as String,
      currentStatus: json['currentStatus'] as String,
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      currentLocationSummary: json['currentLocationSummary'] as String?,
      latestConfusionScore: (json['latestConfusionScore'] as num).toDouble(),
      hasEmergency: json['hasEmergency'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'condition': condition,
        'currentStatus': currentStatus,
        'lastActiveAt': lastActiveAt.toIso8601String(),
        'currentLocationSummary': currentLocationSummary,
        'latestConfusionScore': latestConfusionScore,
        'hasEmergency': hasEmergency,
      };
}
