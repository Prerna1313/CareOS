enum ReportCategory { mood, behavior, incident, confusion, medication, activity, other }

extension ReportCategoryExtension on ReportCategory {
  String get displayName {
    switch (this) {
      case ReportCategory.mood: return 'Mood Observation';
      case ReportCategory.behavior: return 'Behavior Change';
      case ReportCategory.incident: return 'Incident';
      case ReportCategory.confusion: return 'Confusion Episode';
      case ReportCategory.medication: return 'Medication Issue';
      case ReportCategory.activity: return 'Activity Change';
      case ReportCategory.other: return 'Other';
    }
  }
}

class CaregiverReport {
  final String id;
  final String patientId;
  final String caregiverId;
  final ReportCategory category;
  final String note;
  final DateTime timestamp;
  final bool visibleToDoctor;

  const CaregiverReport({
    required this.id,
    required this.patientId,
    required this.caregiverId,
    required this.category,
    required this.note,
    required this.timestamp,
    this.visibleToDoctor = true,
  });

  factory CaregiverReport.fromJson(Map<String, dynamic> json) {
    return CaregiverReport(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      caregiverId: json['caregiverId'] as String,
      category: ReportCategory.values.byName(json['category'] as String),
      note: json['note'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      visibleToDoctor: json['visibleToDoctor'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'caregiverId': caregiverId,
        'category': category.name,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
        'visibleToDoctor': visibleToDoctor,
      };

  CaregiverReport copyWith({
    ReportCategory? category,
    String? note,
    DateTime? timestamp,
    bool? visibleToDoctor,
  }) {
    return CaregiverReport(
      id: id,
      patientId: patientId,
      caregiverId: caregiverId,
      category: category ?? this.category,
      note: note ?? this.note,
      timestamp: timestamp ?? this.timestamp,
      visibleToDoctor: visibleToDoctor ?? this.visibleToDoctor,
    );
  }
}
