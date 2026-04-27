import 'package:hive_flutter/hive_flutter.dart';

import '../models/safe_zone.dart';

class CaregiverSafeZoneService {
  static const String _boxName = 'caregiver_safe_zones';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<Box> _openBox() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : Hive.openBox(_boxName);

  Future<void> save(SafeZone zone) async {
    final box = await _openBox();
    await box.put(zone.id, zone.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<SafeZone?> getById(String id) async {
    final box = await _openBox();
    final raw = box.get(id);
    if (raw == null) return null;
    return SafeZone.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<SafeZone>> getAll(String patientId) async {
    final box = await _openBox();
    final values = box.values
        .map((raw) => SafeZone.fromJson(Map<String, dynamic>.from(raw as Map)))
        .where((zone) => zone.patientId == patientId)
        .toList();
    values.sort((a, b) => a.name.compareTo(b.name));
    return values;
  }
}
