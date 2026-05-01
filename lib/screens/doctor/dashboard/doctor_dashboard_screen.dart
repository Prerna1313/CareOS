import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/caregiver_report.dart';
import '../../../models/confusion_detection_result.dart';
import '../../../models/doctor_note.dart';
import '../../../models/patient/patient_profile.dart';
import '../../../repositories/report_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../services/confusion_detection_result_service.dart';
import '../../../services/doctor_note_service.dart';
import '../../../services/patient_session_service.dart';
import 'doctor_notifications_screen.dart';
import 'doctor_patient_details_screen.dart';
import 'doctor_patients_list_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _reportRepository = ReportRepository();
  final _doctorNoteService = DoctorNoteService();
  int _selectedTabIndex = 0;
  int _selectedPatientIndex = 0;

  @override
  void initState() {
    super.initState();
    _doctorNoteService.init();
  }

  Future<List<_DoctorPatientBundle>> _loadDoctorBundles(
    List<PatientProfile> profiles,
    ConfusionDetectionResultService confusionService,
  ) async {
    final bundles = await Future.wait(
      profiles.map((profile) async {
        final reports = (await _reportRepository.getAll(profile.patientId))
            .where((report) => report.visibleToDoctor)
            .toList();
        final confusionAssessments = confusionService.getByPatientId(
          profile.patientId,
        );
        final doctorNotes = await _doctorNoteService.getByPatientId(
          profile.patientId,
        );
        return _DoctorPatientBundle(
          profile: profile,
          confusionAssessments: confusionAssessments,
          reports: reports,
          doctorNotes: doctorNotes,
        );
      }),
    );
    return bundles;
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = context.read<PatientSessionService>();
    final confusionService = context.read<ConfusionDetectionResultService>();
    final profiles = sessionService.getAllProfiles();

    return FutureBuilder<List<_DoctorPatientBundle>>(
      future: _loadDoctorBundles(profiles, confusionService),
      builder: (context, snapshot) {
        final bundles = snapshot.data ?? const <_DoctorPatientBundle>[];
        if (_selectedPatientIndex >= bundles.length) {
          _selectedPatientIndex = 0;
        }
        final selectedBundle = bundles.isNotEmpty
            ? bundles[_selectedPatientIndex]
            : null;

        final pages = [
          _DoctorOverviewPage(
            selectedBundle: selectedBundle,
            allBundles: bundles,
            onOpenPatients: () => setState(() => _selectedTabIndex = 1),
            onOpenNotifications: () => setState(() => _selectedTabIndex = 2),
            onOpenPatientDetails: () {
              if (selectedBundle == null) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorPatientDetailsScreen(
                    patientId: selectedBundle.profile.patientId,
                    patientName: selectedBundle.profile.displayName,
                    confusionAssessments: selectedBundle.confusionAssessments,
                    reports: selectedBundle.reports,
                    initialDoctorNotes: selectedBundle.doctorNotes,
                  ),
                ),
              );
            },
          ),
          DoctorPatientsListScreen(
            patientBundles: bundles
                .map(
                  (bundle) => DoctorPatientListEntry(
                    patientId: bundle.profile.patientId,
                    patientName: bundle.profile.displayName,
                    confusionAssessments: bundle.confusionAssessments,
                    reports: bundle.reports,
                    doctorNotes: bundle.doctorNotes,
                  ),
                )
                .toList(),
            onSelectPatient: (index) {
              setState(() {
                _selectedPatientIndex = index;
                _selectedTabIndex = 0;
              });
            },
            onOpenNotifications: () => setState(() => _selectedTabIndex = 2),
          ),
          DoctorNotificationsScreen(
            patientBundles: bundles
                .map(
                  (bundle) => DoctorPatientListEntry(
                    patientId: bundle.profile.patientId,
                    patientName: bundle.profile.displayName,
                    confusionAssessments: bundle.confusionAssessments,
                    reports: bundle.reports,
                    doctorNotes: bundle.doctorNotes,
                  ),
                )
                .toList(),
          ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8F5),
          body: SafeArea(child: pages[_selectedTabIndex]),
          bottomNavigationBar: _DoctorBottomNav(
            selectedIndex: _selectedTabIndex,
            onChanged: (index) => setState(() => _selectedTabIndex = index),
          ),
        );
      },
    );
  }
}

class _DoctorPatientBundle {
  final PatientProfile profile;
  final List<ConfusionDetectionResult> confusionAssessments;
  final List<CaregiverReport> reports;
  final List<DoctorNote> doctorNotes;

  const _DoctorPatientBundle({
    required this.profile,
    required this.confusionAssessments,
    required this.reports,
    required this.doctorNotes,
  });
}

class _DoctorOverviewPage extends StatelessWidget {
  final _DoctorPatientBundle? selectedBundle;
  final List<_DoctorPatientBundle> allBundles;
  final VoidCallback onOpenPatients;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenPatientDetails;

  const _DoctorOverviewPage({
    required this.selectedBundle,
    required this.allBundles,
    required this.onOpenPatients,
    required this.onOpenNotifications,
    required this.onOpenPatientDetails,
  });

  static const _teal = Color(0xFF2D6E6E);
  static const _tealLight = Color(0xFF3D8C8C);
  static const _darkText = Color(0xFF1A3636);
  static const _bgColor = Color(0xFFF7F8F5);
  static const _tealBgLight = Color(0xFFE0F0F0);

  @override
  Widget build(BuildContext context) {
    final latestAssessment = selectedBundle?.confusionAssessments.isNotEmpty == true
        ? selectedBundle!.confusionAssessments.first
        : null;
    final highRiskCount = allBundles.fold<int>(
      0,
      (total, bundle) =>
          total +
          bundle.confusionAssessments
              .where((result) => result.riskLevel.name.toLowerCase() == 'high')
              .length,
    );
    final doctorVisibleReports = allBundles.fold<int>(
      0,
      (total, bundle) => total + bundle.reports.length,
    );

    return Column(
      children: [
        _buildAppBar(context, highRiskCount),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildPatientCard(
                  patientName:
                      selectedBundle?.profile.displayName ?? 'No linked patient',
                  latestAssessment: latestAssessment,
                ),
                const SizedBox(height: 20),
                _buildSummaryCards(
                  latestAssessment: latestAssessment,
                  doctorVisibleReports: doctorVisibleReports,
                  highRiskCount: highRiskCount,
                  linkedPatients: allBundles.length,
                  doctorNotesCount: allBundles.fold<int>(
                    0,
                    (total, bundle) => total + bundle.doctorNotes.length,
                  ),
                ),
                const SizedBox(height: 20),
                _buildConfusionTrendCard(
                  selectedBundle?.confusionAssessments ?? const [],
                ),
                const SizedBox(height: 20),
                _buildRecentReportsSection(
                  selectedBundle?.reports ?? const [],
                ),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, int alertCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.landing,
                (route) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: _darkText,
                size: 22,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Doctor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onOpenNotifications,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _tealBgLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: _teal,
                    size: 22,
                  ),
                ),
                if (alertCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCC4444),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${alertCount.clamp(0, 9)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard({
    required String patientName,
    required ConfusionDetectionResult? latestAssessment,
  }) {
    final subtitle = latestAssessment == null
        ? 'No doctor-visible confusion assessment yet'
        : 'Latest confusion risk: ${latestAssessment.riskLevel.name.toUpperCase()}';

    return GestureDetector(
      onTap: onOpenPatientDetails,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tealBgLight,
                border: Border.all(color: _teal, width: 2),
              ),
              child: const Icon(Icons.person, color: _teal, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _tealBgLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards({
    required ConfusionDetectionResult? latestAssessment,
    required int doctorVisibleReports,
    required int highRiskCount,
    required int linkedPatients,
    required int doctorNotesCount,
  }) {
    final latestScore = latestAssessment?.score.round() ?? 0;
    final latestRisk =
        latestAssessment?.riskLevel.name.toUpperCase() ?? 'STABLE';

    return Column(
      children: [
        Row(
          children: [
            _buildSummaryCard(
              latestScore == 0 ? '-' : '$latestScore',
              'Latest\nScore',
              const Color(0xFFFFF8E1),
              const Color(0xFFD4910A),
            ),
            const SizedBox(width: 10),
            _buildSummaryCard(latestRisk, 'Latest\nRisk', _tealBgLight, _teal),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildSummaryCard(
              linkedPatients.toString(),
              'Linked\nPatients',
              const Color(0xFFFFE8E8),
              highRiskCount > 0 ? const Color(0xFFCC4444) : _tealLight,
            ),
            const SizedBox(width: 10),
            _buildSummaryCard(
              '$doctorVisibleReports/$doctorNotesCount',
              'Reports/\nNotes',
              const Color(0xFFE7F5EC),
              const Color(0xFF3D8C5A),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String value,
    String label,
    Color bg,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.8),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfusionTrendCard(List<ConfusionDetectionResult> assessments) {
    if (assessments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: const Text('No confusion trend recorded yet.'),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent confusion timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 14),
          ...assessments.take(4).map(
            (assessment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _riskColor(assessment.riskLevel.name.toLowerCase()),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      assessment.explanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _darkText),
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

  Widget _buildRecentReportsSection(List<CaregiverReport> reports) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent caregiver handoff',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 14),
          if (reports.isEmpty)
            const Text('No doctor-visible caregiver notes yet.')
          else
            ...reports.take(3).map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category.displayName,
                      style: const TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(report.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenPatients,
            icon: const Icon(Icons.people_outline_rounded),
            label: const Text('Review Linked Patients'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onOpenNotifications,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Open Handoff Alerts'),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Color _riskColor(String risk) {
    if (risk == 'high') return const Color(0xFFCC4444);
    if (risk == 'moderate' || risk == 'medium') return const Color(0xFFD4910A);
    return const Color(0xFF3D8C5A);
  }
}

class _DoctorBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _DoctorBottomNav({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onChanged,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'Patients',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: 'Alerts',
        ),
      ],
    );
  }
}
