import 'package:hive_flutter/hive_flutter.dart';

import '../models/patient/patient_contracts.dart';

class PatientInterventionService {
  static const String _boxName = 'patient_interventions';
  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  Future<void> logIntervention(PatientInterventionRecord record) async {
    await _box.put(record.interventionId, record.toMap());
  }

  List<PatientInterventionRecord> getAllRecords() {
    final records = _box.values
        .map(
          (value) => PatientInterventionRecord.fromMap(
            Map<String, dynamic>.from(value),
          ),
        )
        .toList();
    records.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    return records;
  }

  List<PatientInterventionRecord> getByPatientId(String patientId) {
    return getAllRecords()
        .where((record) => record.patientId == patientId)
        .toList();
  }
}
