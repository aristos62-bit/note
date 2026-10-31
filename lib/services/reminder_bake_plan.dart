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
// - habit OS-window (E45/A): τα habit-generated one-shots πάνε στο OS μόνο
//   για τις επόμενες 14 ημέρες (+ τις πρώτες 5 occurrences/item) — η DB
//   κρατά 60 και το topUp/resume ξαναγεμίζει καθώς περνά ο χρόνος.
// - ορίζοντας OS (S283): ΠΟΤΕ bake πέρα από [osHorizonDays] — κοινός κανόνας
//   για όλους τους callers (πριν τον είχε μόνο το `getPending`).

import '../models/models.dart';
import 'reminder_text.dart';

/// E45/A: πόσες ημέρες μπροστά κρατά το OS από τα habit-generated alarms.
///
/// 14 = **η ίδια αυτονομία** που έχει ήδη αποφασιστεί για τα daily recurring
/// (`refreshRecurringReminders`, `batchSize = 14` / A5: «με 5 το reminder
/// σταματούσε μετά 5 μέρες χωρίς άνοιγμα της εφαρμογής») — απλώς εκφρασμένη
/// σε ημέρες. Η DB κρατά 60 (`HabitService.horizonDays`), άρα καμία απώλεια
/// δεδομένων: το OS refill γίνεται με τον **υπάρχοντα** topUp.
const int habitOsHorizonDays = 14;

/// E45/A: safety rail — τουλάχιστον τόσες **occurrences** ανά habit μένουν
/// στο OS ανεξάρτητα από το παράθυρο.
///
/// Χωρίς αυτό, μια monthly συνήθεια (επόμενη εμφάνιση *έξω* από το 14ήμερο)
/// θα έμενε με **μηδέν** alarms μέχρι το επόμενο άνοιγμα της εφαρμογής =
/// σιωπηλή απώλεια λειτουργίας. 5 = ίδιο νούμερο με το A5 για
/// weekly/monthly/yearly (parity, όχι νέο κατώφλι).
const int habitMinOsAlarmsPerItem = 5;

/// S283 (E45 follow-up): ορίζοντας του OS σε ημέρες — **μία πηγή**.
///
/// Ίδιος αριθμός με το `getPending()` (`ReminderRepository.pendingHorizonDays`)
/// και τη Διάγνωση (iOS 64 / budget). Ό,τι είναι πιο πέρα **δεν μπαίνει ποτέ**
/// στο OS από **κανέναν** caller: πριν, το έκοβε μόνο το `getPending()`, ενώ το
/// `refreshRecurringReminders(bake: true)` έψηνε και τα πιο μακρινά children
/// (γενέθλια 2028-2031), που τα έσβηνε το επόμενο `cancelAll` του `scheduleAll`.
const int osHorizonDays = 370;

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
    required this.deferredCount,
    required this.beyondHorizonCount,
  });

  final List<int> cancelIds;
  final List<Reminder> schedule;
  final List<int> keepIds;
  final int desiredCount;
  final int skippedCount;
  final bool truncated;

  /// E45/A: habit rows που **αναβλήθηκαν** λόγω OS-window (μένουν στη DB,
  /// δεν μπαίνουν σε `schedule`/`desiredIds`). Δεν είναι skip/fail — είναι
  /// policy. Χωρίς αυτό το μέτρημα, η περικοπή θα φαινόταν σαν εξαφάνιση.
  final int deferredCount;

  /// S283: rows πέρα από τον ορίζοντα OS (`osHorizonDays`) — δεν μπαίνουν ποτέ
  /// στο plan (άρα ούτε στο OS). Δεν είναι skip/fail: μένουν στη DB.
  final int beyondHorizonCount;
}

/// E45/A: pure κανόνας του habit OS-window — **SPoT** του κανόνα, ώστε το
/// plan και το Diagnostics screen να δείχνουν το **ίδιο** αποτέλεσμα.
///
/// Είσοδος: rows **όπως θα έμπαιναν στο plan** (eligible: pending, μέλλον,
/// όχι archived/deleted/done) ταξινομημένα κατά `(triggerAt, id)`. Δεν κάνει
/// άλλο φιλτράρισμα και δεν αγγίζει Isar/plugin (pure).
///
/// Κρατά:
/// (α) ό,τι είναι **πριν** το cutoff — `DateTime(y, m, d + horizonDays)`,
///     δηλαδή τοπικό μεσάνυχτο, DST-safe (όχι `.add(Duration(days:))` που
///     γλιστρά ±1 ώρα στο όριο),
/// (β) τις πρώτες [minPerItem] occurrences κάθε habit item.
///
/// Το cutoff είναι **αποκλειστικό**: `triggerAt == cutoff` → deferred.
/// Non-habit rows δεν αγγίζονται ποτέ (κρατούν τον σημερινό ορίζοντα).
Set<int> habitDeferredIds({
  required List<Reminder> rows,
  required DateTime now,
  int horizonDays = habitOsHorizonDays,
  int minPerItem = habitMinOsAlarmsPerItem,
}) {
  if (rows.isEmpty) return const <int>{};
  final cutoff = DateTime(now.year, now.month, now.day + horizonDays);
  final seenPerItem = <int, int>{};
  final deferred = <int>{};
  for (final r in rows) {
    // Ίδιο predicate με το `_clearHabitGenerated` (habit-generated rows).
    if (r.title != habitGeneratedTitle) continue;
    final index = (seenPerItem[r.itemId] ?? 0) + 1;
    seenPerItem[r.itemId] = index;
    if (index > minPerItem && !r.triggerAt.isBefore(cutoff)) {
      deferred.add(r.id);
    }
  }
  return deferred;
}

/// S283: rows **πέρα** από τον ορίζοντα OS (`triggerAt >= now + horizonDays`).
///
/// Το cutoff είναι **αποκλειστικό** — ίδιος predicate με τη Διάγνωση
/// (`beyondOsHorizonIds`), ώστε η οθόνη και το plan να δείχνουν το ίδιο.
/// Δεν είναι σφάλμα: τα rows μένουν στη DB και μπαίνουν στο OS όταν μπουν
/// στον ορίζοντα (επόμενο cold start / topUp).
Set<int> beyondOsHorizonIds({
  required List<Reminder> rows,
  required DateTime now,
  int horizonDays = osHorizonDays,
}) {
  if (rows.isEmpty) return const <int>{};
  final end = now.add(Duration(days: horizonDays));
  return <int>{
    for (final r in rows)
      if (!r.triggerAt.isBefore(end)) r.id,
  };
}

/// S283: ποια rows **μπορεί** να βρίσκονται στο OS αυτή τη στιγμή;
///
/// Time-only κανόνας (δεν κοιτά item state — χρησιμοποιείται και για cancel
/// μετά από archive/delete): μέλλον **και** εντός ορίζοντα OS **και** όχι
/// habit-deferred. Είναι το ίδιο σύνολο που θα έψηνε το plan, άρα όλα τα
/// υπόλοιπα (π.χ. 93 από 120 habit rows) δεν χρειάζονται platform cancel.
Set<int> osSchedulableIds({
  required List<Reminder> rows,
  required DateTime now,
  int horizonDays = osHorizonDays,
}) {
  if (rows.isEmpty) return const <int>{};
  // Το `habitDeferredIds` απαιτεί σειρά (triggerAt, id) — ίδια με το plan.
  final sorted = [...rows]..sort((a, b) {
      final byTrigger = a.triggerAt.compareTo(b.triggerAt);
      if (byTrigger != 0) return byTrigger;
      return a.id.compareTo(b.id);
    });
  final beyond =
      beyondOsHorizonIds(rows: sorted, now: now, horizonDays: horizonDays);
  final deferred = habitDeferredIds(rows: sorted, now: now);
  return <int>{
    for (final r in sorted)
      if (r.triggerAt.isAfter(now) &&
          !beyond.contains(r.id) &&
          !deferred.contains(r.id))
        r.id,
  };
}

ReminderBakePlan buildReminderBakePlan({
  required List<Reminder> rows,
  required Map<int, Item?> items,
  required Map<int, OsReminderSnapshot> osById,
  required int limit,
  required DateTime now,
  required bool incremental,
  required bool habitOsWindow,
  Set<int>? cancelableOsIds,
  bool forceSchedule = false,
}) {
  final eligible = <Reminder>[];
  final seenIds = <int>{};
  var skipped = 0;
  var beyondHorizon = 0;
  final horizonEnd = now.add(const Duration(days: osHorizonDays));

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
    // S283: ποτέ bake πέρα από τον ορίζοντα OS (ίδιος κανόνας με getPending).
    if (!r.triggerAt.isBefore(horizonEnd)) {
      beyondHorizon++;
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

  // E45/A: habit OS-window. Ό,τι «αναβάλλεται» μένει στη DB και ξαναμπαίνει
  // στο OS όταν μπει στο παράθυρο (topUp/cold start), άρα δεν μετράει ούτε
  // στο desiredCount ούτε στο budget. Τα non-habit rows μένουν ως έχουν.
  final deferred = habitOsWindow
      ? habitDeferredIds(rows: eligible, now: now)
      : const <int>{};
  final wanted = deferred.isEmpty
      ? eligible
      : eligible.where((r) => !deferred.contains(r.id)).toList();

  final desiredIds = <int>{for (final r in wanted) r.id};
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

  for (final r in wanted) {
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
    desiredCount: wanted.length,
    skippedCount: skipped,
    truncated: newRows.length > newTake.length,
    deferredCount: deferred.length,
    beyondHorizonCount: beyondHorizon,
  );
}
