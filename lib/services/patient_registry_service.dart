import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caregiver_report.dart';
import '../models/doctor_note.dart';
import '../models/patient_registry_record.dart';

class PatientRegistryService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _registry =>
      _firestore.collection('patient_registry');

  Future<void> createPatientRegistryRecord(PatientRegistryRecord record) async {
    await _registry.doc(record.patientId).set(record.toMap());
    await _firestore.collection('patient_access_codes').doc(record.accessCode).set({
      'patientId': record.patientId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('doctor_invites').doc(record.doctorInviteCode).set({
      'patientId': record.patientId,
      'createdAt': FieldValue.serverTimestamp(),
      'caregiverUid': record.caregiverUid,
    });
  }

  Future<PatientRegistryRecord?> getByPatientId(String patientId) async {
    final snapshot = await _registry.doc(patientId).get();
    if (!snapshot.exists) return null;
    return PatientRegistryRecord.fromMap(snapshot.data()!);
  }

  Future<PatientRegistryRecord?> getByAccessCode(String accessCode) async {
    final codeSnapshot = await _firestore
        .collection('patient_access_codes')
        .doc(accessCode)
        .get();
    if (!codeSnapshot.exists) {
      return null;
    }
    final patientId = codeSnapshot.data()?['patientId']?.toString();
    if (patientId == null || patientId.isEmpty) {
      return null;
    }
    return getByPatientId(patientId);
  }

  Future<PatientRegistryRecord?> getByDoctorInviteCode(String inviteCode) async {
    final inviteSnapshot = await _firestore
        .collection('doctor_invites')
        .doc(inviteCode)
        .get();
    if (!inviteSnapshot.exists) {
      return null;
    }
    final patientId = inviteSnapshot.data()?['patientId']?.toString();
    if (patientId == null || patientId.isEmpty) {
      return null;
    }
    return getByPatientId(patientId);
  }

  Future<void> assignDoctor({
    required String patientId,
    required String doctorUid,
  }) async {
    await _registry.doc(patientId).set({
      'doctorUids': FieldValue.arrayUnion([doctorUid]),
    }, SetOptions(merge: true));
  }

  Future<List<PatientRegistryRecord>> getForCaregiver(String caregiverUid) async {
    final snapshot = await _registry
        .where('caregiverUid', isEqualTo: caregiverUid)
        .get();
    return snapshot.docs
        .map((doc) => PatientRegistryRecord.fromMap(doc.data()))
        .toList();
  }

  Future<List<PatientRegistryRecord>> getForDoctor(String doctorUid) async {
    final snapshot = await _registry
        .where('doctorUids', arrayContains: doctorUid)
        .get();
    return snapshot.docs
        .map((doc) => PatientRegistryRecord.fromMap(doc.data()))
        .toList();
  }

  Future<List<PatientRegistryRecord>> getByPatientIds(
    List<String> patientIds,
  ) async {
    final uniqueIds = patientIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return const [];

    final records = <PatientRegistryRecord>[];
    for (final patientId in uniqueIds) {
      final record = await getByPatientId(patientId);
      if (record != null) {
        records.add(record);
      }
    }
    return records;
  }

  Future<void> syncSharedCaregiverReport(CaregiverReport report) async {
    await _registry
        .doc(report.patientId)
        .collection('caregiver_reports')
        .doc(report.id)
        .set(report.toJson());
  }

  Future<List<CaregiverReport>> getSharedCaregiverReports(String patientId) async {
    final snapshot = await _registry
        .doc(patientId)
        .collection('caregiver_reports')
        .get();
    final reports = snapshot.docs
        .map((doc) => CaregiverReport.fromJson(doc.data()))
        .toList();
    reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reports;
  }

  Future<void> saveDoctorNote(DoctorNote note) async {
    await _registry
        .doc(note.patientId)
        .collection('doctor_notes')
        .doc(note.id)
        .set(note.toMap());
  }

  Future<List<DoctorNote>> getDoctorNotes(String patientId) async {
    final snapshot = await _registry
        .doc(patientId)
        .collection('doctor_notes')
        .get();
    final notes = snapshot.docs
        .map((doc) => DoctorNote.fromMap(doc.data()))
        .toList();
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }
}
