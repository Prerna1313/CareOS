// ============================================================
// FIREBASE → HIVE MIGRATION
// AlertRepository now reads from Hive via AlertService.
// Demo data is seeded at startup via HiveDemoData.seedIfNeeded().
// ============================================================

import '../models/alert.dart';
import '../services/alert_service.dart';
import '../services/mock_data_provider.dart';

class AlertRepository {
  // Singleton pattern (same as before)
  static final AlertRepository _instance = AlertRepository._internal();
  factory AlertRepository() => _instance;
  AlertRepository._internal();

  final _service = AlertService();

  Future<List<Alert>> getActiveAlerts(String patientId) async {
    final alerts = await _service.getActiveAlerts(patientId);
    if (alerts.isNotEmpty) {
      return alerts;
    }
    return MockDataProvider.getMockAlerts(patientId: patientId);
  }

  Future<List<Alert>> getAlertHistory(String patientId) async {
    final alerts = await _service.getAlertHistory(patientId);
    if (alerts.isNotEmpty) {
      return alerts;
    }
    return const <Alert>[];
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await _service.acknowledgeAlert(alertId);
  }

  Future<void> resolveAlert(String alertId, String caregiverId) async {
    await _service.resolveAlert(alertId, caregiverId);
  }
}

// ============================================================
// ORIGINAL MOCK IMPLEMENTATION (commented out)
// ============================================================
/*
import '../services/mock_data_provider.dart';

class AlertRepository {
  static final AlertRepository _instance = AlertRepository._internal();
  factory AlertRepository() => _instance;
  AlertRepository._internal();

  final List<Alert> _mockAlerts = MockDataProvider.getMockAlerts();

  Future<List<Alert>> getActiveAlerts(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockAlerts
        .where((a) => a.patientId == patientId && a.status == AlertStatus.active)
        .toList();
  }
  // ...
}
*/
