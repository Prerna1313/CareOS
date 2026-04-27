import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/confusion_detection_result.dart';
import '../../models/confusion_event.dart';
import '../../models/reminder_log.dart';
import 'firestore_service.dart';

class FirestoreEventService extends FirestoreService {
  static const String confusionCollection = 'confusion_events';
  static const String confusionAssessmentCollection = 'confusion_assessments';
  static const String reminderLogCollection = 'reminder_logs';

  Future<void> syncConfusionEvent(ConfusionEvent event) async {
    final uid = userId;
    if (uid == null) return;

    final path = 'users/$uid/$confusionCollection/${event.id}';
    
    final data = event.toMap();
    data['lastUpdated'] = FieldValue.serverTimestamp();
    
    await setData(
      path: path,
      data: data,
    );
  }

  Future<void> syncReminderLog(ReminderLog log) async {
    final uid = userId;
    if (uid == null) return;

    final path = 'users/$uid/$reminderLogCollection/${log.id}';
    
    final data = log.toMap();
    data['lastUpdated'] = FieldValue.serverTimestamp();
    
    await setData(
      path: path,
      data: data,
    );
  }

  Future<void> syncConfusionAssessment(ConfusionDetectionResult result) async {
    final uid = userId;
    if (uid == null) return;

    final docId =
        '${result.patientId}_${result.timestamp.toIso8601String()}'.replaceAll(':', '_');
    final path = 'users/$uid/$confusionAssessmentCollection/$docId';

    final data = result.toJson();
    data['lastUpdated'] = FieldValue.serverTimestamp();

    await setData(
      path: path,
      data: data,
    );
  }

  Future<List<ConfusionEvent>> getAllConfusionEvents() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$confusionCollection').get();
    return snapshot.docs.map((doc) {
      return ConfusionEvent.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Future<List<ReminderLog>> getAllReminderLogs() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$reminderLogCollection').get();
    return snapshot.docs.map((doc) {
      return ReminderLog.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Future<List<ConfusionDetectionResult>> getAllConfusionAssessments() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection(
      'users/$uid/$confusionAssessmentCollection',
    ).get();
    return snapshot.docs.map((doc) {
      return ConfusionDetectionResult.fromJson(
        doc.data() as Map<String, dynamic>,
      );
    }).toList();
  }
}
