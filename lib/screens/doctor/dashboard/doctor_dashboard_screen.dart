import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/caregiver_report.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../repositories/report_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../services/confusion_detection_result_service.dart';
import '../../../services/patient_session_service.dart';
import '../../../theme/app_colors.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _reportRepository = ReportRepository();

  @override
  Widget build(BuildContext context) {
    final activeProfile = context.read<PatientSessionService>().getActiveProfile();
    final patientId = activeProfile?.patientId;
    final patientName = activeProfile?.displayName ?? 'Active Patient';
    final confusionAssessments = patientId == null
        ? const <ConfusionDetectionResult>[]
        : context
            .read<ConfusionDetectionResultService>()
            .getByPatientId(patientId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.landing,
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<CaregiverReport>>(
          future: patientId == null
              ? Future.value(const <CaregiverReport>[])
              : _reportRepository.getAll(patientId),
          builder: (context, snapshot) {
            final reports = (snapshot.data ?? const <CaregiverReport>[])
                .where((report) => report.visibleToDoctor)
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor review for $patientName',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Caregiver reports, recent confusion assessments, and quick review cards are now shared here.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryRow(reports, confusionAssessments),
                  const SizedBox(height: 24),
                  _buildConfusionSection(confusionAssessments),
                  const SizedBox(height: 24),
                  _buildCaregiverReportsSection(reports),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    List<CaregiverReport> reports,
    List<ConfusionDetectionResult> confusionAssessments,
  ) {
    final latestRisk = confusionAssessments.isNotEmpty
        ? confusionAssessments.first.riskLevel.name.toUpperCase()
        : 'STABLE';
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _DoctorMetricCard(
          title: 'Doctor-visible reports',
          value: reports.length.toString(),
          subtitle: 'Shared from caregiver flow',
          color: AppColors.primaryContainer,
        ),
        _DoctorMetricCard(
          title: 'Latest confusion risk',
          value: latestRisk,
          subtitle: confusionAssessments.isNotEmpty
              ? '${confusionAssessments.first.score.round()} / 100'
              : 'No AI assessment yet',
          color: AppColors.secondaryContainer,
        ),
      ],
    );
  }

  Widget _buildConfusionSection(List<ConfusionDetectionResult> confusionAssessments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent confusion assessments',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (confusionAssessments.isEmpty)
          _EmptyDoctorCard(
            message: 'No confusion assessments have been shared yet.',
          )
        else
          ...confusionAssessments.take(3).map(
            (result) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk ${result.riskLevel.name.toUpperCase()} • ${result.score.round()}/100',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(result.explanation),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCaregiverReportsSection(List<CaregiverReport> reports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caregiver reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          _EmptyDoctorCard(
            message: 'No caregiver reports have been marked visible to doctor yet.',
          )
        else
          ...reports.take(6).map(
            (report) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  report.category.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(report.note),
                ),
                trailing: Text(
                  '${report.timestamp.day}/${report.timestamp.month}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DoctorMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _DoctorMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyDoctorCard extends StatelessWidget {
  final String message;

  const _EmptyDoctorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
