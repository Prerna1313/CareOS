class CameraEvent {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final String source; // e.g., "camera_live"
  final String eventType; // e.g., "snapshot"
  final String note;
  final List<String> detectedObjects;
  final String locationHint;
  final String unusualObservation;
  final String concernLevel;

  // ML Analysis Fields
  final bool hasFace;
  final int faceCount;
  final String detectedType; // person, place, event, unknown
  final DateTime? analysisTimestamp;

  CameraEvent({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    this.source = 'camera_live',
    this.eventType = 'snapshot',
    this.note = '',
    this.detectedObjects = const [],
    this.locationHint = 'unknown',
    this.unusualObservation = '',
    this.concernLevel = 'none',
    this.hasFace = false,
    this.faceCount = 0,
    this.detectedType = 'unknown',
    this.analysisTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'eventType': eventType,
      'note': note,
      'detectedObjects': detectedObjects,
      'locationHint': locationHint,
      'unusualObservation': unusualObservation,
      'concernLevel': concernLevel,
      'hasFace': hasFace,
      'faceCount': faceCount,
      'detectedType': detectedType,
      'analysisTimestamp': analysisTimestamp?.toIso8601String(),
    };
  }

  factory CameraEvent.fromMap(Map<dynamic, dynamic> map) {
    return CameraEvent(
      id: map['id'] ?? '',
      imagePath: map['imagePath'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      source: map['source'] ?? 'camera_live',
      eventType: map['eventType'] ?? 'snapshot',
      note: map['note'] ?? '',
      detectedObjects: List<String>.from(map['detectedObjects'] ?? const []),
      locationHint: map['locationHint'] ?? 'unknown',
      unusualObservation: map['unusualObservation'] ?? '',
      concernLevel: map['concernLevel'] ?? 'none',
      hasFace: map['hasFace'] ?? false,
      faceCount: map['faceCount'] ?? 0,
      detectedType: map['detectedType'] ?? 'unknown',
      analysisTimestamp: map['analysisTimestamp'] != null
          ? DateTime.parse(map['analysisTimestamp'])
          : null,
    );
  }

  CameraEvent copyWith({
    String? note,
    List<String>? detectedObjects,
    String? locationHint,
    String? unusualObservation,
    String? concernLevel,
    bool? hasFace,
    int? faceCount,
    String? detectedType,
    DateTime? analysisTimestamp,
  }) {
    return CameraEvent(
      id: id,
      imagePath: imagePath,
      timestamp: timestamp,
      source: source,
      eventType: eventType,
      note: note ?? this.note,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      locationHint: locationHint ?? this.locationHint,
      unusualObservation: unusualObservation ?? this.unusualObservation,
      concernLevel: concernLevel ?? this.concernLevel,
      hasFace: hasFace ?? this.hasFace,
      faceCount: faceCount ?? this.faceCount,
      detectedType: detectedType ?? this.detectedType,
      analysisTimestamp: analysisTimestamp ?? this.analysisTimestamp,
    );
  }
}
