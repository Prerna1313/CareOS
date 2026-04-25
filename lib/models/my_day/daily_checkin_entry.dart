import 'question_response.dart';
import 'voice_diary_entry.dart';

class DailyCheckinEntry {
  final DateTime date;
  final List<QuestionResponse> answers;
  final int skippedCount;
  final int totalResponseTimeSeconds;
  final String mood; // derived
  final bool wentOut; // derived
  final bool socialInteraction; // derived
  final String summary;
  final String textField1; // Extra diary
  final String textField2; // Important note
  final VoiceDiaryEntry? voiceNote;

  DailyCheckinEntry({
    required this.date,
    required this.answers,
    this.skippedCount = 0,
    this.totalResponseTimeSeconds = 0,
    this.mood = 'Neutral',
    this.wentOut = false,
    this.socialInteraction = false,
    this.summary = '',
    this.textField1 = '',
    this.textField2 = '',
    this.voiceNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'answers': answers.map((a) => a.toMap()).toList(),
      'skippedCount': skippedCount,
      'totalResponseTimeSeconds': totalResponseTimeSeconds,
      'mood': mood,
      'wentOut': wentOut,
      'socialInteraction': socialInteraction,
      'summary': summary,
      'textField1': textField1,
      'textField2': textField2,
      'voiceNote': voiceNote?.toMap(),
    };
  }

  factory DailyCheckinEntry.fromMap(Map<dynamic, dynamic> map) {
    return DailyCheckinEntry(
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      answers: (map['answers'] as List? ?? [])
          .map((a) => QuestionResponse.fromMap(a))
          .toList(),
      skippedCount: map['skippedCount'] ?? 0,
      totalResponseTimeSeconds: map['totalResponseTimeSeconds'] ?? 0,
      mood: map['mood'] ?? 'Neutral',
      wentOut: map['wentOut'] ?? false,
      socialInteraction: map['socialInteraction'] ?? false,
      summary: map['summary'] ?? '',
      textField1: map['textField1'] ?? '',
      textField2: map['textField2'] ?? '',
      voiceNote: map['voiceNote'] != null 
          ? VoiceDiaryEntry.fromMap(map['voiceNote']) 
          : null,
    );
  }

  DailyCheckinEntry copyWith({
    DateTime? date,
    List<QuestionResponse>? answers,
    int? skippedCount,
    int? totalResponseTimeSeconds,
    String? mood,
    bool? wentOut,
    bool? socialInteraction,
    String? summary,
    String? textField1,
    String? textField2,
    VoiceDiaryEntry? voiceNote,
  }) {
    return DailyCheckinEntry(
      date: date ?? this.date,
      answers: answers ?? this.answers,
      skippedCount: skippedCount ?? this.skippedCount,
      totalResponseTimeSeconds: totalResponseTimeSeconds ?? this.totalResponseTimeSeconds,
      mood: mood ?? this.mood,
      wentOut: wentOut ?? this.wentOut,
      socialInteraction: socialInteraction ?? this.socialInteraction,
      summary: summary ?? this.summary,
      textField1: textField1 ?? this.textField1,
      textField2: textField2 ?? this.textField2,
      voiceNote: voiceNote ?? this.voiceNote,
    );
  }
}
