class ExportedReportFile {
  final String id;
  final String patientId;
  final String title;
  final String filePath;
  final DateTime createdAt;
  final String format;

  const ExportedReportFile({
    required this.id,
    required this.patientId,
    required this.title,
    required this.filePath,
    required this.createdAt,
    required this.format,
  });

  factory ExportedReportFile.fromJson(Map<String, dynamic> json) {
    return ExportedReportFile(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      format: json['format'] as String? ?? 'txt',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'title': title,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'format': format,
      };
}
