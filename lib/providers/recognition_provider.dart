import 'package:flutter/material.dart';
import '../models/recognition/recognition_task.dart';
import '../models/memory_item.dart';
import '../services/recognition_service.dart';

class RecognitionProvider extends ChangeNotifier {
  final RecognitionService _service;

  List<RecognitionTask> _todayTasks = [];
  List<RecognitionTask> _optionalTasks = [];
  bool _isLoading = false;

  RecognitionProvider(this._service) {
    _loadTasks();
  }

  List<RecognitionTask> get todayTasks => _todayTasks;
  List<RecognitionTask> get optionalTasks => _optionalTasks;
  bool get isLoading => _isLoading;

  Map<String, dynamic> buildRecognitionDigest(String patientId) {
    return _service.buildRecognitionDigest(patientId);
  }

  Future<void> _loadTasks() async {
    _isLoading = true;
    notifyListeners();

    await _service.init();
    _todayTasks = _service.getTodayTasks();
    _optionalTasks = _service.getOptionalPracticeTasks();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshTasks() async {
    await _loadTasks();
  }

  Future<RecognitionTask?> createConfusionSupportTask(
    MemoryItem memoryItem,
  ) async {
    final task = _service.createConfusionSupportTask(memoryItem);
    await _loadTasks();
    return task;
  }

  Future<void> submitResponse({
    required RecognitionTask task,
    required String responseText,
    required bool isSkipped,
    required int responseTimeSeconds,
    required MemoryItem memoryItem,
  }) async {
    await _service.submitResponse(
      task: task,
      responseText: responseText,
      isSkipped: isSkipped,
      responseTimeSeconds: responseTimeSeconds,
      memoryItem: memoryItem,
    );

    await _loadTasks(); // Refresh to remove the completed task
  }
}
