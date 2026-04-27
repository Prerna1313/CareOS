import 'package:hive_flutter/hive_flutter.dart';

import '../models/caregiver_report.dart';

class CaregiverReportService {
  static const String _boxName = 'caregiver_reports';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<Box> _openBox() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : Hive.openBox(_boxName);

  Future<void> save(CaregiverReport report) async {
    final box = await _openBox();
    await box.put(report.id, report.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<CaregiverReport?> getById(String id) async {
    final box = await _openBox();
    final raw = box.get(id);
    if (raw == null) return null;
    return CaregiverReport.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<CaregiverReport>> getAll(String patientId) async {
    final box = await _openBox();
    final values = box.values
        .map(
          (raw) => CaregiverReport.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .where((report) => report.patientId == patientId)
        .toList();
    values.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return values;
  }
}
