enum SpeechProcessingStatus {
  pendingUpload,
  queuedForSpeechToText,
  speechToTextProcessing,
  completed,
  failed,
}

class SpeechProcessingRequest {
  final String requestId;
  final String patientId;
  final DateTime createdAt;
  final String source;
  final String transcript;
  final SpeechProcessingStatus status;

  const SpeechProcessingRequest({
    required this.requestId,
    required this.patientId,
    required this.createdAt,
    required this.source,
    required this.transcript,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'patientId': patientId,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
      'transcript': transcript,
      'status': status.name,
    };
  }
}

class SpeechAssessmentRecord {
  final String assessmentId;
  final String patientId;
  final DateTime analyzedAt;
  final String riskLevel;
  final int repeatedQueries;
  final int hesitations;
  final int distressMarkers;
  final int repetitions;
  final int estimatedPauses;
  final String summary;
  final List<String> evidenceNotes;

  const SpeechAssessmentRecord({
    required this.assessmentId,
    required this.patientId,
    required this.analyzedAt,
    required this.riskLevel,
    required this.repeatedQueries,
    required this.hesitations,
    required this.distressMarkers,
    required this.repetitions,
    required this.estimatedPauses,
    required this.summary,
    required this.evidenceNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'assessmentId': assessmentId,
      'patientId': patientId,
      'analyzedAt': analyzedAt.toIso8601String(),
      'riskLevel': riskLevel,
      'repeatedQueries': repeatedQueries,
      'hesitations': hesitations,
      'distressMarkers': distressMarkers,
      'repetitions': repetitions,
      'estimatedPauses': estimatedPauses,
      'summary': summary,
      'evidenceNotes': evidenceNotes,
    };
  }
}

class AdvancedSpeechBundle {
  final DateTime generatedAt;
  final List<SpeechProcessingRequest> requests;
  final SpeechAssessmentRecord assessment;

  const AdvancedSpeechBundle({
    required this.generatedAt,
    required this.requests,
    required this.assessment,
  });

  Map<String, dynamic> toMap() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'requests': requests.map((item) => item.toMap()).toList(),
      'assessment': assessment.toMap(),
    };
  }
}
