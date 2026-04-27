import 'package:flutter/material.dart';

import '../../../models/caregiver_session.dart';
import '../../../models/medication_reminder.dart';
import '../../../repositories/reminder_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/caregiver/empty_state.dart';

class ReminderManagementScreen extends StatefulWidget {
  const ReminderManagementScreen({super.key});

  @override
  State<ReminderManagementScreen> createState() =>
      _ReminderManagementScreenState();
}

class _ReminderManagementScreenState extends State<ReminderManagementScreen> {
  final _repository = ReminderRepository();
  CaregiverSession? _session;
  bool _isLoading = true;
  List<MedicationReminder> _reminders = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CaregiverSessionScope.of(context);
    if (_session?.patientId == session.patientId) {
      return;
    }
    _session = session;
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final session = _session ?? CaregiverSession.fallback();
    setState(() => _isLoading = true);
    final reminders = await _repository.getAll(session.patientId);
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
          ? EmptyState(
              title: 'No Reminders',
              message:
                  'Add medication, water, or exercise reminders for ${(_session ?? CaregiverSession.fallback()).patientName}.',
              icon: Icons.alarm_add,
              actionLabel: 'Add Reminder',
              onAction: () => _openReminderEditor(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final rem = _reminders[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: rem.responseStatus ==
                              ReminderResponseStatus.missed
                          ? AppColors.errorColor.withValues(alpha: 0.5)
                          : Colors.grey[200]!,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    title: Text(
                      rem.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${rem.time} • ${rem.repeatPattern}\nStatus: ${rem.responseStatus.name}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openReminderEditor(existing: rem),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openReminderEditor(),
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _openReminderEditor({MedicationReminder? existing}) async {
    final session = _session ?? CaregiverSession.fallback();
    final titleController = TextEditingController(text: existing?.title ?? '');
    final instructionsController = TextEditingController(
      text: existing?.instructions ?? '',
    );
    var selectedType = existing?.type ?? ReminderType.medicine;
    var selectedTime = _parseTimeOfDay(existing?.time ?? '08:00');
    var repeatPattern = existing?.repeatPattern ?? 'daily';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? 'Add Reminder' : 'Edit Reminder',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Reminder title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ReminderType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ReminderType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: sheetContext,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setModalState(() => selectedTime = picked);
                              }
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(selectedTime.format(sheetContext)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: repeatPattern,
                            decoration: const InputDecoration(
                              labelText: 'Repeat',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('daily'),
                              ),
                              DropdownMenuItem(
                                value: 'weekdays',
                                child: Text('weekdays'),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('custom'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => repeatPattern = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: instructionsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(sheetContext);
                          final messenger = ScaffoldMessenger.of(context);
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final reminder = MedicationReminder(
                            id:
                                existing?.id ??
                                'med_${DateTime.now().microsecondsSinceEpoch}',
                            patientId: session.patientId,
                            title: title,
                            type: selectedType,
                            time:
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            repeatPattern: repeatPattern,
                            instructions:
                                instructionsController.text.trim().isEmpty
                                ? null
                                : instructionsController.text.trim(),
                            responseStatus:
                                existing?.responseStatus ??
                                ReminderResponseStatus.pending,
                            lastResponseAt: existing?.lastResponseAt,
                            snoozedUntil: existing?.snoozedUntil,
                            isEnabled: existing?.isEnabled ?? true,
                          );

                          if (existing == null) {
                            await _repository.create(reminder);
                          } else {
                            await _repository.update(reminder);
                          }

                          if (!mounted) return;
                          navigator.pop();
                          await _loadReminders();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? 'Reminder added for ${session.patientName}.'
                                    : 'Reminder updated for ${session.patientName}.',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          existing == null ? 'Save Reminder' : 'Update Reminder',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
