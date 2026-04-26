enum SpeechSignalSource {
  companionVoice,
  voiceDiary,
}

class SpeechSignal {
  final String id;
  final String patientId;
  final DateTime timestamp;
  final SpeechSignalSource source;
  final String transcript;
  final int durationSeconds;
  final int estimatedPauseCount;
  final int repetitionCount;
  final int hesitancyCount;
  final int distressMarkerCount;
  final bool repeatedQuery;
  final String summary;

  const SpeechSignal({
    required this.id,
    required this.patientId,
    required this.timestamp,
    required this.source,
    required this.transcript,
    required this.durationSeconds,
    required this.estimatedPauseCount,
    required this.repetitionCount,
    required this.hesitancyCount,
    required this.distressMarkerCount,
    required this.repeatedQuery,
    required this.summary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'timestamp': timestamp.toIso8601String(),
      'source': source.name,
      'transcript': transcript,
      'durationSeconds': durationSeconds,
      'estimatedPauseCount': estimatedPauseCount,
      'repetitionCount': repetitionCount,
      'hesitancyCount': hesitancyCount,
      'distressMarkerCount': distressMarkerCount,
      'repeatedQuery': repeatedQuery,
      'summary': summary,
    };
  }

  factory SpeechSignal.fromMap(Map<dynamic, dynamic> map) {
    return SpeechSignal(
      id: map['id']?.toString() ?? '',
      patientId: map['patientId']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      source: SpeechSignalSource.values.firstWhere(
        (value) => value.name == map['source'],
        orElse: () => SpeechSignalSource.companionVoice,
      ),
      transcript: map['transcript']?.toString() ?? '',
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      estimatedPauseCount: map['estimatedPauseCount'] as int? ?? 0,
      repetitionCount: map['repetitionCount'] as int? ?? 0,
      hesitancyCount: map['hesitancyCount'] as int? ?? 0,
      distressMarkerCount: map['distressMarkerCount'] as int? ?? 0,
      repeatedQuery: map['repeatedQuery'] as bool? ?? false,
      summary: map['summary']?.toString() ?? '',
    );
  }
}
