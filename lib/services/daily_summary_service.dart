import '../models/my_day/daily_checkin_entry.dart';
import 'cloud_ai_service.dart';

class DailySummaryService {
  final CloudAIService _aiService;

  DailySummaryService(this._aiService);

  Future<String> generateSummary(DailyCheckinEntry entry) async {
    final answers = entry.answers;
    if (answers.isEmpty) return "No check-in data available for today.";

    // Use Vertex AI for an empathetic summary
    return await _aiService.generateDailySummary(entry);
  }

  Future<String> transcribeAudio(String path) async {
    return await _aiService.transcribeAudio(path);
  }
}
