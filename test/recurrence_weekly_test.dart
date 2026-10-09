// test/recurrence_weekly_test.dart
//
// Pure-Dart tests για weekly interval>1 + BYDAY (Session 54).
// Τρέξιμο: flutter test test/recurrence_weekly_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/recurrence.dart';

void main() {
  group('isValidWeeklyDay', () {
    // Δευτέρα 05/10/2026, anchor ίδια μέρα.
    final anchor = DateTime(2026, 10, 5, 9, 0);
    const days = [DateTime.monday];

    test('interval=1: κάθε Δευτέρα έγκυρη', () {
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 5), days, 1, anchor), isTrue);
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 12), days, 1, anchor), isTrue);
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 6), days, 1, anchor), isFalse);
    });

    test('interval=2: μόνο ανά 2η εβδομάδα', () {
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 5), days, 2, anchor), isTrue);
      // 12/10 = επόμενη εβδομάδα → άκυρη
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 12), days, 2, anchor), isFalse);
      // 19/10 = μεθεπόμενη → έγκυρη
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 19), days, 2, anchor), isTrue);
      // Τρίτη έγκυρης εβδομάδας → άκυρη (λάθος weekday)
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 20), days, 2, anchor), isFalse);
    });

    test('anchor στο μέλλον → week 0, δεν κολλάει', () {
      final futureAnchor = DateTime(2027, 1, 4);
      expect(
          Recurrence.isValidWeeklyDay(
              DateTime(2026, 10, 5), days, 2, futureAnchor),
          isTrue);
    });
  });

  group('nextOccurrence weekly', () {
    test('interval=2 Δευτέρα από 5/10 → 19/10 (όχι 12/10)', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      final from = DateTime(2026, 10, 5, 9, 0);
      final next = r.nextOccurrence(from, anchor: DateTime(2026, 10, 5, 9, 0))!;
      expect(next.year, 2026);
      expect(next.month, 10);
      expect(next.day, 19);
      expect(next.weekday, DateTime.monday);
      // Ώρα διατηρείται από from.
      expect(next.hour, 9);
    });

    test('legacy path (χωρίς anchor) = παλιά συμπεριφορά', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      final next = r.nextOccurrence(DateTime(2026, 10, 5, 9, 0))!;
      expect(next.day, 12); // παλιά (λανθασμένη) συμπεριφορά διατηρείται
    });

    test('interval=1 αμετάβλητο', () {
      const r = Recurrence(type: RecurrenceType.weekly, days: [DateTime.monday]);
      final next = r.nextOccurrence(DateTime(2026, 10, 6, 9, 0), anchor: DateTime(2026, 10, 5))!;
      expect(next.day, 12);
    });
  });

  group('anchor divergence — documented decision (epoch vs root)', () {
    const days = [DateTime.monday];
    final mon0 = Recurrence.epochMonday;
    final mon1 = mon0.add(const Duration(days: 7));
    final mon2 = mon0.add(const Duration(days: 14));

    test('epoch: mon0 ON, mon1 OFF, mon2 ON', () {
      expect(Recurrence.isValidWeeklyDay(mon0, days, 2, Recurrence.epochMonday), isTrue);
      expect(Recurrence.isValidWeeklyDay(mon1, days, 2, Recurrence.epochMonday), isFalse);
      expect(Recurrence.isValidWeeklyDay(mon2, days, 2, Recurrence.epochMonday), isTrue);
    });

    test('root σε off-epoch εβδομάδα: αντίστροφα (mirror)', () {
      expect(Recurrence.isValidWeeklyDay(mon1, days, 2, mon1), isTrue);
      expect(Recurrence.isValidWeeklyDay(mon2, days, 2, mon1), isFalse);
      expect(Recurrence.isValidWeeklyDay(mon0, days, 2, mon1), isTrue);
    });

    test('native agreement: periodStart = valid boundary', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      expect(r.getPeriodStart(DateTime(1970, 1, 14)), DateTime(1970, 1, 5));
      expect(Recurrence.isValidWeeklyDay(DateTime(1970, 1, 5), days, 2, Recurrence.epochMonday), isTrue);
      expect(Recurrence.isValidWeeklyDay(DateTime(1970, 1, 12), days, 2, Recurrence.epochMonday), isFalse);
      expect(Recurrence.isValidWeeklyDay(DateTime(1970, 1, 19), days, 2, Recurrence.epochMonday), isTrue);
    });
  });
}
