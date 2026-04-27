import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/patient_location_ping.dart';
import 'firestore/firestore_caregiver_service.dart';
import 'patient_location_service.dart';

class WearableLocationSourceStatus {
  final bool serviceEnabled;
  final LocationPermission permission;
  final bool tracking;
  final String message;

  const WearableLocationSourceStatus({
    required this.serviceEnabled,
    required this.permission,
    required this.tracking,
    required this.message,
  });

  bool get canTrack {
    return serviceEnabled &&
        permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }
}

class WearableLocationSourceService {
  static StreamSubscription<Position>? _subscription;
  static String? _activePatientId;
  static final StreamController<PatientLocationPing> _pingController =
      StreamController<PatientLocationPing>.broadcast();

  final _uuid = const Uuid();
  final _locationService = PatientLocationService();
  final _firestoreCaregiverService = FirestoreCaregiverService();

  Stream<PatientLocationPing> get pingStream => _pingController.stream;

  bool get isTracking => _subscription != null;
  String? get activePatientId => _activePatientId;

  Future<WearableLocationSourceStatus> getStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    return WearableLocationSourceStatus(
      serviceEnabled: serviceEnabled,
      permission: permission,
      tracking: isTracking,
      message: _messageFor(
        serviceEnabled: serviceEnabled,
        permission: permission,
        tracking: isTracking,
      ),
    );
  }

  Future<WearableLocationSourceStatus> ensureReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const WearableLocationSourceStatus(
        serviceEnabled: false,
        permission: LocationPermission.unableToDetermine,
        tracking: false,
        message: 'Turn on device location services to share live GPS updates.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return WearableLocationSourceStatus(
      serviceEnabled: serviceEnabled,
      permission: permission,
      tracking: isTracking,
      message: _messageFor(
        serviceEnabled: serviceEnabled,
        permission: permission,
        tracking: isTracking,
      ),
    );
  }

  Future<WearableLocationSourceStatus> startTracking({
    required String patientId,
    required String label,
  }) async {
    final status = await ensureReady();
    if (!status.canTrack) {
      return status;
    }

    if (_subscription != null && _activePatientId == patientId) {
      return const WearableLocationSourceStatus(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
        tracking: true,
        message: 'Live GPS sharing is already active on this device.',
      );
    }

    await stopTracking();
    _activePatientId = patientId;

    final initial = await _captureAndPersist(
      patientId: patientId,
      label: label,
      source: 'patient_device_gps_snapshot',
      settings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    );
    _pingController.add(initial);

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 20,
      ),
    ).listen((position) async {
      try {
        final ping = await _persistPosition(
          patientId: patientId,
          label: label,
          source: 'patient_device_gps_live',
          position: position,
        );
        _pingController.add(ping);
      } catch (_) {
        // Keep the stream alive even if one sync/save call fails.
      }
    });

    return const WearableLocationSourceStatus(
      serviceEnabled: true,
      permission: LocationPermission.whileInUse,
      tracking: true,
      message:
          'Live device GPS sharing is active. Caregiver safe-zone monitoring will use this feed.',
    );
  }

  Future<PatientLocationPing?> captureCurrentPosition({
    required String patientId,
    required String label,
  }) async {
    final status = await ensureReady();
    if (!status.canTrack) {
      return null;
    }
    final ping = await _captureAndPersist(
      patientId: patientId,
      label: label,
      source: 'patient_device_gps_snapshot',
      settings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    );
    _pingController.add(ping);
    return ping;
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _activePatientId = null;
  }

  Future<PatientLocationPing> _captureAndPersist({
    required String patientId,
    required String label,
    required String source,
    required LocationSettings settings,
  }) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    );
    return _persistPosition(
      patientId: patientId,
      label: label,
      source: source,
      position: position,
    );
  }

  Future<PatientLocationPing> _persistPosition({
    required String patientId,
    required String label,
    required String source,
    required Position position,
  }) async {
    final ping = PatientLocationPing(
      id: _uuid.v4(),
      patientId: patientId,
      label: label.trim().isEmpty ? 'Live device GPS' : label.trim(),
      latitude: position.latitude,
      longitude: position.longitude,
      source: source,
      capturedAt: DateTime.now(),
    );
    await _locationService.save(ping);
    await _firestoreCaregiverService.syncPatientLocationPing(ping);
    return ping;
  }

  String _messageFor({
    required bool serviceEnabled,
    required LocationPermission permission,
    required bool tracking,
  }) {
    if (!serviceEnabled) {
      return 'Turn on device location services to share live GPS updates.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission is permanently denied. Re-enable it from device settings.';
    }
    if (permission == LocationPermission.denied) {
      return 'Allow location access so CareOS can send live patient GPS updates.';
    }
    if (tracking) {
      return 'Live device GPS sharing is active.';
    }
    return 'Device GPS is available and ready to share with caregivers.';
  }
}
