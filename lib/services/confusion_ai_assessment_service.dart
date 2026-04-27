import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../models/confusion_detection_result.dart';
import '../models/confusion_state.dart';
import '../models/reminder_log.dart';

class ConfusionAiAssessmentService {
  late final GenerativeModel _model;

  ConfusionAiAssessmentService()
    : _model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-pro',
      );

  Future<ConfusionDetectionResult?> assessReminderPattern({
    required String patientId,
    required String patientName,
    required List<ReminderLog> logs,
    required ConfusionState localState,
  }) async {
    if (logs.isEmpty) {
      return null;
    }

    final recentLogs = logs.take(7).map(_serializeLog).toList();
    final localReasons = localState.reasons.isEmpty
        ? 'No strong local reasons yet.'
        : localState.reasons.join(' | ');

    final prompt = '''
You are a clinical-style cognitive support assistant for an Alzheimer's care app.
Review the recent reminder-response behavior and produce only JSON with this exact schema:
{
  "score": 0,
  "riskLevel": "stable|mild|moderate|high",
  "detectedSignals": ["signal_a", "signal_b"],
  "explanation": "one short caregiver-friendly explanation",
  "memoryCueNeeded": true
}

Rules:
- Score must be a number between 0 and 100.
- Use "high" only for strong evidence of confusion or repeated failure.
- Use "moderate" for meaningful concern that should likely notify a caregiver.
- Use "mild" for light concern.
- Use "stable" when behavior seems okay.
- Keep explanation under 35 words.
- detectedSignals should be short snake_case phrases.
- memoryCueNeeded should be true only when orientation or recall support would help.

Patient name: $patientName
Patient id: $patientId

Current local confusion state:
- level: ${localState.level.name}
- score: ${localState.score}
- reasons: $localReasons

Recent reminder interaction logs (latest first):
${jsonEncode(recentLogs)}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final rawText = response.text?.trim() ?? '';
      final parsed = jsonDecode(_extractJsonBlock(rawText)) as Map<String, dynamic>;

      final rawScore = (parsed['score'] as num?)?.toDouble() ?? 0.0;
      final score = rawScore.clamp(0.0, 100.0).toDouble();
      final riskValue = (parsed['riskLevel'] as String?)?.trim().toLowerCase();
      final riskLevel = switch (riskValue) {
        'high' => ConfusionRiskLevel.high,
        'moderate' => ConfusionRiskLevel.moderate,
        'mild' => ConfusionRiskLevel.mild,
        _ => ConfusionRiskLevel.stable,
      };

      return ConfusionDetectionResult(
        patientId: patientId,
        score: score,
        riskLevel: riskLevel,
        detectedSignals:
            (parsed['detectedSignals'] as List? ?? const [])
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(),
        explanation: (parsed['explanation'] as String?)?.trim().isNotEmpty == true
            ? (parsed['explanation'] as String).trim()
            : 'Recent reminder behavior suggests additional caregiver attention may help.',
        memoryCueNeeded: parsed['memoryCueNeeded'] as bool? ?? false,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Confusion AI assessment failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _serializeLog(ReminderLog log) {
    final responseDelayMinutes =
        log.actualResponseTime.difference(log.scheduledTime).inMinutes;
    return {
      'timestamp': log.timestamp.toIso8601String(),
      'actionTaken': log.actionTaken.name,
      'reminderType': log.reminderType.name,
      'responseDelayMinutes': responseDelayMinutes,
      'scheduledTime': log.scheduledTime.toIso8601String(),
    };
  }

  String _extractJsonBlock(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }
}
