// lib/services/reminder_text.dart
//
// SPoT για το κείμενο των OS notifications. Pure — χωρίς Isar/plugin/UI.
// Εδώ ζει η μία και μοναδική σύμβαση title/body, ώστε scheduler, DB sync
// και tests να βλέπουν το ίδιο αποτέλεσμα.

import '../helpers/item_color_helper.dart';
import '../models/models.dart';

/// Τίτλος όλων των habit-generated one-shots (κοινό literal με HabitService).
const String habitGeneratedTitle = 'Υπενθύμιση συνήθειας';

class ReminderNotificationText {
  const ReminderNotificationText({required this.title, required this.body});

  final String title;
  final String body;

  bool matches({String? title, String? body}) =>
      this.title == title && this.body == body;

  @override
  String toString() => 'ReminderNotificationText(title=$title, body=$body)';
}

/// Resolve του τελικού κειμένου μιας reminder row.
///
/// Η σειρά των κανόνων είναι σημαντική:
/// 1. title == null → live title από item (icon + title). Το body μένει ως έχει.
/// 2. generic «Υπενθύμιση» ή event-γενέθλια → live body από item.title.
/// 3. habit-generated → live body «Υπενθύμιση: <όνομα>».
/// 4. contact birthday → title+body «Γενέθλια <όνομα>».
///
/// Δεν αλλάζει custom title/body. Αν το item title είναι κενό, κρατά τα
/// αποθηκευμένα (καμία σιωπηλή διαγραφή).
ReminderNotificationText resolveReminderNotificationText(
  Reminder reminder,
  Item? item,
) {
  var title = reminder.title ?? 'SuperNote';
  var body = reminder.body ?? 'Έχεις μια υπενθύμιση';

  if (reminder.title == null && item != null) {
    title = item.icon != null
        ? '${item.icon} ${item.title ?? 'Χωρίς τίτλο'}'
        : item.title ?? 'Χωρίς τίτλο';
    return ReminderNotificationText(title: title, body: body);
  }

  if (item == null) {
    return ReminderNotificationText(title: title, body: body);
  }

  final itemTitle = item.title;
  if (itemTitle == null || itemTitle.isEmpty) {
    return ReminderNotificationText(title: title, body: body);
  }

  if (reminder.title == 'Υπενθύμιση' ||
      ItemColorHelper.isBirthdayEvent(item)) {
    body = itemTitle;
  } else if (reminder.title == habitGeneratedTitle) {
    body = 'Υπενθύμιση: $itemTitle';
  } else if (item.type == ItemType.contact &&
      (reminder.title?.startsWith('Γενέθλια ') ?? false)) {
    title = 'Γενέθλια $itemTitle';
    body = title;
  }

  return ReminderNotificationText(title: title, body: body);
}

/// Το text που επιτρέπεται να γραφτεί πίσω στη DB (DB sync).
/// Για title == null ΔΕΝ γράφουμε το derived title — θα έχανε το live icon/title.
ReminderNotificationText? syncableReminderNotificationText(
  Reminder reminder,
  Item? item,
) {
  if (reminder.title == null) return null;
  final resolved = resolveReminderNotificationText(reminder, item);
  if (resolved.title == reminder.title && resolved.body == reminder.body) {
    return null;
  }
  return resolved;
}
