// ============================================================
// FIREBASE → HIVE MIGRATION
// Fixed: removed duplicate method bodies (compile error in original).
// Now reads patient + daily summary from Hive boxes.
// Falls back to MockDataProvider if Hive is empty.
// ============================================================

import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/patient.dart';
import '../models/daily_summary.dart';
import '../services/mock_data_provider.dart';

class PatientMonitoringRepository {
  /// Get patient status from Hive.
  /// Falls back to mock data if Hive is empty (e.g., before demo seed runs).
  Future<Patient?> getPatientStatus(
    String patientId, {
    String? fallbackName,
    String? fallbackCondition,
    String? fallbackLocation,
  }) async {
    final box = await Hive.openBox('patients');
    final raw = box.get(patientId);
    if (raw != null) {
      return Patient.fromJson(Map<String, dynamic>.from(raw as Map));
    }
    // Fallback to mock data
    return MockDataProvider.getMockPatient(
      patientId: patientId,
      patientName: fallbackName ?? 'Eleanor Smith',
      condition: fallbackCondition ?? 'Alzheimer\'s Stage 2',
      location: fallbackLocation ?? 'Living Room',
    );
  }

  Future<DailySummary?> getDailySummary(
    String patientId, {
    String? fallbackPatientName,
  }) async {
    final box = await Hive.openBox('daily_summaries');
    final today = DateTime.now().toIso8601String().split('T').first;
    final raw = box.get('${patientId}_$today');
    if (raw != null) {
      return DailySummary.fromJson(Map<String, dynamic>.from(raw as Map));
    }
    // Fallback to mock data
    return MockDataProvider.getMockDailySummary(
      patientId: patientId,
      patientName: fallbackPatientName ?? 'Eleanor Smith',
    );
  }

  /// Stream that emits patient status.
  /// Uses a periodic refresh every 30 seconds to simulate live updates.
  Stream<Patient?> getPatientStatusStream(
    String patientId, {
    String? fallbackName,
    String? fallbackCondition,
    String? fallbackLocation,
  }) async* {
    // Emit immediately
    yield await getPatientStatus(
      patientId,
      fallbackName: fallbackName,
      fallbackCondition: fallbackCondition,
      fallbackLocation: fallbackLocation,
    );

    // Then emit every 30 seconds (simulates real-time updates)
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield await getPatientStatus(
        patientId,
        fallbackName: fallbackName,
        fallbackCondition: fallbackCondition,
        fallbackLocation: fallbackLocation,
      );
    }
  }

  /// Stream that emits daily summary.
  Stream<DailySummary?> getDailySummaryStream(
    String patientId, {
    String? fallbackPatientName,
  }) async* {
    yield await getDailySummary(
      patientId,
      fallbackPatientName: fallbackPatientName,
    );

    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield await getDailySummary(
        patientId,
        fallbackPatientName: fallbackPatientName,
      );
    }
  }
}

// ============================================================
// ORIGINAL FIREBASE IMPLEMENTATION (commented out)
// Note: the original file also had a compile error —
//  methods were defined both inside and outside the class.
// ============================================================
/*
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore/firestore_service.dart';

class PatientMonitoringRepository extends FirestoreService {
  Future<Patient?> getPatientStatus(String patientId) async {
    final doc = await getDocument<Patient?>(
      path: 'patients/\$patientId',
      builder: (data, _) => Patient.fromJson(data),
    );
    return doc ?? MockDataProvider.getMockPatient();
  }

  Stream<Patient?> getPatientStatusStream(String patientId) {
    return FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .snapshots()
        .map((doc) => doc.exists ? Patient.fromJson(doc.data()!) : null);
  }
  // ...
}
*/

extension StreamExtensions<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
