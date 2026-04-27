import 'package:hive_flutter/hive_flutter.dart';

import '../models/patient_location_ping.dart';

class PatientLocationService {
  static const String _boxName = 'patient_location_pings';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<Box> _openBox() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : Hive.openBox(_boxName);

  Future<void> save(PatientLocationPing ping) async {
    final box = await _openBox();
    await box.put(ping.id, ping.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<List<PatientLocationPing>> getAll(String patientId) async {
    final box = await _openBox();
    final pings = box.values
        .map(
          (raw) => PatientLocationPing.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .where((ping) => ping.patientId == patientId)
        .toList();
    pings.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return pings;
  }

  Future<PatientLocationPing?> getLatest(String patientId) async {
    final all = await getAll(patientId);
    return all.isEmpty ? null : all.first;
  }
}
