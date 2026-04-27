import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/exported_report_file.dart';
import '../models/progress_report.dart';

class CaregiverReportExportService {
  static const String _boxName = 'exported_report_files';
  final Uuid _uuid = const Uuid();

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<Box> _openBox() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : Hive.openBox(_boxName);

  Future<ExportedReportFile> exportProgressReport({
    required String patientId,
    required String patientName,
    required ProgressReport report,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(directory.path, 'caregiver_reports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final safeName = patientName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final file = File(
      path.join(
        exportDir.path,
        '${safeName}_progress_${DateTime.now().millisecondsSinceEpoch}.txt',
      ),
    );

    final content = StringBuffer()
      ..writeln('CareOS Progress Report')
      ..writeln('Patient: $patientName')
      ..writeln('Date range: ${report.dateRange}')
      ..writeln('Generated at: ${report.generatedAt.toIso8601String()}')
      ..writeln('')
      ..writeln('Alert Summary')
      ..writeln('High: ${report.alertSummary['high'] ?? 0}')
      ..writeln('Medium: ${report.alertSummary['medium'] ?? 0}')
      ..writeln('Low: ${report.alertSummary['low'] ?? 0}')
      ..writeln('')
      ..writeln('Medication Adherence: ${(report.medicationAdherence * 100).round()}%')
      ..writeln('Location Safety: ${report.locationSafety}')
      ..writeln('')
      ..writeln('Recommendations:')
      ..writeln(report.recommendedActions.map((item) => '- $item').join('\n'));

    await file.writeAsString(content.toString());

    final exported = ExportedReportFile(
      id: _uuid.v4(),
      patientId: patientId,
      title: 'Progress Report',
      filePath: file.path,
      createdAt: DateTime.now(),
      format: 'txt',
    );

    final box = await _openBox();
    await box.put(exported.id, exported.toJson());
    return exported;
  }

  Future<List<ExportedReportFile>> getAll(String patientId) async {
    final box = await _openBox();
    final files = box.values
        .map(
          (raw) => ExportedReportFile.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .where((item) => item.patientId == patientId)
        .toList();
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }
}
