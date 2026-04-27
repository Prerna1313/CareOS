import 'package:hive_flutter/hive_flutter.dart';

import '../models/patient/backend_processing_models.dart';

class BackendVideoResultService {
  static const String boxName = 'backend_video_results';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box get _box => Hive.box(boxName);

  Future<void> saveResult(BackendVideoProcessingResult result) async {
    await _box.put(result.clipId, result.toMap());
  }

  List<BackendVideoProcessingResult> getByPatientId(String patientId) {
    return _box.values
        .map((item) => BackendVideoProcessingResult.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.patientId == patientId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  BackendVideoProcessingResult? getLatestForPatient(String patientId) {
    final results = getByPatientId(patientId);
    return results.isEmpty ? null : results.first;
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
