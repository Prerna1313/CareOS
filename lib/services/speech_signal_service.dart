import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/speech_signal.dart';

class SpeechSignalService {
  static const String boxName = 'speech_signals';
  final Uuid _uuid = const Uuid();

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box get _box => Hive.box(boxName);

  Future<SpeechSignal> logSpeechSignal({
    required String patientId,
    required SpeechSignalSource source,
    required String transcript,
    required int durationSeconds,
  }) async {
    final cleanedTranscript = transcript.trim();
    final existingSignals = getByPatientId(patientId);
    final priorSignals = existingSignals
        .where((signal) => signal.source == source)
        .take(6)
        .toList();

    final normalized = _normalizeTranscript(cleanedTranscript);
    final repeatedQuery = priorSignals.any(
      (signal) => _normalizeTranscript(signal.transcript) == normalized,
    );
    final words = _tokenize(cleanedTranscript);
    final hesitancyCount = _countMarkers(
      words,
      const ['um', 'uh', 'hmm', 'maybe', 'wait', 'sorry', 'forgot'],
    );
    final distressCount = _countMarkers(
      words,
      const ['help', 'lost', 'scared', 'confused', 'anxious', 'emergency'],
    );
    final repetitionCount = _countRepetitions(words);
    final estimatedPauseCount = _estimatePauses(
      transcript: cleanedTranscript,
      durationSeconds: durationSeconds,
      wordCount: words.length,
    );

    final summary = _buildSummary(
      repeatedQuery: repeatedQuery,
      hesitancyCount: hesitancyCount,
      distressCount: distressCount,
      repetitionCount: repetitionCount,
      estimatedPauseCount: estimatedPauseCount,
      source: source,
    );

    final signal = SpeechSignal(
      id: _uuid.v4(),
      patientId: patientId,
      timestamp: DateTime.now(),
      source: source,
      transcript: cleanedTranscript,
      durationSeconds: durationSeconds,
      estimatedPauseCount: estimatedPauseCount,
      repetitionCount: repetitionCount,
      hesitancyCount: hesitancyCount,
      distressMarkerCount: distressCount,
      repeatedQuery: repeatedQuery,
      summary: summary,
    );

    await _box.put(signal.id, signal.toMap());
    return signal;
  }

  List<SpeechSignal> getAllSignals() {
    final signals = _box.values
        .map((value) => SpeechSignal.fromMap(value))
        .toList();
    signals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return signals;
  }

  List<SpeechSignal> getByPatientId(String patientId) {
    return getAllSignals()
        .where((signal) => signal.patientId == patientId)
        .toList();
  }

  List<String> _tokenize(String transcript) {
    return transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  String _normalizeTranscript(String transcript) {
    return _tokenize(transcript).join(' ');
  }

  int _countMarkers(List<String> words, List<String> markers) {
    return words.where((word) => markers.contains(word)).length;
  }

  int _countRepetitions(List<String> words) {
    if (words.length < 2) return 0;
    var count = 0;
    for (var index = 1; index < words.length; index++) {
      if (words[index] == words[index - 1]) {
        count++;
      }
    }
    return count;
  }

  int _estimatePauses({
    required String transcript,
    required int durationSeconds,
    required int wordCount,
  }) {
    final punctuationPauses =
        RegExp(r'(\.\.\.|,|\.|\?)').allMatches(transcript).length;
    final longSpeechPause = durationSeconds > 0 && wordCount > 0
        ? ((durationSeconds - (wordCount ~/ 2)) ~/ 2).clamp(0, 4)
        : 0;
    return punctuationPauses + longSpeechPause;
  }

  String _buildSummary({
    required bool repeatedQuery,
    required int hesitancyCount,
    required int distressCount,
    required int repetitionCount,
    required int estimatedPauseCount,
    required SpeechSignalSource source,
  }) {
    final sourceLabel = source == SpeechSignalSource.companionVoice
        ? 'Companion voice input'
        : 'Voice diary';

    final notes = <String>[];
    if (repeatedQuery) notes.add('repeated question');
    if (hesitancyCount > 0) notes.add('hesitation markers');
    if (distressCount > 0) notes.add('distress words');
    if (repetitionCount > 0) notes.add('repeated words');
    if (estimatedPauseCount > 1) notes.add('long pauses');

    if (notes.isEmpty) {
      return '$sourceLabel sounded steady.';
    }
    return '$sourceLabel showed ${notes.join(', ')}.';
  }
}
