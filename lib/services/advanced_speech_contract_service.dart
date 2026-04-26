import '../models/patient/advanced_speech_contracts.dart';
import 'patient_records_service.dart';
import 'speech_signal_service.dart';

class AdvancedSpeechContractService {
  final SpeechSignalService _speechSignalService;
  final PatientRecordsService _patientRecordsService;

  AdvancedSpeechContractService(
    this._speechSignalService,
    this._patientRecordsService,
  );

  AdvancedSpeechBundle buildBundle(String patientId) {
    final signals = _speechSignalService.getByPatientId(patientId);
    final requests = signals
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
        .toList();

    final digest = _patientRecordsService.buildSpeechDigest(patientId);
    final assessment = SpeechAssessmentRecord(
      assessmentId: 'assessment_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      analyzedAt: DateTime.now(),
      riskLevel: digest['riskLevel'] as String? ?? 'low',
      repeatedQueries: digest['repeatedQueries'] as int? ?? 0,
      hesitations: digest['hesitations'] as int? ?? 0,
      distressMarkers: digest['distressMarkers'] as int? ?? 0,
      repetitions: digest['repetitions'] as int? ?? 0,
      estimatedPauses: digest['estimatedPauses'] as int? ?? 0,
      summary: digest['headline'] as String? ?? 'Recent speech looks steady.',
      evidenceNotes: List<String>.from(digest['patterns'] ?? const []),
    );

    return AdvancedSpeechBundle(
      generatedAt: DateTime.now(),
      requests: requests,
      assessment: assessment,
    );
  }
}
