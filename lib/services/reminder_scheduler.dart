// lib/services/reminder_scheduler.dart
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';
import '../core/core.dart';
import 'package:isar/isar.dart';
import 'dart:async';

class ReminderScheduler {
  ReminderScheduler._internal();
  static final ReminderScheduler instance = ReminderScheduler._internal();
  Timer? _refreshTimer;

  Future<void> scheduleAll() async {
    DebugConfig.notif('ReminderScheduler.scheduleAll: called, platform=$defaultTargetPlatform');
    if (![
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ].contains(defaultTargetPlatform)) {
      DebugConfig.notif('ReminderScheduler.scheduleAll: platform not supported, skipping');
      return;
    }

    final settings = await SuperNoteHelper.instance.settings.get();
    DebugConfig.notif('ReminderScheduler.scheduleAll: notificationsEnabled=${settings.notificationsEnabled}');
    if (!settings.notificationsEnabled) return;

    await NotificationService.instance.cancelAll();
    DebugConfig.notif('ReminderScheduler.scheduleAll: cancelAll done');

    final pending = await SuperNoteHelper.instance.reminders.getPending();
    DebugConfig.notif('ReminderScheduler.scheduleAll: found ${pending.length} pending reminders');
    for (final r in pending) {
      DebugConfig.notif('  pending: id=${r.id} trigger=${r.triggerAt} status=${r.status.name} itemId=${r.itemId}');
    }

    for (final reminder in pending) {
      await _scheduleOne(
        reminder,
        sound:     settings.soundEnabled,
        vibration: settings.vibrationEnabled,
      );
    }
    DebugConfig.notif('ReminderScheduler.scheduleAll: DONE');
  }


  // ─────────────────────────────────────────────────────────
  // Debounced version for lifecycle events
  // ─────────────────────────────────────────────────────────

  Future<void> debouncedRefreshRecurringReminders({Duration delay = const Duration(seconds: 2)}) async {
    DebugConfig.notif('ReminderScheduler.debouncedRefreshRecurringReminders: called, delay=$delay');
    _refreshTimer?.cancel();
    _refreshTimer = Timer(delay, () async {
      DebugConfig.notif('ReminderScheduler.debouncedRefreshRecurringReminders: executing actual refresh');
      await refreshRecurringReminders();
    });
  }

  // ─────────────────────────────────────────────────────────
  // Ανανέωση επαναλαμβανόμενων υπενθυμίσεων (batch logic)
  // ─────────────────────────────────────────────────────────

  Future<void> refreshRecurringReminders() async {
    DebugConfig.notif('ReminderScheduler.refreshRecurringReminders: started');
    final settings = await SuperNoteHelper.instance.settings.get();
    if (!settings.notificationsEnabled) {
      DebugConfig.notif('refreshRecurringReminders: notifications disabled, skipping');
      return;
    }

    // ΜΟΝΟ ρίζες: έχουν rrule και parentReminderId == null
    final allRecurring = await SuperNoteHelper.instance.isar.reminders
        .filter()
        .rruleIsNotNull()
        .and()
        .not()
        .rruleEqualTo('')
        .parentReminderIdIsNull()
        .findAll();

    DebugConfig.notif('Found ${allRecurring.length} recurring root reminders');
    final now = DateTime.now();
    int createdTotal = 0;

    for (final root in allRecurring) {
      final rrule = root.rrule!;
      if (rrule.isEmpty) continue;

      final recurrence = rruleToRecurrence(rrule);
      if (recurrence == null) {
        DebugConfig.notif('Root ${root.id}: invalid rrule="$rrule", skipping');
        continue;
      }

      // 1. Έλεγξε αν ο root έχει ήδη παιδιά στο μέλλον (ενεργό batch)
      final futureChildren = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .parentReminderIdEqualTo(root.id)
          .triggerAtGreaterThan(now, include: true)
          .findAll();

      if (futureChildren.isNotEmpty) {
        // ✅ Έλεγχος αν τα παιδιά έχουν σωστή ώρα (ίδια με το root trigger)
        final wrongTimeChildren = futureChildren.where((child) =>
        child.triggerAt.hour != root.triggerAt.hour ||
            child.triggerAt.minute != root.triggerAt.minute
        ).toList();

        if (wrongTimeChildren.isEmpty) {
          DebugConfig.notif(
            'Root ${root.id}: has ${futureChildren.length} future children with correct time, skipping',
          );
          continue;
        }

        // Υπάρχουν παιδιά με λάθος ώρα → διέγραψε τα
        DebugConfig.notif(
          'Root ${root.id}: found ${wrongTimeChildren.length} children with wrong trigger time, cleaning up',
        );
        for (final wrongChild in wrongTimeChildren) {
          DebugConfig.notif(
            '  Deleting wrong child id=${wrongChild.id} trigger=${wrongChild.triggerAt} (expected hour=${root.triggerAt.hour}:${root.triggerAt.minute})',
          );
          await NotificationService.instance.cancel(wrongChild.id);
          await SuperNoteHelper.instance.isar.writeTxn(() async {
            await SuperNoteHelper.instance.isar.reminders.delete(wrongChild.id);
          });
        }

        // Αν υπάρχουν ακόμα σωστά παιδιά, skip
        final correctChildren = futureChildren.where((child) =>
        child.triggerAt.hour == root.triggerAt.hour &&
            child.triggerAt.minute == root.triggerAt.minute
        ).toList();
        if (correctChildren.isNotEmpty) {
          DebugConfig.notif(
            'Root ${root.id}: still has ${correctChildren.length} correct children, skipping batch creation',
          );
          continue;
        }
      }

      // 2. Δεν υπάρχουν future children → δημιούργησε νέο batch
      const batchSize = 2;
      final List<DateTime> nextOccurrences = [];

      // ✅ Χρησιμοποιούμε την ώρα του root trigger αντί για now
      // ώστε τα παιδιά να έχουν πάντα τη σωστή ώρα (π.χ. 20:30)
      final rootHour   = root.triggerAt.hour;
      final rootMinute = root.triggerAt.minute;
      final rootSecond = root.triggerAt.second;

      final todayAtTriggerTime = DateTime(
        now.year, now.month, now.day,
        rootHour, rootMinute, rootSecond,
      );

      // Αν η σημερινή ώρα trigger δεν έχει περάσει ακόμα → ξεκινάμε από χθες
      // ώστε nextOccurrence να επιστρέψει σήμερα στη σωστή ώρα
      final DateTime start;
      if (todayAtTriggerTime.isAfter(now)) {
        start = todayAtTriggerTime.subtract(Duration(days: recurrence.interval));
      } else {
        start = todayAtTriggerTime;
      }

      DateTime current = start;
      while (nextOccurrences.length < batchSize) {
        final next = recurrence.nextOccurrence(current);
        if (next == null) break;
        nextOccurrences.add(next);
        current = next.add(const Duration(seconds: 1));
      }

      if (nextOccurrences.isEmpty) {
        DebugConfig.notif('Root ${root.id}: no future occurrences from rrule, deleting thread');
        await deleteReminderThread(root.id);
        continue;
      }

      int createdForRoot = 0;

      for (final occ in nextOccurrences) {
        // Safety: αν για κάποιο λόγο έχει δημιουργηθεί ήδη child με αυτή την ώρα, μην το διπλο-δημιουργήσεις
        final existingChild = await SuperNoteHelper.instance.isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .triggerAtEqualTo(occ)
            .findFirst();

        if (existingChild != null) {
          DebugConfig.notif('Root ${root.id}: child already exists at $occ, skipping');
          continue;
        }

        final child = Reminder()
          ..itemId = root.itemId
          ..triggerAt = occ
          ..rrule = null          // τα παιδιά είναι one-shot
          ..title = root.title
          ..body = root.body
          ..status = ReminderStatus.pending
          ..parentReminderId = root.id
          ..createdAt = DateTime.now();

        await SuperNoteHelper.instance.isar.writeTxn(() async {
          await SuperNoteHelper.instance.isar.reminders.put(child);
        });

        await scheduleReminder(child);
        createdForRoot++;
        createdTotal++;
        DebugConfig.notif('Created child reminder ${child.id} for root ${root.id} at $occ');
      }

      DebugConfig.notif('Root ${root.id}: created $createdForRoot new children in this batch');
    }

    DebugConfig.notif('refreshRecurringReminders: created $createdTotal new child reminders total');
  }

  // ─────────────────────────────────────────────────────────
  // Cascade διαγραφή νήματος (ρίζα + όλα τα παιδιά)
  // ─────────────────────────────────────────────────────────

  Future<void> deleteReminderThread(int reminderId) async {
    DebugConfig.notif('ReminderScheduler.deleteReminderThread: id=$reminderId');
    final reminder = await SuperNoteHelper.instance.isar.reminders.get(reminderId);
    if (reminder == null) return;
    final rootId = reminder.parentReminderId ?? reminder.id;

    final children = await SuperNoteHelper.instance.isar.reminders
        .filter()
        .parentReminderIdEqualTo(rootId)
        .findAll();

    final allIds = [rootId, ...children.map((c) => c.id)];

    for (final id in allIds) {
      await NotificationService.instance.cancel(id);
    }

    await SuperNoteHelper.instance.isar.writeTxn(() async {
      await SuperNoteHelper.instance.isar.reminders.deleteAll(allIds);
    });

    DebugConfig.notif('deleteReminderThread: deleted thread with ids $allIds');
  }

  Future<void> deleteAllRemindersForItem(int itemId) async {
    DebugConfig.notif('ReminderScheduler.deleteAllRemindersForItem: itemId=$itemId');
    final all = await SuperNoteHelper.instance.isar.reminders
        .filter()
        .itemIdEqualTo(itemId)
        .findAll();
    for (final r in all) {
      await deleteReminderThread(r.id);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Υπάρχουσες μέθοδοι (όπως τις είχες)
  // ─────────────────────────────────────────────────────────

  Future<void> scheduleReminder(Reminder reminder) async {
    DebugConfig.notif('ReminderScheduler.scheduleReminder: id=${reminder.id}, trigger=${reminder.triggerAt}, status=${reminder.status.name}');
    final settings = await SuperNoteHelper.instance.settings.get();
    if (!settings.notificationsEnabled) return;
    if (reminder.triggerAt.isBefore(DateTime.now())) {
      DebugConfig.notif('scheduleReminder: trigger in past, skipping');
      return;
    }
    await _scheduleOne(
      reminder,
      sound:     settings.soundEnabled,
      vibration: settings.vibrationEnabled,
    );
  }

  Future<void> cancelReminder(int reminderId) async {
    DebugConfig.notif('ReminderScheduler.cancelReminder: id=$reminderId');
    await NotificationService.instance.cancel(reminderId);
  }

  Future<void> cancelAllForItem(int itemId) async {
    DebugConfig.notif('ReminderScheduler.cancelAllForItem: itemId=$itemId');
    final reminders = await SuperNoteHelper.instance.reminders.getForItem(itemId);
    for (final r in reminders) {
      await NotificationService.instance.cancel(r.id);
    }
  }

  Future<void> _scheduleOne(
      Reminder reminder, {
        bool sound = true,
        bool vibration = true,
      }) async {
    final now = DateTime.now();
    if (reminder.triggerAt.isBefore(now)) {
      DebugConfig.notif('ReminderScheduler._scheduleOne: SKIP - trigger in past');
      return;
    }

    String title = reminder.title ?? 'SuperNote';
    String body = reminder.body ?? 'Έχεις μια υπενθύμιση';

    if (reminder.title == null) {
      final item = await SuperNoteHelper.instance.items.getById(reminder.itemId);
      if (item != null) {
        title = item.icon != null
            ? '${item.icon} ${item.title ?? 'Χωρίς τίτλο'}'
            : item.title ?? 'Χωρίς τίτλο';
      }
    }

    try {
      await NotificationService.instance.schedule(
        id: reminder.id,
        title: title,
        body: body,
        scheduledAt: reminder.triggerAt,
        payload: reminder.itemId.toString(),
        sound: sound,
        vibration: vibration,
      );
      DebugConfig.notif('ReminderScheduler._scheduleOne: ✅ SUCCESS id=${reminder.id}');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler._scheduleOne: ❌ EXCEPTION id=${reminder.id}', e, stack);
    }
  }
}