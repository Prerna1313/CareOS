import 'package:flutter/foundation.dart';
import 'firestore/firestore_daily_checkin_service.dart';
import 'firestore/firestore_memory_service.dart';
import 'firestore/firestore_event_service.dart';
import 'daily_checkin_service.dart';
import 'memory_service.dart';
import 'confusion_event_service.dart';
import 'event_log_service.dart';

class SyncService {
  final FirestoreDailyCheckinService _firestoreDailyService;
  final FirestoreMemoryService _firestoreMemoryService;
  final FirestoreEventService _firestoreEventService;

  final DailyCheckinService _localDailyService;
  final MemoryService _localMemoryService;
  final ConfusionEventService _localConfusionService;
  final EventLogService _localEventLogService;

  SyncService({
    required FirestoreDailyCheckinService firestoreDailyService,
    required FirestoreMemoryService firestoreMemoryService,
    required FirestoreEventService firestoreEventService,
    required DailyCheckinService localDailyService,
    required MemoryService localMemoryService,
    required ConfusionEventService localConfusionService,
    required EventLogService localEventLogService,
  }) : _firestoreDailyService = firestoreDailyService,
       _firestoreMemoryService = firestoreMemoryService,
       _firestoreEventService = firestoreEventService,
       _localDailyService = localDailyService,
       _localMemoryService = localMemoryService,
       _localConfusionService = localConfusionService,
       _localEventLogService = localEventLogService;

  Future<void> syncAll() async {
    debugPrint('Starting cloud sync...');
    try {
      await Future.wait([_syncDailyCheckins(), _syncMemories(), _syncEvents()]);
      debugPrint('Sync completed successfully.');
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  Future<void> _syncDailyCheckins() async {
    final remoteEntries = await _firestoreDailyService.getAllDailyEntries();
    for (final entry in remoteEntries) {
      final localEntry = _localDailyService.getEntryByDate(entry.date);
      if (localEntry == null) {
        // Missing locally, save it
        await _localDailyService.saveDailyEntry(entry);
      } else {
        // Both exist. In a real app, we'd compare lastUpdated.
        // For now, remote wins if local is empty/minimal (placeholder sync)
        if (localEntry.summary.isEmpty && entry.summary.isNotEmpty) {
          await _localDailyService.saveDailyEntry(entry);
        }
      }
    }

    // Reverse sync: upload local entries that are missing in remote
    final localEntries = _localDailyService.getAllEntries();
    for (final entry in localEntries) {
      // This is simplified; ideally we'd track what's already synced
      await _firestoreDailyService.syncDailyEntry(entry);
    }
  }

  Future<void> _syncMemories() async {
    final remoteMemories = await _firestoreMemoryService.getAllMemories();
    final localMemories = _localMemoryService.getAllMemories();

    final localIds = localMemories.map((m) => m.id).toSet();

    for (final memory in remoteMemories) {
      if (!localIds.contains(memory.id)) {
        await _localMemoryService.addMemory(memory);
      }
    }

    // Upload local-only memories
    final remoteIds = remoteMemories.map((m) => m.id).toSet();
    for (final memory in localMemories) {
      if (!remoteIds.contains(memory.id)) {
        await _firestoreMemoryService.syncMemoryItem(memory);
      }
    }
  }

  Future<void> _syncEvents() async {
    // Confusion Events
    final remoteConfusion = await _firestoreEventService
        .getAllConfusionEvents();
    final localConfusion = _localConfusionService.getAllEvents();
    final localConfusionIds = localConfusion.map((e) => e.id).toSet();

    for (final event in remoteConfusion) {
      if (!localConfusionIds.contains(event.id)) {
        await _localConfusionService.logEvent(event);
      }
    }

    final remoteConfusionIds = remoteConfusion.map((e) => e.id).toSet();
    for (final event in localConfusion) {
      if (!remoteConfusionIds.contains(event.id)) {
        await _firestoreEventService.syncConfusionEvent(event);
      }
    }

    // Reminder Logs
    final remoteLogs = await _firestoreEventService.getAllReminderLogs();
    final localLogs = _localEventLogService.getAllEvents();
    final localLogIds = localLogs.map((e) => e.id).toSet();

    for (final log in remoteLogs) {
      if (!localLogIds.contains(log.id)) {
        await _localEventLogService.logEvent(log);
      }
    }

    final remoteLogIds = remoteLogs.map((e) => e.id).toSet();
    for (final log in localLogs) {
      if (!remoteLogIds.contains(log.id)) {
        await _firestoreEventService.syncReminderLog(log);
      }
    }
  }
}
