import '../models/patient/advanced_speech_contracts.dart';
import 'backend_speech_result_service.dart';
import 'patient_records_service.dart';
import 'speech_signal_service.dart';

class AdvancedSpeechContractService {
  final SpeechSignalService _speechSignalService;
  final PatientRecordsService _patientRecordsService;
  final BackendSpeechResultService _backendSpeechResultService;

  AdvancedSpeechContractService(
    this._speechSignalService,
    this._patientRecordsService,
    this._backendSpeechResultService,
  );

  AdvancedSpeechBundle buildBundle(String patientId) {
    final backendResults = _backendSpeechResultService.getByPatientId(patientId);
    final signals = _speechSignalService.getByPatientId(patientId);
    final requests = backendResults
        .map(
          (result) => SpeechProcessingRequest(
            requestId: result.requestId,
            patientId: result.patientId,
            createdAt: result.createdAt,
            source: result.source,
            transcript: result.transcript,
            status: SpeechProcessingStatus.completed,
          ),
        )
        .toList();

    if (requests.isEmpty) {
      requests.addAll(signals
        .take(8)
        .map(
          (signal) => SpeechProcessingRequest(
            requestId: 'speech_${signal.id}',
            patientId: patientId,
            createdAt: signal.timestamp,
            source: signal.source.name,
            transcript: signal.transcript,
            status: SpeechProcessingStatus.completed,
          ),
        )
        .toList());
    }

    final assessment = backendResults.isNotEmpty
        ? SpeechAssessmentRecord(
            assessmentId: backendResults.first.assessment.assessmentId,
            patientId: patientId,
            analyzedAt: backendResults.first.assessment.analyzedAt,
            riskLevel: backendResults.first.assessment.riskLevel,
            repeatedQueries: backendResults.first.assessment.repeatedQueries,
            hesitations: backendResults.first.assessment.hesitations,
            distressMarkers: backendResults.first.assessment.distressMarkers,
            repetitions: backendResults.first.assessment.repetitions,
            estimatedPauses: backendResults.first.assessment.estimatedPauses,
            summary: backendResults.first.assessment.summary,
            evidenceNotes: backendResults.first.assessment.evidenceNotes,
          )
        : () {
            final digest = _patientRecordsService.buildSpeechDigest(patientId);
            return SpeechAssessmentRecord(
              assessmentId: 'assessment_${DateTime.now().millisecondsSinceEpoch}',
              patientId: patientId,
              analyzedAt: DateTime.now(),
              riskLevel: digest['riskLevel'] as String? ?? 'low',
              repeatedQueries: digest['repeatedQueries'] as int? ?? 0,
              hesitations: digest['hesitations'] as int? ?? 0,
              distressMarkers: digest['distressMarkers'] as int? ?? 0,
              repetitions: digest['repetitions'] as int? ?? 0,
              estimatedPauses: digest['estimatedPauses'] as int? ?? 0,
              summary:
                  digest['headline'] as String? ?? 'Recent speech looks steady.',
              evidenceNotes: List<String>.from(digest['patterns'] ?? const []),
            );
          }();

    return AdvancedSpeechBundle(
      generatedAt: DateTime.now(),
      requests: requests,
      assessment: assessment,
    );
  }
}
