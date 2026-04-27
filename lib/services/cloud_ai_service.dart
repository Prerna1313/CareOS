import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../models/my_day/daily_checkin_entry.dart';
import '../models/memory_item.dart';

class CloudAIService {
  // Use Gemini 2.5 Flash for the app's fast multimodal tasks.
  // Deeper confusion assessment now uses a dedicated Gemini 2.5 Pro service.
  late GenerativeModel _textModel;
  late GenerativeModel _visionModel;

  CloudAIService() {
    final ai = FirebaseAI.vertexAI();
    _textModel = ai.generativeModel(model: 'gemini-2.5-flash');
    _visionModel = ai.generativeModel(model: 'gemini-2.5-flash');
  }

  /// Generates an empathetic summary of the patient's daily check-in
  Future<String> generateDailySummary(DailyCheckinEntry entry) async {
    final prompt =
        """
      You are an empathetic caregiver assistant for an elderly person with Alzheimer's.
      Based on their daily check-in responses, write a short, warm, and encouraging summary of their day (2-3 sentences).
      Focus on positive highlights and offer comfort if they felt tired or confused.
      
      Responses:
      ${entry.answers.map((a) => "${a.question}: ${a.answer}").join('\n')}

      Additional Written Notes:
      Diary note 1: ${entry.textField1.isNotEmpty ? entry.textField1 : 'No extra note.'}
      Diary note 2: ${entry.textField2.isNotEmpty ? entry.textField2 : 'No second note.'}
      
      Additional Voice Diary Entry:
      ${entry.voiceNote?.transcription ?? 'No voice note recorded.'}
      
      Summary:
    """;

    try {
      final response = await _textModel.generateContent([Content.text(prompt)]);
      return response.text ??
          "You had a reflective day. I'm here for you tomorrow.";
    } catch (e) {
      debugPrint('AI Summary Error: $e');
      return "It was good to hear from you today. Rest well!";
    }
  }

  /// Evaluates a patient's recognition response using semantic understanding
  Future<bool> evaluateRecognitionResponse({
    required String responseText,
    required MemoryItem memoryItem,
  }) async {
    final prompt =
        """
      Identify if the patient's response correctly identifies the memory item.
      The patient might use natural language, nicknames, or descriptions.
      
      Memory Item Name: ${memoryItem.name}
      Memory Note: ${memoryItem.note ?? 'N/A'}
      Patient Response: "$responseText"
      
      Return only the word 'true' if the response is conceptually correct, otherwise 'false'.
    """;

    try {
      final response = await _textModel.generateContent([Content.text(prompt)]);
      return response.text?.toLowerCase().contains('true') ?? false;
    } catch (e) {
      debugPrint('AI Evaluation Error: $e');
      // Fallback to simple matching if AI fails
      return responseText.toLowerCase().contains(memoryItem.name.toLowerCase());
    }
  }

  /// Analyzes an image to provide context-aware insights for the patient
  Future<String> analyzeImage(String localPath) async {
    final insights = await analyzeImageInsights(localPath);
    return insights['description'] as String? ?? "A beautiful moment captured.";
  }

  Future<Map<String, dynamic>> analyzeImageInsights(String localPath) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();

      final prompt = TextPart("""
Look at this photo and return only JSON with this exact schema:
{
  "description": "short reassuring description",
  "detectedObjects": ["object1", "object2"],
  "locationHint": "one short canonical place label such as bedroom, bedside table, living room, sofa area, kitchen, kitchen counter, dining table, bathroom, bathroom sink, entryway, entry shelf, hallway, study desk, or unknown",
  "unusualObservation": "short note if something may need attention, otherwise empty string",
  "concernLevel": "none|low|medium|high"
}

Rules:
- Keep description short and reassuring.
- Include common personal items if visible, like diary, specs, keys, medicine, water bottle, phone, bag, shoes.
- Prefer one stable place label from this set when possible:
  bedroom, bedside table, living room, sofa area, kitchen, kitchen counter, dining table, bathroom, bathroom sink, entryway, entry shelf, hallway, study desk, unknown.
- Do not invent many variations for the same place. For example:
  "next to bed" -> "bedside table"
  "couch" -> "sofa area"
  "door area" -> "entryway"
  "wash basin" -> "bathroom sink"
- If the scene may suggest a fall, collapse, lying on the floor, unstable posture, clutter risk, sharp-object risk, or spill/slip risk, mention it briefly in unusualObservation.
- If no clear location is visible, use "unknown".
- If nothing unusual is visible, use an empty string for unusualObservation and "none" for concernLevel.
- Return JSON only.
""");
      final imagePart = InlineDataPart('image/jpeg', bytes);

      final response = await _visionModel.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final rawText = response.text?.trim() ?? '';
      final cleaned = _extractJsonBlock(rawText);
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return {
        'description':
            parsed['description']?.toString().trim().isNotEmpty == true
            ? parsed['description'].toString().trim()
            : 'A beautiful moment captured.',
        'detectedObjects':
            List<String>.from(parsed['detectedObjects'] ?? const [])
                .map((item) => item.trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList(),
        'locationHint':
            parsed['locationHint']?.toString().trim().isNotEmpty == true
            ? parsed['locationHint'].toString().trim()
            : 'unknown',
        'unusualObservation':
            parsed['unusualObservation']?.toString().trim() ?? '',
        'concernLevel': _normalizeConcernLevel(
          parsed['concernLevel']?.toString(),
        ),
      };
    } catch (e) {
      debugPrint('AI Vision Error: $e');
      return {
        'description': 'I see a friendly moment here.',
        'detectedObjects': const <String>[],
        'locationHint': 'unknown',
        'unusualObservation': '',
        'concernLevel': 'none',
      };
    }
  }

  /// Transcribes audio from a local file using Gemini
  Future<String> transcribeAudio(String localPath) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return "";

      final bytes = await file.readAsBytes();

      // Determine mime type based on extension
      final extension = localPath.split('.').last.toLowerCase();
      final mimeType = extension == 'wav' ? 'audio/wav' : 'audio/m4a';

      final prompt = TextPart(
        "Transcribe this audio response accurately. If there is no clear speech, return an empty string. Only return the transcribed text.",
      );
      final audioPart = InlineDataPart(mimeType, bytes);

      final response = await _textModel.generateContent([
        Content.multi([prompt, audioPart]),
      ]);

      return response.text?.trim() ?? "";
    } catch (e) {
      debugPrint('AI Transcription Error: $e');
      return "";
    }
  }

  String _extractJsonBlock(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }

  String _normalizeConcernLevel(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'high':
        return 'high';
      case 'medium':
        return 'medium';
      case 'low':
        return 'low';
      default:
        return 'none';
    }
  }
}
