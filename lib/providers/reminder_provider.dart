// lib/providers/reminder_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder.dart';
import 'db_provider.dart';

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
    await ref.read(dbProvider).reminders.create(
      itemId: arg,
      triggerAt: triggerAt,
      rrule: rrule,
      title: title,
      body: body,
    );
    ref.invalidateSelf();
    // Ενημέρωσε και τα pending
    ref.invalidate(pendingRemindersProvider);
  }

  Future<void> snooze(int reminderId, Duration duration) async {
    await ref.read(dbProvider).reminders.snooze(reminderId, duration);
    ref.invalidateSelf();
    ref.invalidate(pendingRemindersProvider);
  }

  Future<void> delete(int reminderId) async {
    await ref.read(dbProvider).reminders.delete(reminderId);
    ref.invalidateSelf();
    ref.invalidate(pendingRemindersProvider);
  }

  Future<void> markSent(int reminderId) async {
    await ref.read(dbProvider).reminders.markSent(reminderId);
    ref.invalidateSelf();
    ref.invalidate(pendingRemindersProvider);
  }
}

final reminderNotifierProvider =
AsyncNotifierProviderFamily<ReminderNotifier, List<Reminder>, int>(
  ReminderNotifier.new,
);