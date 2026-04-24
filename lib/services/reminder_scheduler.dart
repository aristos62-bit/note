// lib/services/reminder_scheduler.dart
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';
import '../core/core.dart';
import 'package:isar/isar.dart';

class ReminderScheduler {
  ReminderScheduler._internal();
  static final ReminderScheduler instance = ReminderScheduler._internal();

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
  // Ανανέωση επαναλαμβανόμενων υπενθυμίσεων
  // ─────────────────────────────────────────────────────────

  Future<void> refreshRecurringReminders() async {
    DebugConfig.notif('ReminderScheduler.refreshRecurringReminders: started');
    final settings = await SuperNoteHelper.instance.settings.get();
    if (!settings.notificationsEnabled) {
      DebugConfig.notif('refreshRecurringReminders: notifications disabled, skipping');
      return;
    }

    final allRecurring = await SuperNoteHelper.instance.isar.reminders
        .filter()
        .rruleIsNotNull()
        .findAll();

    DebugConfig.notif('Found ${allRecurring.length} recurring reminders');
    final now = DateTime.now();
    int updated = 0;

    for (final reminder in allRecurring) {
      final rrule = reminder.rrule!;
      if (rrule.isEmpty) continue;

      final recurrence = rruleToRecurrence(rrule);
      if (recurrence == null) continue;

      bool needsNext = false;
      if (reminder.triggerAt.isBefore(now)) {
        needsNext = true;
      } else if (reminder.status != ReminderStatus.pending) {
        needsNext = true;
      }

      if (!needsNext) continue;

      DateTime start = reminder.triggerAt.isBefore(now) ? now : reminder.triggerAt;
      final nextTrigger = recurrence.nextOccurrence(start);
      if (nextTrigger == null) {
        DebugConfig.notif('Recurring reminder ${reminder.id}: no next occurrence, deleting thread');
        await deleteReminderThread(reminder.id);
        continue;
      }

      final rootId = reminder.parentReminderId ?? reminder.id;

      final existingChild = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .parentReminderIdEqualTo(rootId)
          .triggerAtEqualTo(nextTrigger)
          .findFirst();

      if (existingChild != null) {
        DebugConfig.notif('Child already exists for root $rootId at $nextTrigger, skipping');
        continue;
      }

      final child = Reminder()
        ..itemId = reminder.itemId
        ..triggerAt = nextTrigger
        ..rrule = reminder.rrule
        ..title = reminder.title
        ..body = reminder.body
        ..status = ReminderStatus.pending
        ..parentReminderId = rootId
        ..createdAt = DateTime.now();

      await SuperNoteHelper.instance.isar.writeTxn(() async {
        await SuperNoteHelper.instance.isar.reminders.put(child);
      });

      await scheduleReminder(child);
      updated++;
      DebugConfig.notif('Created child reminder ${child.id} for root $rootId at $nextTrigger');
    }

    DebugConfig.notif('refreshRecurringReminders: created $updated new child reminders');
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
  // Υπάρχουσες μέθοδοι (τροποποιημένες)
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