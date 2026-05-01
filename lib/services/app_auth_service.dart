import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_profile.dart';
import 'patient_registry_service.dart';

class AppAuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final PatientRegistryService _patientRegistryService = PatientRegistryService();

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  Future<AppUserProfile?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _loadProfile(user.uid);
  }

  Future<AppUserProfile> signInCaregiver({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final profile = await _loadProfile(credential.user!.uid);
    if (profile == null || profile.role != AppUserRole.caregiver) {
      throw FirebaseAuthException(
        code: 'wrong-role',
        message: 'This account is not registered as a caregiver.',
      );
    }
    return profile;
  }

  Future<AppUserProfile> registerCaregiver({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final profile = AppUserProfile(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      role: AppUserRole.caregiver,
      linkedPatientIds: const [],
      activePatientId: null,
      createdAt: DateTime.now(),
    );
    await _saveProfile(profile);
    return profile;
  }

  Future<AppUserProfile> signInDoctor({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final profile = await _loadProfile(credential.user!.uid);
    if (profile == null || profile.role != AppUserRole.doctor) {
      throw FirebaseAuthException(
        code: 'wrong-role',
        message: 'This account is not registered as a doctor.',
      );
    }
    return profile;
  }

  Future<AppUserProfile> registerDoctor({
    required String email,
    required String password,
    required String displayName,
    required String doctorInviteCode,
  }) async {
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
    final linkedRecord = await _patientRegistryService.getByDoctorInviteCode(
      doctorInviteCode,
    );
    if (linkedRecord == null) {
      throw FirebaseAuthException(
        code: 'invalid-invite',
        message: 'That doctor invite code is not valid.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final profile = AppUserProfile(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      role: AppUserRole.doctor,
      linkedPatientIds: [linkedRecord.patientId],
      activePatientId: linkedRecord.patientId,
      createdAt: DateTime.now(),
    );
    await _saveProfile(profile);
    await _patientRegistryService.assignDoctor(
      patientId: linkedRecord.patientId,
      doctorUid: credential.user!.uid,
    );
    return profile;
  }

  Future<void> updateLinkedPatients({
    required String uid,
    required List<String> linkedPatientIds,
    String? activePatientId,
  }) async {
    await _firestore.collection('app_users').doc(uid).set({
      'linkedPatientIds': linkedPatientIds,
      'activePatientId': activePatientId,
    }, SetOptions(merge: true));
  }

  Future<AppUserProfile?> _loadProfile(String uid) async {
    final snapshot = await _firestore.collection('app_users').doc(uid).get();
    if (!snapshot.exists) return null;
    return AppUserProfile.fromMap(snapshot.data()!, uid);
  }

  Future<void> _saveProfile(AppUserProfile profile) async {
    await _firestore
        .collection('app_users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }
}
