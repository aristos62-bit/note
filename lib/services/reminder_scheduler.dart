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

class ReminderScheduler {
  ReminderScheduler._internal();
  static final ReminderScheduler instance = ReminderScheduler._internal();

  // ─────────────────────────────────────────────────────────
  // Προγραμματισμός ΟΛΩΝ των pending reminders
  // Κάλεσε αυτό στο app startup και μετά από κάθε αλλαγή
  // ─────────────────────────────────────────────────────────

  Future<void> scheduleAll() async {
    final pending =
    await SuperNoteHelper.instance.reminders.getPending();

    for (final reminder in pending) {
      await _scheduleOne(reminder);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Προγραμματισμός ενός reminder
  // Κάλεσε αυτό μετά τη δημιουργία νέου reminder
  // ─────────────────────────────────────────────────────────

  Future<void> scheduleReminder(Reminder reminder) async {
    await _scheduleOne(reminder);
  }

  // ─────────────────────────────────────────────────────────
  // Ακύρωση reminder (π.χ. όταν ο χρήστης διαγράψει)
  // ─────────────────────────────────────────────────────────

  Future<void> cancelReminder(int reminderId) async {
    await NotificationService.instance.cancel(reminderId);
  }

  Future<void> cancelAllForItem(int itemId) async {
    final reminders = await SuperNoteHelper.instance.reminders
        .getForItem(itemId);
    for (final r in reminders) {
      await NotificationService.instance.cancel(r.id);
    }
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────

  Future<void> _scheduleOne(Reminder reminder) async {
    // Αγνόησε αν έχει ήδη περάσει
    if (reminder.triggerAt.isBefore(DateTime.now())) return;

    // Φέρε τον τίτλο από το item αν δεν υπάρχει τίτλος στο reminder
    String title = reminder.title ?? 'SuperNote';
    String body  = reminder.body  ?? 'Έχεις μια υπενθύμιση';

    if (reminder.title == null) {
      final item = await SuperNoteHelper.instance.items
          .getById(reminder.itemId);
      if (item != null) {
        title = item.icon != null
            ? '${item.icon} ${item.title ?? 'Χωρίς τίτλο'}'
            : item.title ?? 'Χωρίς τίτλο';
      }
    }

    await NotificationService.instance.schedule(
      id: reminder.id,
      title: title,
      body: body,
      scheduledAt: reminder.triggerAt,
      payload: reminder.itemId.toString(), // Για navigation στο tap
    );
  }
}