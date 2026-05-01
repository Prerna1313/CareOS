import 'package:hive_flutter/hive_flutter.dart';
import '../models/memory_item.dart';

class MemoryService {
  static const String _boxName = 'memory_items';

  Future<void> init() async {
    await _openBox();
    await purgeLegacyDemoMemories();
  }

  Future<Box> _openBox() async =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : Hive.openBox(_boxName);

  Future<void> addMemory(MemoryItem item) async {
    final box = await _openBox();
    await box.put(item.id, item.toMap());
  }

  MemoryItem? getMemoryById(String id) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final data = Hive.box(_boxName).get(id);
    return data != null ? MemoryItem.fromMap(data) : null;
  }

  List<MemoryItem> getAllMemories({String? patientId}) {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final memories = Hive.box(_boxName).values
        .map((data) => MemoryItem.fromMap(data))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (patientId == null || patientId.trim().isEmpty) {
      return memories;
    }
    return memories.where((memory) => memory.patientId == patientId).toList();
  }

  List<MemoryItem> getMemoriesByType(MemoryType type) {
    return getAllMemories().where((m) => m.type == type).toList();
  }

  List<MemoryItem> searchMemories(String query) {
    if (query.isEmpty) return getAllMemories();
    final lowerQuery = query.toLowerCase();
    return getAllMemories().where((m) {
      final nameMatch = m.name.toLowerCase().contains(lowerQuery);
      final tagMatch = m.tags.any((t) => t.toLowerCase().contains(lowerQuery));
      return nameMatch || tagMatch;
    }).toList();
  }

  Future<void> updateMemory(MemoryItem item) async {
    final box = await _openBox();
    await box.put(item.id, item.toMap());
  }

  Future<void> deleteMemory(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<void> clearMemoriesForPatient(String patientId) async {
    final box = await _openBox();
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final item = MemoryItem.fromMap(raw);
      if (item.patientId == patientId) {
        keysToDelete.add(key);
      }
    }
    await box.deleteAll(keysToDelete);
  }

  Future<void> purgeLegacyDemoMemories() async {
    final box = await _openBox();
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final item = MemoryItem.fromMap(raw);
      if (item.patientId.isEmpty ||
          item.patientId == 'patient_local_demo' ||
          item.patientId == 'pat_123') {
        keysToDelete.add(key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }
}
