import 'package:hive_flutter/hive_flutter.dart';

import '../models/patient/backend_processing_models.dart';

class BackendSpeechResultService {
  static const String boxName = 'backend_speech_results';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box get _box => Hive.box(boxName);

  Future<void> saveResult(BackendSpeechProcessingResult result) async {
    await _box.put(result.requestId, result.toMap());
  }

  List<BackendSpeechProcessingResult> getByPatientId(String patientId) {
    return _box.values
        .map((item) => BackendSpeechProcessingResult.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.patientId == patientId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  BackendSpeechProcessingResult? getLatestForPatient(String patientId) {
    final results = getByPatientId(patientId);
    return results.isEmpty ? null : results.first;
  }
}
