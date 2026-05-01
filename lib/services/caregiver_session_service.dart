import 'package:hive_flutter/hive_flutter.dart';

import '../models/caregiver_session.dart';

class CaregiverSessionService {
  static const String _boxName = 'caregiver_sessions';
  static const String _activeKey = 'active_session';
  static const String _emailIndexPrefix = 'email::';
  static const String _sessionPrefix = 'session::';

  Future<Box> _openBox() async =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : Hive.openBox(_boxName);

  Future<void> saveSession(CaregiverSession session) async {
    final box = await _openBox();
    await box.put('$_sessionPrefix${session.caregiverId}', session.toMap());
    if (session.caregiverEmail != null && session.caregiverEmail!.trim().isNotEmpty) {
      await box.put(
        '$_emailIndexPrefix${session.caregiverEmail!.trim().toLowerCase()}',
        session.caregiverId,
      );
    }
    await box.put(_activeKey, session.toMap());
  }

  Future<CaregiverSession?> getSessionByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final box = await _openBox();
    final caregiverId = box.get('$_emailIndexPrefix$normalized');
    if (caregiverId is! String) return null;
    final raw = box.get('$_sessionPrefix$caregiverId');
    if (raw is! Map) return null;
    return CaregiverSession.fromRouteArguments(Map<dynamic, dynamic>.from(raw));
  }

  Future<CaregiverSession?> getActiveSession() async {
    final box = await _openBox();
    final raw = box.get(_activeKey);
    if (raw is! Map) return null;
    return CaregiverSession.fromRouteArguments(Map<dynamic, dynamic>.from(raw));
  }

  Future<void> clearSession() async {
    final box = await _openBox();
    await box.delete(_activeKey);
  }
}
