import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'cloud_vision_service.dart';
import 'cloud_ai_service.dart';

class VisionDetectionBox {
  final String label;
  final double left;
  final double top;
  final double width;
  final double height;
  final String category;

  const VisionDetectionBox({
    required this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.category,
  });
}

class VisionAnalysisResult {
  final bool hasFace;
  final int faceCount;
  final String detectedType;
  final String description;
  final List<String> detectedObjects;
  final String locationHint;
  final String unusualObservation;
  final String concernLevel;
  final DateTime analysisTimestamp;
  final List<VisionDetectionBox> detectionBoxes;

  VisionAnalysisResult({
    required this.hasFace,
    required this.faceCount,
    required this.detectedType,
    required this.description,
    required this.detectedObjects,
    required this.locationHint,
    required this.unusualObservation,
    required this.concernLevel,
    required this.analysisTimestamp,
    required this.detectionBoxes,
  });
}

class VisionService {
  final CloudAIService _aiService;
  final CloudVisionService _cloudVisionService;
  final FaceDetector _faceDetector;

  VisionService(this._aiService, this._cloudVisionService)
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
          enableLandmarks: false,
          enableTracking: false,
          minFaceSize: 0.1,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

  Future<VisionAnalysisResult> analyzeImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);
      final hasFace = faces.isNotEmpty;
      final faceCount = faces.length;
      final imageSize = await _readImageSize(imagePath);
      final localizedObjects = await _cloudVisionService.localizeObjectDetections(
        imagePath,
      );

      final insights = await _aiService.analyzeImageInsights(imagePath);
      final description =
          insights['description'] as String? ?? 'A moment from your day.';
      final aiObjects = List<String>.from(
        insights['detectedObjects'] ?? const <String>[],
      );
      final detectedObjects = <String>{
        ...localizedObjects.map((item) => item.name),
        ...aiObjects,
      }.toList();
      final locationHint = _normalizeLocationHint(
        insights['locationHint'] as String? ?? 'unknown',
      );
      final unusualObservation =
          insights['unusualObservation'] as String? ?? '';
      final concernLevel = insights['concernLevel'] as String? ?? 'none';

      final descriptionSuggestsPerson =
          description.toLowerCase().contains('person') ||
          description.toLowerCase().contains('face') ||
          description.toLowerCase().contains('you');
      final isPerson = hasFace || descriptionSuggestsPerson;
      final faceBoxes = _buildFaceBoxes(faces, imageSize);
      final objectBoxes = localizedObjects
          .map(
            (item) => VisionDetectionBox(
              label: item.name,
              left: item.left,
              top: item.top,
              width: item.width,
              height: item.height,
              category: 'object',
            ),
          )
          .toList();
      final safetyBoxes = _buildSafetyBoxes(
        faces: faceBoxes,
        objectBoxes: objectBoxes,
        unusualObservation: unusualObservation,
        concernLevel: concernLevel,
      );

      return VisionAnalysisResult(
        hasFace: hasFace,
        faceCount: faceCount,
        detectedType: isPerson ? 'person' : 'place',
        description: description,
        detectedObjects: detectedObjects,
        locationHint: locationHint,
        unusualObservation: unusualObservation,
        concernLevel: concernLevel,
        analysisTimestamp: DateTime.now(),
        detectionBoxes: [
          ...faceBoxes,
          ...objectBoxes,
          ...safetyBoxes,
        ],
      );
    } catch (e) {
      debugPrint('Vision Analysis Error: $e');
      return VisionAnalysisResult(
        hasFace: false,
        faceCount: 0,
        detectedType: 'unknown',
        description: "A moment from your day.",
        detectedObjects: const [],
        locationHint: 'unknown',
        unusualObservation: '',
        concernLevel: 'none',
        analysisTimestamp: DateTime.now(),
        detectionBoxes: const [],
      );
    }
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }

  String _normalizeLocationHint(String rawHint) {
    final value = rawHint.trim().toLowerCase();
    if (value.isEmpty) return 'unknown';

    const mappings = <String, String>{
      'bedroom': 'bedroom',
      'bedside': 'bedside table',
      'next to bed': 'bedside table',
      'bed side': 'bedside table',
      'nightstand': 'bedside table',
      'bed table': 'bedside table',
      'living room': 'living room',
      'lounge': 'living room',
      'sofa': 'sofa area',
      'couch': 'sofa area',
      'sofa area': 'sofa area',
      'kitchen': 'kitchen',
      'counter': 'kitchen counter',
      'kitchen counter': 'kitchen counter',
      'dining': 'dining table',
      'dining table': 'dining table',
      'bathroom': 'bathroom',
      'washroom': 'bathroom',
      'toilet': 'bathroom',
      'sink': 'bathroom sink',
      'wash basin': 'bathroom sink',
      'bathroom sink': 'bathroom sink',
      'entry': 'entryway',
      'door': 'entryway',
      'entryway': 'entryway',
      'entrance': 'entryway',
      'entry shelf': 'entry shelf',
      'hall': 'hallway',
      'hallway': 'hallway',
      'corridor': 'hallway',
      'desk': 'study desk',
      'study': 'study desk',
      'study desk': 'study desk',
      'unknown': 'unknown',
    };

    for (final entry in mappings.entries) {
      if (value.contains(entry.key)) {
        return entry.value;
      }
    }
    return value;
  }

  Future<ui.Size> _readImageSize(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
  }

  List<VisionDetectionBox> _buildFaceBoxes(
    List<Face> faces,
    ui.Size imageSize,
  ) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return const [];
    }
    return faces
        .map(
          (face) => VisionDetectionBox(
            label: 'person',
            left: (face.boundingBox.left / imageSize.width).clamp(0.0, 1.0),
            top: (face.boundingBox.top / imageSize.height).clamp(0.0, 1.0),
            width:
                (face.boundingBox.width / imageSize.width).clamp(0.0, 1.0),
            height:
                (face.boundingBox.height / imageSize.height).clamp(0.0, 1.0),
            category: 'person',
          ),
        )
        .toList();
  }

  List<VisionDetectionBox> _buildSafetyBoxes({
    required List<VisionDetectionBox> faces,
    required List<VisionDetectionBox> objectBoxes,
    required String unusualObservation,
    required String concernLevel,
  }) {
    if (concernLevel != 'high' && concernLevel != 'medium') {
      return const [];
    }
    final note = unusualObservation.toLowerCase();
    final looksLikeFall =
        note.contains('fall') ||
        note.contains('collapse') ||
        note.contains('lying on the floor') ||
        note.contains('slumped');
    final looksRisky =
        note.contains('risk') ||
        note.contains('spill') ||
        note.contains('clutter') ||
        note.contains('sharp') ||
        note.contains('blocked');

    VisionDetectionBox? anchor;
    if (faces.isNotEmpty) {
      anchor = faces.first;
    } else if (objectBoxes.isNotEmpty) {
      anchor = objectBoxes.first;
    }
    if (anchor == null) return const [];

    return [
      VisionDetectionBox(
        label: looksLikeFall
            ? 'possible fall'
            : looksRisky
            ? 'safety review'
            : 'attention',
        left: anchor.left,
        top: anchor.top,
        width: anchor.width,
        height: anchor.height,
        category: 'safety',
      ),
    ];
  }
}
