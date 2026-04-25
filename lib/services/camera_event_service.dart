import 'package:hive_flutter/hive_flutter.dart';
import '../models/camera_event.dart';

class CameraEventService {
  static const String boxName = 'camera_events';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box get _box => Hive.box(boxName);

  Future<void> logEvent(CameraEvent event) async {
    await _box.put(event.id, event.toMap());
  }

  Future<void> updateEvent(CameraEvent event) async {
    await _box.put(event.id, event.toMap());
  }

  List<CameraEvent> getAllEvents() {
    return _box.values
        .map((m) => CameraEvent.fromMap(m))
        .toList();
  }

  Future<void> clearEvents() async {
    await _box.clear();
  }
}
