import 'package:hive_flutter/hive_flutter.dart';
import '../models/my_day/daily_checkin_entry.dart';

class DailyCheckinService {
  static const String _boxName = 'daily_checkins';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  String _generateKey(DateTime date) {
    return "${date.year}-${date.month}-${date.day}";
  }

  Future<void> saveDailyEntry(DailyCheckinEntry entry) async {
    final key = _generateKey(entry.date);
    await _box.put(key, entry.toMap());
  }

  DailyCheckinEntry? getEntryByDate(DateTime date) {
    final key = _generateKey(date);
    final data = _box.get(key);
    if (data == null) return null;
    return DailyCheckinEntry.fromMap(data);
  }

  List<DailyCheckinEntry> getAllEntries() {
    return _box.values
        .map((data) => DailyCheckinEntry.fromMap(data))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Latest first
  }

  Future<void> updateEntry(DailyCheckinEntry entry) async {
    await saveDailyEntry(entry);
  }
}
