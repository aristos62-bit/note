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
      );
      expect(plan.desiredCount, 0);
      expect(plan.schedule, isEmpty);
    });
  });
}
