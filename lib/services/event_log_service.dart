import 'package:hive_flutter/hive_flutter.dart';
import '../models/reminder_log.dart';

class EventLogService {
  static const String _boxName = 'event_logs';
  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  Future<void> logEvent(ReminderLog log) async {
    await _box.put(log.id, log.toMap());
  }

  List<ReminderLog> getAllEvents() {
    final events = _box.values.map((e) {
      return ReminderLog.fromMap(Map<String, dynamic>.from(e));
    }).toList();
    
    // Sort latest first
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  List<ReminderLog> getEventsByReminderId(String id) {
    return getAllEvents().where((event) => event.reminderId == id).toList();
  }
}
