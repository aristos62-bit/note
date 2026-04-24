// lib/utils/reminder_picker.dart
import 'package:flutter/material.dart';

/// Εμφανίζει dialog για επιλογή ημερομηνίας και ώρας υπενθύμισης.
/// Επιστρέφει DateTime ή null αν ακυρωθεί.
Future<DateTime?> showReminderPicker({
  required BuildContext context,
  required DateTime initialDateTime,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final first = firstDate ?? now;
  final last = lastDate ?? DateTime(now.year + 5);

  final date = await showDatePicker(
    context: context,
    initialDate: initialDateTime.isAfter(now) ? initialDateTime : now,
    firstDate: first,
    lastDate: last,
    helpText: 'Ημερομηνία υπενθύμισης',
    locale: const Locale('el'),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDateTime),
    helpText: 'Ώρα υπενθύμισης',
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}