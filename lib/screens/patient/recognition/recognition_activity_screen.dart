import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../theme/app_colors.dart';
import '../../../models/recognition/recognition_task.dart';
import '../../../models/memory_item.dart';
import '../../../providers/recognition_provider.dart';
import '../../../providers/memory_provider.dart';
import '../../../services/voice_orientation_service.dart';
import '../../../services/cloud_ai_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class RecognitionActivityScreen extends StatefulWidget {
  final RecognitionTask task;

  const RecognitionActivityScreen({super.key, required this.task});

  @override
  State<RecognitionActivityScreen> createState() => _RecognitionActivityScreenState();
}

class _RecognitionActivityScreenState extends State<RecognitionActivityScreen> {
  final TextEditingController _controller = TextEditingController();
  final DateTime _startTime = DateTime.now();
  bool _isSubmitting = false;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    // Speak the question after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      VoiceOrientationService().speak("Let's remember together. ${widget.task.questionText}");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      
      if (_audioPath != null) {
        _processAudio(_audioPath!);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'recognition_${DateTime.now().millisecondsSinceEpoch}.m4a');
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });
      }
    }
  }

  Future<void> _processAudio(String path) async {
    setState(() => _isSubmitting = true);
    try {
      final transcription = await CloudAIService().transcribeAudio(path);
      if (transcription.isNotEmpty) {
        _controller.text = transcription;
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit(bool isSkipped) async {
    setState(() => _isSubmitting = true);
    
    final memoryItem = context.read<MemoryProvider>().memories.firstWhere((m) => m.id == widget.task.memoryItemId);
    final responseTime = DateTime.now().difference(_startTime).inSeconds;

    await context.read<RecognitionProvider>().submitResponse(
      task: widget.task,
      responseText: _controller.text,
      isSkipped: isSkipped,
      responseTimeSeconds: responseTime,
      memoryItem: memoryItem,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wonderful effort. We'll remember more together later."),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final memoryProvider = context.watch<MemoryProvider>();
    final MemoryItem? memoryItem = memoryProvider.memories.cast<MemoryItem?>().firstWhere(
      (m) => m?.id == widget.task.memoryItemId,
      orElse: () => null,
    );

    if (memoryItem == null) {
      return const Scaffold(body: Center(child: Text("Memory not found")));
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Memory Moment", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Memory Image
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildImage(memoryItem),
            ),
            const SizedBox(height: 32),
            
            // Question
            Text(
              widget.task.questionText,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Take your time. There's no rush.",
              style: textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // Input Field
            TextField(
              controller: _controller,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "Type your answer here...",
                hintStyle: textTheme.headlineSmall?.copyWith(color: AppColors.outlineVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primaryContainer),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                      color: _isRecording ? Colors.red : AppColors.primary,
                      size: 32,
                    ),
                    onPressed: _isSubmitting ? null : _toggleRecording,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(false),
            ),
            const SizedBox(height: 40),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _submit(true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Skip for now"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : () => _submit(false),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isSubmitting 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("I Remember"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(MemoryItem item) {
    if (!kIsWeb && item.localImagePath != null) {
      final file = File(item.localImagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    if (item.remoteImageUrl != null) {
      return Image.network(item.remoteImageUrl!, fit: BoxFit.cover);
    }
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Icon(Icons.image_rounded, size: 64, color: AppColors.outlineVariant),
    );
  }
}
