import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/memory_item.dart';
import '../../../models/recognition/recognition_task.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/recognition_provider.dart';
import '../recognition/recognition_activity_screen.dart';

import 'package:audioplayers/audioplayers.dart';

class MemoryDetailScreen extends StatefulWidget {
  final MemoryItem item;

  const MemoryDetailScreen({super.key, required this.item});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback(String path) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() => _isPlaying = true);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  Widget _buildImage(MemoryItem item) {
    final String? displayPath = item.localImagePath ?? item.remoteImageUrl;

    if (displayPath == null) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Icon(
          Icons.image_not_supported_rounded,
          size: 64,
          color: AppColors.onSurfaceVariant,
        ),
      );
    }

    return Container(
      height: 400,
      margin: const EdgeInsets.all(24),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: _renderImage(item),
      ),
    );
  }

  Widget _renderImage(MemoryItem item) {
    // If we have a local path and it exists, prefer it
    if (!kIsWeb && item.localImagePath != null) {
      final file = File(item.localImagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    // Fallback to remote URL
    if (item.remoteImageUrl != null) {
      return Image.network(
        item.remoteImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }

    return _buildImageError();
  }

  Widget _buildImageError() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: AppColors.onSurfaceVariant,
          ),
          SizedBox(height: 12),
          Text(
            'Image not available',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStatus(BuildContext context, MemoryItem item) {
    IconData icon;
    Color color;
    String label;

    switch (item.uploadStatus) {
      case UploadStatus.uploading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UploadStatus.failed:
        icon = Icons.error_outline_rounded;
        color = AppColors.error;
        label = 'Upload Failed';
        break;
      case UploadStatus.localOnly:
        icon = Icons.cloud_off_rounded;
        color = AppColors.onSurfaceVariant;
        label = 'Local Only';
        break;
      case UploadStatus.uploaded:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        if (item.uploadStatus == UploadStatus.failed) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: () =>
                context.read<MemoryProvider>().retryUpload(item.id),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final textTheme = Theme.of(context).textTheme;
    final recognitionProvider = context.watch<RecognitionProvider>();
    final RecognitionTask? recognitionTask = recognitionProvider.todayTasks
        .cast<RecognitionTask?>()
        .firstWhere(
          (task) => task?.memoryItemId == item.id,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Memory Details',
          style: textTheme.titleLarge?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            _buildImage(item),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(
                            item.type,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.type.name.toUpperCase(),
                          style: textTheme.labelLarge?.copyWith(
                            color: _getTypeColor(item.type),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      // Upload Status Badge
                      if (item.uploadStatus != UploadStatus.uploaded &&
                          (item.localImagePath != null ||
                              item.remoteImageUrl != null))
                        _buildUploadStatus(context, item),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    item.name,
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date
                  Text(
                    DateFormat('MMMM d, yyyy • h:mm a').format(item.createdAt),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _MemoryOverviewCard(item: item),

                  if (recognitionTask != null) ...[
                    const SizedBox(height: 24),
                    _RecognitionActionCard(task: recognitionTask),
                  ],

                  // Note
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    Text(
                      'The Story',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        item.note!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurface,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],

                  // Voice Caption Section
                  if (item.voiceNotePath != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Voice Caption',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.1),
                            AppColors.surfaceContainerLow,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton.filled(
                            onPressed: () =>
                                _togglePlayback(item.voiceNotePath!),
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 32,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.onSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Listen to the story',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Hear a loved one\'s voice',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tags
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  AppColors.surfaceContainerHighest,
                              labelStyle: textTheme.labelMedium,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(MemoryType type) {
    switch (type) {
      case MemoryType.person:
        return AppColors.secondary;
      case MemoryType.place:
        return AppColors.primary;
      case MemoryType.event:
        return AppColors.tertiary;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete Memory?'),
        content: const Text(
          'This memory will be permanently removed from your story.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () {
              context.read<MemoryProvider>().deleteMemory(widget.item.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to timeline
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MemoryOverviewCard extends StatelessWidget {
  final MemoryItem item;

  const _MemoryOverviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final overviewRows = <({IconData icon, String label, String value})>[
      (
        icon: Icons.category_rounded,
        label: 'Type',
        value: item.type.name[0].toUpperCase() + item.type.name.substring(1),
      ),
      if (item.location != null && item.location!.isNotEmpty)
        (icon: Icons.place_rounded, label: 'Place', value: item.location!),
      if (item.summary != null && item.summary!.isNotEmpty)
        (
          icon: Icons.auto_awesome_rounded,
          label: 'Summary',
          value: item.summary!,
        ),
      if (item.confidence != null)
        (
          icon: Icons.verified_rounded,
          label: 'Confidence',
          value: '${(item.confidence! * 100).round()}%',
        ),
    ];

    if (overviewRows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memory Overview',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...overviewRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    '${row.label}: ',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecognitionActionCard extends StatelessWidget {
  final RecognitionTask task;

  const _RecognitionActionCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.25),
            AppColors.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice This Memory',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.questionText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecognitionActivityScreen(task: task),
                ),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
