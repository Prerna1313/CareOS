import '../confusion_state.dart';
import '../reminder.dart';

class PatientStateSnapshot {
  final String patientId;
  final DateTime timestamp;
  final ConfusionLevel confusionLevel;
  final ReminderType? activeReminder;
  final String currentActivity;
  final DateTime? lastInteractionAt;
  final String lastKnownContextSummary;

  const PatientStateSnapshot({
    required this.patientId,
    required this.timestamp,
    required this.confusionLevel,
    required this.activeReminder,
    required this.currentActivity,
    required this.lastInteractionAt,
    required this.lastKnownContextSummary,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'timestamp': timestamp.toIso8601String(),
      'confusionLevel': confusionLevel.name,
      'activeReminder': activeReminder?.name,
      'currentActivity': currentActivity,
      'lastInteractionAt': lastInteractionAt?.toIso8601String(),
      'lastKnownContextSummary': lastKnownContextSummary,
    };
  }

  factory PatientStateSnapshot.fromMap(Map<String, dynamic> map) {
    return PatientStateSnapshot(
      patientId: map['patientId'] as String? ?? '',
      timestamp: DateTime.parse(map['timestamp'] as String),
      confusionLevel: ConfusionLevel.values.firstWhere(
        (value) => value.name == map['confusionLevel'],
        orElse: () => ConfusionLevel.normal,
      ),
      activeReminder: map['activeReminder'] == null
          ? null
          : ReminderType.values.firstWhere(
              (value) => value.name == map['activeReminder'],
              orElse: () => ReminderType.task,
            ),
      currentActivity: map['currentActivity'] as String? ?? '',
      lastInteractionAt: map['lastInteractionAt'] == null
          ? null
          : DateTime.parse(map['lastInteractionAt'] as String),
      lastKnownContextSummary: map['lastKnownContextSummary'] as String? ?? '',
    );
  }
}

class PatientCareEvent {
  final String eventId;
  final String patientId;
  final String type;
  final DateTime timestamp;
  final String severity;
  final String summary;
  final String source;
  final List<String> evidenceRefs;

  const PatientCareEvent({
    required this.eventId,
    required this.patientId,
    required this.type,
    required this.timestamp,
    required this.severity,
    required this.summary,
    required this.source,
    required this.evidenceRefs,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'patientId': patientId,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity,
      'summary': summary,
      'source': source,
      'evidenceRefs': evidenceRefs,
    };
  }

  factory PatientCareEvent.fromMap(Map<String, dynamic> map) {
    return PatientCareEvent(
      eventId: map['eventId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      type: map['type'] as String? ?? 'event',
      timestamp: DateTime.parse(map['timestamp'] as String),
      severity: map['severity'] as String? ?? 'info',
      summary: map['summary'] as String? ?? '',
      source: map['source'] as String? ?? 'local',
      evidenceRefs: List<String>.from(map['evidenceRefs'] ?? const []),
    );
  }
}

class PatientMemoryRecord {
  final String memoryId;
  final String patientId;
  final String memoryType;
  final String title;
  final String summary;
  final List<String> peopleTags;
  final List<String> placeTags;
  final List<String> mediaRefs;
  final DateTime createdAt;

  const PatientMemoryRecord({
    required this.memoryId,
    required this.patientId,
    required this.memoryType,
    required this.title,
    required this.summary,
    required this.peopleTags,
    required this.placeTags,
    required this.mediaRefs,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'memoryId': memoryId,
      'patientId': patientId,
      'memoryType': memoryType,
      'title': title,
      'summary': summary,
      'peopleTags': peopleTags,
      'placeTags': placeTags,
      'mediaRefs': mediaRefs,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PatientMemoryRecord.fromMap(Map<String, dynamic> map) {
    return PatientMemoryRecord(
      memoryId: map['memoryId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      memoryType: map['memoryType'] as String? ?? 'event',
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      peopleTags: List<String>.from(map['peopleTags'] ?? const []),
      placeTags: List<String>.from(map['placeTags'] ?? const []),
      mediaRefs: List<String>.from(map['mediaRefs'] ?? const []),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class PatientInterventionRecord {
  final String interventionId;
  final String patientId;
  final String triggerType;
  final String interventionType;
  final DateTime deliveredAt;
  final String outcome;
  final String notes;

  const PatientInterventionRecord({
    required this.interventionId,
    required this.patientId,
    required this.triggerType,
    required this.interventionType,
    required this.deliveredAt,
    required this.outcome,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'interventionId': interventionId,
      'patientId': patientId,
      'triggerType': triggerType,
      'interventionType': interventionType,
      'deliveredAt': deliveredAt.toIso8601String(),
      'outcome': outcome,
      'notes': notes,
    };
  }

  factory PatientInterventionRecord.fromMap(Map<String, dynamic> map) {
    return PatientInterventionRecord(
      interventionId: map['interventionId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      triggerType: map['triggerType'] as String? ?? '',
      interventionType: map['interventionType'] as String? ?? '',
      deliveredAt: DateTime.parse(map['deliveredAt'] as String),
      outcome: map['outcome'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }
}

class PatientDailySummaryRecord {
  final String patientId;
  final DateTime date;
  final String diaryStatus;
  final String moodSummary;
  final String engagementSummary;
  final String aiSummaryText;

  const PatientDailySummaryRecord({
    required this.patientId,
    required this.date,
    required this.diaryStatus,
    required this.moodSummary,
    required this.engagementSummary,
    required this.aiSummaryText,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'date': date.toIso8601String(),
      'diaryStatus': diaryStatus,
      'moodSummary': moodSummary,
      'engagementSummary': engagementSummary,
      'aiSummaryText': aiSummaryText,
    };
  }

  factory PatientDailySummaryRecord.fromMap(Map<String, dynamic> map) {
    return PatientDailySummaryRecord(
      patientId: map['patientId'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      diaryStatus: map['diaryStatus'] as String? ?? 'draft',
      moodSummary: map['moodSummary'] as String? ?? 'Neutral',
      engagementSummary: map['engagementSummary'] as String? ?? '',
      aiSummaryText: map['aiSummaryText'] as String? ?? '',
    );
  }
}

class PatientTimelineRecord {
  final String id;
  final String patientId;
  final String category;
  final String title;
  final String summary;
  final String severity;
  final DateTime timestamp;
  final String source;
  final List<String> evidenceRefs;

  const PatientTimelineRecord({
    required this.id,
    required this.patientId,
    required this.category,
    required this.title,
    required this.summary,
    required this.severity,
    required this.timestamp,
    required this.source,
    required this.evidenceRefs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'category': category,
      'title': title,
      'summary': summary,
      'severity': severity,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'evidenceRefs': evidenceRefs,
    };
  }
}

class PatientIntegrationBundle {
  final DateTime generatedAt;
  final PatientStateSnapshot stateSnapshot;
  final List<PatientCareEvent> careEvents;
  final List<PatientMemoryRecord> memoryRecords;
  final List<PatientInterventionRecord> interventionRecords;
  final List<PatientDailySummaryRecord> dailySummaries;

  const PatientIntegrationBundle({
    required this.generatedAt,
    required this.stateSnapshot,
    required this.careEvents,
    required this.memoryRecords,
    required this.interventionRecords,
    required this.dailySummaries,
  });

  Map<String, dynamic> toMap() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'stateSnapshot': stateSnapshot.toMap(),
      'careEvents': careEvents.map((event) => event.toMap()).toList(),
      'memoryRecords': memoryRecords.map((record) => record.toMap()).toList(),
      'interventionRecords': interventionRecords
          .map((record) => record.toMap())
          .toList(),
      'dailySummaries': dailySummaries.map((record) => record.toMap()).toList(),
    };
  }
}
