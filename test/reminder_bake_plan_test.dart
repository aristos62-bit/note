import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/services/reminder_bake_plan.dart';
import 'package:super_note/services/reminder_text.dart';

final _now = DateTime(2030, 1, 1, 8);

Item _item({
  int id = 1,
  ItemType type = ItemType.note,
  String? title = 'Item',
  bool archived = false,
  ItemStatus status = ItemStatus.active,
  DateTime? deletedAt,
}) {
  return Item()
    ..id = id
    ..workspaceId = 1
    ..type = type
    ..title = title
    ..archived = archived
    ..status = status
    ..deletedAt = deletedAt;
}

Reminder _reminder({
  required int id,
  int itemId = 1,
  int minutes = 60,
  String? title = 'Υπενθύμιση',
  String? body = 'Παλιό',
  ReminderStatus status = ReminderStatus.pending,
  String? rrule,
}) {
  return Reminder()
    ..id = id
    ..itemId = itemId
    ..triggerAt = _now.add(Duration(minutes: minutes))
    ..title = title
    ..body = body
    ..status = status
    ..rrule = rrule;
}

OsReminderSnapshot _os(Reminder r, Item? item) {
  final text = resolveReminderNotificationText(r, item);
  return OsReminderSnapshot(
    id: r.id,
    title: text.title,
    body: text.body,
    payload: r.itemId.toString(),
  );
}

void main() {
  group('buildReminderBakePlan', () {
    test('full bake is oldest-first and truncates at limit', () {
      final rows = [
        _reminder(id: 3, minutes: 180),
        _reminder(id: 1, minutes: 60),
        _reminder(id: 2, minutes: 120),
      ];
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: _item()},
        osById: const {},
        limit: 2,
        now: _now,
        incremental: false,
        habitOsWindow: false,
      );
      expect(plan.cancelIds, isEmpty);
      expect(plan.schedule.map((r) => r.id), [1, 2]);
      expect(plan.truncated, isTrue);
      expect(plan.desiredCount, 3);
    });

    test('incremental keeps matching text, replaces stale, adds free slots', () {
      final rows = [
        _reminder(id: 1, minutes: 60),
        _reminder(id: 2, minutes: 120),
        _reminder(id: 3, minutes: 180),
      ];
      final item = _item(title: 'Νέο');
      final os = {
        1: _os(rows[0], item),
        2: const OsReminderSnapshot(
            id: 2, title: 'Υπενθύμιση', body: 'Παλιό'),
      };
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: item},
        osById: os,
        limit: 3,
        now: _now,
        incremental: true,
        habitOsWindow: false,
      );
      expect(plan.keepIds, [1]);
      expect(plan.schedule.map((r) => r.id), [2, 3]);
      expect(plan.truncated, isFalse);
    });

    test('never evicts a valid alarm when OS is full', () {
      final rows = [
        _reminder(id: 1, minutes: 60),
        _reminder(id: 2, minutes: 120),
        _reminder(id: 3, minutes: 180),
      ];
      final item = _item(title: 'Νέο');
      final os = {
        1: _os(rows[0], item),
        2: _os(rows[1], item),
      };
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: item},
        osById: os,
        limit: 2,
        now: _now,
        incremental: true,
        habitOsWindow: false,
      );
      expect(plan.keepIds, [1, 2]);
      expect(plan.schedule, isEmpty);
      expect(plan.truncated, isTrue);
    });

    test('cancels only stale OS ids inside the allowed scope', () {
      final rows = [_reminder(id: 1, minutes: 60)];
      final item = _item(title: 'Νέο');
      final os = {
        1: _os(rows[0], item),
        2: const OsReminderSnapshot(id: 2, title: 'Παλιό', body: 'Παλιό'),
      };
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: item},
        osById: os,
        limit: 60,
        now: _now,
        incremental: true,
        habitOsWindow: false,
        cancelableOsIds: {2},
      );
      expect(plan.cancelIds, [2]);
      expect(plan.keepIds, [1]);
      expect(plan.schedule, isEmpty);
    });

    test('archived/done/orphan rows are skipped', () {
      final rows = [
        _reminder(id: 1, itemId: 1),
        _reminder(id: 2, itemId: 2),
        _reminder(id: 3, itemId: 3),
      ];
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {
          1: _item(id: 1, archived: true),
          2: _item(id: 2, status: ItemStatus.done),
        },
        osById: const {},
        limit: 60,
        now: _now,
        incremental: false,
        habitOsWindow: false,
      );
      expect(plan.desiredCount, 0);
      expect(plan.skippedCount, 3);
      expect(plan.schedule, isEmpty);
    });

    test('forceSchedule replaces matching OS rows without consuming a slot', () {
      final rows = [_reminder(id: 1), _reminder(id: 2, minutes: 120)];
      final item = _item(title: 'Νέο');
      final os = {1: _os(rows[0], item)};
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: item},
        osById: os,
        limit: 1,
        now: _now,
        incremental: true,
        habitOsWindow: false,
        forceSchedule: true,
      );
      expect(plan.keepIds, isEmpty);
      expect(plan.schedule.map((r) => r.id), [1]);
      expect(plan.truncated, isTrue);
    });

    test('recurring roots and past rows are not scheduled', () {
      final plan = buildReminderBakePlan(
        rows: [
          _reminder(id: 1, rrule: 'FREQ=DAILY'),
          _reminder(id: 2, minutes: -10),
        ],
        items: {1: _item()},
        osById: const {},
        limit: 60,
        now: _now,
        incremental: false,
        habitOsWindow: false,
      );
      expect(plan.desiredCount, 0);
      expect(plan.schedule, isEmpty);
    });
  });

  // ── E45/A: habit OS-window ──────────────────────────────────────────
  group('habit OS window (E45/A)', () {
    /// Λεπτά από το `_now` μέχρι το **αποκλειστικό** cutoff: +14 ημέρες από
    /// το μεσάνυχτο της 01/01/2030 = 15/01/2030 00:00, δηλαδή 13ημ 16ω.
    const cutoffMinutes = 13 * 1440 + 960; // 19680

    Reminder habit(int id, int minutes, {int itemId = 1}) => _reminder(
          id: id,
          itemId: itemId,
          minutes: minutes,
          title: habitGeneratedTitle,
          body: 'Υπενθύμιση: Συνήθεια',
        );

    Item habitItem({int id = 1}) =>
        _item(id: id, type: ItemType.habit, title: 'Συνήθεια');

    test('flag off → ίδιο plan (regression guard)', () {
      final rows = [habit(1, 30000), habit(2, 40000), habit(3, 50000)];
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: false,
      );
      expect(plan.desiredCount, 3);
      expect(plan.deferredCount, 0);
      expect(plan.schedule.map((r) => r.id), [1, 2, 3]);
    });

    test('habit row μέσα στο παράθυρο κρατιέται', () {
      final plan = buildReminderBakePlan(
        rows: [habit(1, 60)],
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(plan.desiredCount, 1);
      expect(plan.deferredCount, 0);
      expect(plan.schedule.single.id, 1);
    });

    test('habit row έξω → deferred (όχι skip, όχι schedule)', () {
      // index 6: τα πρώτα 5 τα κρατά το rail, το 6ο (έξω) αναβάλλεται.
      final plan = buildReminderBakePlan(
        rows: [
          for (var i = 1; i <= 5; i++) habit(i, i * 60),
          habit(6, 14 * 1440),
        ],
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(plan.desiredCount, 5);
      expect(plan.deferredCount, 1);
      expect(plan.skippedCount, 0);
      expect(plan.schedule.map((r) => r.id), [1, 2, 3, 4, 5]);
      expect(plan.truncated, isFalse);
    });

    test('non-habit row έξω από το παράθυρο κρατιέται', () {
      final plan = buildReminderBakePlan(
        rows: [_reminder(id: 1, minutes: 40 * 1440)],
        items: {1: _item()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(plan.desiredCount, 1);
      expect(plan.deferredCount, 0);
      expect(plan.schedule.single.id, 1);
    });

    test('min-5 rail: sparse habit κρατά 5 occurrences, οι άλλες deferred', () {
      final plan = buildReminderBakePlan(
        rows: [for (var i = 0; i < 7; i++) habit(i + 1, 14 * 1440 + i * 1440)],
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(plan.desiredCount, 5);
      expect(plan.deferredCount, 2);
      expect(plan.schedule.map((r) => r.id), [1, 2, 3, 4, 5]);

      // <5 occurrences όλες έξω → καμία αναβολή (καμία σιωπή).
      final sparse = buildReminderBakePlan(
        rows: [for (var i = 0; i < 4; i++) habit(i + 1, 20 * 1440 + i)],
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(sparse.desiredCount, 4);
      expect(sparse.deferredCount, 0);
    });

    test('budget: 900 habit + 56 non-habit → χωρίς truncation', () {
      final rows = <Reminder>[];
      for (var item = 1; item <= 4; item++) {
        for (var i = 0; i < 225; i++) {
          rows.add(habit(item * 1000 + i, 60 + i * 380, itemId: item));
        }
      }
      for (var i = 0; i < 56; i++) {
        rows.add(_reminder(id: 9000 + i, itemId: 900, minutes: 30 + i));
      }
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {
          for (var item = 1; item <= 4; item++) item: habitItem(id: item),
          900: _item(id: 900, title: 'Ραντεβού'),
        },
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      // 4 × 52 habit occurrences μέσα στο 14ήμερο + 56 non-habit.
      expect(plan.desiredCount, 264);
      expect(plan.deferredCount, 692);
      expect(plan.schedule.length, 264);
      expect(plan.truncated, isFalse);
    });

    test('όριο: triggerAt == cutoff → deferred, cutoff-1ms → kept', () {
      // index 6 (τα πρώτα 5 είναι μέσα) ώστε να μη «σώζεται» από το rail.
      final base = [for (var i = 1; i <= 5; i++) habit(i, i * 60)];
      final atCutoff = buildReminderBakePlan(
        rows: [...base, habit(6, cutoffMinutes)],
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(atCutoff.deferredCount, 1);
      expect(atCutoff.desiredCount, 5);

      final justInside = buildReminderBakePlan(
        rows: [...base, habit(6, cutoffMinutes - 1)],
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(justInside.deferredCount, 0);
      expect(justInside.desiredCount, 6);
    });
  });

  group('S283 — ορίζοντας OS', () {
    // `_now` = 01/01/2030 08:00 → cutoff = +370 ημέρες (Duration, όπως στο plan).
    const dayMin = 1440;
    const horizonMin = osHorizonDays * dayMin;

    Reminder habit(int id, int minutes, {int itemId = 1}) => _reminder(
          id: id,
          itemId: itemId,
          minutes: minutes,
          title: habitGeneratedTitle,
          body: 'Υπενθύμιση: Συνήθεια',
        );

    Item habitItem({int id = 1}) =>
        _item(id: id, type: ItemType.habit, title: 'Συνήθεια');

    test('plan: rows πέρα από τον ορίζοντα δεν ψήνονται (beyond, όχι skip)', () {
      final rows = [
        _reminder(id: 1, minutes: 60),
        _reminder(id: 2, minutes: horizonMin - 1),
        _reminder(id: 3, minutes: horizonMin), // == cutoff → έξω
        _reminder(id: 4, minutes: horizonMin + 60),
      ];
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: _item()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(plan.beyondHorizonCount, 2);
      expect(plan.skippedCount, 0);
      expect(plan.desiredCount, 2);
      expect(plan.schedule.map((r) => r.id), [1, 2]);
    });

    test('plan: habit πέρα από ορίζοντα δεν μπαίνει στο OS (ούτε μέσω rail)',
        () {
      // 1-5 εντός 14ημέρου (κρατιούνται), 6-11 πέρα από το 14ήμερο (deferred),
      // 12 πέρα από τον ορίζοντα 370ημ. → beyond (όχι deferred).
      final rows = [
        for (var i = 1; i <= 5; i++) habit(i, i * dayMin),
        for (var i = 6; i <= 11; i++) habit(i, i * 4 * dayMin),
        habit(12, horizonMin + dayMin),
      ];
      final plan = buildReminderBakePlan(
        rows: rows,
        items: {1: habitItem()},
        osById: const {},
        limit: 450,
        now: _now,
        incremental: false,
        habitOsWindow: true,
      );
      expect(plan.beyondHorizonCount, 1);
      expect(plan.deferredCount, 6);
      expect(plan.desiredCount, 5);
      expect(plan.schedule.map((r) => r.id), [1, 2, 3, 4, 5]);
    });

    test('beyondOsHorizonIds: αποκλειστικό cutoff (== cutoff ανήκει στο beyond)',
        () {
      final rows = [
        _reminder(id: 1, minutes: horizonMin - 1),
        _reminder(id: 2, minutes: horizonMin),
        _reminder(id: 3, minutes: horizonMin + dayMin),
      ];
      expect(beyondOsHorizonIds(rows: rows, now: _now), {2, 3});
    });

    test('osSchedulableIds: μέλλον ∧ εντός ορίζοντα ∧ όχι deferred', () {
      final rows = [
        _reminder(id: 1, minutes: -60), // παρελθόν
        habit(2, 1 * dayMin), // index 1 → μέσα
        habit(3, 2 * dayMin), // index 2 → μέσα
        habit(4, 3 * dayMin), // index 3 → μέσα
        habit(5, 4 * dayMin), // index 4 → μέσα
        habit(6, 5 * dayMin), // index 5 (rail) → μέσα
        habit(7, 20 * dayMin), // index 6 + εκτός 14ημ. → deferred
        _reminder(id: 8, minutes: horizonMin + dayMin), // πέρα από ορίζοντα
        _reminder(id: 9, minutes: 120), // εντός ορίζοντα
      ];
      expect(osSchedulableIds(rows: rows, now: _now), {2, 3, 4, 5, 6, 9});
    });

    test('cancel scope: 120 daily habit rows → μόνο το 14ήμερο (27-28)', () {
      // Ό,τι είδε το device (T6): 120 OS cancel calls για 27 alarms.
      final rows = [
        for (var d = 0; d < 60; d++) ...[
          habit(d * 2 + 1, d * dayMin + 105), // 09:45
          habit(d * 2 + 2, d * dayMin + 645), // 18:45
        ],
      ];
      final ids = osSchedulableIds(rows: rows, now: _now);
      expect(rows.length, 120);
      expect(ids.length, 28); // 14 ημέρες × 2 ώρες
      expect(ids.contains(1), isTrue);
      expect(ids.contains(29), isFalse); // 15η ημέρα → deferred
      expect(ids.contains(120), isFalse); // 60ή ημέρα → deferred
    });
  });
}
