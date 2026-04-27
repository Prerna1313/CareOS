import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/patient.dart';
import '../../../models/patient_location_ping.dart';
import '../../../repositories/patient_monitoring_repository.dart';
import '../../../repositories/safe_zone_repository.dart';
import '../../../services/backend_video_result_service.dart';
import '../../../services/caregiver_geofence_service.dart';
import '../../../services/firestore/firestore_caregiver_service.dart';
import '../../../services/patient_location_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/status_chip.dart';
import '../../../widgets/caregiver/metric_card.dart';

class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  final _repository = PatientMonitoringRepository();
  final _safeZoneRepository = SafeZoneRepository();
  final _locationService = PatientLocationService();
  final _firestoreCaregiverService = FirestoreCaregiverService();
  final _geofenceService = CaregiverGeofenceService();
  final _uuid = const Uuid();
  CaregiverSession? _session;
  Patient? _patient;
  PatientLocationPing? _latestLocationPing;
  bool _isLoading = true;
  String _safeZoneStatus = 'Checking safe zones';
  String _lastInteractionLabel = 'Unknown';

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
    _loadData();
  }

  Future<void> _loadData() async {
    final session = _session ?? CaregiverSession.fallback();
    setState(() => _isLoading = true);
    final p = await _repository.getPatientStatus(
      session.patientId,
      fallbackName: session.patientName,
      fallbackCondition: session.condition,
      fallbackLocation: session.location,
    );
    final safeZones = await _safeZoneRepository.getAll(session.patientId);
    final latestPing = await _locationService.getLatest(session.patientId);
    final geofence = _geofenceService.evaluate(
      latestPing: latestPing,
      safeZones: safeZones,
    );
    if (mounted) {
      setState(() {
        _patient = p;
        _latestLocationPing = latestPing;
        _safeZoneStatus = geofence.summary;
        _lastInteractionLabel = _formatRelative(
          p?.lastActiveAt ?? DateTime.now(),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Live Monitoring'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryColor),
            onPressed: _loadData,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildLocationSnapshot(),
            const SizedBox(height: 16),
            _buildDeviceStatus(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final latestVideo = context
        .read<BackendVideoResultService>()
        .getLatestForPatient((_session ?? CaregiverSession.fallback()).patientId);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.monitor_heart, size: 48, color: AppColors.primaryColor),
          const SizedBox(height: 12),
          Text(_patient!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StatusChip(
            label: 'STATUS: ${_patient!.currentStatus.toUpperCase()}',
            isPositive: _patient!.currentStatus == 'active',
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Last Move', _lastInteractionLabel),
              _buildMiniStat(
                'Activity',
                _patient!.currentStatus.toUpperCase(),
              ),
              _buildMiniStat(
                'Motion Risk',
                latestVideo?.movementAnalysis.movementRiskLevel.toUpperCase() ??
                    'LOW',
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildLocationSnapshot() {
    final session = _session ?? CaregiverSession.fallback();
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryContainer,
            AppColors.surfaceContainerLowest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary.withValues(alpha: 0.08),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: AppColors.errorColor, size: 40),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _latestLocationPing?.label ??
                      _patient!.currentLocationSummary ??
                      'Unknown Location',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Home base: ${session.location}',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _safeZoneStatus,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_latestLocationPing != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Source: ${_latestLocationPing!.source}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceStatus() {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            title: 'Last Interaction',
            value: _lastInteractionLabel,
            icon: Icons.touch_app,
            color: AppColors.secondaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            title: 'Safe Zone',
            value: _safeZoneStatus.contains('Inside') ? 'Inside' : 'Review',
            icon: Icons.watch_later_outlined,
            color: AppColors.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            final session = _session ?? CaregiverSession.fallback();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  session.emergencyPhone?.isNotEmpty == true
                      ? 'Call flow should use caregiver/emergency number: ${session.emergencyPhone}'
                      : 'No emergency phone configured yet. Add one in Care Team.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.phone),
          label: const Text('Call Patient'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            final session = _session ?? CaregiverSession.fallback();
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Emergency Contact'),
                content: Text(
                  session.emergencyPhone?.isNotEmpty == true
                      ? 'Escalate using ${session.emergencyPhone}. You can also store additional contacts in Care Team.'
                      : 'No emergency contact is configured yet. Add one from Care Team.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.emergency),
          label: const Text('Escalate to Emergency'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            foregroundColor: AppColors.errorColor,
            side: const BorderSide(color: AppColors.errorColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showLocationUpdateDialog,
          icon: const Icon(Icons.my_location),
          label: const Text('Manual Location Override'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            foregroundColor: AppColors.primaryColor,
            side: const BorderSide(color: AppColors.primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  String _formatRelative(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  Future<void> _showLocationUpdateDialog() async {
    final session = _session ?? CaregiverSession.fallback();
    final labelController = TextEditingController(
      text: _latestLocationPing?.label ?? session.location,
    );
    final latController = TextEditingController(
      text: _latestLocationPing?.latitude.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: _latestLocationPing?.longitude.toString() ?? '',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tracked Location Update',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Live patient device GPS can now feed this monitor automatically. Use this form only when you need to correct or override the tracked location manually.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Location label'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final latitude = double.tryParse(latController.text.trim());
                    final longitude = double.tryParse(lngController.text.trim());
                    if (latitude == null || longitude == null) {
                      return;
                    }
                    final ping = PatientLocationPing(
                      id: _uuid.v4(),
                      patientId: session.patientId,
                      label: labelController.text.trim().isEmpty
                          ? 'Tracked location'
                          : labelController.text.trim(),
                      latitude: latitude,
                      longitude: longitude,
                      source: 'caregiver_manual_update',
                      capturedAt: DateTime.now(),
                    );
                    await _locationService.save(ping);
                    await _firestoreCaregiverService.syncPatientLocationPing(
                      ping,
                    );
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Location Update'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracked location updated.')),
      );
    }
  }
}
