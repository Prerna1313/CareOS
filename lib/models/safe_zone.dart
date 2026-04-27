enum SafeZoneType { home, hospital, relative, custom }

class SafeZone {
  final String id;
  final String patientId;
  final String name;
  final SafeZoneType type;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;

  const SafeZone({
    required this.id,
    required this.patientId,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 50.0,
    this.isActive = true,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      name: json['name'] as String,
      type: SafeZoneType.values.byName(json['type'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      isActive: json['isActive'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'name': name,
        'type': type.name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'isActive': isActive,
      };

  SafeZone copyWith({
    String? name,
    SafeZoneType? type,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isActive,
  }) {
    return SafeZone(
      id: id,
      patientId: patientId,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
    );
  }
}
