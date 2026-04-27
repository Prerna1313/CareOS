import '../models/memory_cue.dart';
import '../models/memory_item.dart';
import '../services/mock_data_provider.dart';
import '../services/caregiver_memory_cue_service.dart';
import '../services/firestore/firestore_caregiver_service.dart';
import '../services/memory_service.dart';
import 'base_repository.dart';

class MemoryCueRepository implements BaseRepository<MemoryCue> {
  final _service = CaregiverMemoryCueService();
  final _firestoreService = FirestoreCaregiverService();
  final _memoryService = MemoryService();

  @override
  Future<void> create(MemoryCue item) async {
    await _service.save(item);
    await _firestoreService.syncMemoryCue(item);
  }

  @override
  Future<void> delete(String id) async {
    await _service.delete(id);
    await _firestoreService.deleteMemoryCue(id);
  }

  @override
  Future<List<MemoryCue>> getAll(String patientId) async {
    var cues = await _service.getAll(patientId);
    if (cues.isNotEmpty) {
      return cues;
    }
    final remoteCues = (await _firestoreService.getAllMemoryCues())
        .where((cue) => cue.patientId == patientId)
        .toList();
    if (remoteCues.isNotEmpty) {
      for (final cue in remoteCues) {
        await _service.save(cue);
      }
      cues = remoteCues;
      return cues;
    }
    final patientMemories = _memoryService
        .getAllMemories()
        .where((memory) => memory.patientId == patientId)
        .map(_memoryToCue)
        .toList();
    if (patientMemories.isNotEmpty) {
      return patientMemories;
    }
    return MockDataProvider.getMockMemoryCues(patientId: patientId);
  }

  @override
  Future<MemoryCue?> getById(String id) async {
    return _service.getById(id);
  }

  @override
  Future<void> update(MemoryCue item) async {
    await _service.save(item);
    await _firestoreService.syncMemoryCue(item);
  }

  MemoryCue _memoryToCue(MemoryItem memory) {
    final type = switch (memory.type) {
      MemoryType.person => MemoryCueType.family,
      MemoryType.place => MemoryCueType.place,
      MemoryType.event => MemoryCueType.event,
    };

    return MemoryCue(
      id: 'memory_${memory.id}',
      patientId: memory.patientId,
      type: type,
      priority: MemoryCuePriority.high,
      title: memory.name,
      mediaUrl: memory.remoteImageUrl ?? memory.localImagePath,
      caption: memory.note,
      tags: memory.tags,
    );
  }
}
