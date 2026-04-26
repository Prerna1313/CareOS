class BackendSpeechAssessment {
  final String assessmentId;
  final DateTime analyzedAt;
  final String source;
  final String riskLevel;
  final int repeatedQueries;
  final int hesitations;
  final int distressMarkers;
  final int repetitions;
  final int estimatedPauses;
  final String summary;
  final List<String> evidenceNotes;

  const BackendSpeechAssessment({
    required this.assessmentId,
    required this.analyzedAt,
    required this.source,
    required this.riskLevel,
    required this.repeatedQueries,
    required this.hesitations,
    required this.distressMarkers,
    required this.repetitions,
    required this.estimatedPauses,
    required this.summary,
    required this.evidenceNotes,
  });

  factory BackendSpeechAssessment.fromMap(Map<String, dynamic> map) {
    return BackendSpeechAssessment(
      assessmentId: map['assessmentId'] as String? ?? '',
      analyzedAt: DateTime.tryParse(map['analyzedAt'] as String? ?? '') ??
          DateTime.now(),
      source: map['source'] as String? ?? 'unknown',
      riskLevel: map['riskLevel'] as String? ?? 'low',
      repeatedQueries: map['repeatedQueries'] as int? ?? 0,
      hesitations: map['hesitations'] as int? ?? 0,
      distressMarkers: map['distressMarkers'] as int? ?? 0,
      repetitions: map['repetitions'] as int? ?? 0,
      estimatedPauses: map['estimatedPauses'] as int? ?? 0,
      summary: map['summary'] as String? ?? '',
      evidenceNotes: List<String>.from(map['evidenceNotes'] ?? const []),
    );
  }
}

class BackendSpeechProcessingResult {
  final String requestId;
  final String patientId;
  final DateTime createdAt;
  final String source;
  final String gcsUri;
  final String status;
  final String transcript;
  final double confidenceAverage;
  final BackendSpeechAssessment assessment;

  const BackendSpeechProcessingResult({
    required this.requestId,
    required this.patientId,
    required this.createdAt,
    required this.source,
    required this.gcsUri,
    required this.status,
    required this.transcript,
    required this.confidenceAverage,
    required this.assessment,
  });

  factory BackendSpeechProcessingResult.fromMap(Map<String, dynamic> map) {
    final request = Map<String, dynamic>.from(map['request'] ?? const {});
    return BackendSpeechProcessingResult(
      requestId: request['requestId'] as String? ?? '',
      patientId: request['patientId'] as String? ?? '',
      createdAt: DateTime.tryParse(request['createdAt'] as String? ?? '') ??
          DateTime.now(),
      source: request['source'] as String? ?? 'unknown',
      gcsUri: request['gcsUri'] as String? ?? '',
      status: request['status'] as String? ?? 'unknown',
      transcript: map['transcript'] as String? ?? '',
      confidenceAverage: (map['confidenceAverage'] as num?)?.toDouble() ?? 0,
      assessment: BackendSpeechAssessment.fromMap(
        Map<String, dynamic>.from(map['assessment'] ?? const {}),
      ),
    );
  }
}

class BackendVideoMovementAnalysis {
  final String analysisId;
  final DateTime analyzedAt;
  final String movementRiskLevel;
  final int locationSwitches;
  final int shortIntervalSwitches;
  final int repeatedLoopCount;
  final int distinctVisitedLocations;
  final String summary;
  final List<String> evidenceNotes;

  const BackendVideoMovementAnalysis({
    required this.analysisId,
    required this.analyzedAt,
    required this.movementRiskLevel,
    required this.locationSwitches,
    required this.shortIntervalSwitches,
    required this.repeatedLoopCount,
    required this.distinctVisitedLocations,
    required this.summary,
    required this.evidenceNotes,
  });

  factory BackendVideoMovementAnalysis.fromMap(Map<String, dynamic> map) {
    return BackendVideoMovementAnalysis(
      analysisId: map['analysisId'] as String? ?? '',
      analyzedAt: DateTime.tryParse(map['analyzedAt'] as String? ?? '') ??
          DateTime.now(),
      movementRiskLevel: map['movementRiskLevel'] as String? ?? 'low',
      locationSwitches: map['locationSwitches'] as int? ?? 0,
      shortIntervalSwitches: map['shortIntervalSwitches'] as int? ?? 0,
      repeatedLoopCount: map['repeatedLoopCount'] as int? ?? 0,
      distinctVisitedLocations: map['distinctVisitedLocations'] as int? ?? 0,
      summary: map['summary'] as String? ?? '',
      evidenceNotes: List<String>.from(map['evidenceNotes'] ?? const []),
    );
  }
}

class BackendVideoFallAnalysis {
  final String analysisId;
  final String clipId;
  final DateTime analyzedAt;
  final String riskLevel;
  final double confidence;
  final String modelSource;
  final String summary;
  final List<String> evidenceNotes;

  const BackendVideoFallAnalysis({
    required this.analysisId,
    required this.clipId,
    required this.analyzedAt,
    required this.riskLevel,
    required this.confidence,
    required this.modelSource,
    required this.summary,
    required this.evidenceNotes,
  });

  factory BackendVideoFallAnalysis.fromMap(Map<String, dynamic> map) {
    return BackendVideoFallAnalysis(
      analysisId: map['analysisId'] as String? ?? '',
      clipId: map['clipId'] as String? ?? '',
      analyzedAt: DateTime.tryParse(map['analyzedAt'] as String? ?? '') ??
          DateTime.now(),
      riskLevel: map['riskLevel'] as String? ?? 'low',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      modelSource: map['modelSource'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      evidenceNotes: List<String>.from(map['evidenceNotes'] ?? const []),
    );
  }
}

class BackendVideoProcessingResult {
  final String clipId;
  final String patientId;
  final String sourceEventId;
  final String triggerReason;
  final DateTime createdAt;
  final String gcsUri;
  final String status;
  final BackendVideoMovementAnalysis movementAnalysis;
  final BackendVideoFallAnalysis fallAnalysis;
  final List<String> labels;

  const BackendVideoProcessingResult({
    required this.clipId,
    required this.patientId,
    required this.sourceEventId,
    required this.triggerReason,
    required this.createdAt,
    required this.gcsUri,
    required this.status,
    required this.movementAnalysis,
    required this.fallAnalysis,
    required this.labels,
  });

  factory BackendVideoProcessingResult.fromMap(Map<String, dynamic> map) {
    final request = Map<String, dynamic>.from(map['request'] ?? const {});
    return BackendVideoProcessingResult(
      clipId: request['clipId'] as String? ?? '',
      patientId: request['patientId'] as String? ?? '',
      sourceEventId: request['sourceEventId'] as String? ?? '',
      triggerReason: request['triggerReason'] as String? ?? '',
      createdAt: DateTime.tryParse(request['createdAt'] as String? ?? '') ??
          DateTime.now(),
      gcsUri: request['gcsUri'] as String? ?? '',
      status: request['status'] as String? ?? 'unknown',
      movementAnalysis: BackendVideoMovementAnalysis.fromMap(
        Map<String, dynamic>.from(map['movementAnalysis'] ?? const {}),
      ),
      fallAnalysis: BackendVideoFallAnalysis.fromMap(
        Map<String, dynamic>.from(map['fallAnalysis'] ?? const {}),
      ),
      labels: List<String>.from(map['labels'] ?? const []),
    );
  }
}
