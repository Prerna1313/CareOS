import 'package:flutter/material.dart';
import '../services/daily_checkin_service.dart';
import '../services/daily_report_service.dart';
import '../services/daily_summary_service.dart';
import '../services/firestore/firestore_daily_checkin_service.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/my_day/daily_checkin_entry.dart';
import '../models/my_day/question_response.dart';
import '../models/my_day/voice_diary_entry.dart';

class MyDayProvider extends ChangeNotifier {
  final DailyCheckinService _storageService;
  final DailyReportService _reportService;
  final DailySummaryService _summaryService;
  final FirestoreDailyCheckinService? _firestoreService;
  final AudioRecorder _recorder = AudioRecorder();

  MyDayProvider(
    this._storageService,
    this._reportService,
    this._summaryService, {
    FirestoreDailyCheckinService? firestoreService,
  }) : _firestoreService = firestoreService {
    _loadHistory();
    _loadTodayEntry();
  }

  // Overlay state
  bool _isOverlayVisible = true;
  bool get isOverlayVisible => _isOverlayVisible;

  int _currentQuestionIndex = 0;
  int get currentQuestionIndex => _currentQuestionIndex;

  bool _isChatCompleted = false;
  bool get isChatCompleted => _isChatCompleted;

  int get totalQuestionCount => questions.length;
  int get answeredQuestionCount =>
      _todayEntry?.answers.where((answer) => !answer.isSkipped).length ?? 0;
  int get skippedQuestionCount => _todayEntry?.skippedCount ?? 0;
  bool get hasGuidedResponses =>
      _todayEntry != null && _todayEntry!.answers.isNotEmpty;
  bool get hasDraftContent {
    final entry = _todayEntry;
    if (entry == null) return false;
    return entry.textField1.trim().isNotEmpty ||
        entry.textField2.trim().isNotEmpty ||
        entry.voiceNote != null ||
        entry.answers.isNotEmpty;
  }

  double get completionProgress {
    if (hasGuidedResponses) {
      return answeredQuestionCount / totalQuestionCount;
    }
    if (hasDraftContent) return 0.25;
    return 0;
  }

  String get completionLabel {
    if (isChatCompleted && hasGuidedResponses) {
      return 'Completed';
    }
    if (hasDraftContent) {
      return 'In progress';
    }
    return 'Not started';
  }

  final List<String> questions = [
    "What did you eat today?",
    "Did you meet someone today? Who?",
    "Did you go anywhere today? Where?",
    "What did you do most of the day?",
    "How are you feeling today?",
    "What was the best part of your day?",
    "What is one thing you did today that you would like to remember later?",
  ];

  // Timing tracking
  DateTime? _questionStartTime;
  final Map<int, int> _responseTimes = {}; // index -> seconds

  // Current session data
  final Map<int, String> _chatResponses = {};
  Map<int, String> get chatResponses => _chatResponses;

  final Set<int> _skippedIndices = {};

  // Persistence data
  List<DailyCheckinEntry> _history = [];
  List<DailyCheckinEntry> get history => _history;

  DailyCheckinEntry? _todayEntry;
  DailyCheckinEntry? get todayEntry => _todayEntry;
  DailyCheckinEntry? get yesterdayEntry => _storageService.getEntryByDate(
    DateTime.now().subtract(const Duration(days: 1)),
  );

  // Voice Recording state
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  DateTime? _recordingStartTime;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  void _loadHistory() {
    _history = _storageService.getAllEntries();
    notifyListeners();
  }

  void _loadTodayEntry() {
    _todayEntry = _storageService.getEntryByDate(DateTime.now());
    if (_todayEntry != null && _todayEntry!.answers.isNotEmpty) {
      _isChatCompleted = true;
      _isOverlayVisible = false;
    } else {
      // Keep drafts local without forcing the overlay open.
      _isOverlayVisible = false;
      _isChatCompleted = false;
    }
    notifyListeners();
  }

  void startChat() {
    _isOverlayVisible = true;
    _currentQuestionIndex = 0;
    _isChatCompleted = false;
    _chatResponses.clear();
    _skippedIndices.clear();
    _responseTimes.clear();
    _questionStartTime = DateTime.now();
    notifyListeners();
  }

  void resumeOrStartChat() {
    startChat();
  }

  Future<void> answerQuestion(String answer) async {
    if (_isChatCompleted) return;

    final now = DateTime.now();
    if (_questionStartTime != null) {
      _responseTimes[_currentQuestionIndex] = now
          .difference(_questionStartTime!)
          .inSeconds;
    }

    if (answer.trim().isNotEmpty) {
      _chatResponses[_currentQuestionIndex] = answer.trim();
    }
    await _nextQuestion();
  }

  Future<void> skipQuestion() async {
    if (_isChatCompleted) return;

    final now = DateTime.now();
    if (_questionStartTime != null) {
      _responseTimes[_currentQuestionIndex] = now
          .difference(_questionStartTime!)
          .inSeconds;
    }
    _skippedIndices.add(_currentQuestionIndex);
    await _nextQuestion();
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex < questions.length - 1) {
      _currentQuestionIndex++;
      _questionStartTime = DateTime.now();
    } else {
      _isChatCompleted = true;
      await _saveChatToEntry();
    }
    notifyListeners();
  }

  Future<void> _saveChatToEntry() async {
    final List<QuestionResponse> qResponses = [];
    int totalTime = 0;

    for (int i = 0; i < questions.length; i++) {
      final time = _responseTimes[i] ?? 0;
      totalTime += time;
      qResponses.add(
        QuestionResponse(
          question: questions[i],
          answer: _chatResponses[i] ?? '',
          isSkipped: _skippedIndices.contains(i),
          responseTimeSeconds: time,
        ),
      );
    }

    final entry = DailyCheckinEntry(
      date: DateTime.now(),
      answers: qResponses,
      totalResponseTimeSeconds: totalTime,
      skippedCount: _skippedIndices.length,
      textField1: _todayEntry?.textField1 ?? '',
      textField2: _todayEntry?.textField2 ?? '',
      voiceNote: _todayEntry?.voiceNote,
    );

    _todayEntry = _reportService.generateReport(entry);

    // Generate the patient-friendly summary using the new DailySummaryService
    final patientSummary = await _summaryService.generateSummary(_todayEntry!);
    _todayEntry = _todayEntry!.copyWith(summary: patientSummary);

    _storageService.saveDailyEntry(_todayEntry!);
    _firestoreService?.syncDailyEntry(_todayEntry!);
    _loadHistory();
  }

  void dismissOverlay() {
    if (!_isOverlayVisible) return;
    _isOverlayVisible = false;
    notifyListeners();
  }

  // Diary Updates (Main Page)
  void updateTextField1(String value) {
    if (_todayEntry == null) {
      _todayEntry = DailyCheckinEntry(
        date: DateTime.now(),
        answers: [],
        textField1: value,
      );
    } else {
      _todayEntry = _todayEntry!.copyWith(textField1: value);
    }
    _storageService.saveDailyEntry(_todayEntry!);
    _firestoreService?.syncDailyEntry(_todayEntry!);
    _loadHistory();
    notifyListeners();
  }

  void updateTextField2(String value) {
    if (_todayEntry == null) {
      _todayEntry = DailyCheckinEntry(
        date: DateTime.now(),
        answers: [],
        textField2: value,
      );
    } else {
      _todayEntry = _todayEntry!.copyWith(textField2: value);
    }
    _storageService.saveDailyEntry(_todayEntry!);
    _firestoreService?.syncDailyEntry(_todayEntry!);
    _loadHistory();
    notifyListeners();
  }

  void saveTodayEntry() {
    if (_todayEntry != null) {
      _storageService.saveDailyEntry(_todayEntry!);
      _loadHistory();
      notifyListeners();
    }
  }

  void updateMood(String mood) {
    if (_todayEntry == null) {
      _todayEntry = DailyCheckinEntry(
        date: DateTime.now(),
        answers: [],
        mood: mood,
      );
    } else {
      _todayEntry = _todayEntry!.copyWith(mood: mood);
    }
    _storageService.saveDailyEntry(_todayEntry!);
    _loadHistory();
    notifyListeners();
  }

  Future<void> restartTodayReflection() async {
    final existing = _todayEntry;
    _todayEntry = DailyCheckinEntry(
      date: DateTime.now(),
      answers: [],
      textField1: existing?.textField1 ?? '',
      textField2: existing?.textField2 ?? '',
      voiceNote: existing?.voiceNote,
      mood: existing?.mood ?? 'Neutral',
    );
    _isChatCompleted = false;
    _isOverlayVisible = false;
    await _storageService.saveDailyEntry(_todayEntry!);
    _loadHistory();
    notifyListeners();
  }

  // --- Voice Recording Implementation ---

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'voice_diary_${const Uuid().v4()}.m4a';
        final path = '${directory.path}/$fileName';

        const config = RecordConfig();

        await _recorder.start(config, path: path);
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null && _recordingStartTime != null) {
        final duration = DateTime.now()
            .difference(_recordingStartTime!)
            .inSeconds;

        // Update today's entry with the new voice note
        if (_todayEntry != null) {
          // Perform transcription
          final transcription = await _summaryService.transcribeAudio(path);

          final voiceEntry = VoiceDiaryEntry(
            filePath: path,
            transcription: transcription.isNotEmpty ? transcription : null,
            durationSeconds: duration,
            timestamp: DateTime.now(),
          );
          _todayEntry = _todayEntry!.copyWith(voiceNote: voiceEntry);

          // Regenerate summary if we have new content
          if (transcription.isNotEmpty) {
            final patientSummary = await _summaryService.generateSummary(
              _todayEntry!,
            );
            _todayEntry = _todayEntry!.copyWith(summary: patientSummary);
          }

          await _storageService.saveDailyEntry(_todayEntry!);
          await _firestoreService?.syncDailyEntry(_todayEntry!);
          _loadHistory();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> deleteVoiceNote() async {
    if (_todayEntry?.voiceNote?.filePath != null) {
      try {
        final file = File(_todayEntry!.voiceNote!.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }

    if (_todayEntry != null) {
      _todayEntry = _todayEntry!.copyWith(voiceNote: null);
      await _storageService.saveDailyEntry(_todayEntry!);
      await _firestoreService?.syncDailyEntry(_todayEntry!);
      _loadHistory();
      notifyListeners();
    }
  }
}
