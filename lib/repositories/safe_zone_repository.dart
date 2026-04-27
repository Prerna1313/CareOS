import '../models/safe_zone.dart';
import '../services/mock_data_provider.dart';
import '../services/caregiver_safe_zone_service.dart';
import '../services/firestore/firestore_caregiver_service.dart';
import 'base_repository.dart';

class SafeZoneRepository implements BaseRepository<SafeZone> {
  final _service = CaregiverSafeZoneService();
  final _firestoreService = FirestoreCaregiverService();

  @override
  Future<void> create(SafeZone item) async {
    await _service.save(item);
    await _firestoreService.syncSafeZone(item);
  }

  @override
  Future<void> delete(String id) async {
    await _service.delete(id);
    await _firestoreService.deleteSafeZone(id);
  }

  @override
  Future<List<SafeZone>> getAll(String patientId) async {
    var zones = await _service.getAll(patientId);
    if (zones.isNotEmpty) {
      return zones;
    }
    final remoteZones = (await _firestoreService.getAllSafeZones())
        .where((zone) => zone.patientId == patientId)
        .toList();
    if (remoteZones.isNotEmpty) {
      for (final zone in remoteZones) {
        await _service.save(zone);
      }
      zones = remoteZones;
      return zones;
    }
    return MockDataProvider.getMockSafeZones(patientId: patientId);
  }

  @override
  Future<SafeZone?> getById(String id) => _service.getById(id);

  @override
  Future<void> update(SafeZone item) async {
    await _service.save(item);
    await _firestoreService.syncSafeZone(item);
  }
}
