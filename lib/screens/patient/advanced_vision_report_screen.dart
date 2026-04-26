import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient/advanced_vision_contracts.dart';
import '../../providers/patient_session_provider.dart';
import '../../services/advanced_vision_contract_service.dart';
import '../../theme/app_colors.dart';

class AdvancedVisionReportScreen extends StatelessWidget {
  const AdvancedVisionReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = context.watch<PatientSessionProvider>().profile;

    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceBright,
          title: const Text('Advanced Vision Report'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Open the patient dashboard first so advanced vision data can be prepared.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final bundle = context
        .watch<AdvancedVisionContractService>()
        .buildBundle(profile.patientId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBright,
        title: Text(
          'Advanced Vision Report',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdvancedVisionSummaryCard(bundle: bundle),
          const SizedBox(height: 18),
          _MovementAnalysisCard(analysis: bundle.movementAnalysis),
          if (bundle.latestFallAnalysis != null) ...[
            const SizedBox(height: 18),
            _FallAnalysisCard(analysis: bundle.latestFallAnalysis!),
          ],
          if (bundle.incidentRecords.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Incident Records',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...bundle.incidentRecords.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _IncidentCard(incident: incident),
              ),
            ),
          ],
          if (bundle.clipRequests.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Future Backend Clip Requests',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...bundle.clipRequests.map(
              (clip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClipRequestCard(clip: clip),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdvancedVisionSummaryCard extends StatelessWidget {
  final AdvancedVisionBundle bundle;

  const _AdvancedVisionSummaryCard({required this.bundle});

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
            'Future Google Video Pipeline Bundle',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'This local contract is ready for future Video Intelligence API person tracking and a custom Vertex AI fall model.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReportChip(
                label: 'Clip Requests',
                value: '${bundle.clipRequests.length}',
              ),
              _ReportChip(
                label: 'Incidents',
                value: '${bundle.incidentRecords.length}',
              ),
              _ReportChip(
                label: 'Movement Risk',
                value: bundle.movementAnalysis.movementRiskLevel,
              ),
              _ReportChip(
                label: 'Fall Contract',
                value: bundle.latestFallAnalysis == null ? 'None' : 'Ready',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovementAnalysisCard extends StatelessWidget {
  final MovementAnalysisResult analysis;

  const _MovementAnalysisCard({required this.analysis});

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
            'Movement Analysis',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            analysis.summary,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReportChip(
                label: 'Switches',
                value: '${analysis.locationSwitches}',
              ),
              _ReportChip(
                label: 'Quick Moves',
                value: '${analysis.shortIntervalSwitches}',
              ),
              _ReportChip(
                label: 'Loops',
                value: '${analysis.repeatedLoopCount}',
              ),
              _ReportChip(
                label: 'Places',
                value: '${analysis.distinctVisitedLocations}',
              ),
            ],
          ),
          if (analysis.evidenceNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...analysis.evidenceNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReportLine(
                  icon: Icons.route_rounded,
                  text: note,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FallAnalysisCard extends StatelessWidget {
  final FallAnalysisResult analysis;

  const _FallAnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFCCBC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Future Fall Analysis Contract',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            analysis.summary,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReportChip(label: 'Risk', value: analysis.riskLevel),
              _ReportChip(
                label: 'Confidence',
                value: '${(analysis.confidence * 100).round()}%',
              ),
              _ReportChip(label: 'Source', value: analysis.modelSource),
            ],
          ),
          if (analysis.evidenceNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...analysis.evidenceNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReportLine(
                  icon: Icons.personal_injury_rounded,
                  text: note,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final AdvancedVisionIncidentRecord incident;

  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  incident.incidentType.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM, h:mm a').format(incident.detectedAt),
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            incident.summary,
            style: textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(label: 'severity: ${incident.severity}'),
              _MiniPill(label: '${incident.evidenceRefs.length} evidence'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClipRequestCard extends StatelessWidget {
  final VideoObservationClipRequest clip;

  const _ClipRequestCard({required this.clip});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clip.triggerReason,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${clip.processingStatus.name}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(label: 'source: ${clip.metadata['source'] ?? 'local'}'),
              _MiniPill(
                label:
                    'incident: ${clip.metadata['incidentType'] ?? 'observation'}',
              ),
              _MiniPill(
                label:
                    'location: ${clip.metadata['locationHint'] ?? 'unknown'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  final String label;
  final String value;

  const _ReportChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReportLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
