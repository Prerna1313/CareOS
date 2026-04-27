import 'package:hive_flutter/hive_flutter.dart';

import '../models/confusion_detection_result.dart';

class ConfusionDetectionResultService {
  static const String boxName = 'confusion_detection_results';
  Box<Map>? _box;

  Future<void> init() async {
    _box = await _ensureBox();
  }

  Future<Box<Map>> _ensureBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<Map>(boxName);
      return _box!;
    }
    _box = await Hive.openBox<Map>(boxName);
    return _box!;
  }

  Future<void> saveResult(ConfusionDetectionResult result) async {
    final box = await _ensureBox();
    await box.put(
      '${result.patientId}_${result.timestamp.toIso8601String()}',
      result.toJson(),
    );
  }

  List<ConfusionDetectionResult> getByPatientId(String patientId) {
    final box = _box ??
        (Hive.isBoxOpen(boxName) ? Hive.box<Map>(boxName) : null);
    if (box == null) {
      return [];
    }

    final results = box.values
        .map((item) => ConfusionDetectionResult.fromJson(Map<String, dynamic>.from(item)))
        .where((result) => result.patientId == patientId)
        .toList();
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  ConfusionDetectionResult? getLatestForPatient(String patientId) {
    final results = getByPatientId(patientId);
    return results.isNotEmpty ? results.first : null;
  }
}
