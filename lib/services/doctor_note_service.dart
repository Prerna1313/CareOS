import 'package:hive_flutter/hive_flutter.dart';

import '../models/doctor_note.dart';
import 'patient_registry_service.dart';

class DoctorNoteService {
  static const String _boxName = 'doctor_notes';
  Box? _box;
  final _registryService = PatientRegistryService();

  Future<void> init() async {
    _box = await _openBox();
  }

  Future<Box> _openBox() async =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : Hive.openBox(_boxName);

  Future<void> save(DoctorNote note) async {
    final box = _box ?? await _openBox();
    await box.put(note.id, note.toMap());
    await _registryService.saveDoctorNote(note);
  }

  Future<List<DoctorNote>> getByPatientId(String patientId) async {
    final box = _box ?? (Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null);
    final localNotes = box == null
        ? <DoctorNote>[]
        : box.values
              .map(
                (raw) => DoctorNote.fromMap(
                  Map<String, dynamic>.from(raw as Map),
                ),
              )
              .where((note) => note.patientId == patientId)
              .toList();
    if (localNotes.isNotEmpty) {
      localNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return localNotes;
    }
    final remoteNotes = await _registryService.getDoctorNotes(patientId);
    for (final note in remoteNotes) {
      await box?.put(note.id, note.toMap());
    }
    return remoteNotes;
  }
}
