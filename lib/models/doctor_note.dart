class DoctorNote {
  final String id;
  final String patientId;
  final String authorName;
  final String note;
  final String recommendation;
  final DateTime createdAt;

  const DoctorNote({
    required this.id,
    required this.patientId,
    required this.authorName,
    required this.note,
    required this.recommendation,
    required this.createdAt,
  });

  factory DoctorNote.fromMap(Map<String, dynamic> map) {
    return DoctorNote(
      id: map['id']?.toString() ?? '',
      patientId: map['patientId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ?? 'Assigned Doctor',
      note: map['note']?.toString() ?? '',
      recommendation: map['recommendation']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'authorName': authorName,
      'note': note,
      'recommendation': recommendation,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
