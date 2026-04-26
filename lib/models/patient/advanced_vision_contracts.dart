enum BackendProcessingStatus {
  pendingUpload,
  queuedForVideoIntelligence,
  videoIntelligenceProcessing,
  vertexFallModelProcessing,
  completed,
  failed,
}

enum AdvancedVisionIncidentType {
  possibleFall,
  riskyScene,
  wanderingPattern,
  repeatedLocationLoop,
  personPresence,
}

class VideoObservationClipRequest {
  final String clipId;
  final String patientId;
  final String sourceEventId;
  final DateTime createdAt;
  final String localMediaPath;
  final String triggerReason;
  final BackendProcessingStatus processingStatus;
  final Map<String, dynamic> metadata;

  const VideoObservationClipRequest({
    required this.clipId,
    required this.patientId,
    required this.sourceEventId,
    required this.createdAt,
    required this.localMediaPath,
    required this.triggerReason,
    required this.processingStatus,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'clipId': clipId,
      'patientId': patientId,
      'sourceEventId': sourceEventId,
      'createdAt': createdAt.toIso8601String(),
      'localMediaPath': localMediaPath,
      'triggerReason': triggerReason,
      'processingStatus': processingStatus.name,
      'metadata': metadata,
    };
  }

  factory VideoObservationClipRequest.fromMap(Map<String, dynamic> map) {
    return VideoObservationClipRequest(
      clipId: map['clipId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      sourceEventId: map['sourceEventId'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      localMediaPath: map['localMediaPath'] as String? ?? '',
      triggerReason: map['triggerReason'] as String? ?? '',
      processingStatus: BackendProcessingStatus.values.firstWhere(
        (value) => value.name == map['processingStatus'],
        orElse: () => BackendProcessingStatus.pendingUpload,
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? const {}),
    );
  }
}

class FallAnalysisResult {
  final String analysisId;
  final String patientId;
  final String clipId;
  final DateTime analyzedAt;
  final String riskLevel;
  final double confidence;
  final String modelSource;
  final String summary;
  final List<String> evidenceNotes;
  final BackendProcessingStatus processingStatus;

  const FallAnalysisResult({
    required this.analysisId,
    required this.patientId,
    required this.clipId,
    required this.analyzedAt,
    required this.riskLevel,
    required this.confidence,
    required this.modelSource,
    required this.summary,
    required this.evidenceNotes,
    required this.processingStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'analysisId': analysisId,
      'patientId': patientId,
      'clipId': clipId,
      'analyzedAt': analyzedAt.toIso8601String(),
      'riskLevel': riskLevel,
      'confidence': confidence,
      'modelSource': modelSource,
      'summary': summary,
      'evidenceNotes': evidenceNotes,
      'processingStatus': processingStatus.name,
    };
  }

  factory FallAnalysisResult.fromMap(Map<String, dynamic> map) {
    return FallAnalysisResult(
      analysisId: map['analysisId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      clipId: map['clipId'] as String? ?? '',
      analyzedAt: DateTime.parse(map['analyzedAt'] as String),
      riskLevel: map['riskLevel'] as String? ?? 'low',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      modelSource: map['modelSource'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      evidenceNotes: List<String>.from(map['evidenceNotes'] ?? const []),
      processingStatus: BackendProcessingStatus.values.firstWhere(
        (value) => value.name == map['processingStatus'],
        orElse: () => BackendProcessingStatus.pendingUpload,
      ),
    );
  }
}

class MovementAnalysisResult {
  final String analysisId;
  final String patientId;
  final DateTime analyzedAt;
  final String movementRiskLevel;
  final int locationSwitches;
  final int shortIntervalSwitches;
  final int repeatedLoopCount;
  final int distinctVisitedLocations;
  final String summary;
  final List<String> evidenceNotes;
  final BackendProcessingStatus processingStatus;

  const MovementAnalysisResult({
    required this.analysisId,
    required this.patientId,
    required this.analyzedAt,
    required this.movementRiskLevel,
    required this.locationSwitches,
    required this.shortIntervalSwitches,
    required this.repeatedLoopCount,
    required this.distinctVisitedLocations,
    required this.summary,
    required this.evidenceNotes,
    required this.processingStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'analysisId': analysisId,
      'patientId': patientId,
      'analyzedAt': analyzedAt.toIso8601String(),
      'movementRiskLevel': movementRiskLevel,
      'locationSwitches': locationSwitches,
      'shortIntervalSwitches': shortIntervalSwitches,
      'repeatedLoopCount': repeatedLoopCount,
      'distinctVisitedLocations': distinctVisitedLocations,
      'summary': summary,
      'evidenceNotes': evidenceNotes,
      'processingStatus': processingStatus.name,
    };
  }

  factory MovementAnalysisResult.fromMap(Map<String, dynamic> map) {
    return MovementAnalysisResult(
      analysisId: map['analysisId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      analyzedAt: DateTime.parse(map['analyzedAt'] as String),
      movementRiskLevel: map['movementRiskLevel'] as String? ?? 'low',
      locationSwitches: map['locationSwitches'] as int? ?? 0,
      shortIntervalSwitches: map['shortIntervalSwitches'] as int? ?? 0,
      repeatedLoopCount: map['repeatedLoopCount'] as int? ?? 0,
      distinctVisitedLocations: map['distinctVisitedLocations'] as int? ?? 0,
      summary: map['summary'] as String? ?? '',
      evidenceNotes: List<String>.from(map['evidenceNotes'] ?? const []),
      processingStatus: BackendProcessingStatus.values.firstWhere(
        (value) => value.name == map['processingStatus'],
        orElse: () => BackendProcessingStatus.pendingUpload,
      ),
    );
  }
}

class AdvancedVisionIncidentRecord {
  final String incidentId;
  final String patientId;
  final AdvancedVisionIncidentType incidentType;
  final DateTime detectedAt;
  final String severity;
  final String summary;
  final List<String> evidenceRefs;
  final Map<String, dynamic> structuredSignals;

  const AdvancedVisionIncidentRecord({
    required this.incidentId,
    required this.patientId,
    required this.incidentType,
    required this.detectedAt,
    required this.severity,
    required this.summary,
    required this.evidenceRefs,
    required this.structuredSignals,
  });

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'patientId': patientId,
      'incidentType': incidentType.name,
      'detectedAt': detectedAt.toIso8601String(),
      'severity': severity,
      'summary': summary,
      'evidenceRefs': evidenceRefs,
      'structuredSignals': structuredSignals,
    };
  }
}

class AdvancedVisionBundle {
  final DateTime generatedAt;
  final List<VideoObservationClipRequest> clipRequests;
  final List<AdvancedVisionIncidentRecord> incidentRecords;
  final MovementAnalysisResult movementAnalysis;
  final FallAnalysisResult? latestFallAnalysis;

  const AdvancedVisionBundle({
    required this.generatedAt,
    required this.clipRequests,
    required this.incidentRecords,
    required this.movementAnalysis,
    required this.latestFallAnalysis,
  });

  Map<String, dynamic> toMap() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'clipRequests': clipRequests.map((item) => item.toMap()).toList(),
      'incidentRecords': incidentRecords.map((item) => item.toMap()).toList(),
      'movementAnalysis': movementAnalysis.toMap(),
      'latestFallAnalysis': latestFallAnalysis?.toMap(),
    };
  }
}
