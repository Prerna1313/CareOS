import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'cloud_ai_service.dart';

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
  });
}

class VisionService {
  final CloudAIService _aiService;
  final FaceDetector _faceDetector;

  VisionService(this._aiService)
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

      final insights = await _aiService.analyzeImageInsights(imagePath);
      final description =
          insights['description'] as String? ?? 'A moment from your day.';
      final detectedObjects = List<String>.from(
        insights['detectedObjects'] ?? const <String>[],
      );
      final locationHint = insights['locationHint'] as String? ?? 'unknown';
      final unusualObservation =
          insights['unusualObservation'] as String? ?? '';
      final concernLevel = insights['concernLevel'] as String? ?? 'none';

      final descriptionSuggestsPerson =
          description.toLowerCase().contains('person') ||
          description.toLowerCase().contains('face') ||
          description.toLowerCase().contains('you');
      final isPerson = hasFace || descriptionSuggestsPerson;

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
      );
    }
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}
