import 'package:hive_flutter/hive_flutter.dart';

import '../models/patient/patient_profile.dart';

class PatientSessionService {
  static const String _boxName = 'patient_session';
  static const String _profileKey = 'active_profile';
  static const String _profilesByIdKey = 'profiles_by_id';
  static const String _profilesByCodeKey = 'profiles_by_code';

  Future<void> init() async {
    await _openBox();
  }

  Future<Box> _openBox() async =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : Hive.openBox(_boxName);

  PatientProfile? getActiveProfile() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final data = Hive.box(_boxName).get(_profileKey);
    if (data == null) return null;
    return PatientProfile.fromMap(Map<dynamic, dynamic>.from(data));
  }

  PatientProfile? getProfileById(String patientId) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final storedProfiles = Map<dynamic, dynamic>.from(
      box.get(_profilesByIdKey, defaultValue: const <String, dynamic>{}) as Map,
    );
    final raw = storedProfiles[patientId];
    if (raw == null) {
      final profile = getActiveProfile();
      if (profile == null || profile.patientId != patientId) {
        return null;
      }
      return profile;
    }
    return PatientProfile.fromMap(Map<dynamic, dynamic>.from(raw as Map));
  }

  PatientProfile? getProfileForAccessCode(String accessCode) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final normalized = accessCode.trim();
    if (normalized.isEmpty) return null;
    final box = Hive.box(_boxName);
    final storedCodes = Map<dynamic, dynamic>.from(
      box.get(_profilesByCodeKey, defaultValue: const <String, dynamic>{}) as Map,
    );
    final patientId = storedCodes[normalized];
    if (patientId is! String) return null;
    return getProfileById(patientId);
  }

  List<PatientProfile> getAllProfiles() {
    if (!Hive.isBoxOpen(_boxName)) {
      return [];
    }
    final box = Hive.box(_boxName);
    final storedProfiles = Map<dynamic, dynamic>.from(
      box.get(_profilesByIdKey, defaultValue: const <String, dynamic>{}) as Map,
    );
    final profiles = storedProfiles.values
        .map((raw) => PatientProfile.fromMap(Map<dynamic, dynamic>.from(raw as Map)))
        .toList();
    profiles.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    final activeProfile = getActiveProfile();
    if (activeProfile != null &&
        profiles.every((profile) => profile.patientId != activeProfile.patientId)) {
      profiles.insert(0, activeProfile);
    }
    return profiles;
  }

  Future<void> saveProfile(PatientProfile profile) async {
    final box = await _openBox();
    await box.put(_profileKey, profile.toMap());
    await _saveLinkedProfileInternal(box, profile);
  }

  Future<void> saveLinkedProfile(PatientProfile profile) async {
    final box = await _openBox();
    await _saveLinkedProfileInternal(box, profile);
  }

  Future<void> clearProfile() async {
    final box = await _openBox();
    await box.delete(_profileKey);
  }

  Future<void> _saveLinkedProfileInternal(Box box, PatientProfile profile) async {
    final storedProfiles = Map<String, dynamic>.from(
      box.get(_profilesByIdKey, defaultValue: const <String, dynamic>{}) as Map,
    );
    storedProfiles[profile.patientId] = profile.toMap();
    await box.put(_profilesByIdKey, storedProfiles);

    final storedCodes = Map<String, dynamic>.from(
      box.get(_profilesByCodeKey, defaultValue: const <String, dynamic>{}) as Map,
    );
    storedCodes[profile.accessCode] = profile.patientId;
    storedCodes[profile.patientId] = profile.patientId;
    await box.put(_profilesByCodeKey, storedCodes);
  }
}
