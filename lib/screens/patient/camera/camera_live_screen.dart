import 'dart:async';
import 'dart:io';
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
import '../../../models/patient/backend_processing_models.dart';
import '../../../services/backend_processing_service.dart';
import '../../../services/backend_video_result_service.dart';
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
  bool _isMonitoring = false;
  bool _isRecordingClip = false;
  bool _isAnalyzingClip = false;
  Timer? _intervalTimer;
  Timer? _sessionTicker;
  bool _autoCaptureEnabled = false;
  DateTime? _monitoringStartedAt;
  Duration _monitoringDuration = Duration.zero;
  VisionAnalysisResult? _latestAnalysisResult;
  String? _latestAnalyzedImagePath;
  BackendVideoProcessingResult? _latestVideoResult;
  DateTime? _lastAutoTriggeredClipAt;

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
    _sessionTicker?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  void _toggleAutoCapture() {
    setState(() {
      _autoCaptureEnabled = !_autoCaptureEnabled;
      if (_autoCaptureEnabled) {
        _startAutoCaptureTimer();
      } else {
        _stopAutoCaptureTimer();
      }
    });
  }

  void _startAutoCaptureTimer() {
    _intervalTimer?.cancel();
    _intervalTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _capture(triggerReason: _isMonitoring ? 'live_monitoring_interval' : 'auto_capture');
    });
  }

  void _stopAutoCaptureTimer() {
    _intervalTimer?.cancel();
    _intervalTimer = null;
  }

  Future<void> _toggleMonitoringSession() async {
    if (_isMonitoring) {
      await _stopMonitoringSession();
      return;
    }

    await context.read<PatientSessionProvider>().touchActivity(
      'Live observation running',
      contextSummary: 'The app is monitoring the surroundings for safety changes.',
    );

    setState(() {
      _isMonitoring = true;
      _monitoringStartedAt = DateTime.now();
      _monitoringDuration = Duration.zero;
      _autoCaptureEnabled = true;
    });

    _startAutoCaptureTimer();
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _monitoringStartedAt;
      if (!mounted || startedAt == null) return;
      setState(() {
        _monitoringDuration = DateTime.now().difference(startedAt);
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live observation started. The app will capture interval snapshots.'),
        ),
      );
    }
  }

  Future<void> _stopMonitoringSession() async {
    _stopAutoCaptureTimer();
    _sessionTicker?.cancel();
    await context.read<PatientSessionProvider>().touchActivity(
      'Live observation stopped',
      contextSummary: 'The monitoring session has ended.',
    );
    if (!mounted) return;
    setState(() {
      _isMonitoring = false;
      _autoCaptureEnabled = false;
      _monitoringStartedAt = null;
      _monitoringDuration = Duration.zero;
    });
  }

  Future<void> _capture({String triggerReason = 'manual_snapshot'}) async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      await context.read<PatientSessionProvider>().touchActivity(
        'Capturing an observation',
        contextSummary: _isMonitoring
            ? 'A live observation snapshot is being captured.'
            : 'A new surroundings snapshot is being captured.',
      );
      final event = await _cameraService.captureSnapshot();
      if (mounted) {
        _runAnalysis(event, triggerReason: triggerReason);
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

  Future<void> _runAnalysis(
    CameraEvent event, {
    String triggerReason = 'manual_snapshot',
  }) async {
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
        setState(() {
          _latestAnalysisResult = result;
          _latestAnalyzedImagePath = event.imagePath;
        });
        _showCaptureFeedback(updatedEvent, triggerReason: triggerReason);
        _maybeAutoTriggerSafetyClip(updatedEvent);
      }
    } catch (e) {
      debugPrint('Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showCaptureFeedback(CameraEvent event, {String triggerReason = 'manual_snapshot'}) {
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
        showCloseIcon: true,
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
            if (_isMonitoring && triggerReason == 'live_monitoring_interval') ...[
              const SizedBox(height: 4),
              Text(
                'Captured during live observation.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
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

  Future<void> _recordShortClip({String triggerReason = 'manual_clip'}) async {
    if (_isRecordingClip || _isAnalyzingClip) return;

    try {
      await context.read<PatientSessionProvider>().touchActivity(
        'Recording observation clip',
        contextSummary: 'A short live observation clip is being recorded for safety analysis.',
      );

      setState(() => _isRecordingClip = true);
      await _cameraService.startVideoRecording();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            triggerReason == 'manual_clip'
                ? 'Recording a short safety clip...'
                : 'Safety concern detected. Recording a short clip...',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(seconds: 8));
      final clipPath = await _cameraService.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecordingClip = false);
      await _analyzeObservationClip(clipPath, triggerReason: triggerReason);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecordingClip = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Clip recording failed: $e')));
    }
  }

  Future<void> _analyzeObservationClip(
    String clipPath, {
    String triggerReason = 'manual_clip',
  }) async {
    final backend = context.read<BackendProcessingService>();
    final resultStore = context.read<BackendVideoResultService>();
    final patientSession = context.read<PatientSessionProvider>();

    if (!backend.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend is not configured for live clip analysis yet.'),
        ),
      );
      return;
    }

    setState(() => _isAnalyzingClip = true);
    try {
      final clipId = 'clip_${DateTime.now().millisecondsSinceEpoch}';
      final result = await backend.processObservationClip(
        patientId: patientSession.patientId,
        clipId: clipId,
        clipPath: clipPath,
        sourceEventId: _latestAnalyzedImagePath ?? 'live_observation',
        triggerReason: triggerReason,
      );

      if (result != null) {
        await resultStore.saveResult(result);
        await patientSession.touchActivity(
          'Observation clip analyzed',
          contextSummary: result.fallAnalysis.summary.isNotEmpty
              ? result.fallAnalysis.summary
              : result.movementAnalysis.summary,
        );
      }

      if (!mounted) return;
      setState(() => _latestVideoResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'Clip saved, but no backend result was returned.'
                : 'Clip analyzed: ${result.fallAnalysis.riskLevel.toUpperCase()} fall risk, ${result.movementAnalysis.movementRiskLevel.toUpperCase()} movement risk.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Clip analysis failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingClip = false);
      }
    }
  }

  void _maybeAutoTriggerSafetyClip(CameraEvent event) {
    if (!_isMonitoring ||
        _isRecordingClip ||
        _isAnalyzingClip ||
        !_cameraService.isInitialized) {
      return;
    }

    final now = DateTime.now();
    final lastTrigger = _lastAutoTriggeredClipAt;
    if (lastTrigger != null && now.difference(lastTrigger) < const Duration(minutes: 2)) {
      return;
    }

    final triggerReason = _autoClipTriggerReason(event);
    if (triggerReason == null) return;

    _lastAutoTriggeredClipAt = now;
    unawaited(_recordShortClip(triggerReason: triggerReason));
  }

  String? _autoClipTriggerReason(CameraEvent event) {
    final note = '${event.note} ${event.unusualObservation}'.toLowerCase();
    final objects = event.detectedObjects.map((item) => item.toLowerCase()).toList();

    final possibleFall = note.contains('fall') ||
        note.contains('collapse') ||
        note.contains('lying on the floor') ||
        note.contains('slumped') ||
        (event.concernLevel == 'high' &&
            (note.contains('floor') || note.contains('ground')));
    if (possibleFall) {
      return 'auto_possible_fall';
    }

    final riskyScene = event.concernLevel == 'high' ||
        note.contains('spill') ||
        note.contains('clutter') ||
        note.contains('blocked') ||
        note.contains('sharp') ||
        note.contains('stove') ||
        objects.any(
          (item) =>
              item.contains('spill') ||
              item.contains('knife') ||
              item.contains('sharp'),
        );
    if (riskyScene) {
      return 'auto_risky_scene';
    }

    final wanderingStyle = event.concernLevel == 'medium' &&
        event.locationHint.toLowerCase() == 'unknown' &&
        (note.contains('unclear') || note.contains('wandering'));
    if (wanderingStyle) {
      return 'auto_wandering_review';
    }

    return null;
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

          if (_latestAnalysisResult != null && _latestAnalyzedImagePath != null)
            Positioned(
              top: 132,
              right: 16,
              child: _DetectionPreviewCard(
                imagePath: _latestAnalyzedImagePath!,
                result: _latestAnalysisResult!,
                onClose: () {
                  setState(() {
                    _latestAnalysisResult = null;
                    _latestAnalyzedImagePath = null;
                  });
                },
              ),
            ),

          if (_latestVideoResult != null)
            Positioned(
              top: 360,
              right: 16,
              child: _VideoAnalysisPreviewCard(
                result: _latestVideoResult!,
                onClose: () {
                  setState(() {
                    _latestVideoResult = null;
                  });
                },
              ),
            ),

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
                        _isMonitoring ? 'LIVE OBSERVATION ON' : 'LIVE OBSERVATION',
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
                if (_isMonitoring)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Monitoring active',
                          style: textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(_monitoringDuration),
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Interval snapshots run every 20 seconds. You can also record a short safety clip.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    GestureDetector(
                      onTap: _toggleMonitoringSession,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _isMonitoring
                              ? const Color(0xFFE45B5B)
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isMonitoring ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isMonitoring ? 'STOP MONITORING' : 'START MONITORING',
                              style: textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                              _autoCaptureEnabled ? 'AUTO ON (20s)' : 'AUTO OFF',
                              style: textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Auto Capture Toggle
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
                ElevatedButton.icon(
                  onPressed: _isRecordingClip || _isAnalyzingClip
                      ? null
                      : () => _recordShortClip(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: _isRecordingClip
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.video_call_rounded),
                  label: Text(
                    _isRecordingClip
                        ? 'Recording clip...'
                        : _isAnalyzingClip
                        ? 'Analyzing clip...'
                        : 'Record short clip',
                  ),
                ),
                const SizedBox(height: 8),
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

          if (_isAnalyzingClip)
            Positioned(
              top: 172,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE45B5B).withValues(alpha: 0.92),
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
                        'Analyzing short observation clip...',
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

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _DetectionPreviewCard extends StatelessWidget {
  final String imagePath;
  final VisionAnalysisResult result;
  final VoidCallback onClose;

  const _DetectionPreviewCard({
    required this.imagePath,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Latest detection',
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                      ),
                      ...result.detectionBoxes.map(
                        (box) => _buildDetectionBox(
                          box,
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.unusualObservation.trim().isNotEmpty
                ? result.unusualObservation
                : result.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionBox(
    VisionDetectionBox box,
    double width,
    double height,
  ) {
    return Positioned(
      left: box.left * width,
      top: box.top * height,
      width: box.width * width,
      height: box.height * height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _strokeColor(box.category),
            width: box.category == 'safety' ? 2.4 : 1.8,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: _strokeColor(box.category),
            child: Text(
              box.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _strokeColor(String category) {
    switch (category) {
      case 'safety':
        return const Color(0xFFE53935);
      case 'person':
        return const Color(0xFFFF7043);
      default:
        return const Color(0xFFFF5252);
    }
  }
}

class _VideoAnalysisPreviewCard extends StatelessWidget {
  final BackendVideoProcessingResult result;
  final VoidCallback onClose;

  const _VideoAnalysisPreviewCard({
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Latest clip result',
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ResultChip(
            label: 'Fall risk',
            value: result.fallAnalysis.riskLevel.toUpperCase(),
            color: _severityColor(result.fallAnalysis.riskLevel),
          ),
          const SizedBox(height: 8),
          _ResultChip(
            label: 'Movement',
            value: result.movementAnalysis.movementRiskLevel.toUpperCase(),
            color: _severityColor(result.movementAnalysis.movementRiskLevel),
          ),
          const SizedBox(height: 10),
          Text(
            result.fallAnalysis.summary.isNotEmpty
                ? result.fallAnalysis.summary
                : result.movementAnalysis.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
          if (result.labels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.labels
                  .take(4)
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _severityColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return const Color(0xFFE45B5B);
      case 'medium':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF7BCB90);
    }
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
