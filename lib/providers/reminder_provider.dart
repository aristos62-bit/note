// lib/providers/reminder_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder.dart';
import 'db_provider.dart';
import '../core/utils/debug_config.dart';

// ─────────────────────────────────────────────────────────────────
// Reminders
// ─────────────────────────────────────────────────────────────────

/// Pending reminders (επόμενες 7 μέρες)
final pendingRemindersProvider = FutureProvider<List<Reminder>>((ref) {
  return ref.watch(dbProvider).reminders.getPending();
});

/// Real‑time pending reminders (επόμενες 7 μέρες) – ενημερώνεται αυτόματα
final pendingRemindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final db = ref.watch(dbProvider);
  return db.reminders.watchPending();
});

/// Reminders ενός item
final itemRemindersProvider =
FutureProvider.family<List<Reminder>, int>((ref, itemId) {
  return ref.watch(dbProvider).reminders.getForItem(itemId);
});

// ─────────────────────────────────────────────────────────────────
// ReminderNotifier
// ─────────────────────────────────────────────────────────────────

class ReminderNotifier extends FamilyAsyncNotifier<List<Reminder>, int> {
  @override
  Future<List<Reminder>> build(int arg) {
    return ref.watch(dbProvider).reminders.getForItem(arg);
  }

  Future<void> create({
    required DateTime triggerAt,
    String? rrule,
    String? title,
    String? body,
  }) async {
    try {
      await ref.read(dbProvider).reminders.create(
        itemId: arg,
        triggerAt: triggerAt,
        rrule: rrule,
        title: title,
        body: body,
      );
      ref.invalidateSelf();
      ref.invalidate(pendingRemindersProvider);
    } catch (e, s) {
      DebugConfig.error('ReminderNotifier.create', e, s);
    }
  }

  Future<void> snooze(int reminderId, Duration duration) async {
    try {
      await ref.read(dbProvider).reminders.snooze(reminderId, duration);
      ref.invalidateSelf();
      ref.invalidate(pendingRemindersProvider);
    } catch (e, s) {
      DebugConfig.error('ReminderNotifier.snooze', e, s);
    }
  }

  Future<void> delete(int reminderId) async {
    try {
      await ref.read(dbProvider).reminders.delete(reminderId);
      ref.invalidateSelf();
      ref.invalidate(pendingRemindersProvider);
    } catch (e, s) {
      DebugConfig.error('ReminderNotifier.delete', e, s);
    }
  }

  Future<void> markSent(int reminderId) async {
    try {
      await ref.read(dbProvider).reminders.markSent(reminderId);
      ref.invalidateSelf();
      ref.invalidate(pendingRemindersProvider);
    } catch (e, s) {
      DebugConfig.error('ReminderNotifier.markSent', e, s);
    }
  }
}

final reminderNotifierProvider =
AsyncNotifierProviderFamily<ReminderNotifier, List<Reminder>, int>(
  ReminderNotifier.new,
);