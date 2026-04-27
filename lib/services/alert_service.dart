// ============================================================
// Simple Alert Service — Hive-based
// Stores and retrieves alerts from 'alerts' Hive box.
// Note: Alert model uses toJson()/fromJson() (not toMap()).
// ============================================================

import 'package:hive_flutter/hive_flutter.dart';
import '../models/alert.dart';

class AlertService {
  static const String _boxName = 'alerts';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<void> addAlert(Alert alert) async {
    final box = await Hive.openBox(_boxName);
    await box.put(alert.id, alert.toJson());
  }

  Future<List<Alert>> getAllAlerts() async {
    final box = await Hive.openBox(_boxName);
    final items = box.values.toList();
    final alerts = items
        .map((e) => Alert.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alerts;
  }

  Future<List<Alert>> getActiveAlerts(String patientId) async {
    final all = await getAllAlerts();
    return all
        .where(
            (a) => a.patientId == patientId && a.status == AlertStatus.active)
        .toList();
  }

  Future<List<Alert>> getAlertHistory(String patientId) async {
    final all = await getAllAlerts();
    return all
        .where(
            (a) => a.patientId == patientId && a.status != AlertStatus.active)
        .toList();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(alertId);
    if (raw == null) return;

    final alert = Alert.fromJson(Map<String, dynamic>.from(raw as Map));
    final updated = alert.copyWith(status: AlertStatus.acknowledged);
    await box.put(alertId, updated.toJson());
  }

  Future<void> resolveAlert(String alertId, String caregiverId) async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(alertId);
    if (raw == null) return;

    final alert = Alert.fromJson(Map<String, dynamic>.from(raw as Map));
    final updated = alert.copyWith(
      status: AlertStatus.resolved,
      resolvedBy: caregiverId,
      resolvedAt: DateTime.now(),
    );
    await box.put(alertId, updated.toJson());
  }

  Future<void> deleteAlert(String alertId) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(alertId);
  }
}
