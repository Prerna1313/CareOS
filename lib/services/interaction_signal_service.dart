import 'package:hive_flutter/hive_flutter.dart';

import '../models/interaction_signal.dart';

class InteractionSignalService {
  static const String boxName = 'interaction_signals';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box get _box => Hive.box(boxName);

  Future<void> logSignal(InteractionSignal signal) async {
    await _box.put(signal.id, signal.toMap());
  }

  List<InteractionSignal> getAllSignals() {
    final signals = _box.values
        .map((value) => InteractionSignal.fromMap(value))
        .toList();
    signals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return signals;
  }

  List<InteractionSignal> getByPatientId(String patientId) {
    return getAllSignals()
        .where((signal) => signal.patientId == patientId)
        .toList();
  }
}
