import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/caregiver_report.dart';
import '../../../models/exported_report_file.dart';
import '../../../repositories/report_repository.dart';
import '../../../services/caregiver_report_export_service.dart';
import '../../../theme/app_colors.dart';
import '../../../models/progress_report.dart';

class ProgressReportScreen extends StatefulWidget {
  const ProgressReportScreen({super.key});

  @override
  State<ProgressReportScreen> createState() => _ProgressReportScreenState();
}

class _ProgressReportScreenState extends State<ProgressReportScreen> {
  final _repository = ReportRepository();
  final _exportService = CaregiverReportExportService();
  final _uuid = const Uuid();
  CaregiverSession? _session;
  bool _isLoading = true;
  ProgressReport? _report;
  List<ExportedReportFile> _exports = [];
  bool _sharedToDoctor = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CaregiverSessionScope.of(context);
    if (_session?.patientId == session.patientId) {
      return;
    }
    _session = session;
    _generateReport();
  }

  Future<void> _generateReport() async {
    final session = _session ?? CaregiverSession.fallback();
    final report = await _repository.generateProgressReport(
      session.patientId,
      session.caregiverId,
    );
    final exports = await _exportService.getAll(session.patientId);
    if (mounted) {
      setState(() {
        _report = report;
        _exports = exports;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Progress Report'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_outlined, color: AppColors.primaryColor),
            tooltip: 'Share summary to doctor',
            onPressed: _shareWithDoctor,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primaryColor),
            onPressed: _exportSoftCopy,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('${(_session ?? CaregiverSession.fallback()).patientName.toUpperCase()} REPORT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2))),
              const SizedBox(height: 24),
              _buildDataRow('Date Range', _report!.dateRange),
              const Divider(height: 32),
              _buildSectionTitle('Alert Summary'),
              _buildDataRow('High Severity Alerts', _report!.alertSummary['high'].toString()),
              _buildDataRow('Medium Severity Alerts', _report!.alertSummary['medium'].toString()),
              const Divider(height: 32),
              _buildSectionTitle('Adherence & Safety'),
              _buildDataRow('Medication Adherence', '${(_report!.medicationAdherence * 100).toInt()}%'),
              _buildDataRow('Location Safety', _report!.locationSafety),
              const Divider(height: 32),
              _buildSectionTitle('Recommendations'),
              ..._report!.recommendedActions.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(r)),
                  ],
                ),
              )),
              const SizedBox(height: 24),
              if (_sharedToDoctor)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This progress snapshot has been shared into the doctor handoff feed.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              _buildSectionTitle('Stored Soft Copies'),
              if (_exports.isEmpty)
                Text(
                  'No exported soft copies yet.',
                  style: TextStyle(color: Colors.grey[700]),
                )
              else
                ..._exports.take(4).map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${file.title} • ${file.filePath}',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryColor)),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportSoftCopy() async {
    final session = _session ?? CaregiverSession.fallback();
    if (_report == null) {
      return;
    }
    final exported = await _exportService.exportProgressReport(
      patientId: session.patientId,
      patientName: session.patientName,
      report: _report!,
    );
    if (!mounted) return;
    setState(() {
      _exports = [exported, ..._exports];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Soft copy saved at ${exported.filePath}')),
    );
  }

  Future<void> _shareWithDoctor() async {
    final session = _session ?? CaregiverSession.fallback();
    if (_report == null) {
      return;
    }

    final note = StringBuffer()
      ..writeln('Weekly caregiver progress summary for ${session.patientName}.')
      ..writeln(
        'Medication adherence: ${(_report!.medicationAdherence * 100).round()}%.',
      )
      ..writeln(
        'Alert counts - high: ${_report!.alertSummary['high'] ?? 0}, medium: ${_report!.alertSummary['medium'] ?? 0}, low: ${_report!.alertSummary['low'] ?? 0}.',
      )
      ..writeln(_report!.locationSafety)
      ..writeln('Recommended follow-up:')
      ..writeln(_report!.recommendedActions.map((item) => '- $item').join('\n'));

    await _repository.create(
      CaregiverReport(
        id: _uuid.v4(),
        patientId: session.patientId,
        caregiverId: session.caregiverId,
        category: ReportCategory.activity,
        note: note.toString().trim(),
        timestamp: DateTime.now(),
        visibleToDoctor: true,
      ),
    );

    if (!mounted) return;
    setState(() => _sharedToDoctor = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress report summary shared to doctor feed.'),
      ),
    );
  }
}
