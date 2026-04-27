import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'camera_event_service.dart';
import '../models/camera_event.dart';

class CameraService {
  final CameraEventService _eventService;
  final Uuid _uuid = const Uuid();
  
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isRecordingVideo = false;

  CameraService(this._eventService);

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isRecordingVideo => _isRecordingVideo;

  Future<void> init() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      await _initializeCamera(_cameras.first);
    }
  }

  Future<void> _initializeCamera(CameraDescription description) async {
    _controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: !kIsWeb,
    );

    try {
      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    
    final currentDescription = _controller?.description;
    final newDescription = _cameras.firstWhere(
      (c) => c.lensDirection != currentDescription?.lensDirection,
      orElse: () => _cameras.first,
    );

    await _controller?.dispose();
    await _initializeCamera(newDescription);
  }

  Future<CameraEvent> captureSnapshot() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }

    final XFile file = await _controller!.takePicture();

    late final String savedPath;
    if (kIsWeb) {
      savedPath = file.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${_uuid.v4()}.jpg';
      savedPath = p.join(directory.path, 'captures', fileName);

      final capturesDir = Directory(p.join(directory.path, 'captures'));
      if (!capturesDir.existsSync()) {
        capturesDir.createSync(recursive: true);
      }

      await File(file.path).copy(savedPath);
    }
    
    // Create event record
    final event = CameraEvent(
      id: _uuid.v4(),
      imagePath: savedPath,
      timestamp: DateTime.now(),
    );

    await _eventService.logEvent(event);
    return event;
  }

  Future<void> startVideoRecording() async {
    if (kIsWeb) {
      throw Exception('Video recording is not available on web yet.');
    }
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }
    if (_isRecordingVideo) return;

    await _controller!.startVideoRecording();
    _isRecordingVideo = true;
  }

  Future<String> stopVideoRecording() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }
    if (!_isRecordingVideo) {
      throw Exception('Video recording is not active');
    }

    final XFile file = await _controller!.stopVideoRecording();
    _isRecordingVideo = false;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${_uuid.v4()}.mp4';
    final savedPath = p.join(directory.path, 'clips', fileName);

    final clipsDir = Directory(p.join(directory.path, 'clips'));
    if (!clipsDir.existsSync()) {
      clipsDir.createSync(recursive: true);
    }

    await File(file.path).copy(savedPath);
    return savedPath;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _isInitialized = false;
  }
}
