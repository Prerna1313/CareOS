import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/caregiver_report.dart';
import '../../models/care_team_member.dart';
import '../../models/memory_cue.dart';
import '../../models/patient_location_ping.dart';
import '../../models/safe_zone.dart';
import 'firestore_service.dart';

class FirestoreCaregiverService extends FirestoreService {
  static const String memoryCueCollection = 'caregiver_memory_cues';
  static const String safeZoneCollection = 'caregiver_safe_zones';
  static const String reportCollection = 'caregiver_reports';
  static const String careTeamCollection = 'care_team_members';
  static const String locationCollection = 'patient_location_pings';

  Future<void> syncMemoryCue(MemoryCue cue) async {
    final uid = userId;
    if (uid == null) return;

    await setData(
      path: 'users/$uid/$memoryCueCollection/${cue.id}',
      data: {
        ...cue.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteMemoryCue(String id) async {
    final uid = userId;
    if (uid == null) return;
    await deleteData(path: 'users/$uid/$memoryCueCollection/$id');
  }

  Future<List<MemoryCue>> getAllMemoryCues() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$memoryCueCollection').get();
    return snapshot.docs
        .map((doc) => MemoryCue.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> syncSafeZone(SafeZone zone) async {
    final uid = userId;
    if (uid == null) return;

    await setData(
      path: 'users/$uid/$safeZoneCollection/${zone.id}',
      data: {
        ...zone.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteSafeZone(String id) async {
    final uid = userId;
    if (uid == null) return;
    await deleteData(path: 'users/$uid/$safeZoneCollection/$id');
  }

  Future<List<SafeZone>> getAllSafeZones() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$safeZoneCollection').get();
    return snapshot.docs
        .map((doc) => SafeZone.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> syncCaregiverReport(CaregiverReport report) async {
    final uid = userId;
    if (uid == null) return;

    await setData(
      path: 'users/$uid/$reportCollection/${report.id}',
      data: {
        ...report.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteCaregiverReport(String id) async {
    final uid = userId;
    if (uid == null) return;
    await deleteData(path: 'users/$uid/$reportCollection/$id');
  }

  Future<List<CaregiverReport>> getAllCaregiverReports() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$reportCollection').get();
    return snapshot.docs
        .map(
          (doc) => CaregiverReport.fromJson(doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> syncCareTeamMember(CareTeamMember member) async {
    final uid = userId;
    if (uid == null) return;

    await setData(
      path: 'users/$uid/$careTeamCollection/${member.id}',
      data: {
        ...member.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteCareTeamMember(String id) async {
    final uid = userId;
    if (uid == null) return;
    await deleteData(path: 'users/$uid/$careTeamCollection/$id');
  }

  Future<List<CareTeamMember>> getAllCareTeamMembers() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$careTeamCollection').get();
    return snapshot.docs
        .map(
          (doc) => CareTeamMember.fromJson(doc.data() as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> syncPatientLocationPing(PatientLocationPing ping) async {
    final uid = userId;
    if (uid == null) return;

    await setData(
      path: 'users/$uid/$locationCollection/${ping.id}',
      data: {
        ...ping.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<List<PatientLocationPing>> getAllPatientLocationPings() async {
    final uid = userId;
    if (uid == null) return [];

    final snapshot = await getCollection('users/$uid/$locationCollection').get();
    return snapshot.docs
        .map(
          (doc) => PatientLocationPing.fromJson(
            doc.data() as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
