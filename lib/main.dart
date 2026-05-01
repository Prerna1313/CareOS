import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/reminder_service.dart';
import 'services/caregiver_reminder_service.dart';
import 'services/event_log_service.dart';
import 'services/confusion_detection_service.dart';
import 'services/confusion_ai_assessment_service.dart';
import 'services/confusion_event_service.dart';
import 'services/confusion_detection_result_service.dart';
import 'services/daily_checkin_service.dart';
import 'services/daily_report_service.dart';
import 'services/daily_summary_service.dart';
import 'services/memory_service.dart';
import 'services/memory_media_service.dart';
import 'services/firestore/firestore_daily_checkin_service.dart';
import 'services/firestore/firestore_memory_service.dart';
import 'services/firestore/firestore_event_service.dart';
import 'providers/reminder_provider.dart';
import 'providers/my_day_provider.dart';
import 'providers/memory_provider.dart';
import 'services/recognition_service.dart';
import 'services/recognition_response_service.dart';
import 'services/camera_service.dart';
import 'services/camera_event_service.dart';
import 'services/cloud_vision_service.dart';
import 'services/vision_service.dart';
import 'services/cloud_ai_service.dart';
import 'providers/recognition_provider.dart';
import 'providers/patient_session_provider.dart';
import 'services/patient_contract_mapper_service.dart';
import 'services/patient_intervention_service.dart';
import 'services/patient_records_service.dart';
import 'services/patient_session_service.dart';
import 'services/interaction_signal_service.dart';
import 'services/speech_signal_service.dart';
import 'services/advanced_vision_contract_service.dart';
import 'services/advanced_speech_contract_service.dart';
import 'services/backend_processing_service.dart';
import 'services/backend_speech_result_service.dart';
import 'services/backend_video_result_service.dart';
import 'services/wearable_location_source_service.dart';
import 'services/app_auth_service.dart';
import 'services/patient_registry_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final eventLogService = EventLogService();
  final confusionEventService = ConfusionEventService();
  final confusionDetectionResultService = ConfusionDetectionResultService();
  final caregiverReminderService = CaregiverReminderService();
  final dailyCheckinService = DailyCheckinService();
  final memoryService = MemoryService();
  final memoryMediaService = MemoryMediaService();
  final recognitionResponseService = RecognitionResponseService();
  final cameraEventService = CameraEventService();
  final cameraService = CameraService(cameraEventService);
  final patientSessionService = PatientSessionService();
  final patientInterventionService = PatientInterventionService();
  final interactionSignalService = InteractionSignalService();
  final speechSignalService = SpeechSignalService();
  final backendProcessingService = BackendProcessingService();
  final backendSpeechResultService = BackendSpeechResultService();
  final backendVideoResultService = BackendVideoResultService();
  final appAuthService = AppAuthService();
  final patientRegistryService = PatientRegistryService();

  // Late initialization for services that depend on Firebase/AI
  late RecognitionService recognitionService;
  late VisionService visionService;
  late DailySummaryService dailySummaryService;
  late CloudVisionService cloudVisionService;
  ConfusionAiAssessmentService? confusionAiAssessmentService;

  // Initialize local services and Firebase (wrapped to prevent blank screen)
  try {
    await eventLogService.init();
    await confusionEventService.init();
    await confusionDetectionResultService.init();
    await caregiverReminderService.init();
    await dailyCheckinService.init();
    await memoryService.init();
    await recognitionResponseService.init();
    await cameraEventService.init();
    await patientSessionService.init();
    await patientInterventionService.init();
    await interactionSignalService.init();
    await speechSignalService.init();
    await backendSpeechResultService.init();
    await backendVideoResultService.init();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final cloudAiService = CloudAIService();
    confusionAiAssessmentService = ConfusionAiAssessmentService();
    cloudVisionService = CloudVisionService();
    recognitionService = RecognitionService(
      recognitionResponseService,
      cloudAiService,
    );
    visionService = VisionService(cloudAiService, cloudVisionService);
    dailySummaryService = DailySummaryService(
      cloudAiService,
      backendProcessingService: backendProcessingService,
      backendSpeechResultService: backendSpeechResultService,
    );

    await recognitionService.init();
  } catch (e) {
    debugPrint('App initialization partially failed: $e');
    if (e.toString().contains('core/not-initialized')) {
      debugPrint(
        'Firebase is not initialized. Web users: Ensure flutterfire configure has been run.',
      );
    }
  }

  runApp(
    CareOSApp(
      eventLogService: eventLogService,
      confusionEventService: confusionEventService,
      confusionDetectionResultService: confusionDetectionResultService,
      dailyCheckinService: dailyCheckinService,
      memoryService: memoryService,
      memoryMediaService: memoryMediaService,
      firestoreDailyCheckinService: FirestoreDailyCheckinService(),
      firestoreMemoryService: FirestoreMemoryService(),
      firestoreEventService: FirestoreEventService(),
      recognitionService: recognitionService,
      recognitionResponseService: recognitionResponseService,
      cameraService: cameraService,
      cameraEventService: cameraEventService,
      visionService: visionService,
      dailySummaryService: dailySummaryService,
      patientSessionService: patientSessionService,
      patientInterventionService: patientInterventionService,
      interactionSignalService: interactionSignalService,
      speechSignalService: speechSignalService,
      backendProcessingService: backendProcessingService,
      backendSpeechResultService: backendSpeechResultService,
      backendVideoResultService: backendVideoResultService,
      appAuthService: appAuthService,
      patientRegistryService: patientRegistryService,
      confusionAiAssessmentService: confusionAiAssessmentService,
      caregiverReminderService: caregiverReminderService,
    ),
  );
}

/// CareOS — Cognitive Clarity & Emotional Peace
/// A digital sanctuary for Alzheimer's care management.
class CareOSApp extends StatelessWidget {
  final EventLogService eventLogService;
  final ConfusionEventService confusionEventService;
  final ConfusionDetectionResultService confusionDetectionResultService;
  final DailyCheckinService dailyCheckinService;
  final MemoryService memoryService;
  final MemoryMediaService memoryMediaService;
  final FirestoreDailyCheckinService firestoreDailyCheckinService;
  final FirestoreMemoryService firestoreMemoryService;
  final FirestoreEventService firestoreEventService;
  final RecognitionService recognitionService;
  final RecognitionResponseService recognitionResponseService;
  final CameraService cameraService;
  final CameraEventService cameraEventService;
  final VisionService visionService;
  final DailySummaryService dailySummaryService;
  final PatientSessionService patientSessionService;
  final PatientInterventionService patientInterventionService;
  final InteractionSignalService interactionSignalService;
  final SpeechSignalService speechSignalService;
  final BackendProcessingService backendProcessingService;
  final BackendSpeechResultService backendSpeechResultService;
  final BackendVideoResultService backendVideoResultService;
  final AppAuthService appAuthService;
  final PatientRegistryService patientRegistryService;
  final ConfusionAiAssessmentService? confusionAiAssessmentService;
  final CaregiverReminderService caregiverReminderService;

  const CareOSApp({
    super.key,
    required this.eventLogService,
    required this.confusionEventService,
    required this.confusionDetectionResultService,
    required this.dailyCheckinService,
    required this.memoryService,
    required this.memoryMediaService,
    required this.firestoreDailyCheckinService,
    required this.firestoreMemoryService,
    required this.firestoreEventService,
    required this.recognitionService,
    required this.recognitionResponseService,
    required this.cameraService,
    required this.cameraEventService,
    required this.visionService,
    required this.dailySummaryService,
    required this.patientSessionService,
    required this.patientInterventionService,
    required this.interactionSignalService,
    required this.speechSignalService,
    required this.backendProcessingService,
    required this.backendSpeechResultService,
    required this.backendVideoResultService,
    required this.appAuthService,
    required this.patientRegistryService,
    required this.confusionAiAssessmentService,
    required this.caregiverReminderService,
  });

  @override
  Widget build(BuildContext context) {
    final confusionDetectionService = ConfusionDetectionService();
    final patientContractMapperService = PatientContractMapperService();
    final patientRecordsService = PatientRecordsService(
      mapper: patientContractMapperService,
      eventLogService: eventLogService,
      confusionEventService: confusionEventService,
      confusionDetectionResultService: confusionDetectionResultService,
      cameraEventService: cameraEventService,
      memoryService: memoryService,
      dailyCheckinService: dailyCheckinService,
      interventionService: patientInterventionService,
      interactionSignalService: interactionSignalService,
      speechSignalService: speechSignalService,
      backendVideoResultService: backendVideoResultService,
      backendSpeechResultService: backendSpeechResultService,
    );
    final advancedVisionContractService = AdvancedVisionContractService(
      cameraEventService,
      patientRecordsService,
      backendVideoResultService,
    );
    final advancedSpeechContractService = AdvancedSpeechContractService(
      speechSignalService,
      patientRecordsService,
      backendSpeechResultService,
    );
    final wearableLocationSourceService = WearableLocationSourceService();

    return MultiProvider(
      providers: [
        Provider<PatientSessionService>.value(value: patientSessionService),
        Provider<PatientContractMapperService>.value(
          value: patientContractMapperService,
        ),
        Provider<PatientInterventionService>.value(
          value: patientInterventionService,
        ),
        Provider<InteractionSignalService>.value(value: interactionSignalService),
        Provider<SpeechSignalService>.value(value: speechSignalService),
        Provider<BackendProcessingService>.value(
          value: backendProcessingService,
        ),
        Provider<BackendSpeechResultService>.value(
          value: backendSpeechResultService,
        ),
        Provider<BackendVideoResultService>.value(
          value: backendVideoResultService,
        ),
        Provider<AppAuthService>.value(value: appAuthService),
        Provider<PatientRegistryService>.value(value: patientRegistryService),
        Provider<WearableLocationSourceService>.value(
          value: wearableLocationSourceService,
        ),
        Provider<PatientRecordsService>.value(value: patientRecordsService),
        Provider<AdvancedVisionContractService>.value(
          value: advancedVisionContractService,
        ),
        Provider<AdvancedSpeechContractService>.value(
          value: advancedSpeechContractService,
        ),
        Provider<EventLogService>.value(value: eventLogService),
        Provider<ConfusionDetectionService>.value(
          value: confusionDetectionService,
        ),
        Provider<ConfusionEventService>.value(value: confusionEventService),
        Provider<ConfusionDetectionResultService>.value(
          value: confusionDetectionResultService,
        ),
        Provider<ConfusionAiAssessmentService?>.value(
          value: confusionAiAssessmentService,
        ),
        Provider<DailyCheckinService>.value(value: dailyCheckinService),
        Provider<FirestoreDailyCheckinService>.value(
          value: firestoreDailyCheckinService,
        ),
        Provider<FirestoreMemoryService>.value(value: firestoreMemoryService),
        Provider<FirestoreEventService>.value(value: firestoreEventService),
        Provider<MemoryMediaService>.value(value: memoryMediaService),
        Provider<RecognitionResponseService>.value(
          value: recognitionResponseService,
        ),
        Provider<CameraService>.value(value: cameraService),
        Provider<CameraEventService>.value(value: cameraEventService),
        Provider<VisionService>.value(value: visionService),
        Provider<DailyReportService>(
          create: (_) => DailyReportService(memoryService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              PatientSessionProvider(patientSessionService)..loadSession(),
        ),
        ChangeNotifierProxyProvider<PatientSessionProvider, MemoryProvider>(
          create: (context) => MemoryProvider(
            memoryService,
            memoryMediaService,
            context.read<PatientSessionProvider>().patientId,
            recognitionService: recognitionService,
          ),
          update: (context, patientSession, previous) => MemoryProvider(
            memoryService,
            memoryMediaService,
            patientSession.patientId,
            recognitionService: recognitionService,
          ),
        ),
        ChangeNotifierProxyProvider<PatientSessionProvider, ReminderProvider>(
          create: (context) => ReminderProvider(
            SharedCaregiverReminderService(caregiverReminderService),
            eventLogService,
            confusionDetectionService,
            confusionEventService,
            context.read<PatientSessionProvider>().patientId,
            patientName:
                context.read<PatientSessionProvider>().profile?.displayName ??
                'Patient',
            confusionAiAssessmentService: confusionAiAssessmentService,
            confusionDetectionResultService: confusionDetectionResultService,
            firestoreEventService: firestoreEventService,
          ),
          update: (context, patientSession, previous) => ReminderProvider(
            SharedCaregiverReminderService(caregiverReminderService),
            eventLogService,
            confusionDetectionService,
            confusionEventService,
            patientSession.patientId,
            patientName: patientSession.profile?.displayName ?? 'Patient',
            confusionAiAssessmentService: confusionAiAssessmentService,
            confusionDetectionResultService: confusionDetectionResultService,
            firestoreEventService: firestoreEventService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MyDayProvider(
            dailyCheckinService,
            DailyReportService(memoryService),
            dailySummaryService,
            speechSignalService: speechSignalService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RecognitionProvider(recognitionService),
        ),
      ],
      child: MaterialApp(
        title: 'CareOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.landing,
        routes: AppRoutes.routes,
      ),
    );
  }
}
