import 'package:flutter_tts/flutter_tts.dart';

class VoiceOrientationService {
  static final VoiceOrientationService _instance = VoiceOrientationService._internal();
  factory VoiceOrientationService() => _instance;
  VoiceOrientationService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.4); // Calm, slow pace for elderly patients
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await _ensureInitialized();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  /// Provides a full orientation phrase based on time and location
  String getOrientationPhrase({
    required String name,
    required String timeOfDay,
    required String location,
    required String dateStr,
  }) {
    return "Hi $name. It is $timeOfDay on $dateStr. You are safe at home in $location.";
  }
}
