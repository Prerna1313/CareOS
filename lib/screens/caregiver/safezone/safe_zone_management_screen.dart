import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/caregiver_session.dart';
import '../../../models/safe_zone.dart';
import '../../../repositories/safe_zone_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/empty_state.dart';

class SafeZoneManagementScreen extends StatefulWidget {
  const SafeZoneManagementScreen({super.key});

  @override
  State<SafeZoneManagementScreen> createState() => _SafeZoneManagementScreenState();
}

class _SafeZoneManagementScreenState extends State<SafeZoneManagementScreen> {
  final _repository = SafeZoneRepository();
  final _uuid = const Uuid();
  CaregiverSession? _session;
  bool _isLoading = true;
  List<SafeZone> _zones = [];

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
    _loadZones();
  }

  Future<void> _loadZones() async {
    final session = _session ?? CaregiverSession.fallback();
    setState(() => _isLoading = true);
    final zones = await _repository.getAll(session.patientId);
    if (mounted) {
      setState(() {
        _zones = zones;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Safe Zones'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _zones.isEmpty
              ? EmptyState(
                  title: 'No Safe Zones',
                  message: 'Define areas like Home or Hospital to get alerted if ${(_session ?? CaregiverSession.fallback()).patientName} wanders away.',
                  icon: Icons.share_location,
                  actionLabel: 'Add Safe Zone',
                  onAction: () {},
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _zones.length,
                  itemBuilder: (context, index) {
                    final zone = _zones[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.home, color: AppColors.secondaryColor),
                        ),
                        title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Radius: ${zone.radiusMeters}m\nLat: ${zone.latitude}, Lng: ${zone.longitude}'),
                        trailing: Switch(
                          value: zone.isActive,
                          onChanged: (val) async {
                            await _repository.update(zone.copyWith(isActive: val));
                            await _loadZones();
                          },
                          activeThumbColor: AppColors.primaryColor,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddZoneDialog,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add_location_alt, color: Colors.white),
      ),
    );
  }

  Future<void> _showAddZoneDialog() async {
    final session = _session ?? CaregiverSession.fallback();
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final radiusController = TextEditingController(text: '50');
    var selectedType = SafeZoneType.home;

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
                  const Text(
                    'Add Safe Zone',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Zone name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SafeZoneType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Zone type'),
                    items: SafeZoneType.values
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: radiusController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Radius (meters)'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final latitude = double.tryParse(latController.text.trim());
                        final longitude = double.tryParse(lngController.text.trim());
                        final radius = double.tryParse(radiusController.text.trim());
                        if (name.isEmpty ||
                            latitude == null ||
                            longitude == null ||
                            radius == null) {
                          return;
                        }

                        await _repository.create(
                          SafeZone(
                            id: _uuid.v4(),
                            patientId: session.patientId,
                            name: name,
                            type: selectedType,
                            latitude: latitude,
                            longitude: longitude,
                            radiusMeters: radius,
                          ),
                        );
                        if (mounted) {
                          Navigator.of(this.context).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Safe Zone'),
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
      await _loadZones();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Safe zone saved for ${session.patientName}.')),
        );
      }
    }
  }
}
