import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../models/alert.dart';
import '../models/caregiver_report.dart';
import '../models/medication_reminder.dart';
import '../models/memory_cue.dart';
import '../models/daily_summary.dart';
import '../models/safe_zone.dart';

class MockDataProvider {
  static const _uuid = Uuid();

  static Patient getMockPatient({
    String patientId = 'pat_123',
    String patientName = 'Eleanor Smith',
    int patientAge = 78,
    String condition = 'Alzheimer\'s Stage 2',
    String location = 'Living Room',
  }) {
    return Patient(
      id: patientId,
      name: patientName,
      age: patientAge,
      condition: condition,
      currentStatus: 'active',
      lastActiveAt: DateTime.now().subtract(const Duration(minutes: 5)),
      currentLocationSummary: location,
      latestConfusionScore: 35.0,
      hasEmergency: false,
    );
  }

  static DailySummary getMockDailySummary({
    String patientId = 'pat_123',
    String patientName = 'Eleanor Smith',
  }) {
    return DailySummary(
      patientId: patientId,
      date: DateTime.now(),
      confusionFrequency: 0.2,
      alertCount: 2,
      medicineAdherence: 0.85,
      memoryCueEngagement: 4,
      moodSummary: '$patientName was calm and cooperative this morning.',
      routineAdherence: 0.90,
      activityLevel: 'Normal',
      stepsToday: 2100,
    );
  }

  static List<Alert> getMockAlerts({
    String patientId = 'pat_123',
    String patientName = 'the patient',
  }) {
    return [
      Alert(
        id: _uuid.v4(),
        patientId: patientId,
        type: AlertType.confusion,
        severity: AlertSeverity.high,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        title: 'High Confusion Detected',
        message: '$patientName is repeating the same question multiple times.',
        explanation:
            'Voice analysis detected repeated phrases "Where is my bag?" 4 times in 5 minutes.',
        recommendedAction: 'Trigger orientation support or voice note.',
        status: AlertStatus.active,
      ),
      Alert(
        id: _uuid.v4(),
        patientId: patientId,
        type: AlertType.missedReminder,
        severity: AlertSeverity.medium,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        title: 'Missed Medication',
        message: 'Did not respond to Afternoon Donepezil reminder.',
        status: AlertStatus.active,
      ),
    ];
  }

  static List<MemoryCue> getMockMemoryCues({
    String patientId = 'pat_123',
  }) {
    return [
      MemoryCue(
        id: _uuid.v4(),
        patientId: patientId,
        type: MemoryCueType.family,
        title: 'Daughter Sarah',
        caption: 'Sarah visited yesterday. She loves you very much.',
        priority: MemoryCuePriority.high,
      ),
      MemoryCue(
        id: _uuid.v4(),
        patientId: patientId,
        type: MemoryCueType.place,
        title: 'Living Room',
        caption: 'You are at home in the living room.',
      ),
    ];
  }

  static List<MedicationReminder> getMockReminders({
    String patientId = 'pat_123',
  }) {
    return [
      MedicationReminder(
        id: _uuid.v4(),
        patientId: patientId,
        title: 'Morning Donepezil',
        type: ReminderType.medicine,
        time: '08:00',
        repeatPattern: 'daily',
        instructions: 'Take with breakfast and a glass of water.',
        responseStatus: ReminderResponseStatus.taken,
      ),
      MedicationReminder(
        id: _uuid.v4(),
        patientId: patientId,
        title: 'Hydration Check',
        type: ReminderType.water,
        time: '14:00',
        repeatPattern: 'daily',
        instructions: 'Offer water or tea.',
      ),
    ];
  }

  static List<CaregiverReport> getMockCaregiverReports({
    String patientId = 'pat_123',
    String caregiverId = 'cg_demo',
    String patientName = 'the patient',
  }) {
    return [
      CaregiverReport(
        id: _uuid.v4(),
        patientId: patientId,
        caregiverId: caregiverId,
        category: ReportCategory.behavior,
        note:
            '$patientName was more engaged after lunch and responded well to family-photo cues.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      CaregiverReport(
        id: _uuid.v4(),
        patientId: patientId,
        caregiverId: caregiverId,
        category: ReportCategory.confusion,
        note:
            '$patientName repeated a location question twice before evening medication.',
        timestamp: DateTime.now().subtract(const Duration(hours: 7)),
      ),
    ];
  }

  static List<SafeZone> getMockSafeZones({
    String patientId = 'pat_123',
    String homeName = 'Home',
  }) {
    return [
      SafeZone(
        id: 'sz_home_$patientId',
        patientId: patientId,
        name: homeName,
        type: SafeZoneType.home,
        latitude: 40.7128,
        longitude: -74.0060,
        radiusMeters: 100,
      ),
    ];
  }
}
