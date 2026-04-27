import 'package:hive_flutter/hive_flutter.dart';

import '../models/patient/patient_profile.dart';

class PatientSessionService {
  static const String _boxName = 'patient_session';
  static const String _profileKey = 'active_profile';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  PatientProfile? getActiveProfile() {
    final data = _box.get(_profileKey);
    if (data == null) return null;
    return PatientProfile.fromMap(Map<dynamic, dynamic>.from(data));
  }

  PatientProfile? getProfileById(String patientId) {
    final profile = getActiveProfile();
    if (profile == null || profile.patientId != patientId) {
      return null;
    }
    return profile;
  }

  Future<void> saveProfile(PatientProfile profile) async {
    await _box.put(_profileKey, profile.toMap());
  }

  Future<void> clearProfile() async {
    await _box.delete(_profileKey);
  }
}
