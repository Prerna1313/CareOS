enum AlertSeverity { low, medium, high, critical }
enum AlertStatus { active, acknowledged, resolved }
enum AlertType { confusion, inactivity, missedReminder, geofence, routineDeviation, emergency }

class Alert {
  final String id;
  final String patientId;
  final AlertType type;
  final AlertSeverity severity;
  final DateTime timestamp;
  final String title;
  final String message;
  final String? explanation; // Why it was generated
  final String? recommendedAction;
  final AlertStatus status;
  final String? resolvedBy; // Caregiver ID who resolved it
  final DateTime? resolvedAt;

  const Alert({
    required this.id,
    required this.patientId,
    required this.type,
    required this.severity,
    required this.timestamp,
    required this.title,
    required this.message,
    this.explanation,
    this.recommendedAction,
    this.status = AlertStatus.active,
    this.resolvedBy,
    this.resolvedAt,
  });

  Alert copyWith({
    AlertStatus? status,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return Alert(
      id: id,
      patientId: patientId,
      type: type,
      severity: severity,
      timestamp: timestamp,
      title: title,
      message: message,
      explanation: explanation,
      recommendedAction: recommendedAction,
      status: status ?? this.status,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      type: AlertType.values.byName(json['type'] as String),
      severity: AlertSeverity.values.byName(json['severity'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      explanation: json['explanation'] as String?,
      recommendedAction: json['recommendedAction'] as String?,
      status: AlertStatus.values.byName(json['status'] as String),
      resolvedBy: json['resolvedBy'] as String?,
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'type': type.name,
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'title': title,
        'message': message,
        'explanation': explanation,
        'recommendedAction': recommendedAction,
        'status': status.name,
        'resolvedBy': resolvedBy,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };
}
