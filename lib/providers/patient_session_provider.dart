import 'package:flutter/foundation.dart';

import '../models/patient/patient_profile.dart';
import '../services/patient_session_service.dart';

class PatientSessionProvider extends ChangeNotifier {
  final PatientSessionService _service;

  PatientSessionProvider(this._service);

  PatientProfile? _profile;
  bool _isLoaded = false;

  PatientProfile? get profile => _profile;
  bool get isLoaded => _isLoaded;
  bool get hasActiveSession => _profile != null;
  String get patientId => _profile?.patientId ?? 'patient_local_demo';

  Future<void> loadSession() async {
    _profile = _service.getActiveProfile();
    _isLoaded = true;
    notifyListeners();
  }

  Future<bool> bootstrapAccess({
    required String enteredCode,
    String? preferredName,
  }) async {
    final normalizedCode = enteredCode.trim();
    if (normalizedCode.isEmpty) return false;

    if (_profile == null) {
      _profile = PatientProfile.initial(
        patientId: _normalizePatientId(normalizedCode),
        accessCode: normalizedCode,
        displayName: preferredName,
      );
      await _service.saveProfile(_profile!);
      notifyListeners();
      return true;
    }

    final matchesExisting =
        normalizedCode == _profile!.accessCode ||
        normalizedCode == _profile!.patientId;
    if (!matchesExisting) {
      return false;
    }

    final updatedProfile = _profile!.copyWith(
      displayName: preferredName?.trim().isNotEmpty == true
          ? preferredName!.trim()
          : _profile!.displayName,
      lastActiveAt: DateTime.now(),
    );
    _profile = updatedProfile;
    await _service.saveProfile(updatedProfile);
    notifyListeners();
    return true;
  }

  Future<void> touchActivity(String activity, {String? contextSummary}) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      currentActivity: activity,
      lastActiveAt: DateTime.now(),
      lastKnownContextSummary:
          contextSummary ?? _profile!.lastKnownContextSummary,
    );
    await _service.saveProfile(_profile!);
    notifyListeners();
  }

  Future<void> updateOrientationContext({
    String? homeLabel,
    String? city,
    String? caregiverName,
    String? caregiverRelationship,
    String? contextSummary,
  }) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      homeLabel: homeLabel ?? _profile!.homeLabel,
      city: city ?? _profile!.city,
      caregiverName: caregiverName ?? _profile!.caregiverName,
      caregiverRelationship:
          caregiverRelationship ?? _profile!.caregiverRelationship,
      lastKnownContextSummary:
          contextSummary ?? _profile!.lastKnownContextSummary,
      lastActiveAt: DateTime.now(),
    );
    await _service.saveProfile(_profile!);
    notifyListeners();
  }

  Future<void> updateProfileSettings({
    required String displayName,
    required String homeLabel,
    required String city,
    required String caregiverName,
    required String caregiverRelationship,
    required List<String> importantItems,
    required bool autoOrientationEnabled,
    required bool voicePromptsEnabled,
    required double textScaleFactor,
    required bool highContrastEnabled,
    required bool reducedMotionEnabled,
    required bool simpleLayoutEnabled,
  }) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      displayName: displayName.trim().isNotEmpty
          ? displayName.trim()
          : _profile!.displayName,
      homeLabel: homeLabel.trim().isNotEmpty
          ? homeLabel.trim()
          : _profile!.homeLabel,
      city: city.trim().isNotEmpty ? city.trim() : _profile!.city,
      caregiverName: caregiverName.trim().isNotEmpty
          ? caregiverName.trim()
          : _profile!.caregiverName,
      caregiverRelationship: caregiverRelationship.trim().isNotEmpty
          ? caregiverRelationship.trim()
          : _profile!.caregiverRelationship,
      importantItems: importantItems,
      autoOrientationEnabled: autoOrientationEnabled,
      voicePromptsEnabled: voicePromptsEnabled,
      textScaleFactor: textScaleFactor,
      highContrastEnabled: highContrastEnabled,
      reducedMotionEnabled: reducedMotionEnabled,
      simpleLayoutEnabled: simpleLayoutEnabled,
      lastActiveAt: DateTime.now(),
      lastKnownContextSummary:
          'You are safe at ${homeLabel.trim().isNotEmpty ? homeLabel.trim() : _profile!.homeLabel}.',
    );
    await _service.saveProfile(_profile!);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _service.clearProfile();
    _profile = null;
    notifyListeners();
  }

  String _normalizePatientId(String raw) {
    final clean = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return clean.startsWith('patient_') ? clean : 'patient_$clean';
  }
}
