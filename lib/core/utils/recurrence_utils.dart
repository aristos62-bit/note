// lib/utils/recurrence_utils.dart
// Βοηθητικές συναρτήσεις για μετατροπή Recurrence ↔ RRULE
import '../../models/models.dart';

/// Μετατρέπει ένα αντικείμενο Recurrence σε RRULE string (RFC 5545).
String? recurrenceToRRULE(Recurrence? recurrence) {
  if (recurrence == null) return null;
  switch (recurrence.type) {
    case RecurrenceType.daily:
      return 'FREQ=DAILY;INTERVAL=${recurrence.interval}';
    case RecurrenceType.weekly:
      if (recurrence.days != null && recurrence.days!.isNotEmpty) {
        const dayMap = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
        final byday = recurrence.days!.map((d) => dayMap[d]).join(',');
        return 'FREQ=WEEKLY;INTERVAL=${recurrence.interval};BYDAY=$byday';
      } else {
        return 'FREQ=WEEKLY;INTERVAL=${recurrence.interval}';
      }
    case RecurrenceType.monthly:
      if (recurrence.dayOfMonth != null) {
        return 'FREQ=MONTHLY;INTERVAL=${recurrence.interval};BYMONTHDAY=${recurrence.dayOfMonth}';
      } else {
        return 'FREQ=MONTHLY;INTERVAL=${recurrence.interval}';
      }
    case RecurrenceType.custom:
      return 'FREQ=DAILY;INTERVAL=${recurrence.interval}';
  }
}

/// Μετατρέπει ένα RRULE string (από Reminder.rrule) σε Recurrence αντικείμενο.
Recurrence? rruleToRecurrence(String? rrule) {
  if (rrule == null || rrule.isEmpty) return null;
  final parts = rrule.split(';');
  String? freq;
  int interval = 1;
  List<int>? days;
  int? dayOfMonth;

  for (final p in parts) {
    if (p.startsWith('FREQ=')) freq = p.substring(5);
    if (p.startsWith('INTERVAL=')) interval = int.tryParse(p.substring(9)) ?? 1;
    if (p.startsWith('BYDAY=')) {
      final byday = p.substring(6);
      const dayMapRev = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
      days = byday.split(',').map((d) => dayMapRev[d]).whereType<int>().toList();
    }
    if (p.startsWith('BYMONTHDAY=')) {
      dayOfMonth = int.tryParse(p.substring(11));
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
    default:
      type = RecurrenceType.daily;
  }
  return Recurrence(
    type: type,
    interval: interval,
    days: days,
    dayOfMonth: dayOfMonth,
  );
}