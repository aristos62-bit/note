// lib/services/reminder_bake_plan.dart
//
// Pure planning για OS notification bakes (E10/E35).
// Δεν αγγίζει Isar/plugin: δέχεται snapshots και επιστρέφει ΑΠΟΦΑΣΗ.
//
// Κανόνες:
// - oldest-first (triggerAt, id)
// - keep μόνο όταν το OS title/body ταιριάζει με το resolved text
// - replacement = υπάρχον OS id με stale text (δεν καταναλώνει νέο slot)
// - new = χωρίς OS id· μόνο όσα χωράνε στα ελεύθερα slots
// - cancel μόνο ό,τι είναι εκτός desired και ανήκει στο επιτρεπτό scope
// - ΠΟΤΕ eviction υπάρχοντος valid alarm για χάρη νέου

import '../models/models.dart';
import 'reminder_text.dart';

class OsReminderSnapshot {
  const OsReminderSnapshot({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;

  bool matches(ReminderNotificationText text) =>
      text.matches(title: title, body: body);
}

class ReminderBakePlan {
  const ReminderBakePlan({
    required this.cancelIds,
    required this.schedule,
    required this.keepIds,
    required this.desiredCount,
    required this.skippedCount,
    required this.truncated,
  });

  final List<int> cancelIds;
  final List<Reminder> schedule;
  final List<int> keepIds;
  final int desiredCount;
  final int skippedCount;
  final bool truncated;
}

ReminderBakePlan buildReminderBakePlan({
  required List<Reminder> rows,
  required Map<int, Item?> items,
  required Map<int, OsReminderSnapshot> osById,
  required int limit,
  required DateTime now,
  required bool incremental,
  Set<int>? cancelableOsIds,
  bool forceSchedule = false,
}) {
  final eligible = <Reminder>[];
  final seenIds = <int>{};
  var skipped = 0;

  for (final r in rows) {
    if (!seenIds.add(r.id)) {
      skipped++;
      continue;
    }
    if (r.status != ReminderStatus.pending) {
      skipped++;
      continue;
    }
    if (r.triggerAt.isBefore(now)) {
      skipped++;
      continue;
    }
    if (r.rrule != null && r.rrule!.isNotEmpty) {
      skipped++;
      continue;
    }
    final item = items[r.itemId];
    if (item == null ||
        item.archived ||
        item.isDeleted ||
        item.status == ItemStatus.done ||
        item.status == ItemStatus.cancelled) {
      skipped++;
      continue;
    }
    eligible.add(r);
  }

  eligible.sort((a, b) {
    final byTrigger = a.triggerAt.compareTo(b.triggerAt);
    if (byTrigger != 0) return byTrigger;
    return a.id.compareTo(b.id);
  });

  final desiredIds = <int>{for (final r in eligible) r.id};
  final cancelIds = <int>[];
  if (incremental && cancelableOsIds != null) {
    for (final id in cancelableOsIds) {
      if (osById.containsKey(id) && !desiredIds.contains(id)) {
        cancelIds.add(id);
      }
    }
    cancelIds.sort();
  }

  final osAfterCancel = osById.length - cancelIds.length;
  final osCount = osAfterCancel < 0 ? 0 : osAfterCancel;

  final keepIds = <int>[];
  final replacements = <Reminder>[];
  final newRows = <Reminder>[];

  for (final r in eligible) {
    final os = osById[r.id];
    final text = resolveReminderNotificationText(r, items[r.itemId]);
    if (os != null) {
      if (!forceSchedule && os.matches(text)) {
        keepIds.add(r.id);
      } else {
        replacements.add(r);
      }
    } else {
      newRows.add(r);
    }
  }

  final free = limit - osCount;
  final canAdd = free < 0 ? 0 : free;
  final newTake = newRows.take(canAdd).toList();
  final schedule = <Reminder>[...replacements, ...newTake]
    ..sort((a, b) {
      final byTrigger = a.triggerAt.compareTo(b.triggerAt);
      if (byTrigger != 0) return byTrigger;
      return a.id.compareTo(b.id);
    });

  return ReminderBakePlan(
    cancelIds: cancelIds,
    schedule: schedule,
    keepIds: keepIds,
    desiredCount: eligible.length,
    skippedCount: skipped,
    truncated: newRows.length > newTake.length,
  );
}
