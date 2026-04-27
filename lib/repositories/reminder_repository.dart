import '../models/medication_reminder.dart';
import '../services/caregiver_reminder_service.dart';
import '../services/mock_data_provider.dart';
import 'base_repository.dart';

class ReminderRepository implements BaseRepository<MedicationReminder> {
  final _service = CaregiverReminderService();

  @override
  Future<void> create(MedicationReminder item) async => _service.save(item);

  @override
  Future<void> delete(String id) async => _service.delete(id);

  @override
  Future<List<MedicationReminder>> getAll(String patientId) async {
    final reminders = await _service.getAll(patientId);
    if (reminders.isNotEmpty) {
      return reminders;
    }
    return MockDataProvider.getMockReminders(patientId: patientId);
  }

  @override
  Future<MedicationReminder?> getById(String id) => _service.getById(id);

  @override
  Future<void> update(MedicationReminder item) async => _service.save(item);
}
