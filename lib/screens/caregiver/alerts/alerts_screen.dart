import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/alert.dart';
import '../../../models/caregiver_session.dart';
import '../../../repositories/alert_repository.dart';
import '../../../repositories/patient_monitoring_repository.dart';
import '../../../repositories/reminder_repository.dart';
import '../../../repositories/safe_zone_repository.dart';
import '../../../services/backend_speech_result_service.dart';
import '../../../services/backend_video_result_service.dart';
import '../../../services/caregiver_alert_feed_service.dart';
import '../../../services/confusion_detection_result_service.dart';
import '../../../services/patient_location_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/alert_card.dart';
import '../../../widgets/caregiver/empty_state.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  final _repository = AlertRepository();
  final _patientRepository = PatientMonitoringRepository();
  final _reminderRepository = ReminderRepository();
  final _safeZoneRepository = SafeZoneRepository();
  final _locationService = PatientLocationService();
  final _alertFeedService = CaregiverAlertFeedService();
  late TabController _tabController;
  CaregiverSession? _session;
  bool _isLoading = true;
  List<Alert> _activeAlerts = [];
  List<Alert> _historyAlerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CaregiverSessionScope.of(context);
    if (_session?.patientId == session.patientId) {
      return;
    }
    _session = session;
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final session = _session ?? CaregiverSession.fallback();
    final confusionService = context.read<ConfusionDetectionResultService>();
    final videoService = context.read<BackendVideoResultService>();
    final speechService = context.read<BackendSpeechResultService>();
    setState(() => _isLoading = true);
    final latestAssessment = confusionService.getLatestForPatient(
      session.patientId,
    );
    final patient = await _patientRepository.getPatientStatus(
      session.patientId,
      fallbackName: session.patientName,
      fallbackCondition: session.condition,
      fallbackLocation: session.location,
    );
    final active = await _repository.getActiveAlerts(session.patientId);
    final history = await _repository.getAlertHistory(session.patientId);
    final reminders = await _reminderRepository.getAll(session.patientId);
    final safeZones = await _safeZoneRepository.getAll(session.patientId);
    final latestLocationPing = await _locationService.getLatest(session.patientId);
    final latestVideo = videoService.getLatestForPatient(session.patientId);
    final latestSpeech = speechService.getLatestForPatient(session.patientId);
    
    if (mounted) {
      setState(() {
        _activeAlerts = _alertFeedService.buildActiveAlerts(
          patientId: session.patientId,
          storedAlerts: active,
          patient: patient,
          confusionAssessment: latestAssessment,
          reminders: reminders,
          safeZones: safeZones,
          latestLocationPing: latestLocationPing,
          latestVideo: latestVideo,
          latestSpeech: latestSpeech,
        );
        _historyAlerts = _alertFeedService.buildHistoryAlerts(
          patientId: session.patientId,
          storedAlerts: history,
          patient: patient,
          confusionAssessment: latestAssessment,
          reminders: reminders,
          safeZones: safeZones,
          latestLocationPing: latestLocationPing,
          latestVideo: latestVideo,
          latestSpeech: latestSpeech,
        );
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Patient Alerts'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryColor,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAlertList(_activeAlerts, isActiveTab: true),
                _buildAlertList(_historyAlerts, isActiveTab: false),
              ],
            ),
    );
  }

  Widget _buildAlertList(List<Alert> alerts, {required bool isActiveTab}) {
    if (alerts.isEmpty) {
      return EmptyState(
        title: isActiveTab ? 'No Active Alerts' : 'No Alert History',
        message: isActiveTab 
            ? '${(_session ?? CaregiverSession.fallback()).patientName} is currently safe and stable.' 
            : 'No alerts have been recorded yet.',
        icon: Icons.check_circle_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return AlertCard(
            alert: alert,
            onAcknowledge: isActiveTab ? () async {
              await _repository.acknowledgeAlert(alert.id);
              _loadAlerts();
            } : null,
            onTap: () => _showAlertDetails(alert),
          );
        },
      ),
    );
  }

  void _showAlertDetails(Alert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Explanation:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
            Text(alert.explanation ?? alert.message),
            const SizedBox(height: 16),
            Text('Recommended Action:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
            Text(alert.recommendedAction ?? 'Please check on the patient.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _repository.resolveAlert(
                    alert.id,
                    (_session ?? CaregiverSession.fallback()).caregiverId,
                  );
                  _loadAlerts();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mark as Resolved', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
