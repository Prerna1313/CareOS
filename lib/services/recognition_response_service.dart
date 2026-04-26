import 'package:hive_flutter/hive_flutter.dart';
import '../models/recognition/recognition_response.dart';

/// Lightweight Recognition Signal Logging Layer (Phase 1)
/// Captures and stores minimal cognitive signals from recognition tasks.
class RecognitionResponseService {
  static const String responseBoxName = 'recognition_responses';

  Future<void> init() async {
    if (!Hive.isBoxOpen(responseBoxName)) {
      await Hive.openBox(responseBoxName);
    }
  }

  Box get _responseBox => Hive.box(responseBoxName);

  /// Saves a recognition response to persistent storage.
  /// Each response is appended to the box to ensure historical data is preserved.
  Future<void> saveResponse(RecognitionResponse response) async {
    await _responseBox.add(response.toMap());
  }

  /// Retrieves all responses for a specific memory item.
  List<RecognitionResponse> getResponsesByMemoryId(String memoryId) {
    return _responseBox.values
        .map((m) => RecognitionResponse.fromMap(m))
        .where((r) => r.memoryItemId == memoryId)
        .toList();
  }

  /// Retrieves all historical recognition responses.
  List<RecognitionResponse> getAllResponses() {
    return _responseBox.values
        .map((m) => RecognitionResponse.fromMap(m))
        .toList();
  }

  List<RecognitionResponse> getResponsesByPatientId(String patientId) {
    return getAllResponses()
        .where((response) => response.patientId == patientId)
        .toList();
  }
}
