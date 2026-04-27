import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class CaregiverVoiceNoteService {
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  Future<String?> startRecording() async {
    if (!await _recorder.hasPermission()) {
      return null;
    }
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/caregiver_cue_${_uuid.v4()}.m4a';
    await _recorder.start(const RecordConfig(), path: filePath);
    return filePath;
  }

  Future<String?> stopRecording() async {
    return _recorder.stop();
  }

  Future<void> deleteRecording(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
