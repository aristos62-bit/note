// lib/services/reminder_scheduler.dart
//
// ═══════════════════════════════════════════════════════════════
// ΟΔΗΓΙΕΣ ΠΡΟΣΑΡΜΟΓΗΣ
// ═══════════════════════════════════════════════════════════════
//
// ΚΑΛΕΣΕ στο main.dart μετά το NotificationService.init():
//
//   await NotificationService.instance.init();
//   await ReminderScheduler.instance.scheduleAll(); // ← Αυτό
//
// Επίσης κάλεσε scheduleAll() κάθε φορά που:
//   - Ο χρήστης δημιουργεί/επεξεργάζεται reminder
//   - Η εφαρμογή επιστρέφει από background (AppLifecycleState.resumed)
//
// ═══════════════════════════════════════════════════════════════

import '../helpers/super_note_helper.dart';
import '../models/reminder.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/debug_config.dart';

class ReminderScheduler {
  ReminderScheduler._internal();
  static final ReminderScheduler instance = ReminderScheduler._internal();

  // ─────────────────────────────────────────────────────────
  // Προγραμματισμός ΟΛΩΝ των pending reminders
  // Κάλεσε αυτό στο app startup και μετά από κάθε αλλαγή
  // ─────────────────────────────────────────────────────────

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
  // Προγραμματισμός ενός reminder
  // Κάλεσε αυτό μετά τη δημιουργία νέου reminder
  // ─────────────────────────────────────────────────────────

  Future<void> scheduleReminder(Reminder reminder) async {
    DebugConfig.notif('ReminderScheduler.scheduleReminder: id=${reminder.id}, trigger=${reminder.triggerAt}, status=${reminder.status.name}');
    final settings = await SuperNoteHelper.instance.settings.get();
    DebugConfig.notif('ReminderScheduler.scheduleReminder: notificationsEnabled=${settings.notificationsEnabled}');
    if (!settings.notificationsEnabled) return;
    await _scheduleOne(
      reminder,
      sound:     settings.soundEnabled,
      vibration: settings.vibrationEnabled,
    );
  }

  Future<void> cancelReminder(int reminderId) async {
    DebugConfig.notif('ReminderScheduler.cancelReminder: id=$reminderId');
    await NotificationService.instance.cancel(reminderId);
    DebugConfig.notif('ReminderScheduler.cancelReminder: done id=$reminderId');
  }

  Future<void> cancelAllForItem(int itemId) async {
    DebugConfig.notif('ReminderScheduler.cancelAllForItem: itemId=$itemId');
    final reminders = await SuperNoteHelper.instance.reminders.getForItem(itemId);
    DebugConfig.notif('ReminderScheduler.cancelAllForItem: found ${reminders.length} reminders to cancel');
    for (final r in reminders) {
      DebugConfig.notif('  cancelling id=${r.id}');
      await NotificationService.instance.cancel(r.id);
    }
  }

  Future<void> _scheduleOne(
      Reminder reminder, {
        bool sound     = true,
        bool vibration = true,
      }) async {
    final now = DateTime.now();
    DebugConfig.notif('ReminderScheduler._scheduleOne: id=${reminder.id}, trigger=${reminder.triggerAt}, now=$now, status=${reminder.status.name}');

    if (reminder.triggerAt.isBefore(now)) {
      DebugConfig.notif('ReminderScheduler._scheduleOne: SKIP - trigger is in the past (diff=${now.difference(reminder.triggerAt).inSeconds}s)');
      return;
    }

    String title = reminder.title ?? 'SuperNote';
    String body  = reminder.body  ?? 'Έχεις μια υπενθύμιση';
    DebugConfig.notif('ReminderScheduler._scheduleOne: title from reminder="${reminder.title}", body="${reminder.body}"');

    if (reminder.title == null) {
      DebugConfig.notif('ReminderScheduler._scheduleOne: fetching item title for itemId=${reminder.itemId}');
      final item = await SuperNoteHelper.instance.items.getById(reminder.itemId);
      if (item != null) {
        title = item.icon != null
            ? '${item.icon} ${item.title ?? 'Χωρίς τίτλο'}'
            : item.title ?? 'Χωρίς τίτλο';
        DebugConfig.notif('ReminderScheduler._scheduleOne: fetched title="$title"');
      } else {
        DebugConfig.notif('ReminderScheduler._scheduleOne: WARNING item not found for itemId=${reminder.itemId}');
      }
    }

    DebugConfig.notif('ReminderScheduler._scheduleOne: calling NotificationService.schedule id=${reminder.id}, scheduledAt=${reminder.triggerAt}');
    try {
      await NotificationService.instance.schedule(
        id:          reminder.id,
        title:       title,
        body:        body,
        scheduledAt: reminder.triggerAt,
        payload:     reminder.itemId.toString(),
        sound:       sound,
        vibration:   vibration,
      );
      DebugConfig.notif('ReminderScheduler._scheduleOne: ✅ SUCCESS id=${reminder.id}');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler._scheduleOne: ❌ EXCEPTION id=${reminder.id}', e, stack);
    }
  }
}