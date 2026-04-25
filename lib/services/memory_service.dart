import 'package:hive_flutter/hive_flutter.dart';
import '../models/memory_item.dart';

class MemoryService {
  static const String _boxName = 'memory_items';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  Future<void> addMemory(MemoryItem item) async {
    await _box.put(item.id, item.toMap());
  }

  MemoryItem? getMemoryById(String id) {
    final data = _box.get(id);
    return data != null ? MemoryItem.fromMap(data) : null;
  }

  List<MemoryItem> getAllMemories() {
    return _box.values
        .map((data) => MemoryItem.fromMap(data))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    await _box.put(item.id, item.toMap());
  }

  Future<void> deleteMemory(String id) async {
    await _box.delete(id);
  }
}
