import '../models/camera_event.dart';
import '../models/patient/advanced_vision_contracts.dart';
import 'camera_event_service.dart';
import 'patient_records_service.dart';

class AdvancedVisionContractService {
  final CameraEventService _cameraEventService;
  final PatientRecordsService _patientRecordsService;

  AdvancedVisionContractService(
    this._cameraEventService,
    this._patientRecordsService,
  );

  AdvancedVisionBundle buildBundle(String patientId) {
    final events = _cameraEventService.getAllEvents()
      ..sort(
        (a, b) => (b.analysisTimestamp ?? b.timestamp).compareTo(
          a.analysisTimestamp ?? a.timestamp,
        ),
      );
    final visualDigest = _patientRecordsService.buildVisualBehaviorDigest();
    final incidentRecords = _buildIncidentRecords(patientId, events, visualDigest);
    final clipRequests = _buildClipRequests(patientId, events, incidentRecords);
    final movementAnalysis = _buildMovementAnalysis(patientId, visualDigest);
    final latestFallAnalysis = _buildLatestFallAnalysis(
      patientId,
      clipRequests,
      visualDigest,
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
  ) {
    final requests = <VideoObservationClipRequest>[];
    for (final incident in incidents) {
      final matchingEvent = events.firstWhere(
        (event) => incident.evidenceRefs.contains(event.imagePath),
        orElse: () => events.first,
      );
      requests.add(
        VideoObservationClipRequest(
          clipId: 'clip_${incident.incidentId}',
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
  ) {
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
  ) {
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
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
