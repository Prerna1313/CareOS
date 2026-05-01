import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/memory_item.dart';
import '../services/memory_service.dart';
import '../services/memory_media_service.dart';
import '../services/firestore/firestore_memory_service.dart';
import '../services/recognition_service.dart';

class MemoryProvider extends ChangeNotifier {
  final String _patientId;
  final MemoryService _service;
  final MemoryMediaService _mediaService;
  final FirestoreMemoryService? _firestoreService;
  final RecognitionService? _recognitionService;

  MemoryProvider(
    this._service,
    this._mediaService,
    this._patientId, {
    FirestoreMemoryService? firestoreService,
    RecognitionService? recognitionService,
  }) : _firestoreService = firestoreService,
       _recognitionService = recognitionService {
    _loadMemories();
    _listenToCloudUpdates();
  }

  void _listenToCloudUpdates() {
    _firestoreService?.getMemoriesStream().listen((cloudMemories) async {
      final scopedCloudMemories = cloudMemories
          .where((item) => item.patientId == _patientId)
          .toList();
      // 1. Reconcile with local Hive
      for (final cloudItem in scopedCloudMemories) {
        final localItem = _service.getMemoryById(cloudItem.id);
        if (localItem == null) {
          // New from cloud
          await _service.addMemory(cloudItem);
        } else if (cloudItem.remoteImageUrl != null &&
            localItem.remoteImageUrl == null) {
          // Updated with remote URL
          await _service.updateMemory(
            localItem.copyWith(
              remoteImageUrl: cloudItem.remoteImageUrl,
              uploadStatus: UploadStatus.uploaded,
            ),
          );
        }
      }
      _loadMemories();
    });
  }

  List<MemoryItem> _memories = [];
  String _searchQuery = '';
  MemoryType? _filterType;

  List<MemoryItem> get memories {
    var list = _memories;
    if (_filterType != null) {
      list = list.where((m) => m.type == _filterType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((m) {
        return m.name.toLowerCase().contains(query) ||
            m.tags.any((t) => t.toLowerCase().contains(query));
      }).toList();
    }
    return list;
  }

  void _loadMemories() {
    _memories = _service.getAllMemories(patientId: _patientId);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterType(MemoryType? type) {
    _filterType = type;
    notifyListeners();
  }

  /// Adds a new memory item and triggers the upload pipeline if an image is provided
  Future<void> addMemory({
    required String name,
    required String note,
    required MemoryType type,
    String? localImagePath,
    String? voiceNotePath,
    List<String> tags = const [],
    String? location,
    String? summary,
    double? confidence,
  }) async {
    final item = MemoryItem(
      id: const Uuid().v4(),
      patientId: _patientId,
      type: type,
      name: name,
      note: note,
      localImagePath: localImagePath,
      voiceNotePath: voiceNotePath,
      uploadStatus: localImagePath != null
          ? UploadStatus.localOnly
          : UploadStatus.uploaded,
      createdAt: DateTime.now(),
      tags: tags,
      location: location,
      summary: summary,
      confidence: confidence,
    );

    // 1. Save locally first (Source of Truth)
    await _service.addMemory(item);
    _loadMemories();

    // Trigger recognition scheduling
    await _recognitionService?.onMemoryAdded(item);

    // 2. Sync metadata to Firestore
    await _firestoreService?.syncMemoryItem(item);

    // 3. Trigger background upload if image exists
    if (localImagePath != null) {
      _startUpload(item.id, localImagePath, item.patientId);
    }
  }

  /// Retries a failed upload
  Future<void> retryUpload(String memoryId) async {
    final item = _memories.firstWhere((m) => m.id == memoryId);
    if (item.localImagePath != null) {
      _startUpload(item.id, item.localImagePath!, item.patientId);
    }
  }

  /// Internal method to handle the upload pipeline in background
  Future<void> _startUpload(String id, String localPath, String userId) async {
    try {
      // Update status to uploading
      await _updateItemStatus(id, UploadStatus.uploading);

      // Upload to Firebase Storage
      final remoteUrl = await _mediaService.uploadToFirebase(localPath, userId);

      if (remoteUrl != null) {
        // Update with remote URL and uploaded status
        await _updateItemStatus(
          id,
          UploadStatus.uploaded,
          remoteUrl: remoteUrl,
        );
      } else {
        // Mark as failed
        await _updateItemStatus(id, UploadStatus.failed);
      }
    } catch (e) {
      debugPrint('Upload pipeline error: $e');
      await _updateItemStatus(id, UploadStatus.failed);
    }
  }

  Future<void> _updateItemStatus(
    String id,
    UploadStatus status, {
    String? remoteUrl,
  }) async {
    final index = _memories.indexWhere((m) => m.id == id);
    if (index != -1) {
      final updatedItem = _memories[index].copyWith(
        uploadStatus: status,
        remoteImageUrl: remoteUrl,
      );

      // Update local Hive
      await _service.updateMemory(updatedItem);

      // Update Firestore
      await _firestoreService?.syncMemoryItem(updatedItem);

      // Refresh local list
      _loadMemories();
    }
  }

  Future<void> deleteMemory(String id) async {
    final item = _memories.firstWhere(
      (m) => m.id == id,
      orElse: () => throw Exception('Item not found'),
    );

    // Delete local file if it's in our app's documents
    if (item.localImagePath != null &&
        item.localImagePath!.contains('memories')) {
      await _mediaService.deleteLocalFile(item.localImagePath!);
    }

    await _service.deleteMemory(id);
    await _firestoreService?.deleteMemoryItem(id);
    _loadMemories();
  }

  /// UI utility for picking images
  Future<XFile?> pickImage(ImageSource source) async {
    return await _mediaService.pickImage(source);
  }

  /// UI utility for saving image locally before adding memory
  Future<String?> saveImageLocally(XFile file) async {
    return await _mediaService.saveImageLocally(file);
  }
}
