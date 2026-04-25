import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/memory_item.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/patient_session_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../services/camera_service.dart';
import '../../../models/camera_event.dart';
import '../../../services/vision_service.dart';
import '../../../services/camera_event_service.dart';

class CameraLiveScreen extends StatefulWidget {
  const CameraLiveScreen({super.key});

  @override
  State<CameraLiveScreen> createState() => _CameraLiveScreenState();
}

class _CameraLiveScreenState extends State<CameraLiveScreen> {
  late CameraService _cameraService;
  late VisionService _visionService;
  late CameraEventService _eventService;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  Timer? _intervalTimer;
  bool _autoCaptureEnabled = false;

  @override
  void initState() {
    super.initState();
    _cameraService = context.read<CameraService>();
    _visionService = context.read<VisionService>();
    _eventService = context.read<CameraEventService>();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraService.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _intervalTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  void _toggleAutoCapture() {
    setState(() {
      _autoCaptureEnabled = !_autoCaptureEnabled;
      if (_autoCaptureEnabled) {
        _intervalTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
          _capture();
        });
      } else {
        _intervalTimer?.cancel();
      }
    });
  }

  Future<void> _capture() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      await context.read<PatientSessionProvider>().touchActivity(
        'Capturing an observation',
        contextSummary: 'A new surroundings snapshot is being captured.',
      );
      final event = await _cameraService.captureSnapshot();
      if (mounted) {
        _runAnalysis(event);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _runAnalysis(CameraEvent event) async {
    final patientSession = context.read<PatientSessionProvider>();
    setState(() => _isAnalyzing = true);
    try {
      final result = await _visionService.analyzeImage(event.imagePath);

      final updatedEvent = event.copyWith(
        note: result.description,
        detectedObjects: result.detectedObjects,
        locationHint: result.locationHint,
        unusualObservation: result.unusualObservation,
        concernLevel: result.concernLevel,
        hasFace: result.hasFace,
        faceCount: result.faceCount,
        detectedType: result.detectedType,
        analysisTimestamp: result.analysisTimestamp,
      );

      await _eventService.updateEvent(updatedEvent);
      await patientSession.touchActivity(
        'Observation analyzed',
        contextSummary: result.description,
      );

      if (mounted) {
        _showCaptureFeedback(updatedEvent);
      }
    } catch (e) {
      debugPrint('Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showCaptureFeedback(CameraEvent event) {
    final String suggestion = event.detectedType == 'person'
        ? 'Looks like a person'
        : 'Looks like a place or event';
    final String description = event.note.isNotEmpty
        ? event.note
        : 'This observation is ready to be saved as a memory.';
    final String extraHint = event.detectedObjects.isNotEmpty
        ? 'Objects: ${event.detectedObjects.take(3).join(', ')}'
        : event.locationHint.toLowerCase() != 'unknown'
        ? 'Location: ${event.locationHint}'
        : '';

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Snapshot Captured & Analyzed'),
            Text(
              suggestion,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (extraHint.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                extraHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        action: SnackBarAction(
          label: 'SAVE AS MEMORY',
          onPressed: () async {
            await _saveAsMemory(event);
          },
        ),
      ),
    );
  }

  Future<void> _saveAsMemory(CameraEvent event) async {
    final messenger = ScaffoldMessenger.of(context);
    final memoryProvider = context.read<MemoryProvider>();
    final patientSession = context.read<PatientSessionProvider>();
    final memoryType = _toMemoryType(event.detectedType);
    final title = _memoryTitleFor(event);
    final tags = <String>[
      event.detectedType,
      'camera_capture',
      ...event.detectedObjects,
      if (event.locationHint.toLowerCase() != 'unknown')
        event.locationHint.toLowerCase().replaceAll(' ', '_'),
      if (event.hasFace) 'person_detected',
      if (!event.hasFace && event.detectedType == 'place') 'place_context',
    ];

    await memoryProvider.addMemory(
      name: title,
      note: event.note.isNotEmpty
          ? event.note
          : 'Saved from patient observation.',
      type: memoryType,
      localImagePath: event.imagePath,
      tags: tags,
      location: patientSession.profile?.homeLabel,
      summary: event.note.isNotEmpty
          ? event.note
          : 'Observed a ${event.detectedType} moment.',
      confidence: event.concernLevel == 'high'
          ? 0.98
          : event.hasFace
          ? 0.95
          : 0.8,
    );

    await patientSession.touchActivity(
      'Saved an observation as memory',
      contextSummary: event.note.isNotEmpty
          ? event.note
          : 'A new memory was created from observation.',
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Saved "$title" to memories.')),
    );
  }

  MemoryType _toMemoryType(String detectedType) {
    switch (detectedType) {
      case 'person':
        return MemoryType.person;
      case 'place':
        return MemoryType.place;
      default:
        return MemoryType.event;
    }
  }

  String _memoryTitleFor(CameraEvent event) {
    final dateLabel =
        '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}';
    switch (event.detectedType) {
      case 'person':
        return 'Familiar person at $dateLabel';
      case 'place':
        return 'Important place at $dateLabel';
      default:
        return 'Observed moment at $dateLabel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!_cameraService.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(child: CameraPreview(_cameraService.controller!)),

          // Top Controls
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE OBSERVATION',
                        style: textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.patientObservationHistory,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Auto Capture Toggle
                GestureDetector(
                  onTap: _toggleAutoCapture,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _autoCaptureEnabled
                          ? AppColors.primary
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _autoCaptureEnabled ? Icons.timer : Icons.timer_off,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _autoCaptureEnabled ? 'AUTO ON (15s)' : 'AUTO OFF',
                          style: textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Capture Button
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    height: 90,
                    width: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    await _cameraService.switchCamera();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(
                    Icons.flip_camera_ios_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Switch Camera',
                    style: textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Analyzing Indicator
          if (_isAnalyzing)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Analyzing Environment...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Placeholder for Future ML Detection
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Environment Perception Active',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
