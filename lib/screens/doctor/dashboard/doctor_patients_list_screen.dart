import 'package:flutter/material.dart';

import '../../../models/caregiver_report.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../models/doctor_note.dart';
import 'doctor_patient_details_screen.dart';

class DoctorPatientListEntry {
  final String patientId;
  final String patientName;
  final List<ConfusionDetectionResult> confusionAssessments;
  final List<CaregiverReport> reports;
  final List<DoctorNote> doctorNotes;

  const DoctorPatientListEntry({
    required this.patientId,
    required this.patientName,
    required this.confusionAssessments,
    required this.reports,
    required this.doctorNotes,
  });
}

class DoctorPatientsListScreen extends StatelessWidget {
  final List<DoctorPatientListEntry> patientBundles;
  final ValueChanged<int> onSelectPatient;
  final VoidCallback onOpenNotifications;

  const DoctorPatientsListScreen({
    super.key,
    required this.patientBundles,
    required this.onSelectPatient,
    required this.onOpenNotifications,
  });

  static const _teal = Color(0xFF2D6E6E);
  static const _darkText = Color(0xFF1A3636);
  static const _bgColor = Color(0xFFF7F8F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildSectionLabel(patientBundles.length),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: patientBundles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) =>
                    _buildPatientCard(ctx, patientBundles[index], index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'DR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doctor Patients',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                Text(
                  'Linked through CareOS caregiver setup',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpenNotifications,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: _teal,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(
            'DOCTOR PATIENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(
    BuildContext context,
    DoctorPatientListEntry patient,
    int index,
  ) {
    final latestRisk = patient.confusionAssessments.isEmpty
        ? 'Stable'
        : patient.confusionAssessments.first.riskLevel.name.toUpperCase();
    final stageColor = patient.confusionAssessments.isEmpty
        ? const Color(0xFF3D8C5A)
        : _stageColor(patient.confusionAssessments.first.riskLevel.name.toLowerCase());
    final alerts = patient.confusionAssessments
        .where((result) => result.riskLevel.name.toLowerCase() == 'high')
        .length;

    return GestureDetector(
      onTap: () {
        onSelectPatient(index);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorPatientDetailsScreen(
              patientId: patient.patientId,
              patientName: patient.patientName,
              confusionAssessments: patient.confusionAssessments,
              reports: patient.reports,
              initialDoctorNotes: patient.doctorNotes,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _buildInitials(patient.patientName),
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.patientName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Patient ID ${patient.patientId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: stageColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    latestRisk,
                    style: TextStyle(
                      color: stageColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  alerts > 0 ? '$alerts alert(s)' : 'No alerts',
                  style: TextStyle(
                    fontSize: 11,
                    color: alerts > 0
                        ? const Color(0xFFCC4444)
                        : Colors.grey[400],
                    fontWeight: alerts > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildInitials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'PT';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Color _stageColor(String risk) {
    if (risk == 'high') return const Color(0xFFCC4444);
    if (risk == 'moderate' || risk == 'medium') return const Color(0xFFD4910A);
    return const Color(0xFF3D8C5A);
  }
}
