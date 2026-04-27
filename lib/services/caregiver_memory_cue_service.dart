import 'package:hive_flutter/hive_flutter.dart';

import '../models/memory_cue.dart';

class CaregiverMemoryCueService {
  static const String _boxName = 'caregiver_memory_cues';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<Box> _openBox() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : Hive.openBox(_boxName);

  Future<void> save(MemoryCue cue) async {
    final box = await _openBox();
    await box.put(cue.id, cue.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<MemoryCue?> getById(String id) async {
    final box = await _openBox();
    final raw = box.get(id);
    if (raw == null) return null;
    return MemoryCue.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<MemoryCue>> getAll(String patientId) async {
    final box = await _openBox();
    final values = box.values
        .map((raw) => MemoryCue.fromJson(Map<String, dynamic>.from(raw as Map)))
        .where((cue) => cue.patientId == patientId)
        .toList();
    values.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    return values;
  }
}
