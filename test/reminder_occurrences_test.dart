// test/reminder_occurrences_test.dart
//
// Pure-Dart tests για ReminderScheduler.planOccurrences (A3/A4 — ΒΗΜΑ 11).
// Χωρίς Isar-harness (static pure μέθοδος).
// Τρέξιμο: flutter test test/reminder_occurrences_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/recurrence.dart';
import 'package:super_note/services/reminder_scheduler.dart';

void main() {
  group('ReminderScheduler.planOccurrences', () {
    test('daily κάθε 3 ημέρες, σήμερα εκτός πλέγματος → μένει στο πλέγμα', () {
      const r = Recurrence(type: RecurrenceType.daily, interval: 3);
      final out = ReminderScheduler.planOccurrences(
          r, DateTime(2026, 9, 1, 9, 0), DateTime(2026, 9, 14, 10, 0), 3);
      expect(out, [
        DateTime(2026, 9, 16, 9, 0),
        DateTime(2026, 9, 19, 9, 0),
        DateTime(2026, 9, 22, 9, 0),
      ]);
    });

    test('monthly κάθε 2 μήνες (15η) από Ιαν → Μαρ, Μαΐ, Ιούλ', () {
      const r = Recurrence(
          type: RecurrenceType.monthly, interval: 2, days: [15]);
      final out = ReminderScheduler.planOccurrences(
          r, DateTime(2026, 1, 15, 9, 0), DateTime(2026, 2, 20, 12, 0), 3);
      expect(out, [
        DateTime(2026, 3, 15, 9, 0),
        DateTime(2026, 5, 15, 9, 0),
        DateTime(2026, 7, 15, 9, 0),
      ]);
    });

    test('yearly κάθε 2 χρόνια: Ιαν 2027 → Μαρ 2028 (όχι 2027)', () {
      const r = Recurrence(
          type: RecurrenceType.yearly, interval: 2, days: [3, 5]);
      final out = ReminderScheduler.planOccurrences(
          r, DateTime(2026, 3, 5, 9, 0), DateTime(2027, 1, 10, 12, 0), 2);
      expect(out, [
        DateTime(2028, 3, 5, 9, 0),
        DateTime(2030, 3, 5, 9, 0),
      ]);
    });

    test('μελλοντικό DTSTART: πρώτη εμφάνιση = DTSTART (όχι σήμερα)', () {
      final out = ReminderScheduler.planOccurrences(Recurrence.daily(),
          DateTime(2026, 10, 20, 9, 0), DateTime(2026, 10, 13, 12, 0), 3);
      expect(out, [
        DateTime(2026, 10, 20, 9, 0),
        DateTime(2026, 10, 21, 9, 0),
        DateTime(2026, 10, 22, 9, 0),
      ]);
    });

    test('daily πάνω από λήξη DST 25/10/2026 δεν κολλά', () {
      final out = ReminderScheduler.planOccurrences(Recurrence.daily(),
          DateTime(2026, 10, 23, 9, 0), DateTime(2026, 10, 24, 12, 0), 3);
      expect(out, [
        DateTime(2026, 10, 25, 9, 0),
        DateTime(2026, 10, 26, 9, 0),
        DateTime(2026, 10, 27, 9, 0),
      ]);
    });
  });

  group('Recurrence DST (Europe/Athens)', () {
    test('daily: 25/10/2026 (λήξη DST, μέρα 25 ωρών) → 26/10 ίδια ώρα', () {
      final n = Recurrence.daily().nextOccurrence(DateTime(2026, 10, 25, 9, 0));
      expect(n, DateTime(2026, 10, 26, 9, 0));
    });
    test('nextPeriodStart daily: 25/10 00:00 → 26/10 00:00 ακριβώς', () {
      final n =
      Recurrence.daily().nextPeriodStart(DateTime(2026, 10, 25));
      expect(n, DateTime(2026, 10, 26));
    });

    test('nextPeriodStart daily: 28/3 00:00 → 29/3 00:00 ακριβώς', () {
      final n =
      Recurrence.daily().nextPeriodStart(DateTime(2026, 3, 28));
      expect(n, DateTime(2026, 3, 29));
    });
  });
}
