import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class CloudVisionLocalizedObject {
  final String name;
  final double left;
  final double top;
  final double width;
  final double height;

  const CloudVisionLocalizedObject({
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class CloudVisionService {
  static const String _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  Future<List<String>> localizeObjects(String imagePath) async {
    final detections = await localizeObjectDetections(imagePath);
    return detections.map((item) => item.name).toSet().toList();
  }

  Future<List<CloudVisionLocalizedObject>> localizeObjectDetections(
    String imagePath,
  ) async {
    final apiKey = _visionApiKey;
    if (apiKey.isEmpty || apiKey == 'placeholder_key') {
      debugPrint(
        'Cloud Vision API key missing. Skipping object localization for $imagePath.',
      );
      return const <CloudVisionLocalizedObject>[];
    }

    try {
      final file = File(imagePath);
      if (!file.existsSync()) return const <CloudVisionLocalizedObject>[];

      final bytes = await file.readAsBytes();
      final client = HttpClient();
      final uri = Uri.parse('$_endpoint?key=$apiKey');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'requests': [
            {
              'image': {'content': base64Encode(bytes)},
              'features': [
                {'type': 'OBJECT_LOCALIZATION', 'maxResults': 10},
              ],
            },
          ],
        }),
      );

      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Cloud Vision request failed: ${response.statusCode} $raw');
        return const <CloudVisionLocalizedObject>[];
      }

      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final responses = parsed['responses'] as List<dynamic>? ?? const [];
      if (responses.isEmpty) return const <CloudVisionLocalizedObject>[];
      final first = responses.first as Map<String, dynamic>;
      final objects =
          first['localizedObjectAnnotations'] as List<dynamic>? ?? const [];

      return objects
          .map((item) => item as Map<String, dynamic>)
          .map(_parseLocalizedObject)
          .whereType<CloudVisionLocalizedObject>()
          .where((item) => item.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Cloud Vision Object Localization Error: $e');
      return const <CloudVisionLocalizedObject>[];
    }
  }

  CloudVisionLocalizedObject? _parseLocalizedObject(Map<String, dynamic> map) {
    final name = (map['name'] as String? ?? '').trim().toLowerCase();
    final vertices =
        (map['boundingPoly']?['normalizedVertices'] as List<dynamic>? ??
                const [])
            .cast<Map<String, dynamic>>();
    if (name.isEmpty || vertices.isEmpty) return null;

    final xs = vertices
        .map((point) => (point['x'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final ys = vertices
        .map((point) => (point['y'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final left = xs.reduce((a, b) => a < b ? a : b).clamp(0.0, 1.0);
    final right = xs.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0);
    final top = ys.reduce((a, b) => a < b ? a : b).clamp(0.0, 1.0);
    final bottom = ys.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0);

    return CloudVisionLocalizedObject(
      name: name,
      left: left,
      top: top,
      width: (right - left).clamp(0.0, 1.0),
      height: (bottom - top).clamp(0.0, 1.0),
    );
  }

  String get _visionApiKey {
    const directKey = String.fromEnvironment('GOOGLE_CLOUD_VISION_API_KEY');
    if (directKey.isNotEmpty) return directKey;

    const webFallback = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const androidFallback = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const iosFallback = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    return [
      directKey,
      webFallback,
      androidFallback,
      iosFallback,
    ].firstWhere(
      (value) => value.isNotEmpty,
      orElse: () => '',
    );
  }
}
