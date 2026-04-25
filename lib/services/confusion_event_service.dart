import 'package:hive_flutter/hive_flutter.dart';
import '../models/confusion_event.dart';

class ConfusionEventService {
  static const String _boxName = 'confusion_events';
  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  Future<void> logEvent(ConfusionEvent event) async {
    await _box.put(event.id, event.toMap());
  }

  List<ConfusionEvent> getAllEvents() {
    final events = _box.values.map((e) {
      return ConfusionEvent.fromMap(Map<String, dynamic>.from(e));
    }).toList();
    
    // Sort latest first
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  /// Returns the most recent trigger timestamp for a given patient.
  /// If no events exist, returns null.
  DateTime? getLastTriggerTime(String patientId) {
    final events = getAllEvents().where((e) => e.patientId == patientId).toList();
    if (events.isEmpty) return null;
    
    // Already sorted latest first
    return events.first.timestamp;
  }
}
