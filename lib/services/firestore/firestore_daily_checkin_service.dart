import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/my_day/daily_checkin_entry.dart';
import 'firestore_service.dart';
import 'package:intl/intl.dart';

class FirestoreDailyCheckinService extends FirestoreService {
  static const String collectionPath = 'daily_checkins';

  String _getDateId(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> syncDailyEntry(DailyCheckinEntry entry) async {
    final uid = userId;
    if (uid == null) return;

    final path = 'users/$uid/$collectionPath/${_getDateId(entry.date)}';
    
    // Add a lastUpdated timestamp for sync merging
    final data = entry.toMap();
    data['lastUpdated'] = FieldValue.serverTimestamp();
    
    await setData(
      path: path,
      data: data,
    );
  }

  Future<List<DailyCheckinEntry>> getAllDailyEntries() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$collectionPath').get();
    return snapshot.docs.map((doc) {
      return DailyCheckinEntry.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Future<DailyCheckinEntry?> getDailyEntry(DateTime date) async {
    final uid = userId;
    if (uid == null) return null;

    final path = 'users/$uid/$collectionPath/${_getDateId(date)}';
    return await getDocument(
      path: path,
      builder: (data, id) => DailyCheckinEntry.fromMap(data),
    );
  }
}
