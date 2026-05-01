import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/memory_item.dart';
import '../../../models/memory_cue.dart';
import '../../../models/my_day/daily_checkin_entry.dart';
import '../../../repositories/memory_cue_repository.dart';
import '../../../services/caregiver_voice_note_service.dart';
import '../../../services/daily_checkin_service.dart';
import '../../../services/memory_service.dart';
import '../../../services/patient_records_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/empty_state.dart';

class MemoryCueManagementScreen extends StatefulWidget {
  const MemoryCueManagementScreen({super.key});

  @override
  State<MemoryCueManagementScreen> createState() => _MemoryCueManagementScreenState();
}

class _MemoryCueManagementScreenState extends State<MemoryCueManagementScreen> {
  final _repository = MemoryCueRepository();
  final _uuid = const Uuid();
  final _voiceNoteService = CaregiverVoiceNoteService();
  final _memoryService = MemoryService();
  final _audioPlayer = AudioPlayer();
  CaregiverSession? _session;
  bool _isLoading = true;
  List<MemoryCue> _cues = [];
  List<DailyCheckinEntry> _recentEntries = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _voiceNoteService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CaregiverSessionScope.of(context);
    if (_session?.patientId == session.patientId) {
      return;
    }
    _session = session;
    _loadCues();
  }

  Future<void> _loadCues() async {
    final session = _session ?? CaregiverSession.fallback();
    final dailyCheckinService = context.read<DailyCheckinService>();
    setState(() => _isLoading = true);
    final cues = await _repository.getAll(session.patientId);
    final entries = dailyCheckinService.getAllEntries().take(3).toList();
    if (mounted) {
      setState(() {
        _cues = cues;
        _recentEntries = entries;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Memory Cues'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cues.isEmpty
              ? EmptyState(
                  title: 'No Memory Cues',
                  message:
                      'Add photos, places, and events to help orient ${(_session ?? CaregiverSession.fallback()).patientName} when confused.',
                  icon: Icons.photo_library_outlined,
                  actionLabel: 'Add First Cue',
                  onAction: _showAddCueDialog,
                )
              : RefreshIndicator(
                  onRefresh: _loadCues,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDiaryReviewCard(),
                      const SizedBox(height: 16),
                      ..._cues.map(_buildCueCard),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCueDialog,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCueCard(MemoryCue cue) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.tertiaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Icon(
                _getIconForType(cue.type),
                size: 48,
                color: AppColors.tertiaryColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cue.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (cue.priority == MemoryCuePriority.high)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HIGH PRIORITY',
                          style: TextStyle(fontSize: 10, color: AppColors.errorColor, fontWeight: FontWeight.bold),
                        ),
                      )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  cue.caption ?? 'No caption',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                if (cue.voiceNotePath != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.mic,
                        size: 18,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cue.voiceNoteDurationSeconds != null
                            ? 'Voice note • ${cue.voiceNoteDurationSeconds}s'
                            : 'Voice note attached',
                        style: const TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _playVoiceNote(cue.voiceNotePath!),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCueDialog(existing: cue),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pushCueToPatient(cue),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Push to Patient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Delete cue',
                      onPressed: () => _deleteCue(cue),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDiaryReviewCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diary & Memory Review',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _recentEntries.isEmpty
                  ? 'No patient diary entries have been saved yet.'
                  : 'Recent diary notes and check-ins are available below for caregiver review.',
              style: TextStyle(color: Colors.grey[700], height: 1.35),
            ),
            const SizedBox(height: 12),
            if (_recentEntries.isEmpty)
              Text(
                'Uploaded photos and saved patient memories will still appear as memory cues.',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ..._recentEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.date.day}/${entry.date.month}/${entry.date.year} • ${entry.mood}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.summary.isNotEmpty
                              ? entry.summary
                              : (entry.textField1.isNotEmpty
                                    ? entry.textField1
                                    : entry.textField2.isNotEmpty
                                    ? entry.textField2
                                    : 'Diary entry saved without additional written notes.'),
                          style: TextStyle(color: Colors.grey[800], height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(MemoryCueType type) {
    switch (type) {
      case MemoryCueType.family: return Icons.people;
      case MemoryCueType.place: return Icons.place;
      case MemoryCueType.event: return Icons.event;
      case MemoryCueType.medicine: return Icons.medication;
      case MemoryCueType.routine: return Icons.schedule_rounded;
      case MemoryCueType.custom: return Icons.star;
    }
  }

  void _showAddCueDialog() => _showCueDialog();

  Future<void> _pushCueToPatient(MemoryCue cue) async {
    final session = _session ?? CaregiverSession.fallback();
    final recordsService = context.read<PatientRecordsService>();
    await _syncCueToPatientMemory(cue);
    await recordsService.logIntervention(
      patientId: session.patientId,
      triggerType: 'caregiver_memory_cue',
      interventionType: 'memory_cue_push',
      outcome: 'requested',
      notes: 'Caregiver pushed memory cue "${cue.title}" to the patient support flow.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Memory cue "${cue.title}" prepared for ${session.patientName}.'),
      ),
    );
  }

  Future<void> _deleteCue(MemoryCue cue) async {
    await _repository.delete(cue.id);
    if (cue.id.startsWith('memory_')) {
      await _memoryService.deleteMemory(cue.id.replaceFirst('memory_', ''));
    }
    await _loadCues();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed memory cue "${cue.title}".')),
    );
  }

  Future<void> _showCueDialog({MemoryCue? existing}) async {
    final session = _session ?? CaregiverSession.fallback();
    final titleController = TextEditingController(text: existing?.title ?? '');
    final captionController = TextEditingController(
      text: existing?.caption ?? '',
    );
    final tagsController = TextEditingController(
      text: existing?.tags.join(', ') ?? '',
    );
    var selectedType = existing?.type ?? MemoryCueType.family;
    var selectedPriority = existing?.priority ?? MemoryCuePriority.normal;
    var voiceNotePath = existing?.voiceNotePath;
    var voiceNoteDuration = existing?.voiceNoteDurationSeconds;
    var isRecordingVoiceNote = false;
    DateTime? recordingStartedAt;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Add Memory Cue' : 'Edit Memory Cue',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Cue title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: captionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Caption or caregiver note',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MemoryCueType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Cue type'),
                    items: MemoryCueType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MemoryCuePriority>(
                    initialValue: selectedPriority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: MemoryCuePriority.values
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedPriority = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Optional voice note',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          voiceNotePath != null
                              ? 'Voice note ready${voiceNoteDuration != null ? ' • ${voiceNoteDuration}s' : ''}'
                              : 'Record a familiar spoken cue for the patient.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (isRecordingVoiceNote) {
                                  final stoppedPath = await _voiceNoteService.stopRecording();
                                  if (stoppedPath != null) {
                                    final seconds = recordingStartedAt == null
                                        ? null
                                        : DateTime.now()
                                            .difference(recordingStartedAt!)
                                            .inSeconds;
                                    setModalState(() {
                                      voiceNotePath = stoppedPath;
                                      voiceNoteDuration = seconds;
                                      isRecordingVoiceNote = false;
                                    });
                                  }
                                } else {
                                  final startedPath = await _voiceNoteService.startRecording();
                                  if (startedPath != null) {
                                    recordingStartedAt = DateTime.now();
                                    setModalState(() {
                                      isRecordingVoiceNote = true;
                                      voiceNotePath = startedPath;
                                    });
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRecordingVoiceNote
                                    ? AppColors.errorColor
                                    : AppColors.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(
                                isRecordingVoiceNote ? Icons.stop : Icons.mic,
                              ),
                              label: Text(
                                isRecordingVoiceNote ? 'Stop Recording' : 'Record Voice Note',
                              ),
                            ),
                            if (voiceNotePath != null && !isRecordingVoiceNote)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await _playVoiceNote(voiceNotePath!);
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play'),
                              ),
                            if (voiceNotePath != null && !isRecordingVoiceNote)
                              TextButton.icon(
                                onPressed: () async {
                                  await _voiceNoteService.deleteRecording(voiceNotePath);
                                  setModalState(() {
                                    voiceNotePath = null;
                                    voiceNoteDuration = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }

                        final cue = MemoryCue(
                          id: existing?.id ?? _uuid.v4(),
                          patientId: session.patientId,
                          type: selectedType,
                          priority: selectedPriority,
                          title: title,
                          caption: captionController.text.trim().isEmpty
                              ? null
                              : captionController.text.trim(),
                          tags: tagsController.text
                              .split(',')
                              .map((tag) => tag.trim())
                              .where((tag) => tag.isNotEmpty)
                              .toList(),
                          mediaUrl: existing?.mediaUrl,
                          voiceNotePath: voiceNotePath,
                          voiceNoteDurationSeconds: voiceNoteDuration,
                          voiceNoteTranscription: existing?.voiceNoteTranscription,
                        );

                        if (existing == null) {
                          await _repository.create(cue);
                        } else {
                          await _repository.update(cue);
                        }
                        await _syncCueToPatientMemory(cue);
                        if (mounted) {
                          Navigator.of(this.context).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(existing == null ? 'Save Cue' : 'Update Cue'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved == true) {
      await _loadCues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Memory cue saved for ${session.patientName}.'),
          ),
        );
      }
    }
  }

  Future<void> _playVoiceNote(String path) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
  }

  Future<void> _syncCueToPatientMemory(MemoryCue cue) async {
    final memoryId = cue.id.startsWith('memory_')
        ? cue.id.replaceFirst('memory_', '')
        : 'cue_${cue.id}';
    final existingMemory = _memoryService.getMemoryById(memoryId);
    final memory = MemoryItem(
      id: memoryId,
      patientId: cue.patientId,
      type: switch (cue.type) {
        MemoryCueType.family => MemoryType.person,
        MemoryCueType.place => MemoryType.place,
        _ => MemoryType.event,
      },
      name: cue.title,
      note: cue.caption,
      localImagePath: cue.mediaUrl,
      remoteImageUrl: cue.mediaUrl,
      uploadStatus: cue.mediaUrl != null
          ? UploadStatus.uploaded
          : UploadStatus.localOnly,
      createdAt: existingMemory?.createdAt ?? DateTime.now(),
      voiceNotePath: cue.voiceNotePath,
      tags: cue.tags,
      summary: cue.caption,
    );
    if (existingMemory == null) {
      await _memoryService.addMemory(memory);
    } else {
      await _memoryService.updateMemory(memory);
    }
  }
}
