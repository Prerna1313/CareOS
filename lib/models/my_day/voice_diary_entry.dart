class VoiceDiaryEntry {
  final String? filePath;
  final String? transcription;
  final int durationSeconds;
  final DateTime timestamp;
 
  VoiceDiaryEntry({
    this.filePath,
    this.transcription,
    required this.durationSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'transcription': transcription,
      'durationSeconds': durationSeconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory VoiceDiaryEntry.fromMap(Map<dynamic, dynamic> map) {
    return VoiceDiaryEntry(
      filePath: map['filePath'],
      transcription: map['transcription'],
      durationSeconds: map['durationSeconds'] ?? 0,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
