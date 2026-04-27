import '../models/camera_event.dart';
import '../models/patient/advanced_vision_contracts.dart';
import '../models/patient/backend_processing_models.dart';
import 'backend_video_result_service.dart';
import 'camera_event_service.dart';
import 'patient_records_service.dart';

class AdvancedVisionContractService {
  final CameraEventService _cameraEventService;
  final PatientRecordsService _patientRecordsService;
  final BackendVideoResultService _backendVideoResultService;

  AdvancedVisionContractService(
    this._cameraEventService,
    this._patientRecordsService,
    this._backendVideoResultService,
  );

  AdvancedVisionBundle buildBundle(String patientId) {
    final events = _cameraEventService.getAllEvents()
      ..sort(
        (a, b) => (b.analysisTimestamp ?? b.timestamp).compareTo(
          a.analysisTimestamp ?? a.timestamp,
        ),
      );
    final visualDigest = _patientRecordsService.buildVisualBehaviorDigest();
    final backendResults = _backendVideoResultService.getByPatientId(patientId);
    final incidentRecords = _buildIncidentRecords(patientId, events, visualDigest);
    final clipRequests = _buildClipRequests(
      patientId,
      events,
      incidentRecords,
      backendResults,
    );
    final movementAnalysis = _buildMovementAnalysis(
      patientId,
      visualDigest,
      backendResults,
    );
    final latestFallAnalysis = _buildLatestFallAnalysis(
      patientId,
      clipRequests,
      visualDigest,
      backendResults,
    );

    return AdvancedVisionBundle(
      generatedAt: DateTime.now(),
      clipRequests: clipRequests,
      incidentRecords: incidentRecords,
      movementAnalysis: movementAnalysis,
      latestFallAnalysis: latestFallAnalysis,
    );
  }

  List<VideoObservationClipRequest> _buildClipRequests(
    String patientId,
    List<CameraEvent> events,
    List<AdvancedVisionIncidentRecord> incidents,
    List<BackendVideoProcessingResult> backendResults,
  ) {
    final requests = backendResults
        .map(
          (result) => VideoObservationClipRequest(
            clipId: result.clipId,
            patientId: result.patientId,
            sourceEventId: result.sourceEventId,
            createdAt: result.createdAt,
            localMediaPath: result.gcsUri.isNotEmpty ? result.gcsUri : 'uploaded_clip',
            triggerReason: result.triggerReason,
            processingStatus: _statusFromBackend(result.status),
            metadata: {
              'source': 'careos_backend',
              'labels': result.labels,
              'fallRisk': result.fallAnalysis.riskLevel,
              'movementRisk': result.movementAnalysis.movementRiskLevel,
            },
          ),
        )
        .toList();

    final existingClipIds = requests.map((item) => item.clipId).toSet();
    for (final incident in incidents) {
      final matchingEvent = events.firstWhere(
        (event) => incident.evidenceRefs.contains(event.imagePath),
        orElse: () => events.first,
      );
      final incidentClipId = 'clip_${incident.incidentId}';
      if (existingClipIds.contains(incidentClipId)) {
        continue;
      }
      requests.add(
        VideoObservationClipRequest(
          clipId: incidentClipId,
          patientId: patientId,
          sourceEventId: matchingEvent.id,
          createdAt: DateTime.now(),
          localMediaPath: matchingEvent.imagePath,
          triggerReason: incident.summary,
          processingStatus: BackendProcessingStatus.pendingUpload,
          metadata: {
            'source': 'patient_observe_pipeline',
            'incidentType': incident.incidentType.name,
            'locationHint': matchingEvent.locationHint,
            'detectedObjects': matchingEvent.detectedObjects,
          },
        ),
      );
    }
    return requests;
  }

  List<AdvancedVisionIncidentRecord> _buildIncidentRecords(
    String patientId,
    List<CameraEvent> events,
    Map<String, dynamic> visualDigest,
  ) {
    final incidentRecords = <AdvancedVisionIncidentRecord>[];
    final recentEvents = events.take(6).toList();

    for (final event in recentEvents) {
      final note = '${event.note} ${event.unusualObservation}'.toLowerCase();
      if (note.contains('fall') ||
          note.contains('collapse') ||
          note.contains('slumped')) {
        incidentRecords.add(
          AdvancedVisionIncidentRecord(
            incidentId: 'fall_${event.id}',
            patientId: patientId,
            incidentType: AdvancedVisionIncidentType.possibleFall,
            detectedAt: event.analysisTimestamp ?? event.timestamp,
            severity: event.concernLevel == 'high' ? 'high' : 'medium',
            summary: 'Possible fall-style visual pattern detected.',
            evidenceRefs: [event.imagePath],
            structuredSignals: {
              'locationHint': event.locationHint,
              'unusualObservation': event.unusualObservation,
              'detectedObjects': event.detectedObjects,
            },
          ),
        );
      } else if (event.concernLevel == 'high' ||
          note.contains('spill') ||
          note.contains('clutter') ||
          note.contains('blocked')) {
        incidentRecords.add(
          AdvancedVisionIncidentRecord(
            incidentId: 'risk_${event.id}',
            patientId: patientId,
            incidentType: AdvancedVisionIncidentType.riskyScene,
            detectedAt: event.analysisTimestamp ?? event.timestamp,
            severity: event.concernLevel == 'high' ? 'high' : 'medium',
            summary: 'Risky scene markers suggest a safety review may help.',
            evidenceRefs: [event.imagePath],
            structuredSignals: {
              'locationHint': event.locationHint,
              'unusualObservation': event.unusualObservation,
              'detectedObjects': event.detectedObjects,
            },
          ),
        );
      }
    }

    if (visualDigest['possibleWandering'] == true) {
      incidentRecords.add(
        AdvancedVisionIncidentRecord(
          incidentId: 'wandering_${DateTime.now().millisecondsSinceEpoch}',
          patientId: patientId,
          incidentType: AdvancedVisionIncidentType.wanderingPattern,
          detectedAt: DateTime.now(),
          severity: (visualDigest['riskLevel'] as String? ?? 'low') == 'high'
              ? 'high'
              : 'medium',
          summary: visualDigest['wanderingHeadline'] as String? ??
              'Recent observation patterns suggest wandering-style movement.',
          evidenceRefs: recentEvents.map((event) => event.imagePath).toList(),
          structuredSignals: {
            'locationSwitches': visualDigest['locationSwitches'] ?? 0,
            'shortIntervalSwitches':
                visualDigest['shortIntervalSwitches'] ?? 0,
            'repeatedLoopCount': visualDigest['repeatedLoopCount'] ?? 0,
            'distinctVisitedLocations':
                visualDigest['distinctVisitedLocations'] ?? 0,
          },
        ),
      );
    } else if ((visualDigest['repeatedLoopCount'] as int? ?? 0) > 0) {
      incidentRecords.add(
        AdvancedVisionIncidentRecord(
          incidentId: 'loop_${DateTime.now().millisecondsSinceEpoch}',
          patientId: patientId,
          incidentType: AdvancedVisionIncidentType.repeatedLocationLoop,
          detectedAt: DateTime.now(),
          severity: 'medium',
          summary: 'Recent observations suggest a repeated location loop.',
          evidenceRefs: recentEvents.map((event) => event.imagePath).toList(),
          structuredSignals: {
            'repeatedLoopCount': visualDigest['repeatedLoopCount'] ?? 0,
            'locationSwitches': visualDigest['locationSwitches'] ?? 0,
          },
        ),
      );
    }

    return incidentRecords;
  }

  MovementAnalysisResult _buildMovementAnalysis(
    String patientId,
    Map<String, dynamic> visualDigest,
    List<BackendVideoProcessingResult> backendResults,
  ) {
    final latestBackendResult = backendResults.isNotEmpty ? backendResults.first : null;
    if (latestBackendResult != null) {
      return MovementAnalysisResult(
        analysisId: latestBackendResult.movementAnalysis.analysisId,
        patientId: patientId,
        analyzedAt: latestBackendResult.movementAnalysis.analyzedAt,
        movementRiskLevel:
            latestBackendResult.movementAnalysis.movementRiskLevel,
        locationSwitches: latestBackendResult.movementAnalysis.locationSwitches,
        shortIntervalSwitches:
            latestBackendResult.movementAnalysis.shortIntervalSwitches,
        repeatedLoopCount:
            latestBackendResult.movementAnalysis.repeatedLoopCount,
        distinctVisitedLocations:
            latestBackendResult.movementAnalysis.distinctVisitedLocations,
        summary: latestBackendResult.movementAnalysis.summary,
        evidenceNotes: latestBackendResult.movementAnalysis.evidenceNotes,
        processingStatus: _statusFromBackend(latestBackendResult.status),
      );
    }

    return MovementAnalysisResult(
      analysisId: 'movement_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      analyzedAt: DateTime.now(),
      movementRiskLevel: visualDigest['riskLevel'] as String? ?? 'low',
      locationSwitches: visualDigest['locationSwitches'] as int? ?? 0,
      shortIntervalSwitches:
          visualDigest['shortIntervalSwitches'] as int? ?? 0,
      repeatedLoopCount: visualDigest['repeatedLoopCount'] as int? ?? 0,
      distinctVisitedLocations:
          visualDigest['distinctVisitedLocations'] as int? ?? 0,
      summary: visualDigest['wanderingHeadline'] as String? ??
          'Movement analysis is ready for backend review.',
      evidenceNotes: List<String>.from(visualDigest['patterns'] ?? const []),
      processingStatus: BackendProcessingStatus.pendingUpload,
    );
  }

  FallAnalysisResult? _buildLatestFallAnalysis(
    String patientId,
    List<VideoObservationClipRequest> clipRequests,
    Map<String, dynamic> visualDigest,
    List<BackendVideoProcessingResult> backendResults,
  ) {
    if (backendResults.isNotEmpty) {
      final latest = backendResults.first;
      return FallAnalysisResult(
        analysisId: latest.fallAnalysis.analysisId,
        patientId: patientId,
        clipId: latest.fallAnalysis.clipId,
        analyzedAt: latest.fallAnalysis.analyzedAt,
        riskLevel: latest.fallAnalysis.riskLevel,
        confidence: latest.fallAnalysis.confidence,
        modelSource: latest.fallAnalysis.modelSource,
        summary: latest.fallAnalysis.summary,
        evidenceNotes: latest.fallAnalysis.evidenceNotes,
        processingStatus: _statusFromBackend(latest.status),
      );
    }

    if ((visualDigest['possibleFallCount'] as int? ?? 0) <= 0) {
      return null;
    }

    final clipId = clipRequests
            .where(
              (request) =>
                  request.metadata['incidentType'] ==
                  AdvancedVisionIncidentType.possibleFall.name,
            )
            .map((request) => request.clipId)
            .firstOrNull ??
        'clip_pending';

    return FallAnalysisResult(
      analysisId: 'fall_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      clipId: clipId,
      analyzedAt: DateTime.now(),
      riskLevel: visualDigest['riskLevel'] as String? ?? 'medium',
      confidence: (visualDigest['possibleFallCount'] as int? ?? 0) > 1
          ? 0.82
          : 0.68,
      modelSource: 'future_video_intelligence_plus_vertex_fall_model',
      summary:
          'This is a backend-ready placeholder for stronger Google video/fall analysis.',
      evidenceNotes: [
        'Prepare to run Video Intelligence person detection.',
        'Prepare to run a custom Vertex AI fall model on the resulting clip.',
      ],
      processingStatus: BackendProcessingStatus.pendingUpload,
    );
  }

  BackendProcessingStatus _statusFromBackend(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return BackendProcessingStatus.completed;
      case 'failed':
        return BackendProcessingStatus.failed;
      case 'vertex_processing':
        return BackendProcessingStatus.vertexFallModelProcessing;
      case 'video_processing':
        return BackendProcessingStatus.videoIntelligenceProcessing;
      case 'queued':
        return BackendProcessingStatus.queuedForVideoIntelligence;
      default:
        return BackendProcessingStatus.pendingUpload;
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
