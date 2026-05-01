import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../../../theme/app_colors.dart';
import '../../../providers/my_day_provider.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/recognition_provider.dart';
import '../../../models/my_day/daily_checkin_entry.dart';
import '../../../models/memory_item.dart';
import '../../../models/recognition/recognition_task.dart';
import '../../../widgets/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'memory_detail_screen.dart';
import '../recognition/recognition_activity_screen.dart';

const _memoryBackground = Color(0xFFEEF5FA);
const _memorySurface = Color(0xFFFFFDFB);
const _memoryMutedSurface = Color(0xFFE4EEF6);
const _memoryAccent = Color(0xFF5E84A1);
const _memoryAccentSoft = Color(0xFFD8E7F2);
const _memoryTextSoft = Color(0xFF607487);

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({super.key});

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  MemoryType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final myDayProvider = context.watch<MyDayProvider>();
    final memoryProvider = context.watch<MemoryProvider>();
    final recognitionProvider = context.watch<RecognitionProvider>();
    final todayEntry = myDayProvider.todayEntry;

    // Daily History (Daily check-ins)
    // Combine Daily entries and Manual memories
    final dailyHistory = myDayProvider.history.where((e) {
      final now = DateTime.now();
      // Use local date parts for comparison to avoid timezone shift issues
      return e.date.year != now.year ||
          e.date.month != now.month ||
          e.date.day != now.day;
    }).toList();

    // Manual Memories from Provider (Filtered/Searched)
    final List<MemoryItem> manualMemories = memoryProvider.memories;
    final allMemories = memoryProvider.memories;
    final peopleCount = allMemories
        .where((memory) => memory.type == MemoryType.person)
        .length;
    final placeCount = allMemories
        .where((memory) => memory.type == MemoryType.place)
        .length;
    final eventCount = allMemories
        .where((memory) => memory.type == MemoryType.event)
        .length;
    final RecognitionTask? quickTask = recognitionProvider.todayTasks.isNotEmpty
        ? recognitionProvider.todayTasks.first
        : null;
    final MemoryItem? quickTaskMemory = quickTask == null
        ? null
        : allMemories.cast<MemoryItem?>().firstWhere(
            (memory) => memory?.id == quickTask.memoryItemId,
            orElse: () => null,
          );

    return Scaffold(
      backgroundColor: _memoryBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memories',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revisit your beautiful moments.',
                      style: textTheme.titleMedium?.copyWith(
                        color: _memoryTextSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => memoryProvider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search memories...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: _memorySurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            // Filter Tabs
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _selectedFilter == null,
                      onTap: () {
                        setState(() => _selectedFilter = null);
                        memoryProvider.setFilterType(null);
                      },
                    ),
                    _FilterChip(
                      label: 'People',
                      isSelected: _selectedFilter == MemoryType.person,
                      onTap: () {
                        setState(() => _selectedFilter = MemoryType.person);
                        memoryProvider.setFilterType(MemoryType.person);
                      },
                    ),
                    _FilterChip(
                      label: 'Places',
                      isSelected: _selectedFilter == MemoryType.place,
                      onTap: () {
                        setState(() => _selectedFilter = MemoryType.place);
                        memoryProvider.setFilterType(MemoryType.place);
                      },
                    ),
                    _FilterChip(
                      label: 'Events',
                      isSelected: _selectedFilter == MemoryType.event,
                      onTap: () {
                        setState(() => _selectedFilter = MemoryType.event);
                        memoryProvider.setFilterType(MemoryType.event);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Record New Memory Action
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    _MemoryStatsCard(
                      textTheme: textTheme,
                      totalCount: allMemories.length,
                      peopleCount: peopleCount,
                      placeCount: placeCount,
                      eventCount: eventCount,
                    ),
                    const SizedBox(height: 16),
                    if (quickTask != null && quickTaskMemory != null) ...[
                      _RecognitionPromptCard(
                        textTheme: textTheme,
                        task: quickTask,
                        memoryItem: quickTaskMemory,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _RecordActionCard(
                      textTheme: textTheme,
                      onAddMemory: () =>
                          _showAddMemoryModal(context, textTheme),
                    ),
                  ],
                ),
              ),
            ),

            // If Filtered or Searching, show ONLY Manual Memories
            if (_searchController.text.isNotEmpty ||
                _selectedFilter != null) ...[
              if (manualMemories.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: Text('No matching memories found.')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ManualMemoryCard(
                          item: manualMemories[index],
                          textTheme: textTheme,
                        ),
                      ),
                      childCount: manualMemories.length,
                    ),
                  ),
                ),
            ] else ...[
              // Default View: Combined History (Today + Historical)

              // Today's Summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: _SummaryCard(entry: todayEntry, textTheme: textTheme),
                ),
              ),

              // Recent Memories Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Memory Timeline',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),

              // Combined List (Daily + Manual)
              _buildCombinedList(dailyHistory, manualMemories, textTheme),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedList(
    List<DailyCheckinEntry> daily,
    List<MemoryItem> manual,
    TextTheme textTheme,
  ) {
    // Combine and sort, but ensure we don't have null issues
    final List<dynamic> combined = [...daily, ...manual]
      ..sort((a, b) {
        DateTime dateA = a is DailyCheckinEntry
            ? a.date
            : (a as MemoryItem).createdAt;
        DateTime dateB = b is DailyCheckinEntry
            ? b.date
            : (b as MemoryItem).createdAt;
        // Normalize to local to avoid shift-based assertion issues in some Flutter versions
        return dateB.toLocal().compareTo(dateA.toLocal());
      });

    if (combined.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Center(child: Text('Your story begins here.')),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = combined[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: entry is DailyCheckinEntry
                ? _PastEntryCard(entry: entry, textTheme: textTheme)
                : _ManualMemoryCard(
                    item: entry as MemoryItem,
                    textTheme: textTheme,
                  ),
          );
        }, childCount: combined.length),
      ),
    );
  }

  void _showAddMemoryModal(BuildContext context, TextTheme textTheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMemoryModal(textTheme: textTheme),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: _memorySurface,
        selectedColor: _memoryAccentSoft,
        labelStyle: TextStyle(
          color: isSelected
              ? _memoryAccent
              : _memoryTextSoft,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MemoryStatsCard extends StatelessWidget {
  final TextTheme textTheme;
  final int totalCount;
  final int peopleCount;
  final int placeCount;
  final int eventCount;

  const _MemoryStatsCard({
    required this.textTheme,
    required this.totalCount,
    required this.peopleCount,
    required this.placeCount,
    required this.eventCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _memorySurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _memoryAccentSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Memory Library',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            totalCount == 0
                ? 'Start saving important people, places, and moments.'
                : 'You have saved $totalCount memories so far.',
            style: textTheme.bodyMedium?.copyWith(
              color: _memoryTextSoft,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MemoryStatTile(
                  label: 'People',
                  count: peopleCount,
                  icon: Icons.favorite_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MemoryStatTile(
                  label: 'Places',
                  count: placeCount,
                  icon: Icons.place_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MemoryStatTile(
                  label: 'Events',
                  count: eventCount,
                  icon: Icons.celebration_rounded,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryStatTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _MemoryStatTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecognitionPromptCard extends StatelessWidget {
  final TextTheme textTheme;
  final RecognitionTask task;
  final MemoryItem memoryItem;

  const _RecognitionPromptCard({
    required this.textTheme,
    required this.task,
    required this.memoryItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _memoryAccentSoft,
            const Color(0xFFF8FBFE),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memory Practice',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try a quick recognition moment for "${memoryItem.name}".',
                  style: textTheme.bodyMedium?.copyWith(
                    color: _memoryTextSoft,
                    height: 1.4,
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

class _AddMemoryModal extends StatefulWidget {
  final TextTheme textTheme;
  const _AddMemoryModal({required this.textTheme});

  @override
  State<_AddMemoryModal> createState() => _AddMemoryModalState();
}

class _AddMemoryModalState extends State<_AddMemoryModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  MemoryType _selectedType = MemoryType.person;
  String? _imagePath;
  String? _voicePath;
  bool _isRecording = false;
  final _recorder = AudioRecorder();
  final List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  bool _isPickingImage = false;

  @override
  void dispose() {
    _recorder.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickMemoryImage(ImageSource source) async {
    setState(() => _isPickingImage = true);
    try {
      final provider = context.read<MemoryProvider>();
      final file = await provider.pickImage(source);
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photo was selected.')),
        );
        return;
      }

      final localPath = await provider.saveImageLocally(file);
      if (!mounted) return;
      if (localPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The photo could not be prepared right now.'),
          ),
        );
        return;
      }

      setState(() => _imagePath = localPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Photo selected: ${p.basename(localPath).isEmpty ? 'memory image' : p.basename(localPath)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          _voicePath = path;
        });
      } else {
        if (await _recorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = p.join(
            dir.path,
            'memories',
            'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );

          // Ensure directory exists
          final memoriesDir = Directory(p.join(dir.path, 'memories'));
          if (!await memoriesDir.exists()) {
            await memoriesDir.create(recursive: true);
          }

          await _recorder.start(const RecordConfig(), path: path);
          setState(() {
            _isRecording = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Capture Memory',
                        style: widget.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Keep this moment forever',
                        style: widget.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Image Upload Placeholder (Redesigned)
            // Image Capture/Upload Section
            Row(
              children: [
                Expanded(
                  child: _ImageActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: _isPickingImage ? 'Loading...' : 'Camera',
                    onTap: _isPickingImage
                        ? () {}
                        : () => _pickMemoryImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageActionButton(
                    icon: Icons.photo_library_rounded,
                    label: _isPickingImage ? 'Loading...' : 'Gallery',
                    onTap: _isPickingImage
                        ? () {}
                        : () => _pickMemoryImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Image Preview (Redesigned)
            if (_imagePath != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Photo selected successfully',
                                style: widget.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.basename(_imagePath!),
                                style: widget.textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: kIsWeb
                                ? Image.network(_imagePath!, fit: BoxFit.cover)
                                : (File(_imagePath!).existsSync()
                                      ? Image.file(
                                          File(_imagePath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: AppColors.surfaceContainerHigh,
                                        )),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_imagePath != null) const SizedBox(height: 24),
            const SizedBox(height: 24),

            Text('This is a:', style: widget.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: MemoryType.values.map((type) {
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type.name.toUpperCase()),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedType = type),
                    backgroundColor: AppColors.surfaceContainerLow,
                    selectedColor: AppColors.secondaryContainer,
                    labelStyle: widget.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? AppColors.onSecondaryContainer
                          : AppColors.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            CustomTextField(
              label: 'Who or What?',
              controller: _nameController,
              hintText: 'e.g., Grandkids, The Garden, etc.',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Special Note',
              controller: _noteController,
              hintText: 'Tell me more about this...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Relationship / Tags Section
            Text('Who is in this memory?', style: widget.textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ..._tags.map(
                  (tag) => Chip(
                    label: Text(tag),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                    deleteIcon: const Icon(Icons.close, size: 14),
                  ),
                ),
                ActionChip(
                  label: const Text('+ Add Person'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Add Relationship'),
                        content: TextField(
                          controller: _tagController,
                          decoration: const InputDecoration(
                            hintText: 'e.g., Daughter, Best Friend',
                          ),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (_tagController.text.isNotEmpty) {
                                setState(() => _tags.add(_tagController.text));
                                _tagController.clear();
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Voice Caption Section
            Text('Add a Voice Caption', style: widget.textTheme.titleSmall),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: _toggleRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _isRecording
                          ? AppColors.error
                          : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRecording
                              ? 'Recording...'
                              : (_voicePath != null
                                    ? 'Voice caption added'
                                    : 'Tap to record a story'),
                          style: widget.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isRecording
                                ? AppColors.error
                                : AppColors.onSurface,
                          ),
                        ),
                        if (_voicePath != null && !_isRecording)
                          Text(
                            'Your story is ready to be saved',
                            style: widget.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_voicePath != null && !_isRecording)
                    IconButton(
                      onPressed: () => setState(() => _voicePath = null),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  context.read<MemoryProvider>().addMemory(
                    name: _nameController.text,
                    note: _noteController.text,
                    type: _selectedType,
                    localImagePath: _imagePath,
                    voiceNotePath: _voicePath,
                    tags: _tags,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_added_rounded, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Save to My Story',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualMemoryCard extends StatelessWidget {
  final MemoryItem item;
  final TextTheme textTheme;

  const _ManualMemoryCard({required this.item, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(item.type);
    final typeIcon = _typeIcon(item.type);
    final dateLabel = DateFormat('MMM d').format(item.createdAt);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MemoryDetailScreen(item: item)),
      ),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _memorySurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _memoryAccentSoft,
          ),
        ),
        child: Row(
          children: [
            if (item.localImagePath != null || item.remoteImageUrl != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildListImage(item),
                  ),
                  if (item.uploadStatus != UploadStatus.uploaded)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: item.uploadStatus == UploadStatus.uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : item.uploadStatus == UploadStatus.failed
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => context
                                      .read<MemoryProvider>()
                                      .retryUpload(item.id),
                                )
                              : const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 14, color: typeColor),
                            const SizedBox(width: 6),
                            Text(
                              item.type.name.toUpperCase(),
                              style: textTheme.labelSmall?.copyWith(
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Delete memory',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          await context.read<MemoryProvider>().deleteMemory(item.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Deleted "${item.name}" from memories.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.summary != null && item.summary!.isNotEmpty)
                    Text(
                      item.summary!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (item.note != null && item.note!.isNotEmpty)
                    Text(
                      item.note!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.tags.isNotEmpty || item.location != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.location != null)
                          _MemoryMetaPill(
                            label: item.location!,
                            icon: Icons.home_rounded,
                          ),
                        ...item.tags
                            .take(2)
                            .map((tag) => _MemoryMetaPill(label: tag)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListImage(MemoryItem item) {
    const double size = 70;

    // Local image
    if (!kIsWeb && item.localImagePath != null) {
      final file = File(item.localImagePath!);
      if (file.existsSync()) {
        return Image.file(file, width: size, height: size, fit: BoxFit.cover);
      }
    }

    // Remote image
    if (item.remoteImageUrl != null) {
      return Image.network(
        item.remoteImageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppColors.surfaceContainerHigh,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.image_rounded, color: AppColors.onSurfaceVariant),
    );
  }

  Color _typeColor(MemoryType type) {
    switch (type) {
      case MemoryType.person:
        return AppColors.secondary;
      case MemoryType.place:
        return AppColors.primary;
      case MemoryType.event:
        return AppColors.tertiary;
    }
  }

  IconData _typeIcon(MemoryType type) {
    switch (type) {
      case MemoryType.person:
        return Icons.person_rounded;
      case MemoryType.place:
        return Icons.place_rounded;
      case MemoryType.event:
        return Icons.celebration_rounded;
    }
  }
}

class _MemoryMetaPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _MemoryMetaPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _memoryMutedSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DailyCheckinEntry? entry;
  final TextTheme textTheme;

  const _SummaryCard({required this.entry, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _memoryAccentSoft,
          borderRadius: BorderRadius.circular(32),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _memoryAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Summary',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _memoryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            entry?.summary != null && entry!.summary.isNotEmpty
                ? entry!.summary
                : 'Start your chat with the companion to capture today\'s highlights.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurface,
              height: 1.5,
              fontStyle: entry?.summary == null || entry!.summary.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordActionCard extends StatelessWidget {
  final TextTheme textTheme;
  final VoidCallback onAddMemory;

  const _RecordActionCard({required this.textTheme, required this.onAddMemory});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAddMemory,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F3FA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _memoryAccentSoft,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: _memoryAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a New Memory',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _memoryAccent,
                    ),
                  ),
                  Text(
                    'Save a photo or a special moment',
                    style: textTheme.bodySmall?.copyWith(
                      color: _memoryTextSoft.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _memoryAccent.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastEntryCard extends StatelessWidget {
  final DailyCheckinEntry entry;
  final TextTheme textTheme;

  const _PastEntryCard({required this.entry, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.date);
    String title = entry.summary.isNotEmpty
        ? entry.summary.split('.').first
        : 'Entry from $dateStr';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.summary.isNotEmpty ? entry.summary : 'No summary available.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
