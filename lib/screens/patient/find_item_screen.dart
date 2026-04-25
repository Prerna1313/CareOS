import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/camera_event.dart';
import '../../services/patient_records_service.dart';
import '../../theme/app_colors.dart';

class FindItemScreen extends StatefulWidget {
  const FindItemScreen({super.key});

  @override
  State<FindItemScreen> createState() => _FindItemScreenState();
}

class _FindItemScreenState extends State<FindItemScreen> {
  final TextEditingController _controller = TextEditingController();
  CameraEvent? _result;
  String _searchedQuery = '';

  final List<String> _suggestedItems = const [
    'specs',
    'glasses',
    'diary',
    'keys',
    'medicine',
    'phone',
    'water bottle',
    'bag',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final result = context
        .read<PatientRecordsService>()
        .findLatestObjectSighting(query);
    setState(() {
      _searchedQuery = query;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBright,
        title: Text(
          'Find My Item',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Ask where something was last seen',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try diary, specs, medicine, keys, or another important item.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Where is my diary?',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _search, child: const Text('Find')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedItems
                .map(
                  (item) => ActionChip(
                    label: Text(item),
                    onPressed: () {
                      _controller.text = item;
                      _search();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          if (_searchedQuery.isNotEmpty)
            _result != null
                ? _FoundItemCard(query: _searchedQuery, event: _result!)
                : _EmptySearchCard(query: _searchedQuery),
        ],
      ),
    );
  }
}

class _FoundItemCard extends StatelessWidget {
  final String query;
  final CameraEvent event;

  const _FoundItemCard({required this.query, required this.event});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final formattedTime = DateFormat(
      'dd MMM, h:mm a',
    ).format(event.analysisTimestamp ?? event.timestamp);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (File(event.imagePath).existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.file(
                File(event.imagePath),
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I last saw your $query here.',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.locationHint.trim().isNotEmpty &&
                          event.locationHint.toLowerCase() != 'unknown'
                      ? 'Likely location: ${event.locationHint}'
                      : 'A saved observation may help you find it.',
                  style: textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  event.note.isNotEmpty
                      ? event.note
                      : 'This observation was stored for item finding.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FactChip(label: formattedTime),
                    if (event.detectedObjects.isNotEmpty)
                      ...event.detectedObjects.map(
                        (object) => _FactChip(label: object),
                      ),
                  ],
                ),
                if (event.unusualObservation.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Note: ${event.unusualObservation}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchCard extends StatelessWidget {
  final String query;

  const _EmptySearchCard({required this.query});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No saved sighting for "$query" yet.',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try capturing a few observation snapshots around the room so CareOS can remember where important items were last seen.',
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

class _FactChip extends StatelessWidget {
  final String label;

  const _FactChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
