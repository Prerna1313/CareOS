import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recognition/recognition_task.dart';
import '../models/recognition/recognition_response.dart';
import '../models/recognition/memory_reinforcement_profile.dart';
import '../models/memory_item.dart';
import 'recognition_response_service.dart';
import 'cloud_ai_service.dart';

class RecognitionService {
  static const String taskBoxName = 'recognition_tasks';
  static const String profileBoxName = 'recognition_profiles';
  
  final RecognitionResponseService _responseService;
  final CloudAIService _aiService;
  final Uuid _uuid = const Uuid();

  RecognitionService(this._responseService, this._aiService);

  Future<void> init() async {
    await Hive.openBox(taskBoxName);
    await Hive.openBox(profileBoxName);
    await _responseService.init();
  }

  Box get _taskBox => Hive.box(taskBoxName);
  Box get _profileBox => Hive.box(profileBoxName);

  /// Schedules the initial reinforcement profile for a new memory
  Future<void> onMemoryAdded(MemoryItem item) async {
    // Determine importance based on tags or type
    RecognitionImportance importance = RecognitionImportance.medium;
    if (item.tags.any((tag) => tag.toLowerCase().contains('daughter') || 
                               tag.toLowerCase().contains('son') || 
                               tag.toLowerCase().contains('husband') || 
                               tag.toLowerCase().contains('wife'))) {
      importance = RecognitionImportance.high;
    }

    final profile = MemoryReinforcementProfile(
      memoryItemId: item.id,
      importance: importance,
      nextScheduledAt: DateTime.now().add(const Duration(days: 1)),
    );

    await _profileBox.put(item.id, profile.toMap());
    await _generateTaskForProfile(profile, item);
  }

  Future<void> _generateTaskForProfile(MemoryReinforcementProfile profile, MemoryItem item) async {
    String questionText = "Who is this?";
    String questionType = "who";

    if (item.type == MemoryType.place) {
      questionText = "Do you remember this place?";
      questionType = "where";
    } else if (item.type == MemoryType.event) {
      questionText = "Do you remember what happened here?";
      questionType = "what";
    }

    final task = RecognitionTask(
      id: _uuid.v4(),
      patientId: item.patientId,
      memoryItemId: item.id,
      questionType: questionType,
      questionText: questionText,
      scheduledFor: profile.nextScheduledAt,
      createdAt: DateTime.now(),
      importance: profile.importance,
    );

    await _taskBox.put(task.id, task.toMap());
  }

  List<RecognitionTask> getTodayTasks() {
    final now = DateTime.now();
    return _taskBox.values
        .map((m) => RecognitionTask.fromMap(m))
        .where((t) => t.status == RecognitionTaskStatus.pending && 
                       t.scheduledFor.isBefore(now.add(const Duration(hours: 1))))
        .toList()
      ..sort((a, b) => b.importance.index.compareTo(a.importance.index));
  }

  Future<void> submitResponse({
    required RecognitionTask task,
    required String responseText,
    required bool isSkipped,
    required int responseTimeSeconds,
    required MemoryItem memoryItem,
  }) async {
    // 1. Evaluate (Phase 1: Simple Match)
    EvaluationStatus evaluation = EvaluationStatus.notEvaluated;
    bool? isCorrect;
    
    if (isSkipped) {
      evaluation = EvaluationStatus.notEvaluated;
      isCorrect = false;
    } else {
      // Use AI for semantic matching
      final isAiCorrect = await _aiService.evaluateRecognitionResponse(
        responseText: responseText,
        memoryItem: memoryItem,
      );
      
      if (isAiCorrect) {
        evaluation = EvaluationStatus.correct;
        isCorrect = true;
      } else {
        evaluation = EvaluationStatus.manualReview;
        isCorrect = null; // Manual review needed, status ambiguous
      }
    }

    // 2. Log Response via dedicated Response Service
    final response = RecognitionResponse(
      id: _uuid.v4(),
      taskId: task.id,
      patientId: task.patientId,
      memoryItemId: task.memoryItemId,
      responseText: responseText,
      isSkipped: isSkipped,
      isCorrect: isCorrect,
      responseTimeSeconds: responseTimeSeconds,
      answeredAt: DateTime.now(),
      evaluationStatus: evaluation,
    );

    await _responseService.saveResponse(response);

    // 3. Update Task Status
    final updatedTask = task.copyWith(status: RecognitionTaskStatus.completed);
    await _taskBox.put(task.id, updatedTask.toMap());

    // 4. Update Reinforcement Profile (Spaced Repetition)
    final profileData = _profileBox.get(task.memoryItemId);
    if (profileData != null) {
      final profile = MemoryReinforcementProfile.fromMap(profileData);
      
      int nextDays = 1;
      if (evaluation == EvaluationStatus.correct) {
        // Spaced repetition: 1, 3, 7, 14, 30...
        final intervals = [1, 3, 7, 14, 30, 60, 90];
        int currentIdx = intervals.indexOf(profile.nextScheduledAt.difference(profile.lastAskedAt ?? profile.nextScheduledAt.subtract(const Duration(days: 1))).inDays);
        if (currentIdx == -1) currentIdx = 0;
        nextDays = intervals[currentIdx < intervals.length - 1 ? currentIdx + 1 : currentIdx];
      }

      final updatedProfile = profile.copyWith(
        totalTimesAsked: profile.totalTimesAsked + 1,
        lastAskedAt: DateTime.now(),
        consecutiveCorrectAnswers: evaluation == EvaluationStatus.correct ? profile.consecutiveCorrectAnswers + 1 : 0,
        nextScheduledAt: DateTime.now().add(Duration(days: nextDays)),
      );

      await _profileBox.put(task.memoryItemId, updatedProfile.toMap());
      
      // Schedule the next one if it's a high importance memory or we still need reinforcement
      if (updatedProfile.totalTimesAsked < 10) {
        await _generateTaskForProfile(updatedProfile, memoryItem);
      }
    }
  }
}
