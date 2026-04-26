import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/patient/backend_processing_models.dart';

class BackendProcessingService {
  static const String _baseUrl = String.fromEnvironment(
    'CAREOS_BACKEND_BASE_URL',
    defaultValue: '',
  );

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  Uri _uri(String path) => Uri.parse('${_baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<BackendSpeechProcessingResult?> processSpeechAudio({
    required String patientId,
    required String source,
    required String audioPath,
    String languageCode = 'en-US',
  }) async {
    if (!isConfigured) return null;

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) return null;

    final request = http.MultipartRequest(
      'POST',
      _uri('/api/speech/transcribe'),
    )
      ..fields['patientId'] = patientId
      ..fields['source'] = source
      ..fields['languageCode'] = languageCode
      ..files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          filename: audioFile.uri.pathSegments.isNotEmpty
              ? audioFile.uri.pathSegments.last
              : 'voice.m4a',
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend speech processing failed (${response.statusCode}): $body',
      );
    }

    return BackendSpeechProcessingResult.fromMap(
      jsonDecode(body) as Map<String, dynamic>,
    );
  }

  Future<BackendVideoProcessingResult?> processObservationClip({
    required String patientId,
    required String clipId,
    required String clipPath,
    required String sourceEventId,
    required String triggerReason,
  }) async {
    if (!isConfigured) return null;

    final clipFile = File(clipPath);
    if (!await clipFile.exists()) return null;

    final request = http.MultipartRequest(
      'POST',
      _uri('/api/video/analyze'),
    )
      ..fields['patientId'] = patientId
      ..fields['clipId'] = clipId
      ..fields['sourceEventId'] = sourceEventId
      ..fields['triggerReason'] = triggerReason
      ..files.add(
        await http.MultipartFile.fromPath(
          'clip',
          clipPath,
          filename: clipFile.uri.pathSegments.isNotEmpty
              ? clipFile.uri.pathSegments.last
              : 'observation.mp4',
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend video processing failed (${response.statusCode}): $body',
      );
    }

    return BackendVideoProcessingResult.fromMap(
      jsonDecode(body) as Map<String, dynamic>,
    );
  }

  Future<bool> ping() async {
    if (!isConfigured) return false;
    final response = await http.get(_uri('/health'));
    return response.statusCode == 200;
  }
}
