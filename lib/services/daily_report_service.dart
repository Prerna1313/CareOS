import '../models/my_day/daily_checkin_entry.dart';
import 'memory_service.dart';

class DailyReportService {
  final MemoryService? _memoryService;

  DailyReportService([this._memoryService]);

  DailyCheckinEntry generateReport(DailyCheckinEntry entry) {
    final answers = entry.answers;
    
    // 1. Completion Score
    final answeredCount = answers.where((a) => !a.isSkipped).length;
    final totalQuestions = answers.length;
    
    // 2. Behavioral Signals (Rule-based derivation)
    // Q2: Social Interaction
    // Q3: Movement/Outing
    // Q5: Mood
    
    bool social = false;
    bool moved = false;
    String mood = 'Neutral';

    if (answers.length >= 5) {
      // Logic based on index (0-indexed)
      // Q2 (index 1): Social interaction
      if (!answers[1].isSkipped && answers[1].answer.toLowerCase() != 'no' && answers[1].answer.length > 2) {
        social = true;
      }
      
      // Q3 (index 2): Movement
      if (!answers[2].isSkipped && answers[2].answer.toLowerCase() != 'no' && answers[2].answer.length > 2) {
        moved = true;
      }
      
      // Q5 (index 4): Mood
      final moodText = answers[4].answer.toLowerCase();
      if (moodText.contains('good') || moodText.contains('happy') || moodText.contains('great')) {
        mood = 'Positive';
      } else if (moodText.contains('sad') || moodText.contains('tired') || moodText.contains('bad') || moodText.contains('confused')) {
        mood = 'Low';
      }
    }

    // 3. Summary Generation
    String summary = "";
    if (answeredCount == 0) {
      summary = "No data recorded for today.";
    } else {
      if (social && moved) {
        summary = "You had a productive day with social interaction and some activity.";
      } else if (social) {
        summary = "You enjoyed some social time today, which is great for the soul.";
      } else if (moved) {
        summary = "You stayed active today, keeping your body moving.";
      } else {
        summary = "A quiet day spent reflecting. It's good to rest sometimes.";
      }
      
      if (mood == 'Low') {
        summary += " You seemed a bit low; remember to reach out to loved ones.";
      }

      // Add memory acknowledgment
      if (_memoryService != null) {
        final todayMemories = _memoryService.getAllMemories().where((m) {
          final now = DateTime.now();
          return m.createdAt.year == now.year && 
                 m.createdAt.month == now.month && 
                 m.createdAt.day == now.day;
        }).length;
        
        if (todayMemories > 0) {
          summary += " Also, you captured $todayMemories beautiful moments today!";
        }
      }
    }

    return entry.copyWith(
      mood: mood,
      socialInteraction: social,
      wentOut: moved,
      summary: summary,
      skippedCount: totalQuestions - answeredCount,
    );
  }
}
