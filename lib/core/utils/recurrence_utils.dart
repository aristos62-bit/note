// lib/utils/recurrence_utils.dart
// Βοηθητικές συναρτήσεις για μετατροπή Recurrence ↔ RRULE
import '../../models/models.dart';

/// Μετατρέπει ένα αντικείμενο Recurrence σε RRULE string (RFC 5545).
String? recurrenceToRRULE(Recurrence? recurrence) {
  if (recurrence == null) return null;
  return recurrence.toRRULE();
}

/// Μετατρέπει ένα RRULE string (από Reminder.rrule) σε Recurrence αντικείμενο.
Recurrence? rruleToRecurrence(String? rrule) {
  if (rrule == null || rrule.isEmpty) return null;

  final parts = rrule.split(';');
  String? freq;
  int interval = 1;
  List<int>? days;
  int? byMonth;
  int? byMonthDay;

  for (final p in parts) {
    if (p.startsWith('FREQ='))       freq        = p.substring(5);
    if (p.startsWith('INTERVAL='))   interval    = int.tryParse(p.substring(9)) ?? 1;
    if (p.startsWith('BYMONTH='))    byMonth     = int.tryParse(p.substring(8));
    if (p.startsWith('BYDAY=')) {
      final byday = p.substring(6);
      const dayMapRev = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
      days = byday.split(',').map((d) => dayMapRev[d]).whereType<int>().toList();
    }
    if (p.startsWith('BYMONTHDAY=')) {
      final raw = p.substring(11);
      // Για MONTHLY: comma-separated list
      // Για YEARLY: single int — θα χρησιμοποιηθεί παρακάτω
      byMonthDay = int.tryParse(raw.split(',').first.trim());
      if (freq != 'YEARLY') {
        // MONTHLY: διατήρησε όλες τις μέρες στη λίστα days
        days = raw.split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
      }
    }
  }

  RecurrenceType type;
  switch (freq) {
    case 'DAILY':
      type = RecurrenceType.daily;
      break;
    case 'WEEKLY':
      type = RecurrenceType.weekly;
      break;
    case 'MONTHLY':
      type = RecurrenceType.monthly;
      break;
    case 'YEARLY':
      type = RecurrenceType.yearly;
      // Για YEARLY: days = [month, day] από BYMONTH + BYMONTHDAY
      if (byMonth != null && byMonthDay != null) {
        days = [byMonth, byMonthDay];
      }
      break;
    default:
      type = RecurrenceType.daily;
  }

  return Recurrence(
    type: type,
    interval: interval,
    days: days,
  );
}