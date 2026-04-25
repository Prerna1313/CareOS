import 'package:flutter/material.dart';
import '../models/recognition/recognition_task.dart';
import '../models/memory_item.dart';
import '../services/recognition_service.dart';

class RecognitionProvider extends ChangeNotifier {
  final RecognitionService _service;
  
  List<RecognitionTask> _todayTasks = [];
  bool _isLoading = false;

  RecognitionProvider(this._service) {
    _loadTasks();
  }

  List<RecognitionTask> get todayTasks => _todayTasks;
  bool get isLoading => _isLoading;

  Future<void> _loadTasks() async {
    _isLoading = true;
    notifyListeners();
    
    await _service.init();
    _todayTasks = _service.getTodayTasks();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshTasks() async {
    await _loadTasks();
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
