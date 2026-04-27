import '../models/my_day/daily_checkin_entry.dart';
import 'backend_speech_result_service.dart';
import 'backend_processing_service.dart';
import 'cloud_ai_service.dart';

class DailySummaryService {
  final CloudAIService _aiService;
  final BackendProcessingService? _backendProcessingService;
  final BackendSpeechResultService? _backendSpeechResultService;

  DailySummaryService(
    this._aiService, {
    BackendProcessingService? backendProcessingService,
    BackendSpeechResultService? backendSpeechResultService,
  }) : _backendProcessingService = backendProcessingService,
       _backendSpeechResultService = backendSpeechResultService;

  Future<String> generateSummary(DailyCheckinEntry entry) async {
    final answers = entry.answers;
    if (answers.isEmpty) return "No check-in data available for today.";

    // Use Vertex AI for an empathetic summary
    return await _aiService.generateDailySummary(entry);
  }

  Future<String> transcribeAudio(
    String path, {
    String patientId = 'patient_local_demo',
    String source = 'voiceDiary',
  }) async {
    if (_backendProcessingService?.isConfigured == true) {
      final backendResult = await _backendProcessingService!.processSpeechAudio(
        patientId: patientId,
        source: source,
        audioPath: path,
      );
      if (backendResult != null) {
        await _backendSpeechResultService?.saveResult(backendResult);
      }
      final transcript = backendResult?.transcript.trim() ?? '';
      if (transcript.isNotEmpty) {
        return transcript;
      }
    }

    return await _aiService.transcribeAudio(path);
  }
}
