import 'dart:math';
import '../models/reminder_log.dart';
import '../models/confusion_state.dart';

class ConfusionDetectionService {
  /// Analyzes the recent event logs using a sliding window and returns a calculated ConfusionState
  ConfusionState analyze(List<ReminderLog> allLogs) {
    if (allLogs.isEmpty) {
      return const ConfusionState();
    }

    // SLIDING WINDOW: Analyze only the last 7 reminder events maximum
    final recentLogs = allLogs.take(7).toList();
    
    // We also need subsets for specific conditions
    final last5 = recentLogs.take(5).toList();
    final last6 = recentLogs.take(6).toList();

    int score = 0;
    
    // Calculate Score from the last 7 events
    // Processing from oldest to newest to handle resets properly
    for (final log in recentLogs.reversed) {
      if (log.actionTaken == ReminderAction.ignore) {
        score += 2;
      } else if (log.actionTaken == ReminderAction.remindLater) {
        score += 1;
      } else if (log.actionTaken == ReminderAction.done) {
        score = max(0, score - 2); // Done reduces score, floor at 0
      }
    }

    // Check specific conditions
    // Condition A: 3 or more Ignore actions within last 5 events
    int ignoresInLast5 = last5.where((l) => l.actionTaken == ReminderAction.ignore).length;
    bool conditionA = ignoresInLast5 >= 3;

    // Condition B: 3 or more Remind Later within last 5 events
    int delaysInLast5 = last5.where((l) => l.actionTaken == ReminderAction.remindLater).length;
    bool conditionB = delaysInLast5 >= 3;

    // Condition C: mixed pattern (Ignore + Remind Later) >= 4 within last 6 events
    int mixedInLast6 = last6.where((l) => 
      l.actionTaken == ReminderAction.ignore || 
      l.actionTaken == ReminderAction.remindLater
    ).length;
    bool conditionC = mixedInLast6 >= 4;

    List<String> reasons = [];
    ConfusionLevel level = ConfusionLevel.normal;

    // Determine Level based on explicit conditions or score
    if (conditionA || conditionB || conditionC) {
      level = ConfusionLevel.high;
      if (conditionA) reasons.add('Ignored $ignoresInLast5 of the last 5 reminders.');
      if (conditionB) reasons.add('Delayed $delaysInLast5 of the last 5 reminders.');
      if (conditionC) reasons.add('Missed or delayed $mixedInLast6 of the last 6 reminders.');
    } else {
      // Fallback to score
      if (score >= 5) {
        level = ConfusionLevel.high;
        reasons.add('Consistent pattern of missed reminders (Score: $score).');
      } else if (score >= 3) {
        level = ConfusionLevel.mild;
        reasons.add('A few missed or delayed reminders recently (Score: $score).');
      }
    }

    return ConfusionState(
      level: level,
      score: score,
      reasons: reasons,
    );
  }
}
